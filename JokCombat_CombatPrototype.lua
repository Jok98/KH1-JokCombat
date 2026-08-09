LUAGUI_NAME = "JokCombat Combat Prototype"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra / KSX"
LUAGUI_DESC = "Target-free normal chains, Triangle finisher, universal Guard cancel, jump branch and fixed Dodge."

-- JokCombat v0.2.2 prototype for the current Steam Global executable.
-- Critical Mix was used as an authorized technical reference. This script is
-- intentionally limited to combat/input state and does not touch save data,
-- story flags, rewards, inventory, AP, levels, worlds, chests, or synthesis.

local CONFIG = {
    enabled = true,
    debugLog = true,

    attackBuffer = true,
    infiniteGroundNormals = true,
    triangleGroundFinisher = true,
    groundToAirJumpBranch = true,
    defensiveCancels = true,
    universalGuardCancel = true,
    guardOnL2Circle = true,
    fixedDodgeOnSquare = true,

    -- Enabled for the first combat test so the requested bindings also work
    -- on an early save. This bypass is runtime-only and never edits the save.
    -- Set false later to respect vanilla ability acquisition/equipment.
    unlockDefensiveActions = true,

    -- A press made early in an attack is remembered until the native link
    -- window opens. The short delay lets a native accepted press win first,
    -- which prevents one physical input from creating two attacks.
    attackBufferFrames = 45,
    attackBufferDelayFrames = 3,
    groundChainMemoryFrames = 90,
    releasedCommandMinimumFrames = 1,
    releasedCommandTimeoutFrames = 30,
    transitionCheckFrames = 12,
    forcedInputFrames = 4,
}

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local VERSION = "v0.2.2"

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    rawButtons = 0x22C9301,
    commandMenuSlot = 0x28527AC,
    triggerMenu1 = 0x23D3F80,
    triggerMenu2 = 0x232DDC4,
    defenseAbilityFlags = 0x2D5EC10,

    -- Steam ports of Critical Mix's transient combo byte and Sora's active
    -- ground-combo length. These do not point to the save file.
    comboPosition = 0x296B221,
    maxGroundComboLength = 0x2D5CCE4,

    circleControlMap = 0x22C9345,
    squareControlMap = 0x22C9347,
    forceCircleBranch = 0x2A7B74,       -- 74 normal, 72 forced
    forceSquareBranch = 0x2A7BD6,       -- 84 normal, 82 forced
    airDefenseBranch = 0x2A7BE0,        -- 85 ground-only, 82 allow in air
    guardAvailabilityBranch = 0x2A7BFD, -- 74 normal, 72 enabled, EB choose roll
    guardSelectionBranch = 0x2A7C01,    -- 74 normal, EB choose guard
    dodgeAvailabilityBranch = 0x2A7C1F, -- 84 normal, 82 enabled
}

local PLAYER = {
    actionControl = 0x000,
    slotReference = 0x06C,
    airborneState = 0x070,
    animationId = 0x164,
    secondaryAnimationId = 0x168,
    animationTime = 0x16C,
}

local BUTTON = {
    L2 = 0x01,
    CIRCLE = 0x20,
    CROSS = 0x40,
    SQUARE = 0x80,
    TRIANGLE = 0x10,
}

-- These are deliberately conservative first-pass windows, measured in the
-- game's animation-time units. They are configuration data to tune from logs.
local CANCEL_WINDOW = {
    [0xC8] = 18.0, -- basic ground combo A1
    [0xC9] = 18.0, -- ground combo continuation/context
    [0xCA] = 20.0, -- basic ground combo A2/context
    [0xCC] = 12.0, -- air combo 1
    [0xCD] = 14.0, -- air combo 2
    [0xCF] = 18.0, -- Slapshot
    [0xD0] = 18.0, -- Sliding Dash family
    [0xD2] = 18.0, -- Cleave family
    [0xD3] = 18.0, -- Impulse family
}

local NORMAL = {
    forceCircle = 0x74,
    forceSquare = 0x84,
    airDefense = 0x85,
    guardAvailability = 0x74,
    guardSelection = 0x74,
    dodgeAvailability = 0x84,
    circleControlMap = 0xFF,
    squareControlMap = 0xFF,
}

