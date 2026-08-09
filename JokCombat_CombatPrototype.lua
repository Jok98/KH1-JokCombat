LUAGUI_NAME = "JokCombat Combat Prototype"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra / KSX"
LUAGUI_DESC = "Cross-only combo, deterministic L2+Cross Stun Impact, universal Guard/Dodge cancels and jump branch."

-- JokCombat v0.2.10 prototype for the current Steam Global executable.
-- Critical Mix was used as an authorized technical reference. This script is
-- intentionally limited to combat/input state and does not touch save data,
-- story flags, rewards, inventory, AP, levels, worlds, chests, or synthesis.

local CONFIG = {
    enabled = true,
    debugLog = true,

    attackBuffer = true,
    crossGroundFinisher = true,
    -- Parked until the Steam Attack dispatcher has a validated force branch.
    -- Triangle remains completely native and never arms a delayed finisher.
    triangleGroundFinisher = false,
    groundToAirJumpBranch = true,
    defensiveCancels = true,
    universalGuardCancel = true,
    universalDodgeCancel = true,
    guardOnL2Circle = true,
    fixedDodgeOnSquare = true,
    stunImpactOnL2Cross = true,

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
    releasedCommandTimeoutFrames = 60,
    -- A real pulse alternates a short high level with a one-frame low gap.
    -- v0.2.4 kept writing 1, so a rejected request could remain high forever
    -- without producing a new edge in the Steam dispatcher.
    attackPulseHighFrames = 2,
    attackPulseLowFrames = 1,
    groundRouteFrames = 104,
    transitionCheckFrames = 96,
    stunImpactRequestFrames = 120,
    forcedInputFrames = 4,
}

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local VERSION = "v0.2.10"

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

    -- Current Steam ports of the Sora ground-action table entries used by
    -- Critical Mix's routed attack experiments. The +0x3980 data shift and
    -- every vanilla byte below were confirmed through a live read-only scan.
    groundFinisherDefault = 0x2D2D7D0,
    groundComboSlide = 0x2D2D7E4,
    groundComboImpulse = 0x2D2D7F8,
    groundCombo2 = 0x2D2D80C,
    groundComboSlapshot = 0x2D2D820,
    groundComboA1 = 0x2D2D834,
    groundComboA2 = 0x2D2D848,

    circleControlMap = 0x22C9345,
    attackControlMap = 0x22C9346,
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

-- The control-map table is action -> physical control. Its indices follow the
-- face-button order used by Critical Mix: Triangle=04, Circle=05, Cross=06,
-- Square=07. Only the Attack action is temporarily sourced from Triangle.
local CONTROL_INDEX = {
    TRIANGLE = 0x04,
}

local DODGE_ROLL_ANIMATION = 0xDC
local STUN_IMPACT_ANIMATION = 0xD8
local STUN_IMPACT_KIND = "stun-impact"
local STUN_IMPACT_PRIME_KIND = "stun-impact-prime"

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

-- Cross cycles the complete ground string. CB deliberately remains outside
-- isGroundNormalContext so the finisher ends the chain instead of linking back
-- into another attack before Sora returns to neutral.
local GROUND_NORMAL_SEQUENCE = { 0xC8, 0xC9, 0xCA }
local GROUND_CROSS_SEQUENCE = { 0xC8, 0xC9, 0xCA, 0xCB }

local GROUND_ACTION_ROUTE = {
    { name = "groundFinisherDefault", address = ADDRESS.groundFinisherDefault,
        normal = 0xCB },
    { name = "groundComboSlide", address = ADDRESS.groundComboSlide,
        normal = 0xD0 },
    { name = "groundComboImpulse", address = ADDRESS.groundComboImpulse,
        normal = 0xD3 },
    { name = "groundCombo2", address = ADDRESS.groundCombo2,
        normal = 0xC9 },
    { name = "groundComboSlapshot", address = ADDRESS.groundComboSlapshot,
        normal = 0xCF },
    { name = "groundComboA1", address = ADDRESS.groundComboA1,
        normal = 0xC8 },
    { name = "groundComboA2", address = ADDRESS.groundComboA2,
        normal = 0xCA },
}

