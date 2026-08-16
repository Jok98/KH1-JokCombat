LUAGUI_NAME = "JokCombat MP Hit Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only Steam normal-hit and Sora MP telemetry probe."

-- This diagnostic only observes memory. It never clears the game's contact
-- byte and never changes Sora's MP. Production regeneration stays disabled
-- until a controlled Steam Global capture validates both signals.

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local HEARTBEAT_FRAMES = 300
local SLOT_REFERENCE_MIN = 0x8000
local SLOT_REFERENCE_MAX = 0xFFFF

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    battleSlotBase = 0x2D50000,
    connectCounter = 0x296B230,
}

local PLAYER = {
    actionControl = 0x000,
    slotReference = 0x06C,
    airborneState = 0x070,
    animationId = 0x164,
    secondaryAnimationId = 0x168,
    animationTime = 0x16C,
}

local BATTLE_SLOT = {
    currentMP = 0x44,
    maxMP = 0x48,
}

local NORMAL_ATTACK = {
    [0xC8] = { family = "ground", label = "C8" },
    [0xC9] = { family = "ground", label = "C9" },
    [0xCA] = { family = "ground", label = "CA" },
    [0xCB] = { family = "ground", label = "CB-finisher" },
    [0xCC] = { family = "air", label = "CC" },
    [0xCD] = { family = "air", label = "CD" },
    [0xCE] = { family = "air", label = "CE-finisher" },
}

-- Critical Mix's authorized reference treats these values as physical-contact
-- candidates. The probe records their Steam behavior without acting on them.
local HIT_SIGNAL = { [0x01] = true, [0x40] = true }

local canRun = false
local buildDetected = false
local waitingWasLogged = false
local unsupportedWasLogged = false
local frame = 0
local lastHeartbeatFrame = 0
local lastPlayerPointer = 0
local lastSignal = nil
local lastCurrentMP = nil
local lastMaxMP = nil
local lastExcludedReuse = nil
local activeAttack = nil
local attackSerial = 0

local function isFinite(value)
    return value == value and value > -math.huge and value < math.huge
end

local function isPlausiblePointer(value)
    return value >= 0x10000 and value <= 140737488355327.0
end

local function isNormalAttack(snapshot)
    local descriptor = NORMAL_ATTACK[snapshot.animation]
    if descriptor == nil then return false end

    -- KH1 Limits can reuse C8-CA with low secondary IDs. Preserve the same
    -- exclusion already used by JokCombat's native attack-speed controller.
    if snapshot.animation <= 0xCA and snapshot.secondary <= 0x02 then
        return false
    end
    return true
end

local function readSnapshot(playerPointer)
    local slotReference = ReadShort(
        playerPointer + PLAYER.slotReference, true)
    local animationTime = ReadFloat(
        playerPointer + PLAYER.animationTime, true)
    if slotReference < SLOT_REFERENCE_MIN
        or slotReference > SLOT_REFERENCE_MAX then
        return nil
    end
    if not isFinite(animationTime) or math.abs(animationTime) > 100000.0 then
        return nil
    end

    local battleSlot = ADDRESS.battleSlotBase + slotReference
    local airborneRaw = ReadInt(
        playerPointer + PLAYER.airborneState, true)
    return {
        pointer = playerPointer,
        slotReference = slotReference,
        battleSlot = battleSlot,
        control = ReadByte(
            playerPointer + PLAYER.actionControl, true),
        airborneRaw = airborneRaw,
        airborne = airborneRaw ~= 0,
        animation = ReadByte(
            playerPointer + PLAYER.animationId, true),
        secondary = ReadByte(
            playerPointer + PLAYER.secondaryAnimationId, true),
        time = animationTime,
        currentMP = ReadByte(battleSlot + BATTLE_SLOT.currentMP),
        maxMP = ReadByte(battleSlot + BATTLE_SLOT.maxMP),
        signal = ReadByte(ADDRESS.connectCounter),
    }
end