local canRun = false
local faulted = false
local lastButtons = 0
local attackBufferFrames = 0
local attackBufferDelayFrames = 0
local attackBufferAnimation = nil
local attackBufferTime = 0.0
local attackBufferWasAirborne = false
local attackBufferComboPosition = nil
local finisherBufferFrames = 0
local groundChainFrames = 0
local forceCircleFrames = 0
local forceSquareFrames = 0
local forceGuardFrames = 0
local comboWarningShown = false
local transitionCheckFrames = 0
local transitionSourceAnimation = nil
local transitionSourceTime = 0.0
local transitionKind = nil
local deferredLinkMinimumFrames = 0
local deferredLinkTimeoutFrames = 0
local deferredLinkKind = nil
local deferredLinkComboPosition = nil
local deferredLinkSourceAnimation = nil
local deferredLinkSourceTime = 0.0
local deferredLinkWasAirborne = false

local function log(message)
    if CONFIG.debugLog then ConsolePrint("[JokCombat] " .. message) end
end

local function isPlausiblePointer(value)
    return value >= 0x10000 and value <= 0x00007FFFFFFFFFFF
end

local function isKnown(value, choices)
    for _, choice in ipairs(choices) do
        if value == choice then return true end
    end
    return false
end

local function normalizeByte(name, address, normal, known)
    local current = ReadByte(address)
    if not isKnown(current, known) then
        ConsolePrint(string.format(
            "[JokCombat:fault] %s RVA=0x%X has unexpected byte 0x%02X; disabled.",
            name, address, current))
        return false
    end
    if current ~= normal then WriteByte(address, normal) end
    return true
end

local function setByte(name, address, desired, allowed)
    if faulted then return false end
    local current = ReadByte(address)
    if not isKnown(current, allowed) then
        faulted = true
        ConsolePrint(string.format(
            "[JokCombat:fault] %s changed unexpectedly at RVA=0x%X "
            .. "(0x%02X); temporary patches stopped.",
            name, address, current))
        return false
    end
    if current ~= desired then WriteByte(address, desired) end
    return true
end

local function restoreIfKnown(address, normal, known)
    local current = ReadByte(address)
    if isKnown(current, known) and current ~= normal then
        WriteByte(address, normal)
    end
end

local function restoreAllPatches()
    restoreIfKnown(ADDRESS.forceCircleBranch, NORMAL.forceCircle,
        { 0x74, 0x72 })
    restoreIfKnown(ADDRESS.forceSquareBranch, NORMAL.forceSquare,
        { 0x84, 0x82 })
    restoreIfKnown(ADDRESS.airDefenseBranch, NORMAL.airDefense,
        { 0x85, 0x82 })
    restoreIfKnown(ADDRESS.guardAvailabilityBranch,
        NORMAL.guardAvailability, { 0x74, 0x72, 0xEB })
    restoreIfKnown(ADDRESS.guardSelectionBranch, NORMAL.guardSelection,
        { 0x74, 0xEB })
    restoreIfKnown(ADDRESS.dodgeAvailabilityBranch,
        NORMAL.dodgeAvailability, { 0x84, 0x82 })
    restoreIfKnown(ADDRESS.circleControlMap, NORMAL.circleControlMap,
        { 0xFF, 0x07, 0xFE })
    restoreIfKnown(ADDRESS.squareControlMap, NORMAL.squareControlMap,
        { 0xFF, 0x05, 0xFE })
end

local function readPlayer()
    local pointer = ReadLong(ADDRESS.playerPointer)
    if not isPlausiblePointer(pointer) then return nil end

    local slot = ReadShort(pointer + PLAYER.slotReference, true)
    local animationTime = ReadFloat(pointer + PLAYER.animationTime, true)
    if slot < 0x8000 or slot > 0xFFFF then return nil end
    if animationTime ~= animationTime or math.abs(animationTime) > 100000 then
        return nil
    end

    return {
        pointer = pointer,
        control = ReadByte(pointer + PLAYER.actionControl, true),
        airborne = ReadInt(pointer + PLAYER.airborneState, true) ~= 0,
        animation = ReadByte(pointer + PLAYER.animationId, true),
        secondary = ReadByte(pointer + PLAYER.secondaryAnimationId, true),
        time = animationTime,
    }
end

local function isAttackContext(player)
    local start = CANCEL_WINDOW[player.animation]
    if start == nil then return false end

    -- C8-CA with a low secondary ID are also reused by limit contexts.
    if player.animation >= 0xC8 and player.animation <= 0xCA
        and player.secondary <= 0x02 then
        return false
    end
    return true
