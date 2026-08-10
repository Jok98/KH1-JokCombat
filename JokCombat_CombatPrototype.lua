LUAGUI_NAME = "JokCombat Combat Prototype"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra / KSX"
LUAGUI_DESC = "Cross combo, configurable Action Ability loadout, universal Guard/Dodge cancels and jump branch."

-- JokCombat v0.6.12 prototype for the current Steam Global executable.
-- Critical Mix was used as an authorized technical reference. This script is
-- intentionally limited to combat/input state and does not touch save data,
-- story flags, rewards, inventory, AP, levels, worlds, chests, or synthesis.

local CONFIG = {
    enabled = true,
    debugLog = true,

    -- KH1 owns every ordinary Cross input. Native Combo Master, Combo Plus
    -- and Air Combo Plus therefore decide whiff continuation, combo length,
    -- intermediate attacks and finishers. The legacy routed-normal pipeline
    -- remains below only as a disabled rollback path.
    nativeNormalAttacks = true,

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
    actionLoadoutOverlay = true,

    -- Enabled for the first combat test so the requested bindings also work
    -- on an early save. This bypass is runtime-only and never edits the save.
    -- Set false later to respect vanilla ability acquisition/equipment.
    unlockDefensiveActions = true,

    -- Only a fresh Cross during the completed phase of CB/CE reopens the
    -- native string. No intermediate normal record is routed by JokCombat.
    groundFinisherRestartTime = 67.0,
    airFinisherRestartTime = 20.0,

    -- Legacy routed-normal rollback settings (inactive while
    -- nativeNormalAttacks=true). A press made early in an attack is remembered
    -- until the native link
    -- window opens. The short delay lets a native accepted press win first,
    -- which prevents one physical input from creating two attacks.
    attackBufferFrames = 45,
    attackBufferDelayFrames = 3,
    -- A normal ground attack accepts one next-hit request only near its native
    -- link point. Earlier spam is ignored instead of being carried forward.
    groundLinkPrebufferLead = 4.0,
    -- The aerial string follows the same one-request rule. CC and CD accept
    -- their next input shortly before their respective release windows.
    airLinkPrebufferLead = 4.0,
    -- CE remains protected through its hit/recovery. Unlike CC/CD, presses
    -- before this time are discarded rather than buffered; a fresh press at
    -- or after the threshold may explicitly restart the aerial string at CC.
    -- Ground-native actions otherwise touch the floor before their active
    -- frame. Once (and only once) the requested animation is actually active,
    -- move Sora upward on KH1's inverted vertical axis and clamp descent there.
    airGroundActionLift = 50.0,
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
local VERSION = "v0.6.12"

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    dpadButtons = 0x22C9300,
    rawButtons = 0x22C9301,
    commandMenuState = 0x2852790,
    -- Native D-pad captures update this selector together with
    -- commandMenuSlot. It is used only for validation/recovery: writing the
    -- pair directly does not run KH1's complete cursor animation.
    commandMenuVisualSlot = 0x2852794,
    commandMenuSlot = 0x28527AC,
    commandMenuObject = 0x2D539F0,
    commandRecordBase = 0x2D36D50,
    commandMessageTokens = 0x2D22F98,
    -- Migration-only addresses: v0.4.9 never patches either location. They
    -- are retained for one release so an F1 reload can undo a stale v0.4.2 or
    -- v0.4.3 experiment before returning to the native three-row menu.
    legacyCommandRowLoopInstruction = 0x27C079,
    legacyCommandRowLoopCountDisplacement = 0x27C07B,
    legacySummonCommandSlot = 0x2DE9B26,
    compactPointerSegments = 0x2EE3980,
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

    -- Canonical 0x14-byte action records. They preserve the complete route
    -- entry, but live v0.3.4 testing proved that special VFX/hitbox dispatch
    -- also depends on the native action selector. These addresses remain
    -- signature-validated before any transient route is copied.
    actionRecordStunImpact = 0x2D2D76C,
    actionRecordGravityBreak = 0x2D2D780,
    actionRecordBlitz = 0x2D2D7A8,
    actionRecordRippleDrive = 0x2D2D7BC,
    actionRecordZantetsuken = 0x2D2D794,
    actionRecordCounterattack = 0x2D2DC08,

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
    -- Steam port of Critical Mix's transient ground-animation-in-air check.
    -- TEST EAX,EAX immediately precedes it, so 73 is an always-taken bridge.
    -- It is used only while pre-arming a physical ground-native action. The
    -- real v0.6.9 shortcut uses vanilla 74 with raw70=0 in suspended fake-ground.
    airGroundActionBranch = 0x2A376D,   -- 74 normal, 73 bridged
    guardAvailabilityBranch = 0x2A7BFD, -- 74 normal, 72 enabled, EB choose roll
    guardSelectionBranch = 0x2A7C01,    -- 74 normal, EB choose guard
    dodgeAvailabilityBranch = 0x2A7C1F, -- 84 normal, 82 enabled

    -- Native ground-finisher selector. Ripple Drive uses its equipped bit
    -- directly; Stun Impact, Gravity Break and Zantetsuken then use three
    -- consecutive probability branches. The relevant branch is bypassed only
    -- while its shortcut is active, letting KH1 create animation, VFX, hitbox
    -- and damage rather than merely entering the routed pose.
    groundFinisherGateBranch = 0x2A6F8A, -- 72 71 normal, 90 90 forced
    stunImpactChanceBranch = 0x2A6FAF,   -- 76 07 normal, 90 90 forced
    gravityBreakChanceBranch = 0x2A6FC5, -- 76 07 normal, 90 90 forced
    zantetsukenChanceBranch = 0x2A6FDF,  -- 76 07 normal, 90 90 forced

    -- Native KH notification storage remains available to the loadout editor.
    -- While the editor is closed, its four 0x20-byte line buffers feed the
    -- original Command Menu text renderer; the notification boxes stay hidden.
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
    L1 = 0x04,
    R1 = 0x08,
    CIRCLE = 0x20,
    CROSS = 0x40,
    SQUARE = 0x80,
    TRIANGLE = 0x10,
}

local SHOULDER_MASK = BUTTON.L2 | BUTTON.R2
local FACE_BUTTON_MASK = BUTTON.CIRCLE | BUTTON.CROSS
    | BUTTON.SQUARE | BUTTON.TRIANGLE

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
local ACTION_RECORD_SIZE = 0x14
local RIPPLE_DRIVE_ABILITY_BIT = 0x04000000
local STUN_IMPACT_ABILITY_BIT = 0x08000000
local GRAVITY_BREAK_ABILITY_BIT = 0x10000000
local ZANTETSUKEN_ABILITY_BIT = 0x20000000
local NATIVE_FINISHER_ABILITY_MASK = RIPPLE_DRIVE_ABILITY_BIT
    | STUN_IMPACT_ABILITY_BIT | GRAVITY_BREAK_ABILITY_BIT
    | ZANTETSUKEN_ABILITY_BIT
local NATIVE_FINISHER_ABILITY_CLEAR_MASK = 0xC3FFFFFF

