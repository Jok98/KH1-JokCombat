LUAGUI_NAME = "JokCombat State Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only probe for KH1 player action state on Steam Global."

-- This experiment intentionally contains no Write* calls.
-- It logs raw values first; action names will be assigned only after observation
-- on an unmodified Steam save.

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local HEARTBEAT_FRAMES = 300           -- 0 disables unchanged-state heartbeats
local SLOT_REFERENCE_MIN = 0x8000
local SLOT_REFERENCE_MAX = 0xFFFF

local STEAM_GL = {
    name = "Steam Global",
    fingerprintAddress = 0x3B2271,

    -- Validated on Steam Global through a live read-only gameplay capture on
    -- 2026-08-09. The resolved absolute pointer remains session-specific.
    playerPointerAddress = 0x2537E48,
}

local PLAYER = {
    actionControl = 0x000,
    slotReference = 0x06C,
    airborneState = 0x070,
    animationId = 0x164,
    secondaryAnimationId = 0x168,
    animationTime = 0x16C,
}

local canRun = false
local buildDetected = false
local waitingWasLogged = false
local unsupportedWasLogged = false
local frame = 0
local lastLogFrame = 0
local lastStateKey = nil
local lastPlayerPointer = 0

local function isFinite(value)
    return value == value and value > -math.huge and value < math.huge
end

local function isPlausiblePointer(value)
    return value >= 0x10000 and value <= 0x00007FFFFFFFFFFF
end

local function readSnapshot(playerPointer)
    local slotReference = ReadShort(
        playerPointer + PLAYER.slotReference, true)
    local animationTime = ReadFloat(
        playerPointer + PLAYER.animationTime, true)

    -- Critical Mix EGS commonly sees a 0x9000-based slot reference. A live
    -- Steam Global read on 2026-08-09 produced 0xCC10 for the valid Sora
    -- object, so this check deliberately accepts the broader high-word range.
    if slotReference < SLOT_REFERENCE_MIN
        or slotReference > SLOT_REFERENCE_MAX then
        return nil
    end
    if not isFinite(animationTime) or math.abs(animationTime) > 100000.0 then
        return nil
    end

    local airborneRaw = ReadInt(
        playerPointer + PLAYER.airborneState, true)

    return {
        pointer = playerPointer,
        actionControl = ReadByte(
            playerPointer + PLAYER.actionControl, true),
        animationId = ReadByte(
            playerPointer + PLAYER.animationId, true),
        secondaryAnimationId = ReadByte(
            playerPointer + PLAYER.secondaryAnimationId, true),
        animationTime = animationTime,
        airborneRaw = airborneRaw,
        airborne = airborneRaw ~= 0,
        slotReference = slotReference,
    }
end

local function tryDetectBuild()
    if ReadLong(STEAM_GL.fingerprintAddress) ~= FINGERPRINT then
        if frame >= 300 and not unsupportedWasLogged then
            unsupportedWasLogged = true
            ConsolePrint(
                "JokCombat State Probe - unsupported KH1 build; "
                .. "no memory beyond the version fingerprint was read.")
        end
        return false
    end

    buildDetected = true
    ConsolePrint(
        "JokCombat State Probe - detected " .. STEAM_GL.name
        .. "; waiting for a valid player object.")
    return true
end

local function logSnapshot(snapshot, reason)
    ConsolePrint(string.format(
        "[state:%s] ptr=0x%X control=0x%02X anim=0x%02X "
        .. "secondary=0x%02X time=%.2f airborne=%s raw70=0x%08X "
        .. "slotRef=0x%04X",
        reason,
        snapshot.pointer,
        snapshot.actionControl,
        snapshot.animationId,
        snapshot.secondaryAnimationId,
        snapshot.animationTime,
        tostring(snapshot.airborne),
        snapshot.airborneRaw,
        snapshot.slotReference))
end

function _OnInit()
    frame = 0
    lastLogFrame = 0
    lastStateKey = nil
    lastPlayerPointer = 0
    buildDetected = false
    waitingWasLogged = false
    unsupportedWasLogged = false

    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND" then
        ConsolePrint(
            "JokCombat State Probe - wrong game or Lua engine; disabled.")
        canRun = false
        return
    end

    canRun = true
    ConsolePrint(
        "JokCombat State Probe initialized (read-only; zero Write* calls).")
end

function _OnFrame()
    if not canRun then return end
    frame = frame + 1

    if not buildDetected and not tryDetectBuild() then return end

    local playerPointer = ReadLong(STEAM_GL.playerPointerAddress)
    if not isPlausiblePointer(playerPointer) then
        if not waitingWasLogged then
            waitingWasLogged = true
            ConsolePrint(
                "JokCombat State Probe - player object unavailable; "
                .. "load a save to continue.")
        end
        lastStateKey = nil
        lastPlayerPointer = 0
        return
    end

    local snapshot = readSnapshot(playerPointer)
    if snapshot == nil then
        if not waitingWasLogged then
            waitingWasLogged = true
            ConsolePrint(
                "JokCombat State Probe - candidate player pointer failed "
                .. "sanity checks; no action state was accepted.")
        end
        lastStateKey = nil
        lastPlayerPointer = 0
        return
    end

    waitingWasLogged = false

    local stateKey = string.format(
        "%X:%X:%X:%s",
        snapshot.actionControl,
        snapshot.animationId,
        snapshot.secondaryAnimationId,
        tostring(snapshot.airborne))

    local pointerChanged = playerPointer ~= lastPlayerPointer
    local stateChanged = stateKey ~= lastStateKey
    local heartbeatDue = HEARTBEAT_FRAMES > 0
        and frame - lastLogFrame >= HEARTBEAT_FRAMES

    if pointerChanged then
        logSnapshot(snapshot, "player")
    elseif stateChanged then
        logSnapshot(snapshot, "change")
    elseif heartbeatDue then
        logSnapshot(snapshot, "heartbeat")
    end

    if pointerChanged or stateChanged or heartbeatDue then
        lastLogFrame = frame
    end
    lastPlayerPointer = playerPointer
    lastStateKey = stateKey
end