end

local function isCancelableAttack(player)
    return isAttackContext(player)
        and player.time >= CANCEL_WINDOW[player.animation]
end

local function pressStarted(buttons, mask)
    return (buttons & mask) ~= 0 and (lastButtons & mask) == 0
end

local function chordStarted(buttons, first, second)
    local chordHeld = (buttons & first) ~= 0 and (buttons & second) ~= 0
    local chordWasHeld = (lastButtons & first) ~= 0
        and (lastButtons & second) ~= 0
    return chordHeld and not chordWasHeld
end

local function triggerAttackCommand()
    if ReadByte(ADDRESS.commandMenuSlot) ~= 0 then return false end
    WriteInt(ADDRESS.triggerMenu1, 1)
    WriteInt(ADDRESS.triggerMenu2, 1)
    return true
end

local function clearAttackBuffer()
    attackBufferFrames = 0
    attackBufferDelayFrames = 0
    attackBufferAnimation = nil
    attackBufferTime = 0.0
    attackBufferComboPosition = nil
end

local function clearFinisherBuffer()
    finisherBufferFrames = 0
end

local function clearTransitionCheck()
    transitionCheckFrames = 0
    transitionSourceAnimation = nil
    transitionSourceTime = 0.0
    transitionKind = nil
end

local function armTransitionCheck(player, kind)
    transitionCheckFrames = CONFIG.transitionCheckFrames
    transitionSourceAnimation = player.animation
    transitionSourceTime = player.time
    transitionKind = kind
end

local function clearDeferredAttackCommand()
    deferredLinkMinimumFrames = 0
    deferredLinkTimeoutFrames = 0
    deferredLinkKind = nil
    deferredLinkComboPosition = nil
    deferredLinkSourceAnimation = nil
    deferredLinkSourceTime = 0.0
    deferredLinkWasAirborne = false
end

local function queueAttackAfterRelease(player, kind, comboPosition)
    if ReadByte(ADDRESS.commandMenuSlot) ~= 0 then return false end

    -- Steam processes the action release before it can accept a replacement
    -- Attack command. v0.2.1 sent both in one frame, so the command was lost and
    -- Sora fell back to locomotion. Keep the two phases independent.
    clearTransitionCheck()
    deferredLinkMinimumFrames = CONFIG.releasedCommandMinimumFrames
    deferredLinkTimeoutFrames = CONFIG.releasedCommandTimeoutFrames
    deferredLinkKind = kind
    deferredLinkComboPosition = comboPosition
    deferredLinkSourceAnimation = player.animation
    deferredLinkSourceTime = player.time
    deferredLinkWasAirborne = player.airborne
    WriteByte(player.pointer + PLAYER.actionControl, 0x03, true)
    log(string.format(
        "%s link release issued: anim=0x%02X time=%.2f",
        kind, player.animation, player.time))
    return true
end

local function updateDeferredAttackCommand(player)
    if deferredLinkKind == nil then return false end

    if player.airborne ~= deferredLinkWasAirborne
        or ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        log(deferredLinkKind .. " deferred command cancelled by state change.")
        clearDeferredAttackCommand()
        return false
    end

    -- A held physical Cross may be accepted naturally after the release. If
    -- that happens, do not emit a second command for the same input.
    if deferredLinkKind == "normal" and isAttackContext(player)
        and (player.animation ~= deferredLinkSourceAnimation
            or player.time + 0.5 < deferredLinkSourceTime) then
        log(string.format(
            "normal transition observed during release: anim=0x%02X time=%.2f",
            player.animation, player.time))
        clearDeferredAttackCommand()
        return true
    end

    deferredLinkMinimumFrames = math.max(
        0, deferredLinkMinimumFrames - 1)
    deferredLinkTimeoutFrames = deferredLinkTimeoutFrames - 1

    -- actionControl=0x03 is the acknowledgement we need. If C8/CC is still
    -- visible on this next frame, issuing now preserves the native combo
    -- context; if the animation already reached neutral, the same command still
    -- starts an untargeted swing. Waiting for the animation to become idle would
    -- unnecessarily discard the combo context.
    local releaseAcknowledged = player.control == 0x03
    if deferredLinkMinimumFrames <= 0 and releaseAcknowledged then
        if deferredLinkComboPosition ~= nil then
            local maximum = ReadByte(ADDRESS.maxGroundComboLength)
            if maximum < 2 or maximum > 12
                or deferredLinkComboPosition > maximum then
                log(deferredLinkKind
                    .. " deferred command cancelled by combo sanity check.")
                clearDeferredAttackCommand()
                return false
            end
            -- The release may reset this byte. Reapply the chosen normal or
            -- finisher position immediately before the new Attack command.
            WriteByte(ADDRESS.comboPosition, deferredLinkComboPosition)
        end

        local kind = deferredLinkKind
        if triggerAttackCommand() then
            log(string.format(
                "target-free %s command issued after release: combo=%d",
                kind, ReadByte(ADDRESS.comboPosition)))
            armTransitionCheck(player, kind)
            clearDeferredAttackCommand()
            return true
        end
    end

    if deferredLinkTimeoutFrames <= 0 then
        log(deferredLinkKind
            .. " deferred command timed out before release acknowledgement.")
        clearDeferredAttackCommand()
    end
    return false