-- Only Sora combat Action Abilities are exposed. Guard and Dodge Roll stay on
-- their fixed controls; support, shared and special/Limit abilities never enter
-- this catalog. The animation map is adapted from the authorized Critical Mix
-- action dictionary; every complete record below was read from and signature-
-- checked against the Steam action table. Gameplay effects and contextual
-- requirements still need live validation one ability at a time.
local ACTION_CATALOG = {
    { id = "none", name = "None", context = "none" },
    { id = "slapshot", name = "Slapshot", context = "both",
        airBridge = true,
        animation = 0xCF, finisher = false,
        recordAddress = ADDRESS.groundComboSlapshot,
        record = { 0xCF, 0x00, 0x05, 0xFF, 0x28, 0x51, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "sliding_dash", name = "Sliding Dash", context = "both",
        airBridge = true,
        animation = 0xD0, finisher = false,
        recordAddress = ADDRESS.groundComboSlide,
        record = { 0xD0, 0x00, 0x05, 0xFF, 0xB8, 0x50, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x02, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "vortex", name = "Vortex", context = "both",
        airBridge = true,
        animation = 0xD3, finisher = false,
        recordAddress = ADDRESS.groundComboImpulse,
        record = { 0xD3, 0x00, 0x05, 0xFF, 0xC8, 0x4C, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "aerial_sweep", name = "Aerial Sweep", context = "both",
        animation = 0xD6, finisher = false,
        recordAddress = ADDRESS.airComboAerialSweep,
        record = { 0xD6, 0x00, 0x05, 0xFF, 0xC8, 0x4C, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x03, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "counterattack", name = "Counterattack", context = "both",
        animation = 0xD5, finisher = false, contextual = true,
        airBridge = true,
        recordAddress = ADDRESS.actionRecordCounterattack,
        record = { 0xD5, 0x00, 0x05, 0xFF, 0x18, 0x4E, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x03, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "blitz", name = "Blitz", context = "both",
        animation = 0xD2, finisher = true, airBridge = true,
        recordAddress = ADDRESS.actionRecordBlitz,
        record = { 0xD2, 0x00, 0x05, 0xFF, 0x38, 0x4D, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x1B, 0x05, 0x06, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "hurricane_blast", name = "Hurricane Blast", context = "air",
        animation = 0xD1, finisher = true,
        recordAddress = ADDRESS.airComboHurricane,
        record = { 0xD1, 0x00, 0x05, 0xFF, 0x48, 0x50, 0x00, 0x00,
            0x00, 0x00, 0x20, 0x42, 0x1B, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "ripple_drive", name = "Ripple Drive", context = "both",
        animation = 0xD7, finisher = true, airBridge = true,
        recordAddress = ADDRESS.actionRecordRippleDrive,
        record = { 0xD7, 0x00, 0x05, 0xFF, 0x88, 0x4E, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x17, 0x05, 0x17, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "stun_impact", name = "Stun Impact", context = "both",
        animation = 0xD8, finisher = true, airBridge = true,
        recordAddress = ADDRESS.actionRecordStunImpact,
        record = { 0xD8, 0x00, 0x05, 0xFF, 0xF8, 0x4E, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x1B, 0x05, 0x1B, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "gravity_break", name = "Gravity Break", context = "both",
        animation = 0xD9, finisher = true, airBridge = true,
        recordAddress = ADDRESS.actionRecordGravityBreak,
        record = { 0xD9, 0x00, 0x05, 0xFF, 0x68, 0x4F, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x17, 0x05, 0x17, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "zantetsuken", name = "Zantetsuken", context = "both",
        animation = 0xDA, finisher = true, airBridge = true,
        recordAddress = ADDRESS.actionRecordZantetsuken,
        record = { 0xDA, 0x00, 0x05, 0xFF, 0xD8, 0x4F, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x18, 0x05, 0x18, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
}

local ACTION_BY_ID = {}
local ACTION_INDEX_BY_ID = {}
local FINISHER_ACTION_ANIMATION = {}
local ROUTE_RECORD_BY_ANIMATION = {}
for index, action in ipairs(ACTION_CATALOG) do
    ACTION_BY_ID[action.id] = action
    ACTION_INDEX_BY_ID[action.id] = index
    if action.animation ~= nil then
        if action.finisher then
            FINISHER_ACTION_ANIMATION[action.animation] = true
        end
        ROUTE_RECORD_BY_ANIMATION[action.animation] = action.record
    end
end

local ACTION_SLOTS = {
    { id = "l2_cross", label = "L2 + X", modifier = BUTTON.L2,
        face = BUTTON.CROSS, faceName = "A" },
    { id = "l2_triangle", label = "L2 + Triangle", modifier = BUTTON.L2,
        face = BUTTON.TRIANGLE, faceName = "Y" },
    { id = "l2_square", label = "L2 + Square", modifier = BUTTON.L2,
        face = BUTTON.SQUARE, faceName = "X" },
    { id = "r2_cross", label = "R2 + X", modifier = BUTTON.R2,
        face = BUTTON.CROSS, faceName = "A" },
    { id = "r2_triangle", label = "R2 + Triangle", modifier = BUTTON.R2,
        face = BUTTON.TRIANGLE, faceName = "Y" },
    { id = "r2_circle", label = "R2 + Circle", modifier = BUTTON.R2,
        face = BUTTON.CIRCLE, faceName = "B" },
    { id = "r2_square", label = "R2 + Square", modifier = BUTTON.R2,
        face = BUTTON.SQUARE, faceName = "X" },
    { id = "dual_cross", label = "L2 + R2 + X",
        modifier = SHOULDER_MASK, face = BUTTON.CROSS, faceName = "A" },
    { id = "dual_triangle", label = "L2 + R2 + Triangle",
        modifier = SHOULDER_MASK, face = BUTTON.TRIANGLE,
        faceName = "Y" },
    { id = "dual_circle", label = "L2 + R2 + Circle",
        modifier = SHOULDER_MASK, face = BUTTON.CIRCLE, faceName = "B" },
    { id = "dual_square", label = "L2 + R2 + Square",
        modifier = SHOULDER_MASK, face = BUTTON.SQUARE, faceName = "X" },
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
            ACTION_SLOT_BY_ID.l2_triangle,
            ACTION_SLOT_BY_ID.l2_square,
            ACTION_SLOT_BY_ID.l2_cross,
        },
    },
    r2 = {
        id = "r2",
        label = "R2",
        openDirection = "Right",
        slots = {
            ACTION_SLOT_BY_ID.r2_triangle,
            ACTION_SLOT_BY_ID.r2_square,
            ACTION_SLOT_BY_ID.r2_cross,
            ACTION_SLOT_BY_ID.r2_circle,
        },
    },
    dual = {
        id = "dual",
        label = "L2+R2",
        openDirection = "Up",
        slots = {
            ACTION_SLOT_BY_ID.dual_triangle,
            ACTION_SLOT_BY_ID.dual_square,
            ACTION_SLOT_BY_ID.dual_cross,
            ACTION_SLOT_BY_ID.dual_circle,
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
    [0xD1] = 30.0, -- Hurricane Blast recovery
    [0xCF] = 18.0, -- Slapshot
    [0xD0] = 18.0, -- Sliding Dash family
    [0xD2] = 18.0, -- Cleave family
    [0xD3] = 18.0, -- Impulse family
    [0xD6] = 20.0, -- Aerial Sweep recovery
}

-- Input can be remembered before a normal attack is safe to release. C9 is
-- the Keyblade thrust ("Unsealing Stab" in the authorized Critical Mix
-- reference): releasing it at the generic time 18-25 visually removes the
-- thrust during spam. Keep its one-slot request, but protect the animation
-- until the late phase observed in the working non-spam sequence.
local GROUND_NORMAL_LINK_RELEASE = {
    [0xC9] = 34.0,
}

-- Cross cycles the complete ground string. CB deliberately remains outside
-- isGroundNormalContext so the finisher ends the chain instead of linking back
-- into another attack before Sora returns to neutral.
local GROUND_NORMAL_SEQUENCE = { 0xC8, 0xC9, 0xCA }
local GROUND_CROSS_SEQUENCE = { 0xC8, 0xC9, 0xCA, 0xCB }

local GROUND_ACTION_ROUTE = {
    { name = "groundFinisherDefault", address = ADDRESS.groundFinisherDefault,
        normal = 0xCB,
        record = { 0xCB, 0x00, 0x05, 0xFF, 0x58, 0x4C, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x03, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "groundComboSlide", address = ADDRESS.groundComboSlide,
        normal = 0xD0,
        record = { 0xD0, 0x00, 0x05, 0xFF, 0xB8, 0x50, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x02, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "groundComboImpulse", address = ADDRESS.groundComboImpulse,
        normal = 0xD3,
        record = { 0xD3, 0x00, 0x05, 0xFF, 0xC8, 0x4C, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "groundCombo2", address = ADDRESS.groundCombo2,
        normal = 0xC9,
        record = { 0xC9, 0x00, 0x05, 0xFF, 0xE8, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "groundComboSlapshot", address = ADDRESS.groundComboSlapshot,
        normal = 0xCF,
        record = { 0xCF, 0x00, 0x05, 0xFF, 0x28, 0x51, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "groundComboA1", address = ADDRESS.groundComboA1,
        normal = 0xC8,
        record = { 0xC8, 0x00, 0x05, 0xFF, 0x78, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "groundComboA2", address = ADDRESS.groundComboA2,
        normal = 0xCA,
        record = { 0xCA, 0x00, 0x05, 0xFF, 0x78, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x02, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
}

local AIR_ACTION_ROUTE = {
    { name = "airComboAerialSweep", address = ADDRESS.airComboAerialSweep,
        normal = 0xD6,
        record = { 0xD6, 0x00, 0x05, 0xFF, 0xC8, 0x4C, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x03, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "airCombo1C", address = ADDRESS.airCombo1C,
        normal = 0xCD,
        record = { 0xCD, 0x00, 0x05, 0xFF, 0xE8, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x04, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "airCombo1B", address = ADDRESS.airCombo1B,
        normal = 0xCC,
        record = { 0xCC, 0x00, 0x05, 0xFF, 0x78, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0x70, 0x42, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "airComboHurricane", address = ADDRESS.airComboHurricane,
        normal = 0xD1,
        record = { 0xD1, 0x00, 0x05, 0xFF, 0x48, 0x50, 0x00, 0x00,
            0x00, 0x00, 0x20, 0x42, 0x1B, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "airComboFinisher", address = ADDRESS.airComboFinisher,
        normal = 0xCE,
        record = { 0xCE, 0x00, 0x05, 0xFF, 0x58, 0x4C, 0x00, 0x00,
            0x00, 0x00, 0x20, 0x42, 0x03, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "airCombo2", address = ADDRESS.airCombo2,
        normal = 0xCD,
        record = { 0xCD, 0x00, 0x05, 0xFF, 0xE8, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0xA0, 0x41, 0x04, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "airCombo1", address = ADDRESS.airCombo1,
        normal = 0xCC,
        record = { 0xCC, 0x00, 0x05, 0xFF, 0x78, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0xA0, 0x41, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { name = "flyingCombo1", address = ADDRESS.flyingCombo1,
        normal = 0xCC,
        record = { 0xCC, 0x00, 0x05, 0xFF, 0x78, 0x4B, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x41, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
}

-- Canonical complete records for the normal routed animations. Special Action
-- Ability records were registered from ACTION_CATALOG above.
ROUTE_RECORD_BY_ANIMATION[0xC8] = GROUND_ACTION_ROUTE[6].record
ROUTE_RECORD_BY_ANIMATION[0xC9] = GROUND_ACTION_ROUTE[4].record
ROUTE_RECORD_BY_ANIMATION[0xCA] = GROUND_ACTION_ROUTE[7].record
ROUTE_RECORD_BY_ANIMATION[0xCB] = GROUND_ACTION_ROUTE[1].record
ROUTE_RECORD_BY_ANIMATION[0xCC] = AIR_ACTION_ROUTE[7].record
ROUTE_RECORD_BY_ANIMATION[0xCD] = AIR_ACTION_ROUTE[6].record
ROUTE_RECORD_BY_ANIMATION[0xCE] = AIR_ACTION_ROUTE[5].record

local NORMAL = {
    forceCircle = 0x74,
    forceSquare = 0x84,
    airDefense = 0x85,
    airGroundAction = 0x74,
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
local airGroundActionBridgeAnimation = nil
local airGroundActionBridgePositionPointer = nil
local airGroundActionBridgeHeight = nil
local airGroundActionBridgeLifted = false
local airGroundActionBridgeUsesBranch = false
local airGroundActionBridgePlayerPointer = nil
local airGroundActionBridgeOriginalState = nil
local airGroundActionBridgeFakeGround = false
local syntheticAttackCommandOwned = false
local syntheticAttackCommandHigh = false
local actionPrimeComboOwned = false
local actionPrimeComboKind = nil
local actionPrimeOriginalComboPosition = nil
local actionPrimeForcedComboPosition = nil
local physicalPrimeAcceptedActionId = nil
local clearActionPrimeCombo
local lastDpad = 0
local loadout = {}
local loadoutPath = nil
local HUD = {
    available = false,
    enabled = true,
    mismatchKey = nil,
    nativeFailureKey = nil,
    overlayGroup = nil,
    overlaySignature = nil,
    nativeTokenBackups = {},
    nativeSelectionOwned = false,
    nativeSelectionOriginalSlot = nil,
    nativeSelectionPreviousSlot = nil,
    nativeSelectionTargetSlot = nil,
    nativeSelectionPendingFrames = 0,
    nativeDpadPassMask = 0,
    directEditGroup = nil,
    directEditActive = false,
    directEditDirty = false,
    directEditIndex = { l2 = 1, r2 = 1, dual = 1 },
    dpadReleaseLock = false,
    controlChordHeld = false,
    controlChordUsed = false,
    nativeRecoveryAddress = 0x2DB7940,
    nativeRecoverySignature = 0x31574F524E4B4F4A, -- "JOKNROW1"
    -- Legacy markers are read only during initialization. The current marker
    -- records the temporary visual/logical cursor pair alongside the token
    -- redirects.
    nativeRecoveryCommandMarker = 0x4A4B0000,
    nativeRecoveryRecordMarker = 0x4A4C0000,
    nativeRecoverySummonMarker = 0x4A4D0000,
    nativeRecoverySelectionMarker = 0x4A4E0000,
    nativeMessageTokenCount = 0x200,
    moduleSize = 0x2F91000,
    boxCount = 2,
    boxStride = 0x3A20,
    titleStride = 0x20,
    bodyOffset = 0x70,
    bodyStride = 0x140,
    lineStride = 0x20,
    colorStride = 0x10,
    ownerSignature = "JokCombat",
}
local nativeFinisherSelectionActionId = nil
local nativeFinisherOriginalAbilityBits = nil

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
        log("loadout file not found; using v0.6.10 defaults.")
        return
    end

    local accepted = 0
    for line in file:lines() do
        local slotId, actionId = line:match(
            "^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
        if slotId == "action_overlay"
            and (actionId == "true" or actionId == "false") then
            HUD.enabled = actionId == "true"
        elseif ACTION_SLOT_BY_ID[slotId] ~= nil
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

    file:write("# JokCombat v0.6.10 Action Ability loadout\n")
    file:write("# Guard remains fixed on L2+Circle; Dodge Roll on Square.\n")
    file:write("action_overlay=", HUD.enabled and "true" or "false", "\n")
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
    ["["] = 0x76,
    ["]"] = 0x77,
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

function HUD.countAddress(index)
    return ADDRESS.promptBoxCount + 0x04 * (index - 1)
end

function HUD.boxAddress(index)
    return ADDRESS.promptBox + HUD.boxStride * (index - 1)
end

function HUD.titleAddress(index)
    return ADDRESS.promptText + HUD.titleStride * (index - 1)
end

function HUD.lineAddress(index, line)
    return ADDRESS.promptText + HUD.bodyOffset
        + HUD.bodyStride * (index - 1)
        + HUD.lineStride * (line - 1)
end

function HUD.textStartsWith(address, value)
    local encoded = getKHSCII(value, #value + 1)
    for index = 1, #encoded - 1 do
        if ReadByte(address + index - 1) ~= encoded[index] then
            return false
        end
    end
    return true
end

function HUD.boxOwned(index)
    local boxAddress = HUD.boxAddress(index)
    local titleAddress = HUD.titleAddress(index)
    if ReadLong(boxAddress + 0x30) ~= BASE_ADDR + titleAddress then
        return false
    end
    if HUD.textStartsWith(titleAddress, HUD.ownerSignature) then
        return true
    end
    -- Clean up an editor prompt left visible by a v0.3.6 reload.
    return index == 1 and HUD.textStartsWith(titleAddress, "Action Loadout")
end

function HUD.initialize(quiet, requiredBoxes)
    HUD.available = false
    if not CONFIG.actionLoadoutPrompt then return false end

    local sawUninitialized = false
    for index = 1, requiredBoxes or HUD.boxCount do
        local boxAddress = HUD.boxAddress(index)
        local expectedBoxColor = BASE_ADDR + ADDRESS.promptColorBox
            + HUD.colorStride * (index - 1)
        local expectedTextColor = BASE_ADDR + ADDRESS.promptColorText
            + HUD.colorStride * (index - 1)
        local actualBoxColor = ReadLong(boxAddress + 0xB88)
        local actualTextColor = ReadLong(boxAddress + 0xB90)
        local hasSteamPointers = actualBoxColor == expectedBoxColor
            and actualTextColor == expectedTextColor
        local isUninitialized = actualBoxColor == 0 and actualTextColor == 0
        sawUninitialized = sawUninitialized or isUninitialized
        if not hasSteamPointers and not isUninitialized then
            local mismatchKey = string.format("%d:%X:%X", index,
                actualBoxColor, actualTextColor)
            if HUD.mismatchKey ~= mismatchKey then
                ConsolePrint(string.format(
                    "[JokCombat:loadout] prompt box %d belongs to another "
                    .. "layout; HUD deferred (box=0x%X text=0x%X).",
                    index, actualBoxColor, actualTextColor))
                HUD.mismatchKey = mismatchKey
            end
            return false
        end
    end

    HUD.available = true
    HUD.mismatchKey = nil
    if sawUninitialized and not quiet then
        log("HUD prompt boxes are empty; lazy initialization ready.")
    end
    return true
end

function HUD.boxesClaimable(count)
    for index = 1, count do
        if not HUD.boxOwned(index)
            and ReadInt(HUD.boxAddress(index)) ~= 0 then
            return false
        end
    end
    return true
end

function HUD.showBox(index, title, firstLine, secondLine)
    local boxAddress = HUD.boxAddress(index)
    local titleAddress = HUD.titleAddress(index)
    local firstLineAddress = HUD.lineAddress(index, 1)
    local secondLineAddress = HUD.lineAddress(index, 2)

    WriteArray(titleAddress, getKHSCII(title, 0x20))
    WriteArray(firstLineAddress, getKHSCII(firstLine, 0x20))
    WriteArray(secondLineAddress, getKHSCII(secondLine, 0x20))
    WriteInt(HUD.countAddress(index), 1)
    WriteLong(boxAddress + 0x30, BASE_ADDR + titleAddress)
    WriteInt(boxAddress + 0x18, 2)
    WriteLong(boxAddress + 0x20, BASE_ADDR + firstLineAddress)
    WriteLong(boxAddress + 0x28, BASE_ADDR + secondLineAddress)
    WriteInt(boxAddress + 0x0C, -30000)
    WriteFloat(boxAddress + 0xB80, 1.0)
    WriteLong(boxAddress + 0xB88, BASE_ADDR + ADDRESS.promptColorBox
        + HUD.colorStride * (index - 1))
    WriteLong(boxAddress + 0xB90, BASE_ADDR + ADDRESS.promptColorText
        + HUD.colorStride * (index - 1))
    WriteInt(boxAddress, 1)
end

function HUD.hideBoxIfOwned(index)
    if not HUD.boxOwned(index) then return false end
    local boxAddress = HUD.boxAddress(index)
    WriteInt(boxAddress + 0x0C, 0)
    WriteInt(boxAddress, 0)
    WriteInt(HUD.countAddress(index), 0)
    return true
end

function HUD.nativeRootSelectionAvailable()
    if ReadByte(ADDRESS.commandMenuState) ~= 0 then return false end
    local visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
    local slot = ReadByte(ADDRESS.commandMenuSlot)
    if visualSlot == 0 and slot == 0 then return true end
    if not HUD.nativeSelectionOwned or visualSlot ~= slot then return false end
    if visualSlot == HUD.nativeSelectionTargetSlot then return true end
    return HUD.nativeSelectionPendingFrames > 0
        and visualSlot == HUD.nativeSelectionPreviousSlot
end

function HUD.restoreNativeSelection()
    if not HUD.nativeSelectionOwned then
        HUD.nativeSelectionOriginalSlot = nil
        HUD.nativeSelectionPreviousSlot = nil
        HUD.nativeSelectionTargetSlot = nil
        HUD.nativeSelectionPendingFrames = 0
        HUD.nativeDpadPassMask = 0
        return false
    end

    local original = HUD.nativeSelectionOriginalSlot or 0
    local previous = HUD.nativeSelectionPreviousSlot or original
    local target = HUD.nativeSelectionTargetSlot or original
    local visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
    local current = ReadByte(ADDRESS.commandMenuSlot)
    local root = ReadByte(ADDRESS.commandMenuState) == 0
    local visualSafe = visualSlot == original or visualSlot == previous
        or visualSlot == target
    local currentSafe = current == original or current == previous
        or current == target
    if root and visualSafe and currentSafe then
        if visualSlot ~= original then
            WriteByte(ADDRESS.commandMenuVisualSlot, original)
        end
        if current ~= original then
            WriteByte(ADDRESS.commandMenuSlot, original)
        end
        visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
        current = ReadByte(ADDRESS.commandMenuSlot)
    end
    local restored = root and visualSlot == original and current == original
    if not restored then
        log(string.format(
            "native editor cursor restore deferred: menu=%d visual=%d slot=%d expected=%d.",
            ReadByte(ADDRESS.commandMenuState), visualSlot, current, original))
    end
    HUD.nativeSelectionOwned = false
    HUD.nativeSelectionOriginalSlot = nil
    HUD.nativeSelectionPreviousSlot = nil
    HUD.nativeSelectionTargetSlot = nil
    HUD.nativeSelectionPendingFrames = 0
    HUD.nativeDpadPassMask = 0
    return restored
end

function HUD.observeNativeSelection()
    if not HUD.nativeSelectionOwned then return true end
    local visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
    local current = ReadByte(ADDRESS.commandMenuSlot)
    local target = HUD.nativeSelectionTargetSlot or 0
    if visualSlot == target and current == target then
        if HUD.nativeSelectionPendingFrames > 0 then
            log(string.format(
                "native cursor move accepted: visual=%d slot=%d.",
                visualSlot, current))
        end
        HUD.nativeSelectionPreviousSlot = target
        HUD.nativeSelectionPendingFrames = 0
        HUD.nativeDpadPassMask = 0
        if #HUD.nativeTokenBackups > 0 then
            HUD.writeNativeRecovery(HUD.nativeTokenBackups)
        end
        return true
    end

    local previous = HUD.nativeSelectionPreviousSlot or 0
    if HUD.nativeSelectionPendingFrames > 0
        and visualSlot == previous and current == previous then
        HUD.nativeSelectionPendingFrames =
            HUD.nativeSelectionPendingFrames - 1
        if HUD.nativeSelectionPendingFrames > 0 then return true end
        log(string.format(
            "native cursor move timed out: visual=%d slot=%d expected=%d.",
            visualSlot, current, target))
    else
        log(string.format(
            "native cursor move drifted: visual=%d slot=%d expected=%d.",
            visualSlot, current, target))
    end
    HUD.restoreNativeSelection()
    return false
end

function HUD.requestNativeSelection(index, direction)
    if index < 1 or index > 4
        or (direction ~= DPAD.UP and direction ~= DPAD.DOWN)
        or ReadByte(ADDRESS.commandMenuState) ~= 0 then return false end
    if HUD.nativeSelectionOwned and not HUD.observeNativeSelection() then
        return false
    end

    local target = index - 1
    local visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
    local current = ReadByte(ADDRESS.commandMenuSlot)
    if visualSlot ~= current then return false end
    if not HUD.nativeSelectionOwned then
        if visualSlot ~= 0 or current ~= 0 then return false end
        HUD.nativeSelectionOwned = true
        HUD.nativeSelectionOriginalSlot = current
    elseif HUD.nativeSelectionPendingFrames > 0 then
        return false
    end

    HUD.nativeSelectionPreviousSlot = current
    HUD.nativeSelectionTargetSlot = target
    HUD.nativeSelectionPendingFrames = 6
    HUD.nativeDpadPassMask = direction
    log(string.format(
        "native cursor move delegated to KH1: %d -> %d (%s).",
        current, target, direction == DPAD.UP and "Up" or "Down"))
    return true
end

function HUD.hideOwned()
    HUD.restoreNativeSelection()
    HUD.restoreNativeRows()
    for index = 1, HUD.boxCount do
        HUD.hideBoxIfOwned(index)
    end
    HUD.overlayGroup = nil
    HUD.overlaySignature = nil
end

function HUD.actionLine(slot)
    local action = ACTION_BY_ID[loadout[slot.id]] or ACTION_BY_ID.none
    return string.format("[%s] %s", slot.faceName, action.name)
end

function HUD.overlayEntries(groupId)
    if groupId == "l2" then
        return {
            HUD.actionLine(ACTION_SLOT_BY_ID.l2_triangle),
            HUD.actionLine(ACTION_SLOT_BY_ID.l2_square),
            HUD.actionLine(ACTION_SLOT_BY_ID.l2_cross),
            "[B] Guard",
        }
    end

    local group = LOADOUT_MENU_GROUPS[groupId]
    if group == nil then return nil end
    local entries = {}
    for _, slot in ipairs(group.slots) do
        table.insert(entries, HUD.actionLine(slot))
    end
    return entries
end

function HUD.pointerTokenForAbsolute(address)
    local low = address & 0x1FFFFFF
    for slot = 0, 0x3F do
        local segment = ReadLong(ADDRESS.compactPointerSegments + slot * 8)
        if segment > 0 and (segment | low) == address then
            return (0x80000000 | (slot * 0x2000000) | low) & 0xFFFFFFFF
        end
    end
    return nil
end

function HUD.commandMessageTokenAddress(commandId)
    if commandId < 0 or commandId > 0xFF then return nil end
    local recordBase = ReadLong(ADDRESS.commandRecordBase)
    if recordBase < BASE_ADDR
        or recordBase >= BASE_ADDR + HUD.moduleSize then
        return nil
    end

    local messageIndex = ReadShort(
        recordBase + commandId * 0x10 + 0x04, true)
    if messageIndex < 0 or messageIndex >= HUD.nativeMessageTokenCount then
        return nil
    end
    return ADDRESS.commandMessageTokens + messageIndex * 4, messageIndex
end

function HUD.clearNativeRecovery()
    WriteLong(HUD.nativeRecoveryAddress, 0)
    WriteInt(HUD.nativeRecoveryAddress + 0x08, 0)
    WriteInt(HUD.nativeRecoveryAddress + 0x0C, 0)
    WriteLong(HUD.nativeRecoveryAddress + 0x40, 0)
end

function HUD.writeNativeRecovery(patches)
    if patches == nil or #patches < 1 or #patches > 4 then return false end
    HUD.clearNativeRecovery()
    WriteInt(HUD.nativeRecoveryAddress + 0x08, #patches)
    if HUD.nativeSelectionOwned then
        local original = HUD.nativeSelectionOriginalSlot or 0
        local patched = HUD.nativeSelectionTargetSlot or original
        local visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
        local current = ReadByte(ADDRESS.commandMenuSlot)
        if visualSlot == current and current >= 0 and current <= 3 then
            patched = current
        end
        WriteInt(HUD.nativeRecoveryAddress + 0x0C,
            HUD.nativeRecoverySelectionMarker
                | (original & 0xFF) | ((patched & 0xFF) << 8))
    end
    for index, patch in ipairs(patches) do
        local address = HUD.nativeRecoveryAddress + 0x10
            + (index - 1) * 0x0C
        WriteInt(address, patch.address)
        WriteInt(address + 0x04, patch.original)
        WriteInt(address + 0x08, patch.patched)
    end
    -- Publish the marker last so a partial recovery record is never accepted.
    WriteLong(HUD.nativeRecoveryAddress, HUD.nativeRecoverySignature)
    return true
end

function HUD.recoverStaleNativeRows()
    -- One-release migration cleanup for the removed v0.4.3 loop patch. The
    -- current overlay never writes executable code.
    local rowLoopRestored = false
    if ReadByte(ADDRESS.legacyCommandRowLoopInstruction) == 0x8D
        and ReadByte(ADDRESS.legacyCommandRowLoopInstruction + 1) == 0x6F
        and ReadByte(ADDRESS.legacyCommandRowLoopCountDisplacement) == 0xF0 then
        WriteByte(ADDRESS.legacyCommandRowLoopCountDisplacement, 0xEF)
        rowLoopRestored = true
    end

    if ReadLong(HUD.nativeRecoveryAddress)
        ~= HUD.nativeRecoverySignature then
        if rowLoopRestored then
            log("removed a stale v0.4.3 Command Menu loop patch.")
        end
        return rowLoopRestored
    end

    local count = ReadInt(HUD.nativeRecoveryAddress + 0x08)
    local restored = 0
    if count >= 1 and count <= 4 then
        for index = 1, count do
            local recovery = HUD.nativeRecoveryAddress + 0x10
                + (index - 1) * 0x0C
            local address = ReadInt(recovery) & 0xFFFFFFFF
            local original = ReadInt(recovery + 0x04) & 0xFFFFFFFF
            local patched = ReadInt(recovery + 0x08) & 0xFFFFFFFF
            local inTokenTable = address >= ADDRESS.commandMessageTokens
                and address < ADDRESS.commandMessageTokens
                    + HUD.nativeMessageTokenCount * 4
                and ((address - ADDRESS.commandMessageTokens) % 4) == 0
            if inTokenTable
                and (ReadInt(address) & 0xFFFFFFFF) == patched then
                WriteInt(address, original)
                restored = restored + 1
            end
        end
    end

    local recoveryMode = ReadInt(HUD.nativeRecoveryAddress + 0x0C)
        & 0xFFFFFFFF
    local commandRestored = false
    local recordRestored = false
    local summonRestored = false
    local selectionRestored = false
    if (recoveryMode & 0xFFFF0000)
        == HUD.nativeRecoveryCommandMarker then
        local original = recoveryMode & 0xFF
        local patched = (recoveryMode >> 8) & 0xFF
        local menuObject = ReadLong(ADDRESS.commandMenuObject)
        if menuObject >= BASE_ADDR
            and menuObject < BASE_ADDR + HUD.moduleSize
            and ReadInt(menuObject, true) == 0
            and ReadInt(menuObject + 0x10, true) == 4
            and ReadByte(menuObject + 0x17, true) == patched then
            WriteByte(menuObject + 0x17, original, true)
            commandRestored = true
        end
    elseif (recoveryMode & 0xFFFF0000)
        == HUD.nativeRecoveryRecordMarker
        and (recoveryMode & 0xFF) == 0x10 then
        local recordAddress = ReadLong(HUD.nativeRecoveryAddress + 0x40)
        local original = {}
        local inModule = recordAddress >= BASE_ADDR
            and recordAddress + 0x10 <= BASE_ADDR + HUD.moduleSize
        local matches = inModule
        for index = 1, 0x10 do
            original[index] = ReadByte(
                HUD.nativeRecoveryAddress + 0x47 + index)
            local patched = ReadByte(
                HUD.nativeRecoveryAddress + 0x57 + index)
            matches = matches and ReadByte(
                recordAddress + index - 1, true) == patched
        end
        if matches then
            for index = 1, 0x10 do
                WriteByte(recordAddress + index - 1, original[index], true)
            end
            recordRestored = true
        end
    elseif (recoveryMode & 0xFFFF0000)
        == HUD.nativeRecoverySummonMarker then
        local original = recoveryMode & 0xFF
        local patched = (recoveryMode >> 8) & 0xFF
        local originalIsEmpty = original == 0x00 or original == 0xFF
        if originalIsEmpty and patched == 0x06
            and ReadByte(ADDRESS.legacySummonCommandSlot) == patched then
            WriteByte(ADDRESS.legacySummonCommandSlot, original)
            summonRestored = true
        end
    elseif (recoveryMode & 0xFFFF0000)
        == HUD.nativeRecoverySelectionMarker then
        local original = recoveryMode & 0xFF
        local patched = (recoveryMode >> 8) & 0xFF
        local visualSlot = ReadByte(ADDRESS.commandMenuVisualSlot)
        local current = ReadByte(ADDRESS.commandMenuSlot)
        if original <= 3 and patched <= 3
            and ReadByte(ADDRESS.commandMenuState) == 0
            and (visualSlot == original or visualSlot == patched)
            and (current == original or current == patched) then
            if visualSlot == patched then
                WriteByte(ADDRESS.commandMenuVisualSlot, original)
            end
            if current == patched then
                WriteByte(ADDRESS.commandMenuSlot, original)
            end
            selectionRestored =
                ReadByte(ADDRESS.commandMenuVisualSlot) == original
                and ReadByte(ADDRESS.commandMenuSlot) == original
        end
    end
    HUD.clearNativeRecovery()
    if restored > 0 or commandRestored or recordRestored or summonRestored
        or selectionRestored or rowLoopRestored then
        log(string.format("Command Menu recovery: labels=%d%s%s%s%s%s.",
            restored,
            commandRestored and " carrier=restored" or "",
            recordRestored and " record=restored" or "",
            summonRestored and " summon-slot=restored" or "",
            selectionRestored and " cursor=restored" or "",
            rowLoopRestored and " row-loop=restored" or ""))
    end
    return restored > 0 or commandRestored or recordRestored or summonRestored
        or selectionRestored or rowLoopRestored
end

function HUD.restoreNativeRows()
    local restored = 0
    for _, patch in ipairs(HUD.nativeTokenBackups or {}) do
        if (ReadInt(patch.address) & 0xFFFFFFFF) == patch.patched then
            WriteInt(patch.address, patch.original)
            restored = restored + 1
        end
    end
    HUD.nativeTokenBackups = {}
    HUD.clearNativeRecovery()
    HUD.overlayGroup = nil
    HUD.overlaySignature = nil
    return restored > 0
end

function HUD.nativeOverlayFailure(reason)
    if HUD.nativeFailureKey ~= reason then
        ConsolePrint("[JokCombat:loadout] native Command Menu overlay "
            .. "deferred: " .. reason .. ".")
        HUD.nativeFailureKey = reason
    end
    HUD.restoreNativeSelection()
    HUD.restoreNativeRows()
    return false
end

function HUD.showOverlay(groupId)
    if not CONFIG.actionLoadoutOverlay then return false end
    if not HUD.initialize(true, HUD.boxCount) then
        return HUD.nativeOverlayFailure("notification buffers unavailable")
    end
    local group = LOADOUT_MENU_GROUPS[groupId]
    local entries = HUD.overlayEntries(groupId)
    if group == nil or entries == nil or #entries ~= 4 then return false end

    local menuObject = ReadLong(ADDRESS.commandMenuObject)
    if menuObject < BASE_ADDR
        or menuObject >= BASE_ADDR + HUD.moduleSize then
        return HUD.nativeOverlayFailure("invalid menu object")
    end
    if ReadInt(menuObject, true) ~= 0
        or ReadInt(menuObject + 0x10, true) ~= 4 then
        return HUD.nativeOverlayFailure("root menu is not in four-row state")
    end

    local commands = {}
    for index = 1, 4 do
        commands[index] = ReadByte(menuObject + 0x13 + index, true)
    end
    -- A zero/FF fourth ID means the native Summon row has not been unlocked
    -- yet. Patch only rows the game already owns; once KH1 supplies a real
    -- fourth ID, the changed signature automatically expands this to four.
    local visibleCount = (commands[4] == 0x00 or commands[4] == 0xFF)
        and 3 or 4
    local signature = string.format("%s|%X|%02X%02X%02X%02X|%s",
        groupId, menuObject, commands[1], commands[2], commands[3],
        commands[4], table.concat(entries, "|"))
    if HUD.overlayGroup == groupId and HUD.overlaySignature == signature then
        local stillPatched = #HUD.nativeTokenBackups == visibleCount
        for _, patch in ipairs(HUD.nativeTokenBackups) do
            stillPatched = stillPatched
                and (ReadInt(patch.address) & 0xFFFFFFFF) == patch.patched
        end
        if stillPatched then return true end
    end

    HUD.restoreNativeRows()
    if not HUD.boxesClaimable(HUD.boxCount) then
        HUD.hideBoxIfOwned(1)
        HUD.hideBoxIfOwned(2)
        return HUD.nativeOverlayFailure("notification box currently in use")
    end

    HUD.hideBoxIfOwned(1)
    HUD.hideBoxIfOwned(2)
    local lineAddresses = {
        HUD.lineAddress(1, 1), HUD.lineAddress(1, 2),
        HUD.lineAddress(2, 1), HUD.lineAddress(2, 2),
    }
    local patches = {}
    local usedAddresses = {}
    for index = 1, visibleCount do
        local messageAddress, messageIndex =
            HUD.commandMessageTokenAddress(commands[index])
        local textToken = HUD.pointerTokenForAbsolute(
            BASE_ADDR + lineAddresses[index])
        if messageAddress == nil or textToken == nil then
            return HUD.nativeOverlayFailure(
                "command/message pointer validation failed")
        end
        if usedAddresses[messageAddress] then
            return HUD.nativeOverlayFailure(
                "two rows share message index " .. tostring(messageIndex))
        end
        usedAddresses[messageAddress] = true
        patches[index] = {
            address = messageAddress,
            original = ReadInt(messageAddress) & 0xFFFFFFFF,
            patched = textToken,
        }
    end

    for index = 1, 4 do
        WriteArray(lineAddresses[index], getKHSCII(entries[index], 0x20))
    end
    if not HUD.writeNativeRecovery(patches) then
        return HUD.nativeOverlayFailure("recovery record rejected")
    end
    for _, patch in ipairs(patches) do
        WriteInt(patch.address, patch.patched)
    end
    HUD.nativeTokenBackups = patches
    HUD.nativeFailureKey = nil
    HUD.overlayGroup = groupId
    HUD.overlaySignature = signature
    log(string.format(
        "native Command Menu labels active: %s ids=%02X/%02X/%02X/%02X visible=%d/4%s.",
        group.label, commands[1], commands[2], commands[3], commands[4],
        visibleCount, visibleCount == 3 and " (Summon locked)" or ""))
    return true
end

function HUD.hideOverlay()
    HUD.restoreNativeSelection()
    HUD.restoreNativeRows()
    HUD.hideBoxIfOwned(1)
    HUD.hideBoxIfOwned(2)
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
    actionPrimeComboOwned = false
    actionPrimeComboKind = nil
    actionPrimeOriginalComboPosition = nil
    actionPrimeForcedComboPosition = nil
    physicalPrimeAcceptedActionId = nil
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

local function restoreAirGroundActionBridge()
    if airGroundActionBridgeFakeGround
        and airGroundActionBridgePlayerPointer ~= nil
        and airGroundActionBridgeOriginalState ~= nil then
        local livePlayerPointer = ReadLong(ADDRESS.playerPointer)
        if livePlayerPointer == airGroundActionBridgePlayerPointer
            and ReadInt(livePlayerPointer + PLAYER.airborneState, true) == 0 then
            WriteInt(livePlayerPointer + PLAYER.airborneState,
                airGroundActionBridgeOriginalState, true)
            log(string.format(
                "airborne action suspension released: raw70=0x%08X.",
                airGroundActionBridgeOriginalState))
        end
    end
    restoreIfKnown(ADDRESS.airGroundActionBranch,
        NORMAL.airGroundAction, { 0x74, 0x73 })
    airGroundActionBridgeAnimation = nil
    airGroundActionBridgePositionPointer = nil
    airGroundActionBridgeHeight = nil
    airGroundActionBridgeLifted = false
    airGroundActionBridgeUsesBranch = false
    airGroundActionBridgePlayerPointer = nil
    airGroundActionBridgeOriginalState = nil
    airGroundActionBridgeFakeGround = false
end

local function updateAirGroundActionBridge(player)
    local animation = airGroundActionBridgeAnimation
    if animation == nil then return end

    local pending = airRouteAnimation == animation
        or groundRouteAnimation == animation
        or transitionExpectedAnimation == animation
        or deferredLinkExpectedAnimation == animation
    local animationMatches = player.animation == animation
    local fakeGround = airGroundActionBridgeFakeGround
    local active = animationMatches and (player.airborne or fakeGround)
    if (not player.airborne and not fakeGround)
        or (not pending and not active) then
        restoreAirGroundActionBridge()
        return
    end

    if fakeGround then
        if player.pointer ~= airGroundActionBridgePlayerPointer then
            log("airborne action suspension released: player pointer changed.")
            restoreAirGroundActionBridge()
            return
        end
        if player.airborneState ~= 0 then
            WriteInt(player.pointer + PLAYER.airborneState, 0, true)
            player.airborneState = 0
        end
        player.airborne = false
    end

    local positionPointer = player.pointer
    if positionPointer ~= airGroundActionBridgePositionPointer
        or airGroundActionBridgeHeight == nil then
        log("airborne ground-action stall released: "
            .. "Sora position pointer changed or became unavailable.")
        restoreAirGroundActionBridge()
        return
    end

    local currentHeight = ReadFloat(positionPointer + 0x14, true)
    if currentHeight ~= currentHeight or math.abs(currentHeight) > 10000000 then
        log("airborne ground-action stall released: invalid vertical position.")
        restoreAirGroundActionBridge()
        return
    end

    -- Fake-ground suspension deliberately keeps vanilla 0x74: raw70=0 now
    -- reaches KH1's complete ground dispatcher while the transform remains at
    -- the captured aerial height. Legacy animation-only primes can still own
    -- the transient 0x73 bridge until the real shortcut input arrives.
    setByte("airGroundAction", ADDRESS.airGroundActionBranch,
        airGroundActionBridgeUsesBranch and 0x73 or NORMAL.airGroundAction,
        { 0x74, 0x73 })
    -- KH1 otherwise lets the ground-native pose fall into Landing before its
    -- active frame. Do not lift Sora while the shortcut is merely primed: wait
    -- until the requested animation is really active. The game's vertical axis
    -- grows toward the floor, so subtraction lifts and later writes clamp only
    -- the descent while preserving any further native upward movement.
    if fakeGround and airGroundActionBridgeLifted then
        if currentHeight ~= airGroundActionBridgeHeight then
            WriteFloat(positionPointer + 0x14,
                airGroundActionBridgeHeight, true)
        end
    elseif active and not airGroundActionBridgeLifted then
        airGroundActionBridgeHeight = currentHeight
            - CONFIG.airGroundActionLift
        WriteFloat(positionPointer + 0x14,
            airGroundActionBridgeHeight, true)
        airGroundActionBridgeLifted = true
        log(string.format(
            "airborne ground-action height stall engaged: "
            .. "anim=0x%02X %.3f -> %.3f.", animation,
            currentHeight, airGroundActionBridgeHeight))
    elseif active and currentHeight > airGroundActionBridgeHeight then
        WriteFloat(positionPointer + 0x14,
            airGroundActionBridgeHeight, true)
    end
end

local NATIVE_FINISHER_SELECTOR = {
    ripple_drive = {
        abilityBit = RIPPLE_DRIVE_ABILITY_BIT,
        chanceBranch = nil,
    },
    stun_impact = {
        abilityBit = STUN_IMPACT_ABILITY_BIT,
        chanceBranch = ADDRESS.stunImpactChanceBranch,
    },
    gravity_break = {
        abilityBit = GRAVITY_BREAK_ABILITY_BIT,
        chanceBranch = ADDRESS.gravityBreakChanceBranch,
    },
    zantetsuken = {
        abilityBit = ZANTETSUKEN_ABILITY_BIT,
        chanceBranch = ADDRESS.zantetsukenChanceBranch,
    },
}

local NATIVE_FINISHER_ACTION_IDS = {
    "ripple_drive",
    "stun_impact",
    "gravity_break",
    "zantetsuken",
}

local function kindTargetsAction(kind, actionId)
    if type(kind) ~= "string" then return false end
    if kind == ACTION_KIND_PREFIX .. actionId then return true end
    return kind:sub(1, #ACTION_PRIME_PREFIX) == ACTION_PRIME_PREFIX
        and kind:sub(-#actionId) == actionId
end

local function pendingNativeFinisherAction()
    for _, actionId in ipairs(NATIVE_FINISHER_ACTION_IDS) do
        if kindTargetsAction(transitionKind, actionId)
            or kindTargetsAction(deferredLinkKind, actionId)
            or kindTargetsAction(groundRouteKind, actionId)
            or kindTargetsAction(airRouteKind, actionId) then
            return ACTION_BY_ID[actionId]
        end
    end
    return nil
end

local function chordNativeFinisherAction(buttons)
    local modifierHeld = (buttons & SHOULDER_MASK) ~= 0
    if not modifierHeld then return nil end

    -- A held non-X face button is an explicit request and takes precedence over
    -- the passive X pre-prime belonging to the same shoulder layer.
    for _, slot in ipairs(ACTION_SLOTS) do
        if slotModifierMatches(buttons, slot)
            and (buttons & slot.face) ~= 0 then
            local action = ACTION_BY_ID[loadout[slot.id]]
            if action ~= nil and NATIVE_FINISHER_SELECTOR[action.id] ~= nil then
                return action
            end
            return nil
        end
    end

    -- X routes must be native one frame before the physical X edge arrives.
    for _, slot in ipairs(ACTION_SLOTS) do
        if slot.face == BUTTON.CROSS and slotModifierMatches(buttons, slot) then
            local action = ACTION_BY_ID[loadout[slot.id]]
            if action ~= nil and NATIVE_FINISHER_SELECTOR[action.id] ~= nil then
                return action
            end
            return nil
        end
    end
    return nil
end

local function restoreNativeFinisherSelection()
    restoreIfKnown(ADDRESS.groundFinisherGateBranch, 0x72,
        { 0x72, 0x90 })
    restoreIfKnown(ADDRESS.groundFinisherGateBranch + 1, 0x71,
        { 0x71, 0x90 })
    for _, selector in pairs(NATIVE_FINISHER_SELECTOR) do
        if selector.chanceBranch ~= nil then
            restoreIfKnown(selector.chanceBranch, 0x76,
                { 0x76, 0x90 })
            restoreIfKnown(selector.chanceBranch + 1, 0x07,
                { 0x07, 0x90 })
        end
    end

    if nativeFinisherOriginalAbilityBits ~= nil then
        local current = ReadInt(ADDRESS.defenseAbilityFlags)
        local restored = (current & NATIVE_FINISHER_ABILITY_CLEAR_MASK)
            | nativeFinisherOriginalAbilityBits
        if current ~= restored then
            WriteInt(ADDRESS.defenseAbilityFlags,
                restored)
        end
    end
    nativeFinisherOriginalAbilityBits = nil
    nativeFinisherSelectionActionId = nil
end

local function updateNativeFinisherSelection(buttons, player)
    local bridgeActive = airGroundActionBridgeAnimation ~= nil
        and player.animation == airGroundActionBridgeAnimation
    local action = nil
    if bridgeActive then
        -- Once a bridged animation owns the air route, a held shoulder must not
        -- swap its native selector to the passive X shortcut. Preserve only the
        -- selector belonging to the active finisher itself; non-finishers clear
        -- any selector that was armed while their modifier was held.
        for _, actionId in ipairs(NATIVE_FINISHER_ACTION_IDS) do
            local candidate = ACTION_BY_ID[actionId]
            if candidate.animation == player.animation then
                action = candidate
                break
            end
        end
    else
        action = pendingNativeFinisherAction()
            or chordNativeFinisherAction(buttons)
    end
    local selector = action ~= nil and NATIVE_FINISHER_SELECTOR[action.id]
        or nil
    local enable = CONFIG.actionLoadout and selector ~= nil

    if not enable then
        if nativeFinisherSelectionActionId ~= nil
            or nativeFinisherOriginalAbilityBits ~= nil then
            restoreNativeFinisherSelection()
        end
        return true
    end

    if nativeFinisherSelectionActionId ~= nil
        and nativeFinisherSelectionActionId ~= action.id then
        restoreNativeFinisherSelection()
    end

    local abilities = ReadInt(ADDRESS.defenseAbilityFlags)
    local newlyActive = nativeFinisherSelectionActionId == nil
    if newlyActive then
        nativeFinisherSelectionActionId = action.id
        nativeFinisherOriginalAbilityBits = abilities
            & NATIVE_FINISHER_ABILITY_MASK
    end

    -- The native selector scans these finishers in a fixed order. Keep only
    -- the requested bit active during the shortcut so another equipped action
    -- cannot pre-empt it; restore the exact original four bits afterwards.
    local desiredAbilities =
        (abilities & NATIVE_FINISHER_ABILITY_CLEAR_MASK)
        | selector.abilityBit
    if abilities ~= desiredAbilities then
        WriteInt(ADDRESS.defenseAbilityFlags, desiredAbilities)
    end

    local valid = true
    valid = setByte("groundFinisherGateOpcode",
        ADDRESS.groundFinisherGateBranch, 0x90,
        { 0x72, 0x90 }) and valid
    valid = setByte("groundFinisherGateDisplacement",
        ADDRESS.groundFinisherGateBranch + 1, 0x90,
        { 0x71, 0x90 }) and valid
    for actionId, candidate in pairs(NATIVE_FINISHER_SELECTOR) do
        if candidate.chanceBranch ~= nil then
            local forced = action.id == actionId
            valid = setByte(actionId .. "ChanceOpcode",
                candidate.chanceBranch,
                forced and 0x90 or 0x76,
                { 0x76, 0x90 }) and valid
            valid = setByte(actionId .. "ChanceDisplacement",
                candidate.chanceBranch + 1,
                forced and 0x90 or 0x07,
                { 0x07, 0x90 }) and valid
        end
    end

    if valid and newlyActive then
        local selectorMode = selector.chanceBranch == nil
            and "equipped-bit route"
            or "finisher gate + 100% roll"
        log(action.name .. " native selector armed: "
            .. selectorMode .. ".")
    end
    return valid
end

local function actionRecordMatches(address, expected, firstOffset)
    if expected == nil or #expected ~= ACTION_RECORD_SIZE then return false end
    for offset = firstOffset or 0, ACTION_RECORD_SIZE - 1 do
        if ReadByte(address + offset) ~= expected[offset + 1] then
            return false
        end
    end
    return true
end

local function writeActionRecord(address, desired)
    for offset = 0, ACTION_RECORD_SIZE - 1 do
        local value = desired[offset + 1]
        if ReadByte(address + offset) ~= value then
            WriteByte(address + offset, value)
        end
    end
end

local function actionRecordHead(address)
    return string.format("%02X %02X %02X %02X",
        ReadByte(address), ReadByte(address + 1),
        ReadByte(address + 2), ReadByte(address + 3))
end

local function routeEntryHasKnownRecord(entry)
    if actionRecordMatches(entry.address, entry.record) then return true end

    for _, record in pairs(ROUTE_RECORD_BY_ANIMATION) do
        if actionRecordMatches(entry.address, record) then return true end
    end

    -- v0.3.3 and earlier changed only byte zero. Accept that legacy hybrid on
    -- reload only when all remaining 19 bytes still match this entry's Steam
    -- baseline, then normalize it to the complete baseline below.
    local animation = ReadByte(entry.address)
    local routedRecord = ROUTE_RECORD_BY_ANIMATION[animation]
    if routedRecord == nil then return false end
    if actionRecordMatches(entry.address, entry.record, 1) then return true end

    -- v0.6.7 special-finisher hybrid: the aerial dispatcher reads the motion
    -- ID from byte zero and its native resource from dword +4. Preserve every
    -- other byte from the aerial entry so the ground record cannot request Fall
    -- before Ripple Drive/Stun Impact reach their late VFX/hit frames.
    for offset = 1, 3 do
        if ReadByte(entry.address + offset) ~= entry.record[offset + 1] then
            return false
        end
    end
    for offset = 4, 7 do
        if ReadByte(entry.address + offset) ~= routedRecord[offset + 1] then
            return false
        end
    end
    for offset = 8, ACTION_RECORD_SIZE - 1 do
        if ReadByte(entry.address + offset) ~= entry.record[offset + 1] then
            return false
        end
    end
    return true
end

local function validateCanonicalActionRecords()
    local validCount = 0
    for _, action in ipairs(ACTION_CATALOG) do
        if action.animation ~= nil then
            action.recordAvailable = actionRecordMatches(
                action.recordAddress, action.record)
            if action.recordAvailable then
                validCount = validCount + 1
            else
                ConsolePrint(string.format(
                    "[JokCombat:route] %s canonical record mismatch at "
                    .. "RVA=0x%X (%s); this action is disabled.",
                    action.name, action.recordAddress,
                    actionRecordHead(action.recordAddress)))
            end
        end
    end
    return validCount
end

local function restoreGroundActionRoute()
    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        if routeEntryHasKnownRecord(entry)
            and not actionRecordMatches(entry.address, entry.record) then
            writeActionRecord(entry.address, entry.record)
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
        if not routeEntryHasKnownRecord(entry) then
            ConsolePrint(string.format(
                "[JokCombat:route] %s RVA=0x%X has unexpected record %s; "
                .. "forced ground routing disabled.",
                entry.name, entry.address, actionRecordHead(entry.address)))
            valid = false
        elseif not actionRecordMatches(entry.address, entry.record) then
            -- Clean up a complete or legacy route left active by a reload.
            writeActionRecord(entry.address, entry.record)
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
    local desiredRecord = ROUTE_RECORD_BY_ANIMATION[desiredAnimation]
    if desiredRecord == nil then
        log(string.format(
            "%s has no complete ground record for anim=0x%02X.",
            kind, desiredAnimation))
        return false
    end

    restoreGroundActionRoute()
    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        if not actionRecordMatches(entry.address, entry.record) then
            ConsolePrint(string.format(
                "[JokCombat:route] %s changed before complete routing (%s); "
                .. "forced ground routing disabled.", entry.name,
                actionRecordHead(entry.address)))
            groundRouteAvailable = false
            restoreGroundActionRoute()
            return false
        end
    end

    for _, entry in ipairs(GROUND_ACTION_ROUTE) do
        writeActionRecord(entry.address, desiredRecord)
    end
    groundRouteFrames = CONFIG.groundRouteFrames
    groundRouteAnimation = desiredAnimation
    groundRouteKind = kind
    groundRouteSourceAnimation = player.animation
    groundRouteSourceTime = player.time
    log(string.format(
        "%s route armed: all ground entries -> complete 0x%02X record",
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
        if routeEntryHasKnownRecord(entry)
            and not actionRecordMatches(entry.address, entry.record) then
            writeActionRecord(entry.address, entry.record)
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
        if not routeEntryHasKnownRecord(entry) then
            ConsolePrint(string.format(
                "[JokCombat:route] %s RVA=0x%X has unexpected record %s; "
                .. "forced aerial routing disabled.",
                entry.name, entry.address, actionRecordHead(entry.address)))
            valid = false
        elseif not actionRecordMatches(entry.address, entry.record) then
            writeActionRecord(entry.address, entry.record)
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

local function beginAirActionRoute(kind, desiredAnimation, player, routeMode)
    if not airRouteAvailable or desiredAnimation == nil then return false end
    local desiredRecord = ROUTE_RECORD_BY_ANIMATION[desiredAnimation]
    if desiredRecord == nil then
        log(string.format(
            "%s has no complete aerial record for anim=0x%02X.",
            kind, desiredAnimation))
        return false
    end

    restoreAirActionRoute()
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        if not actionRecordMatches(entry.address, entry.record) then
            ConsolePrint(string.format(
                "[JokCombat:route] %s changed before complete routing (%s); "
                .. "forced aerial routing disabled.", entry.name,
                actionRecordHead(entry.address)))
            airRouteAvailable = false
            restoreAirActionRoute()
            return false
        end
    end

    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        if routeMode == "animation" then
            -- Ground-native animations must inherit the aerial entry's state,
            -- movement and hit-dispatch metadata. Critical Mix routes these by
            -- replacing byte zero only; copying the complete ground record made
            -- KH1 clear Sora's airborne state at animation time 12-25.
            if ReadByte(entry.address) ~= desiredAnimation then
                WriteByte(entry.address, desiredAnimation)
            end
        elseif routeMode == "resource" then
            -- D7/D8/D9/DA need their own native motion resource for their late
            -- effect/hit script, but the complete ground record also requests
            -- Fall at animation time 20-22. Import only ID + resource and keep
            -- the aerial movement/state/hit-dispatch fields at +8..+19.
            if ReadByte(entry.address) ~= desiredAnimation then
                WriteByte(entry.address, desiredAnimation)
            end
            for offset = 4, 7 do
                local desired = desiredRecord[offset + 1]
                if ReadByte(entry.address + offset) ~= desired then
                    WriteByte(entry.address + offset, desired)
                end
            end
        else
            writeActionRecord(entry.address, desiredRecord)
        end
    end
    airRouteFrames = CONFIG.groundRouteFrames
    airRouteAnimation = desiredAnimation
    airRouteKind = kind
    airRouteSourceAnimation = player.animation
    airRouteSourceTime = player.time
    if routeMode == "animation" then
        log(string.format(
            "%s route armed: all aerial entries -> animation 0x%02X "
            .. "over native air records", kind, desiredAnimation))
    elseif routeMode == "resource" then
        log(string.format(
            "%s route armed: all aerial entries -> animation 0x%02X + "
            .. "native resource %02X%02X%02X%02X over air state",
            kind, desiredAnimation, desiredRecord[8], desiredRecord[7],
            desiredRecord[6], desiredRecord[5]))
    else
        log(string.format(
            "%s route armed: all aerial entries -> complete 0x%02X record",
            kind, desiredAnimation))
    end
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

local function restoreActionRoutes(restorePrimeCombo)
    restoreGroundActionRoute()
    restoreAirActionRoute()
    if restorePrimeCombo ~= false and clearActionPrimeCombo ~= nil then
        clearActionPrimeCombo(true)
    end
end

local function beginActionRoute(kind, action, player)
    if action == nil or action.animation == nil then return false end
    if action.recordAvailable ~= true then return false end
    local bridged = player.airborne and action.airBridge == true
    local priming = type(kind) == "string"
        and kind:sub(1, #ACTION_PRIME_PREFIX) == ACTION_PRIME_PREFIX
    -- Limit fake-ground to the normal Jump/Fall states validated by the probe.
    -- Swimming, flying and scripted airborne states keep the older aerial route.
    local fakeGround = bridged and not priming
        and (player.airborneState == 1 or player.airborneState == 2)
    local nativeFinisherBridge = bridged
        and NATIVE_FINISHER_SELECTOR[action.id] ~= nil
    if bridged then
        restoreAirGroundActionBridge()
        -- The validated player object owns its live position vector directly at
        -- +0x10; +0x14 is the vertical component. The former global pointer can
        -- legitimately be zero in gameplay and must never gate an action route.
        local positionPointer = player.pointer
        local height = ReadFloat(positionPointer + 0x14, true)
        if height == nil or height ~= height or math.abs(height) > 10000000 then
            log(string.format(
                "%s suspension unavailable; using executable aerial fallback.",
                kind))
            fakeGround = false
        else
            local usesGroundBranch = not fakeGround and not nativeFinisherBridge
            if not setByte("airGroundAction", ADDRESS.airGroundActionBranch,
                    usesGroundBranch and 0x73 or NORMAL.airGroundAction,
                    { 0x74, 0x73 }) then
                return false
            end
            airGroundActionBridgeAnimation = action.animation
            airGroundActionBridgePositionPointer = positionPointer
            airGroundActionBridgeUsesBranch = usesGroundBranch
            airGroundActionBridgePlayerPointer = player.pointer
            airGroundActionBridgeOriginalState = player.airborneState
            airGroundActionBridgeFakeGround = fakeGround
            if fakeGround then
                airGroundActionBridgeHeight = height - CONFIG.airGroundActionLift
                airGroundActionBridgeLifted = true
                WriteFloat(positionPointer + 0x14,
                    airGroundActionBridgeHeight, true)
                WriteInt(player.pointer + PLAYER.airborneState, 0, true)
                player.airborneState = 0
                player.airborne = false
                log(string.format(
                    "%s airborne action suspension armed for 0x%02X: "
                    .. "fake-ground raw70=0x%08X->0 height=%.3f->%.3f.",
                    kind, action.animation, airGroundActionBridgeOriginalState,
                    height, airGroundActionBridgeHeight))
            else
                airGroundActionBridgeHeight = height
                airGroundActionBridgeLifted = false
                log(string.format(
                    "%s airborne ground-action prime armed for 0x%02X at %.3f "
                    .. "(%s).", kind, action.animation, height,
                    nativeFinisherBridge
                        and "native aerial dispatcher + resource"
                        or "transient ground bridge + air state"))
            end
        end
    else
        restoreAirGroundActionBridge()
    end

    local armed = false
    if fakeGround then
        armed = beginGroundActionRoute(kind, action.animation, player)
    elseif player.airborne then
        armed = beginAirActionRoute(
            kind, action.animation, player,
            bridged and (nativeFinisherBridge and "resource" or "animation"))
    else
        armed = beginGroundActionRoute(kind, action.animation, player)
    end
    if not armed and bridged then restoreAirGroundActionBridge() end
    return armed
end

local function updateActionRoutes(player)
    local groundAccepted = updateGroundActionRoute(player)
    local airAccepted = updateAirActionRoute(player)
    return groundAccepted or airAccepted
end

local function restoreAllPatches()
    clearSyntheticAttackCommand(false)
    restoreActionRoutes()
    restoreAirGroundActionBridge()
    restoreNativeFinisherSelection()
    HUD.hideOverlay()
    restoreIfKnown(ADDRESS.forceCircleBranch, NORMAL.forceCircle,
        { 0x74, 0x72 })
    restoreIfKnown(ADDRESS.forceSquareBranch, NORMAL.forceSquare,
        { 0x84, 0x82 })
    restoreIfKnown(ADDRESS.airDefenseBranch, NORMAL.airDefense,
        { 0x85, 0x82 })
    restoreIfKnown(ADDRESS.airGroundActionBranch,
        NORMAL.airGroundAction, { 0x74, 0x73 })
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

    local airborneState = ReadInt(pointer + PLAYER.airborneState, true)
    return {
        pointer = pointer,
        control = ReadByte(pointer + PLAYER.actionControl, true),
        airborneState = airborneState,
        airborne = airborneState ~= 0,
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

function HUD.shoulderGroup(buttons)
    local modifier = buttons & SHOULDER_MASK
    if modifier == BUTTON.L2 then return "l2" end
    if modifier == BUTTON.R2 then return "r2" end
    if modifier == SHOULDER_MASK then return "dual" end
    return nil
end

function HUD.overlayEligible(buttons, player)
    return CONFIG.actionLoadout and CONFIG.actionLoadoutPrompt
        and CONFIG.actionLoadoutOverlay and HUD.enabled
        and HUD.shoulderGroup(buttons) ~= nil
        and HUD.nativeRootSelectionAvailable()
        and player.control == 0x03 and player.animation <= 0x07
end

function HUD.finishDirectEdit(reason, dpad)
    HUD.restoreNativeSelection()
    local groupId = HUD.directEditGroup
    if groupId == nil then
        if dpad == 0 then HUD.dpadReleaseLock = false end
        return false
    end

    if dpad ~= nil and dpad ~= 0 then HUD.dpadReleaseLock = true end
    local dirty = HUD.directEditDirty
    if dirty then
        saveActionLoadout()
        local group = LOADOUT_MENU_GROUPS[groupId]
        log(string.format("%s direct loadout saved (%s).",
            group ~= nil and group.label or groupId,
            reason or "modifier released"))
    end
    HUD.directEditGroup = nil
    HUD.directEditActive = false
    HUD.directEditDirty = false
    HUD.overlaySignature = nil
    return dirty
end

function HUD.updateOverlayControls(buttons, dpad)
    local toggleMask = BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2
    local toggleHeld = (buttons & toggleMask) == toggleMask
    if toggleHeld and not HUD.controlChordHeld then
        HUD.controlChordHeld = true
        HUD.controlChordUsed = false
    end

    local dpadConsumed = toggleHeld and dpad ~= 0
    if dpadConsumed then HUD.controlChordUsed = true end
    local resetStarted = toggleHeld and (dpad & DPAD.DOWN) ~= 0
        and (lastDpad & DPAD.DOWN) == 0
    if resetStarted then
        HUD.restoreNativeSelection()
        resetLoadoutToDefaults()
        HUD.directEditDirty = false
        HUD.directEditActive = false
        HUD.overlaySignature = nil
        saveActionLoadout()
        ConsolePrint(
            "[JokCombat:loadout] all 11 slots restored to JokCombat defaults.")
    end

    if not toggleHeld and HUD.controlChordHeld then
        if not HUD.controlChordUsed then
            HUD.finishDirectEdit("overlay toggle", dpad)
            HUD.enabled = not HUD.enabled
            HUD.hideOverlay()
            saveActionLoadout()
            log("native Command Menu overlay "
                .. (HUD.enabled and "enabled" or "disabled")
                .. " after releasing L1+R1+L2+R2.")
        end
        HUD.controlChordHeld = false
        HUD.controlChordUsed = false
    end
    return toggleHeld, dpadConsumed
end

function HUD.visibleEditableCount(groupId)
    local group = LOADOUT_MENU_GROUPS[groupId]
    if group == nil then return 0 end
    local maximum = #group.slots
    if maximum <= 3 then return maximum end

    local menuObject = ReadLong(ADDRESS.commandMenuObject)
    if menuObject >= BASE_ADDR
        and menuObject < BASE_ADDR + HUD.moduleSize
        and ReadInt(menuObject, true) == 0
        and ReadInt(menuObject + 0x10, true) == 4 then
        local fourthCommand = ReadByte(menuObject + 0x17, true)
        if fourthCommand ~= 0x00 and fourthCommand ~= 0xFF then
            return maximum
        end
    end
    return math.min(3, maximum)
end

function HUD.updateDirectEditor(buttons, dpad, player, controlConsumed)
    if dpad == 0 then HUD.dpadReleaseLock = false end
    local groupId = HUD.shoulderGroup(buttons)
    local eligible = CONFIG.actionLoadoutMenu
        and HUD.overlayEligible(buttons, player)
        and (buttons & FACE_BUTTON_MASK) == 0
    if not eligible then
        local reason = "shortcut context ended"
        if groupId == nil then
            reason = "modifier released"
        elseif (buttons & FACE_BUTTON_MASK) ~= 0 then
            reason = "shortcut input"
        end
        HUD.finishDirectEdit(reason, dpad)
        return HUD.dpadReleaseLock
    end

    if HUD.directEditGroup ~= groupId then
        if HUD.directEditGroup ~= nil then
            HUD.finishDirectEdit("modifier changed", dpad)
        end
        HUD.directEditGroup = groupId
        HUD.directEditActive = false
        HUD.directEditDirty = false
        -- The native root cursor always starts on Attack. Start each editing
        -- session on the first displayed row so logical and visual selection
        -- have the same origin.
        HUD.directEditIndex[groupId] = 1
    end

    if controlConsumed then return true end
    local group = LOADOUT_MENU_GROUPS[groupId]
    local editableCount = HUD.visibleEditableCount(groupId)
    local index = math.max(1, math.min(
        HUD.directEditIndex[groupId], editableCount))
    HUD.directEditIndex[groupId] = index
    local upStarted = (dpad & DPAD.UP) ~= 0
        and (lastDpad & DPAD.UP) == 0
    local downStarted = (dpad & DPAD.DOWN) ~= 0
        and (lastDpad & DPAD.DOWN) == 0
    local leftStarted = (dpad & DPAD.LEFT) ~= 0
        and (lastDpad & DPAD.LEFT) == 0
    local rightStarted = (dpad & DPAD.RIGHT) ~= 0
        and (lastDpad & DPAD.RIGHT) == 0

    local previousIndex = index
    if upStarted then
        index = math.max(1, index - 1)
    elseif downStarted then
        index = math.min(editableCount, index + 1)
    end
    if (upStarted or downStarted) and index ~= previousIndex then
        HUD.directEditIndex[groupId] = index
        HUD.directEditActive = true
        HUD.overlaySignature = nil
        log(string.format("%s direct loadout selected %s.",
            group.label, group.slots[index].label))
        local direction = upStarted and DPAD.UP or DPAD.DOWN
        if not HUD.requestNativeSelection(index, direction) then
            log("native editor cursor became unavailable; editor selection closed.")
            HUD.finishDirectEdit("native cursor unavailable", dpad)
            return true
        end
    end

    if leftStarted or rightStarted then
        local slot = group.slots[index]
        local currentIndex = ACTION_INDEX_BY_ID[loadout[slot.id]] or 1
        local delta = leftStarted and -1 or 1
        local nextIndex = ((currentIndex - 1 + delta)
            % #ACTION_CATALOG) + 1
        local action = ACTION_CATALOG[nextIndex]
        loadout[slot.id] = action.id
        HUD.directEditActive = true
        HUD.directEditDirty = true
        HUD.overlaySignature = nil
        ConsolePrint(string.format("[JokCombat:loadout] %s -> %s",
            slot.label, action.name))
    end
    if HUD.directEditActive and not HUD.observeNativeSelection() then
        log("native editor cursor became unavailable; editor selection closed.")
        HUD.finishDirectEdit("native cursor unavailable", dpad)
    end
    return true
end

function HUD.updateOverlay(buttons, player)

    local groupId = HUD.shoulderGroup(buttons)
    local show = HUD.overlayEligible(buttons, player)
        and (buttons & FACE_BUTTON_MASK) == 0
    if not show then
        HUD.hideOverlay()
        return false
    end
    return HUD.showOverlay(groupId)
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

local function isAirNormalContext(player)
    return player.airborne and isAttackContext(player)
        and (player.animation == 0xCC or player.animation == 0xCD)
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

local function requestNativeFinisherRestart(player)
    if not CONFIG.nativeNormalAttacks
        or ReadByte(ADDRESS.commandMenuSlot) ~= 0
        or deferredLinkKind ~= nil or transitionKind ~= nil then
        return false
    end

    local finisher = nil
    local threshold = nil
    if not player.airborne and player.animation == 0xCB then
        finisher = "ground"
        threshold = CONFIG.groundFinisherRestartTime
    elseif player.airborne and player.animation == 0xCE then
        finisher = "aerial"
        threshold = CONFIG.airFinisherRestartTime
    else
        return false
    end

    if player.time < threshold then
        log(string.format(
            "%s finisher restart ignored before native recovery: "
            .. "time=%.2f opens=%.2f.",
            finisher, player.time, threshold))
        return false
    end

    -- Reset only the native combo cursor. The following Attack edge is not
    -- associated with a forced C8/CC record: KH1 chooses the opening attack
    -- from the real ground/air state and all three equipped combo passives.
    clearAttackBuffer()
    clearFinisherBuffer()
    groundChainFrames = 0
    WriteByte(ADDRESS.comboPosition, 1)
    if not queueAttackAfterRelease(player, "restart", 1, nil) then
        return false
    end
    log(string.format(
        "%s infinite combo restart requested natively: "
        .. "anim=0x%02X time=%.2f.",
        finisher, player.animation, player.time))
    return true
end

local function updateDeferredAttackCommand(player)
    if deferredLinkKind == nil then return false, nil end

    if player.airborne ~= deferredLinkWasAirborne
        or ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        log(deferredLinkKind .. " deferred command cancelled by state change.")
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
        if expectedAnimation ~= nil then
            if player.airborne then
                routeArmed = beginAirActionRoute(
                    kind, expectedAnimation, player)
            else
                routeArmed = beginGroundActionRoute(
                    kind, expectedAnimation, player)
            end
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

local function prepareNormalAirAttack(player)
    if not player.airborne then return false end
    local desiredAnimation = nil
    if player.animation == 0xCC then
        desiredAnimation = 0xCD
    elseif player.animation == 0xCD then
        desiredAnimation = 0xCE
    elseif player.animation == 0xD1 or player.animation == 0xD6 then
        -- A completed airborne Action Ability rejoins the normal cycle at CC.
        desiredAnimation = 0xCC
    end
    if desiredAnimation == nil then return false end
    -- Complete aerial records are routed explicitly, so this path does not
    -- depend on the early save's native max-air-combo byte or combo counter.
    return true, nil, desiredAnimation
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
    local protectedRelease = not player.airborne
        and GROUND_NORMAL_LINK_RELEASE[player.animation] or nil
    if protectedRelease ~= nil then
        canLinkNow = isAttackContext(player)
            and player.time >= protectedRelease
    end
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
            if player.airborne then
                routeArmed = beginAirActionRoute(
                    "normal", expectedAnimation, player)
            else
                routeArmed = beginGroundActionRoute(
                    "normal", expectedAnimation, player)
            end
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
    if airGroundActionBridgeAnimation ~= nil then
        restoreAirGroundActionBridge()
    end
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
    if action.context == "both" then return true end
    if action.context == "air" then return player.airborne end
    return action.context == "ground" and not player.airborne
end

local function actionRouteState(action, player)
    if player.airborne then
        return airRouteKind, airRouteAnimation
    end
    return groundRouteKind, groundRouteAnimation
end

local function promotePrimedActionRoute(action, kind, player)
    if player.airborne then
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

clearActionPrimeCombo = function(restoreOriginal)
    if actionPrimeComboOwned and restoreOriginal then
        local current = ReadByte(ADDRESS.comboPosition)
        -- Never overwrite a value the game has already consumed or advanced.
        -- Restore only while the exact value owned by this prime is still live.
        if current == actionPrimeForcedComboPosition then
            WriteByte(ADDRESS.comboPosition,
                actionPrimeOriginalComboPosition)
        end
    end
    actionPrimeComboOwned = false
    actionPrimeComboKind = nil
    actionPrimeOriginalComboPosition = nil
    actionPrimeForcedComboPosition = nil
end

local function primeActionComboState(action, primeKind, player)
    local needsGroundFinisherContext = action.finisher
        and (not player.airborne or action.airBridge == true)
    if not needsGroundFinisherContext then
        clearActionPrimeCombo(true)
        return true
    end

    local position, maximum = readGroundComboState()
    if position == nil then return false end
    local desired = maximum + 1

    if actionPrimeComboOwned and actionPrimeComboKind ~= primeKind then
        clearActionPrimeCombo(true)
        position, maximum = readGroundComboState()
        if position == nil then return false end
        desired = maximum + 1
    end

    if not actionPrimeComboOwned then
        actionPrimeComboOwned = true
        actionPrimeComboKind = primeKind
        actionPrimeOriginalComboPosition = position
        actionPrimeForcedComboPosition = desired
        log(string.format(
            "%s finisher context prearmed: combo=%d max=%d.",
            action.name, desired, maximum))
    end

    WriteByte(ADDRESS.comboPosition, actionPrimeForcedComboPosition)
    return true
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
    local requestedFromAir = player.airborne

    local kind = actionKind(action)
    local currentRouteKind, currentRouteAnimation =
        actionRouteState(action, player)
    if player.animation == action.animation then
        if usesPhysicalInput
            and physicalPrimeAcceptedActionId == action.id then
            physicalPrimeAcceptedActionId = nil
            clearActionPrimeCombo(false)
            log(action.name
                .. " accepted by physical X with its complete action record.")
            return true
        end
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
        or (player.airborne and player.animation == 0xCE
            and player.time >= CONFIG.airFinisherRestartTime)
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
    if not player.airborne or action.airBridge == true then
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
        if usesPhysicalInput then clearActionPrimeCombo(true) end
        log(action.name .. " ignored: its action route is unavailable.")
        return true
    end
    if routeWasPrimed then clearActionPrimeCombo(false) end

    armTransitionCheck(player, kind, action.animation,
        comboPosition, usesPhysicalInput)
    transitionCheckFrames = math.max(
        transitionCheckFrames, CONFIG.actionRequestFrames)
    if player.airborne then
        airRouteFrames = math.max(airRouteFrames, CONFIG.actionRequestFrames)
    else
        groundRouteFrames = math.max(
            groundRouteFrames, CONFIG.actionRequestFrames)
    end
    log(string.format(
        "%s requested by %s: anim=0x%02X context=%s route=%s%s",
        action.name, slot.label, action.animation,
        requestedFromAir and "air-suspended" or "ground",
        routeWasPrimed and "prearmed" or "synthetic",
        comboPosition ~= nil
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

    local currentPrimeMatchesPlayer = currentPrimeKind == nil
        or (player.airborne and isActionPrimeKind(airRouteKind))
        or (not player.airborne and isActionPrimeKind(groundRouteKind))
    if not currentPrimeMatchesPlayer then
        restoreActionRoutes()
        currentPrimeKind = nil
        log("Action Ability X prime moved to the current air/ground context.")
    end

    local bridgeActive = airGroundActionBridgeAnimation ~= nil
        and player.animation == airGroundActionBridgeAnimation
    if bridgeActive and currentPrimeKind == nil then
        -- Holding the modifier after a non-X shortcut used to pre-arm its X
        -- binding immediately. That replaced the live bridge animation (for
        -- example D0 with D8) and released the height stall mid-action. An
        -- explicit cancel can still route another non-X shortcut later, but a
        -- passive X prime never takes ownership from the active move.
        clearActionPrimeCombo(true)
        return false
    end

    local canStayPrimed = CONFIG.actionLoadout and desiredPrime ~= nil
        and action.recordAvailable == true
        and actionMatchesContext(action, player)
        and player.animation ~= action.animation
        and HUD.nativeRootSelectionAvailable()
        and not otherFaceHeld
        and transitionKind == nil and deferredLinkKind == nil

    if currentPrimeKind ~= nil then
        if currentPrimeKind == desiredPrime
            and action ~= nil and player.animation == action.animation then
            clearActionPrimeCombo(false)
            physicalPrimeAcceptedActionId = action.id
            restoreActionRoutes(false)
            return false
        end
        if currentPrimeKind ~= desiredPrime or not canStayPrimed then
            restoreActionRoutes()
            log("Action Ability X prime cancelled by state change.")
            return false
        end
        if not primeActionComboState(action, currentPrimeKind, player) then
            restoreActionRoutes()
            log("Action Ability X prime cancelled: combo state unavailable.")
            return false
        end
        if player.airborne then
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
        if desiredPrime == nil then clearActionPrimeCombo(true) end
        return false
    end

    if not primeActionComboState(action, desiredPrime, player) then
        log(action.name .. " prime ignored: combo state unavailable.")
        return false
    end
    local routeArmed = beginActionRoute(desiredPrime, action, player)
    if routeArmed then
        if player.airborne then
            airRouteFrames = math.max(
                airRouteFrames, CONFIG.actionRequestFrames)
        else
            groundRouteFrames = math.max(
                groundRouteFrames, CONFIG.actionRequestFrames)
        end
        log(string.format("%s primed by %s; waiting for X.",
            action.name, slotModifierName(slot)))
    else
        clearActionPrimeCombo(true)
    end
    return routeArmed
end

local function updateLoadoutMenuRouting(controlsOwned, dpadOwned)
    local passMask = HUD.nativeDpadPassMask or 0
    local upMap = dpadOwned and (passMask & DPAD.UP) == 0
        and 0xFE or NORMAL.dpadUpControlMap
    local rightMap = dpadOwned and (passMask & DPAD.RIGHT) == 0
        and 0xFE or NORMAL.dpadRightControlMap
    local downMap = dpadOwned and (passMask & DPAD.DOWN) == 0
        and 0xFE or NORMAL.dpadDownControlMap
    local leftMap = dpadOwned and (passMask & DPAD.LEFT) == 0
        and 0xFE or NORMAL.dpadLeftControlMap
    setByte("dpadUpControlMap", ADDRESS.dpadUpControlMap, upMap,
        { 0xFF, 0xFE })
    setByte("dpadRightControlMap", ADDRESS.dpadRightControlMap, rightMap,
        { 0xFF, 0xFE })
    setByte("dpadDownControlMap", ADDRESS.dpadDownControlMap, downMap,
        { 0xFF, 0xFE })
    setByte("dpadLeftControlMap", ADDRESS.dpadLeftControlMap, leftMap,
        { 0xFF, 0xFE })

    if controlsOwned then
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
    local reactionActive = not HUD.nativeRootSelectionAvailable()
    return setByte("triangleControlMap", ADDRESS.triangleControlMap,
        actionModifierHeld and not reactionActive and 0xFE
            or NORMAL.triangleControlMap,
        { 0xFF, 0xFE })
end

local function updateAttackControlRouting(buttons, player)
    local suppressPhysicalCross = airGroundActionBridgeFakeGround
    if not suppressPhysicalCross and buttons ~= nil and player ~= nil
        and player.airborne then
        local l2Held = (buttons & BUTTON.L2) ~= 0
        local r2Held = (buttons & BUTTON.R2) ~= 0
        local slot = nil
        if l2Held and not r2Held then
            slot = ACTION_SLOT_BY_ID.l2_cross
        elseif r2Held and not l2Held then
            slot = ACTION_SLOT_BY_ID.r2_cross
        elseif l2Held and r2Held then
            slot = ACTION_SLOT_BY_ID.dual_cross
        end
        local action = slot ~= nil and ACTION_BY_ID[loadout[slot.id]] or nil
        suppressPhysicalCross = action ~= nil and action.airBridge == true
            and action.recordAvailable == true
            and (player.airborneState == 1 or player.airborneState == 2)
    end

    if not CONFIG.triangleGroundFinisher then
        forceTriangleAttackFrames = 0
        return setByte("attackControlMap", ADDRESS.attackControlMap,
            suppressPhysicalCross and 0xFE or NORMAL.attackControlMap,
            { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
    end
    return setByte("attackControlMap", ADDRESS.attackControlMap,
        suppressPhysicalCross and 0xFE
            or (forceTriangleAttackFrames > 0 and CONTROL_INDEX.TRIANGLE
                or NORMAL.attackControlMap),
        { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
end

local function updateDefenseRouting(buttons, guardAvailable, dodgeActive)
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local circleHeld = (buttons & BUTTON.CIRCLE) ~= 0
    local squareHeld = (buttons & BUTTON.SQUARE) ~= 0
    local actionModifierHeld = l2Held or r2Held
    -- L1/R1 own KH1's native magic shortcut layer. Fixed Dodge must leave
    -- Square completely vanilla while either shortcut modifier is held.
    local nativeShortcutHeld = (buttons & (BUTTON.L1 | BUTTON.R1)) ~= 0
    local anyDodgeModifierHeld = actionModifierHeld or nativeShortcutHeld
    local guardChord = l2Held and not r2Held and circleHeld
    local dodgeSquareHeld = squareHeld and not dodgeActive
        and not anyDodgeModifierHeld

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
    if dodgeActive and squareHeld and not anyDodgeModifierHeld then
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
        and (dodgeSquareHeld
            or (forceSquareFrames > 0 and not nativeShortcutHeld))
    setByte("airDefense", ADDRESS.airDefenseBranch,
        (allowAirGuard or allowAirDodge) and 0x82 or 0x85,
        { 0x85, 0x82 })

    local guardAvailability = CONFIG.unlockDefensiveActions and 0x72 or 0x74
    -- Keep the roll route armed before the first Square frame. Previously it
    -- was selected only after Square was observed, so a stationary first press
    -- could already have entered Guard and a second press appeared to roll.
    if CONFIG.fixedDodgeOnSquare and forceGuardFrames == 0
        and (not anyDodgeModifierHeld
            or (forceSquareFrames > 0 and not nativeShortcutHeld)) then
        guardAvailability = 0xEB
    end
    setByte("guardAvailability", ADDRESS.guardAvailabilityBranch,
        guardAvailability, { 0x74, 0x72, 0xEB })

    -- Merely holding L2 must only pre-arm the Circle mapping. The defensive
    -- bypass itself is enabled after Circle/Square is physically present;
    -- enabling it on L2 alone caused the unwanted automatic Guard.
    if (CONFIG.guardOnL2Circle and guardChord)
        or (CONFIG.fixedDodgeOnSquare and dodgeSquareHeld)
        or (forceSquareFrames > 0 and not nativeShortcutHeld) then
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
    HUD.available = false
    HUD.enabled = true
    HUD.mismatchKey = nil
    HUD.nativeFailureKey = nil
    HUD.overlayGroup = nil
    HUD.overlaySignature = nil
    HUD.nativeTokenBackups = {}
    HUD.nativeSelectionOwned = false
    HUD.nativeSelectionOriginalSlot = nil
    HUD.nativeSelectionPreviousSlot = nil
    HUD.nativeSelectionTargetSlot = nil
    HUD.nativeSelectionPendingFrames = 0
    HUD.nativeDpadPassMask = 0
    HUD.directEditGroup = nil
    HUD.directEditActive = false
    HUD.directEditDirty = false
    HUD.directEditIndex = { l2 = 1, r2 = 1, dual = 1 }
    HUD.dpadReleaseLock = false
    HUD.controlChordHeld = false
    HUD.controlChordUsed = false
    nativeFinisherSelectionActionId = nil
    nativeFinisherOriginalAbilityBits = nil
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
    airGroundActionBridgeAnimation = nil
    airGroundActionBridgePositionPointer = nil
    airGroundActionBridgeHeight = nil
    airGroundActionBridgeLifted = false
    airGroundActionBridgeUsesBranch = false
    airGroundActionBridgePlayerPointer = nil
    airGroundActionBridgeOriginalState = nil
    airGroundActionBridgeFakeGround = false

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
    valid = normalizeByte("airGroundAction", ADDRESS.airGroundActionBranch,
        0x74, { 0x74, 0x73 }) and valid
    valid = normalizeByte("guardAvailability", ADDRESS.guardAvailabilityBranch,
        0x74, { 0x74, 0x72, 0xEB }) and valid
    valid = normalizeByte("guardSelection", ADDRESS.guardSelectionBranch,
        0x74, { 0x74, 0xEB }) and valid
    valid = normalizeByte("dodgeAvailability", ADDRESS.dodgeAvailabilityBranch,
        0x84, { 0x84, 0x82 }) and valid
    valid = normalizeByte("groundFinisherGateOpcode",
        ADDRESS.groundFinisherGateBranch, 0x72,
        { 0x72, 0x90 }) and valid
    valid = normalizeByte("groundFinisherGateDisplacement",
        ADDRESS.groundFinisherGateBranch + 1, 0x71,
        { 0x71, 0x90 }) and valid
    for actionId, selector in pairs(NATIVE_FINISHER_SELECTOR) do
        if selector.chanceBranch ~= nil then
            valid = normalizeByte(actionId .. "ChanceOpcode",
                selector.chanceBranch, 0x76,
                { 0x76, 0x90 }) and valid
            valid = normalizeByte(actionId .. "ChanceDisplacement",
                selector.chanceBranch + 1, 0x07,
                { 0x07, 0x90 }) and valid
        end
    end
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

    HUD.recoverStaleNativeRows()
    local groundRouteValid = normalizeGroundActionRoute()
    local airRouteValid = normalizeAirActionRoute()
    local validActionRecordCount = validateCanonicalActionRecords()
    loadActionLoadout()
    HUD.initialize()
    HUD.hideOwned()

    canRun = true
    ConsolePrint(
        "JokCombat Combat Prototype " .. VERSION
        .. " initialized (Steam GL; combat-only; experimental).")
    log("ground action route " .. (groundRouteValid and "ready." or
        "unavailable."))
    log("aerial action route " .. (airRouteValid and "ready." or
        "unavailable."))
    log(string.format("complete action records ready: %d/%d.",
        validActionRecordCount, #ACTION_CATALOG - 1))
    log("direct Action Loadout ready: hold L2/R2/L2+R2; "
        .. "D-pad Up/Down selects, Left/Right changes, release saves.")
    log("native editor cursor delegation ready: Up/Down uses KH1's complete "
        .. "native transition; Left/Right remains isolated for editing.")
    log("native Command Menu overlay ready: up to four native rows; "
        .. "release L1+R1+L2+R2 to toggle it; add D-pad Down to reset "
        .. "defaults; overlay is currently "
        .. (HUD.enabled and "on." or "off."))
    log("fourth loadout row follows the native Summon unlock; early saves "
        .. "show and edit the three rows KH1 currently renders.")
    log("native Ripple Drive/Stun Impact/Gravity Break/Zantetsuken "
        .. "selectors ready.")
    log("airborne Action Ability routes ready: all 11 catalog actions; "
        .. "ground-native moves use the complete ground dispatcher in a "
        .. "temporary suspended fake-ground state.")
    log(string.format("airborne action suspension ready: ground-native "
        .. "actions lift by %.1f and lock vertical position until completion.",
        CONFIG.airGroundActionLift))
    log("airborne fake-ground lifecycle ready: raw70 is restored on complete, "
        .. "cancel, route failure, script fault or player loss.")
    log("airborne ground-native X shortcuts use a suppressed physical edge "
        .. "followed by one synthetic ground-dispatch pulse.")
    log("airborne bridge ownership ready: a passive X prime cannot replace "
        .. "an active bridged action.")
    if staleSyntheticAttack then
        log("cleared stale synthetic Attack flags during reload.")
    end

    if CONFIG.nativeNormalAttacks then
        log("native normal combo ownership ready: KH1 controls every "
            .. "intermediate Cross, Combo Plus/Air Combo Plus length and "
            .. "Combo Master whiff continuation.")
        log(string.format(
            "infinite native combo bridge ready: CB>=%.1f and CE>=%.1f; "
            .. "no normal action records are routed.",
            CONFIG.groundFinisherRestartTime,
            CONFIG.airFinisherRestartTime))
    else
        local position, maximum = readGroundComboState()
        if position ~= nil then
            log(string.format(
                "legacy combo controller ready: position=%d maxGround=%d",
                position, maximum))
        end
    end
end

function _OnFrame()
    if not canRun then return end
    if faulted then
        HUD.finishDirectEdit("script fault", 0)
        if HUD.overlayGroup ~= nil then HUD.hideOwned() end
        restoreAllPatches()
        return
    end

    physicalPrimeAcceptedActionId = nil

    local player = readPlayer()
    if player == nil then
        HUD.finishDirectEdit("player unavailable", 0)
        HUD.controlChordHeld = false
        HUD.controlChordUsed = false
        HUD.dpadReleaseLock = false
        if HUD.overlayGroup ~= nil then HUD.hideOwned() end
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
    updateAirGroundActionBridge(player)
    if faulted then
        restoreAllPatches()
        return
    end
    local controlDpadOwned, controlConsumed =
        HUD.updateOverlayControls(buttons, dpad)
    local directDpadOwned = HUD.updateDirectEditor(
        buttons, dpad, player, controlConsumed)
    local dpadOwned = controlDpadOwned or directDpadOwned
        or HUD.dpadReleaseLock
    local configurationInputActive = dpadOwned and dpad ~= 0
    if configurationInputActive then
        restoreNativeFinisherSelection()
    else
        updateNativeFinisherSelection(buttons, player)
    end
    if faulted then
        HUD.finishDirectEdit("script fault", dpad)
        restoreAllPatches()
        return
    end
    updateLoadoutMenuRouting(configurationInputActive, dpadOwned)
    HUD.updateOverlay(buttons, player)
    if faulted then
        HUD.finishDirectEdit("script fault", dpad)
        if HUD.overlayGroup ~= nil then HUD.hideOwned() end
        restoreAllPatches()
        return
    end

    if configurationInputActive then
        -- D-pad editing owns every mapped control for this frame. Keeping the
        -- combat dispatcher inert prevents a selection input from priming or
        -- executing an Action Ability; raw input remains readable here.
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        restoreActionRoutes()
        restoreNativeFinisherSelection()
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
    updateAttackControlRouting(buttons, player)
    if faulted then
        restoreAllPatches()
        return
    end

    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local nativeShortcutHeld = (buttons & (BUTTON.L1 | BUTTON.R1)) ~= 0
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
        and not l2Held and not r2Held and not nativeShortcutHeld then
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
                    local suspendedSynthetic = player.airborne
                        and action.airBridge == true
                        and (player.airborneState == 1
                            or player.airborneState == 2)
                    if suspendedSynthetic then
                        -- The prior shoulder frame disabled native X and kept a
                        -- harmless aerial prime. Replace it now: fake-ground must
                        -- exist before KH1 consumes the synthetic Attack edge.
                        restoreActionRoutes()
                    end
                    actionConsumed = requestActionAbility(
                        player, selectedSlot, action, not suspendedSynthetic)
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
    if acceptedKind == "normal" then
        -- A completed link opens a new animation, but a Cross pressed on its
        -- first frame must still pass the late-window test below.
        actionConsumed = false
    end

    if CONFIG.nativeNormalAttacks then
        -- Ordinary Cross input is never consumed, buffered or routed here.
        -- Only a modifier-free edge in the safe tail of CB/CE is converted
        -- into a fresh native Attack after releasing the completed finisher.
        if not actionConsumed and crossPressed
            and not l2Held and not r2Held and not nativeShortcutHeld
            and not finisherRequested then
            actionConsumed = requestNativeFinisherRestart(player)
        end
    else
    local physicalCrossConsumedByFreshNative = crossPressed
        and acceptedKind ~= "normal"
        and (isGroundNormalContext(player) or isAirNormalContext(player))
        and player.control ~= 0x03
        and player.time <= 0.5

    local normalPipelineBusy = transitionKind == "normal"
        or deferredLinkKind == "normal"
    local aerialFinisherActive = player.airborne
        and player.animation == 0xCE
    local aerialFinisherRestartReady = aerialFinisherActive
        and player.time >= CONFIG.airFinisherRestartTime
    local normalFinisherLocked = (not player.airborne
            and player.animation == 0xCB)
        or (aerialFinisherActive and not aerialFinisherRestartReady)
    local normalInputSuppressed = crossPressed
        and (normalPipelineBusy or attackBufferFrames > 0
            or normalFinisherLocked)
        and not finisherRequested and finisherBufferFrames <= 0
        and ReadByte(ADDRESS.commandMenuSlot) == 0
    if normalInputSuppressed then
        if attackBufferFrames > 0 then
            log("Cross ignored: this animation already owns its next link.")
        elseif normalPipelineBusy then
            log("Cross ignored: the current combo link is transitioning.")
        else
            log("Cross ignored: combo finisher must end first.")
        end
    end

    if not actionConsumed then
        local normalInputRequested = crossPressed
            and not normalInputSuppressed
        if normalInputRequested and not finisherRequested
            and finisherBufferFrames <= 0
            and ReadByte(ADDRESS.commandMenuSlot) == 0 then
            clearFinisherBuffer()
            -- LuaBackend can observe the same physical Cross only after KH1
            -- has already used it to enter a fresh normal animation. Treating
            -- that edge as a buffer as well made one press produce two attacks
            -- on both the ground and aerial paths.
            local nativeCrossAlreadyConsumed =
                physicalCrossConsumedByFreshNative

            if aerialFinisherRestartReady then
                clearAttackBuffer()
                if queueAttackAfterRelease(
                        player, "normal", nil, 0xCC) then
                    log(string.format(
                        "Aerial finisher cycle requested: "
                        .. "CE -> CC at time=%.2f.", player.time))
                end
            elseif nativeCrossAlreadyConsumed then
                clearAttackBuffer()
                if not player.airborne then
                    groundChainFrames = CONFIG.groundChainMemoryFrames
                end
                log(string.format(
                    "native Cross edge consumed by fresh 0x%02X; "
                    .. "next link not queued.", player.animation))
            else
                local normalInputWindowOpen = true
                local inputOpensAt = nil
                local inputWindowName = nil
                if isGroundNormalContext(player) then
                    local linkTime = CANCEL_WINDOW[player.animation]
                    inputOpensAt = math.max(
                        0.0, linkTime - CONFIG.groundLinkPrebufferLead)
                    inputWindowName = "ground"
                elseif isAirNormalContext(player) then
                    local linkTime = CANCEL_WINDOW[player.animation]
                    inputOpensAt = math.max(
                        0.0, linkTime - CONFIG.airLinkPrebufferLead)
                    inputWindowName = "aerial"
                end
                if inputOpensAt ~= nil then
                    normalInputWindowOpen = player.time >= inputOpensAt
                end
                if not normalInputWindowOpen then
                    log(string.format(
                        "Cross ignored before %s link prebuffer: "
                        .. "anim=0x%02X time=%.2f opens=%.2f.",
                        inputWindowName, player.animation,
                        player.time, inputOpensAt))
                end

                if normalInputWindowOpen then
                    local comboPrepared = true
                    local desiredPosition = nil
                    local expectedAnimation = nil
                    if player.airborne then
                        comboPrepared, desiredPosition,
                            expectedAnimation = prepareNormalAirAttack(player)
                        if comboPrepared then
                            log(string.format(
                                "Aerial Cross input accepted: expected=0x%02X",
                                expectedAnimation))
                        end
                    else
                        local maximum
                        comboPrepared, desiredPosition, maximum,
                            expectedAnimation = prepareNormalGroundAttack(
                                player, chainWasArmed)
                        if comboPrepared then
                            groundChainFrames =
                                CONFIG.groundChainMemoryFrames
                            log(string.format(
                                "Cross input accepted: combo=%d max=%d "
                                .. "expected=0x%02X",
                                desiredPosition, maximum,
                                expectedAnimation))
                        end
                    end

                    if CONFIG.attackBuffer and isAttackContext(player)
                        and (player.airborne or comboPrepared) then
                        queueAttackBuffer(
                            player, desiredPosition, expectedAnimation)
                    end
                end
            end
        end

        updateFinisherBuffer(player)
        if finisherBufferFrames <= 0 then
            updateAttackBuffer(player)
        end
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
        updateAttackControlRouting(buttons, player)
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
        HUD.finishDirectEdit("script exit", 0)
        HUD.hideOwned()
        restoreAllPatches()
    end
end