local function tryDetectBuild()
    if ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        if frame >= 300 and not unsupportedWasLogged then
            unsupportedWasLogged = true
            ConsolePrint(
                "[JokCombat:mp-hit-probe] unsupported KH1 build; "
                .. "no gameplay memory was accepted.")
        end
        return false
    end

    buildDetected = true
    ConsolePrint(
        "[JokCombat:mp-hit-probe] Steam Global fingerprint accepted; "
        .. "waiting for a valid Sora object.")
    return true
end

local function attackTag()
    if activeAttack == nil then return "none" end
    return string.format("#%d", activeAttack.serial)
end

local function finishAttack(reason)
    if activeAttack == nil then return end
    ConsolePrint(string.format(
        "[JokCombat:mp-hit-probe:attack-end] #%d %s hitCandidate=%s "
        .. "signalEdges=%d frames=%d reason=%s",
        activeAttack.serial,
        activeAttack.label,
        tostring(activeAttack.hitCandidate),
        activeAttack.signalEdges,
        frame - activeAttack.startFrame + 1,
        reason))
    activeAttack = nil
end

local function beginAttack(snapshot, descriptor)
    attackSerial = attackSerial + 1
    activeAttack = {
        serial = attackSerial,
        animation = snapshot.animation,
        label = descriptor.family .. "/" .. descriptor.label,
        startFrame = frame,
        lastTime = snapshot.time,
        hitCandidate = false,
        signalEdges = 0,
    }
    ConsolePrint(string.format(
        "[JokCombat:mp-hit-probe:attack-start] #%d %s control=0x%02X "
        .. "secondary=0x%02X time=%.2f airborne=%s raw70=0x%08X "
        .. "signal=0x%02X mp=%d/%d",
        activeAttack.serial,
        activeAttack.label,
        snapshot.control,
        snapshot.secondary,
        snapshot.time,
        tostring(snapshot.airborne),
        snapshot.airborneRaw,
        snapshot.signal,
        snapshot.currentMP,
        snapshot.maxMP))
end

local function updateAttack(snapshot)
    local descriptor = NORMAL_ATTACK[snapshot.animation]
    local eligible = isNormalAttack(snapshot)
    if not eligible then
        if activeAttack ~= nil then finishAttack("left-normal-family") end
        if descriptor ~= nil and snapshot.animation <= 0xCA
            and snapshot.secondary <= 0x02 then
            local reuseKey = snapshot.animation * 0x100 + snapshot.secondary
            if reuseKey ~= lastExcludedReuse then
                ConsolePrint(string.format(
                    "[JokCombat:mp-hit-probe:reuse-excluded] anim=0x%02X "
                    .. "secondary=0x%02X time=%.2f signal=0x%02X",
                    snapshot.animation, snapshot.secondary,
                    snapshot.time, snapshot.signal))
                lastExcludedReuse = reuseKey
            end
        else
            lastExcludedReuse = nil
        end
        return
    end
    lastExcludedReuse = nil

    local restarted = activeAttack ~= nil
        and activeAttack.animation == snapshot.animation
        and snapshot.time + 0.50 < activeAttack.lastTime
    local changed = activeAttack ~= nil
        and activeAttack.animation ~= snapshot.animation
    if activeAttack == nil or restarted or changed then
        if activeAttack ~= nil then
            finishAttack(restarted and "time-reset" or "next-normal")
        end
        beginAttack(snapshot, descriptor)
    end
    activeAttack.lastTime = snapshot.time
end

local function updateSignal(snapshot)
    if lastSignal == nil or snapshot.signal == lastSignal then return end

    ConsolePrint(string.format(
        "[JokCombat:mp-hit-probe:signal] 0x%02X->0x%02X "
        .. "candidate=%s attack=%s anim=0x%02X secondary=0x%02X "
        .. "time=%.2f mp=%d/%d",
        lastSignal,
        snapshot.signal,
        tostring(HIT_SIGNAL[snapshot.signal] == true),
        attackTag(),
        snapshot.animation,
        snapshot.secondary,
        snapshot.time,
        snapshot.currentMP,
        snapshot.maxMP))

    if HIT_SIGNAL[snapshot.signal] and activeAttack ~= nil then
        activeAttack.signalEdges = activeAttack.signalEdges + 1
        if not activeAttack.hitCandidate then
            activeAttack.hitCandidate = true
            ConsolePrint(string.format(
                "[JokCombat:mp-hit-probe:hit-candidate] #%d %s "
                .. "signal=0x%02X time=%.2f mp=%d/%d",
                activeAttack.serial,
                activeAttack.label,
                snapshot.signal,
                snapshot.time,
                snapshot.currentMP,
                snapshot.maxMP))
        end
    end