end

local function updateTransitionCheck(player)
    if transitionCheckFrames <= 0 or transitionKind == nil then return end

    local accepted = false
    if transitionKind == "finisher" then
        accepted = player.animation == 0xCB
    else
        accepted = isAttackContext(player)
            and (player.animation ~= transitionSourceAnimation
                or player.time + 0.5 < transitionSourceTime)
    end

    if accepted then
        log(string.format(
            "%s transition observed: anim=0x%02X time=%.2f",
            transitionKind, player.animation, player.time))
        clearTransitionCheck()
        return
    end

    transitionCheckFrames = transitionCheckFrames - 1
    if transitionCheckFrames <= 0 then
        log(string.format(
            "%s transition was not observed after the target-free request.",
            transitionKind))
        clearTransitionCheck()
    end
end

local function clearComboIntent()
    clearAttackBuffer()
    clearFinisherBuffer()
    groundChainFrames = 0
end

local function readGroundComboState()
    local position = ReadByte(ADDRESS.comboPosition)
    local maximum = ReadByte(ADDRESS.maxGroundComboLength)

    -- Vanilla values are small (3 in the current early-game test). Keep a
    -- generous upper bound for Combo Plus, but never write through an address
    -- that does not look like the expected pair of gameplay fields.
    if maximum < 2 or maximum > 12 or position > maximum + 2 then
        if not comboWarningShown then
            comboWarningShown = true
            ConsolePrint(string.format(
                "[JokCombat:combo] implausible state position=%d max=%d; "
                .. "combo routing skipped.", position, maximum))
        end
        return nil, nil
    end

    comboWarningShown = false
    return position, maximum
end

local function prepareNormalGroundAttack()
    local position, maximum = readGroundComboState()
    if position == nil then return false end

    -- The native engine selects the finisher when the incoming combo position
    -- reaches max-1. Cross wraps to the first normal instead, so every press is
    -- exactly one normal hit and the chain has no automatic end.
    if CONFIG.infiniteGroundNormals and position >= maximum - 1 then
        WriteByte(ADDRESS.comboPosition, 0)
        position = 0
    end
    return true, position, maximum
end

local function prepareGroundFinisher()
    local position, maximum = readGroundComboState()
    if position == nil then return false end

    local finisherPosition = maximum - 1
    if position ~= finisherPosition then
        WriteByte(ADDRESS.comboPosition, finisherPosition)
    end
    return true, finisherPosition, maximum
end

local function queueAttackBuffer(player)
    attackBufferFrames = CONFIG.attackBufferFrames
    attackBufferDelayFrames = CONFIG.attackBufferDelayFrames
    attackBufferAnimation = player.animation
    attackBufferTime = player.time
    attackBufferWasAirborne = player.airborne
    attackBufferComboPosition = ReadByte(ADDRESS.comboPosition)
end

