LUAGUI_NAME = "JokCombat Combat Prototype"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra / KSX"
LUAGUI_DESC = "Cross combo, configurable Action Ability loadout, universal Guard/Dodge cancels and jump branch."

-- JokCombat v0.3.3 prototype for the current Steam Global executable.
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
    actionLoadout = true,
    actionLoadoutMenu = true,
    actionLoadoutPrompt = true,

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
    actionRequestFrames = 120,
    forcedInputFrames = 4,
}

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local VERSION = "v0.3.3"

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    dpadButtons = 0x22C9300,
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

    -- Steam ports of the aerial action entries. Their vanilla values were
    -- verified read-only against the supported executable before v0.3.0.
    airComboAerialSweep = 0x2D2D730,
    airCombo1C = 0x2D2D744,
    airCombo1B = 0x2D2D758,
    airComboHurricane = 0x2D2D85C,
    airComboFinisher = 0x2D2D870,
    airCombo2 = 0x2D2D884,
    airCombo1 = 0x2D2D898,
    flyingCombo1 = 0x2D2D8D4,

    dpadUpControlMap = 0x22C933C,
    dpadRightControlMap = 0x22C933D,
    dpadDownControlMap = 0x22C933E,
    dpadLeftControlMap = 0x22C933F,
    triangleControlMap = 0x22C9344,
    circleControlMap = 0x22C9345,
    attackControlMap = 0x22C9346,
    squareControlMap = 0x22C9347,
    forceCircleBranch = 0x2A7B74,       -- 74 normal, 72 forced
    forceSquareBranch = 0x2A7BD6,       -- 84 normal, 82 forced
    airDefenseBranch = 0x2A7BE0,        -- 85 ground-only, 82 allow in air
    guardAvailabilityBranch = 0x2A7BFD, -- 74 normal, 72 enabled, EB choose roll
    guardSelectionBranch = 0x2A7C01,    -- 74 normal, EB choose guard
    dodgeAvailabilityBranch = 0x2A7C1F, -- 84 normal, 82 enabled

    -- One native KH notification box is reused only while the loadout editor
    -- is open. These Steam addresses and their color pointers were validated
    -- read-only on the same fingerprint as the combat routes.
    promptBoxCount = 0x283B380,
    promptBox = 0x283B390,
    promptText = 0x2DB7720,
    promptColorBox = 0x527A10,
    promptColorText = 0x527A50,
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
    R2 = 0x02,
    CIRCLE = 0x20,
    CROSS = 0x40,
    SQUARE = 0x80,
    TRIANGLE = 0x10,
}

local SHOULDER_MASK = BUTTON.L2 | BUTTON.R2

local DPAD = {
    UP = 0x10,
    RIGHT = 0x20,
    DOWN = 0x40,
    LEFT = 0x80,
}

-- The control-map table is action -> physical control. Its indices follow the
-- face-button order used by Critical Mix: Triangle=04, Circle=05, Cross=06,
-- Square=07. Only the Attack action is temporarily sourced from Triangle.
local CONTROL_INDEX = {
    TRIANGLE = 0x04,
    CIRCLE = 0x05,
    CROSS = 0x06,
    SQUARE = 0x07,
}

local DODGE_ROLL_ANIMATION = 0xDC
local ACTION_KIND_PREFIX = "action:"
local ACTION_PRIME_PREFIX = "action-prime:"

-- Only Sora combat Action Abilities are exposed. Guard and Dodge Roll stay on
-- their fixed controls; support, shared and special/Limit abilities never enter
-- this catalog. The animation map is adapted from the authorized Critical Mix
-- action dictionary and the Steam action tables. Stun Impact is already live-
-- validated; the remaining entries deliberately log their first transitions so
-- their hitboxes and contextual requirements can be verified one by one.
local ACTION_CATALOG = {
    { id = "none", name = "None", context = "none" },
    { id = "slapshot", name = "Slapshot", context = "ground",
        animation = 0xCF, finisher = false },
    { id = "sliding_dash", name = "Sliding Dash", context = "ground",
        animation = 0xD0, finisher = false },
    { id = "vortex", name = "Vortex", context = "ground",
        animation = 0xD3, finisher = false },
    { id = "aerial_sweep", name = "Aerial Sweep", context = "ground",
        animation = 0xD6, finisher = false },
    { id = "counterattack", name = "Counterattack", context = "ground",
        animation = 0xD5, finisher = false, contextual = true },
    { id = "blitz", name = "Blitz", context = "ground",
        animation = 0xD2, finisher = true },
    { id = "hurricane_blast", name = "Hurricane Blast", context = "air",
        animation = 0xD1, finisher = true },
    { id = "ripple_drive", name = "Ripple Drive", context = "ground",
        animation = 0xD7, finisher = true },
    { id = "stun_impact", name = "Stun Impact", context = "ground",
        animation = 0xD8, finisher = true, validated = true },
    { id = "gravity_break", name = "Gravity Break", context = "ground",
        animation = 0xDA, finisher = true },
    { id = "zantetsuken", name = "Zantetsuken", context = "ground",
        animation = 0xDB, finisher = true },
}

local ACTION_BY_ID = {}
local ACTION_INDEX_BY_ID = {}
local ROUTABLE_ACTION_ANIMATION = {}
local FINISHER_ACTION_ANIMATION = {}
for index, action in ipairs(ACTION_CATALOG) do
    ACTION_BY_ID[action.id] = action
    ACTION_INDEX_BY_ID[action.id] = index
    if action.animation ~= nil then
        ROUTABLE_ACTION_ANIMATION[action.animation] = true
        if action.finisher then
            FINISHER_ACTION_ANIMATION[action.animation] = true
        end
    end
end