end

local function updateMP(snapshot)
    if lastCurrentMP == nil then return end
    if snapshot.currentMP == lastCurrentMP and snapshot.maxMP == lastMaxMP then
        return
    end
    ConsolePrint(string.format(
        "[JokCombat:mp-hit-probe:mp-change] %d/%d -> %d/%d "
        .. "attack=%s anim=0x%02X signal=0x%02X",
        lastCurrentMP, lastMaxMP,
        snapshot.currentMP, snapshot.maxMP,
        attackTag(), snapshot.animation, snapshot.signal))
end

local function resetObservation(reason)
    finishAttack(reason)
    lastPlayerPointer = 0
    lastSignal = nil
    lastCurrentMP = nil
    lastMaxMP = nil
    lastExcludedReuse = nil
end

function _OnInit()
    canRun = GAME_ID == EXPECTED_GAME_ID and ENGINE_TYPE == "BACKEND"
    buildDetected = false
    waitingWasLogged = false
    unsupportedWasLogged = false
    frame = 0
    lastHeartbeatFrame = 0
    attackSerial = 0
    resetObservation("reload")

    if not canRun then
        ConsolePrint(
            "[JokCombat:mp-hit-probe] wrong game or Lua engine; disabled.")
        return
    end
    ConsolePrint(
        "[JokCombat:mp-hit-probe] initialized read-only; MP recovery is OFF.")
end

function _OnFrame()
    if not canRun then return end
    frame = frame + 1
    if not buildDetected and not tryDetectBuild() then return end

    local playerPointer = ReadLong(ADDRESS.playerPointer)
    if not isPlausiblePointer(playerPointer) then
        if not waitingWasLogged then
            waitingWasLogged = true
            ConsolePrint(
                "[JokCombat:mp-hit-probe] player unavailable; load gameplay.")
        end
        resetObservation("player-unavailable")
        return
    end

    local snapshot = readSnapshot(playerPointer)
    if snapshot == nil then
        if not waitingWasLogged then
            waitingWasLogged = true
            ConsolePrint(
                "[JokCombat:mp-hit-probe] candidate player failed sanity checks.")
        end
        resetObservation("invalid-player")
        return
    end
    waitingWasLogged = false

    local pointerChanged = playerPointer ~= lastPlayerPointer
    if pointerChanged then
        resetObservation("player-changed")
        ConsolePrint(string.format(
            "[JokCombat:mp-hit-probe:player] ptr=0x%X slotRef=0x%04X "
            .. "battleSlot=0x%X mp=%d/%d signal=0x%02X",
            playerPointer,
            snapshot.slotReference,
            snapshot.battleSlot,
            snapshot.currentMP,
            snapshot.maxMP,
            snapshot.signal))
    end

    updateAttack(snapshot)
    updateSignal(snapshot)
    updateMP(snapshot)

    if frame - lastHeartbeatFrame >= HEARTBEAT_FRAMES then
        ConsolePrint(string.format(
            "[JokCombat:mp-hit-probe:heartbeat] attack=%s control=0x%02X "
            .. "anim=0x%02X secondary=0x%02X time=%.2f airborne=%s "
            .. "signal=0x%02X mp=%d/%d",
            attackTag(), snapshot.control, snapshot.animation,
            snapshot.secondary, snapshot.time, tostring(snapshot.airborne),
            snapshot.signal, snapshot.currentMP, snapshot.maxMP))
        lastHeartbeatFrame = frame
    end

    lastPlayerPointer = playerPointer
    lastSignal = snapshot.signal
    lastCurrentMP = snapshot.currentMP
    lastMaxMP = snapshot.maxMP
end