local function updateAttackBuffer(player)
    if attackBufferFrames <= 0 or attackBufferAnimation == nil then return end

    if player.airborne ~= attackBufferWasAirborne then
        clearAttackBuffer()
        return
    end

    if attackBufferComboPosition ~= nil
        and ReadByte(ADDRESS.comboPosition) ~= attackBufferComboPosition then
        clearAttackBuffer()
        return
    end

    -- A changed attack ID, or the same ID restarting at time zero, means the
    -- game already consumed the physical press. Do not synthesize a duplicate.
    if isAttackContext(player) and (player.animation ~= attackBufferAnimation
        or player.time + 0.5 < attackBufferTime) then
        clearAttackBuffer()
        return
    end

    attackBufferFrames = attackBufferFrames - 1
    attackBufferDelayFrames = math.max(0, attackBufferDelayFrames - 1)
    if attackBufferFrames <= 0 then
        clearAttackBuffer()
        return
    end
    if attackBufferDelayFrames > 0 then return end

    local canLinkNow = isCancelableAttack(player)
    local returnedToNeutral = not isAttackContext(player)
        and player.control == 0x03 and player.animation <= 0x07
    if not canLinkNow and not returnedToNeutral then return end

    local desiredComboPosition = nil
    if not player.airborne then
        local prepared, position = prepareNormalGroundAttack()
        if not prepared then return end
        desiredComboPosition = position
    end

    if canLinkNow then
        if queueAttackAfterRelease(
            player, "normal", desiredComboPosition) then
            clearAttackBuffer()
        end
    elseif triggerAttackCommand() then
        log(string.format(
            "target-free normal command issued from neutral: combo=%d",
            ReadByte(ADDRESS.comboPosition)))
        armTransitionCheck(player, "normal")
        clearAttackBuffer()
    end
end

local function updateFinisherBuffer(player)
    if finisherBufferFrames <= 0 then return end

    finisherBufferFrames = finisherBufferFrames - 1
    if finisherBufferFrames <= 0 or player.airborne
        or groundChainFrames <= 0 then
        clearFinisherBuffer()
        return
    end

    -- A visible reaction command keeps vanilla Triangle priority and cancels
    -- the queued finisher, avoiding a delayed surprise attack afterward.
    if ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        clearFinisherBuffer()
        return
    end

    local canLinkNow = isCancelableAttack(player)
    local returnedToNeutral = not isAttackContext(player)
        and player.control == 0x03 and player.animation <= 0x07
    if not canLinkNow and not returnedToNeutral then return end
    local prepared, finisherPosition = prepareGroundFinisher()
    if not prepared then return end

    if canLinkNow then
        if queueAttackAfterRelease(
            player, "finisher", finisherPosition) then
            clearComboIntent()
        end
    elseif triggerAttackCommand() then
        log(string.format(
            "target-free finisher command issued from neutral: combo=%d max=%d",
            ReadByte(ADDRESS.comboPosition),
            ReadByte(ADDRESS.maxGroundComboLength)))
        armTransitionCheck(player, "finisher")
        clearComboIntent()
    end
end

local function cancelPlayer(player, label)
    WriteByte(player.pointer + PLAYER.actionControl, 0x03, true)
    log(string.format(
        "%s cancel: anim=0x%02X secondary=0x%02X time=%.2f",
        label, player.animation, player.secondary, player.time))
end

local function updateDefenseRouting(buttons, guardAvailable)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local circleHeld = (buttons & BUTTON.CIRCLE) ~= 0
    local squareHeld = (buttons & BUTTON.SQUARE) ~= 0
    local guardChord = l2Held and circleHeld

    local circleMap = NORMAL.circleControlMap
    local squareMap = NORMAL.squareControlMap
    if CONFIG.guardOnL2Circle and l2Held then
        -- The override table is action -> physical control. Disable the native
        -- Circle/jump action and source the virtual Square/defense action from
        -- physical Circle (control index 0x05).
        circleMap = 0xFE
        if circleHeld then
            squareMap = guardAvailable and 0x05 or 0xFE
        end
    end
    setByte("circleControlMap", ADDRESS.circleControlMap, circleMap,
        { 0xFF, 0x07, 0xFE })
    setByte("squareControlMap", ADDRESS.squareControlMap, squareMap,
        { 0xFF, 0x05, 0xFE })

    local selectGuard = (CONFIG.guardOnL2Circle and l2Held
        and not (squareHeld and not circleHeld)) or forceGuardFrames > 0
    setByte("guardSelection", ADDRESS.guardSelectionBranch,
        selectGuard and 0xEB or 0x74, { 0x74, 0xEB })

    -- Only Guard receives the airborne bypass. Square/Dodge keeps the normal
    -- ground restriction and its existing cancel windows.
    local allowAirGuard = CONFIG.universalGuardCancel
        and (guardChord or forceGuardFrames > 0)
    setByte("airDefense", ADDRESS.airDefenseBranch,
        allowAirGuard and 0x82 or 0x85, { 0x85, 0x82 })

    local guardAvailability = CONFIG.unlockDefensiveActions and 0x72 or 0x74
    -- Keep the roll route armed before the first Square frame. Previously it
    -- was selected only after Square was observed, so a stationary first press
    -- could already have entered Guard and a second press appeared to roll.
    if CONFIG.fixedDodgeOnSquare and forceGuardFrames == 0
        and (not l2Held or (squareHeld and not circleHeld)) then
        guardAvailability = 0xEB
    end
    setByte("guardAvailability", ADDRESS.guardAvailabilityBranch,
        guardAvailability, { 0x74, 0x72, 0xEB })

    -- Merely holding L2 must only pre-arm the Circle mapping. The defensive
    -- bypass itself is enabled after Circle/Square is physically present;
    -- enabling it on L2 alone caused the unwanted automatic Guard.
    if (CONFIG.guardOnL2Circle and guardChord)
        or (CONFIG.fixedDodgeOnSquare and squareHeld)
        or forceSquareFrames > 0 then
        setByte("forceSquare", ADDRESS.forceSquareBranch, 0x82,
            { 0x84, 0x82 })
    else
        setByte("forceSquare", ADDRESS.forceSquareBranch, 0x84,
            { 0x84, 0x82 })
    end