local ACTION_SLOTS = {
    { id = "l2_cross", label = "L2 + X", modifier = BUTTON.L2,
        face = BUTTON.CROSS, faceName = "X" },
    { id = "l2_triangle", label = "L2 + Triangle", modifier = BUTTON.L2,
        face = BUTTON.TRIANGLE, faceName = "Triangle" },
    { id = "l2_square", label = "L2 + Square", modifier = BUTTON.L2,
        face = BUTTON.SQUARE, faceName = "Square" },
    { id = "r2_cross", label = "R2 + X", modifier = BUTTON.R2,
        face = BUTTON.CROSS, faceName = "X" },
    { id = "r2_triangle", label = "R2 + Triangle", modifier = BUTTON.R2,
        face = BUTTON.TRIANGLE, faceName = "Triangle" },
    { id = "r2_circle", label = "R2 + Circle", modifier = BUTTON.R2,
        face = BUTTON.CIRCLE, faceName = "Circle" },
    { id = "r2_square", label = "R2 + Square", modifier = BUTTON.R2,
        face = BUTTON.SQUARE, faceName = "Square" },
    { id = "dual_cross", label = "L2 + R2 + X",
        modifier = SHOULDER_MASK, face = BUTTON.CROSS, faceName = "X" },
    { id = "dual_triangle", label = "L2 + R2 + Triangle",
        modifier = SHOULDER_MASK, face = BUTTON.TRIANGLE,
        faceName = "Triangle" },
    { id = "dual_circle", label = "L2 + R2 + Circle",
        modifier = SHOULDER_MASK, face = BUTTON.CIRCLE, faceName = "Circle" },
    { id = "dual_square", label = "L2 + R2 + Square",
        modifier = SHOULDER_MASK, face = BUTTON.SQUARE, faceName = "Square" },
}

local ACTION_SLOT_BY_ID = {}
for _, slot in ipairs(ACTION_SLOTS) do ACTION_SLOT_BY_ID[slot.id] = slot end

local function slotModifierMatches(buttons, slot)
    return (buttons & SHOULDER_MASK) == slot.modifier
end

local function slotModifierName(slot)
    if slot.modifier == SHOULDER_MASK then return "L2+R2" end
    if slot.modifier == BUTTON.L2 then return "L2" end
    return "R2"
end

local LOADOUT_MENU_GROUPS = {
    l2 = {
        id = "l2",
        label = "L2",
        openDirection = "Left",
        slots = {
            ACTION_SLOT_BY_ID.l2_cross,
            ACTION_SLOT_BY_ID.l2_triangle,
            ACTION_SLOT_BY_ID.l2_square,
        },
    },
    r2 = {
        id = "r2",
        label = "R2",
        openDirection = "Right",
        slots = {
            ACTION_SLOT_BY_ID.r2_cross,
            ACTION_SLOT_BY_ID.r2_triangle,
            ACTION_SLOT_BY_ID.r2_circle,
            ACTION_SLOT_BY_ID.r2_square,
        },
    },
    dual = {
        id = "dual",
        label = "L2+R2",
        openDirection = "Up",
        slots = {
            ACTION_SLOT_BY_ID.dual_cross,
            ACTION_SLOT_BY_ID.dual_triangle,
            ACTION_SLOT_BY_ID.dual_circle,
            ACTION_SLOT_BY_ID.dual_square,
        },
    },
}

