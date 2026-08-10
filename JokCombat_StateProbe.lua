LUAGUI_NAME = "JokCombat State Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only Steam state and X->Triangle branch-entry probe."

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
    rawButtonsAddress = 0x22C9301,
    commandMenuStateAddress = 0x2852790,
    commandMenuVisualSlotAddress = 0x2852794,
    commandMenuSlotAddress = 0x28527AC,
    comboPositionAddress = 0x296B221,
    maxGroundComboAddress = 0x2D5CCE4,
    maxAirComboAddress = 0x2D5CCE5,
}

local BUTTON = {
    L2 = 0x01,
    R2 = 0x02,
    L1 = 0x04,
    R1 = 0x08,
    TRIANGLE = 0x10,
}

local SHOULDER_MASK = BUTTON.L2 | BUTTON.R2 | BUTTON.L1 | BUTTON.R1
local GROUND_NORMAL = { [0xC8] = true, [0xC9] = true, [0xCA] = true }
local AIR_NORMAL = { [0xCC] = true, [0xCD] = true }

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
local lastRawButtons = 0

local function isFinite(value)
    return value == value and value > -math.huge and value < math.huge
end

local function isPlausiblePointer(value)
    -- Keep the upper bound as an exactly representable float. This avoids
    -- truncation in 32-bit Lua 5.3 test runtimes while retaining the same
    -- canonical user-space limit used by LuaBackend on Windows x64.
    return value >= 0x10000 and value <= 140737488355327.0
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
        comboPosition = ReadByte(STEAM_GL.comboPositionAddress),
        maxGroundCombo = ReadByte(STEAM_GL.maxGroundComboAddress),
        maxAirCombo = ReadByte(STEAM_GL.maxAirComboAddress),
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
        .. "slotRef=0x%04X combo=%d/%d airMax=%d",
        reason,
        snapshot.pointer,
        snapshot.actionControl,
        snapshot.animationId,
        snapshot.secondaryAnimationId,
        snapshot.animationTime,
        tostring(snapshot.airborne),
        snapshot.airborneRaw,
        snapshot.slotReference,
        snapshot.comboPosition,
        snapshot.maxGroundCombo,
        snapshot.maxAirCombo))
end

local function branchPath(position)
    if position < 1 or position > 16 then return nil end
    return string.rep("X", position) .. "T"
end

local function logTriangleEdge(snapshot, rawButtons)
    local trianglePressed = (rawButtons & BUTTON.TRIANGLE) ~= 0
        and (lastRawButtons & BUTTON.TRIANGLE) == 0
    if not trianglePressed then return end

    if (rawButtons & SHOULDER_MASK) ~= 0 then
        -- L1/R1 retain native magic shortcuts; L2/R2 retain the configurable
        -- Action Ability loadout. None of those chords belongs to this tree.
        return
    end

    local menuState = ReadByte(STEAM_GL.commandMenuStateAddress)
    local visualSlot = ReadByte(STEAM_GL.commandMenuVisualSlotAddress)
    local menuSlot = ReadByte(STEAM_GL.commandMenuSlotAddress)
    if menuState ~= 0 or visualSlot ~= 0 or menuSlot ~= 0 then
        ConsolePrint(string.format(
            "[branch:native] Triangle reserved for KH1 command: "
            .. "menu=%d visual=%d slot=%d anim=0x%02X combo=%d.",
            menuState, visualSlot, menuSlot,
            snapshot.animationId, snapshot.comboPosition))
        return
    end

    local context = nil
    local maximum = nil
    if snapshot.airborne and AIR_NORMAL[snapshot.animationId] then
        context = "air"
        maximum = snapshot.maxAirCombo
    elseif not snapshot.airborne
        and GROUND_NORMAL[snapshot.animationId] then
        context = "ground"
        maximum = snapshot.maxGroundCombo
    end

    local path = branchPath(snapshot.comboPosition)
    if context ~= nil and path ~= nil
        and snapshot.comboPosition < maximum then
        ConsolePrint(string.format(
            "[branch:candidate] context=%s path=%s position=%d/%d "
            .. "anim=0x%02X time=%.2f (observed only; input untouched).",
            context, path, snapshot.comboPosition, maximum,
            snapshot.animationId, snapshot.animationTime))
    elseif snapshot.animationId == 0xCB or snapshot.animationId == 0xCE then
        ConsolePrint(string.format(
            "[branch:excluded] Triangle after native finisher 0x%02X "
            .. "is not an initial branch entry (combo=%d time=%.2f).",
            snapshot.animationId, snapshot.comboPosition,
            snapshot.animationTime))
    else
        ConsolePrint(string.format(
            "[branch:neutral] Triangle stayed native: no active X trunk "
            .. "(airborne=%s anim=0x%02X combo=%d time=%.2f).",
            tostring(snapshot.airborne), snapshot.animationId,
            snapshot.comboPosition, snapshot.animationTime))
    end
end

function _OnInit()
    frame = 0
    lastLogFrame = 0
    lastStateKey = nil
    lastPlayerPointer = 0
    lastRawButtons = 0
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
        lastRawButtons = ReadByte(STEAM_GL.rawButtonsAddress)
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
        lastRawButtons = ReadByte(STEAM_GL.rawButtonsAddress)
        return
    end

    waitingWasLogged = false

    local rawButtons = ReadByte(STEAM_GL.rawButtonsAddress)
    logTriangleEdge(snapshot, rawButtons)

    local stateKey = string.format(
        "%X:%X:%X:%s:%X:%X:%X",
        snapshot.actionControl,
        snapshot.animationId,
        snapshot.secondaryAnimationId,
        tostring(snapshot.airborne),
        snapshot.comboPosition,
        snapshot.maxGroundCombo,
        snapshot.maxAirCombo)

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
    lastRawButtons = rawButtons
end