end

function _OnInit()
    canRun = false
    faulted = false
    lastButtons = 0
    clearComboIntent()
    clearTransitionCheck()
    clearDeferredAttackCommand()
    attackBufferWasAirborne = false
    forceCircleFrames = 0
    forceSquareFrames = 0
    forceGuardFrames = 0
    comboWarningShown = false

    if not CONFIG.enabled then
        ConsolePrint("JokCombat Combat Prototype is disabled in CONFIG.")
        return
    end
    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND"
        or ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        ConsolePrint("JokCombat Combat Prototype - unsupported game/build; disabled.")
        return
    end

    local valid = true
    valid = normalizeByte("forceCircle", ADDRESS.forceCircleBranch, 0x74,
        { 0x74, 0x72 }) and valid
    valid = normalizeByte("forceSquare", ADDRESS.forceSquareBranch, 0x84,
        { 0x84, 0x82 }) and valid
    valid = normalizeByte("airDefense", ADDRESS.airDefenseBranch, 0x85,
        { 0x85, 0x82 }) and valid
    valid = normalizeByte("guardAvailability", ADDRESS.guardAvailabilityBranch,
        0x74, { 0x74, 0x72, 0xEB }) and valid
    valid = normalizeByte("guardSelection", ADDRESS.guardSelectionBranch,
        0x74, { 0x74, 0xEB }) and valid
    valid = normalizeByte("dodgeAvailability", ADDRESS.dodgeAvailabilityBranch,
        0x84, { 0x84, 0x82 }) and valid
    valid = normalizeByte("circleControlMap", ADDRESS.circleControlMap,
        0xFF, { 0xFF, 0x07, 0xFE }) and valid
    valid = normalizeByte("squareControlMap", ADDRESS.squareControlMap,
        0xFF, { 0xFF, 0x05, 0xFE }) and valid
    if not valid then return end

    canRun = true
    ConsolePrint(
        "JokCombat Combat Prototype " .. VERSION
        .. " initialized (Steam GL; combat-only; experimental).")

    local position, maximum = readGroundComboState()
    if position ~= nil then
        log(string.format(
            "combo controller ready: position=%d maxGround=%d",
            position, maximum))
    end
end