local DEFAULT_LOADOUT = {
    l2_cross = "stun_impact",
    l2_triangle = "slapshot",
    l2_square = "sliding_dash",
    r2_cross = "gravity_break",
    r2_triangle = "ripple_drive",
    r2_circle = "hurricane_blast",
    r2_square = "zantetsuken",
    dual_cross = "blitz",
    dual_triangle = "vortex",
    dual_circle = "aerial_sweep",
    dual_square = "counterattack",
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

local AIR_ACTION_ROUTE = {
    { name = "airComboAerialSweep", address = ADDRESS.airComboAerialSweep,
        normal = 0xD6 },
    { name = "airCombo1C", address = ADDRESS.airCombo1C,
        normal = 0xCD },
    { name = "airCombo1B", address = ADDRESS.airCombo1B,
        normal = 0xCC },
    { name = "airComboHurricane", address = ADDRESS.airComboHurricane,
        normal = 0xD1 },
    { name = "airComboFinisher", address = ADDRESS.airComboFinisher,
        normal = 0xCE },
    { name = "airCombo2", address = ADDRESS.airCombo2,
        normal = 0xCD },
    { name = "airCombo1", address = ADDRESS.airCombo1,
        normal = 0xCC },
    { name = "flyingCombo1", address = ADDRESS.flyingCombo1,
        normal = 0xCC },
}

local NORMAL = {
    forceCircle = 0x74,
    forceSquare = 0x84,
    airDefense = 0x85,
    guardAvailability = 0x74,
    guardSelection = 0x74,
    dodgeAvailability = 0x84,
    dpadUpControlMap = 0xFF,
    dpadRightControlMap = 0xFF,
    dpadDownControlMap = 0xFF,
    dpadLeftControlMap = 0xFF,
    triangleControlMap = 0xFF,
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
local airRouteAvailable = false
local airRouteFrames = 0
local airRouteAnimation = nil
local airRouteKind = nil
local airRouteSourceAnimation = nil
local airRouteSourceTime = 0.0
local syntheticAttackCommandOwned = false
local syntheticAttackCommandHigh = false
local queuedNormalInput = false
local lastDpad = 0
local loadout = {}
local loadoutPath = nil
local loadoutMenuOpen = false
local loadoutMenuGroup = "l2"
local loadoutMenuIndex = 1
local loadoutPromptAvailable = false
local loadoutPromptMismatchKey = nil

local function log(message)
    if CONFIG.debugLog then ConsolePrint("[JokCombat] " .. message) end
end

local function joinPath(root, name)
    if type(root) ~= "string" or root == "" then return name end
    local last = root:sub(-1)
    if last == "\\" or last == "/" then return root .. name end
    return root .. "\\" .. name
end

local function resetLoadoutToDefaults()
    loadout = {}
    for _, slot in ipairs(ACTION_SLOTS) do
        loadout[slot.id] = DEFAULT_LOADOUT[slot.id] or "none"
    end
end

local function loadActionLoadout()
    resetLoadoutToDefaults()
    loadoutPath = joinPath(SCRIPT_PATH, "JokCombat_ActionLoadout.cfg")

    local file = io.open(loadoutPath, "r")
    if file == nil then
        log("loadout file not found; using v0.3.3 defaults.")
        return
    end

    local accepted = 0
    for line in file:lines() do
        local slotId, actionId = line:match(
            "^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
        if ACTION_SLOT_BY_ID[slotId] ~= nil
            and ACTION_BY_ID[actionId] ~= nil then
            loadout[slotId] = actionId
            accepted = accepted + 1
        end
    end
    file:close()
    log(string.format("loaded Action Ability loadout: %d valid slot(s).",
        accepted))
end

local function saveActionLoadout()
    if loadoutPath == nil then return false end
    local file, errorMessage = io.open(loadoutPath, "w")
    if file == nil then
        ConsolePrint("[JokCombat:loadout] unable to save " .. loadoutPath
            .. ": " .. tostring(errorMessage))
        return false
    end

    file:write("# JokCombat v0.3.3 Action Ability loadout\n")
    file:write("# Guard remains fixed on L2+Circle; Dodge Roll on Square.\n")
    for _, slot in ipairs(ACTION_SLOTS) do
        file:write(slot.id, "=", loadout[slot.id] or "none", "\n")
    end
    file:close()
    log("Action Ability loadout saved to " .. loadoutPath)
    return true
end

-- Minimal KHSCII encoder adapted from the authorized Critical Mix prompt
-- helper. The loadout UI deliberately uses only this small ASCII subset.
local KHSCII_PUNCTUATION = {
    [" "] = 0x01,
    ["-"] = 0x6E,
    ["!"] = 0x5F,
    ["?"] = 0x60,
    ["+"] = 0x63,
    ["/"] = 0x66,
    ["."] = 0x68,
    [","] = 0x69,
    [":"] = 0x6B,
    ["("] = 0x74,
    [")"] = 0x75,
}

local function getKHSCII(input, capacity)
    local result = {}
    local maximum = math.max(1, capacity) - 1
    for index = 1, math.min(#input, maximum) do
        local character = input:sub(index, index)
        local byte = string.byte(character)
        local encoded = KHSCII_PUNCTUATION[character]
        if character >= "a" and character <= "z" then
            encoded = byte - 0x1C
        elseif character >= "A" and character <= "Z" then
            encoded = byte - 0x16
        elseif character >= "0" and character <= "9" then
            encoded = byte - 0x0F
        end
        table.insert(result, encoded or 0x01)
    end
    table.insert(result, 0x00)
    while #result < capacity do table.insert(result, 0x00) end
    return result
end

local function initializeLoadoutPrompt(quiet)
    loadoutPromptAvailable = false
    if not CONFIG.actionLoadoutPrompt then return false end

    local expectedBoxColor = BASE_ADDR + ADDRESS.promptColorBox
    local expectedTextColor = BASE_ADDR + ADDRESS.promptColorText
    local actualBoxColor = ReadLong(ADDRESS.promptBox + 0xB88)
    local actualTextColor = ReadLong(ADDRESS.promptBox + 0xB90)
    local hasSteamPointers = actualBoxColor == expectedBoxColor
        and actualTextColor == expectedTextColor
    local isUninitialized = actualBoxColor == 0 and actualTextColor == 0
    if not hasSteamPointers and not isUninitialized then
        local mismatchKey = string.format("%X:%X",
            actualBoxColor, actualTextColor)
        if loadoutPromptMismatchKey ~= mismatchKey then
            ConsolePrint(string.format(
                "[JokCombat:loadout] prompt slot is currently owned by "
                .. "another layout; HUD deferred (box=0x%X text=0x%X).",
                actualBoxColor, actualTextColor))
            loadoutPromptMismatchKey = mismatchKey
        end
        return false
    end

    loadoutPromptAvailable = true
    loadoutPromptMismatchKey = nil
    if isUninitialized and not quiet then
        log("HUD prompt slot is empty; lazy initialization ready.")
    end
    return true
end

local function currentLoadoutMenuGroup()
    return LOADOUT_MENU_GROUPS[loadoutMenuGroup]
        or LOADOUT_MENU_GROUPS.l2
end

local function showLoadoutPrompt()
    if not loadoutMenuOpen then return end
    -- A freshly loaded area commonly leaves the reserved notification slot at
    -- 0/0 until its first use. Revalidate here and initialize the known Steam
    -- pointers only when the JokCombat editor actually needs the box.
    if not initializeLoadoutPrompt(true) then return end
    local group = currentLoadoutMenuGroup()
    local slot = group.slots[loadoutMenuIndex]
    local action = ACTION_BY_ID[loadout[slot.id]] or ACTION_BY_ID.none
    local title = string.format("Action Loadout %s %d/%d",
        group.label, loadoutMenuIndex, #group.slots)

    WriteArray(ADDRESS.promptText, getKHSCII(title, 0x20))
    WriteArray(ADDRESS.promptText + 0x70,
        getKHSCII(slot.label, 0x20))
    WriteArray(ADDRESS.promptText + 0x90,
        getKHSCII(action.name, 0x20))

    WriteInt(ADDRESS.promptBoxCount, 1)
    WriteLong(ADDRESS.promptBox + 0x30,
        BASE_ADDR + ADDRESS.promptText)
    WriteInt(ADDRESS.promptBox + 0x18, 2)
    WriteLong(ADDRESS.promptBox + 0x20,
        BASE_ADDR + ADDRESS.promptText + 0x70)
    WriteLong(ADDRESS.promptBox + 0x28,
        BASE_ADDR + ADDRESS.promptText + 0x90)
    WriteInt(ADDRESS.promptBox + 0x0C, -30000)
    WriteFloat(ADDRESS.promptBox + 0xB80, 1.0)
    WriteLong(ADDRESS.promptBox + 0xB88,
        BASE_ADDR + ADDRESS.promptColorBox)
    WriteLong(ADDRESS.promptBox + 0xB90,
        BASE_ADDR + ADDRESS.promptColorText)
    WriteInt(ADDRESS.promptBox, 1)
end

local function hideLoadoutPrompt()
    if not loadoutPromptAvailable then return end
    WriteInt(ADDRESS.promptBox + 0x0C, 0)
    WriteInt(ADDRESS.promptBox, 0)
    WriteInt(ADDRESS.promptBoxCount, 0)
end

local function hideOwnedLoadoutPrompt()
    if not loadoutPromptAvailable then return end
    if ReadLong(ADDRESS.promptBox + 0x30)
        ~= BASE_ADDR + ADDRESS.promptText then return end
    local signature = getKHSCII("Action Loadout", 0x0F)
    for index = 1, #signature - 1 do
        if ReadByte(ADDRESS.promptText + index - 1) ~= signature[index] then
            return
        end
    end
    hideLoadoutPrompt()
end

local function printLoadoutMenu()
    local group = currentLoadoutMenuGroup()
    ConsolePrint("[JokCombat:loadout] ------------------------------")
    ConsolePrint("[JokCombat:loadout] " .. group.label .. " slots")
    for index, slot in ipairs(group.slots) do
        local action = ACTION_BY_ID[loadout[slot.id]] or ACTION_BY_ID.none
        ConsolePrint(string.format("[JokCombat:loadout] %s %d. %-14s -> %s",
            index == loadoutMenuIndex and ">" or " ", index,
            slot.label, action.name))
    end
    ConsolePrint(
        "[JokCombat:loadout] D-pad Up/Down: slot; Left/Right: ability.")
    ConsolePrint(string.format(
        "[JokCombat:loadout] Repeat L2+R2+D-pad %s to save/close.",
        group.openDirection))
    ConsolePrint(
        "[JokCombat:loadout] With L2+R2: Left/Up/Right switch; Down resets.")
end

local function cycleLoadoutAction(delta)
    local group = currentLoadoutMenuGroup()
    local slot = group.slots[loadoutMenuIndex]
    local currentIndex = ACTION_INDEX_BY_ID[loadout[slot.id]] or 1
    local nextIndex = ((currentIndex - 1 + delta) % #ACTION_CATALOG) + 1
    loadout[slot.id] = ACTION_CATALOG[nextIndex].id
    saveActionLoadout()
    showLoadoutPrompt()
    local action = ACTION_CATALOG[nextIndex]
    ConsolePrint(string.format("[JokCombat:loadout] %s -> %s",
        slot.label, action.name))
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
        or ROUTABLE_ACTION_ANIMATION[value] == true
end

local function isAirRouteValue(value, normal)
    return value == normal or value == 0xCC or value == 0xCD
        or value == 0xCE or ROUTABLE_ACTION_ANIMATION[value] == true
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

local function restoreAirActionRoute()
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        local current = ReadByte(entry.address)
        if isAirRouteValue(current, entry.normal)
            and current ~= entry.normal then
            WriteByte(entry.address, entry.normal)
        end
    end
    airRouteFrames = 0
    airRouteAnimation = nil
    airRouteKind = nil
    airRouteSourceAnimation = nil
    airRouteSourceTime = 0.0
end

local function normalizeAirActionRoute()
    local valid = true
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        local current = ReadByte(entry.address)
        if not isAirRouteValue(current, entry.normal) then
            ConsolePrint(string.format(
                "[JokCombat:route] %s RVA=0x%X has unexpected byte 0x%02X; "
                .. "forced aerial routing disabled.",
                entry.name, entry.address, current))
            valid = false
        elseif current ~= entry.normal then
            WriteByte(entry.address, entry.normal)
        end
    end
    airRouteFrames = 0
    airRouteAnimation = nil
    airRouteKind = nil
    airRouteSourceAnimation = nil
    airRouteSourceTime = 0.0
    airRouteAvailable = valid
    return valid
end

local function beginAirActionRoute(kind, desiredAnimation, player)
    if not airRouteAvailable or desiredAnimation == nil then return false end

    restoreAirActionRoute()
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        local current = ReadByte(entry.address)
        if current ~= entry.normal then
            ConsolePrint(string.format(
                "[JokCombat:route] %s changed to 0x%02X before routing; "
                .. "forced aerial routing disabled.", entry.name, current))
            airRouteAvailable = false
            restoreAirActionRoute()
            return false
        end
    end

    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        if entry.normal ~= desiredAnimation then
            WriteByte(entry.address, desiredAnimation)
        end
    end
    airRouteFrames = CONFIG.groundRouteFrames
    airRouteAnimation = desiredAnimation
    airRouteKind = kind
    airRouteSourceAnimation = player.animation
    airRouteSourceTime = player.time
    log(string.format(
        "%s route armed: all aerial entries -> 0x%02X",
        kind, desiredAnimation))
    return true
end

local function updateAirActionRoute(player)
    if airRouteFrames <= 0 or airRouteAnimation == nil then return false end

    local accepted = player.animation == airRouteAnimation
        and (player.animation ~= airRouteSourceAnimation
            or player.time + 0.5 < airRouteSourceTime)
    if accepted then
        log(string.format(
            "%s route accepted: anim=0x%02X time=%.2f",
            airRouteKind, player.animation, player.time))
        restoreAirActionRoute()
        return true
    end

    airRouteFrames = airRouteFrames - 1
    if airRouteFrames <= 0 then
        log(string.format(
            "%s route timed out before anim=0x%02X was observed.",
            airRouteKind, airRouteAnimation))
        restoreAirActionRoute()
    end
    return false
end

local function restoreActionRoutes()
    restoreGroundActionRoute()
    restoreAirActionRoute()
end

local function beginActionRoute(kind, action, player)
    if action == nil or action.animation == nil then return false end
    if action.context == "air" then
        return beginAirActionRoute(kind, action.animation, player)
    end
    return beginGroundActionRoute(kind, action.animation, player)
end

local function updateActionRoutes(player)
    local groundAccepted = updateGroundActionRoute(player)
    local airAccepted = updateAirActionRoute(player)
    return groundAccepted or airAccepted
end

local function restoreAllPatches()
    clearSyntheticAttackCommand(false)
    restoreActionRoutes()
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
    restoreIfKnown(ADDRESS.dpadUpControlMap, NORMAL.dpadUpControlMap,
        { 0xFF, 0xFE })
    restoreIfKnown(ADDRESS.dpadRightControlMap, NORMAL.dpadRightControlMap,
        { 0xFF, 0xFE })
    restoreIfKnown(ADDRESS.dpadDownControlMap, NORMAL.dpadDownControlMap,
        { 0xFF, 0xFE })
    restoreIfKnown(ADDRESS.dpadLeftControlMap, NORMAL.dpadLeftControlMap,
        { 0xFF, 0xFE })
    restoreIfKnown(ADDRESS.triangleControlMap, NORMAL.triangleControlMap,
        { 0xFF, 0xFE })
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

local function dpadStarted(dpad, mask)
    return (dpad & mask) ~= 0 and (lastDpad & mask) == 0
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
    -- A transition owns any temporary action route for its whole retry window.
    -- Restoring here also makes Guard, Dodge, jump and reload cancellation safe.
    local restorePhysicalAttackMap = transitionUsesPhysicalInput
    if canRun then restoreActionRoutes() end
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
    return kind == "finisher"
        or expectedAnimation == 0xCB
        or FINISHER_ACTION_ANIMATION[expectedAnimation] == true
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

    -- Evaluate the expected animation before the ground/air guard. Aerial
    -- Sweep legitimately starts on the ground and becomes airborne as D6 is
    -- accepted; rejecting the state change first would hide a valid dispatch.
    if player.airborne ~= transitionWasAirborne
        or ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        log(transitionKind .. " persistent command cancelled by state change.")
        queuedNormalInput = false
        clearTransitionCheck()
        return nil
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

    -- A request that already owns a physical X edge only needs the transition
    -- monitor. Configurable X slots use a pre-armed action table and must never
    -- also pulse the command-menu integers, or one input can replay twice.
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

local function actionKind(action)
    return ACTION_KIND_PREFIX .. action.id
end

local function actionPrimeKind(slot, action)
    return ACTION_PRIME_PREFIX .. slot.id .. ":" .. action.id
end

local function isActionPrimeKind(kind)
    return type(kind) == "string"
        and kind:sub(1, #ACTION_PRIME_PREFIX) == ACTION_PRIME_PREFIX
end

local function actionMatchesContext(action, player)
    if action == nil or action.animation == nil then return false end
    if action.context == "air" then return player.airborne end
    return action.context == "ground" and not player.airborne
end

local function actionRouteState(action)
    if action.context == "air" then
        return airRouteKind, airRouteAnimation
    end
    return groundRouteKind, groundRouteAnimation
end

local function promotePrimedActionRoute(action, kind, player)
    if action.context == "air" then
        airRouteKind = kind
        airRouteSourceAnimation = player.animation
        airRouteSourceTime = player.time
        airRouteFrames = math.max(airRouteFrames, CONFIG.actionRequestFrames)
    else
        groundRouteKind = kind
        groundRouteSourceAnimation = player.animation
        groundRouteSourceTime = player.time
        groundRouteFrames = math.max(
            groundRouteFrames, CONFIG.actionRequestFrames)
    end
end

local function requestActionAbility(player, slot, action, usesPhysicalInput)
    if action == nil or action.animation == nil then
        log(slot.label .. " has no Action Ability assigned.")
        return false
    end
    if not actionMatchesContext(action, player) then
        log(string.format("%s ignored: %s is %s-only.",
            slot.label, action.name, action.context))
        return false
    end
    if ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        log(slot.label .. " ignored: reaction command is active.")
        return true
    end

    local kind = actionKind(action)
    local currentRouteKind, currentRouteAnimation = actionRouteState(action)
    if player.animation == action.animation then
        if transitionKind == kind then clearTransitionCheck() end
        if currentRouteKind == kind or isActionPrimeKind(currentRouteKind) then
            restoreActionRoutes()
        end
        log(action.name .. " input ignored: the same action is already active.")
        return true
    end
    if transitionKind == kind or currentRouteKind == kind then
        log(action.name .. " input ignored: request already pending.")
        return true
    end

    local neutral = player.control == 0x03 and not isAttackContext(player)
    local canCancel = isCancelableAttack(player)
    if not usesPhysicalInput and not neutral and not canCancel then
        log(string.format(
            "%s ignored: current action is outside its link window (0x%02X %.2f).",
            action.name, player.animation, player.time))
        return true
    end

    local primeKind = actionPrimeKind(slot, action)
    local routeWasPrimed = currentRouteKind == primeKind
        and currentRouteAnimation == action.animation
    if usesPhysicalInput and not routeWasPrimed then
        log(slot.label .. " ignored: hold the modifier before pressing X.")
        return true
    end

    local comboPosition = nil
    local maximum = nil
    if action.context == "ground" then
        local position
        position, maximum = readGroundComboState()
        if position == nil then
            log(action.name .. " ignored: combo state is unavailable.")
            return true
        end
        if action.finisher then
            comboPosition = maximum + 1
        else
            comboPosition = math.min(math.max(position, 1), maximum)
        end
    end

    clearComboIntent()
    clearDeferredAttackCommand()
    if not usesPhysicalInput then
        clearTransitionCheck()
        if canCancel then cancelPlayer(player, "action-" .. action.id) end
    end

    if comboPosition ~= nil then
        WriteByte(ADDRESS.comboPosition, comboPosition)
    end

    local routeArmed = routeWasPrimed
    if routeWasPrimed then
        promotePrimedActionRoute(action, kind, player)
    else
        routeArmed = beginActionRoute(kind, action, player)
    end
    if not routeArmed then
        log(action.name .. " ignored: its action route is unavailable.")
        return true
    end

    armTransitionCheck(player, kind, action.animation,
        comboPosition, usesPhysicalInput)
    transitionCheckFrames = math.max(
        transitionCheckFrames, CONFIG.actionRequestFrames)
    if action.context == "air" then
        airRouteFrames = math.max(airRouteFrames, CONFIG.actionRequestFrames)
    else
        groundRouteFrames = math.max(
            groundRouteFrames, CONFIG.actionRequestFrames)
    end
    log(string.format(
        "%s requested by %s: anim=0x%02X context=%s route=%s%s",
        action.name, slot.label, action.animation, action.context,
        routeWasPrimed and "prearmed" or "synthetic",
        action.context == "ground"
            and string.format(" combo=%d max=%d", comboPosition, maximum)
            or ""))
    return true
end

local function updateCrossActionPrime(player, buttons)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local crossHeld = (buttons & BUTTON.CROSS) ~= 0
    local otherFaceHeld = (buttons & (BUTTON.TRIANGLE
        | BUTTON.CIRCLE | BUTTON.SQUARE)) ~= 0
    local slot = nil
    if l2Held and not r2Held then
        slot = ACTION_SLOT_BY_ID.l2_cross
    elseif r2Held and not l2Held then
        slot = ACTION_SLOT_BY_ID.r2_cross
    elseif l2Held and r2Held then
        slot = ACTION_SLOT_BY_ID.dual_cross
    end
    local action = slot ~= nil
        and ACTION_BY_ID[loadout[slot.id]] or nil
    local desiredPrime = action ~= nil and action.animation ~= nil
        and actionPrimeKind(slot, action) or nil

    local currentPrimeKind = nil
    if isActionPrimeKind(groundRouteKind) then
        currentPrimeKind = groundRouteKind
    elseif isActionPrimeKind(airRouteKind) then
        currentPrimeKind = airRouteKind
    end

    local canStayPrimed = CONFIG.actionLoadout and desiredPrime ~= nil
        and actionMatchesContext(action, player)
        and player.animation ~= action.animation
        and ReadByte(ADDRESS.commandMenuSlot) == 0
        and not otherFaceHeld
        and transitionKind == nil and deferredLinkKind == nil

    if currentPrimeKind ~= nil then
        if currentPrimeKind ~= desiredPrime or not canStayPrimed then
            restoreActionRoutes()
            log("Action Ability X prime cancelled by state change.")
            return false
        end
        if action.context == "air" then
            airRouteFrames = math.max(
                airRouteFrames, CONFIG.actionRequestFrames)
        else
            groundRouteFrames = math.max(
                groundRouteFrames, CONFIG.actionRequestFrames)
        end
        return true
    end

    -- The physical X route must exist one frame before X reaches KH1's action
    -- dispatcher. Pressing modifier and X together therefore stays native and
    -- the log asks the player to hold the modifier first.
    if not canStayPrimed or crossHeld
        or groundRouteKind ~= nil or airRouteKind ~= nil then
        return false
    end

    local routeArmed = beginActionRoute(desiredPrime, action, player)
    if routeArmed then
        if action.context == "air" then
            airRouteFrames = math.max(
                airRouteFrames, CONFIG.actionRequestFrames)
        else
            groundRouteFrames = math.max(
                groundRouteFrames, CONFIG.actionRequestFrames)
        end
        log(string.format("%s primed by %s; waiting for X.",
            action.name, slotModifierName(slot)))
    end
    return routeArmed
end

local function updateLoadoutMenu(buttons, dpad)
    if not CONFIG.actionLoadoutMenu then return false end
    local bothShoulders = (buttons & BUTTON.L2) ~= 0
        and (buttons & BUTTON.R2) ~= 0

    if bothShoulders and dpadStarted(dpad, DPAD.DOWN) then
        resetLoadoutToDefaults()
        saveActionLoadout()
        if loadoutMenuOpen then
            loadoutMenuIndex = 1
            showLoadoutPrompt()
            printLoadoutMenu()
        end
        ConsolePrint(
            "[JokCombat:loadout] all 11 slots restored to JokCombat defaults.")
        return true
    end

    local requestedGroup = nil
    if bothShoulders and dpadStarted(dpad, DPAD.LEFT) then
        requestedGroup = "l2"
    elseif bothShoulders and dpadStarted(dpad, DPAD.UP) then
        requestedGroup = "dual"
    elseif bothShoulders and dpadStarted(dpad, DPAD.RIGHT) then
        requestedGroup = "r2"
    end

    if requestedGroup ~= nil then
        if loadoutMenuOpen and loadoutMenuGroup == requestedGroup then
            saveActionLoadout()
            loadoutMenuOpen = false
            hideLoadoutPrompt()
            ConsolePrint("[JokCombat:loadout] saved; editor closed.")
        else
            if not loadoutMenuOpen then
                clearComboIntent()
                clearTransitionCheck()
                clearDeferredAttackCommand()
                restoreActionRoutes()
                forceCircleFrames = 0
                forceSquareFrames = 0
                forceGuardFrames = 0
            else
                saveActionLoadout()
            end
            loadoutMenuGroup = requestedGroup
            loadoutMenuIndex = 1
            loadoutMenuOpen = true
            showLoadoutPrompt()
            ConsolePrint(string.format(
                "[JokCombat:loadout] %s editor opened.",
                currentLoadoutMenuGroup().label))
            printLoadoutMenu()
        end
        return true
    end

    if not loadoutMenuOpen then return false end

    local group = currentLoadoutMenuGroup()
    local selectionChanged = false
    if dpadStarted(dpad, DPAD.UP) then
        loadoutMenuIndex = ((loadoutMenuIndex - 2) % #group.slots) + 1
        selectionChanged = true
    elseif dpadStarted(dpad, DPAD.DOWN) then
        loadoutMenuIndex = (loadoutMenuIndex % #group.slots) + 1
        selectionChanged = true
    elseif dpadStarted(dpad, DPAD.LEFT) then
        cycleLoadoutAction(-1)
    elseif dpadStarted(dpad, DPAD.RIGHT) then
        cycleLoadoutAction(1)
    end

    if selectionChanged then
        showLoadoutPrompt()
        printLoadoutMenu()
    end
    return true
end

local function updateLoadoutMenuRouting(menuOpen)
    local map = menuOpen and 0xFE or 0xFF
    setByte("dpadUpControlMap", ADDRESS.dpadUpControlMap, map,
        { 0xFF, 0xFE })
    setByte("dpadRightControlMap", ADDRESS.dpadRightControlMap, map,
        { 0xFF, 0xFE })
    setByte("dpadDownControlMap", ADDRESS.dpadDownControlMap, map,
        { 0xFF, 0xFE })
    setByte("dpadLeftControlMap", ADDRESS.dpadLeftControlMap, map,
        { 0xFF, 0xFE })

    if menuOpen then
        setByte("triangleControlMap", ADDRESS.triangleControlMap, 0xFE,
            { 0xFF, 0xFE })
        setByte("circleControlMap", ADDRESS.circleControlMap, 0xFE,
            { 0xFF, 0x07, 0xFE })
        setByte("attackControlMap", ADDRESS.attackControlMap, 0xFE,
            { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
        setByte("squareControlMap", ADDRESS.squareControlMap, 0xFE,
            { 0xFF, 0x05, 0xFE })
    end
    return not faulted
end

local function updateModifierFaceRouting(buttons)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local actionModifierHeld = l2Held or r2Held
    local reactionActive = ReadByte(ADDRESS.commandMenuSlot) ~= 0
    return setByte("triangleControlMap", ADDRESS.triangleControlMap,
        actionModifierHeld and not reactionActive and 0xFE
            or NORMAL.triangleControlMap,
        { 0xFF, 0xFE })
end

local function updateAttackControlRouting()
    if not CONFIG.triangleGroundFinisher then
        forceTriangleAttackFrames = 0
        return setByte("attackControlMap", ADDRESS.attackControlMap,
            NORMAL.attackControlMap,
            { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
    end
    return setByte("attackControlMap", ADDRESS.attackControlMap,
        forceTriangleAttackFrames > 0 and CONTROL_INDEX.TRIANGLE
            or NORMAL.attackControlMap,
        { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
end

local function updateDefenseRouting(buttons, guardAvailable, dodgeActive)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local circleHeld = (buttons & BUTTON.CIRCLE) ~= 0
    local squareHeld = (buttons & BUTTON.SQUARE) ~= 0
    local anyModifierHeld = l2Held or r2Held
    local guardChord = l2Held and not r2Held and circleHeld
    local dodgeSquareHeld = squareHeld and not dodgeActive
        and not anyModifierHeld

    local circleMap = NORMAL.circleControlMap
    local squareMap = NORMAL.squareControlMap
    if l2Held and r2Held then
        -- Both shoulders belong to the editor chord; no face action leaks into
        -- gameplay while the player prepares either loadout editor chord.
        circleMap = 0xFE
        squareMap = 0xFE
    elseif CONFIG.guardOnL2Circle and l2Held then
        -- The override table is action -> physical control. Disable the native
        -- Circle/jump action and source the virtual Square/defense action from
        -- physical Circle (control index 0x05).
        circleMap = 0xFE
        squareMap = 0xFE
        if circleHeld then
            squareMap = guardAvailable and 0x05 or 0xFE
        end
    elseif r2Held then
        -- R2+Circle and R2+Square are configurable Action Ability slots.
        circleMap = 0xFE
        squareMap = 0xFE
    end
    if dodgeActive and squareHeld and not anyModifierHeld then
        -- Once DC has begun, physical Square must not feed the shared defense
        -- action again. Guard remains available through its Circle mapping.
        squareMap = 0xFE
    end
    setByte("circleControlMap", ADDRESS.circleControlMap, circleMap,
        { 0xFF, 0x07, 0xFE })
    setByte("squareControlMap", ADDRESS.squareControlMap, squareMap,
        { 0xFF, 0x05, 0xFE })

    local selectGuard = guardChord or forceGuardFrames > 0
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
        and (not anyModifierHeld or forceSquareFrames > 0) then
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
    lastDpad = 0
    loadoutMenuOpen = false
    loadoutMenuGroup = "l2"
    loadoutMenuIndex = 1
    loadoutPromptAvailable = false
    loadoutPromptMismatchKey = nil
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
    airRouteAvailable = false
    airRouteFrames = 0
    airRouteAnimation = nil
    airRouteKind = nil
    airRouteSourceAnimation = nil
    airRouteSourceTime = 0.0

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
    valid = normalizeByte("dpadUpControlMap", ADDRESS.dpadUpControlMap,
        0xFF, { 0xFF, 0xFE }) and valid
    valid = normalizeByte("dpadRightControlMap", ADDRESS.dpadRightControlMap,
        0xFF, { 0xFF, 0xFE }) and valid
    valid = normalizeByte("dpadDownControlMap", ADDRESS.dpadDownControlMap,
        0xFF, { 0xFF, 0xFE }) and valid
    valid = normalizeByte("dpadLeftControlMap", ADDRESS.dpadLeftControlMap,
        0xFF, { 0xFF, 0xFE }) and valid
    valid = normalizeByte("triangleControlMap", ADDRESS.triangleControlMap,
        0xFF, { 0xFF, 0xFE }) and valid
    valid = normalizeByte("circleControlMap", ADDRESS.circleControlMap,
        0xFF, { 0xFF, 0x07, 0xFE }) and valid
    valid = normalizeByte("attackControlMap", ADDRESS.attackControlMap,
        0xFF, { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE }) and valid
    valid = normalizeByte("squareControlMap", ADDRESS.squareControlMap,
        0xFF, { 0xFF, 0x05, 0xFE }) and valid
    if not valid then return end

    local groundRouteValid = normalizeGroundActionRoute()
    local airRouteValid = normalizeAirActionRoute()
    loadActionLoadout()
    initializeLoadoutPrompt()
    hideOwnedLoadoutPrompt()

    canRun = true
    ConsolePrint(
        "JokCombat Combat Prototype " .. VERSION
        .. " initialized (Steam GL; combat-only; experimental).")
    log("ground action route " .. (groundRouteValid and "ready." or
        "unavailable."))
    log("aerial action route " .. (airRouteValid and "ready." or
        "unavailable."))
    log("Action Loadout: L2+R2+D-pad Left=L2, Up=dual, Right=R2, Down=reset.")
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
        if loadoutMenuOpen then hideOwnedLoadoutPrompt() end
        loadoutMenuOpen = false
        restoreAllPatches()
        return
    end

    local player = readPlayer()
    if player == nil then
        if loadoutMenuOpen then hideOwnedLoadoutPrompt() end
        loadoutMenuOpen = false
        restoreAllPatches()
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        forceGuardFrames = 0
        forceTriangleAttackFrames = 0
        lastButtons = 0
        lastDpad = 0
        return
    end

    local buttons = ReadByte(ADDRESS.rawButtons)
    local dpad = ReadByte(ADDRESS.dpadButtons)
    updateLoadoutMenu(buttons, dpad)
    local editorChordArmed = (buttons & BUTTON.L2) ~= 0
        and (buttons & BUTTON.R2) ~= 0
    updateLoadoutMenuRouting(loadoutMenuOpen or editorChordArmed)
    if faulted then
        if loadoutMenuOpen then hideOwnedLoadoutPrompt() end
        loadoutMenuOpen = false
        restoreAllPatches()
        return
    end

    if loadoutMenuOpen then
        -- Keep every transient combat branch inert while the editor owns the
        -- D-pad and face controls. Raw input remains readable by this script.
        setByte("forceCircle", ADDRESS.forceCircleBranch, NORMAL.forceCircle,
            { 0x74, 0x72 })
        setByte("forceSquare", ADDRESS.forceSquareBranch, NORMAL.forceSquare,
            { 0x84, 0x82 })
        setByte("airDefense", ADDRESS.airDefenseBranch, NORMAL.airDefense,
            { 0x85, 0x82 })
        setByte("guardSelection", ADDRESS.guardSelectionBranch,
            NORMAL.guardSelection, { 0x74, 0xEB })
        lastButtons = buttons
        lastDpad = dpad
        return
    end

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
    updateModifierFaceRouting(buttons)
    updateAttackControlRouting()
    if faulted then
        restoreAllPatches()
        return
    end

    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local circlePressed = pressStarted(buttons, BUTTON.CIRCLE)
    local crossPressed = pressStarted(buttons, BUTTON.CROSS)
    local squarePressed = pressStarted(buttons, BUTTON.SQUARE)
    local trianglePressed = pressStarted(buttons, BUTTON.TRIANGLE)
    local guardPressed = not r2Held
        and chordStarted(buttons, BUTTON.L2, BUTTON.CIRCLE)
    updateCrossActionPrime(player, buttons)
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
        restoreActionRoutes()
        actionConsumed = true
    elseif circlePressed and not l2Held and not r2Held then
        -- A normal jump breaks the local ground chain. It only cancels an
        -- attack after the configured link window; it is not universal.
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        restoreActionRoutes()
        actionConsumed = true
        if CONFIG.groundToAirJumpBranch and not player.airborne
            and cancelWindowOpen then
            cancelPlayer(player, "jump")
            forceCircleFrames = CONFIG.forcedInputFrames
        end
    elseif CONFIG.fixedDodgeOnSquare and squarePressed and dodgeAvailable
        and not l2Held and not r2Held then
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
            restoreActionRoutes()
        end
        if not dodgeActive and CONFIG.defensiveCancels
            and (CONFIG.universalDodgeCancel or cancelWindowOpen) then
            cancelPlayer(player, "dodge-universal")
            forceSquareFrames = CONFIG.forcedInputFrames
        end
    end

    -- The exact shoulder layer selects one of eleven configurable slots. X uses
    -- the proven pre-armed physical route; the other face buttons are suppressed
    -- while their modifier is held and dispatch a delayed synthetic Attack edge.
    if not actionConsumed and CONFIG.actionLoadout and (l2Held or r2Held) then
        local selectedSlot = nil
        for _, slot in ipairs(ACTION_SLOTS) do
            if slotModifierMatches(buttons, slot)
                and pressStarted(buttons, slot.face) then
                selectedSlot = slot
                break
            end
        end

        if selectedSlot ~= nil then
            local modifierWasHeld = slotModifierMatches(
                lastButtons, selectedSlot)
            local action = ACTION_BY_ID[loadout[selectedSlot.id]]
                or ACTION_BY_ID.none
            local isPhysicalCross = selectedSlot.face == BUTTON.CROSS

            if not modifierWasHeld then
                log(selectedSlot.label
                    .. " ignored: hold the modifier for one frame first.")
                -- X can safely fall through to its native combo. The other face
                -- buttons may already have reached KH1 on this first shoulder
                -- frame, so do not dispatch a second action from the script.
                actionConsumed = not isPhysicalCross
            elseif isPhysicalCross then
                if actionMatchesContext(action, player) then
                    actionConsumed = requestActionAbility(
                        player, selectedSlot, action, true)
                else
                    -- None or a ground/air mismatch deliberately preserves the
                    -- normal X combo rather than leaving the player inert.
                    actionConsumed = false
                end
            else
                actionConsumed = true
                requestActionAbility(player, selectedSlot, action, false)
            end
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
        updateActionRoutes(player)
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
    lastDpad = dpad
end

-- LuaBackend reloads call _OnInit(), which normalizes every known patch. This
-- hook additionally restores state on loaders that provide an exit callback.
function _OnExit()
    if canRun then
        if loadoutMenuOpen then
            saveActionLoadout()
            hideOwnedLoadoutPrompt()
            loadoutMenuOpen = false
        end
        restoreAllPatches()
    end
end