local NORMAL = {
    forceCircle = 0x74,
    forceSquare = 0x84,
    airDefense = 0x85,
    guardAvailability = 0x74,
    guardSelection = 0x74,
    dodgeAvailability = 0x84,
    circleControlMap = 0xFF,
    attackControlMap = 0xFF,
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
local attackBufferExpectedAnimation = nil
local finisherBufferFrames = 0
local groundChainFrames = 0
local forceCircleFrames = 0
local forceSquareFrames = 0
local forceGuardFrames = 0
local forceTriangleAttackFrames = 0
local comboWarningShown = false
local transitionCheckFrames = 0
local transitionSourceAnimation = nil
local transitionSourceTime = 0.0
local transitionKind = nil
local transitionExpectedAnimation = nil
local transitionExpectedComboPosition = nil
local transitionWasAirborne = false
local transitionPulseCount = 0
local transitionPulsePhaseFrames = 0
local transitionUsesPhysicalInput = false
local deferredLinkMinimumFrames = 0
local deferredLinkTimeoutFrames = 0
local deferredLinkKind = nil
local deferredLinkComboPosition = nil
local deferredLinkSourceAnimation = nil
local deferredLinkSourceTime = 0.0
local deferredLinkWasAirborne = false
local deferredLinkExpectedAnimation = nil
local groundRouteAvailable = false
local groundRouteFrames = 0
local groundRouteAnimation = nil
local groundRouteKind = nil
local groundRouteSourceAnimation = nil
local groundRouteSourceTime = 0.0
local syntheticAttackCommandOwned = false
local syntheticAttackCommandHigh = false
local queuedNormalInput = false

local function log(message)
    if CONFIG.debugLog then ConsolePrint("[JokCombat] " .. message) end
end

local function lowerSyntheticAttackCommand()
    if syntheticAttackCommandOwned or syntheticAttackCommandHigh then
        WriteInt(ADDRESS.triggerMenu1, 0)
        WriteInt(ADDRESS.triggerMenu2, 0)
    end
    syntheticAttackCommandHigh = false
end

local function clearSyntheticAttackCommand(forceWrite)
    if forceWrite or syntheticAttackCommandOwned
        or syntheticAttackCommandHigh then
        WriteInt(ADDRESS.triggerMenu1, 0)
        WriteInt(ADDRESS.triggerMenu2, 0)
    end
    syntheticAttackCommandOwned = false
    syntheticAttackCommandHigh = false
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

local function isGroundRouteValue(value, normal)
    return value == normal or value == 0xC8 or value == 0xC9
        or value == 0xCA or value == 0xCB
        or value == STUN_IMPACT_ANIMATION
end

local function restoreGroundActionRoute()
    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        local current = ReadByte(entry.address)
        if isGroundRouteValue(current, entry.normal)
            and current ~= entry.normal then
            WriteByte(entry.address, entry.normal)
        end
    end
    groundRouteFrames = 0
    groundRouteAnimation = nil
    groundRouteKind = nil
    groundRouteSourceAnimation = nil
    groundRouteSourceTime = 0.0
end

local function normalizeGroundActionRoute()
    local valid = true
    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        local current = ReadByte(entry.address)
        if not isGroundRouteValue(current, entry.normal) then
            ConsolePrint(string.format(
                "[JokCombat:route] %s RVA=0x%X has unexpected byte 0x%02X; "
                .. "forced ground routing disabled.",
                entry.name, entry.address, current))
            valid = false
        elseif current ~= entry.normal then
            -- Clean up a route left active by a reload during its short window.
            WriteByte(entry.address, entry.normal)
        end
    end
    groundRouteFrames = 0
    groundRouteAnimation = nil
    groundRouteKind = nil
    groundRouteSourceAnimation = nil
    groundRouteSourceTime = 0.0
    groundRouteAvailable = valid
    return valid
end

local function beginGroundActionRoute(kind, desiredAnimation, player)
    if not groundRouteAvailable or desiredAnimation == nil then return false end

    restoreGroundActionRoute()
    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        local current = ReadByte(entry.address)
        if current ~= entry.normal then
            ConsolePrint(string.format(
                "[JokCombat:route] %s changed to 0x%02X before routing; "
                .. "forced ground routing disabled.", entry.name, current))
            groundRouteAvailable = false
            restoreGroundActionRoute()
            return false
        end
    end

    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        if entry.normal ~= desiredAnimation then
            WriteByte(entry.address, desiredAnimation)
        end
    end
    groundRouteFrames = CONFIG.groundRouteFrames
    groundRouteAnimation = desiredAnimation
    groundRouteKind = kind
    groundRouteSourceAnimation = player.animation
    groundRouteSourceTime = player.time
    log(string.format(
        "%s route armed: all ground entries -> 0x%02X",
        kind, desiredAnimation))
    return true
end

local function updateGroundActionRoute(player)
    if groundRouteFrames <= 0 or groundRouteAnimation == nil then return false end

    local accepted = player.animation == groundRouteAnimation
        and (player.animation ~= groundRouteSourceAnimation
            or player.time + 0.5 < groundRouteSourceTime)
    if accepted then
        log(string.format(
            "%s route accepted: anim=0x%02X time=%.2f",
            groundRouteKind, player.animation, player.time))
        restoreGroundActionRoute()
        return true
    end

    groundRouteFrames = groundRouteFrames - 1
    if groundRouteFrames <= 0 then
        log(string.format(
            "%s route timed out before anim=0x%02X was observed.",
            groundRouteKind, groundRouteAnimation))
        restoreGroundActionRoute()
    end
    return false
end

local function restoreAllPatches()
    clearSyntheticAttackCommand(false)
    restoreGroundActionRoute()
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
    restoreIfKnown(ADDRESS.attackControlMap, NORMAL.attackControlMap,
        { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
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

local function isGroundNormalContext(player)
    if player.airborne or not isAttackContext(player) then return false end
    for _, animation in ipairs(GROUND_NORMAL_SEQUENCE) do
        if player.animation == animation then return true end
    end
    return false
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
    syntheticAttackCommandOwned = true
    syntheticAttackCommandHigh = true
    return true
end

local function clearAttackBuffer()
    attackBufferFrames = 0
    attackBufferDelayFrames = 0
    attackBufferAnimation = nil
    attackBufferTime = 0.0
    attackBufferComboPosition = nil
    attackBufferExpectedAnimation = nil
end

local function clearFinisherBuffer()
    finisherBufferFrames = 0
end

local function clearTransitionCheck()
    -- A transition owns any temporary ground route for its whole retry window.
    -- Restoring here also makes Guard, Dodge, jump and reload cancellation safe.
    local restorePhysicalAttackMap = transitionUsesPhysicalInput
    if canRun then restoreGroundActionRoute() end
    clearSyntheticAttackCommand(false)
    transitionCheckFrames = 0
    transitionSourceAnimation = nil
    transitionSourceTime = 0.0
    transitionKind = nil
    transitionExpectedAnimation = nil
    transitionExpectedComboPosition = nil
    transitionWasAirborne = false
    transitionPulseCount = 0
    transitionPulsePhaseFrames = 0
    transitionUsesPhysicalInput = false
    if restorePhysicalAttackMap then
        forceTriangleAttackFrames = 0
        restoreIfKnown(ADDRESS.attackControlMap, NORMAL.attackControlMap,
            { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
    end
end

local function linkMatchesExpectation(player, kind, expectedAnimation,
        sourceAnimation, sourceTime)
    if kind == "finisher" then return player.animation == 0xCB end

    if expectedAnimation ~= nil then
        return player.animation == expectedAnimation
            and (player.animation ~= sourceAnimation
                or player.time + 0.5 < sourceTime)
    end

    return isAttackContext(player)
        and (player.animation ~= sourceAnimation
            or player.time + 0.5 < sourceTime)
end

local function usesFinisherComboPosition(kind, expectedAnimation)
    return kind == "finisher" or kind == STUN_IMPACT_KIND
        or expectedAnimation == 0xCB
        or expectedAnimation == STUN_IMPACT_ANIMATION
end

local function armTransitionCheck(player, kind, expectedAnimation,
        comboPosition, usesPhysicalInput)
    -- Always create a low frame before the first high edge. This also cleans a
    -- stale level left by an earlier rejected request or a script reload.
    clearSyntheticAttackCommand(true)
    transitionCheckFrames = CONFIG.transitionCheckFrames
    transitionSourceAnimation = player.animation
    transitionSourceTime = player.time
    transitionKind = kind
    transitionExpectedAnimation = expectedAnimation
    transitionExpectedComboPosition = comboPosition
    transitionWasAirborne = player.airborne
    transitionPulseCount = 0
    transitionPulsePhaseFrames = CONFIG.attackPulseLowFrames
    transitionUsesPhysicalInput = usesPhysicalInput == true
end

local function clearDeferredAttackCommand()
    deferredLinkMinimumFrames = 0
    deferredLinkTimeoutFrames = 0
    deferredLinkKind = nil
    deferredLinkComboPosition = nil
    deferredLinkSourceAnimation = nil
    deferredLinkSourceTime = 0.0
    deferredLinkWasAirborne = false
    deferredLinkExpectedAnimation = nil
end

local function queueAttackAfterRelease(player, kind, comboPosition,
        expectedAnimation)
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
    deferredLinkExpectedAnimation = expectedAnimation
    WriteByte(player.pointer + PLAYER.actionControl, 0x03, true)
    log(string.format(
        "%s link release issued: anim=0x%02X time=%.2f",
        kind, player.animation, player.time))
    return true
end

local function updateDeferredAttackCommand(player)
    if deferredLinkKind == nil then return false, nil end

    if player.airborne ~= deferredLinkWasAirborne
        or ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        log(deferredLinkKind .. " deferred command cancelled by state change.")
        queuedNormalInput = false
        clearDeferredAttackCommand()
        return false, nil
    end

    -- A held physical Cross may be accepted naturally after the release. If
    -- that happens, do not emit a second command for the same input.
    if deferredLinkKind == "normal" and linkMatchesExpectation(
            player, deferredLinkKind, deferredLinkExpectedAnimation,
            deferredLinkSourceAnimation, deferredLinkSourceTime) then
        log(string.format(
            "normal transition observed during release: anim=0x%02X time=%.2f",
            player.animation, player.time))
        clearDeferredAttackCommand()
        return true, "normal"
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
            local maximumRequest = maximum
            if usesFinisherComboPosition(
                    deferredLinkKind, deferredLinkExpectedAnimation) then
                maximumRequest = maximum + 1
            end
            if maximum < 2 or maximum > 12
                or deferredLinkComboPosition > maximumRequest then
                log(deferredLinkKind
                    .. " deferred command cancelled by combo sanity check.")
                queuedNormalInput = false
                clearDeferredAttackCommand()
                return false, nil
            end
            -- The release may reset this byte. Reapply the chosen normal or
            -- finisher position immediately before the new Attack command.
            WriteByte(ADDRESS.comboPosition, deferredLinkComboPosition)
        end

        local kind = deferredLinkKind
        local expectedAnimation = deferredLinkExpectedAnimation
        local desiredComboPosition = deferredLinkComboPosition
        local routeArmed = false
        if expectedAnimation ~= nil and not player.airborne then
            routeArmed = beginGroundActionRoute(
                kind, expectedAnimation, player)
        end
        armTransitionCheck(
            player, kind, expectedAnimation, desiredComboPosition)
        if expectedAnimation ~= nil then
            log(string.format(
                "target-free %s pulse armed after release: "
                .. "combo=%d expected=0x%02X route=%s",
                kind, ReadByte(ADDRESS.comboPosition), expectedAnimation,
                tostring(routeArmed)))
        else
            log(string.format(
                "target-free %s pulse armed after release: combo=%d",
                kind, ReadByte(ADDRESS.comboPosition)))
        end
        clearDeferredAttackCommand()
        return true, nil
    end

    if deferredLinkTimeoutFrames <= 0 then
        log(deferredLinkKind
            .. " deferred command timed out before release acknowledgement.")
        queuedNormalInput = false
        clearDeferredAttackCommand()
    end
    return false, nil
end

local function updateTransitionCheck(player)
    if transitionCheckFrames <= 0 or transitionKind == nil then return nil end

    if player.airborne ~= transitionWasAirborne
        or ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        log(transitionKind .. " persistent command cancelled by state change.")
        queuedNormalInput = false
        clearTransitionCheck()
        return nil
    end

    local accepted = linkMatchesExpectation(
        player, transitionKind, transitionExpectedAnimation,
        transitionSourceAnimation, transitionSourceTime)

    if accepted then
        local acceptedKind = transitionKind
        if transitionExpectedAnimation ~= nil then
            log(string.format(
                "%s transition observed: anim=0x%02X time=%.2f combo=%d",
                transitionKind, player.animation, player.time,
                ReadByte(ADDRESS.comboPosition)))
        else
            log(string.format(
                "%s transition observed: anim=0x%02X time=%.2f",
                transitionKind, player.animation, player.time))
        end
        log(string.format("%s command accepted after %d pulse(s).",
            transitionKind, transitionPulseCount))
        clearTransitionCheck()
        return acceptedKind
    end

    transitionCheckFrames = transitionCheckFrames - 1
    if transitionCheckFrames <= 0 then
        if transitionUsesPhysicalInput then
            log(string.format(
                "%s physical input was not accepted: expected=0x%02X "
                .. "desiredCombo=%d actualCombo=%d.",
                transitionKind, transitionExpectedAnimation or -1,
                transitionExpectedComboPosition or -1,
                ReadByte(ADDRESS.comboPosition)))
        elseif transitionExpectedAnimation ~= nil then
            log(string.format(
                "%s transition was not observed: expected=0x%02X "
                .. "desiredCombo=%d actualCombo=%d pulses=%d.",
                transitionKind, transitionExpectedAnimation,
                transitionExpectedComboPosition or -1,
                ReadByte(ADDRESS.comboPosition), transitionPulseCount))
        else
            log(string.format(
                "%s transition was not observed after %d target-free pulses.",
                transitionKind, transitionPulseCount))
        end
        queuedNormalInput = false
        clearTransitionCheck()
        return nil
    end

    -- Reapply the transient combo slot because the engine may reset it between
    -- the release and the frame in which it polls Attack. Only pulse while the
    -- released action-control state is acknowledged; once control changes, we
    -- wait for the matching animation instead of risking a duplicate attack.
    if transitionExpectedComboPosition ~= nil then
        local maximum = ReadByte(ADDRESS.maxGroundComboLength)
        local maximumRequest = maximum
        if usesFinisherComboPosition(
                transitionKind, transitionExpectedAnimation) then
            maximumRequest = maximum + 1
        end
        if maximum < 2 or maximum > 12
            or transitionExpectedComboPosition > maximumRequest then
            log(transitionKind
                .. " persistent command cancelled by combo sanity check.")
            queuedNormalInput = false
            clearTransitionCheck()
            return nil
        end
        WriteByte(ADDRESS.comboPosition, transitionExpectedComboPosition)
    end

    -- A direct request that already owns a physical Attack edge only needs the
    -- transition monitor. Triangle's parked path sources that edge from its
    -- control mapping; Stun Impact uses a pre-armed physical Cross. Neither
    -- path may also pulse the command-menu integers, or the request can replay.
    if transitionUsesPhysicalInput then return nil end

    -- v0.2.4 repeatedly wrote 1, leaving both trigger integers high after a
    -- rejected command. Alternate a bounded high phase with an explicit low
    -- gap so every retry produces a real 0 -> 1 edge. If action control changes
    -- first, lower the flags immediately and only observe the transition.
    if player.control ~= 0x03 then
        lowerSyntheticAttackCommand()
        transitionPulsePhaseFrames = CONFIG.attackPulseLowFrames
        return nil
    end

    transitionPulsePhaseFrames = math.max(
        0, transitionPulsePhaseFrames - 1)
    if syntheticAttackCommandHigh then
        if transitionPulsePhaseFrames <= 0 then
            lowerSyntheticAttackCommand()
            transitionPulsePhaseFrames = CONFIG.attackPulseLowFrames
        end
    elseif transitionPulsePhaseFrames <= 0 and triggerAttackCommand() then
        transitionPulseCount = transitionPulseCount + 1
        transitionPulsePhaseFrames = CONFIG.attackPulseHighFrames
    end
    return nil
end

local function clearComboIntent()
    clearAttackBuffer()
    clearFinisherBuffer()
    groundChainFrames = 0
    queuedNormalInput = false
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

local function nextGroundCrossAnimation(player, chainOpen)
    if not chainOpen or player.airborne or not isAttackContext(player) then
        return GROUND_NORMAL_SEQUENCE[1]
    end

    local sequence = CONFIG.crossGroundFinisher
        and GROUND_CROSS_SEQUENCE or GROUND_NORMAL_SEQUENCE
    for index, animation in ipairs(sequence) do
        if player.animation == animation then
            return sequence[(index % #sequence) + 1]
        end
    end
    return GROUND_NORMAL_SEQUENCE[1]
end

local function prepareNormalGroundAttack(player, chainOpen)
    local position, maximum = readGroundComboState()
    if position == nil then return false end

    local desiredAnimation = nextGroundCrossAnimation(player, chainOpen)
    local desiredPosition = 1
    if desiredAnimation == 0xCB then
        -- A real Cross edge now owns the finisher request. max+1 selects CB;
        -- no Triangle mapping or latent command-menu pulse is involved.
        desiredPosition = maximum + 1
    elseif desiredAnimation ~= GROUND_NORMAL_SEQUENCE[1] then
        -- Keep every Cross request below the native finisher position. C9 and
        -- CA are routed explicitly, so they can share the last normal counter.
        desiredPosition = math.max(1, maximum - 1)
    end

    if position ~= desiredPosition then
        WriteByte(ADDRESS.comboPosition, desiredPosition)
    end
    return true, desiredPosition, maximum, desiredAnimation
end

local function prepareGroundFinisher()
    local position, maximum = readGroundComboState()
    if position == nil then return false end

    -- Dormant while triangleGroundFinisher=false. Kept only as a parked
    -- research path until a native Steam Attack-force branch is validated.
    local finisherPosition = maximum + 1
    if position ~= finisherPosition then
        WriteByte(ADDRESS.comboPosition, finisherPosition)
    end
    return true, finisherPosition, maximum
end

local function requestStunImpact(player)
    if player.airborne then return false end

    if player.animation == STUN_IMPACT_ANIMATION then
        -- Close the accepted request immediately if a second chord arrives on
        -- D8. Restoring the table here prevents that same Cross from routing a
        -- second Stun Impact while the first one is still active.
        if transitionKind == STUN_IMPACT_KIND then
            clearTransitionCheck()
        elseif groundRouteKind == STUN_IMPACT_KIND
            or groundRouteKind == STUN_IMPACT_PRIME_KIND then
            restoreGroundActionRoute()
        end
        log("Stun Impact input ignored: Stun Impact is already active.")
        return true
    end

    if transitionKind == STUN_IMPACT_KIND
        or groundRouteKind == STUN_IMPACT_KIND then
        log("Stun Impact input ignored: request already pending.")
        return true
    end

    local position, maximum = readGroundComboState()
    if position == nil then
        log("Stun Impact request ignored: combo state is unavailable.")
        return true
    end

    local routeWasPrimed = groundRouteKind == STUN_IMPACT_PRIME_KIND
        and groundRouteAnimation == STUN_IMPACT_ANIMATION
    if not routeWasPrimed then
        -- LuaBackend observes a new Cross after the native dispatcher has
        -- already selected its action. Never append D8 to that already-chosen
        -- C8: require L2 to have primed the table on an earlier frame instead.
        log("Stun Impact input ignored: hold L2 before pressing Cross.")
        return true
    end

    -- The chord owns the current attack intent. It does not globally change
    -- Stun Impact's vanilla 30 percent selector: the table was routed to D8 on
    -- an earlier L2-only frame, before this physical Cross reached the native
    -- dispatcher. Promote that bounded prime into the observed request without
    -- restoring the table between the two phases.
    clearComboIntent()
    clearDeferredAttackCommand()
    groundRouteKind = STUN_IMPACT_KIND
    groundRouteSourceAnimation = player.animation
    groundRouteSourceTime = player.time

    local finisherPosition = maximum + 1
    WriteByte(ADDRESS.comboPosition, finisherPosition)
    groundRouteFrames = math.max(
        groundRouteFrames, CONFIG.stunImpactRequestFrames)
    armTransitionCheck(player, STUN_IMPACT_KIND,
        STUN_IMPACT_ANIMATION, finisherPosition, true)
    transitionCheckFrames = math.max(
        transitionCheckFrames, CONFIG.stunImpactRequestFrames)
    log(string.format(
        "Stun Impact requested by L2+Cross: combo=%d max=%d route=prearmed",
        finisherPosition, maximum))
    return true
end

local function updateStunImpactPrime(player, buttons)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local crossHeld = (buttons & BUTTON.CROSS) ~= 0
    local circleHeld = (buttons & BUTTON.CIRCLE) ~= 0
    local squareHeld = (buttons & BUTTON.SQUARE) ~= 0
    local canStayPrimed = CONFIG.stunImpactOnL2Cross
        and l2Held and not player.airborne
        and player.animation ~= STUN_IMPACT_ANIMATION
        and ReadByte(ADDRESS.commandMenuSlot) == 0
        and not circleHeld and not squareHeld

    if groundRouteKind == STUN_IMPACT_PRIME_KIND then
        if not canStayPrimed or transitionKind ~= nil
            or deferredLinkKind ~= nil then
            restoreGroundActionRoute()
            log("Stun Impact L2 prime cancelled by state change.")
            return false
        end
        groundRouteFrames = math.max(
            groundRouteFrames, CONFIG.stunImpactRequestFrames)
        return true
    end

    -- A route created on the same frame as Cross is too late: C8 has already
    -- been selected. Initial priming therefore requires an L2-only frame. This
    -- also prevents pressing L2 while Cross is already held from converting a
    -- vanilla attack into a delayed special.
    if not canStayPrimed or crossHeld
        or transitionKind ~= nil or deferredLinkKind ~= nil
        or groundRouteKind ~= nil then
        return false
    end

    local routeArmed = beginGroundActionRoute(
        STUN_IMPACT_PRIME_KIND, STUN_IMPACT_ANIMATION, player)
    if routeArmed then
        groundRouteFrames = math.max(
            groundRouteFrames, CONFIG.stunImpactRequestFrames)
        log("Stun Impact route primed by L2; waiting for Cross.")
    end
    return routeArmed
end

local function queueAttackBuffer(player, comboPosition, expectedAnimation)
    attackBufferFrames = CONFIG.attackBufferFrames
    attackBufferDelayFrames = CONFIG.attackBufferDelayFrames
    attackBufferAnimation = player.animation
    attackBufferTime = player.time
    attackBufferWasAirborne = player.airborne
    attackBufferComboPosition = comboPosition
    attackBufferExpectedAnimation = expectedAnimation
end

local function updateAttackBuffer(player)
    if attackBufferFrames <= 0 or attackBufferAnimation == nil then return end

    if player.airborne ~= attackBufferWasAirborne then
        clearAttackBuffer()
        return
    end

    -- The engine may rewrite comboPosition while the current animation is
    -- still active. Keep the buffered intent and reapply its desired value at
    -- command time; animation state, not this transient byte, decides whether
    -- the physical press was already consumed.

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

    local desiredComboPosition = attackBufferComboPosition
    local expectedAnimation = attackBufferExpectedAnimation

    if canLinkNow then
        if queueAttackAfterRelease(
            player, "normal", desiredComboPosition, expectedAnimation) then
            clearAttackBuffer()
        end
    else
        if desiredComboPosition ~= nil then
            WriteByte(ADDRESS.comboPosition, desiredComboPosition)
        end
        local routeArmed = false
        if expectedAnimation ~= nil then
            routeArmed = beginGroundActionRoute(
                "normal", expectedAnimation, player)
        end
        armTransitionCheck(player, "normal", expectedAnimation,
            desiredComboPosition)
        log(string.format(
            "target-free normal pulse armed from neutral: combo=%d "
            .. "expected=%s route=%s",
            ReadByte(ADDRESS.comboPosition),
            expectedAnimation ~= nil
                and string.format("0x%02X", expectedAnimation) or "native",
            tostring(routeArmed)))
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
            player, "finisher", finisherPosition, 0xCB) then
            clearComboIntent()
        end
    else
        WriteByte(ADDRESS.comboPosition, finisherPosition)
        local routeArmed = beginGroundActionRoute("finisher", 0xCB, player)
        armTransitionCheck(player, "finisher", 0xCB,
            finisherPosition)
        log(string.format(
            "target-free finisher pulse armed from neutral: "
            .. "combo=%d max=%d route=%s",
            ReadByte(ADDRESS.comboPosition),
            ReadByte(ADDRESS.maxGroundComboLength),
            tostring(routeArmed)))
        clearComboIntent()
    end
end

local function cancelPlayer(player, label)
    WriteByte(player.pointer + PLAYER.actionControl, 0x03, true)
    log(string.format(
        "%s cancel: anim=0x%02X secondary=0x%02X time=%.2f",
        label, player.animation, player.secondary, player.time))
end

local function updateAttackControlRouting()
    if not CONFIG.triangleGroundFinisher then
        forceTriangleAttackFrames = 0
        return true
    end
    return setByte("attackControlMap", ADDRESS.attackControlMap,
        forceTriangleAttackFrames > 0 and CONTROL_INDEX.TRIANGLE
            or NORMAL.attackControlMap,
        { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
end

local function updateDefenseRouting(buttons, guardAvailable, dodgeActive)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local circleHeld = (buttons & BUTTON.CIRCLE) ~= 0
    local squareHeld = (buttons & BUTTON.SQUARE) ~= 0
    local guardChord = l2Held and circleHeld
    local dodgeSquareHeld = squareHeld and not dodgeActive

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
    if dodgeActive and squareHeld and not guardChord then
        -- Once DC has begun, physical Square must not feed the shared defense
        -- action again. Guard remains available through its Circle mapping.
        squareMap = 0xFE
    end
    setByte("circleControlMap", ADDRESS.circleControlMap, circleMap,
        { 0xFF, 0x07, 0xFE })
    setByte("squareControlMap", ADDRESS.squareControlMap, squareMap,
        { 0xFF, 0x05, 0xFE })

    local selectGuard = (CONFIG.guardOnL2Circle and l2Held
        and not (squareHeld and not circleHeld)) or forceGuardFrames > 0
    setByte("guardSelection", ADDRESS.guardSelectionBranch,
        selectGuard and 0xEB or 0x74, { 0x74, 0xEB })

    -- Universal Guard and Dodge both receive the airborne bypass while their
    -- own forced input is active. forceGuardFrames disambiguates the shared
    -- virtual Square/defense action used by the two routes.
    local allowAirGuard = CONFIG.universalGuardCancel
        and (guardChord or forceGuardFrames > 0)
    local allowAirDodge = CONFIG.universalDodgeCancel
        and forceGuardFrames == 0
        and (dodgeSquareHeld or forceSquareFrames > 0)
    setByte("airDefense", ADDRESS.airDefenseBranch,
        (allowAirGuard or allowAirDodge) and 0x82 or 0x85,
        { 0x85, 0x82 })

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
        or (CONFIG.fixedDodgeOnSquare and dodgeSquareHeld)
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
    forceTriangleAttackFrames = 0
    comboWarningShown = false
    transitionPulsePhaseFrames = 0
    transitionUsesPhysicalInput = false
    syntheticAttackCommandOwned = false
    syntheticAttackCommandHigh = false
    groundRouteAvailable = false
    groundRouteFrames = 0
    groundRouteAnimation = nil
    groundRouteKind = nil
    groundRouteSourceAnimation = nil
    groundRouteSourceTime = 0.0

    if not CONFIG.enabled then
        ConsolePrint("JokCombat Combat Prototype is disabled in CONFIG.")
        return
    end
    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND"
        or ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        ConsolePrint("JokCombat Combat Prototype - unsupported game/build; disabled.")
        return
    end

    local staleSyntheticAttack = ReadInt(ADDRESS.triggerMenu1) ~= 0
        or ReadInt(ADDRESS.triggerMenu2) ~= 0
    clearSyntheticAttackCommand(true)

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
    if CONFIG.triangleGroundFinisher then
        valid = normalizeByte("attackControlMap", ADDRESS.attackControlMap,
            0xFF, { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE }) and valid
    else
        restoreIfKnown(ADDRESS.attackControlMap, NORMAL.attackControlMap,
            { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
    end
    valid = normalizeByte("squareControlMap", ADDRESS.squareControlMap,
        0xFF, { 0xFF, 0x05, 0xFE }) and valid
    if not valid then return end

    local routeValid = normalizeGroundActionRoute()

    canRun = true
    ConsolePrint(
        "JokCombat Combat Prototype " .. VERSION
        .. " initialized (Steam GL; combat-only; experimental).")
    log("ground action route " .. (routeValid and "ready." or
        "unavailable; combo-position fallback only."))
    if staleSyntheticAttack then
        log("cleared stale synthetic Attack flags during reload.")
    end

    local position, maximum = readGroundComboState()
    if position ~= nil then
        log(string.format(
            "combo controller ready: position=%d maxGround=%d",
            position, maximum))
    end
end

function _OnFrame()
    if not canRun then return end
    if faulted then
        restoreAllPatches()
        return
    end

    local player = readPlayer()
    if player == nil then
        restoreAllPatches()
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        forceGuardFrames = 0
        forceTriangleAttackFrames = 0
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

    local dodgeActive = player.animation == DODGE_ROLL_ANIMATION
    if dodgeActive then
        -- The initial forced window is no longer needed after DC is visible;
        -- retaining it would let a new Square edge restart the same roll.
        forceSquareFrames = 0
    end
    updateDefenseRouting(buttons, guardAvailable, dodgeActive)
    updateAttackControlRouting()
    if faulted then
        restoreAllPatches()
        return
    end

    local l2Held = (buttons & BUTTON.L2) ~= 0
    local circlePressed = pressStarted(buttons, BUTTON.CIRCLE)
    local crossPressed = pressStarted(buttons, BUTTON.CROSS)
    local squarePressed = pressStarted(buttons, BUTTON.SQUARE)
    local trianglePressed = pressStarted(buttons, BUTTON.TRIANGLE)
    local guardPressed = chordStarted(buttons, BUTTON.L2, BUTTON.CIRCLE)
    local stunImpactPressed = CONFIG.stunImpactOnL2Cross
        and l2Held and crossPressed
    updateStunImpactPrime(player, buttons)
    local cancelWindowOpen = isCancelableAttack(player)
    local actionConsumed = false
    local chainWasArmed = groundChainFrames > 0
        or isGroundNormalContext(player)
    local directFinisherContext = isGroundNormalContext(player)
        or (groundChainFrames > 0 and not isAttackContext(player)
            and player.control == 0x03 and player.animation <= 0x07)

    -- Guard keeps first priority and can break any current action, including a
    -- Dodge Roll; Dodge itself cannot restart DC once the roll is active.
    if CONFIG.defensiveCancels and CONFIG.guardOnL2Circle and guardPressed
        and guardAvailable
        and (CONFIG.universalGuardCancel or cancelWindowOpen) then
        cancelPlayer(player, "guard-universal")
        forceSquareFrames = CONFIG.forcedInputFrames
        forceGuardFrames = CONFIG.forcedInputFrames
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        restoreGroundActionRoute()
        actionConsumed = true
    elseif circlePressed and not l2Held then
        -- A normal jump breaks the local ground chain. It only cancels an
        -- attack after the configured link window; it is not universal.
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        restoreGroundActionRoute()
        actionConsumed = true
        if CONFIG.groundToAirJumpBranch and not player.airborne
            and cancelWindowOpen then
            cancelPlayer(player, "jump")
            forceCircleFrames = CONFIG.forcedInputFrames
        end
    elseif CONFIG.fixedDodgeOnSquare and squarePressed and dodgeAvailable then
        actionConsumed = true
        if dodgeActive then
            -- Dodge Roll is intentionally not self-cancellable: a second
            -- Square cannot reset DC to frame zero or extend its invulnerability.
            log("Dodge input ignored: Dodge Roll is already active.")
        else
            -- From every other state, universal Dodge can release the current
            -- action. The forced Square window then selects Dodge Roll.
            clearComboIntent()
            clearTransitionCheck()
            clearDeferredAttackCommand()
            restoreGroundActionRoute()
        end
        if not dodgeActive and CONFIG.defensiveCancels
            and (CONFIG.universalDodgeCancel or cancelWindowOpen) then
            cancelPlayer(player, "dodge-universal")
            forceSquareFrames = CONFIG.forcedInputFrames
        end
    end

    -- Holding L2 on an earlier frame pre-arms D8; the later physical Cross can
    -- therefore be selected directly by the native dispatcher, without first
    -- entering C8. In the air the chord falls through to the normal aerial
    -- Cross behavior because Stun Impact is a ground finisher.
    if not actionConsumed and stunImpactPressed and not player.airborne then
        if ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
            log("Stun Impact input ignored: reaction command is active.")
        else
            actionConsumed = requestStunImpact(player)
        end
    end

    -- Triangle has priority over a normal link that is buffered, waiting for
    -- release, or being retried. Unlike the target-free command-menu pulse,
    -- the temporary Attack -> Triangle mapping creates a native Attack input
    -- in the same frame, so CB no longer waits for a later physical Cross.
    local finisherRequested = false
    if not actionConsumed and CONFIG.triangleGroundFinisher and trianglePressed
        and not player.airborne
        and ReadByte(ADDRESS.commandMenuSlot) == 0 then
        local finisherAlreadyPending = finisherBufferFrames > 0
            or deferredLinkKind == "finisher"
            or transitionKind == "finisher"
        if finisherAlreadyPending then
            finisherRequested = true
            log("Triangle finisher already pending; repeated input ignored.")
        elseif chainWasArmed and directFinisherContext then
            clearAttackBuffer()
            clearFinisherBuffer()
            queuedNormalInput = false
            clearDeferredAttackCommand()
            clearTransitionCheck()
            finisherRequested = true
            local prepared, finisherPosition, maximum =
                prepareGroundFinisher()
            if prepared then
                local routeArmed = beginGroundActionRoute(
                    "finisher", 0xCB, player)
                armTransitionCheck(
                    player, "finisher", 0xCB, finisherPosition, true)
                forceTriangleAttackFrames = CONFIG.forcedInputFrames
                if updateAttackControlRouting() then
                    cancelPlayer(player, "finisher-direct")
                    clearComboIntent()
                    log(string.format(
                        "Triangle finisher dispatched directly: "
                        .. "combo=%d max=%d Attack<-Triangle route=%s",
                        ReadByte(ADDRESS.comboPosition), maximum,
                        tostring(routeArmed)))
                else
                    clearTransitionCheck()
                end
            end
        else
            log("Triangle finisher ignored: no active ground-normal chain.")
        end
    end

    local deferredHandledThisFrame = false
    local transitionAcceptedKind = nil
    local deferredAcceptedKind = nil
    if not actionConsumed then
        updateGroundActionRoute(player)
        transitionAcceptedKind = updateTransitionCheck(player)
        deferredHandledThisFrame, deferredAcceptedKind =
            updateDeferredAttackCommand(player)
        actionConsumed = deferredHandledThisFrame
            or deferredLinkKind ~= nil
            or transitionKind ~= nil
    end

    local acceptedKind = transitionAcceptedKind or deferredAcceptedKind
    local replayedNormalInput = false
    if acceptedKind == "normal" and queuedNormalInput then
        queuedNormalInput = false
        replayedNormalInput = true
        actionConsumed = false
        log("buffered normal input replayed on the new attack.")
    elseif acceptedKind == "normal" then
        -- A naturally accepted link can resolve inside the deferred phase.
        -- Let a new physical press from this same frame be read normally.
        actionConsumed = false
    end

    local normalPipelineBusy = transitionKind == "normal"
        or deferredLinkKind == "normal"
    if actionConsumed and normalPipelineBusy and crossPressed
        and not finisherRequested and finisherBufferFrames <= 0
        and ReadByte(ADDRESS.commandMenuSlot) == 0 then
        if not queuedNormalInput then
            log("normal input buffered behind the pending link.")
        end
        queuedNormalInput = true
    end

    if not actionConsumed then
        local normalInputRequested = crossPressed or replayedNormalInput
        if normalInputRequested and not finisherRequested
            and finisherBufferFrames <= 0
            and ReadByte(ADDRESS.commandMenuSlot) == 0 then
            clearFinisherBuffer()
            local comboPrepared = true
            local desiredPosition = nil
            local expectedAnimation = nil
            if not player.airborne then
                local maximum
                comboPrepared, desiredPosition, maximum, expectedAnimation =
                    prepareNormalGroundAttack(player, chainWasArmed)
                if comboPrepared then
                    groundChainFrames = CONFIG.groundChainMemoryFrames
                    log(string.format(
                        "Cross input accepted: combo=%d max=%d expected=0x%02X",
                        desiredPosition, maximum, expectedAnimation))
                end
            end

            if CONFIG.attackBuffer and isAttackContext(player)
                and (player.airborne or comboPrepared) then
                queueAttackBuffer(
                    player, desiredPosition, expectedAnimation)
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
    forceTriangleAttackFrames = math.max(
        0, forceTriangleAttackFrames - 1)
    if forceTriangleAttackFrames == 0 then
        updateAttackControlRouting()
    end
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