function _OnFrame()
    if not canRun or faulted then return end

    local player = readPlayer()
    if player == nil then
        restoreAllPatches()
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        forceGuardFrames = 0
        lastButtons = 0
        return
    end

    local buttons = ReadByte(ADDRESS.rawButtons)
    local abilities = ReadInt(ADDRESS.defenseAbilityFlags)
    local guardAvailable = CONFIG.unlockDefensiveActions
        or (abilities & 0x10) ~= 0
    local dodgeAvailable = CONFIG.unlockDefensiveActions
        or (abilities & 0x20) ~= 0

    if CONFIG.unlockDefensiveActions then
        setByte("dodgeAvailability", ADDRESS.dodgeAvailabilityBranch,
            0x82, { 0x84, 0x82 })
    else
        setByte("dodgeAvailability", ADDRESS.dodgeAvailabilityBranch,
            0x84, { 0x84, 0x82 })
    end

    updateDefenseRouting(buttons, guardAvailable)
    if faulted then
        restoreAllPatches()
        return
    end

    updateTransitionCheck(player)
    local deferredHandledThisFrame = updateDeferredAttackCommand(player)

    local l2Held = (buttons & BUTTON.L2) ~= 0
    local circlePressed = pressStarted(buttons, BUTTON.CIRCLE)
    local crossPressed = pressStarted(buttons, BUTTON.CROSS)
    local squarePressed = pressStarted(buttons, BUTTON.SQUARE)
    local trianglePressed = pressStarted(buttons, BUTTON.TRIANGLE)
    local guardPressed = chordStarted(buttons, BUTTON.L2, BUTTON.CIRCLE)
    local cancelWindowOpen = isCancelableAttack(player)
    local actionConsumed = deferredHandledThisFrame
        or deferredLinkKind ~= nil
    local chainWasArmed = groundChainFrames > 0

    -- Guard is the sole universal cancel. It can break any current action and,
    -- through airDefenseBranch, is also allowed while Sora is airborne.
    if CONFIG.defensiveCancels and CONFIG.guardOnL2Circle and guardPressed
        and guardAvailable
        and (CONFIG.universalGuardCancel or cancelWindowOpen) then
        cancelPlayer(player, "guard-universal")
        forceSquareFrames = CONFIG.forcedInputFrames
        forceGuardFrames = CONFIG.forcedInputFrames
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        actionConsumed = true
    elseif circlePressed and not l2Held then
        -- A normal jump breaks the local ground chain. It only cancels an
        -- attack after the configured link window; it is not universal.
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        actionConsumed = true
        if CONFIG.groundToAirJumpBranch and not player.airborne
            and cancelWindowOpen then
            cancelPlayer(player, "jump")
            forceCircleFrames = CONFIG.forcedInputFrames
        end
    elseif CONFIG.fixedDodgeOnSquare and squarePressed and dodgeAvailable then
        -- Dodge keeps the conservative attack cancel window. From neutral the
        -- native Square route handles it without an action-control write.
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        actionConsumed = true
        if CONFIG.defensiveCancels and cancelWindowOpen then
            cancelPlayer(player, "dodge")
            forceSquareFrames = CONFIG.forcedInputFrames
        end
    end

    if not actionConsumed then
        if crossPressed and ReadByte(ADDRESS.commandMenuSlot) == 0 then
            clearFinisherBuffer()
            local comboPrepared = true
            if not player.airborne then
                local position, maximum
                comboPrepared, position, maximum = prepareNormalGroundAttack()
                if comboPrepared then
                    groundChainFrames = CONFIG.groundChainMemoryFrames
                    log(string.format(
                        "normal input accepted: combo=%d max=%d",
                        position, maximum))
                end
            end

            if CONFIG.attackBuffer and isAttackContext(player)
                and (player.airborne or comboPrepared) then
                queueAttackBuffer(player)
            end
        end

        if CONFIG.triangleGroundFinisher and trianglePressed
            and not player.airborne
            and ReadByte(ADDRESS.commandMenuSlot) == 0 then
            if chainWasArmed then
                clearAttackBuffer()
                finisherBufferFrames = CONFIG.attackBufferFrames
                log("Triangle finisher queued after a ground normal.")
            else
                log("Triangle finisher ignored: no preceding ground normal.")
            end
        end

        updateFinisherBuffer(player)
        if finisherBufferFrames <= 0 then
            updateAttackBuffer(player)
        end
    end

    setByte("forceCircle", ADDRESS.forceCircleBranch,
        forceCircleFrames > 0 and 0x72 or 0x74, { 0x74, 0x72 })
    forceCircleFrames = math.max(0, forceCircleFrames - 1)
    forceSquareFrames = math.max(0, forceSquareFrames - 1)
    forceGuardFrames = math.max(0, forceGuardFrames - 1)
    if player.airborne then
        groundChainFrames = 0
    else
        groundChainFrames = math.max(0, groundChainFrames - 1)
    end
    lastButtons = buttons
end

-- LuaBackend reloads call _OnInit(), which normalizes every known patch. This
-- hook additionally restores state on loaders that provide an exit callback.
function _OnExit()
    if canRun then restoreAllPatches() end
end
