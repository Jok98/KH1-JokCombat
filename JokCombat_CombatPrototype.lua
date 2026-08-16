LUAGUI_NAME = "JokCombat"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra / KSX"
LUAGUI_DESC = "Native Cross combo, Musou-style Y Action/Limit families, one-cycle double jump, second R2 magic page and universal defense."

-- JokCombat v2.2.0 for the current Steam Global executable.
-- Critical Mix was used as an authorized technical reference. This script is
-- intentionally limited to combat/input state and does not persist changes to
-- story flags, rewards, inventory, AP, levels, worlds, chests, or synthesis.
-- Four Musou combo Limits are exposed through KH1's native Reaction/Limit
-- dispatcher. Their MP state and dispatcher bytes are borrowed only while the
-- selected combo Limit is owned, then restored conditionally before normal
-- play resumes.

local CONFIG = {
    enabled = true,
    debugLog = true,

    -- KH1 owns every ordinary Cross input. Native Combo Master, Combo Plus
    -- and Air Combo Plus therefore decide whiff continuation, combo length,
    -- intermediate attacks and finishers. The legacy routed-normal pipeline
    -- remains below only as a disabled rollback path.
    nativeNormalAttacks = true,

    -- KH1's native Attack selector enables either Aerial Sweep D6 or the
    -- ordinary aerial hit CD when a grounded target vector crosses its height
    -- threshold. Bypass only that high-target branch while Sora is grounded;
    -- the complete native aerial selector is restored after a real jump.
    intentionalAirEntry = true,

    -- Give only KH1's seven native physical combo animations a light speed
    -- increase. Action Abilities, Limits, magic, defense, jumps and locomotion
    -- retain their authored playback speed. The controller snapshots the live
    -- value, applies a multiplier, and restores only its exact owned value.
    normalAttackSpeedup = true,
    normalAttackSpeedMultiplier = 1.15,

    -- A confirmed native normal hit contributes one process-local charge.
    -- Ten charges restore exactly 1 MP, capped by Sora's live battle-slot max.
    -- Whiffs, Y Actions, Limits, defense and multiple targets in one animation
    -- do not add charges; hits made while MP is full are never banked.
    meleeMPRecovery = true,
    meleeHitsPerMP = 10,

    -- Modifier-free Triangle selects the Musou-style Strong/C2/C3/C4/C5
    -- family. Eight ground Action Abilities and four native Limits form
    -- five standard role-specific branches; Cross after a named move closes
    -- the family and remains a physical continuation. The pure Y family owns
    -- Slapshot -> Vortex -> Blitz -> Zantetsuken -> Ars Arcanum; C4 opens
    -- Strike Raid directly and C5 owns Gravity Break -> Ragnarok.
    -- The failed reverse-magic adapter is retired: normal menu/R1 magic remains
    -- entirely native. The three Limit leaves and direct C4 root use the
    -- validated native Reaction dispatcher; no Limit animation, hitbox or
    -- follow-up is imitated. Trinity Limit is excluded because its native
    -- sequence owns Donald and Goofy.
    branchCombos = true,
    branchActionAbilities = true,
    branchLimits = true,
    branchInputTimeoutFrames = 150,
    -- A completed terminal special preserves only its logical family depth.
    -- The next real ground A must enter a native C8-CA attack before that
    -- virtual depth may select the following Y family. No KH1 combo counter is
    -- written, and C5 remains terminal.
    branchDepthCarryFrames = 360,
    branchDepthConfirmFrames = 30,
    -- A neutral Y is shared with Talk/Examine/Save. Leave its physical edge
    -- native, then wait two released frames before opening Strong so KH1 can
    -- publish a contextual Reaction first. A following A always cancels this
    -- short arbitration and remains available as a native confirmation.
    neutralTriangleGraceFrames = 2,
    -- While KH1 owns a normal Cross string, reuse the native Command Menu as
    -- a read-only guide for the current Musou-style family. Named Action
    -- Abilities are dispatched only by Triangle/Y; Cross/A always remains a
    -- physical continuation. The existing overlay master toggle controls it.
    comboGuide = true,

    attackBuffer = true,
    crossGroundFinisher = true,
    -- Parked until the Steam Attack dispatcher has a validated force branch.
    -- Triangle remains completely native and never arms a delayed finisher.
    triangleGroundFinisher = false,
    groundToAirJumpBranch = true,
    -- A real ground jump arms one additional Kinetic Step jump. The second
    -- press may cancel any ordinary airborne action, then restarts the aerial
    -- combo from its first hit. Landing is the only normal way to refill it.
    -- This is the authorized Critical Mix Multi Jump route: only byte zero of
    -- the eight air-action entries is borrowed, then a real Attack command
    -- enters animation 0x0F and a bounded vertical lift reproduces its jump.
    secondJump = true,
    secondJumpArmFrames = 45,
    secondJumpRouteFrames = 60,
    secondJumpLiftAmount = 30.0,
    secondJumpLiftEndTime = 25.0,
    secondJumpSpeedDivisor = 1.1,
    -- High Jump keeps native variable-height B ownership. KH1 already maps
    -- learned Superglide to held Square in midair, so the mod leaves that input
    -- completely vanilla and limits its forced Square Dodge to the ground.
    nativeAirSuperglideOnSquare = true,
    -- Slow the positive position delta of vanilla Fall 0x06 after either the
    -- first jump or Kinetic Step. The same controller owns both phases, so the
    -- factor is never applied twice after the second jump. Aerial attacks use
    -- the separate profile below.
    airFallBrakeFactor = 0.45,
    -- Ordinary aerial attacks retain only 25% of their downward transform
    -- delta. Upward motion is untouched. Native movement Actions D1/D6 are
    -- deliberately excluded so Hurricane Blast and Aerial Sweep keep their
    -- authored trajectories.
    airAttackFallBrake = true,
    airAttackFallBrakeFactor = 0.25,
    defensiveCancels = true,
    universalGuardCancel = true,
    universalDodgeCancel = true, -- any ordinary ground action; never airborne
    guardOnL2Circle = true,
    fixedDodgeOnSquare = true, -- ground X; airborne X is native Superglide
    -- Counterattack is contextual rather than part of an offensive branch.
    -- A real 0x10 Guard-connect event opens one short physical Cross window.
    guardCounterAttemptFrames = 120,
    guardCounterWindowFrames = 35,
    -- R2 owns a second native three-slot magic page. KH1 still performs the
    -- complete cast (learned tier, MP, target, animation, VFX and effect).
    r2MagicShortcuts = true,
    r2MagicShortcutMenu = true,
    -- While the native R2 page is being edited, tint the selected spell name
    -- gold. The renderer extension is signed and completely restored outside
    -- that page; L1 and every other KH1 text path retain their native colors.
    r2MagicShortcutHighlight = true,
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
    -- Airborne branches use only records that KH1 owns natively in the air.
    -- Ground-native Action Abilities are never converted through fake-ground.
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
local VERSION = "v2.2.0"

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    dpadButtons = 0x22C9300,
    rawButtons = 0x22C9301,
    -- Steam Global's controller path calls the native edge-state builder here.
    -- JokCombat redirects that one call through a signed tail cave so an armed
    -- physical R2 becomes a complete native L1 Shortcut event (held, pressed
    -- and released) before KH1's dispatcher sees it.
    nativeShortcutInputBridge = 0x28B19A,
    nativeShortcutInputCave = 0x3ADED8,
    -- Control layers retained for normal input recovery and one-version cleanup
    -- of a stale pre-v0.10.6 combo-magic journal.
    l2ControlMap = 0x22C9340,
    shortcutControlSelector = 0x22C9342,
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
    -- Steam Global's native Auto-Reaction input level sits 0x1C bytes after
    -- triggerMenu2. It is never used as a free-running macro: the Limit
    -- adapter may hold it only after one real final-Y edge, with ownership
    -- recorded in the existing recovery journal first.
    autoReaction = 0x232DDE0,
    defenseAbilityFlags = 0x2D5EC10,

    -- Native three-slot Shortcut page. The first byte is also retained for
    -- migration of the retired combo-magic adapter.
    -- Shortcut Sets resolves this owner pointer from Steam's unique Shortcut
    -- writer signature. Its live object owns the real three-slot page at +844;
    -- learned magic levels sit 0x3B2 bytes before that page.
    nativeShortcutStoragePointer = 0x2868BA0,
    magicLevelBase = 0x2DE97F2,
    nativeShortcutTriangle = 0x2DE9BA4,
    nativeShortcutSquare = 0x2DE9BA5,
    nativeShortcutCross = 0x2DE9BA6,

    -- Migration-only reload journal written by v0.9.1-v0.10.5.
    -- v0.12.0+ reuses the same reserved block with a distinct Limit signature;
    -- the legacy reader ignores it and the native Limit reader restores it.
    magicRecovery = 0x2DB79B0,

    -- Native Limit adapter. The Reaction-command global has a regional
    -- Steam shift of +0x3380; its two writers and enable masks have a code
    -- shift of +0x47D0. Their exact bytes were verified against the supported
    -- executable before this adapter was enabled. The four ordinary Limit
    -- costs are contiguous shorts in the high data tables and use the separately
    -- validated +0x3980 shift. The old Trinity adapter remains recoverable from
    -- its journal but is no longer exposed by the active combo map.
    sonicBladeCost = 0x2D22E8C,
    arsArcanumCost = 0x2D22E8E,
    strikeRaidCost = 0x2D22E90,
    ragnarokCost = 0x2D22E92,
    reactionCommandId = 0x528917,
    reactionEnableFlag = 0x294333,
    reactionEnableFlag2 = 0x29433F,
    reactionWriter = 0x294304,
    reactionWriter2 = 0x29492E,
    world = 0x234045C,
    -- Read-only Steam Global port of Critical Mix's global game-speed float.
    -- Live validation on the supported executable returned exactly 1.0.
    gameSpeed = 0x233FBCC,
    partyMember1 = 0x2DE97DF,
    partyMember2 = 0x2DE97E0,
    battleSlotBase = 0x2D50000,

    -- Steam ports of Critical Mix's transient combo byte and Sora's active
    -- ground-combo length. These do not point to the save file.
    comboPosition = 0x296B221,
    -- Same validated +0x3980 Steam shift as comboPosition: Critical Mix uses
    -- EGS 0x29678B0 and checks 0x10 only when Guard animation D4 connects.
    -- JokCombat observes this byte read-only; it never clears or forces it.
    connectCounter = 0x296B230,
    maxGroundComboLength = 0x2D5CCE4,
    maxAirComboLength = 0x2D5CCE5,

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
    -- Migration-only recovery for the retired ground-animation-in-air bridge.
    -- v0.9.6 never arms 0x73; initialization still restores a stale older build
    -- to vanilla 0x74 before enabling the native-air-only policy.
    airGroundActionBranch = 0x2A376D,   -- 74 normal, 73 bridged
    -- Native high-target Attack selector. At this point candidate 0 is D6
    -- (Aerial Sweep) and candidate 1 is CD (ordinary aerial hit). The signed
    -- runtime patch jumps to the existing ground-candidate scan at 0x2A71DB;
    -- it is installed only while Sora is genuinely grounded.
    groundAirTargetSelector = 0x2A70D5,
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
    verticalPosition = 0x014,
    slotReference = 0x06C,
    airborneState = 0x070,
    animationId = 0x164,
    secondaryAnimationId = 0x168,
    animationTime = 0x16C,
    animationSpeed = 0x284,
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

-- Only Sora combat Action Abilities are exposed. Guard and ground Dodge Roll
-- stay on their fixed controls; support, shared and special/Limit abilities never enter
-- this catalog. The animation map is adapted from the authorized Critical Mix
-- action dictionary; every complete record below was read from and signature-
-- checked against the Steam action table. Gameplay effects and contextual
-- requirements still need live validation one ability at a time.
local ACTION_CATALOG = {
    { id = "none", name = "None", context = "none" },
    { id = "slapshot", name = "Slapshot", context = "ground",
        animation = 0xCF, finisher = false,
        recordAddress = ADDRESS.groundComboSlapshot,
        record = { 0xCF, 0x00, 0x05, 0xFF, 0x28, 0x51, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "sliding_dash", name = "Sliding Dash", context = "ground",
        animation = 0xD0, finisher = false,
        recordAddress = ADDRESS.groundComboSlide,
        record = { 0xD0, 0x00, 0x05, 0xFF, 0xB8, 0x50, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x02, 0x05, 0x06, 0x04,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "vortex", name = "Vortex", context = "ground",
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
    { id = "counterattack", name = "Counterattack", context = "ground",
        animation = 0xD5, finisher = false, contextual = true,
        recordAddress = ADDRESS.actionRecordCounterattack,
        record = { 0xD5, 0x00, 0x05, 0xFF, 0x18, 0x4E, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x03, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "blitz", name = "Blitz", context = "ground",
        animation = 0xD2, finisher = true,
        recordAddress = ADDRESS.actionRecordBlitz,
        record = { 0xD2, 0x00, 0x05, 0xFF, 0x38, 0x4D, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x1B, 0x05, 0x06, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "hurricane_blast", name = "Hurricane Blast", context = "both",
        animation = 0xD1, finisher = true,
        recordAddress = ADDRESS.airComboHurricane,
        record = { 0xD1, 0x00, 0x05, 0xFF, 0x48, 0x50, 0x00, 0x00,
            0x00, 0x00, 0x20, 0x42, 0x1B, 0x05, 0x06, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "ripple_drive", name = "Ripple Drive", context = "ground",
        animation = 0xD7, finisher = true,
        recordAddress = ADDRESS.actionRecordRippleDrive,
        record = { 0xD7, 0x00, 0x05, 0xFF, 0x88, 0x4E, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x17, 0x05, 0x17, 0x05,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "stun_impact", name = "Stun Impact", context = "ground",
        animation = 0xD8, finisher = true,
        recordAddress = ADDRESS.actionRecordStunImpact,
        record = { 0xD8, 0x00, 0x05, 0xFF, 0xF8, 0x4E, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x1B, 0x05, 0x1B, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "gravity_break", name = "Gravity Break", context = "ground",
        animation = 0xD9, finisher = true,
        recordAddress = ADDRESS.actionRecordGravityBreak,
        record = { 0xD9, 0x00, 0x05, 0xFF, 0x68, 0x4F, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x17, 0x05, 0x17, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
    { id = "zantetsuken", name = "Zantetsuken", context = "ground",
        animation = 0xDA, finisher = true,
        recordAddress = ADDRESS.actionRecordZantetsuken,
        record = { 0xDA, 0x00, 0x05, 0xFF, 0xD8, 0x4F, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x18, 0x05, 0x18, 0x06,
            0x00, 0x00, 0x00, 0x00 } },
}

local ACTION_BY_ID = {}
local FINISHER_ACTION_ANIMATION = {}
local ROUTE_RECORD_BY_ANIMATION = {}
for _, action in ipairs(ACTION_CATALOG) do
    ACTION_BY_ID[action.id] = action
    if action.animation ~= nil then
        if action.finisher then
            FINISHER_ACTION_ANIMATION[action.animation] = true
        end
        ROUTE_RECORD_BY_ANIMATION[action.animation] = action.record
    end
end

local SHORTCUT_SLOTS = {
    { id = "r2_triangle", label = "R2 + Y", modifier = BUTTON.R2,
        face = BUTTON.TRIANGLE, faceName = "Y",
        address = ADDRESS.nativeShortcutTriangle },
    { id = "r2_square", label = "R2 + X", modifier = BUTTON.R2,
        face = BUTTON.SQUARE, faceName = "X",
        address = ADDRESS.nativeShortcutSquare },
    { id = "r2_cross", label = "R2 + A", modifier = BUTTON.R2,
        face = BUTTON.CROSS, faceName = "A",
        address = ADDRESS.nativeShortcutCross },
}

local SHORTCUT_SLOT_BY_ID = {}
for _, slot in ipairs(SHORTCUT_SLOTS) do
    SHORTCUT_SLOT_BY_ID[slot.id] = slot
end

local LOADOUT_MENU_GROUPS = {
    r2 = {
        id = "r2",
        label = "R2",
        openDirection = "Right",
        slots = {
            SHORTCUT_SLOT_BY_ID.r2_triangle,
            SHORTCUT_SLOT_BY_ID.r2_square,
            SHORTCUT_SLOT_BY_ID.r2_cross,
        },
    },
}

local DEFAULT_LOADOUT = {
    -- Used only before KH1 has exposed a loaded save. On the first usable R2
    -- hold these are replaced by learned spells absent from the live L1 page.
    r2_triangle = "cure",
    r2_square = "gravity",
    r2_cross = "aero",
}

-- Kept global because the main Lua chunk is close to Lua 5.3's 200-local
-- ceiling. These IDs are the exact values stored by KH1's native Shortcut
-- menu; 0xFF is an empty slot.
JokCombatR2Shortcut = {
    catalog = {
        { id = "fire", name = "Fire", index = 0 },
        { id = "blizzard", name = "Blizzard", index = 1 },
        { id = "thunder", name = "Thunder", index = 2 },
        { id = "cure", name = "Cure", index = 3 },
        { id = "gravity", name = "Gravity", index = 4 },
        { id = "stop", name = "Stop", index = 5 },
        { id = "aero", name = "Aero", index = 6 },
        { id = "none", name = "-", index = 0xFF },
    },
    byId = {},
    byIndex = {},
    recoverySignature = 0x313043534D32524A, -- "JR2MSC01"
    recoveryMarker = 0xC4,
    active = false,
    failedKey = nil,
    needsInitialSeed = false,
    addressResolved = false,
}

-- Signed native R2 -> Shortcut edge bridge. The five-byte call site is stock
-- KH1 code; the 28-byte tail cave is zero padding at the end of Steam Global's
-- executable .text section. The cave checks JokCombat's recovery marker, maps
-- only the controller shoulder nibble R2 -> L1, then tail-jumps to KH1's
-- original edge builder. Physical raw input stays R2, so JokCombat can retain
-- page ownership while KH1 receives coherent held/pressed/released L1 states.
--
-- The two older bridge layouts are recovery-only and are never installed.
JokCombatR2NativeBridge = {
    address = ADDRESS.nativeShortcutInputBridge,
    normal = {
        0xE8, 0x91, 0x02, 0x00, 0x00,
    },
    owned = {
        0xE8, 0x39, 0x2D, 0x12, 0x00,
    },
    caveAddress = ADDRESS.nativeShortcutInputCave,
    caveNormal = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    },
    caveOwned = {
        -- Compare JokCombat's recovery marker with C4.
        0x80, 0x3D, 0xD9, 0x9A, 0xA0, 0x02, 0xC4,
        -- If armed, map only DH's R2 shoulder nibble to L1.
        0x75, 0x0E, 0x88, 0xF0, 0x24, 0x0F, 0x3C, 0x02,
        0x75, 0x06, 0x80, 0xE6, 0xFD, 0x80, 0xCE, 0x04,
        -- Tail-jump to KH1's original edge-state builder.
        0xE9, 0x3C, 0xD5, 0xED, 0xFF,
    },
    preDispatchAddress = 0x18C870,
    preDispatchNormal = {
        0xE8, 0x3B, 0xE8, 0x0F, 0x00,
        0x83, 0x3D, 0x14, 0x47, 0x1B, 0x02, 0x00,
        0x0F, 0x28, 0x05, 0x2D, 0x01, 0x80, 0x02,
        0x0F, 0x28, 0x0D, 0x36, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x05, 0x1F, 0x3F, 0x1B, 0x02,
        0x0F, 0x28, 0x05, 0x38, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x0D, 0x21, 0x3F, 0x1B, 0x02,
        0x0F, 0x28, 0x0D, 0x3A, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x05, 0x23, 0x3F, 0x1B, 0x02,
        0x0F, 0x28, 0x05, 0x3C, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x0D, 0x25, 0x3F, 0x1B, 0x02,
    },
    preDispatchOwned = {
        0x8A, 0x05, 0x3F, 0x01, 0x80, 0x02,
        0x88, 0xC4, 0x80, 0xE4, 0x0F, 0x80, 0xFC, 0x02,
        0x75, 0x0A,
        0x24, 0xFD, 0x0C, 0x04,
        0x88, 0x05, 0x2B, 0x01, 0x80, 0x02,
        0xE8, 0x21, 0xE8, 0x0F, 0x00,
        0x83, 0x3D, 0xFA, 0x46, 0x1B, 0x02, 0x00,
        0x9C, 0x56, 0x57,
        0x48, 0x8D, 0x35, 0x10, 0x01, 0x80, 0x02,
        0x48, 0x8D, 0x3D, 0x09, 0x3F, 0x1B, 0x02,
        0xB9, 0x1C, 0x00, 0x00, 0x00,
        0xF3, 0x48, 0xA5, 0x5F, 0x5E, 0x9D,
        0xE9, 0x89, 0x00, 0x00, 0x00,
        0x90, 0x90, 0x90, 0x90,
    },
    legacyAddress = 0x18C87C,
    legacyNormal = {
        0x0F, 0x28, 0x05, 0x2D, 0x01, 0x80, 0x02,
        0x0F, 0x28, 0x0D, 0x36, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x05, 0x1F, 0x3F, 0x1B, 0x02,
        0x0F, 0x28, 0x05, 0x38, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x0D, 0x21, 0x3F, 0x1B, 0x02,
        0x0F, 0x28, 0x0D, 0x3A, 0x01, 0x80, 0x02,
        0x0F, 0x29, 0x05, 0x23, 0x3F, 0x1B, 0x02,
        0x0F, 0x28, 0x05, 0x3C, 0x01, 0x80, 0x02,
    },
    legacyOwned = {
        0x9C, 0x56,
        0x48, 0x8D, 0x35, 0x2B, 0x01, 0x80, 0x02,
        0x48, 0x8D, 0x3D, 0x24, 0x3F, 0x1B, 0x02,
        0xB9, 0x1C, 0x00, 0x00, 0x00,
        0xF3, 0x48, 0xA5, 0x5E,
        0x8A, 0x05, 0x1A, 0x3F, 0x1B, 0x02,
        0xA8, 0x02, 0x74, 0x0A,
        0x24, 0xFD, 0x0C, 0x04,
        0x88, 0x05, 0x0C, 0x3F, 0x1B, 0x02,
        0x9D, 0xE9, 0x91, 0x00, 0x00, 0x00,
        0x90, 0x90, 0x90, 0x90, 0x90,
    },
    ready = false,
    ownedNow = false,
    installLogged = false,
    failureLogged = false,
}

-- KH1's Shortcut text wrapper accepts one grayscale byte and therefore has no
-- native concept of an editor cursor. The row renderer does, however, draw Y,
-- X and A separately. These two signed hooks extend only that call path: the
-- selected row sends one private RGB sentinel and the text wrapper expands it
-- to gold. Every other value follows the original three grayscale writes.
--
-- Both helpers live in untouched zero padding after the existing R2 input
-- cave. The row helper also requires the complete active R2 journal signature,
-- marker and owner byte, so physical L1 and inactive R2 pages cannot acquire
-- the highlight even if a stale selection byte remains in memory.
JokCombatR2ShortcutHighlight = {
    rowHookAddress = 0x27C09B,
    rowHookNormal = {
        0x45, 0x0F, 0x44, 0xCD, 0x0F, 0xB6, 0x0E,
    },
    rowHookOwned = {
        0xE8, 0x54, 0x1E, 0x13, 0x00, 0x90, 0x90,
    },
    rowCaveAddress = 0x3ADEF4,
    rowCaveNormal = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    },
    rowCaveOwned = {
        -- Preserve KH1's pressed/disabled shade and original magic ID load.
        0x45, 0x0F, 0x44, 0xCD,
        0x0F, 0xB6, 0x0E,
        -- Require "JR2M", marker C4 and owner tag 53.
        0x81, 0x3D, 0xAB, 0x9A, 0xA0, 0x02,
        0x4A, 0x52, 0x32, 0x4D,
        0x75, 0x20,
        0x80, 0x3D, 0xAA, 0x9A, 0xA0, 0x02, 0xC4,
        0x75, 0x17,
        0x80, 0x3D, 0xA9, 0x9A, 0xA0, 0x02, 0x53,
        0x75, 0x0E,
        -- BL is 1/2/4 for the three rows; +11 stores the selected mask.
        0x38, 0x1D, 0xA2, 0x9A, 0xA0, 0x02,
        0x75, 0x06,
        -- Private 0050D0FF sentinel: RGB FF/D0/50 (gold).
        0x41, 0xB9, 0xFF, 0xD0, 0x50, 0x00,
        0xC3,
    },
    textHookAddress = 0x27A944,
    textHookNormal = {
        0x44, 0x88, 0x4C, 0x24, 0x58,
        0x44, 0x88, 0x4C, 0x24, 0x59,
        0x44, 0x88, 0x4C, 0x24, 0x5A,
    },
    textHookOwned = {
        0xE8, 0xE7, 0x35, 0x13, 0x00,
        0x90, 0x90, 0x90, 0x90, 0x90,
        0x90, 0x90, 0x90, 0x90, 0x90,
    },
    textCaveAddress = 0x3ADF30,
    textCaveNormal = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    },
    textCaveOwned = {
        -- Only the private sentinel receives RGB; native grayscale values are
        -- copied exactly as before. CALL shifts the original stack by 8.
        0x41, 0x81, 0xF9, 0xFF, 0xD0, 0x50, 0x00,
        0x74, 0x10,
        0x44, 0x88, 0x4C, 0x24, 0x60,
        0x44, 0x88, 0x4C, 0x24, 0x61,
        0x44, 0x88, 0x4C, 0x24, 0x62,
        0xC3,
        0x44, 0x89, 0xC8,
        0x88, 0x44, 0x24, 0x60,
        0xC1, 0xE8, 0x08,
        0x88, 0x44, 0x24, 0x61,
        0xC1, 0xE8, 0x08,
        0x88, 0x44, 0x24, 0x62,
        0xC3,
    },
    ready = false,
    ownedNow = false,
    failureLogged = false,
}

for index, magic in ipairs(JokCombatR2Shortcut.catalog) do
    JokCombatR2Shortcut.byId[magic.id] = magic
    JokCombatR2Shortcut.byIndex[magic.index] = magic
    magic.catalogIndex = index
end

function JokCombatR2Shortcut.isLearned(magic)
    return magic ~= nil and magic.index ~= 0xFF
        and ReadByte(ADDRESS.magicLevelBase + magic.index) > 0
end

function JokCombatR2Shortcut.resolveNativeAddresses()
    JokCombatR2Shortcut.addressResolved = false
    local storage = ReadLong(ADDRESS.nativeShortcutStoragePointer)
    if storage < BASE_ADDR or storage >= BASE_ADDR + 0x2F91000 then
        ConsolePrint(string.format(
            "[JokCombat:r2-magic:fault] Shortcut storage pointer is invalid: 0x%X.",
            storage))
        return false
    end

    local triangle = storage - BASE_ADDR + 0x844
    local levelBase = triangle - 0x3B2
    if triangle < 0 or triangle + 2 >= 0x2F91000
        or levelBase < 0 or levelBase + 6 >= 0x2F91000 then
        ConsolePrint("[JokCombat:r2-magic:fault] resolved Shortcut storage "
            .. "falls outside the Steam module.")
        return false
    end
    for offset = 0, 2 do
        local value = ReadByte(triangle + offset)
        if value ~= 0xFF and (value < 0 or value > 6) then
            ConsolePrint(string.format(
                "[JokCombat:r2-magic:fault] resolved Shortcut slot %d has "
                    .. "invalid value 0x%02X.", offset + 1, value))
            return false
        end
    end
    for offset = 0, 6 do
        local level = ReadByte(levelBase + offset)
        if level < 0 or level > 3 then
            ConsolePrint(string.format(
                "[JokCombat:r2-magic:fault] resolved magic level %d has "
                    .. "invalid value 0x%02X.", offset, level))
            return false
        end
    end

    ADDRESS.nativeShortcutTriangle = triangle
    ADDRESS.nativeShortcutSquare = triangle + 1
    ADDRESS.nativeShortcutCross = triangle + 2
    ADDRESS.magicLevelBase = levelBase
    SHORTCUT_SLOT_BY_ID.r2_triangle.address = triangle
    SHORTCUT_SLOT_BY_ID.r2_square.address = triangle + 1
    SHORTCUT_SLOT_BY_ID.r2_cross.address = triangle + 2
    JokCombatR2Shortcut.addressResolved = true
    ConsolePrint(string.format(
        "[JokCombat] native Shortcut storage resolved: "
            .. "slots=0x%X levels=0x%X.", triangle, levelBase))
    return true
end

function JokCombatR2Shortcut.distinctLearnedDefaults()
    local native = {}
    for _, slot in ipairs(SHORTCUT_SLOTS) do
        local value = ReadByte(slot.address)
        if JokCombatR2Shortcut.validSlotValue == nil
            or JokCombatR2Shortcut.validSlotValue(value) then
            native[value] = true
        end
    end

    local defaults = {}
    for _, magic in ipairs(JokCombatR2Shortcut.catalog) do
        if #defaults < #SHORTCUT_SLOTS
            and JokCombatR2Shortcut.isLearned(magic)
            and not native[magic.index] then
            table.insert(defaults, magic.id)
        end
    end
    if #defaults == 0 then return nil end
    while #defaults < #SHORTCUT_SLOTS do
        table.insert(defaults, "none")
    end
    return defaults
end

function JokCombatR2Shortcut.nextSelectable(current, delta)
    local start = current ~= nil and current.catalogIndex or 1
    for step = 1, #JokCombatR2Shortcut.catalog do
        local index = ((start - 1 + delta * step)
            % #JokCombatR2Shortcut.catalog) + 1
        local magic = JokCombatR2Shortcut.catalog[index]
        if magic.index == 0xFF
            or JokCombatR2Shortcut.isLearned(magic) then
            return magic
        end
    end
    return JokCombatR2Shortcut.byId.none
end

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
    l2ControlMap = 0xFF,
    shortcutControlSelector = 0xFF,
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
    directEditIndex = { r2 = 1 },
    dpadReleaseLock = false,
    controlChordHeld = false,
    controlChordUsed = false,
    -- KH1 renders locked Summon as command 0x00. While the four-row Combo
    -- Guide owns all
    -- four face inputs, command 0x06 is borrowed only as a normal visual
    -- carrier for row four and is restored conditionally when the overlay ends.
    nativeFallbackCommandId = 0x06,
    nativeCommandBackup = nil,
    nativeRecoveryAddress = 0x2DB7940,
    nativeRecoverySignature = 0x31574F524E4B4F4A, -- "JOKNROW1"
    nativeCarrierSignature = 0x31444D43524B4A, -- "JKRCMD1\0"
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
    local learnedDefaults = JokCombatR2Shortcut.distinctLearnedDefaults()
    for index, slot in ipairs(SHORTCUT_SLOTS) do
        loadout[slot.id] = learnedDefaults ~= nil
            and learnedDefaults[index]
            or DEFAULT_LOADOUT[slot.id] or "none"
    end
end

local function loadActionLoadout()
    resetLoadoutToDefaults()
    loadoutPath = joinPath(SCRIPT_PATH, "JokCombat_MagicShortcuts.cfg")

    local file = io.open(loadoutPath, "r")
    if file == nil then
        -- Preserve the user's overlay preference when migrating from the
        -- retired Action Ability page, but never import its ability IDs.
        local legacy = io.open(joinPath(
            SCRIPT_PATH, "JokCombat_ActionLoadout.cfg"), "r")
        if legacy ~= nil then
            for line in legacy:lines() do
                local value = line:match(
                    "^%s*action_overlay%s*=%s*(%a+)%s*$")
                if value == "true" or value == "false" then
                    HUD.enabled = value == "true"
                end
            end
            legacy:close()
        end
        JokCombatR2Shortcut.needsInitialSeed = true
        log("R2 magic shortcut file not found; the first gameplay hold will "
            .. "seed a page distinct from L1.")
        return
    end

    JokCombatR2Shortcut.needsInitialSeed = false
    local formatVersion = 0
    local accepted = 0
    for line in file:lines() do
        local slotId, actionId = line:match(
            "^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
        if slotId == "format_version" then
            formatVersion = tonumber(actionId) or 0
        elseif slotId == "action_overlay"
            and (actionId == "true" or actionId == "false") then
            HUD.enabled = actionId == "true"
        elseif SHORTCUT_SLOT_BY_ID[slotId] ~= nil
            and JokCombatR2Shortcut.byId[actionId] ~= nil then
            loadout[slotId] = actionId
            accepted = accepted + 1
        end
    end
    file:close()

    -- The first R2 prototype wrote Fire/Blizzard/Thunder before its D-pad
    -- editor could ever become eligible. Treat only that exact unversioned
    -- preset as generated legacy data; any versioned or customized file is
    -- authoritative and is never rewritten automatically.
    local legacyDuplicate = loadout.r2_triangle == "fire"
        and loadout.r2_square == "blizzard"
        and loadout.r2_cross == "thunder"
    local invalidEmptyPage = loadout.r2_triangle == "none"
        and loadout.r2_square == "none"
        and loadout.r2_cross == "none"
    if formatVersion < 3 and (legacyDuplicate or invalidEmptyPage) then
        JokCombatR2Shortcut.needsInitialSeed = true
        log("invalid pre-v3 R2 magic preset detected; it will be replaced "
            .. "from the resolved native Shortcut data.")
    end
    log(string.format("loaded R2 magic shortcuts: %d valid slot(s).",
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

    file:write("# JokCombat R2 native magic shortcuts\n")
    file:write("# R2+Y / R2+X / R2+A; B remains jump or Kinetic Step.\n")
    file:write("# D-pad Up/Down selects; Left/Right changes the spell.\n")
    file:write("# action_overlay controls the Combo Guide.\n")
    file:write("format_version=3\n")
    file:write("action_overlay=", HUD.enabled and "true" or "false", "\n")
    for _, slot in ipairs(SHORTCUT_SLOTS) do
        file:write(slot.id, "=", loadout[slot.id] or "none", "\n")
    end
    file:close()
    log("R2 magic shortcuts saved to " .. loadoutPath)
    JokCombatR2Shortcut.needsInitialSeed = false
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
            HUD.writeNativeRecovery(
                HUD.nativeTokenBackups, HUD.nativeCommandBackup)
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
    local magic = JokCombatR2Shortcut.byId[loadout[slot.id]]
        or JokCombatR2Shortcut.byId.none
    return string.format("[%s] %s", slot.faceName, magic.name)
end

function HUD.overlayEntries(groupId)
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

function HUD.writeNativeRecovery(patches, commandPatch)
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
    if commandPatch ~= nil then
        -- This secondary signed record ends before the separate recovery block
        -- at +0x70. The primary marker is still published last below.
        WriteLong(HUD.nativeRecoveryAddress + 0x48,
            commandPatch.menuObject)
        WriteByte(HUD.nativeRecoveryAddress + 0x50,
            commandPatch.original)
        WriteByte(HUD.nativeRecoveryAddress + 0x51,
            commandPatch.patched)
        WriteByte(HUD.nativeRecoveryAddress + 0x52, 0x17)
        WriteByte(HUD.nativeRecoveryAddress + 0x53, 0xC6)
        WriteLong(HUD.nativeRecoveryAddress + 0x40,
            HUD.nativeCarrierSignature)
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
    local carrierRestored = false
    if ReadLong(HUD.nativeRecoveryAddress + 0x40)
            == HUD.nativeCarrierSignature
        and ReadByte(HUD.nativeRecoveryAddress + 0x52) == 0x17
        and ReadByte(HUD.nativeRecoveryAddress + 0x53) == 0xC6 then
        local menuObject = ReadLong(HUD.nativeRecoveryAddress + 0x48)
        local original = ReadByte(HUD.nativeRecoveryAddress + 0x50)
        local patched = ReadByte(HUD.nativeRecoveryAddress + 0x51)
        if menuObject >= BASE_ADDR
            and menuObject < BASE_ADDR + HUD.moduleSize
            and ReadByte(menuObject + 0x17, true) == patched then
            WriteByte(menuObject + 0x17, original, true)
            carrierRestored = true
        end
    end
    HUD.clearNativeRecovery()
    if restored > 0 or commandRestored or recordRestored or summonRestored
        or selectionRestored or carrierRestored or rowLoopRestored then
        log(string.format("Command Menu recovery: labels=%d%s%s%s%s%s%s.",
            restored,
            commandRestored and " carrier=restored" or "",
            recordRestored and " record=restored" or "",
            summonRestored and " summon-slot=restored" or "",
            selectionRestored and " cursor=restored" or "",
            carrierRestored and " row4=restored" or "",
            rowLoopRestored and " row-loop=restored" or ""))
    end
    return restored > 0 or commandRestored or recordRestored or summonRestored
        or selectionRestored or carrierRestored or rowLoopRestored
end

function HUD.restoreNativeRows()
    local restored = 0
    for _, patch in ipairs(HUD.nativeTokenBackups or {}) do
        if (ReadInt(patch.address) & 0xFFFFFFFF) == patch.patched then
            WriteInt(patch.address, patch.original)
            restored = restored + 1
        end
    end
    local commandPatch = HUD.nativeCommandBackup
    if commandPatch ~= nil
        and ReadByte(commandPatch.address, true) == commandPatch.patched then
        WriteByte(commandPatch.address, commandPatch.original, true)
        restored = restored + 1
    end
    HUD.nativeTokenBackups = {}
    HUD.nativeCommandBackup = nil
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

function HUD.showOverlay(groupId, suppliedEntries, suppliedLabel)
    if not CONFIG.actionLoadoutOverlay then return false end
    if not CONFIG.actionLoadoutPrompt then return false end
    -- The native-row overlay only borrows the four text buffers; it does not
    -- display either notification box. Requiring their color-pointer layout
    -- made the Combo Guide disappear when KH1 had initialized those dormant
    -- boxes differently. The ownership check below is the relevant safety
    -- condition: no text is written while either box is actually in use.
    local group = LOADOUT_MENU_GROUPS[groupId]
    local entries = suppliedEntries or HUD.overlayEntries(groupId)
    local groupLabel = suppliedLabel
        or (group ~= nil and group.label or groupId)
    if entries == nil or #entries ~= 4 then return false end

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
    local activeCommandPatch = HUD.nativeCommandBackup
    if activeCommandPatch ~= nil
        and activeCommandPatch.address == menuObject + 0x17
        and commands[4] == activeCommandPatch.patched then
        commands[4] = activeCommandPatch.original
    end
    -- A real four-row root may expose locked Summon as command 0x00. The row
    -- already exists visually, so borrow a normal command only while the R2
    -- overlay owns it. Only 0xFF means KH1 published no fourth row at all.
    local visibleCount = commands[4] == 0xFF and 3 or 4
    local displayCommands = {
        commands[1], commands[2], commands[3], commands[4],
    }
    local commandPatch = nil
    if visibleCount == 4
        and (commands[4] == 0x00 or commands[4] == 0x36) then
        displayCommands[4] = HUD.nativeFallbackCommandId
        commandPatch = {
            address = menuObject + 0x17,
            menuObject = menuObject,
            original = commands[4],
            patched = displayCommands[4],
        }
    end
    local signature = string.format("%s|%X|%02X%02X%02X%02X|%s",
        groupId, menuObject, commands[1], commands[2], commands[3],
        commands[4], table.concat(entries, "|"))
    if HUD.overlayGroup == groupId and HUD.overlaySignature == signature then
        local stillPatched = #HUD.nativeTokenBackups == visibleCount
        for _, patch in ipairs(HUD.nativeTokenBackups) do
            stillPatched = stillPatched
                and (ReadInt(patch.address) & 0xFFFFFFFF) == patch.patched
        end
        if commandPatch ~= nil then
            stillPatched = stillPatched and activeCommandPatch ~= nil
                and activeCommandPatch.address == commandPatch.address
                and activeCommandPatch.original == commandPatch.original
                and activeCommandPatch.patched == commandPatch.patched
                and ReadByte(commandPatch.address, true)
                    == commandPatch.patched
        else
            stillPatched = stillPatched and activeCommandPatch == nil
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
            HUD.commandMessageTokenAddress(displayCommands[index])
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
    if not HUD.writeNativeRecovery(patches, commandPatch) then
        return HUD.nativeOverlayFailure("recovery record rejected")
    end
    for _, patch in ipairs(patches) do
        WriteInt(patch.address, patch.patched)
    end
    if commandPatch ~= nil then
        WriteByte(commandPatch.address, commandPatch.patched, true)
    end
    HUD.nativeTokenBackups = patches
    HUD.nativeCommandBackup = commandPatch
    HUD.nativeFailureKey = nil
    HUD.overlayGroup = groupId
    HUD.overlaySignature = signature
    log(string.format(
        "native Command Menu labels active: %s ids=%02X/%02X/%02X/%02X visible=%d/4%s%s.",
        groupLabel, commands[1], commands[2], commands[3], commands[4],
        visibleCount, visibleCount == 3 and " (fourth row unavailable)" or "",
        commandPatch ~= nil and " row4-carrier=06" or ""))
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
    local action = pendingNativeFinisherAction()
    local selector = action ~= nil and NATIVE_FINISHER_SELECTOR[action.id]
        or nil
    local enable = selector ~= nil

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
    -- Kinetic Step borrows only the animation byte of this same table. Restore
    -- its owned hybrid first; the generic known-record check deliberately
    -- refuses otherwise unknown 0x0F/0x09 heads.
    if JokCombatAirJump ~= nil
        and JokCombatAirJump.restoreRoutes ~= nil then
        JokCombatAirJump.restoreRoutes("aerial route restore", true)
    end
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
    if player.airborne then
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
    if JokCombatR2NativeBridge ~= nil
        and JokCombatR2NativeBridge.restore ~= nil then
        JokCombatR2NativeBridge.restore("patch restore", true)
    end
    if JokCombatR2Shortcut ~= nil
        and JokCombatR2Shortcut.restore ~= nil then
        JokCombatR2Shortcut.restore("patch restore", true)
    end
    if JokCombatAttackSpeed ~= nil
        and JokCombatAttackSpeed.restore ~= nil then
        JokCombatAttackSpeed.restore("patch restore", true)
    end
    if JokCombatMeleeMP ~= nil and JokCombatMeleeMP.reset ~= nil then
        JokCombatMeleeMP.reset("patch restore", true, true)
    end
    if JokCombatAirJump ~= nil
        and JokCombatAirJump.restoreRoutes ~= nil then
        JokCombatAirJump.restoreRoutes("patch restore", true)
    end
    if JokCombatNativeLimit ~= nil
        and JokCombatNativeLimit.restore ~= nil then
        JokCombatNativeLimit.restore("patch restore", true)
    end
    if JokCombatBranch ~= nil and JokCombatBranch.reset ~= nil then
        JokCombatBranch.reset("patch restore", true, true)
    end
    if JokCombatGuardCounter ~= nil
        and JokCombatGuardCounter.reset ~= nil then
        JokCombatGuardCounter.reset("patch restore", true)
    end
    clearSyntheticAttackCommand(false)
    restoreActionRoutes()
    restoreNativeFinisherSelection()
    if JokCombatGroundIntent ~= nil
        and JokCombatGroundIntent.restore ~= nil then
        JokCombatGroundIntent.restore("patch restore", true)
    end
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
    restoreIfKnown(ADDRESS.shortcutControlSelector,
        NORMAL.shortcutControlSelector,
        { 0xFF, CONTROL_INDEX.TRIANGLE, 0x20 })
    restoreIfKnown(ADDRESS.l2ControlMap, NORMAL.l2ControlMap,
        { 0xFF, 0x01, CONTROL_INDEX.TRIANGLE, 0x21 })
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
    if modifier == BUTTON.R2 then return "r2" end
    return nil
end

function HUD.overlayEligible(buttons, player)
    return CONFIG.r2MagicShortcuts and CONFIG.actionLoadoutPrompt
        and HUD.enabled
        and HUD.shoulderGroup(buttons) ~= nil
        and player.control == 0x03 and player.animation <= 0x07
end

function HUD.finishDirectEdit(reason, dpad)
    HUD.restoreNativeSelection()
    if JokCombatR2ShortcutHighlight ~= nil
        and JokCombatR2ShortcutHighlight.select ~= nil then
        JokCombatR2ShortcutHighlight.select(0)
    end
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
            "[JokCombat:loadout] all three R2 magic slots restored to defaults.")
    end

    if not toggleHeld and HUD.controlChordHeld then
        if not HUD.controlChordUsed then
            HUD.finishDirectEdit("overlay toggle", dpad)
            HUD.enabled = not HUD.enabled
            HUD.hideOverlay()
            saveActionLoadout()
            log("Combo Guide overlay "
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
        if fourthCommand ~= 0xFF then
            return maximum
        end
    end
    return math.min(3, maximum)
end

function HUD.updateDirectEditor(buttons, dpad, player, controlConsumed)
    if dpad == 0 then HUD.dpadReleaseLock = false end
    local groupId = HUD.shoulderGroup(buttons)
    -- The editor belongs to the active native R2 page itself. It must not
    -- depend on the optional Combo Guide overlay or on the root Command Menu:
    -- once KH1 opens menu 5, those old Action-Loadout eligibility checks are
    -- no longer true and silently discarded every D-pad input.
    local eligible = CONFIG.r2MagicShortcutMenu
        and groupId == "r2" and JokCombatR2Shortcut.active
        and player ~= nil
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
        -- A new R2 hold starts from the first native Shortcut row.
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
        log(string.format("%s magic shortcut selected %s.",
            group.label, group.slots[index].label))
    end

    if leftStarted or rightStarted then
        local slot = group.slots[index]
        local current = JokCombatR2Shortcut.byId[loadout[slot.id]]
            or JokCombatR2Shortcut.byId.none
        local delta = leftStarted and -1 or 1
        local magic = JokCombatR2Shortcut.nextSelectable(current, delta)
        loadout[slot.id] = magic.id
        HUD.directEditActive = true
        HUD.directEditDirty = true
        HUD.overlaySignature = nil
        ConsolePrint(string.format("[JokCombat:loadout] %s -> %s",
            slot.label, magic.name))
    end
    JokCombatR2ShortcutHighlight.select(index)
    return true
end

function HUD.updateOverlay(buttons, player)
    local groupId = HUD.shoulderGroup(buttons)
    if groupId == "r2" then
        -- KH1's own three-row Shortcut panel is the R2 HUD. Do not draw a
        -- second Command Menu overlay on top of it.
        HUD.hideOverlay()
        return false
    end
    local show = HUD.overlayEligible(buttons, player)
        and (buttons & FACE_BUTTON_MASK) == 0
    if show then return HUD.showOverlay(groupId) end

    local guideEntries = nil
    if JokCombatBranch ~= nil
        and JokCombatBranch.guideEntries ~= nil then
        guideEntries = JokCombatBranch.guideEntries(player, buttons)
    end
    if guideEntries ~= nil then
        return HUD.showOverlay("guide", guideEntries, "Combo Guide")
    end

    HUD.hideOverlay()
    return false
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
    WriteByte(player.pointer + PLAYER.actionControl, 0x03, true)
    log(string.format(
        "%s cancel: anim=0x%02X secondary=0x%02X time=%.2f",
        label, player.animation, player.secondary, player.time))
end

-- KH1FM has one native High Jump ability, but no learnable Double Jump. The
-- authorized Critical Mix Multi Jump does not use Circle's state dispatcher:
-- it transiently replaces only the animation byte of every aerial action entry
-- with Kinetic Step 0x0F (FlyingCombo1 uses its native 0x09 recovery entry),
-- cancels the current action and sends one real Attack command. During the
-- first 25 animation-time units it applies the same bounded vertical lift as
-- Critical Mix. JokCombat adds strict ownership, full-record validation and a
-- single charge that is armed by a real first jump and restored only on land.
JokCombatAirJump = {
    enabled = false,
    available = false,
    consumed = false,
    wasAirborne = false,
    releaseRequired = false,
    groundRequestFrames = 0,
    routeFrames = 0,
    requestAge = 0,
    routeOwned = false,
    active = false,
    playerPointer = nil,
    sourceAnimation = nil,
    sourceTime = 0.0,
    sourceAirborneState = 0,
    routeFaultLogged = false,
    liftFaultLogged = false,
    fallBrakeArmed = false,
    lastVerticalPosition = nil,
    fallBrakeSamples = 0,
    fallBrakeRawMaximum = 0.0,
    fallBrakeCorrectedMaximum = 0.0,
    fallBrakeFaultLogged = false,
}

function JokCombatAirJump.routeAnimation(entry)
    if entry.name == "flyingCombo1" then return 0x09 end
    return 0x0F
end

function JokCombatAirJump.entryMatchesOwnedRoute(entry)
    if ReadByte(entry.address) ~= JokCombatAirJump.routeAnimation(entry) then
        return false
    end
    for offset = 1, #entry.record - 1 do
        if ReadByte(entry.address + offset) ~= entry.record[offset + 1] then
            return false
        end
    end
    return true
end

function JokCombatAirJump.restoreRoutes(reason, quiet)
    local restored = false
    local unexpected = false
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        local desired = JokCombatAirJump.routeAnimation(entry)
        if JokCombatAirJump.entryMatchesOwnedRoute(entry) then
            writeActionRecord(entry.address, entry.record)
            restored = true
        elseif ReadByte(entry.address) == desired then
            -- The head looks like our route but its remaining 19 bytes do not.
            -- Never overwrite a table another mod changed independently.
            unexpected = true
        end
    end
    JokCombatAirJump.routeOwned = false
    JokCombatAirJump.routeFrames = 0
    JokCombatAirJump.requestAge = 0

    if unexpected then
        JokCombatAirJump.enabled = false
        if not JokCombatAirJump.routeFaultLogged then
            log("[air-jump] an owned-looking 0x0F/0x09 route has foreign "
                .. "record bytes; second jump disabled without overwriting it.")
            JokCombatAirJump.routeFaultLogged = true
        end
        return false
    end
    if restored and reason ~= nil and not quiet then
        log("[air-jump] Kinetic Step air entries restored: " .. reason .. ".")
    end
    return true
end

function JokCombatAirJump.recordsCanonical()
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        if not actionRecordMatches(entry.address, entry.record) then
            return false, entry
        end
    end
    return true, nil
end

function JokCombatAirJump.initialize(airRouteReady)
    JokCombatAirJump.enabled = false
    JokCombatAirJump.available = false
    JokCombatAirJump.consumed = false
    JokCombatAirJump.wasAirborne = false
    JokCombatAirJump.releaseRequired = false
    JokCombatAirJump.groundRequestFrames = 0
    JokCombatAirJump.routeFrames = 0
    JokCombatAirJump.requestAge = 0
    JokCombatAirJump.routeOwned = false
    JokCombatAirJump.active = false
    JokCombatAirJump.playerPointer = nil
    JokCombatAirJump.sourceAnimation = nil
    JokCombatAirJump.sourceTime = 0.0
    JokCombatAirJump.sourceAirborneState = 0
    JokCombatAirJump.routeFaultLogged = false
    JokCombatAirJump.liftFaultLogged = false
    JokCombatAirJump.fallBrakeArmed = false
    JokCombatAirJump.lastVerticalPosition = nil
    JokCombatAirJump.fallBrakeSamples = 0
    JokCombatAirJump.fallBrakeRawMaximum = 0.0
    JokCombatAirJump.fallBrakeCorrectedMaximum = 0.0
    JokCombatAirJump.fallBrakeFaultLogged = false

    if not JokCombatAirJump.restoreRoutes("reload recovery", true) then
        return false
    end
    local canonical, changedEntry = JokCombatAirJump.recordsCanonical()
    if airRouteReady ~= true or not canonical then
        log("[air-jump] canonical aerial records unavailable"
            .. (changedEntry ~= nil and " at " .. changedEntry.name or "")
            .. "; second jump disabled.")
        return false
    end
    local gameSpeed = ReadFloat(ADDRESS.gameSpeed)
    if gameSpeed ~= gameSpeed or gameSpeed < 0.05 or gameSpeed > 4.0 then
        log(string.format(
            "[air-jump] game-speed signature invalid (%.3f); disabled.",
            gameSpeed))
        return false
    end
    if CONFIG.airFallBrakeFactor <= 0.0
        or CONFIG.airFallBrakeFactor > 1.0 then
        log(string.format(
            "[air-jump] fall-brake factor invalid (%.3f); disabled.",
            CONFIG.airFallBrakeFactor))
        return false
    end
    JokCombatAirJump.enabled = CONFIG.secondJump == true
    return JokCombatAirJump.enabled
end

function JokCombatAirJump.reset(reason, quiet, clearPlayer)
    local hadCycle = JokCombatAirJump.available
        or JokCombatAirJump.consumed
        or JokCombatAirJump.groundRequestFrames > 0
        or JokCombatAirJump.routeOwned
        or JokCombatAirJump.active
        or JokCombatAirJump.fallBrakeArmed
    local ownedCommand = JokCombatAirJump.routeOwned
    JokCombatAirJump.restoreRoutes(reason, true)
    if ownedCommand then clearSyntheticAttackCommand(false) end
    JokCombatAirJump.available = false
    JokCombatAirJump.consumed = false
    JokCombatAirJump.wasAirborne = false
    JokCombatAirJump.releaseRequired = false
    JokCombatAirJump.groundRequestFrames = 0
    JokCombatAirJump.requestAge = 0
    JokCombatAirJump.active = false
    JokCombatAirJump.sourceAnimation = nil
    JokCombatAirJump.sourceTime = 0.0
    JokCombatAirJump.sourceAirborneState = 0
    JokCombatAirJump.fallBrakeArmed = false
    JokCombatAirJump.lastVerticalPosition = nil
    JokCombatAirJump.fallBrakeSamples = 0
    JokCombatAirJump.fallBrakeRawMaximum = 0.0
    JokCombatAirJump.fallBrakeCorrectedMaximum = 0.0
    if clearPlayer then JokCombatAirJump.playerPointer = nil end
    if hadCycle and reason ~= nil and not quiet then
        log("[air-jump] cycle reset: " .. reason .. ".")
    end
end

function JokCombatAirJump.noteGroundJump(player)
    if not JokCombatAirJump.enabled or player.airborne then return end
    JokCombatAirJump.playerPointer = player.pointer
    -- LuaBackend may observe the ground press only after KH1 has already set
    -- raw70=1. Requiring a release prevents that same physical edge from being
    -- consumed immediately as the newly armed second jump.
    JokCombatAirJump.releaseRequired = true
    JokCombatAirJump.groundRequestFrames = CONFIG.secondJumpArmFrames
end

function JokCombatAirJump.isNativeFirstJumpEntry(animation)
    -- 0x04 is KH1's base Jump entry. Once the real Shared High Jump record is
    -- active, the same physical B enters 0x09 instead. LuaBackend can observe
    -- either transition after raw70 has already become airborne, so both are
    -- valid first-jump evidence and neither is a Kinetic Step request.
    return animation == 0x04 or animation == 0x09
end

function JokCombatAirJump.boost(player)
    if not JokCombatAirJump.active or not player.airborne
        or player.animation ~= 0x0F
        or player.time > CONFIG.secondJumpLiftEndTime
        or player.airborneState == 0x0F
        or player.airborneState == 0x10
        or ReadByte(ADDRESS.world) == 0x09 then
        return false
    end

    local position = ReadFloat(
        player.pointer + PLAYER.verticalPosition, true)
    local gameSpeed = ReadFloat(ADDRESS.gameSpeed)
    local animationSpeed = ReadFloat(
        player.pointer + PLAYER.animationSpeed, true)
    local valid = position == position and math.abs(position) < 1000000.0
        and gameSpeed == gameSpeed and gameSpeed >= 0.05 and gameSpeed <= 4.0
        and animationSpeed == animationSpeed
        and animationSpeed >= 0.05 and animationSpeed <= 4.0
    if not valid then
        if not JokCombatAirJump.liftFaultLogged then
            log("[air-jump] invalid position/speed sample; lift suppressed.")
            JokCombatAirJump.liftFaultLogged = true
        end
        return false
    end

    local lift = CONFIG.secondJumpLiftAmount
        * (gameSpeed / CONFIG.secondJumpSpeedDivisor * animationSpeed)
    local boostedPosition = position - lift
    WriteFloat(player.pointer + PLAYER.verticalPosition,
        boostedPosition, true)
    JokCombatAirJump.lastVerticalPosition = boostedPosition
    return true
end

function JokCombatAirJump.brakeFall(player)
    if not JokCombatAirJump.fallBrakeArmed
        or not player.airborne then
        return false
    end

    local position = ReadFloat(
        player.pointer + PLAYER.verticalPosition, true)
    if position ~= position or math.abs(position) >= 1000000.0 then
        if not JokCombatAirJump.fallBrakeFaultLogged then
            log("[air-jump] invalid fall position; post-jump brake disabled "
                .. "for this cycle.")
            JokCombatAirJump.fallBrakeFaultLogged = true
        end
        JokCombatAirJump.fallBrakeArmed = false
        JokCombatAirJump.lastVerticalPosition = nil
        return false
    end

    local previous = JokCombatAirJump.lastVerticalPosition
    if previous == nil then
        JokCombatAirJump.lastVerticalPosition = position
        return false
    end

    local rawDelta = position - previous
    -- Up is negative on this transform. Therefore only a positive delta in
    -- KH1's ordinary Fall animation is descent. Attack-driven movement such
    -- as Hurricane Blast or Aerial Sweep is observed but never modified.
    -- Base Jump falls through 0x06; Shared High Jump falls through 0x0B.
    if (player.animation ~= 0x06 and player.animation ~= 0x0B)
        or rawDelta <= 0.0 then
        JokCombatAirJump.lastVerticalPosition = position
        return false
    end
    if rawDelta > 1000.0 then
        if not JokCombatAirJump.fallBrakeFaultLogged then
            log(string.format(
                "[air-jump] implausible fall delta %.2f; post-jump brake "
                    .. "disabled for this cycle.", rawDelta))
            JokCombatAirJump.fallBrakeFaultLogged = true
        end
        JokCombatAirJump.fallBrakeArmed = false
        JokCombatAirJump.lastVerticalPosition = position
        return false
    end

    local correctedDelta = rawDelta * CONFIG.airFallBrakeFactor
    local correctedPosition = previous + correctedDelta
    WriteFloat(player.pointer + PLAYER.verticalPosition,
        correctedPosition, true)
    local observed = ReadFloat(
        player.pointer + PLAYER.verticalPosition, true)
    if observed ~= observed
        or math.abs(observed - correctedPosition) > 0.05 then
        if not JokCombatAirJump.fallBrakeFaultLogged then
            log("[air-jump] fall-brake write verification failed; disabled "
                .. "for this cycle.")
            JokCombatAirJump.fallBrakeFaultLogged = true
        end
        JokCombatAirJump.fallBrakeArmed = false
        JokCombatAirJump.lastVerticalPosition = position
        return false
    end

    JokCombatAirJump.lastVerticalPosition = observed
    JokCombatAirJump.fallBrakeSamples = JokCombatAirJump.fallBrakeSamples + 1
    JokCombatAirJump.fallBrakeRawMaximum = math.max(
        JokCombatAirJump.fallBrakeRawMaximum, rawDelta)
    JokCombatAirJump.fallBrakeCorrectedMaximum = math.max(
        JokCombatAirJump.fallBrakeCorrectedMaximum, correctedDelta)
    return true
end

function JokCombatAirJump.observe(player, buttons)
    if not JokCombatAirJump.enabled then return end
    if JokCombatAirJump.playerPointer ~= nil
        and JokCombatAirJump.playerPointer ~= player.pointer then
        JokCombatAirJump.reset("player object changed", true, true)
    end
    JokCombatAirJump.playerPointer = player.pointer

    if JokCombatAirJump.releaseRequired
        and (buttons & BUTTON.CIRCLE) == 0 then
        JokCombatAirJump.releaseRequired = false
        log("[air-jump] first-jump B released; second-jump input unlocked.")
    end

    if player.airborneState >= 0x20 or ReadByte(ADDRESS.world) == 0x09 then
        JokCombatAirJump.reset("special airborne state", true, false)
        return
    end

    if JokCombatAirJump.routeOwned then
        JokCombatAirJump.requestAge = JokCombatAirJump.requestAge + 1
        if player.animation == 0x0F then
            JokCombatAirJump.active = true
            JokCombatAirJump.fallBrakeArmed = true
            JokCombatAirJump.lastVerticalPosition = nil
            JokCombatAirJump.restoreRoutes("Kinetic Step accepted", true)
            clearSyntheticAttackCommand(false)
            WriteByte(ADDRESS.comboPosition, 1)
            log(string.format(
                "[air-jump] Kinetic Step accepted: raw70=%d anim=0x0F "
                    .. "time=%.2f; aerial combo reset to hit 1.",
                player.airborneState, player.time))
        else
            -- Preserve one complete high frame, then explicitly lower the
            -- synthetic command. The route stays armed until acceptance or
            -- timeout, but no delayed repeating Attack can leak afterward.
            if JokCombatAirJump.requestAge >= 1
                and syntheticAttackCommandHigh then
                lowerSyntheticAttackCommand()
            end
            JokCombatAirJump.routeFrames =
                math.max(0, JokCombatAirJump.routeFrames - 1)
            if JokCombatAirJump.routeFrames == 0 then
                JokCombatAirJump.restoreRoutes("Kinetic Step timeout", true)
                clearSyntheticAttackCommand(false)
                log("[air-jump] WARNING: Kinetic Step 0x0F was not observed; "
                    .. "the charge remains consumed until landing.")
            end
        end
    end

    if JokCombatAirJump.active then
        if player.animation == 0x0F then
            JokCombatAirJump.boost(player)
        else
            JokCombatAirJump.active = false
        end
    end

    JokCombatAirJump.brakeFall(player)

    if not player.airborne then
        local completedCycle = JokCombatAirJump.wasAirborne
            and (JokCombatAirJump.available or JokCombatAirJump.consumed)
        JokCombatAirJump.restoreRoutes("landing", true)
        JokCombatAirJump.available = false
        JokCombatAirJump.consumed = false
        JokCombatAirJump.wasAirborne = false
        JokCombatAirJump.releaseRequired = false
        JokCombatAirJump.requestAge = 0
        JokCombatAirJump.active = false
        JokCombatAirJump.sourceAnimation = nil
        if completedCycle and JokCombatAirJump.fallBrakeSamples > 0 then
            log(string.format(
                "[air-jump] free-fall brake: factor=%.2f frames=%d "
                    .. "maxDelta=%.2f->%.2f.",
                CONFIG.airFallBrakeFactor,
                JokCombatAirJump.fallBrakeSamples,
                JokCombatAirJump.fallBrakeRawMaximum,
                JokCombatAirJump.fallBrakeCorrectedMaximum))
        end
        JokCombatAirJump.fallBrakeArmed = false
        JokCombatAirJump.lastVerticalPosition = nil
        JokCombatAirJump.fallBrakeSamples = 0
        JokCombatAirJump.fallBrakeRawMaximum = 0.0
        JokCombatAirJump.fallBrakeCorrectedMaximum = 0.0
        if completedCycle then
            log("[air-jump] landing confirmed; second jump recharges "
                .. "after the next first jump.")
        end
        JokCombatAirJump.groundRequestFrames = math.max(
            0, JokCombatAirJump.groundRequestFrames - 1)
        return
    end

    if not JokCombatAirJump.wasAirborne
        and not JokCombatAirJump.consumed then
        local unmodified = (buttons
            & (BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2)) == 0
        -- The game can publish airborne=true one frame before LuaBackend sees
        -- 0x04/0x09. Requiring the physical B edge here therefore loses a
        -- legitimate High Jump: on the following frame B is already held.
        -- A fresh ground->air transition into either native entry is sufficient
        -- evidence; neither animation can be produced by Kinetic Step.
        local observedJumpEntry = unmodified
            and JokCombatAirJump.isNativeFirstJumpEntry(player.animation)
        if JokCombatAirJump.groundRequestFrames > 0
            or observedJumpEntry then
            JokCombatAirJump.available = true
            -- Arm one shared free-fall controller for the whole aerial cycle.
            -- Kinetic Step may reset only its position baseline, never stack a
            -- second 0.45 multiplier on top of this first-jump brake.
            JokCombatAirJump.fallBrakeArmed = true
            JokCombatAirJump.lastVerticalPosition = nil
            JokCombatAirJump.fallBrakeSamples = 0
            JokCombatAirJump.fallBrakeRawMaximum = 0.0
            JokCombatAirJump.fallBrakeCorrectedMaximum = 0.0
            JokCombatAirJump.releaseRequired =
                JokCombatAirJump.releaseRequired
                or (buttons & BUTTON.CIRCLE) ~= 0
            log(string.format(
                "[air-jump] first native jump confirmed via 0x%02X; "
                    .. "second jump armed.",
                player.animation))
        end
        JokCombatAirJump.groundRequestFrames = 0
    end
    JokCombatAirJump.wasAirborne = true
end

function JokCombatAirJump.canBegin(player, report)
    if not JokCombatAirJump.enabled then return false end
    if JokCombatAirJump.releaseRequired then
        if report then
            log("[air-jump] B ignored: release the first-jump input before "
                .. "requesting the second jump.")
        end
        return false
    end
    if JokCombatAirJump.consumed or not JokCombatAirJump.available then
        if report then
            log("[air-jump] B ignored: second jump is not charged.")
        end
        return false
    end
    if not player.airborne or player.airborneState >= 0x20
        or player.animation == 0x0D or player.animation == 0x0E
        or player.animation == 0x0F or ReadByte(ADDRESS.world) == 0x09 then
        if report then
            log(string.format(
                "[air-jump] B ignored in raw70=%d anim=0x%02X context.",
                player.airborneState, player.animation))
        end
        return false
    end
    if ReadByte(ADDRESS.commandMenuSlot) ~= 0 then
        if report then
            log("[air-jump] B ignored while a Reaction command owns the menu.")
        end
        return false
    end
    return true
end

function JokCombatAirJump.ownsCircle(buttons)
    if not JokCombatAirJump.enabled then return false end
    if (buttons & (BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2)) ~= 0 then
        return false
    end
    -- While the first B is still held, High Jump must remain completely native
    -- or KH1 cuts its variable-height ascent short. Once that B is released,
    -- reserve later B input for Kinetic Step and suppress post-Kinetic B Glide.
    return (JokCombatAirJump.available
            and not JokCombatAirJump.releaseRequired)
        or JokCombatAirJump.consumed
        or JokCombatAirJump.routeOwned or JokCombatAirJump.active
end

function JokCombatAirJump.begin(player)
    if not JokCombatAirJump.canBegin(player, false) then return false end

    restoreActionRoutes()
    local canonical, changedEntry = JokCombatAirJump.recordsCanonical()
    if not canonical then
        log("[air-jump] request rejected: aerial route changed at "
            .. changedEntry.name .. ".")
        return false
    end

    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        WriteByte(entry.address, JokCombatAirJump.routeAnimation(entry))
    end
    for _, entry in ipairs(AIR_ACTION_ROUTE) do
        if not JokCombatAirJump.entryMatchesOwnedRoute(entry) then
            JokCombatAirJump.restoreRoutes("Kinetic Step write failure", true)
            JokCombatAirJump.enabled = false
            log("[air-jump] Kinetic Step route write failed at "
                .. entry.name .. "; second jump disabled.")
            return false
        end
    end

    clearSyntheticAttackCommand(true)
    JokCombatAirJump.routeOwned = true
    JokCombatAirJump.routeFrames = CONFIG.secondJumpRouteFrames
    JokCombatAirJump.requestAge = 0
    JokCombatAirJump.sourceAnimation = player.animation
    JokCombatAirJump.sourceTime = player.time
    JokCombatAirJump.sourceAirborneState = player.airborneState
    cancelPlayer(player, "second-jump")
    WriteByte(ADDRESS.comboPosition, 1)
    if not triggerAttackCommand() then
        JokCombatAirJump.restoreRoutes("Attack trigger rejected", true)
        clearSyntheticAttackCommand(false)
        log("[air-jump] Kinetic Step request rejected by the Command Menu.")
        return false
    end

    JokCombatAirJump.available = false
    JokCombatAirJump.consumed = true
    log(string.format(
        "[air-jump] Kinetic Step requested from raw70=%d anim=0x%02X "
            .. "time=%.2f; air route 0x0F + Attack pulse armed.",
        JokCombatAirJump.sourceAirborneState,
        player.animation, player.time))
    return true
end

-- CC/CD/CE normally keep integrating downward movement throughout their
-- animations. A separate controller reduces only that positive transform
-- delta, independently of Kinetic Step. It never freezes upward movement and
-- deliberately excludes D1 Hurricane Blast and D6 Aerial Sweep, whose vertical
-- trajectories are part of their native attacks.
JokCombatAirAttackBrake = {
    enabled = false,
    playerPointer = nil,
    lastVerticalPosition = nil,
    active = false,
    cycleBlocked = false,
    samples = 0,
    rawMaximum = 0.0,
    correctedMaximum = 0.0,
    faultLogged = false,
}

function JokCombatAirAttackBrake.ownsAnimation(animation)
    return animation == 0xCC or animation == 0xCD or animation == 0xCE
end

function JokCombatAirAttackBrake.initialize()
    JokCombatAirAttackBrake.enabled = false
    JokCombatAirAttackBrake.playerPointer = nil
    JokCombatAirAttackBrake.lastVerticalPosition = nil
    JokCombatAirAttackBrake.active = false
    JokCombatAirAttackBrake.cycleBlocked = false
    JokCombatAirAttackBrake.samples = 0
    JokCombatAirAttackBrake.rawMaximum = 0.0
    JokCombatAirAttackBrake.correctedMaximum = 0.0
    JokCombatAirAttackBrake.faultLogged = false

    if CONFIG.airAttackFallBrakeFactor <= 0.0
        or CONFIG.airAttackFallBrakeFactor > 1.0 then
        log(string.format(
            "[air-attack] fall-brake factor invalid (%.3f); disabled.",
            CONFIG.airAttackFallBrakeFactor))
        return false
    end
    JokCombatAirAttackBrake.enabled = CONFIG.airAttackFallBrake == true
    return JokCombatAirAttackBrake.enabled
end

function JokCombatAirAttackBrake.reset(reason, quiet, clearPlayer)
    if JokCombatAirAttackBrake.samples > 0
        and reason ~= nil and not quiet then
        log(string.format(
            "[air-attack] descent brake: factor=%.2f frames=%d "
                .. "maxDelta=%.2f->%.2f (%s).",
            CONFIG.airAttackFallBrakeFactor,
            JokCombatAirAttackBrake.samples,
            JokCombatAirAttackBrake.rawMaximum,
            JokCombatAirAttackBrake.correctedMaximum,
            reason))
    end
    JokCombatAirAttackBrake.lastVerticalPosition = nil
    JokCombatAirAttackBrake.active = false
    JokCombatAirAttackBrake.cycleBlocked = false
    JokCombatAirAttackBrake.samples = 0
    JokCombatAirAttackBrake.rawMaximum = 0.0
    JokCombatAirAttackBrake.correctedMaximum = 0.0
    if clearPlayer then JokCombatAirAttackBrake.playerPointer = nil end
end

function JokCombatAirAttackBrake.disableCycle(message)
    if not JokCombatAirAttackBrake.faultLogged then
        log("[air-attack] " .. message
            .. "; descent brake disabled until landing.")
        JokCombatAirAttackBrake.faultLogged = true
    end
    JokCombatAirAttackBrake.active = false
    JokCombatAirAttackBrake.cycleBlocked = true
end

function JokCombatAirAttackBrake.observe(player, nativeLimitActive)
    if not JokCombatAirAttackBrake.enabled then return end
    if JokCombatAirAttackBrake.playerPointer ~= nil
        and JokCombatAirAttackBrake.playerPointer ~= player.pointer then
        JokCombatAirAttackBrake.reset("player object changed", true, true)
    end
    JokCombatAirAttackBrake.playerPointer = player.pointer

    if nativeLimitActive or player.airborneState >= 0x20
        or ReadByte(ADDRESS.world) == 0x09 then
        JokCombatAirAttackBrake.reset("special airborne state", true, false)
        return
    end
    if not player.airborne then
        JokCombatAirAttackBrake.reset("landing", false, false)
        return
    end

    local position = ReadFloat(
        player.pointer + PLAYER.verticalPosition, true)
    if position ~= position or math.abs(position) >= 1000000.0 then
        JokCombatAirAttackBrake.disableCycle("invalid vertical position")
        JokCombatAirAttackBrake.lastVerticalPosition = nil
        return
    end

    local previous = JokCombatAirAttackBrake.lastVerticalPosition
    local ownsAnimation = JokCombatAirAttackBrake.ownsAnimation(
        player.animation)
    if previous == nil then
        JokCombatAirAttackBrake.lastVerticalPosition = position
        JokCombatAirAttackBrake.active = ownsAnimation
        return
    end
    if JokCombatAirAttackBrake.cycleBlocked then
        JokCombatAirAttackBrake.lastVerticalPosition = position
        return
    end

    local rawDelta = position - previous
    if not ownsAnimation or rawDelta <= 0.0 then
        -- Negative is upward on this transform and remains completely native.
        -- D1/D6 also enter here, so their authored dives/lifts are untouched.
        JokCombatAirAttackBrake.lastVerticalPosition = position
        JokCombatAirAttackBrake.active = ownsAnimation
        return
    end
    if rawDelta > 1000.0 then
        JokCombatAirAttackBrake.disableCycle(string.format(
            "implausible descent delta %.2f", rawDelta))
        JokCombatAirAttackBrake.lastVerticalPosition = position
        return
    end

    local correctedDelta = rawDelta * CONFIG.airAttackFallBrakeFactor
    local correctedPosition = previous + correctedDelta
    WriteFloat(player.pointer + PLAYER.verticalPosition,
        correctedPosition, true)
    local observed = ReadFloat(
        player.pointer + PLAYER.verticalPosition, true)
    if observed ~= observed
        or math.abs(observed - correctedPosition) > 0.05 then
        JokCombatAirAttackBrake.disableCycle(
            "write verification failed")
        JokCombatAirAttackBrake.lastVerticalPosition = position
        return
    end

    JokCombatAirAttackBrake.lastVerticalPosition = observed
    JokCombatAirAttackBrake.active = true
    JokCombatAirAttackBrake.samples = JokCombatAirAttackBrake.samples + 1
    JokCombatAirAttackBrake.rawMaximum = math.max(
        JokCombatAirAttackBrake.rawMaximum, rawDelta)
    JokCombatAirAttackBrake.correctedMaximum = math.max(
        JokCombatAirAttackBrake.correctedMaximum, correctedDelta)
end

-- C8-CB and CC-CE are KH1's complete native ground and aerial physical
-- strings. This controller changes only their per-player animation playback
-- field. It never changes global game speed or any Action/Limit record, so
-- native hit events and combo-time windows continue to advance with the
-- animation instead of being bypassed by an early cancel.
JokCombatAttackSpeed = {
    enabled = false,
    multiplier = 1.0,
    epsilon = 0.001,
    playerPointer = nil,
    originalSpeed = nil,
    ownedSpeed = nil,
    owned = false,
    cycleBlocked = false,
    sampleLogged = false,
    faultLogged = false,
}

function JokCombatAttackSpeed.same(left, right)
    return left ~= nil and right ~= nil
        and math.abs(left - right) <= JokCombatAttackSpeed.epsilon
end

function JokCombatAttackSpeed.valid(value)
    return value == value and value >= 0.05 and value <= 4.0
end

function JokCombatAttackSpeed.ownsAnimation(player)
    if player == nil or player.animation < 0xC8
        or player.animation > 0xCE then
        return false
    end
    -- C8-CA with a low secondary ID are reused by native Limit contexts.
    return not (player.animation <= 0xCA and player.secondary <= 0x02)
end

function JokCombatAttackSpeed.clearOwnership(blockCycle)
    JokCombatAttackSpeed.playerPointer = nil
    JokCombatAttackSpeed.originalSpeed = nil
    JokCombatAttackSpeed.ownedSpeed = nil
    JokCombatAttackSpeed.owned = false
    JokCombatAttackSpeed.cycleBlocked = blockCycle == true
end

function JokCombatAttackSpeed.restore(reason, quiet)
    if not JokCombatAttackSpeed.owned then
        JokCombatAttackSpeed.clearOwnership(false)
        return true
    end

    local pointer = JokCombatAttackSpeed.playerPointer
    local livePointer = ReadLong(ADDRESS.playerPointer)
    local restored = true
    if pointer ~= nil and livePointer == pointer
        and isPlausiblePointer(pointer) then
        local address = pointer + PLAYER.animationSpeed
        local current = ReadFloat(address, true)
        if JokCombatAttackSpeed.same(
                current, JokCombatAttackSpeed.ownedSpeed) then
            WriteFloat(address, JokCombatAttackSpeed.originalSpeed, true)
            local observed = ReadFloat(address, true)
            restored = JokCombatAttackSpeed.same(
                observed, JokCombatAttackSpeed.originalSpeed)
            if not restored and not quiet then
                log("[attack-speed] original playback speed could not be "
                    .. "verified during restore.")
            end
        elseif not JokCombatAttackSpeed.same(
                current, JokCombatAttackSpeed.originalSpeed) and not quiet then
            log("[attack-speed] playback speed changed externally; leaving "
                .. "the newer value untouched.")
        end
    end

    if not quiet and JokCombatAttackSpeed.owned then
        log("[attack-speed] native combo playback restored"
            .. (reason ~= nil and " (" .. reason .. ")." or "."))
    end
    JokCombatAttackSpeed.clearOwnership(false)
    return restored
end

function JokCombatAttackSpeed.initialize()
    JokCombatAttackSpeed.clearOwnership(false)
    JokCombatAttackSpeed.enabled = false
    JokCombatAttackSpeed.multiplier = CONFIG.normalAttackSpeedMultiplier
    JokCombatAttackSpeed.sampleLogged = false
    JokCombatAttackSpeed.faultLogged = false

    if CONFIG.normalAttackSpeedup ~= true then return false end
    if JokCombatAttackSpeed.multiplier ~= JokCombatAttackSpeed.multiplier
        or JokCombatAttackSpeed.multiplier <= 1.0
        or JokCombatAttackSpeed.multiplier > 2.0 then
        log(string.format(
            "[attack-speed] invalid multiplier %.3f; disabled.",
            JokCombatAttackSpeed.multiplier))
        return false
    end

    -- F1 reload normally calls the exit hook, but some loaders replace the
    -- chunk directly. Normalize only our exact vanilla-derived 1.0x value so a
    -- stale 1.15x cannot be adopted and multiplied a second time.
    local pointer = ReadLong(ADDRESS.playerPointer)
    if isPlausiblePointer(pointer) then
        local address = pointer + PLAYER.animationSpeed
        local current = ReadFloat(address, true)
        if JokCombatAttackSpeed.same(
                current, JokCombatAttackSpeed.multiplier) then
            WriteFloat(address, 1.0, true)
            if JokCombatAttackSpeed.same(ReadFloat(address, true), 1.0) then
                log("[attack-speed] stale owned playback speed recovered.")
            end
        end
    end

    JokCombatAttackSpeed.enabled = true
    return true
end

function JokCombatAttackSpeed.blockCycle(message)
    if not JokCombatAttackSpeed.faultLogged then
        log("[attack-speed] " .. message
            .. "; speedup suspended until the current combo ends.")
        JokCombatAttackSpeed.faultLogged = true
    end
    JokCombatAttackSpeed.clearOwnership(true)
end

function JokCombatAttackSpeed.observe(player, nativeLimitActive)
    if not JokCombatAttackSpeed.enabled then return end

    if JokCombatAttackSpeed.playerPointer ~= nil
        and JokCombatAttackSpeed.playerPointer ~= player.pointer then
        -- The old object is no longer the live Sora pointer and must not be
        -- written. Its field dies with that object; begin clean on the new one.
        JokCombatAttackSpeed.clearOwnership(false)
    end

    local normalPhysical = JokCombatAttackSpeed.ownsAnimation(player)
    if nativeLimitActive or player.airborneState >= 0x20
        or ReadByte(ADDRESS.world) == 0x09 or not normalPhysical then
        if JokCombatAttackSpeed.owned then
            JokCombatAttackSpeed.restore("native combo ended", false)
        else
            JokCombatAttackSpeed.cycleBlocked = false
        end
        return
    end
    if JokCombatAttackSpeed.cycleBlocked then return end

    local address = player.pointer + PLAYER.animationSpeed
    local current = ReadFloat(address, true)
    if not JokCombatAttackSpeed.valid(current) then
        JokCombatAttackSpeed.blockCycle("invalid playback-speed sample")
        return
    end

    if not JokCombatAttackSpeed.owned then
        local desired = current * JokCombatAttackSpeed.multiplier
        if not JokCombatAttackSpeed.valid(desired) then
            JokCombatAttackSpeed.blockCycle("multiplied playback speed is unsafe")
            return
        end

        WriteFloat(address, desired, true)
        local observed = ReadFloat(address, true)
        if not JokCombatAttackSpeed.same(observed, desired) then
            JokCombatAttackSpeed.blockCycle("playback-speed write was rejected")
            return
        end

        JokCombatAttackSpeed.playerPointer = player.pointer
        JokCombatAttackSpeed.originalSpeed = current
        JokCombatAttackSpeed.ownedSpeed = desired
        JokCombatAttackSpeed.owned = true
        if not JokCombatAttackSpeed.sampleLogged then
            log(string.format(
                "[attack-speed] native C8-CE playback %.3f -> %.3f (x%.2f).",
                current, desired, JokCombatAttackSpeed.multiplier))
            JokCombatAttackSpeed.sampleLogged = true
        end
        return
    end

    if JokCombatAttackSpeed.same(current, JokCombatAttackSpeed.ownedSpeed) then
        return
    end
    if JokCombatAttackSpeed.same(
            current, JokCombatAttackSpeed.originalSpeed) then
        -- KH1 may publish the baseline again at an internal combo transition.
        WriteFloat(address, JokCombatAttackSpeed.ownedSpeed, true)
        if not JokCombatAttackSpeed.same(
                ReadFloat(address, true), JokCombatAttackSpeed.ownedSpeed) then
            JokCombatAttackSpeed.blockCycle(
                "playback speed could not be retained across the combo")
        end
        return
    end

    -- Never fight a newer owner. In particular, do not multiply an external
    -- value on the next frame while this physical string is still active.
    JokCombatAttackSpeed.blockCycle("playback speed changed externally")
end

-- Steam Global live capture on 2026-08-15 confirmed that native C8-CE normal
-- contacts raise 0x296B230 to 0x01, while whiffs do not. Strike Raid may raise
-- 0x40 and Slapshot may raise 0x01, but both occur outside C8-CE. Keep that
-- animation boundary and the existing low-secondary Limit exclusion, then
-- accept at most one rising contact edge per native attack animation.
JokCombatMeleeMP = {
    enabled = false,
    hitsPerMP = 10,
    currentMPOffset = 0x44,
    maxMPOffset = 0x48,
    credit = 0,
    playerPointer = nil,
    active = false,
    animation = nil,
    lastTime = 0.0,
    hitSeen = false,
    lastSignal = nil,
    fullLogged = false,
    layoutFaultLogged = false,
}

function JokCombatMeleeMP.clearAttack()
    JokCombatMeleeMP.active = false
    JokCombatMeleeMP.animation = nil
    JokCombatMeleeMP.lastTime = 0.0
    JokCombatMeleeMP.hitSeen = false
end

function JokCombatMeleeMP.reset(reason, clearCredit, quiet)
    local hadProgress = JokCombatMeleeMP.credit > 0
        or JokCombatMeleeMP.active
    JokCombatMeleeMP.clearAttack()
    JokCombatMeleeMP.playerPointer = nil
    JokCombatMeleeMP.lastSignal = nil
    JokCombatMeleeMP.fullLogged = false
    JokCombatMeleeMP.layoutFaultLogged = false
    if clearCredit then JokCombatMeleeMP.credit = 0 end
    if hadProgress and not quiet and reason ~= nil then
        log("[melee-mp] local charge reset (" .. reason .. ").")
    end
end

function JokCombatMeleeMP.initialize()
    JokCombatMeleeMP.enabled = false
    JokCombatMeleeMP.hitsPerMP = CONFIG.meleeHitsPerMP
    JokCombatMeleeMP.credit = 0
    JokCombatMeleeMP.reset("reload", true, true)
    if CONFIG.meleeMPRecovery ~= true then return false end
    if type(JokCombatMeleeMP.hitsPerMP) ~= "number"
        or JokCombatMeleeMP.hitsPerMP < 2
        or JokCombatMeleeMP.hitsPerMP > 20
        or JokCombatMeleeMP.hitsPerMP % 1 ~= 0 then
        log("[melee-mp] invalid hit threshold; recovery disabled.")
        return false
    end
    JokCombatMeleeMP.enabled = true
    return true
end

function JokCombatMeleeMP.ownsAnimation(player)
    if player == nil or player.animation < 0xC8
        or player.animation > 0xCE then
        return false
    end
    return not (player.animation <= 0xCA and player.secondary <= 0x02)
end

function JokCombatMeleeMP.readBattleMP(player)
    local slot = ReadShort(player.pointer + PLAYER.slotReference, true)
    if slot < 0x8000 or slot > 0xFFFF then return nil end
    local base = ADDRESS.battleSlotBase + slot
    local currentAddress = base + JokCombatMeleeMP.currentMPOffset
    local currentMP = ReadByte(currentAddress)
    local maxMP = ReadByte(base + JokCombatMeleeMP.maxMPOffset)
    if maxMP < 1 or maxMP > 99 or currentMP > maxMP then return nil end
    return currentAddress, currentMP, maxMP
end

function JokCombatMeleeMP.acceptHit(player, signal)
    local currentAddress, currentMP, maxMP =
        JokCombatMeleeMP.readBattleMP(player)
    if currentAddress == nil then
        if not JokCombatMeleeMP.layoutFaultLogged then
            log("[melee-mp] invalid Sora MP layout; hit ignored.")
            JokCombatMeleeMP.layoutFaultLogged = true
        end
        return
    end
    JokCombatMeleeMP.layoutFaultLogged = false

    if currentMP >= maxMP then
        JokCombatMeleeMP.credit = 0
        if not JokCombatMeleeMP.fullLogged then
            log(string.format(
                "[melee-mp] confirmed 0x%02X normal hit at full MP; "
                    .. "no charge banked (%d/%d).",
                signal, currentMP, maxMP))
            JokCombatMeleeMP.fullLogged = true
        end
        return
    end
    JokCombatMeleeMP.fullLogged = false

    JokCombatMeleeMP.credit = JokCombatMeleeMP.credit + 1
    if JokCombatMeleeMP.credit < JokCombatMeleeMP.hitsPerMP then
        log(string.format(
            "[melee-mp] confirmed normal hit: charge=%d/%d mp=%d/%d.",
            JokCombatMeleeMP.credit, JokCombatMeleeMP.hitsPerMP,
            currentMP, maxMP))
        return
    end

    local desired = math.min(maxMP, currentMP + 1)
    WriteByte(currentAddress, desired)
    local observed = ReadByte(currentAddress)
    JokCombatMeleeMP.credit = 0
    if observed ~= desired then
        JokCombatMeleeMP.enabled = false
        log(string.format(
            "[melee-mp] MP write verification failed (%d expected, %d read); "
                .. "recovery disabled until reload.",
            desired, observed))
        return
    end
    log(string.format(
        "[melee-mp] 1 MP restored after %d confirmed normal hits: %d/%d.",
        JokCombatMeleeMP.hitsPerMP, observed, maxMP))
end

function JokCombatMeleeMP.observe(player, nativeLimitActive)
    if not JokCombatMeleeMP.enabled or player == nil then return end

    if JokCombatMeleeMP.playerPointer ~= nil
        and JokCombatMeleeMP.playerPointer ~= player.pointer then
        JokCombatMeleeMP.reset("player changed", true, true)
    end
    JokCombatMeleeMP.playerPointer = player.pointer

    local signal = ReadByte(ADDRESS.connectCounter)
    local normal = not nativeLimitActive
        and player.airborneState < 0x20
        and JokCombatMeleeMP.ownsAnimation(player)
    if not normal then
        JokCombatMeleeMP.clearAttack()
    else
        local restarted = JokCombatMeleeMP.active
            and JokCombatMeleeMP.animation == player.animation
            and player.time + 0.50 < JokCombatMeleeMP.lastTime
        local changed = JokCombatMeleeMP.active
            and JokCombatMeleeMP.animation ~= player.animation
        if not JokCombatMeleeMP.active or restarted or changed then
            JokCombatMeleeMP.active = true
            JokCombatMeleeMP.animation = player.animation
            JokCombatMeleeMP.hitSeen = false
        end
        JokCombatMeleeMP.lastTime = player.time
    end

    local hitEdge = JokCombatMeleeMP.lastSignal ~= nil
        and signal ~= JokCombatMeleeMP.lastSignal
        and (signal == 0x01 or signal == 0x40)
    if hitEdge and JokCombatMeleeMP.active
        and not JokCombatMeleeMP.hitSeen then
        JokCombatMeleeMP.hitSeen = true
        JokCombatMeleeMP.acceptHit(player, signal)
    end
    JokCombatMeleeMP.lastSignal = signal
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
        and not player.airborne
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

local function requestActionAbility(player, slot, action, usesPhysicalInput,
        branchWindowAuthorized, branchContextAuthorized)
    if action == nil or action.animation == nil then
        log(slot.label .. " has no Action Ability assigned.")
        return false
    end
    if not branchContextAuthorized
        and not actionMatchesContext(action, player) then
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
    local canCancel = branchWindowAuthorized == true
        or isCancelableAttack(player)
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
    if not player.airborne then
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
        requestedFromAir and "air-native" or "ground",
        routeWasPrimed and "prearmed" or "synthetic",
        comboPosition ~= nil
            and string.format(" combo=%d max=%d", comboPosition, maximum)
            or ""))
    return true
end

-- Legacy v0.9.1-v0.10.5 combo-magic state. The active adapter was retired in
-- v0.10.6 after live tests showed that its remapped physical Y never entered
-- KH1's native shortcut dispatcher. Only recoverStale() is called now, once at
-- reload, so an interrupted older cast can restore fields it still owns.
LegacyMagicRecovery = {
    catalog = {
        fire = {
            name = "Fire", index = 0, costWidth = 1,
            costs = { 0x2D28C98, 0x2D28D08, 0x2D28D78 },
        },
        blizzard = {
            name = "Blizzard", index = 1, costWidth = 1,
            costs = { 0x2D28DE8, 0x2D28E58, 0x2D28EC8 },
        },
        thunder = {
            name = "Thunder", index = 2, costWidth = 2,
            costs = { 0x2D28F38, 0x2D28FA8, 0x2D29018 },
        },
        cure = {
            name = "Cure", index = 3, costWidth = 2,
            costs = { 0x2D29088, 0x2D290F8, 0x2D29168 },
        },
        gravity = {
            name = "Gravity", index = 4, costWidth = 1,
            costs = { 0x2D291D8, 0x2D29248, 0x2D292B8 },
        },
        stop = {
            name = "Stop", index = 5, costWidth = 2,
            costs = { 0x2D29328, 0x2D29398, 0x2D29408 },
        },
        aero = {
            name = "Aero", index = 6, costWidth = 2,
            costs = { 0x2D29478, 0x2D294E8, 0x2D29558 },
        },
    },
    rawRecoverySignature = 0x313047414D4B4F4A, -- "JOKMAG01"
    carrierRecoverySignature = 0x323047414D4B4F4A, -- "JOKMAG02"
    directMapRecoverySignature = 0x333047414D4B4F4A, -- "JOKMAG03"
    recoverySignature = 0x343047414D4B4F4A, -- "JOKMAG04"
    recoveryMarker = 0xA5,
}

function LegacyMagicRecovery.familyByIndex(index)
    for _, family in pairs(LegacyMagicRecovery.catalog) do
        if family.index == index then return family end
    end
    return nil
end

function LegacyMagicRecovery.readCost(family, address)
    if family.costWidth == 1 then return ReadByte(address) end
    return ReadShort(address)
end

function LegacyMagicRecovery.writeCost(family, address, value)
    if family.costWidth == 1 then
        WriteByte(address, value)
    else
        WriteShort(address, value)
    end
end

function LegacyMagicRecovery.clearRecovery()
    WriteLong(ADDRESS.magicRecovery, 0)
end

function LegacyMagicRecovery.recoverStale()
    local journal = ADDRESS.magicRecovery
    local signature = ReadLong(journal)
    if signature ~= LegacyMagicRecovery.recoverySignature
        and signature ~= LegacyMagicRecovery.directMapRecoverySignature
        and signature ~= LegacyMagicRecovery.carrierRecoverySignature
        and signature ~= LegacyMagicRecovery.rawRecoverySignature then
        return false
    end
    local family = LegacyMagicRecovery.familyByIndex(ReadByte(journal + 0x08))
    if family == nil
        or ReadByte(journal + 0x09) ~= LegacyMagicRecovery.recoveryMarker then
        LegacyMagicRecovery.clearRecovery()
        ConsolePrint("[JokCombat:magic:recovery] invalid journal cleared; "
            .. "no unowned memory was overwritten.")
        return false
    end

    local restored = 0
    local shortcutOriginal = ReadByte(journal + 0x0A)
    if ReadByte(ADDRESS.nativeShortcutTriangle) == family.index then
        WriteByte(ADDRESS.nativeShortcutTriangle, shortcutOriginal)
        restored = restored + 1
    end
    local levelAddress = ADDRESS.magicLevelBase + family.index
    local levelOriginal = ReadByte(journal + 0x0B)
    local levelForced = ReadByte(journal + 0x0C)
    if ReadByte(levelAddress) == levelForced then
        WriteByte(levelAddress, levelOriginal)
        restored = restored + 1
    end
    for index, address in ipairs(family.costs) do
        if LegacyMagicRecovery.readCost(family, address) == 0 then
            LegacyMagicRecovery.writeCost(
                family, address, ReadShort(journal + 0x0E + index * 2))
            restored = restored + 1
        end
    end
    local rawOriginal = ReadByte(journal + 0x0D)
    local rawInjected = ReadByte(journal + 0x0E)
    if rawInjected ~= rawOriginal
        and ReadByte(ADDRESS.rawButtons) == rawInjected then
        WriteByte(ADDRESS.rawButtons, rawOriginal)
        restored = restored + 1
    end
    if signature == LegacyMagicRecovery.carrierRecoverySignature
        or signature == LegacyMagicRecovery.directMapRecoverySignature
        or signature == LegacyMagicRecovery.recoverySignature then
        local shortcutControlOriginal = ReadByte(journal + 0x0F)
        local ownedValue = signature == LegacyMagicRecovery.directMapRecoverySignature
            and CONTROL_INDEX.TRIANGLE or 0x20
        if ReadByte(ADDRESS.shortcutControlSelector) == ownedValue then
            WriteByte(ADDRESS.shortcutControlSelector,
                shortcutControlOriginal)
            restored = restored + 1
        end
    end
    if signature == LegacyMagicRecovery.recoverySignature
        and ReadByte(ADDRESS.l2ControlMap) == CONTROL_INDEX.TRIANGLE then
        WriteByte(ADDRESS.l2ControlMap, ReadByte(journal + 0x16))
        restored = restored + 1
    end
    LegacyMagicRecovery.clearRecovery()
    ConsolePrint(string.format(
        "[JokCombat:magic:recovery] stale %s cast restored (%d owned fields).",
        family.name, restored))
    return true
end

function JokCombatR2NativeBridge.matchesAt(address, expected)
    for index = 1, #expected do
        if ReadByte(address + index - 1) ~= expected[index] then
            return false
        end
    end
    return true
end

function JokCombatR2NativeBridge.matches(expected)
    return JokCombatR2NativeBridge.matchesAt(
        JokCombatR2NativeBridge.address, expected)
end

function JokCombatR2NativeBridge.activeNormal()
    return JokCombatR2NativeBridge.matches(
        JokCombatR2NativeBridge.normal)
        and JokCombatR2NativeBridge.matchesAt(
            JokCombatR2NativeBridge.caveAddress,
            JokCombatR2NativeBridge.caveNormal)
end

function JokCombatR2NativeBridge.activeOwned()
    return JokCombatR2NativeBridge.matches(
        JokCombatR2NativeBridge.owned)
        and JokCombatR2NativeBridge.matchesAt(
            JokCombatR2NativeBridge.caveAddress,
            JokCombatR2NativeBridge.caveOwned)
end

function JokCombatR2NativeBridge.restore(reason, quiet)
    local callOwned = JokCombatR2NativeBridge.matches(
        JokCombatR2NativeBridge.owned)
    local caveOwned = JokCombatR2NativeBridge.matchesAt(
        JokCombatR2NativeBridge.caveAddress,
        JokCombatR2NativeBridge.caveOwned)
    local preDispatchOwned = JokCombatR2NativeBridge.matchesAt(
        JokCombatR2NativeBridge.preDispatchAddress,
        JokCombatR2NativeBridge.preDispatchOwned)
    local legacyOwned = JokCombatR2NativeBridge.matchesAt(
        JokCombatR2NativeBridge.legacyAddress,
        JokCombatR2NativeBridge.legacyOwned)
    local wasOwned = JokCombatR2NativeBridge.ownedNow
        or callOwned or caveOwned or preDispatchOwned or legacyOwned

    -- Disconnect the call before clearing its tail cave. Each write remains
    -- conditional on JokCombat's complete signed bytes.
    if callOwned then
        WriteArray(JokCombatR2NativeBridge.address,
            JokCombatR2NativeBridge.normal)
    end
    if caveOwned then
        WriteArray(JokCombatR2NativeBridge.caveAddress,
            JokCombatR2NativeBridge.caveNormal)
    end
    if preDispatchOwned then
        WriteArray(JokCombatR2NativeBridge.preDispatchAddress,
            JokCombatR2NativeBridge.preDispatchNormal)
    elseif legacyOwned then
        WriteArray(JokCombatR2NativeBridge.legacyAddress,
            JokCombatR2NativeBridge.legacyNormal)
    end

    local activeRestored = JokCombatR2NativeBridge.activeNormal()
    local retiredRestored = JokCombatR2NativeBridge.matchesAt(
        JokCombatR2NativeBridge.preDispatchAddress,
        JokCombatR2NativeBridge.preDispatchNormal)
    if (not activeRestored or not retiredRestored)
        and not JokCombatR2NativeBridge.failureLogged then
        JokCombatR2NativeBridge.failureLogged = true
        JokCombatR2NativeBridge.ready = false
        ConsolePrint("[JokCombat:r2-magic:fault] native input bridge changed "
            .. "by another writer; conditional restore left it untouched.")
    end
    JokCombatR2NativeBridge.ownedNow = false
    if wasOwned and not quiet then
        log("R2 native Shortcut input bridge restored"
            .. (reason ~= nil and ": " .. reason or "."))
    end
    return wasOwned
end

function JokCombatR2NativeBridge.ensure()
    if not CONFIG.r2MagicShortcuts
        or not JokCombatR2NativeBridge.ready then return false end
    if JokCombatR2NativeBridge.activeOwned() then
        JokCombatR2NativeBridge.ownedNow = true
        return true
    end
    if not JokCombatR2NativeBridge.activeNormal() then
        JokCombatR2NativeBridge.ready = false
        if not JokCombatR2NativeBridge.failureLogged then
            JokCombatR2NativeBridge.failureLogged = true
            ConsolePrint("[JokCombat:r2-magic:fault] Steam Shortcut edge "
                .. "signature mismatch; R2 page disabled.")
        end
        return false
    end

    -- Publish the tail first and redirect the call only after every helper byte
    -- has been verified. A partial write can therefore never be executed.
    WriteArray(JokCombatR2NativeBridge.caveAddress,
        JokCombatR2NativeBridge.caveOwned)
    if not JokCombatR2NativeBridge.matchesAt(
            JokCombatR2NativeBridge.caveAddress,
            JokCombatR2NativeBridge.caveOwned) then
        JokCombatR2NativeBridge.ready = false
        return false
    end
    WriteArray(JokCombatR2NativeBridge.address,
        JokCombatR2NativeBridge.owned)
    if not JokCombatR2NativeBridge.activeOwned() then
        if JokCombatR2NativeBridge.matches(
                JokCombatR2NativeBridge.normal) then
            WriteArray(JokCombatR2NativeBridge.caveAddress,
                JokCombatR2NativeBridge.caveNormal)
        end
        JokCombatR2NativeBridge.ready = false
        if not JokCombatR2NativeBridge.failureLogged then
            JokCombatR2NativeBridge.failureLogged = true
            ConsolePrint("[JokCombat:r2-magic:fault] native Shortcut edge "
                .. "bridge write was not accepted; R2 page disabled.")
        end
        return false
    end
    JokCombatR2NativeBridge.ownedNow = true
    if not JokCombatR2NativeBridge.installLogged then
        JokCombatR2NativeBridge.installLogged = true
        log("R2 native Shortcut edge bridge ready: physical R2 is mapped "
            .. "before KH1 builds held/pressed/released states.")
    end
    return true
end

function JokCombatR2NativeBridge.initialize()
    JokCombatR2NativeBridge.ready = false
    JokCombatR2NativeBridge.ownedNow = false
    JokCombatR2NativeBridge.installLogged = false
    JokCombatR2NativeBridge.failureLogged = false

    -- Normalize this bridge or either rejected predecessor before validating
    -- the stock call site and zero-padded executable tail.
    JokCombatR2NativeBridge.restore("retired bridge recovery", true)
    if not JokCombatR2NativeBridge.activeNormal() then
        ConsolePrint("[JokCombat:r2-magic:fault] native edge bridge "
            .. "could not be normalized; R2 page disabled.")
        return false
    end
    JokCombatR2NativeBridge.ready = true
    return JokCombatR2NativeBridge.ensure()
end

function JokCombatR2ShortcutHighlight.matches(address, expected)
    return JokCombatR2NativeBridge.matchesAt(address, expected)
end

function JokCombatR2ShortcutHighlight.activeNormal()
    return JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.rowHookAddress,
            JokCombatR2ShortcutHighlight.rowHookNormal)
        and JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.rowCaveAddress,
            JokCombatR2ShortcutHighlight.rowCaveNormal)
        and JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.textHookAddress,
            JokCombatR2ShortcutHighlight.textHookNormal)
        and JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.textCaveAddress,
            JokCombatR2ShortcutHighlight.textCaveNormal)
end

function JokCombatR2ShortcutHighlight.activeOwned()
    return JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.rowHookAddress,
            JokCombatR2ShortcutHighlight.rowHookOwned)
        and JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.rowCaveAddress,
            JokCombatR2ShortcutHighlight.rowCaveOwned)
        and JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.textHookAddress,
            JokCombatR2ShortcutHighlight.textHookOwned)
        and JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.textCaveAddress,
            JokCombatR2ShortcutHighlight.textCaveOwned)
end

function JokCombatR2ShortcutHighlight.restore(reason, quiet)
    local rowHookOwned = JokCombatR2ShortcutHighlight.matches(
        JokCombatR2ShortcutHighlight.rowHookAddress,
        JokCombatR2ShortcutHighlight.rowHookOwned)
    local rowCaveOwned = JokCombatR2ShortcutHighlight.matches(
        JokCombatR2ShortcutHighlight.rowCaveAddress,
        JokCombatR2ShortcutHighlight.rowCaveOwned)
    local textHookOwned = JokCombatR2ShortcutHighlight.matches(
        JokCombatR2ShortcutHighlight.textHookAddress,
        JokCombatR2ShortcutHighlight.textHookOwned)
    local textCaveOwned = JokCombatR2ShortcutHighlight.matches(
        JokCombatR2ShortcutHighlight.textCaveAddress,
        JokCombatR2ShortcutHighlight.textCaveOwned)
    local wasOwned = JokCombatR2ShortcutHighlight.ownedNow
        or rowHookOwned or rowCaveOwned or textHookOwned or textCaveOwned

    -- Disconnect both callers before clearing executable tail padding.
    if rowHookOwned then
        WriteArray(JokCombatR2ShortcutHighlight.rowHookAddress,
            JokCombatR2ShortcutHighlight.rowHookNormal)
    end
    if textHookOwned then
        WriteArray(JokCombatR2ShortcutHighlight.textHookAddress,
            JokCombatR2ShortcutHighlight.textHookNormal)
    end
    local rowHookSafe = JokCombatR2ShortcutHighlight.matches(
        JokCombatR2ShortcutHighlight.rowHookAddress,
        JokCombatR2ShortcutHighlight.rowHookNormal)
    local textHookSafe = JokCombatR2ShortcutHighlight.matches(
        JokCombatR2ShortcutHighlight.textHookAddress,
        JokCombatR2ShortcutHighlight.textHookNormal)
    if rowCaveOwned and rowHookSafe then
        WriteArray(JokCombatR2ShortcutHighlight.rowCaveAddress,
            JokCombatR2ShortcutHighlight.rowCaveNormal)
    end
    if textCaveOwned and textHookSafe then
        WriteArray(JokCombatR2ShortcutHighlight.textCaveAddress,
            JokCombatR2ShortcutHighlight.textCaveNormal)
    end

    JokCombatR2ShortcutHighlight.ownedNow = false
    JokCombatR2ShortcutHighlight.ready =
        JokCombatR2ShortcutHighlight.activeNormal()
    if wasOwned and not JokCombatR2ShortcutHighlight.ready
        and not JokCombatR2ShortcutHighlight.failureLogged then
        JokCombatR2ShortcutHighlight.failureLogged = true
        ConsolePrint("[JokCombat:r2-highlight:fault] Shortcut text renderer "
            .. "changed by another writer; conditional restore left it "
            .. "untouched.")
    elseif wasOwned and not quiet then
        log("R2 selected-row highlight restored"
            .. (reason ~= nil and ": " .. reason or "."))
    end
    return wasOwned
end

function JokCombatR2ShortcutHighlight.ensure()
    if not CONFIG.r2MagicShortcutHighlight
        or not JokCombatR2ShortcutHighlight.ready then return false end
    if JokCombatR2ShortcutHighlight.activeOwned() then
        JokCombatR2ShortcutHighlight.ownedNow = true
        return true
    end
    if not JokCombatR2ShortcutHighlight.activeNormal() then
        JokCombatR2ShortcutHighlight.ready = false
        if not JokCombatR2ShortcutHighlight.failureLogged then
            JokCombatR2ShortcutHighlight.failureLogged = true
            ConsolePrint("[JokCombat:r2-highlight:fault] Steam Shortcut "
                .. "renderer signature mismatch; row highlight disabled.")
        end
        return false
    end

    -- Helpers first, generic RGB wrapper second, row redirect last. Until the
    -- final write succeeds no KH1 path can emit JokCombat's private sentinel.
    WriteArray(JokCombatR2ShortcutHighlight.rowCaveAddress,
        JokCombatR2ShortcutHighlight.rowCaveOwned)
    WriteArray(JokCombatR2ShortcutHighlight.textCaveAddress,
        JokCombatR2ShortcutHighlight.textCaveOwned)
    if not JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.rowCaveAddress,
            JokCombatR2ShortcutHighlight.rowCaveOwned)
        or not JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.textCaveAddress,
            JokCombatR2ShortcutHighlight.textCaveOwned) then
        JokCombatR2ShortcutHighlight.restore("helper write failed", true)
        return false
    end
    WriteArray(JokCombatR2ShortcutHighlight.textHookAddress,
        JokCombatR2ShortcutHighlight.textHookOwned)
    if not JokCombatR2ShortcutHighlight.matches(
            JokCombatR2ShortcutHighlight.textHookAddress,
            JokCombatR2ShortcutHighlight.textHookOwned) then
        JokCombatR2ShortcutHighlight.restore("RGB hook write failed", true)
        return false
    end
    WriteArray(JokCombatR2ShortcutHighlight.rowHookAddress,
        JokCombatR2ShortcutHighlight.rowHookOwned)
    if not JokCombatR2ShortcutHighlight.activeOwned() then
        JokCombatR2ShortcutHighlight.restore("row hook write failed", true)
        return false
    end

    JokCombatR2ShortcutHighlight.ownedNow = true
    return true
end

function JokCombatR2ShortcutHighlight.select(index)
    if not JokCombatR2ShortcutHighlight.ownedNow
        or not JokCombatR2Shortcut.journalValid() then return false end
    local mask = 0
    if index ~= nil and index >= 1 and index <= 3 then
        mask = 1 << (index - 1)
    end
    local address = ADDRESS.magicRecovery + 0x11
    if ReadByte(address) ~= mask then WriteByte(address, mask) end
    return ReadByte(address) == mask
end

function JokCombatR2ShortcutHighlight.initialize()
    JokCombatR2ShortcutHighlight.ready = false
    JokCombatR2ShortcutHighlight.ownedNow = false
    JokCombatR2ShortcutHighlight.failureLogged = false
    JokCombatR2ShortcutHighlight.restore("reload recovery", true)
    if not JokCombatR2ShortcutHighlight.activeNormal() then
        ConsolePrint("[JokCombat:r2-highlight:fault] selected-row renderer "
            .. "could not be normalized; highlight disabled.")
        return false
    end
    JokCombatR2ShortcutHighlight.ready = true
    return true
end

-- R2 is a second page of KH1's real three-slot Shortcut system. L1 remains the
-- untouched vanilla page. This follows Shortcut Sets' proven native-page model:
-- swap only the three real spell IDs. The signed bridge above converts physical
-- R2 before KH1 calculates input edges, so the original Shortcut dispatcher and
-- spell execution path remain responsible for the menu, casts, MP and effects.
function JokCombatR2Shortcut.validSlotValue(value)
    return value == 0xFF or (value >= 0 and value <= 6)
end

function JokCombatR2Shortcut.clearJournal()
    WriteByte(ADDRESS.magicRecovery + 0x11, 0)
    WriteLong(ADDRESS.magicRecovery, 0)
end

function JokCombatR2Shortcut.journalValid()
    local journal = ADDRESS.magicRecovery
    -- 0x01/0x21 and selector 0x20 are recovery-only values from rejected
    -- carriers. The active edge bridge owns neither control-map byte.
    local l2Owned = ReadByte(journal + 0x0E)
    local selectorOwned = ReadByte(journal + 0x0F)
    if ReadLong(journal) ~= JokCombatR2Shortcut.recoverySignature
        or ReadByte(journal + 0x08) ~= JokCombatR2Shortcut.recoveryMarker
        or (l2Owned ~= 0x01 and l2Owned ~= NORMAL.l2ControlMap
            and l2Owned ~= 0x21)
        or (selectorOwned ~= 0x20
            and selectorOwned ~= NORMAL.shortcutControlSelector)
        or ReadByte(journal + 0x10) ~= 0x53 then
        return false
    end
    for offset = 0x09, 0x0B do
        if not JokCombatR2Shortcut.validSlotValue(ReadByte(journal + offset)) then
            return false
        end
    end
    return true
end

function JokCombatR2Shortcut.publishJournal()
    if ReadLong(ADDRESS.magicRecovery) ~= 0
        or ReadByte(ADDRESS.l2ControlMap) ~= NORMAL.l2ControlMap
        or ReadByte(ADDRESS.shortcutControlSelector)
            ~= NORMAL.shortcutControlSelector then
        return false
    end
    for _, slot in ipairs(SHORTCUT_SLOTS) do
        if not JokCombatR2Shortcut.validSlotValue(ReadByte(slot.address)) then
            return false
        end
    end

    local journal = ADDRESS.magicRecovery
    WriteLong(journal, 0)
    WriteByte(journal + 0x08, JokCombatR2Shortcut.recoveryMarker)
    WriteByte(journal + 0x09, ReadByte(ADDRESS.nativeShortcutTriangle))
    WriteByte(journal + 0x0A, ReadByte(ADDRESS.nativeShortcutSquare))
    WriteByte(journal + 0x0B, ReadByte(ADDRESS.nativeShortcutCross))
    WriteByte(journal + 0x0C, ReadByte(ADDRESS.l2ControlMap))
    WriteByte(journal + 0x0D, ReadByte(ADDRESS.shortcutControlSelector))
    -- Both control-map bytes stay stock. The native edge bridge is gated by the
    -- C4 journal marker published above and never borrows L2's selector.
    WriteByte(journal + 0x0E, NORMAL.l2ControlMap)
    WriteByte(journal + 0x0F, NORMAL.shortcutControlSelector)
    WriteByte(journal + 0x10, 0x53)
    -- Bit 0/1/2 corresponds to the native Y/X/A row. The code hook also
    -- requires the signature written below, so publication remains atomic.
    WriteByte(journal + 0x11, 0x01)
    WriteLong(journal, JokCombatR2Shortcut.recoverySignature)
    return JokCombatR2Shortcut.journalValid()
end

function JokCombatR2Shortcut.restore(reason, quiet)
    local journal = ADDRESS.magicRecovery
    local ownedJournal = JokCombatR2Shortcut.journalValid()
    JokCombatR2ShortcutHighlight.select(0)
    local restored = 0
    if ownedJournal then
        local l2Owned = ReadByte(ADDRESS.l2ControlMap)
            == ReadByte(journal + 0x0E)
        local selectorCurrent = ReadByte(ADDRESS.shortcutControlSelector)
        local selectorOriginal = ReadByte(journal + 0x0D)
        local selectorExpected = ReadByte(journal + 0x0F)
        -- KH1 may reset the transient selector to its original value before
        -- Lua observes the R2 release. Both states are still ours to unwind.
        local selectorOwned = selectorCurrent == selectorExpected
            or (selectorExpected == 0x20
                and selectorCurrent == selectorOriginal)
        if l2Owned and selectorOwned then
            WriteByte(ADDRESS.nativeShortcutTriangle, ReadByte(journal + 0x09))
            WriteByte(ADDRESS.nativeShortcutSquare, ReadByte(journal + 0x0A))
            WriteByte(ADDRESS.nativeShortcutCross, ReadByte(journal + 0x0B))
            restored = restored + 3
        else
            ConsolePrint("[JokCombat:r2-magic:fault] Shortcut ownership "
                .. "changed while R2 was held; native slots left untouched.")
        end
        if l2Owned then
            WriteByte(ADDRESS.l2ControlMap, ReadByte(journal + 0x0C))
            restored = restored + 1
        end
        if selectorOwned then
            WriteByte(ADDRESS.shortcutControlSelector,
                ReadByte(journal + 0x0D))
            restored = restored + 1
        end
        JokCombatR2Shortcut.clearJournal()
    end
    JokCombatR2ShortcutHighlight.restore(reason, true)
    local wasActive = JokCombatR2Shortcut.active or ownedJournal
    JokCombatR2Shortcut.active = false
    if wasActive and not quiet then
        log(string.format("R2 native magic page restored (%s; %d fields).",
            reason or "modifier released", restored))
    end
    return ownedJournal
end

function JokCombatR2Shortcut.recoverStale()
    if ReadLong(ADDRESS.magicRecovery)
            ~= JokCombatR2Shortcut.recoverySignature then
        return false
    end
    if not JokCombatR2Shortcut.journalValid() then
        JokCombatR2Shortcut.clearJournal()
        ConsolePrint("[JokCombat:r2-magic:fault] invalid recovery journal "
            .. "cleared without touching Shortcut slots.")
        return false
    end
    JokCombatR2Shortcut.restore("F1/reload recovery")
    return true
end

function JokCombatR2Shortcut.initialize()
    JokCombatR2Shortcut.active = false
    JokCombatR2Shortcut.failedKey = nil
    if not JokCombatR2Shortcut.addressResolved then return false end
    JokCombatR2Shortcut.recoverStale()
    if ReadLong(ADDRESS.magicRecovery) ~= 0
        or ReadByte(ADDRESS.l2ControlMap) ~= NORMAL.l2ControlMap
        or ReadByte(ADDRESS.shortcutControlSelector)
            ~= NORMAL.shortcutControlSelector then
        return false
    end
    for _, slot in ipairs(SHORTCUT_SLOTS) do
        if not JokCombatR2Shortcut.validSlotValue(ReadByte(slot.address)) then
            return false
        end
    end
    return true
end

function JokCombatR2Shortcut.syncPage()
    if not JokCombatR2Shortcut.active
        or not JokCombatR2Shortcut.journalValid()
        or ReadByte(ADDRESS.l2ControlMap) ~= NORMAL.l2ControlMap
        or ReadByte(ADDRESS.shortcutControlSelector)
            ~= NORMAL.shortcutControlSelector then
        return false
    end
    for _, slot in ipairs(SHORTCUT_SLOTS) do
        local magic = JokCombatR2Shortcut.byId[loadout[slot.id]]
            or JokCombatR2Shortcut.byId.none
        if ReadByte(slot.address) ~= magic.index then
            WriteByte(slot.address, magic.index)
        end
    end
    return true
end

function JokCombatR2Shortcut.arm()
    if JokCombatR2Shortcut.active then
        return JokCombatR2Shortcut.syncPage()
    end

    -- A missing configuration is initialized only now, while the loaded save's
    -- learned-magic table and untouched L1 slots are both available. This
    -- guarantees that page two starts useful instead of cloning page one.
    if JokCombatR2Shortcut.needsInitialSeed then
        resetLoadoutToDefaults()
        if saveActionLoadout() then
            log(string.format(
                "R2 magic defaults seeded away from L1: Y=%s X=%s A=%s.",
                JokCombatR2Shortcut.byId[loadout.r2_triangle].name,
                JokCombatR2Shortcut.byId[loadout.r2_square].name,
                JokCombatR2Shortcut.byId[loadout.r2_cross].name))
        end
    end
    if not JokCombatR2Shortcut.publishJournal() then return false end

    if JokCombatR2ShortcutHighlight.ensure() then
        JokCombatR2ShortcutHighlight.select(1)
    end

    for _, slot in ipairs(SHORTCUT_SLOTS) do
        local magic = JokCombatR2Shortcut.byId[loadout[slot.id]]
            or JokCombatR2Shortcut.byId.none
        WriteByte(slot.address, magic.index)
    end
    JokCombatR2Shortcut.active = true
    if not JokCombatR2Shortcut.syncPage() then
        JokCombatR2Shortcut.restore("arm verification failed")
        return false
    end
    JokCombatR2Shortcut.failedKey = nil
    log("R2 second magic page armed: three native Shortcut slots swapped; "
        .. "edge bridge waiting for KH1's next controller sample.")
    return true
end

function JokCombatR2Shortcut.update(player, buttons, nativeLimitActive)
    local exactR2 = (buttons & SHOULDER_MASK) == BUTTON.R2
        and (buttons & (BUTTON.L1 | BUTTON.R1)) == 0
    local eligible = CONFIG.r2MagicShortcuts
        and JokCombatR2Shortcut.addressResolved
        and JokCombatR2NativeBridge.ensure() and exactR2
        and player ~= nil and not nativeLimitActive
    if not eligible then
        if JokCombatR2Shortcut.active then
            JokCombatR2Shortcut.restore("R2 context ended", true)
        end
        return false
    end

    if JokCombatR2Shortcut.arm() then return true end
    JokCombatR2Shortcut.restore("native Shortcut page failed", true)
    local key = string.format("%02X:%02X:%016X",
        ReadByte(ADDRESS.l2ControlMap),
        ReadByte(ADDRESS.shortcutControlSelector),
        ReadLong(ADDRESS.magicRecovery))
    if JokCombatR2Shortcut.failedKey ~= key then
        JokCombatR2Shortcut.failedKey = key
        log("R2 second magic page unavailable: native Shortcut slots or "
            .. "signed edge bridge were not accepted.")
    end
    return false
end

-- Four active Limits use KH1's real Reaction dispatcher. The adapter publishes
-- exactly one native Reaction ID before the final Y, then KH1 owns target
-- selection, movement, animation, VFX, hitboxes, damage and follow-ups. Each
-- active Limit borrows its table cost at zero. The retired Trinity entry is
-- retained only so an F1 reload can restore a journal created by v2.0.0.
--
-- Keep the table global to avoid Lua 5.3's 200-local chunk limit. Every write
-- is journaled first and restored only while the destination still contains
-- JokCombat's exact owned value.
JokCombatNativeLimit = {
    catalog = {
        { id = "sonic_blade", index = 1, tag = "sonic",
            name = "Sonic Blade", path = "XTT", prefix = "XT",
            reactionId = 0x004B, costAddress = ADDRESS.sonicBladeCost,
            context = "ground" },
        { id = "ars_arcanum", index = 2, tag = "ars",
            name = "Ars Arcanum", path = "TTTTT", prefix = "TTTT",
            reactionId = 0x0057, costAddress = ADDRESS.arsArcanumCost,
            context = "ground" },
        { id = "strike_raid", index = 3, tag = "raid",
            name = "Strike Raid", path = "XXXT", prefix = "XXX",
            carryPath = "XXXT",
            reactionId = 0x005E, costAddress = ADDRESS.strikeRaidCost,
            context = "both" },
        { id = "ragnarok", index = 4, tag = "ragnarok",
            name = "Ragnarok", path = "XXXXTT", prefix = "XXXXT",
            reactionId = 0x005A, costAddress = ADDRESS.ragnarokCost,
            context = "both" },
        { id = "trinity_limit", index = 5, tag = "trinity",
            name = "Trinity Limit", path = "XXTTT",
            prefix = "XXTT", reactionId = 0x0052,
            context = "ground", partyRequired = true,
            restorePartyMP = true, retired = true },
    },
    byId = {},
    byIndex = {},
    recoverySignature = 0x0031304D494C4B4A, -- "JKLIM01\0"
    legacySonicSignature = 0x003130434E534B4A, -- "JKSNC01\0"
    recoveryMarker = 0xB8,
    legacySonicMarker = 0xB7,
    timeoutFrames = 180,
    selectionGraceFrames = 20,
    limitExitGraceFrames = 12,
    limitTimeoutFrames = 3600,
    writerOriginal = { 0xC6, 0x05, 0x0C, 0x46, 0x29, 0x00, 0x42 },
    writer2Original = { 0xC6, 0x05, 0xE2, 0x3F, 0x29, 0x00, 0x00 },
    writerOwned = { 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90 },
    activeId = nil,
    armed = false,
    frames = 0,
    selectionFrames = 0,
    activationFrames = 0,
    activationObserved = false,
    selectorRestored = false,
    continuationCrossPending = false,
    continuationCancelled = false,
    -- A real final Y may arrive while the parent Action still owns Sora. KH1
    -- cannot consume that edge yet, so this bounded native input latch keeps
    -- the same request alive until the Reaction dispatcher accepts it.
    finalInputPending = false,
    finalInputMarker = 0xA19C,
}

function JokCombatNativeLimit.buildIndex()
    JokCombatNativeLimit.byId = {}
    JokCombatNativeLimit.byIndex = {}
    for _, limit in ipairs(JokCombatNativeLimit.catalog) do
        limit.available = false
        JokCombatNativeLimit.byId[limit.id] = limit
        JokCombatNativeLimit.byIndex[limit.index] = limit
    end
end

function JokCombatNativeLimit.bytesMatch(address, expected)
    for index = 1, #expected do
        if ReadByte(address + index - 1) ~= expected[index] then
            return false
        end
    end
    return true
end

function JokCombatNativeLimit.writeIfOwned(address, owned, original)
    if not JokCombatNativeLimit.bytesMatch(address, owned) then return false end
    WriteArray(address, original)
    return JokCombatNativeLimit.bytesMatch(address, original)
end

function JokCombatNativeLimit.clearJournal()
    WriteShort(ADDRESS.magicRecovery + 0x16, 0)
    WriteLong(ADDRESS.magicRecovery, 0)
end

function JokCombatNativeLimit.journalLimit()
    if ReadLong(ADDRESS.magicRecovery)
            ~= JokCombatNativeLimit.recoverySignature
        or ReadByte(ADDRESS.magicRecovery + 0x08)
            ~= JokCombatNativeLimit.recoveryMarker
        or ReadByte(ADDRESS.magicRecovery + 0x0E) ~= 0x5A then
        return nil
    end
    local limit = JokCombatNativeLimit.byIndex[
        ReadByte(ADDRESS.magicRecovery + 0x09)]
    if limit == nil then return nil end
    local flags = ReadByte(ADDRESS.magicRecovery + 0x0F)
    if limit.costAddress ~= nil and (flags & 0x01) == 0 then return nil end
    if limit.restorePartyMP
        and ((flags & 0x02) == 0
            or ReadByte(ADDRESS.magicRecovery + 0x15) ~= 0xA6) then
        return nil
    end
    return limit
end

function JokCombatNativeLimit.journalValid()
    return JokCombatNativeLimit.journalLimit() ~= nil
end

function JokCombatNativeLimit.partyMpBase(player)
    if player == nil then return nil end
    local slot = ReadShort(player.pointer + PLAYER.slotReference, true)
    if slot < 0x8000 or slot > 0xFFFF then return nil end
    return ADDRESS.battleSlotBase + slot, slot
end

function JokCombatNativeLimit.publishJournal(limit, player)
    local journal = ADDRESS.magicRecovery
    local costOriginal = limit.costAddress ~= nil
        and ReadShort(limit.costAddress) or 0
    local flags = limit.costAddress ~= nil and 0x01 or 0x00
    local slot = 0
    local soraMP, ally1MP, ally2MP = 0, 0, 0
    if limit.restorePartyMP then
        local base = nil
        base, slot = JokCombatNativeLimit.partyMpBase(player)
        if base == nil then return false end
        flags = flags | 0x02
        soraMP = ReadByte(base + 0x44)
        ally1MP = ReadByte(base + 0x144)
        ally2MP = ReadByte(base + 0x244)
    end

    -- Signature last: an interrupted publication cannot authorize recovery
    -- from partially written snapshot fields.
    WriteLong(journal, 0)
    WriteByte(journal + 0x08, JokCombatNativeLimit.recoveryMarker)
    WriteByte(journal + 0x09, limit.index)
    WriteShort(journal + 0x0A, costOriginal)
    WriteShort(journal + 0x0C, ReadShort(ADDRESS.reactionCommandId))
    WriteByte(journal + 0x0E, 0x5A)
    WriteByte(journal + 0x0F, flags)
    WriteShort(journal + 0x10, slot)
    WriteByte(journal + 0x12, soraMP)
    WriteByte(journal + 0x13, ally1MP)
    WriteByte(journal + 0x14, ally2MP)
    WriteByte(journal + 0x15, limit.restorePartyMP and 0xA6 or 0x00)
    WriteShort(journal + 0x16, 0)
    WriteLong(journal, JokCombatNativeLimit.recoverySignature)
    return JokCombatNativeLimit.journalLimit() == limit
        and ReadShort(journal + 0x0A) == costOriginal
end

function JokCombatNativeLimit.restorePartyMpSnapshot()
    local limit = JokCombatNativeLimit.journalLimit()
    local journal = ADDRESS.magicRecovery
    if limit == nil or not limit.restorePartyMP
        or (ReadByte(journal + 0x0F) & 0x02) == 0 then return 0 end
    local slot = ReadShort(journal + 0x10)
    if slot < 0x8000 or slot > 0xFFFF then return 0 end
    local base = ADDRESS.battleSlotBase + slot
    local addresses = { base + 0x44, base + 0x144, base + 0x244 }
    local restored = 0
    for index, address in ipairs(addresses) do
        local original = ReadByte(journal + 0x11 + index)
        if ReadByte(address) < original then
            WriteByte(address, original)
            restored = restored + 1
        end
    end
    return restored
end

function JokCombatNativeLimit.finalInputOwned()
    return JokCombatNativeLimit.journalLimit() ~= nil
        and ReadShort(ADDRESS.magicRecovery + 0x16)
            == JokCombatNativeLimit.finalInputMarker
end

function JokCombatNativeLimit.restoreFinalInputLatch()
    local owned = JokCombatNativeLimit.finalInputOwned()
    local restored = 0
    if owned and ReadByte(ADDRESS.autoReaction) == 0x01 then
        WriteByte(ADDRESS.autoReaction, 0x00)
        if ReadByte(ADDRESS.autoReaction) == 0x00 then restored = 1 end
    end
    if owned then WriteShort(ADDRESS.magicRecovery + 0x16, 0) end
    JokCombatNativeLimit.finalInputPending = false
    return restored
end

function JokCombatNativeLimit.maintainFinalInputLatch()
    if not JokCombatNativeLimit.finalInputPending
        or JokCombatNativeLimit.activationObserved
        or not JokCombatNativeLimit.journalValid() then return false end

    if JokCombatNativeLimit.finalInputOwned() then
        -- KH1 is allowed to consume the level. Reassert only the value that
        -- this journal owns; any third-party value makes the latch stand down.
        local current = ReadByte(ADDRESS.autoReaction)
        if current == 0x00 then WriteByte(ADDRESS.autoReaction, 0x01) end
        if ReadByte(ADDRESS.autoReaction) == 0x01 then return true end
        JokCombatNativeLimit.finalInputPending = false
        return false
    end

    local current = ReadByte(ADDRESS.autoReaction)
    if current == 0x01 then
        -- The physical edge may still own this frame. Wait for its native
        -- level to fall before claiming the byte for the buffered request.
        return false
    end
    if current ~= 0x00 then
        JokCombatNativeLimit.finalInputPending = false
        log(string.format(
            "[limit] final-Y latch unavailable: Auto-Reaction=0x%02X.",
            current))
        return false
    end

    -- Journal first: an F1 reload between these two writes can safely restore
    -- only the exact 0x01 level JokCombat subsequently owns.
    WriteShort(ADDRESS.magicRecovery + 0x16,
        JokCombatNativeLimit.finalInputMarker)
    WriteByte(ADDRESS.autoReaction, 0x01)
    if JokCombatNativeLimit.finalInputOwned()
        and ReadByte(ADDRESS.autoReaction) == 0x01 then return true end
    if ReadByte(ADDRESS.autoReaction) == 0x01 then
        WriteByte(ADDRESS.autoReaction, 0x00)
    end
    WriteShort(ADDRESS.magicRecovery + 0x16, 0)
    JokCombatNativeLimit.finalInputPending = false
    return false
end

function JokCombatNativeLimit.acceptFinalInput(limitId, player)
    if not JokCombatNativeLimit.armed then
        if not JokCombatNativeLimit.arm(limitId, player) then return false end
    end
    if JokCombatNativeLimit.activeId ~= limitId
        or JokCombatNativeLimit.activationObserved then return false end
    local limit = JokCombatNativeLimit.byId[limitId]
    if limit == nil then return false end
    local firstRequest = not JokCombatNativeLimit.finalInputPending
        and not JokCombatNativeLimit.finalInputOwned()
    JokCombatNativeLimit.selectionFrames =
        JokCombatNativeLimit.selectionGraceFrames
    JokCombatNativeLimit.finalInputPending = true
    JokCombatNativeLimit.maintainFinalInputLatch()
    if firstRequest then
        log(string.format(
            "[limit:%s] first final Y latched once for native %s.",
            limit.tag, limit.name))
    end
    return true
end

function JokCombatNativeLimit.restore(reason, quiet)
    local journal = ADDRESS.magicRecovery
    local limit = JokCombatNativeLimit.journalLimit()
    local ownsJournal = limit ~= nil
    local active = JokCombatNativeLimit.byId[JokCombatNativeLimit.activeId]
    local restored = 0
    if ownsJournal then
        restored = restored
            + JokCombatNativeLimit.restoreFinalInputLatch()
        local reactionOriginal = ReadShort(journal + 0x0C)
        if JokCombatNativeLimit.writeIfOwned(
                ADDRESS.reactionWriter,
                JokCombatNativeLimit.writerOwned,
                JokCombatNativeLimit.writerOriginal) then
            restored = restored + 1
        end
        if JokCombatNativeLimit.writeIfOwned(
                ADDRESS.reactionWriter2,
                JokCombatNativeLimit.writerOwned,
                JokCombatNativeLimit.writer2Original) then
            restored = restored + 1
        end
        if ReadByte(ADDRESS.reactionEnableFlag) == 0xF2 then
            WriteByte(ADDRESS.reactionEnableFlag, 0xFB)
            restored = restored + 1
        end
        if ReadByte(ADDRESS.reactionEnableFlag2) == 0xF2 then
            WriteByte(ADDRESS.reactionEnableFlag2, 0xFB)
            restored = restored + 1
        end
        if ReadShort(ADDRESS.reactionCommandId) == limit.reactionId then
            WriteShort(ADDRESS.reactionCommandId, reactionOriginal)
            restored = restored + 1
        end
        if limit.costAddress ~= nil
            and ReadShort(limit.costAddress) == 0 then
            WriteShort(limit.costAddress, ReadShort(journal + 0x0A))
            restored = restored + 1
        end
        restored = restored
            + JokCombatNativeLimit.restorePartyMpSnapshot()
        JokCombatNativeLimit.clearJournal()
    end
    local wasArmed = JokCombatNativeLimit.armed or ownsJournal
    local label = limit or active
    JokCombatNativeLimit.activeId = nil
    JokCombatNativeLimit.armed = false
    JokCombatNativeLimit.frames = 0
    JokCombatNativeLimit.selectionFrames = 0
    JokCombatNativeLimit.activationFrames = 0
    JokCombatNativeLimit.activationObserved = false
    JokCombatNativeLimit.selectorRestored = false
    JokCombatNativeLimit.finalInputPending = false
    JokCombatNativeLimit.continuationCrossPending = false
    JokCombatNativeLimit.continuationCancelled = false
    if wasArmed and not quiet then
        log(string.format(
            "[limit:%s] native selector restored (%s; %d owned fields).",
            label ~= nil and label.tag or "unknown",
            reason or "closed", restored))
    end
    return ownsJournal
end

function JokCombatNativeLimit.recoverLegacySonic()
    local journal = ADDRESS.magicRecovery
    if ReadLong(journal) ~= JokCombatNativeLimit.legacySonicSignature then
        return false
    end
    if ReadByte(journal + 0x08) ~= JokCombatNativeLimit.legacySonicMarker
        or ReadByte(journal + 0x0E) ~= 0x5A then
        ConsolePrint("[JokCombat:limit:fault] incomplete v0.11.0 Sonic "
            .. "journal; native Limits disabled without guessing originals.")
        return false
    end
    local restored = 0
    if JokCombatNativeLimit.writeIfOwned(
            ADDRESS.reactionWriter, JokCombatNativeLimit.writerOwned,
            JokCombatNativeLimit.writerOriginal) then restored = restored + 1 end
    if JokCombatNativeLimit.writeIfOwned(
            ADDRESS.reactionWriter2, JokCombatNativeLimit.writerOwned,
            JokCombatNativeLimit.writer2Original) then restored = restored + 1 end
    if ReadByte(ADDRESS.reactionEnableFlag) == 0xF2 then
        WriteByte(ADDRESS.reactionEnableFlag, 0xFB)
        restored = restored + 1
    end
    if ReadByte(ADDRESS.reactionEnableFlag2) == 0xF2 then
        WriteByte(ADDRESS.reactionEnableFlag2, 0xFB)
        restored = restored + 1
    end
    if ReadShort(ADDRESS.reactionCommandId) == 0x004B then
        WriteShort(ADDRESS.reactionCommandId, ReadShort(journal + 0x0C))
        restored = restored + 1
    end
    if ReadShort(ADDRESS.sonicBladeCost) == 0 then
        WriteShort(ADDRESS.sonicBladeCost, ReadShort(journal + 0x0A))
        restored = restored + 1
    end
    JokCombatNativeLimit.clearJournal()
    ConsolePrint(string.format(
        "[JokCombat:limit:recovery] v0.11.0 Sonic state restored "
            .. "(%d owned fields).", restored))
    return true
end

function JokCombatNativeLimit.recoverStale()
    if ReadLong(ADDRESS.magicRecovery)
            ~= JokCombatNativeLimit.recoverySignature then
        return false
    end
    if not JokCombatNativeLimit.journalValid() then
        ConsolePrint("[JokCombat:limit:fault] recovery journal is incomplete; "
            .. "native Limits disabled without guessing originals.")
        return false
    end
    JokCombatNativeLimit.restore("F1/reload recovery")
    return true
end

function JokCombatNativeLimit.dispatcherCanonical()
    return ReadByte(ADDRESS.reactionEnableFlag) == 0xFB
        and ReadByte(ADDRESS.reactionEnableFlag2) == 0xFB
        and JokCombatNativeLimit.bytesMatch(
            ADDRESS.reactionWriter, JokCombatNativeLimit.writerOriginal)
        and JokCombatNativeLimit.bytesMatch(
            ADDRESS.reactionWriter2, JokCombatNativeLimit.writer2Original)
end

function JokCombatNativeLimit.initialize()
    JokCombatNativeLimit.buildIndex()
    JokCombatNativeLimit.activeId = nil
    JokCombatNativeLimit.armed = false
    JokCombatNativeLimit.finalInputPending = false
    JokCombatNativeLimit.continuationCrossPending = false
    JokCombatNativeLimit.continuationCancelled = false
    JokCombatNativeLimit.recoverLegacySonic()
    JokCombatNativeLimit.recoverStale()
    if ReadLong(ADDRESS.magicRecovery) ~= 0 then
        ConsolePrint("[JokCombat:limit] recovery block is occupied; all "
            .. "native combo Limit adapters disabled.")
        return 0
    end
    if not JokCombatNativeLimit.dispatcherCanonical() then
        ConsolePrint("[JokCombat:limit] Steam dispatcher fingerprint mismatch; "
            .. "all adapters disabled without writing code.")
        return 0
    end

    local ready = 0
    for _, limit in ipairs(JokCombatNativeLimit.catalog) do
        local valid = true
        if limit.costAddress ~= nil then
            local cost = ReadShort(limit.costAddress)
            valid = cost >= 0 and cost <= 1000
            if not valid then
                ConsolePrint(string.format(
                    "[JokCombat:limit:%s] unexpected MP cost %d; adapter "
                        .. "disabled.", limit.tag, cost))
            end
        end
        limit.available = CONFIG.branchLimits and valid
            and limit.retired ~= true
        if limit.available then ready = ready + 1 end
    end
    return ready
end

function JokCombatNativeLimit.partyReady()
    local first = ReadByte(ADDRESS.partyMember1)
    local second = ReadByte(ADDRESS.partyMember2)
    return (first == 0x01 and second == 0x02)
        or (first == 0x02 and second == 0x01)
end

function JokCombatNativeLimit.isAvailable(limitId)
    local limit = JokCombatNativeLimit.byId[limitId]
    return limit ~= nil and limit.available == true
end

function JokCombatNativeLimit.contextReady(limitId, player)
    local limit = JokCombatNativeLimit.byId[limitId]
    if limit == nil or not limit.available or player == nil
        or ReadByte(ADDRESS.world) == 0x09
        or ReadByte(player.pointer + PLAYER.airborneState, true) >= 0x20 then
        return false
    end
    if limit.context == "ground" and player.airborne then return false end
    if limit.context == "air" and not player.airborne then return false end
    if limit.partyRequired and not JokCombatNativeLimit.partyReady() then
        return false
    end
    return true
end

function JokCombatNativeLimit.forPrefix(prefix)
    for _, limit in ipairs(JokCombatNativeLimit.catalog) do
        if limit.prefix == prefix then return limit end
    end
    return nil
end

function JokCombatNativeLimit.formatPath(path)
    local parts = {}
    for index = 1, #path do
        table.insert(parts, path:sub(index, index) == "T" and "Y" or "A")
    end
    return table.concat(parts, " ")
end

function JokCombatNativeLimit.arm(limitId, player)
    local limit = JokCombatNativeLimit.byId[limitId]
    if JokCombatNativeLimit.armed then
        return JokCombatNativeLimit.activeId == limitId
    end
    if limit == nil or not JokCombatNativeLimit.contextReady(limitId, player)
        or not HUD.nativeRootSelectionAvailable()
        or ReadShort(ADDRESS.reactionCommandId) ~= 0
        or ReadLong(ADDRESS.magicRecovery) ~= 0
        or not JokCombatNativeLimit.dispatcherCanonical() then
        return false
    end

    if limit.costAddress ~= nil then
        local cost = ReadShort(limit.costAddress)
        if cost < 0 or cost > 1000 then return false end
    end
    if not JokCombatNativeLimit.publishJournal(limit, player) then
        ConsolePrint(string.format(
            "[JokCombat:limit:%s] selector journal failed; no dispatcher "
                .. "field was changed.", limit.tag))
        return false
    end

    if limit.costAddress ~= nil then WriteShort(limit.costAddress, 0) end
    WriteArray(ADDRESS.reactionWriter, JokCombatNativeLimit.writerOwned)
    WriteArray(ADDRESS.reactionWriter2, JokCombatNativeLimit.writerOwned)
    WriteByte(ADDRESS.reactionEnableFlag, 0xF2)
    WriteByte(ADDRESS.reactionEnableFlag2, 0xF2)
    WriteShort(ADDRESS.reactionCommandId, limit.reactionId)

    local verified = (limit.costAddress == nil
            or ReadShort(limit.costAddress) == 0)
        and ReadShort(ADDRESS.reactionCommandId) == limit.reactionId
        and ReadByte(ADDRESS.reactionEnableFlag) == 0xF2
        and ReadByte(ADDRESS.reactionEnableFlag2) == 0xF2
        and JokCombatNativeLimit.bytesMatch(
            ADDRESS.reactionWriter, JokCombatNativeLimit.writerOwned)
        and JokCombatNativeLimit.bytesMatch(
            ADDRESS.reactionWriter2, JokCombatNativeLimit.writerOwned)
    if not verified then
        JokCombatNativeLimit.activeId = limitId
        JokCombatNativeLimit.restore("arm verification failed")
        limit.available = false
        return false
    end

    JokCombatNativeLimit.activeId = limitId
    JokCombatNativeLimit.armed = true
    JokCombatNativeLimit.frames = JokCombatNativeLimit.timeoutFrames
    JokCombatNativeLimit.selectionFrames = 0
    JokCombatNativeLimit.activationFrames = 0
    JokCombatNativeLimit.activationObserved = false
    JokCombatNativeLimit.selectorRestored = false
    JokCombatNativeLimit.continuationCrossPending = false
    JokCombatNativeLimit.continuationCancelled = false
    log(string.format(
        "[limit:%s] %s accepted; native %s pre-armed %s. "
            .. "Final Y belongs to KH1.",
        limit.tag, JokCombatNativeLimit.formatPath(limit.prefix), limit.name,
        limit.restorePartyMP and "with party MP preserved" or "at 0 MP"))
    return true
end

function JokCombatNativeLimit.activeState(player)
    return player ~= nil and ReadByte(
        player.pointer + PLAYER.airborneState, true) >= 0x20
end

function JokCombatNativeLimit.selectorOwned()
    return JokCombatNativeLimit.armed
        and not JokCombatNativeLimit.activationObserved
end

function JokCombatNativeLimit.restoreSelectorOwned()
    local limit = JokCombatNativeLimit.byId[JokCombatNativeLimit.activeId]
    if limit == nil or JokCombatNativeLimit.selectorRestored
        or JokCombatNativeLimit.journalLimit() ~= limit then return 0 end
    local restored = 0
    local reactionOriginal = ReadShort(ADDRESS.magicRecovery + 0x0C)
    if JokCombatNativeLimit.writeIfOwned(
            ADDRESS.reactionWriter,
            JokCombatNativeLimit.writerOwned,
            JokCombatNativeLimit.writerOriginal) then
        restored = restored + 1
    end
    if JokCombatNativeLimit.writeIfOwned(
            ADDRESS.reactionWriter2,
            JokCombatNativeLimit.writerOwned,
            JokCombatNativeLimit.writer2Original) then
        restored = restored + 1
    end
    if ReadByte(ADDRESS.reactionEnableFlag) == 0xF2 then
        WriteByte(ADDRESS.reactionEnableFlag, 0xFB)
        restored = restored + 1
    end
    if ReadByte(ADDRESS.reactionEnableFlag2) == 0xF2 then
        WriteByte(ADDRESS.reactionEnableFlag2, 0xFB)
        restored = restored + 1
    end
    if ReadShort(ADDRESS.reactionCommandId) == limit.reactionId then
        WriteShort(ADDRESS.reactionCommandId, reactionOriginal)
        restored = restored + 1
    end
    JokCombatNativeLimit.selectorRestored = true
    log(string.format(
        "[limit:%s] Reaction selector released; %s remains owned for the "
            .. "native Limit (%d fields restored).",
        limit.tag, limit.restorePartyMP and "party MP snapshot"
            or "MP cost 0", restored))
    return restored
end

function JokCombatNativeLimit.finish(reason)
    JokCombatNativeLimit.restore(reason)
    if JokCombatBranch ~= nil and JokCombatBranch.active then
        JokCombatBranch.reset(reason, true)
    end
end

function JokCombatNativeLimit.update(player, buttons)
    if not JokCombatNativeLimit.armed then return false end
    local limit = JokCombatNativeLimit.byId[JokCombatNativeLimit.activeId]
    if player == nil or limit == nil then
        JokCombatNativeLimit.finish("player unavailable")
        return false
    end

    local limitActive = JokCombatNativeLimit.activeState(player)
    if not JokCombatNativeLimit.activationObserved and not limitActive
        and JokCombatBranch ~= nil
        and JokCombatBranch.path == limit.prefix
        and JokCombatBranch.animation ~= nil
        and player.animation ~= JokCombatBranch.animation
        -- The real final Y may have reached KH1 just before the parent Action
        -- ends. Preserve the journaled selector for its bounded selection
        -- grace so a slower native Limit transition can still become visible.
        and JokCombatNativeLimit.selectionFrames <= 0 then
        JokCombatNativeLimit.finish("parent Action ended before final Y")
        return false
    end
    local nonTriangleFace = BUTTON.CROSS | BUTTON.CIRCLE | BUTTON.SQUARE
    local nonTriangleStarted = (buttons & nonTriangleFace) ~= 0
        and (lastButtons & nonTriangleFace) == 0
    local modifierMask = BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2
    local modifierHeld = (buttons & modifierMask) ~= 0
    local modifierStarted = modifierHeld
        and (lastButtons & modifierMask) == 0
    local crossStarted = (buttons & BUTTON.CROSS) ~= 0
        and (lastButtons & BUTTON.CROSS) == 0
    if not JokCombatNativeLimit.activationObserved
        and (ReadByte(ADDRESS.world) == 0x09
            or nonTriangleStarted or modifierStarted) then
        JokCombatNativeLimit.finish("combo selector cancelled")
        return false
    end

    local triangleStarted = (buttons & BUTTON.TRIANGLE) ~= 0
        and (lastButtons & BUTTON.TRIANGLE) == 0
    if triangleStarted and not JokCombatNativeLimit.activationObserved
        and not limitActive then
        JokCombatNativeLimit.acceptFinalInput(limit.id, player)
    end

    if limitActive then
        -- A brief raw-state gap inside a multi-stage Limit is not completion.
        -- Forget inputs seen during such a gap if KH1 resumes Limit ownership.
        JokCombatNativeLimit.continuationCrossPending = false
        JokCombatNativeLimit.continuationCancelled = false
        if not JokCombatNativeLimit.activationObserved then
            JokCombatNativeLimit.activationObserved = true
            JokCombatNativeLimit.frames =
                JokCombatNativeLimit.limitTimeoutFrames
            JokCombatNativeLimit.restoreFinalInputLatch()
            JokCombatNativeLimit.restoreSelectorOwned()
            JokCombatNativeLimit.restorePartyMpSnapshot()
            -- The Reaction has entered KH1's native Limit state. Close only
            -- the Musou prefix so its own follow-up inputs are never hidden.
            if JokCombatBranch ~= nil and JokCombatBranch.active then
                JokCombatBranch.reset(
                    "native " .. limit.name .. " owns follow-ups", true)
            end
            log(string.format(
                "[limit:%s] native %s entered: anim=0x%02X "
                    .. "secondary=0x%02X.",
                limit.tag, limit.name, player.animation, player.secondary))
        end
        JokCombatNativeLimit.restorePartyMpSnapshot()
        JokCombatNativeLimit.activationFrames =
            JokCombatNativeLimit.limitExitGraceFrames
        JokCombatNativeLimit.frames = JokCombatNativeLimit.frames - 1
        if JokCombatNativeLimit.frames <= 0 then
            JokCombatNativeLimit.finish("native Limit safety timeout")
            return false
        end
        return true
    end

    JokCombatNativeLimit.maintainFinalInputLatch()

    if JokCombatNativeLimit.activationObserved then
        local otherFaceStarted = (buttons & (BUTTON.CIRCLE | BUTTON.SQUARE)) ~= 0
            and (lastButtons & (BUTTON.CIRCLE | BUTTON.SQUARE)) == 0
        if modifierStarted or triangleStarted or otherFaceStarted
            or (crossStarted and modifierHeld) then
            JokCombatNativeLimit.continuationCancelled = true
            JokCombatNativeLimit.continuationCrossPending = false
        elseif crossStarted and not player.airborne then
            -- Leave the edge native. If KH1 accepts it before the exit grace
            -- expires, the branch-depth controller will recognize C8-CA.
            JokCombatNativeLimit.continuationCrossPending = true
        end
        JokCombatNativeLimit.restorePartyMpSnapshot()
        JokCombatNativeLimit.frames = JokCombatNativeLimit.frames - 1
        JokCombatNativeLimit.activationFrames =
            JokCombatNativeLimit.activationFrames - 1
        if JokCombatNativeLimit.frames <= 0 then
            JokCombatNativeLimit.finish("native Limit safety timeout")
        elseif JokCombatNativeLimit.activationFrames <= 0 then
            local carryPath = limit.carryPath or limit.prefix
            local carryName = limit.name
            local carryCross =
                JokCombatNativeLimit.continuationCrossPending
            local carryAllowed =
                not JokCombatNativeLimit.continuationCancelled
            JokCombatNativeLimit.finish("native Limit ended")
            if carryAllowed and JokCombatBranch ~= nil then
                JokCombatBranch.armDepthCarry(
                    carryPath, carryName, player, carryCross)
            end
        end
        return true
    end

    local reaction = ReadShort(ADDRESS.reactionCommandId)
    if reaction ~= limit.reactionId then
        if JokCombatNativeLimit.selectionFrames > 0 then
            JokCombatNativeLimit.selectionFrames =
                JokCombatNativeLimit.selectionFrames - 1
        else
            JokCombatNativeLimit.finish("native selector closed")
            return false
        end
    end

    JokCombatNativeLimit.frames = JokCombatNativeLimit.frames - 1
    if JokCombatNativeLimit.frames <= 0 then
        JokCombatNativeLimit.finish("selector timeout")
        return false
    end
    return true
end

-- Counterattack is deliberately outside the offensive A/Y tree. The
-- connectCounter byte is observed read-only and becomes actionable only when
-- it reports 0x10 during the D4 Guard animation after JokCombat itself has
-- accepted L2+Circle. A normal physical A then requests the canonical D5
-- action record; merely guarding, attacking after a miss, or deflecting with
-- another animation can never satisfy all three conditions.
JokCombatGuardCounter = {
    slot = { id = "guard_counter", label = "Guard + A" },
    guardAnimation = 0xD4,
    connectValue = 0x10,
    attemptFrames = 0,
    windowFrames = 0,
}

function JokCombatGuardCounter.initialize()
    JokCombatGuardCounter.attemptFrames = 0
    JokCombatGuardCounter.windowFrames = 0
    return true
end

function JokCombatGuardCounter.reset(reason, quiet)
    local wasOpen = JokCombatGuardCounter.windowFrames > 0
        or JokCombatGuardCounter.attemptFrames > 0
    JokCombatGuardCounter.attemptFrames = 0
    JokCombatGuardCounter.windowFrames = 0
    if wasOpen and not quiet and reason ~= nil then
        log("[guard-counter] closed: " .. reason .. ".")
    end
end

function JokCombatGuardCounter.begin()
    JokCombatGuardCounter.attemptFrames =
        CONFIG.guardCounterAttemptFrames
    JokCombatGuardCounter.windowFrames = 0
end

function JokCombatGuardCounter.update(player, buttons)
    local signal = ReadByte(ADDRESS.connectCounter)
    if JokCombatGuardCounter.attemptFrames > 0 then
        if signal == JokCombatGuardCounter.connectValue
            and player ~= nil and not player.airborne
            and player.animation == JokCombatGuardCounter.guardAnimation then
            JokCombatGuardCounter.attemptFrames = 0
            JokCombatGuardCounter.windowFrames =
                CONFIG.guardCounterWindowFrames
            log(string.format(
                "[guard-counter] successful Guard observed: signal=0x%02X "
                    .. "anim=0x%02X; physical A window opened for %d frames.",
                signal, player.animation,
                JokCombatGuardCounter.windowFrames))
        else
            JokCombatGuardCounter.attemptFrames =
                JokCombatGuardCounter.attemptFrames - 1
        end
    end

    if JokCombatGuardCounter.windowFrames > 0 then
        local invalid = player == nil or player.airborne
            or ReadByte(ADDRESS.world) == 0x09
            or (buttons & (BUTTON.L1 | BUTTON.R1 | BUTTON.R2)) ~= 0
        if invalid then
            JokCombatGuardCounter.reset("context changed", true)
        else
            JokCombatGuardCounter.windowFrames =
                JokCombatGuardCounter.windowFrames - 1
        end
    end
end

function JokCombatGuardCounter.ready(player)
    return JokCombatGuardCounter.windowFrames > 0
        and player ~= nil and not player.airborne
        and ACTION_BY_ID.counterattack ~= nil
        and ACTION_BY_ID.counterattack.recordAvailable == true
        and HUD.nativeRootSelectionAvailable()
end

function JokCombatGuardCounter.guideEntries(player)
    if not JokCombatGuardCounter.ready(player) then return nil end
    return { "[A] Counterattack", "-", "-", "-" }
end

function JokCombatGuardCounter.dispatch(player)
    if not JokCombatGuardCounter.ready(player) then return false end
    JokCombatGuardCounter.attemptFrames = 0
    JokCombatGuardCounter.windowFrames = 0
    if JokCombatBranch ~= nil and JokCombatBranch.active then
        JokCombatBranch.reset("Guard Counterattack", true)
    end
    local requested = requestActionAbility(
        player, JokCombatGuardCounter.slot,
        ACTION_BY_ID.counterattack, false, true)
    if requested then
        log("[guard-counter] physical A consumed by native Counterattack D5.")
    end
    return requested
end

-- KH1's ground Attack candidate builder reaches RVA 0x2A70D5 only after the
-- selected target crosses its native vertical threshold. The stock block then
-- chooses candidate 0 (D6 Aerial Sweep) when ability bit 0x02 is active, or
-- candidate 1 (CD ordinary aerial hit) when it is not. Clearing that ability
-- bit therefore cannot disable the leap: it merely changes D6 into CD.
--
-- While Sora is genuinely grounded, replace the seven-byte TEST instruction
-- with a signed near jump to KH1's existing ground-candidate scan at 0x2A71DB.
-- The patch is restored as soon as Sora enters the air through a real jump, so
-- the native aerial selector and the explicit AIR_D6 family remain untouched.
-- No target pointer, ability bit, airborne state, position or action record is
-- modified. The exact stock/owned byte sequences are checked before every
-- write and restore.
-- Keep this controller global because the Lua 5.3 chunk is already close to
-- its 200-local limit.
JokCombatGroundIntent = {
    address = ADDRESS.groundAirTargetSelector,
    normal = { 0xF6, 0x05, 0x34, 0x7B, 0xAB, 0x02, 0x02 },
    blocked = { 0xE9, 0x01, 0x01, 0x00, 0x00, 0x90, 0x90 },
    ready = false,
    owned = false,
    suppressionLogged = false,
    failureLogged = false,
}

function JokCombatGroundIntent.matches(expected)
    for index = 1, #expected do
        if ReadByte(JokCombatGroundIntent.address + index - 1)
            ~= expected[index] then
            return false
        end
    end
    return true
end

function JokCombatGroundIntent.initialize()
    JokCombatGroundIntent.ready = false
    JokCombatGroundIntent.owned = false
    JokCombatGroundIntent.suppressionLogged = false
    JokCombatGroundIntent.failureLogged = false

    -- F1 may reload while the previous instance still owns the jump. Recover
    -- that exact byte sequence before accepting the executable signature.
    if JokCombatGroundIntent.matches(JokCombatGroundIntent.blocked) then
        WriteArray(JokCombatGroundIntent.address,
            JokCombatGroundIntent.normal)
    end
    if not JokCombatGroundIntent.matches(JokCombatGroundIntent.normal) then
        ConsolePrint(string.format(
            "[JokCombat:ground-intent] selector signature mismatch at "
            .. "RVA=0x%X; intentional air-entry gate disabled.",
            JokCombatGroundIntent.address))
        return false
    end

    JokCombatGroundIntent.ready = true
    return true
end

function JokCombatGroundIntent.restore(reason, quiet)
    if not JokCombatGroundIntent.owned
        and not JokCombatGroundIntent.matches(
            JokCombatGroundIntent.blocked) then return end

    if JokCombatGroundIntent.matches(JokCombatGroundIntent.blocked) then
        WriteArray(JokCombatGroundIntent.address,
            JokCombatGroundIntent.normal)
    elseif not JokCombatGroundIntent.matches(JokCombatGroundIntent.normal)
        and not JokCombatGroundIntent.failureLogged then
        JokCombatGroundIntent.failureLogged = true
        ConsolePrint("[JokCombat:ground-intent] selector changed by another "
            .. "writer; conditional restore left it untouched.")
    end
    JokCombatGroundIntent.owned = false
    if not quiet then
        log("[ground-intent] native high-target Attack selector restored"
            .. (reason ~= nil and ": " .. reason or "."))
    end
end

function JokCombatGroundIntent.update(player, nativeLimitActive)
    local unsupportedContext = player == nil or nativeLimitActive
        or player.airborneState >= 0x20
        or ReadByte(ADDRESS.world) == 0x09
    local shouldSuppress = JokCombatGroundIntent.ready
        and CONFIG.intentionalAirEntry and not unsupportedContext
        and not player.airborne
    if not shouldSuppress then
        JokCombatGroundIntent.restore("unsupported gameplay context", true)
        return
    end

    if JokCombatGroundIntent.matches(JokCombatGroundIntent.blocked) then
        JokCombatGroundIntent.owned = true
        return
    end
    if not JokCombatGroundIntent.matches(JokCombatGroundIntent.normal) then
        if not JokCombatGroundIntent.failureLogged then
            JokCombatGroundIntent.failureLogged = true
            ConsolePrint("[JokCombat:ground-intent] selector changed by "
                .. "another writer; intentional air-entry gate disabled.")
        end
        JokCombatGroundIntent.ready = false
        return
    end

    WriteArray(JokCombatGroundIntent.address,
        JokCombatGroundIntent.blocked)
    if not JokCombatGroundIntent.matches(JokCombatGroundIntent.blocked) then
        if not JokCombatGroundIntent.failureLogged then
            JokCombatGroundIntent.failureLogged = true
            ConsolePrint("[JokCombat:ground-intent] native high-target "
                .. "selector could not be patched; recovery guard remains active.")
        end
        JokCombatGroundIntent.ready = false
        return
    end
    JokCombatGroundIntent.owned = true

    if not JokCombatGroundIntent.suppressionLogged then
        JokCombatGroundIntent.suppressionLogged = true
        log("[ground-intent] native D6/CD high-target leap disabled while "
            .. "grounded; air entry now requires a real jump.")
    end
end

-- Musou-style modifier-free X/T families. Keep this as one global table:
-- Lua 5.3 limits a chunk to 200 local variables and this controller already
-- carries the validated loadout, HUD and route state in the same chunk.
-- Every named move ends in T. X before the first T chooses Strong/C2/C3/C4/C5;
-- X after a named move returns to the vanilla physical string. Strong is the
-- five-step signature chain, C2 is pursuit, C3 is crowd control, C4 is a
-- direct ranged Limit and C5 is gravity burst. Counterattack remains
-- contextual to a successful Guard; the aerial Y family remains independent
-- of every ground branch.
JokCombatBranch = {
    nodes = {
        -- Strong / signature chain: Y Y Y Y Y.
        T = { kind = "action", id = "slapshot", triangle = "TT" },
        TT = { kind = "action", id = "vortex", triangle = "TTT" },
        TTT = { kind = "action", id = "blitz", triangle = "TTTT" },
        TTTT = { kind = "action", id = "zantetsuken",
            triangle = "TTTTT" },
        TTTTT = { kind = "limit", id = "ars_arcanum" },

        -- C2 / pursuit: A Y Y.
        XT = { kind = "action", id = "sliding_dash", triangle = "XTT" },
        XTT = { kind = "limit", id = "sonic_blade" },

        -- C3 / area: A A Y Y. Ripple Drive is terminal; Trinity Limit is
        -- intentionally excluded because its native sequence owns the party.
        XXT = { kind = "action", id = "stun_impact", triangle = "XXTT" },
        XXTT = { kind = "action", id = "ripple_drive" },

        -- C4 / ranged raid: A A A Y.
        XXXT = { kind = "limit", id = "strike_raid" },

        -- C5 / gravity burst: A A A A Y Y.
        XXXXT = { kind = "action", id = "gravity_break",
            triangle = "XXXXTT" },
        XXXXTT = { kind = "limit", id = "ragnarok" },
    },

    -- `open` accepts exactly one buffered edge; `release` is the earliest
    -- frame at which the current move may be cancelled into its child.
    windows = {
        [0xC8] = { open = 14.0, release = 18.0 },
        [0xC9] = { open = 14.0, release = 34.0 },
        [0xCA] = { open = 16.0, release = 20.0 },
        [0xCC] = { open = 8.0, release = 12.0 },
        [0xCD] = { open = 10.0, release = 14.0 },
        -- CE is a real native finisher: early Y presses are discarded rather
        -- than buffered, matching the existing Cross restart protection.
        [0xCE] = { open = 20.0, release = 20.0 },
        [0xCF] = { open = 14.0, release = 18.0 }, -- Slapshot
        [0xD0] = { open = 14.0, release = 18.0 }, -- Sliding Dash
        [0xD1] = { open = 26.0, release = 30.0 }, -- Hurricane Blast
        [0xD2] = { open = 14.0, release = 18.0 }, -- Blitz
        [0xD3] = { open = 14.0, release = 18.0 }, -- Vortex
        [0xD6] = { open = 16.0, release = 20.0 }, -- Aerial Sweep
        -- Live aerial captures reached the complete late VFX phase near 34-36.
        -- These conservative windows avoid cutting the native effect script.
        [0xD7] = { open = 32.0, release = 36.0 }, -- Ripple Drive
        [0xD8] = { open = 32.0, release = 36.0 }, -- Stun Impact
        [0xD9] = { open = 32.0, release = 36.0 }, -- Gravity Break
        -- DA was observed through time 15 in the live native route. Arm Ars in
        -- its late slash tail, matching the conservative short-Action policy.
        [0xDA] = { open = 14.0, release = 18.0 }, -- Zantetsuken
    },

    slot = { id = "branch_combo", label = "Musou Y family" },
    valid = false,
    active = false,
    path = nil,
    animation = nil,
    pendingPath = nil,
    pendingSourceAnimation = nil,
    pendingSourceTime = 0.0,
    pendingRelease = 0.0,
    waitingPath = nil,
    waitingAnimation = nil,
    waitingFrames = 0,
    waitingSourceAnimation = nil,
    waitingSourceTime = 0.0,
    neutralTrianglePending = false,
    neutralTriangleFrames = 0,
    -- A terminal ground special may hand one logical family depth to the next
    -- real native A. The state never writes KH1's comboPosition byte.
    depthCarryState = nil,
    depthCarryDepth = nil,
    depthCarryFrames = 0,
    depthCarryConfirmFrames = 0,
    depthCarryAnimation = nil,
    depthCarrySource = nil,
    -- These three virtual paths keep the validated aerial order independent
    -- from the ground map: native CE -> Hurricane Blast -> Aerial Sweep.
    -- The two Action nodes still reference their single canonical catalog
    -- records, so no ability is duplicated semantically or routed fake-ground.
    airFinisherPath = "AIR_CE",
    airFinisher = {
        kind = "air_finisher",
        id = "aerial_finisher",
        name = "Aerial Finisher",
        context = "air",
        animation = 0xCE,
        finisher = true,
        recordAvailable = true,
    },
    airHurricanePath = "AIR_D1",
    airHurricane = {
        kind = "action",
        id = "hurricane_blast",
    },
    airSweepPath = "AIR_D6",
    airSweep = {
        kind = "action",
        id = "aerial_sweep",
    },
    airFamily = false,
    familyRoles = {
        T = "Strong / signature chain",
        XT = "C2 / pursuit",
        XXT = "C3 / crowd control",
        XXXT = "C4 / ranged raid",
        XXXXT = "C5 / gravity burst",
    },
}

function JokCombatBranch.pathDepth(path)
    if type(path) ~= "string" then return nil end
    local prefix = path:match("^(X*)T")
    return prefix ~= nil and #prefix or nil
end

function JokCombatBranch.clearDepthCarry(reason, quiet)
    local wasActive = JokCombatBranch.depthCarryState ~= nil
    JokCombatBranch.depthCarryState = nil
    JokCombatBranch.depthCarryDepth = nil
    JokCombatBranch.depthCarryFrames = 0
    JokCombatBranch.depthCarryConfirmFrames = 0
    JokCombatBranch.depthCarryAnimation = nil
    JokCombatBranch.depthCarrySource = nil
    if wasActive and reason ~= nil and not quiet then
        log("[branch-depth] closed: " .. reason .. ".")
    end
end

function JokCombatBranch.activateDepthCarry(player)
    if player == nil or not isGroundNormalContext(player) then return false end
    -- C8-CA are reused by a few non-normal contexts with low secondary IDs.
    -- Accept only the native physical variants observed by the normal string.
    if player.animation >= 0xC8 and player.animation <= 0xCA
        and player.secondary <= 0x02 then return false end
    local nativeBeatDeferredFallback = type(deferredLinkKind) == "string"
        and deferredLinkKind:sub(1, 12) == "musou-light:"
    if nativeBeatDeferredFallback then
        -- The physical Cross survived the terminal Action release and KH1 has
        -- already opened C8-CA. Its queued target-free fallback is now stale:
        -- retaining it would block Y for this entire attack, then emit a
        -- duplicate C8 after recovery.
        clearDeferredAttackCommand()
        log("[branch-depth] native A won the handoff; deferred fallback cancelled.")
    end
    JokCombatBranch.depthCarryState = "active"
    JokCombatBranch.depthCarryAnimation = player.animation
    JokCombatBranch.depthCarryConfirmFrames = 0
    log(string.format(
        "[branch-depth] native A accepted: virtual depth=%d, next Y opens C%d.",
        JokCombatBranch.depthCarryDepth, JokCombatBranch.depthCarryDepth + 1))
    return true
end

function JokCombatBranch.armDepthCarry(path, label, player, crossLatched)
    local depth = JokCombatBranch.pathDepth(path)
    local nextDepth = depth ~= nil and depth + 1 or nil
    JokCombatBranch.clearDepthCarry(nil, true)
    if nextDepth == nil or nextDepth > 4 then
        if depth ~= nil and depth >= 4 then
            log("[branch-depth] " .. tostring(label)
                .. " completed C5; the next A starts a new vanilla chain.")
        end
        return false
    end

    JokCombatBranch.depthCarryState = crossLatched and "waiting" or "armed"
    JokCombatBranch.depthCarryDepth = nextDepth
    JokCombatBranch.depthCarryFrames = CONFIG.branchDepthCarryFrames
    JokCombatBranch.depthCarryConfirmFrames = crossLatched
        and CONFIG.branchDepthConfirmFrames or 0
    JokCombatBranch.depthCarrySource = label or path
    log(string.format(
        "[branch-depth] %s completed: next real A may carry virtual depth %d.",
        tostring(JokCombatBranch.depthCarrySource), nextDepth))
    if crossLatched then JokCombatBranch.activateDepthCarry(player) end
    return true
end

function JokCombatBranch.depthCarryRootPath(player)
    if JokCombatBranch.depthCarryState ~= "active"
        or JokCombatBranch.depthCarryDepth == nil
        or player == nil or not isGroundNormalContext(player)
        or player.animation ~= JokCombatBranch.depthCarryAnimation then
        return nil
    end
    return string.rep("X", JokCombatBranch.depthCarryDepth) .. "T"
end

function JokCombatBranch.updateDepthCarry(player, buttons, crossPressed,
        trianglePressed)
    local state = JokCombatBranch.depthCarryState
    if state == nil then return false end

    JokCombatBranch.depthCarryFrames = JokCombatBranch.depthCarryFrames - 1
    if JokCombatBranch.depthCarryFrames <= 0 then
        JokCombatBranch.clearDepthCarry("continuation timed out")
        return false
    end

    local modifiers = BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2
    if (buttons & modifiers) ~= 0 then
        JokCombatBranch.clearDepthCarry("modifier action took priority", true)
        return false
    end

    if state == "armed" then
        if trianglePressed then
            JokCombatBranch.clearDepthCarry("Y started a new family", true)
            return false
        end
        if crossPressed then
            if player.airborne then
                JokCombatBranch.clearDepthCarry(
                    "air attack cannot carry ground depth")
                return false
            end
            JokCombatBranch.depthCarryState = "waiting"
            JokCombatBranch.depthCarryConfirmFrames =
                CONFIG.branchDepthConfirmFrames
            log("[branch-depth] physical A observed; waiting for KH1 acceptance.")
            -- KH1 can publish C8-CA on the very same callback that exposes the
            -- raw Cross edge. Inspect the accepted player state before testing
            -- the neutral control byte, otherwise control=0x07 makes us discard
            -- the carry precisely when the native attack has succeeded.
            JokCombatBranch.activateDepthCarry(player)
            return false
        end
        if player.control ~= 0x03
            or not HUD.nativeRootSelectionAvailable() then
            JokCombatBranch.clearDepthCarry(
                "player state interrupted the continuation", true)
            return false
        end
        return false
    end

    if state == "waiting" then
        if JokCombatBranch.activateDepthCarry(player) then return false end
        if player.control ~= 0x03 and not player.airborne then
            JokCombatBranch.clearDepthCarry(
                "physical A was interrupted before acceptance")
            return false
        end
        if trianglePressed then
            log("[branch-depth] Y ignored until the carried A becomes active.")
            return true
        end
        if crossPressed then
            JokCombatBranch.depthCarryConfirmFrames =
                CONFIG.branchDepthConfirmFrames
        end
        JokCombatBranch.depthCarryConfirmFrames =
            JokCombatBranch.depthCarryConfirmFrames - 1
        if JokCombatBranch.depthCarryConfirmFrames <= 0 then
            JokCombatBranch.depthCarryState = "armed"
            JokCombatBranch.depthCarryConfirmFrames = 0
            log("[branch-depth] A was not accepted; continuation remains armed.")
        end
        return false
    end

    if state == "active" then
        if not isGroundNormalContext(player)
            or player.animation ~= JokCombatBranch.depthCarryAnimation then
            JokCombatBranch.clearDepthCarry("carried native A ended")
        elseif crossPressed then
            JokCombatBranch.clearDepthCarry(
                "another physical A started a vanilla continuation", true)
        end
    end
    return false
end

function JokCombatBranch.kindReady(node)
    if node == nil then return false end
    if node.kind == "action" or node.kind == "air_finisher" then
        return CONFIG.branchActionAbilities
    end
    if node.kind == "limit" then
        return CONFIG.branchLimits and JokCombatNativeLimit ~= nil
            and JokCombatNativeLimit.isAvailable(node.id)
    end
    return false
end

function JokCombatBranch.nodeReady(node, player, path)
    if not JokCombatBranch.kindReady(node) then return false end
    if node.kind == "air_finisher" then
        return player ~= nil and player.airborne and airRouteAvailable
    end
    if node.kind == "limit" then
        return JokCombatNativeLimit.contextReady(node.id, player)
    end
    if player == nil or node.kind ~= "action" then return true end
    local action = ACTION_BY_ID[node.id]
    return action ~= nil and actionMatchesContext(action, player)
end

function JokCombatBranch.nodeForPath(path)
    if path == JokCombatBranch.airFinisherPath then
        return JokCombatBranch.airFinisher
    end
    if path == JokCombatBranch.airHurricanePath then
        return JokCombatBranch.airHurricane
    end
    if path == JokCombatBranch.airSweepPath then
        return JokCombatBranch.airSweep
    end
    return path ~= nil and JokCombatBranch.nodes[path] or nil
end

function JokCombatBranch.triangleChild(path, node, airFamily)
    if airFamily then
        if path == JokCombatBranch.airFinisherPath then
            return JokCombatBranch.airHurricanePath
        end
        if path == JokCombatBranch.airHurricanePath then
            return JokCombatBranch.airSweepPath
        end
        if path == JokCombatBranch.airSweepPath then return nil end
    end
    return node ~= nil and node.triangle or nil
end

function JokCombatBranch.prearmLimitChild(player)
    if JokCombatBranch.path == nil or JokCombatBranch.airFamily
        or JokCombatNativeLimit.selectorOwned() then
        return JokCombatNativeLimit.selectorOwned()
    end
    local limit = JokCombatNativeLimit.forPrefix(JokCombatBranch.path)
    if limit == nil then return false end
    local node = JokCombatBranch.nodeForPath(JokCombatBranch.path)
    local child = JokCombatBranch.triangleChild(
        JokCombatBranch.path, node, false)
    if child ~= limit.path then return false end
    local window = JokCombatBranch.windows[player.animation]
    if window == nil or player.animation ~= JokCombatBranch.animation
        or player.time < window.open then return false end
    return JokCombatNativeLimit.arm(limit.id, player)
end

function JokCombatBranch.executeRootLimit(player, trianglePressed)
    if not trianglePressed or JokCombatBranch.active
        or JokCombatBranch.pendingPath ~= nil
        or JokCombatBranch.waitingPath ~= nil then
        return false
    end
    local path = JokCombatBranch.rootPath(player)
    local node = JokCombatBranch.nodeForPath(path)
    if node == nil or node.kind ~= "limit" then return false end
    if not JokCombatBranch.nodeReady(node, player, path) then
        log("[branch] " .. tostring(path)
            .. " root Limit is unavailable in the current context.")
        return true
    end
    if not JokCombatNativeLimit.arm(node.id, player) then
        log("[branch] " .. path
            .. " root Limit selector could not be armed; Y discarded.")
        return true
    end
    if not JokCombatNativeLimit.acceptFinalInput(node.id, player) then
        JokCombatNativeLimit.restore("root Limit final Y latch failed")
        log("[branch] " .. path
            .. " root Limit final Y could not be latched.")
        return true
    end
    log("[branch] " .. path
        .. " root Limit selector and final Y latched on the same frame.")
    return true
end

function JokCombatBranch.initialize()
    JokCombatBranch.reset(nil, true, true)
    local count = 0
    local unique = {}
    local actionCount = 0
    local valid = true
    for path, node in pairs(JokCombatBranch.nodes) do
        count = count + 1
        local identity = node.kind .. ":" .. node.id
        if unique[identity] ~= nil then
            ConsolePrint(string.format(
                "[JokCombat:branch:fault] duplicate %s at %s and %s.",
                identity, unique[identity], path))
            valid = false
        end
        unique[identity] = path
        if node.kind == "action" then
            actionCount = actionCount + 1
            if ACTION_BY_ID[node.id] == nil then
                ConsolePrint(string.format(
                    "[JokCombat:branch:fault] unknown Action Ability %s at %s.",
                    node.id, path))
                valid = false
            end
        end
        if node.cross ~= nil and JokCombatBranch.nodes[node.cross] == nil then
            ConsolePrint(string.format(
                "[JokCombat:branch:fault] %s has missing X child %s.",
                path, node.cross))
            valid = false
        end
        if node.triangle ~= nil
            and JokCombatBranch.nodes[node.triangle] == nil then
            ConsolePrint(string.format(
                "[JokCombat:branch:fault] %s has missing T child %s.",
                path, node.triangle))
            valid = false
        end
    end
    local reservedActions = {
        JokCombatBranch.airHurricane,
        JokCombatBranch.airSweep,
        { kind = "action", id = "counterattack" },
    }
    for _, node in ipairs(reservedActions) do
        local identity = node.kind .. ":" .. node.id
        if unique[identity] ~= nil or ACTION_BY_ID[node.id] == nil then
            ConsolePrint(string.format(
                "[JokCombat:branch:fault] contextual Action %s is duplicated "
                    .. "or unavailable.", node.id))
            valid = false
        end
        unique[identity] = "contextual"
    end
    if count ~= 12 or actionCount ~= 8 then
        ConsolePrint(string.format(
            "[JokCombat:branch:fault] Musou ground map count mismatch: "
            .. "nodes=%d/12 actions=%d/8.", count, actionCount))
        valid = false
    end
    if JokCombatBranch.nodes.T == nil
        or JokCombatBranch.nodes.T.triangle ~= "TT"
        or JokCombatBranch.nodes.TT == nil
        or JokCombatBranch.nodes.TT.triangle ~= "TTT"
        or JokCombatBranch.nodes.TTT == nil
        or JokCombatBranch.nodes.TTT.triangle ~= "TTTT"
        or JokCombatBranch.nodes.TTTT == nil
        or JokCombatBranch.nodes.TTTT.triangle ~= "TTTTT"
        or JokCombatBranch.nodes.TTTTT == nil
        or JokCombatBranch.nodes.XXXT == nil
        or JokCombatBranch.nodes.XXXT.kind ~= "limit"
        or JokCombatBranch.nodes.XXXXT == nil
        or JokCombatBranch.nodes.XXXXT.triangle ~= "XXXXTT"
        or JokCombatBranch.nodes.XXXXTT == nil then
        ConsolePrint("[JokCombat:branch:fault] requested Y/C4/C5 "
            .. "topology is incomplete.")
        valid = false
    end
    if valid and #ACTION_CATALOG - 1 ~= 11 then valid = false end
    JokCombatBranch.valid = valid
    return valid, count, actionCount
end

function JokCombatBranch.reset(reason, quiet, skipCleanup)
    local branchWasActive = JokCombatBranch.active
        or JokCombatBranch.pendingPath ~= nil
        or JokCombatBranch.waitingPath ~= nil
        or JokCombatBranch.neutralTrianglePending
    if branchWasActive and not skipCleanup and canRun then
        -- A child Limit is pre-armed while its parent Action is active. If
        -- that family closes without entering the native Limit, return the
        -- Reaction selector and borrowed MP state immediately.
        if JokCombatNativeLimit.selectorOwned() then
            JokCombatNativeLimit.restore(
                "branch closed before final Y", quiet == true)
        end
        if JokCombatBranch.waitingPath ~= nil then
            clearTransitionCheck()
            clearDeferredAttackCommand()
        end
        restoreActionRoutes()
    end
    JokCombatBranch.active = false
    JokCombatBranch.path = nil
    JokCombatBranch.animation = nil
    JokCombatBranch.pendingPath = nil
    JokCombatBranch.pendingSourceAnimation = nil
    JokCombatBranch.pendingSourceTime = 0.0
    JokCombatBranch.pendingRelease = 0.0
    JokCombatBranch.waitingPath = nil
    JokCombatBranch.waitingAnimation = nil
    JokCombatBranch.waitingFrames = 0
    JokCombatBranch.waitingSourceAnimation = nil
    JokCombatBranch.waitingSourceTime = 0.0
    JokCombatBranch.neutralTrianglePending = false
    JokCombatBranch.neutralTriangleFrames = 0
    JokCombatBranch.airFamily = false
    JokCombatBranch.clearDepthCarry(nil, true)
    if branchWasActive and not quiet then
        log("[branch] closed" .. (reason ~= nil and ": " .. reason or "."))
    end
end

function JokCombatBranch.refreshAirState(player)
    player.airborneState = ReadInt(
        player.pointer + PLAYER.airborneState, true)
    player.airborne = player.airborneState ~= 0
end

function JokCombatBranch.dispatch(player, path)
    local node = JokCombatBranch.nodeForPath(path)
    local action = nil
    if node ~= nil and node.kind == "action" then
        action = ACTION_BY_ID[node.id]
    elseif node ~= nil and node.kind == "air_finisher" then
        action = node
    end
    if node == nil or action == nil
        or action.animation == nil or action.recordAvailable ~= true then
        log("[branch] " .. tostring(path)
            .. " could not dispatch a complete native action record.")
        JokCombatBranch.reset("dispatcher unavailable")
        return true
    end

    JokCombatBranch.slot.label = path .. " -> " .. action.name
    local requested = requestActionAbility(
        player, JokCombatBranch.slot, action, false, true)
    if not requested or transitionKind ~= actionKind(action) then
        log("[branch] " .. path .. " request was not armed; tree closed.")
        JokCombatBranch.reset("request rejected")
        return true
    end

    JokCombatBranch.pendingPath = nil
    JokCombatBranch.pendingSourceAnimation = nil
    JokCombatBranch.pendingSourceTime = 0.0
    JokCombatBranch.pendingRelease = 0.0
    JokCombatBranch.waitingPath = path
    JokCombatBranch.waitingAnimation = action.animation
    JokCombatBranch.waitingFrames = CONFIG.branchInputTimeoutFrames
    JokCombatBranch.waitingSourceAnimation = player.animation
    JokCombatBranch.waitingSourceTime = player.time
    JokCombatBranch.active = true
    log(string.format(
        "[branch] %s requested: %s (0x%02X).",
        path, action.name, action.animation))
    return true
end

function JokCombatBranch.fallback(player, path)
    local node = JokCombatBranch.nodeForPath(path)
    local label = node ~= nil and (node.kind .. ":" .. node.id) or path
    log("[branch] " .. path .. " -> " .. label
        .. " is reserved; its complete Steam adapter is not enabled yet. "
        .. "Using one native physical fallback.")
    JokCombatBranch.reset("reserved adapter", true)
    clearComboIntent()
    clearTransitionCheck()
    clearDeferredAttackCommand()
    restoreActionRoutes()
    JokCombatBranch.refreshAirState(player)
    if not queueAttackAfterRelease(
            player, "branch-fallback:" .. path, nil, nil) then
        log("[branch] " .. path .. " fallback could not be queued.")
    end
    return true
end

function JokCombatBranch.continuePhysical(player)
    local sourcePath = JokCombatBranch.path or "unknown"
    local sourceNode = JokCombatBranch.nodeForPath(sourcePath)
    local carryTerminalDepth = not JokCombatBranch.airFamily
        and sourceNode ~= nil and sourceNode.kind == "action"
        and JokCombatBranch.triangleChild(
            sourcePath, sourceNode, false) == nil
    local sourceName = JokCombatBranch.nodeName(sourceNode)
    if carryTerminalDepth then
        log("[branch] " .. sourcePath
            .. " + A -> terminal physical handoff queued with its depth.")
    else
        log("[branch] " .. sourcePath
            .. " + A -> native physical continuation; family closed and no "
            .. "named ability dispatched.")
    end
    JokCombatBranch.reset("physical A continuation", true)
    clearComboIntent()
    clearTransitionCheck()
    clearDeferredAttackCommand()
    restoreActionRoutes()
    JokCombatBranch.refreshAirState(player)
    local queued = queueAttackAfterRelease(
        player, "musou-light:" .. sourcePath, nil, nil)
    if not queued then
        log("[branch] " .. sourcePath
            .. " physical continuation could not be queued.")
    elseif carryTerminalDepth then
        -- A pressed in the safe tail of a terminal Action is already the real
        -- continuation requested by the player. Preserve its depth while the
        -- existing release/pulse path waits for KH1 to publish C8-CA; do not
        -- require a second A after Ripple Drive has visibly finished.
        JokCombatBranch.armDepthCarry(
            sourcePath, sourceName, player, true)
    end
    return true
end

function JokCombatBranch.execute(player, path)
    local node = JokCombatBranch.nodeForPath(path)
    if not JokCombatBranch.nodeReady(node, player, path) then
        log("[branch] " .. tostring(path)
            .. " is unavailable in the current ground/air context.")
        JokCombatBranch.reset("context unavailable")
        return true
    end
    if node.kind == "action" or node.kind == "air_finisher" then
        return JokCombatBranch.dispatch(player, path)
    end
    if node.kind == "limit" then
        -- A native Limit must already have been pre-armed by its parent Action.
        -- Arming after this Y would be one frame too late, and substituting a
        -- physical fallback would violate the visible combo map.
        log("[branch] " .. path
            .. " was not pre-armed; final Y discarded without fallback.")
        JokCombatBranch.reset("native Limit unavailable")
        return true
    end
    return JokCombatBranch.fallback(player, path)
end

function JokCombatBranch.queue(player, path)
    local node = JokCombatBranch.nodeForPath(path)
    if node == nil then
        JokCombatBranch.reset("unmapped sequence " .. tostring(path))
        return true
    end
    if not JokCombatBranch.nodeReady(node, player, path) then
        log("[branch] " .. path
            .. " ignored: no native action exists for this air/ground context.")
        JokCombatBranch.reset("context unavailable")
        return true
    end
    local window = JokCombatBranch.windows[player.animation]
    if window == nil then
        log(string.format(
            "[branch] %s ignored: animation 0x%02X has no safe link window.",
            path, player.animation))
        JokCombatBranch.reset("missing safe window")
        return true
    end
    if player.time < window.open then
        log(string.format(
            "[branch] %s ignored before prebuffer: anim=0x%02X "
            .. "time=%.2f opens=%.2f.",
            path, player.animation, player.time, window.open))
        return true
    end

    JokCombatBranch.pendingPath = path
    JokCombatBranch.pendingSourceAnimation = player.animation
    JokCombatBranch.pendingSourceTime = player.time
    JokCombatBranch.pendingRelease = window.release
    JokCombatBranch.active = true
    if player.time >= window.release then
        return JokCombatBranch.execute(player, path)
    end
    log(string.format(
        "[branch] %s buffered once: anim=0x%02X time=%.2f releases=%.2f.",
        path, player.animation, player.time, window.release))
    return true
end

function JokCombatBranch.advancePending(player)
    local path = JokCombatBranch.pendingPath
    if path == nil then return false end
    if player.animation ~= JokCombatBranch.pendingSourceAnimation
        or player.time + 0.5 < JokCombatBranch.pendingSourceTime then
        JokCombatBranch.reset("buffer source changed")
        return false
    end
    if player.time < JokCombatBranch.pendingRelease then return false end
    return JokCombatBranch.execute(player, path)
end

function JokCombatBranch.observeRequest(player)
    if JokCombatBranch.waitingPath == nil then return false end
    if player.animation == JokCombatBranch.waitingAnimation
        and (player.animation ~= JokCombatBranch.waitingSourceAnimation
            or player.time + 0.5 < JokCombatBranch.waitingSourceTime) then
        JokCombatBranch.path = JokCombatBranch.waitingPath
        JokCombatBranch.animation = JokCombatBranch.waitingAnimation
        JokCombatBranch.waitingPath = nil
        JokCombatBranch.waitingAnimation = nil
        JokCombatBranch.waitingFrames = 0
        JokCombatBranch.waitingSourceAnimation = nil
        JokCombatBranch.waitingSourceTime = 0.0
        log(string.format(
            "[branch] %s accepted: anim=0x%02X context=%s.",
            JokCombatBranch.path, player.animation,
            player.airborne and "air-native" or "ground"))
        -- The parent Action is the one-frame-early carrier required by KH1's
        -- real Reaction selector. This replaces the old reverse physical A
        -- prefix without synthesizing or delaying the final Y.
        JokCombatBranch.prearmLimitChild(player)
        return true
    end

    JokCombatBranch.waitingFrames = JokCombatBranch.waitingFrames - 1
    if JokCombatBranch.waitingFrames <= 0 then
        JokCombatBranch.reset("requested action timed out")
    end
    return false
end

function JokCombatBranch.rootPath(player)
    if isGroundNormalContext(player) then
        local carried = JokCombatBranch.depthCarryRootPath(player)
        if carried ~= nil then return carried end
        local maximum = ReadByte(ADDRESS.maxGroundComboLength)
        local position = ReadByte(ADDRESS.comboPosition)
        if position < 1 or position >= maximum then return nil end
        return string.rep("X", position) .. "T"
    end
    if isAirNormalContext(player) then
        local maximum = ReadByte(ADDRESS.maxAirComboLength)
        local position = ReadByte(ADDRESS.comboPosition)
        if position < 1 or position >= maximum then return nil end
        -- Every intermediate native aerial hit aliases to the same contextual
        -- family. It starts from virtual native CE, continues through virtual
        -- AIR_D1 (Hurricane Blast) and closes with AIR_D6 (Aerial Sweep).
        -- Both point to their one canonical Action record; ground C3 is fully
        -- independent and contains only ground-native moves.
        return JokCombatBranch.airFinisherPath
    end
    local neutral = player.control == 0x03
        and not isAttackContext(player) and player.animation <= 0x07
    return neutral and "T" or nil
end

function JokCombatBranch.clearNeutralTriangle(reason)
    local wasPending = JokCombatBranch.neutralTrianglePending
    JokCombatBranch.neutralTrianglePending = false
    JokCombatBranch.neutralTriangleFrames = 0
    if wasPending and reason ~= nil then
        log("[branch] neutral Y arbitration closed: " .. reason .. ".")
    end
    return wasPending
end

function JokCombatBranch.armNeutralTriangle()
    JokCombatBranch.neutralTrianglePending = true
    JokCombatBranch.neutralTriangleFrames =
        CONFIG.neutralTriangleGraceFrames
    log("[branch] neutral Y left native for contextual arbitration; "
        .. "Strong will open after release if no Reaction claims it.")
    return true
end

function JokCombatBranch.resolveNeutralTriangle(player, buttons,
        crossPressed, trianglePressed)
    if not JokCombatBranch.neutralTrianglePending then return false, false end

    local nativeReaction = ReadShort(ADDRESS.reactionCommandId)
    if nativeReaction ~= 0 then
        JokCombatBranch.clearNeutralTriangle(string.format(
            "delegated to native Reaction 0x%04X", nativeReaction))
        return true, false
    end
    if not HUD.nativeRootSelectionAvailable() then
        JokCombatBranch.clearNeutralTriangle(
            "native Command Menu left its root")
        return true, false
    end
    if JokCombatBranch.rootPath(player) ~= "T" then
        JokCombatBranch.clearNeutralTriangle(
            "player left the neutral gameplay state")
        return true, false
    end

    -- Never retain a synthetic Strong request across the first confirmation
    -- press after Talk/Examine/Save. Even if KH1 has not published its Reaction
    -- field yet, physical A wins and reaches the game on this same frame.
    if crossPressed then
        JokCombatBranch.clearNeutralTriangle(
            "physical A took priority")
        return true, false
    end
    if trianglePressed then
        JokCombatBranch.neutralTriangleFrames =
            CONFIG.neutralTriangleGraceFrames
        return true, false
    end
    if (buttons & BUTTON.TRIANGLE) ~= 0 then return true, false end

    JokCombatBranch.neutralTriangleFrames =
        JokCombatBranch.neutralTriangleFrames - 1
    if JokCombatBranch.neutralTriangleFrames > 0 then return true, false end

    JokCombatBranch.clearNeutralTriangle(nil)
    log("[branch] neutral Y arbitration accepted: no native Reaction; "
        .. "opening Strong.")
    return true, JokCombatBranch.execute(player, "T")
end

function JokCombatBranch.nodeName(node)
    if node == nil then return nil end
    if node.kind == "air_finisher" then return node.name end
    local action = ACTION_BY_ID[node.id]
    if node.kind == "action" and action ~= nil then return action.name end
    local label = tostring(node.id):gsub("_", " ")
    return label:gsub("^%l", string.upper)
end

function JokCombatBranch.guideLine(sequence, node, player, path)
    if node == nil or not JokCombatBranch.nodeReady(node, player, path) then
        return sequence .. " -"
    end
    return sequence .. " " .. (JokCombatBranch.nodeName(node) or "-")
end

function JokCombatBranch.familyGuideEntries(node, includeCurrent, player, path,
        airFamily)
    if node == nil then return nil end
    local entries = {}
    local current = node
    local currentPath = path
    if not includeCurrent then
        currentPath = JokCombatBranch.triangleChild(
            currentPath, node, airFamily)
        current = JokCombatBranch.nodeForPath(currentPath)
    end
    local sequence = "[Y]"
    while current ~= nil and #entries < 4
        and JokCombatBranch.nodeReady(current, player, currentPath) do
        table.insert(entries, JokCombatBranch.guideLine(
            sequence, current, player, currentPath))
        sequence = sequence .. "[Y]"
        currentPath = JokCombatBranch.triangleChild(
            currentPath, current, airFamily)
        current = JokCombatBranch.nodeForPath(currentPath)
    end
    if #entries == 0 then return nil end
    while #entries < 4 do table.insert(entries, "-") end
    return entries
end

function JokCombatBranch.guideEntriesFromPrefix(prefix, player)
    if prefix == nil then return nil end
    local entries = {}
    local directPath = prefix
    local sequence = ""
    for _ = 1, 4 do
        directPath = directPath .. "T"
        sequence = sequence .. "[Y]"
        local node = JokCombatBranch.nodes[directPath]
        if node == nil
            or not JokCombatBranch.nodeReady(node, player, directPath) then
            break
        end
        table.insert(entries, JokCombatBranch.guideLine(
            sequence, node, player, directPath))
        if #entries >= 4 then break end
    end
    if #entries == 0 then return nil end
    while #entries < 4 do table.insert(entries, "-") end
    return entries
end

function JokCombatBranch.branchGuideEntries(player)
    if JokCombatBranch.path == nil
        or player.animation ~= JokCombatBranch.animation then
        return nil
    end
    if JokCombatBranch.airFamily then
        local node = JokCombatBranch.nodeForPath(JokCombatBranch.path)
        return JokCombatBranch.familyGuideEntries(
            node, false, player, JokCombatBranch.path, true)
    end
    return JokCombatBranch.guideEntriesFromPrefix(JokCombatBranch.path, player)
end

function JokCombatBranch.guideEntries(player, buttons)
    if not CONFIG.comboGuide or not CONFIG.branchCombos
        or not JokCombatBranch.valid or not HUD.enabled then
        return nil
    end
    if JokCombatBranch.pendingPath ~= nil
        or JokCombatBranch.waitingPath ~= nil then
        return nil
    end
    if HUD.directEditGroup ~= nil
        or (buttons & (BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2
            | BUTTON.TRIANGLE)) ~= 0
        or not HUD.nativeRootSelectionAvailable() then
        return nil
    end

    local counterEntries = JokCombatGuardCounter.guideEntries(player)
    if counterEntries ~= nil then return counterEntries end

    if JokCombatBranch.path ~= nil then
        return JokCombatBranch.branchGuideEntries(player)
    end
    if JokCombatBranch.active then return nil end

    local path = JokCombatBranch.rootPath(player)
    local node = JokCombatBranch.nodeForPath(path)
    -- Never advertise a reserved adapter as executable. The late vanilla
    -- positions currently mapped to magic/Limit therefore keep the ordinary
    -- Command Menu until those complete Steam dispatchers are enabled.
    if node == nil
        or not JokCombatBranch.nodeReady(node, player, path) then return nil end
    -- Do not cover the normal Command Menu permanently while Sora is idle.
    -- The neutral Strong family becomes visible immediately after its first Y.
    if path == "T" then return nil end
    local airFamily = isAirNormalContext(player)
        and path == JokCombatBranch.airFinisherPath
    return JokCombatBranch.familyGuideEntries(
        node, true, player, path, airFamily)
end

function JokCombatBranch.update(player, buttons, crossPressed,
        trianglePressed)
    if not CONFIG.branchCombos or not JokCombatBranch.valid then return false end

    -- The signed selector branch above is the primary protection. If KH1 had
    -- already
    -- committed an old/stale grounded request before suppression, never let
    -- that unexpected air transition retain ownership of X and Y. Releasing
    -- only JokCombat's route/input state preserves the native animation while
    -- guaranteeing that the next physical input works without a Dodge Roll.
    if JokCombatBranch.active and not JokCombatBranch.airFamily
        and player.airborne then
        log("[ground-intent] unexpected grounded branch entered the air; "
            .. "branch input ownership released.")
        JokCombatBranch.reset("unexpected ground-to-air selector transition")
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        restoreActionRoutes()
        return false
    end

    if JokCombatBranch.updateDepthCarry(
            player, buttons, crossPressed, trianglePressed) then
        return true
    end

    local modified = (buttons & (BUTTON.L1 | BUTTON.R1
        | BUTTON.L2 | BUTTON.R2)) ~= 0
    if modified then
        if JokCombatBranch.active or JokCombatBranch.neutralTrianglePending then
            JokCombatBranch.reset("modifier shortcut took priority")
        end
        return false
    end
    -- A Limit's immediate parent Action normally pre-arms its real Reaction.
    -- One real final-Y edge is then latched until KH1 can accept it; the player
    -- never has to repeat Y merely because the parent Action is recovering.
    -- The direct C4 Strike Raid root is armed below on its own final-Y edge.
    if JokCombatNativeLimit.selectorOwned() then
        if trianglePressed then
            local limit = JokCombatNativeLimit.byId[
                JokCombatNativeLimit.activeId]
            if limit ~= nil then
                JokCombatNativeLimit.acceptFinalInput(limit.id, player)
                log(string.format(
                    "[branch] %s first final Y buffered for native %s.",
                    limit.path, limit.name))
            end
        end
        return false
    end
    local arbitrationHandled, arbitrationConsumed =
        JokCombatBranch.resolveNeutralTriangle(
            player, buttons, crossPressed, trianglePressed)
    if arbitrationHandled then return arbitrationConsumed end

    -- Native contextual commands (Save, Examine, Talk, etc.) own Triangle.
    -- Only a Reaction that exists while JokCombat owns no active node may gate
    -- a new family. Some complete Action records publish a transient non-zero
    -- value after entry; treating that as a world interaction closed the first
    -- Strong Action
    -- immediately and left its controls suppressed. Neutral Y uses the short
    -- arbitration above to catch Talk/Examine/Save before Strong is dispatched.
    local nativeReaction = ReadShort(ADDRESS.reactionCommandId)
    local branchOwnsInput = JokCombatBranch.active
    if nativeReaction ~= 0 and not branchOwnsInput then
        if trianglePressed then
            log(string.format(
                "[branch] Y delegated to native Reaction 0x%04X; "
                    .. "Musou family not opened.", nativeReaction))
        end
        return false
    end
    if not HUD.nativeRootSelectionAvailable() and not branchOwnsInput then
        return false
    end
    -- C4 now begins directly with Strike Raid rather than an Action parent.
    -- The physical final Y is still present on this frame, so publish the
    -- native selector and latch that same edge before the generic root queue
    -- can reject an un-prearmed Limit.
    if not branchOwnsInput
        and JokCombatBranch.executeRootLimit(player, trianglePressed) then
        return true
    end

    local requestAccepted = JokCombatBranch.observeRequest(player)
    if JokCombatBranch.waitingPath ~= nil then
        if crossPressed or trianglePressed then
            log("[branch] input ignored while the requested node is entering.")
            return true
        end
        return false
    end
    if requestAccepted and (crossPressed or trianglePressed) then
        log("[branch] input ignored on the first frame of the accepted node.")
        return true
    end

    if JokCombatBranch.pendingPath ~= nil then
        local dispatched = JokCombatBranch.advancePending(player)
        if dispatched then return true end
        if crossPressed or trianglePressed then
            log("[branch] repeated input ignored: one buffered child already exists.")
            return true
        end
        return false
    end

    if JokCombatBranch.path ~= nil then
        if player.animation ~= JokCombatBranch.animation then
            local completedPath = JokCombatBranch.path
            local completedNode = JokCombatBranch.nodeForPath(completedPath)
            local terminalAction = not JokCombatBranch.airFamily
                and completedNode ~= nil and completedNode.kind == "action"
                and JokCombatBranch.triangleChild(
                    completedPath, completedNode, false) == nil
            local naturalRecovery = terminalAction and not player.airborne
                and player.control == 0x03 and player.animation <= 0x07
            local completedName = JokCombatBranch.nodeName(completedNode)
            JokCombatBranch.reset("active node ended or was interrupted",
                naturalRecovery)
            if naturalRecovery then
                JokCombatBranch.armDepthCarry(
                    completedPath, completedName, player, false)
            end
            return false
        end

        -- Retry a parent pre-arm while its native Action remains active. The
        -- normal case succeeds in observeRequest; this covers a transiently
        -- busy root selector. If the first final Y is the edge that makes the
        -- selector ready, preserve that same edge through the native latch.
        local selectorWasOwned = JokCombatNativeLimit.selectorOwned()
        JokCombatBranch.prearmLimitChild(player)
        if JokCombatNativeLimit.selectorOwned() then
            if trianglePressed and not selectorWasOwned then
                local limit = JokCombatNativeLimit.byId[
                    JokCombatNativeLimit.activeId]
                if limit ~= nil then
                    JokCombatNativeLimit.acceptFinalInput(limit.id, player)
                    log(string.format(
                        "[branch] %s selector and first final Y latched "
                            .. "on the same frame.", limit.path))
                end
                return true
            end
            if trianglePressed then
                local limit = JokCombatNativeLimit.byId[
                    JokCombatNativeLimit.activeId]
                if limit ~= nil then
                    JokCombatNativeLimit.acceptFinalInput(limit.id, player)
                    log(string.format(
                        "[branch] %s first final Y buffered for native %s.",
                        limit.path, limit.name))
                end
            end
            return false
        end
        if not crossPressed and not trianglePressed then return false end

        local node = JokCombatBranch.nodeForPath(JokCombatBranch.path)
        if crossPressed then
            if node ~= nil and node.kind == "air_finisher"
                and player.time < CONFIG.airFinisherRestartTime then
                log(string.format(
                    "Aerial Finisher physical continuation ignored before "
                    .. "native recovery: time=%.2f opens=%.2f.",
                    player.time, CONFIG.airFinisherRestartTime))
                return true
            end
            return JokCombatBranch.continuePhysical(player)
        end
        local child = JokCombatBranch.triangleChild(
            JokCombatBranch.path, node, JokCombatBranch.airFamily)
        local childNode = JokCombatBranch.nodeForPath(child)
        if childNode == nil
            or not JokCombatBranch.nodeReady(childNode, player, child) then
            log("[branch] " .. JokCombatBranch.path
                .. " is terminal; new input discarded until recovery.")
            return true
        end
        if childNode.kind == "limit" then
            -- An early final Y is valid input, not a request to skip the
            -- parent Action. Arm the real selector now and keep this one edge
            -- pending until the native dispatcher reaches a legal state.
            if JokCombatNativeLimit.acceptFinalInput(
                    childNode.id, player) then
                log("[branch] " .. child
                    .. " accepted from its first final Y; native input "
                    .. "latched through parent recovery.")
                return true
            end
            log("[branch] " .. child
                .. " ignored: native Limit selector could not be armed; "
                .. "no fallback attack was substituted.")
            return true
        end
        return JokCombatBranch.queue(player, child)
    end

    if not trianglePressed or transitionKind ~= nil
        or deferredLinkKind ~= nil then
        return false
    end

    local carriedRoot = JokCombatBranch.depthCarryRootPath(player)
    local root = JokCombatBranch.rootPath(player)
    local node = JokCombatBranch.nodeForPath(root)
    if node == nil then return false end
    if not JokCombatBranch.nodeReady(node, player, root) then
        log("[branch] " .. root .. " left native: no compatible "
            .. (player.airborne and "airborne" or "ground") .. " action.")
        return false
    end
    JokCombatBranch.airFamily = player.airborne
        and root == JokCombatBranch.airFinisherPath
    if root == "T" then return JokCombatBranch.armNeutralTriangle() end
    local consumed = JokCombatBranch.queue(player, root)
    if carriedRoot ~= nil and root == carriedRoot
        and JokCombatBranch.active then
        JokCombatBranch.clearDepthCarry(nil, true)
    end
    if not JokCombatBranch.active then JokCombatBranch.airFamily = false end
    return consumed
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
    local reactionActive = not HUD.nativeRootSelectionAvailable()
        or (JokCombatNativeLimit ~= nil
            and JokCombatNativeLimit.selectorOwned())
    local branchOwnsTriangle = CONFIG.branchCombos
        and JokCombatBranch ~= nil and JokCombatBranch.active
    return setByte("triangleControlMap", ADDRESS.triangleControlMap,
        branchOwnsTriangle and not reactionActive and 0xFE
            or NORMAL.triangleControlMap,
        { 0xFF, 0xFE })
end

local function updateAttackControlRouting(buttons, player)
    local suppressPhysicalCross = CONFIG.branchCombos
        and JokCombatBranch ~= nil and JokCombatBranch.active
    suppressPhysicalCross = suppressPhysicalCross
        or (JokCombatGuardCounter ~= nil
            and JokCombatGuardCounter.ready ~= nil
            and JokCombatGuardCounter.ready(player))

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

local function updateDefenseRouting(buttons, guardAvailable, dodgeActive,
        nativeLimitActive, player)
    -- KH1's native Limit state owns its complete input and recovery machine.
    -- Cancelling only the visible animation leaves raw70 >= 0x20 orphaned and
    -- permanently locks movement. Restore every custom defense route while a
    -- Limit is active; Guard and Dodge resume as soon as KH1 exits normally.
    if nativeLimitActive then
        setByte("circleControlMap", ADDRESS.circleControlMap,
            NORMAL.circleControlMap, { 0xFF, 0x07, 0xFE })
        setByte("squareControlMap", ADDRESS.squareControlMap,
            NORMAL.squareControlMap, { 0xFF, 0x05, 0xFE })
        setByte("guardSelection", ADDRESS.guardSelectionBranch,
            NORMAL.guardSelection, { 0x74, 0xEB })
        setByte("airDefense", ADDRESS.airDefenseBranch,
            NORMAL.airDefense, { 0x85, 0x82 })
        setByte("guardAvailability", ADDRESS.guardAvailabilityBranch,
            NORMAL.guardAvailability, { 0x74, 0x72, 0xEB })
        setByte("dodgeAvailability", ADDRESS.dodgeAvailabilityBranch,
            NORMAL.dodgeAvailability, { 0x84, 0x82 })
        setByte("forceSquare", ADDRESS.forceSquareBranch,
            NORMAL.forceSquare, { 0x84, 0x82 })
        return
    end
    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local circleHeld = (buttons & BUTTON.CIRCLE) ~= 0
    local squareHeld = (buttons & BUTTON.SQUARE) ~= 0
    local actionModifierHeld = l2Held
    local playerAirborne = player ~= nil and player.airborne
    -- L1/R1 own the normal page; exact R2 owns JokCombat's second native page.
    -- Fixed Dodge must leave Square completely vanilla for either one.
    local nativeShortcutHeld = (buttons & (BUTTON.L1 | BUTTON.R1)) ~= 0
        or (r2Held and not l2Held)
    local anyDodgeModifierHeld = actionModifierHeld or nativeShortcutHeld
    local guardChord = l2Held and not r2Held and circleHeld
    local nativeSuperglideOwnsSquare =
        CONFIG.nativeAirSuperglideOnSquare and playerAirborne
    local dodgeSquareHeld = squareHeld and not nativeSuperglideOwnsSquare
        and not dodgeActive
        and not anyDodgeModifierHeld

    local circleMap = NORMAL.circleControlMap
    local squareMap = NORMAL.squareControlMap
    if CONFIG.guardOnL2Circle and l2Held and not r2Held then
        -- The override table is action -> physical control. Disable the native
        -- Circle/jump action and source the virtual Square/defense action from
        -- physical Circle (control index 0x05).
        circleMap = 0xFE
        squareMap = 0xFE
        if circleHeld then
            squareMap = guardAvailable and 0x05 or 0xFE
        end
    elseif JokCombatAirJump ~= nil
        and JokCombatAirJump.ownsCircle ~= nil
        and JokCombatAirJump.ownsCircle(buttons) then
        -- B remains native during the first held High Jump. After release it
        -- belongs to Kinetic Step, while aerial Square owns Superglide.
        circleMap = 0xFE
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

    -- Universal Guard keeps the airborne bypass. Dodge is deliberately
    -- ground-only because physical Square owns native Superglide in the air.
    local allowAirGuard = CONFIG.universalGuardCancel
        and (guardChord or forceGuardFrames > 0)
    setByte("airDefense", ADDRESS.airDefenseBranch,
        allowAirGuard and 0x82 or 0x85,
        { 0x85, 0x82 })

    local guardAvailability = CONFIG.unlockDefensiveActions and 0x72 or 0x74
    -- Keep the roll route armed before the first Square frame. Previously it
    -- was selected only after Square was observed, so a stationary first press
    -- could already have entered Guard and a second press appeared to roll.
    if CONFIG.fixedDodgeOnSquare and not playerAirborne
        and forceGuardFrames == 0
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
        or (forceSquareFrames > 0 and not playerAirborne
            and not nativeShortcutHeld) then
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
    HUD.nativeCommandBackup = nil
    HUD.nativeSelectionOwned = false
    HUD.nativeSelectionOriginalSlot = nil
    HUD.nativeSelectionPreviousSlot = nil
    HUD.nativeSelectionTargetSlot = nil
    HUD.nativeSelectionPendingFrames = 0
    HUD.nativeDpadPassMask = 0
    HUD.directEditGroup = nil
    HUD.directEditActive = false
    HUD.directEditDirty = false
    HUD.directEditIndex = { r2 = 1 }
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
    if not CONFIG.enabled then
        ConsolePrint("JokCombat is disabled in CONFIG.")
        return
    end
    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND"
        or ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        ConsolePrint("JokCombat - unsupported game/build; disabled.")
        return
    end

    -- Resolve the live Shortcut object exactly as Shortcut Sets does. All
    -- recovery and page operations below must use these addresses; the former
    -- fixed values were 0x10 bytes early and could never affect the visible
    -- native page on this Steam executable.
    local nativeShortcutAddressesReady =
        JokCombatR2Shortcut.resolveNativeAddresses()

    -- Recover before any later validation can return early. Every field is
    -- restored only if it still contains JokCombat's owned patched value.
    JokCombatR2NativeBridge.restore("reload recovery", true)
    JokCombatR2Shortcut.recoverStale()
    LegacyMagicRecovery.recoverStale()
    local nativeLimitReadyCount = JokCombatNativeLimit.initialize()
    local r2HighlightReady = JokCombatR2ShortcutHighlight.initialize()
    local r2MagicReady = nativeShortcutAddressesReady
        and JokCombatR2Shortcut.initialize()

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
    valid = normalizeByte("shortcutControlSelector",
        ADDRESS.shortcutControlSelector, 0xFF,
        { 0xFF, CONTROL_INDEX.TRIANGLE, 0x20 }) and valid
    valid = normalizeByte("l2ControlMap", ADDRESS.l2ControlMap,
        0xFF, { 0xFF, 0x01, CONTROL_INDEX.TRIANGLE,
            0x21 }) and valid
    valid = normalizeByte("triangleControlMap", ADDRESS.triangleControlMap,
        0xFF, { 0xFF, 0xFE }) and valid
    valid = normalizeByte("circleControlMap", ADDRESS.circleControlMap,
        0xFF, { 0xFF, 0x07, 0xFE }) and valid
    valid = normalizeByte("attackControlMap", ADDRESS.attackControlMap,
        0xFF, { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE }) and valid
    valid = normalizeByte("squareControlMap", ADDRESS.squareControlMap,
        0xFF, { 0xFF, 0x05, 0xFE }) and valid
    if not valid then return end
    r2MagicReady = JokCombatR2NativeBridge.initialize() and r2MagicReady

    -- Recover a stale Kinetic Step byte-only route before the generic aerial
    -- normalizer sees its otherwise unknown 0x0F/0x09 heads.
    JokCombatAirJump.restoreRoutes("reload recovery", true)

    HUD.recoverStaleNativeRows()
    local groundRouteValid = normalizeGroundActionRoute()
    local airRouteValid = normalizeAirActionRoute()
    JokCombatAirJump.initialize(airRouteValid)
    local airAttackBrakeReady = JokCombatAirAttackBrake.initialize()
    JokCombatAttackSpeed.initialize()
    JokCombatMeleeMP.initialize()
    local validActionRecordCount = validateCanonicalActionRecords()
    local branchValid, branchNodeCount, branchActionCount =
        JokCombatBranch.initialize()
    local groundIntentReady = JokCombatGroundIntent.initialize()
    local guardCounterReady = JokCombatGuardCounter.initialize()
    loadActionLoadout()
    HUD.initialize()
    HUD.hideOwned()

    canRun = true
    ConsolePrint(
        "JokCombat " .. VERSION
        .. " initialized (Steam Global; release).")
    log("ground action route " .. (groundRouteValid and "ready." or
        "unavailable."))
    log("aerial action route " .. (airRouteValid and "ready." or
        "unavailable."))
    log(string.format("complete action records ready: %d/%d.",
        validActionRecordCount, #ACTION_CATALOG - 1))
    log(string.format("Musou Y map %s: %d ground nodes, "
        .. "%d ground Action routes + four native Limits; "
        .. "two aerial Actions and Counterattack remain contextual.",
        branchValid and "ready" or "disabled",
        branchNodeCount, branchActionCount))
    log("legacy combo-magic recovery ready; no combo path can cast magic.")
    log(string.format(
        "melee MP recovery %s: 1 MP every %d confirmed native normal hits; "
            .. "full-MP hits are not banked.",
        JokCombatMeleeMP.enabled and "ready" or "disabled",
        JokCombatMeleeMP.hitsPerMP))
    log(string.format(
        "native Limit combos ready: %d/4; Sonic/Ars/Strike/Ragnarok use "
            .. "temporary 0 MP costs; Trinity is excluded from the combo map; "
            .. "first final Y uses one journaled native input latch.",
        nativeLimitReadyCount))
    log("successful-Guard Counterattack detector "
        .. (guardCounterReady and "ready: read-only 0x10 signal -> A."
            or "disabled."))
    log("R2 native magic page " .. (r2MagicReady and "ready" or "disabled")
        .. ": Y/X/A cast through KH1; D-pad Up/Down selects, "
        .. "Left/Right changes, release saves; B remains jump.")
    log("R2 selected-row highlight "
        .. (r2HighlightReady and "ready: active spell name is gold."
            or "disabled: native Shortcut colors remain unchanged."))
    log("native Command Menu Combo Guide ready: up to four native rows; "
        .. "release L1+R1+L2+R2 to toggle it; add D-pad Down to reset "
        .. "defaults; overlay is currently "
        .. (HUD.enabled and "on." or "off."))
    log("family roles ready: Strong=signature chain, C2=pursuit, "
        .. "C3=crowd control, C4=ranged raid, C5=gravity burst.")
    log("Combo Guide ready: Y=Slapshot/Vortex/Blitz/Zantetsuken/Ars; "
        .. "C4=Strike Raid; C5=Gravity Break/Ragnarok.")
    log("post-special depth ready: a completed terminal move plus one real A "
        .. "opens the following ground family; C5 remains terminal.")
    log("neutral Y arbitration ready: two released frames before Strong; "
        .. "Reaction Commands and the first physical A keep native priority.")
    log("fourth Combo Guide row ready: locked Summon borrows a reversible visual "
        .. "carrier; only a native 0xFF slot remains three-row.")
    log("native Ripple Drive/Stun Impact/Gravity Break/Zantetsuken "
        .. "selectors ready.")
    log("Action Ability context ready: Hurricane Blast is callable on ground "
        .. "and in air; airborne family is native CE -> Hurricane Blast -> "
        .. "Aerial Sweep terminal, with fake-ground disabled.")
    log("intentional air-entry gate "
        .. (groundIntentReady and "ready" or "disabled")
        .. ": grounded D6/CD target-follow is bypassed; jump and Kinetic Step "
        .. "remain the only air entries.")
    log("Kinetic Step second-jump adapter "
        .. (JokCombatAirJump.enabled and "ready" or "disabled")
        .. ": one charge after a real first jump; B routes animation 0x0F, "
        .. "applies the bounded Critical Mix lift and restarts air hit 1.")
    log("native air Superglide ready: hold Square after either jump; "
        .. "Dodge Roll is forced only while grounded.")
    log("native free-fall brake ready: base Fall 0x06 / High Jump Fall "
        .. "0x0B downward delta x0.45; the factor is applied once per frame.")
    log("native aerial attack descent brake "
        .. (airAttackBrakeReady and "ready" or "disabled")
        .. ": CC/CD/CE downward delta x0.25; upward motion and D1/D6 "
        .. "remain native.")
    log(string.format(
        "native physical combo speed %s: C8-CB + CC-CE x%.2f; "
            .. "all special actions remain at native playback.",
        JokCombatAttackSpeed.enabled and "ready" or "disabled",
        CONFIG.normalAttackSpeedMultiplier))
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
        JokCombatAirJump.reset("player unavailable", true, true)
        JokCombatAirAttackBrake.reset("player unavailable", true, true)
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
        JokCombatGuardCounter.reset("player unavailable", true)
        lastButtons = 0
        lastDpad = 0
        return
    end

    local buttons = ReadByte(ADDRESS.rawButtons)
    local dpad = ReadByte(ADDRESS.dpadButtons)
    local r2MagicActive = JokCombatR2Shortcut.update(
        player, buttons, JokCombatNativeLimit.activeState(player))
    JokCombatNativeLimit.update(player, buttons)
    local nativeLimitActive = JokCombatNativeLimit.activeState(player)
    JokCombatAttackSpeed.observe(player, nativeLimitActive)
    JokCombatMeleeMP.observe(player, nativeLimitActive)
    JokCombatAirAttackBrake.observe(player, nativeLimitActive)
    JokCombatAirJump.observe(player, buttons)
    JokCombatGuardCounter.update(player, buttons)
    local controlDpadOwned, controlConsumed =
        HUD.updateOverlayControls(buttons, dpad)
    local directDpadOwned = HUD.updateDirectEditor(
        buttons, dpad, player, controlConsumed)
    if r2MagicActive then JokCombatR2Shortcut.syncPage() end
    local dpadOwned = controlDpadOwned or directDpadOwned
        or HUD.dpadReleaseLock
    local configurationInputActive = dpadOwned and dpad ~= 0
    if configurationInputActive or nativeLimitActive then
        restoreNativeFinisherSelection()
    else
        updateNativeFinisherSelection(buttons, player)
    end
    if faulted then
        HUD.finishDirectEdit("script fault", dpad)
        restoreAllPatches()
        return
    end
    JokCombatGroundIntent.update(player, nativeLimitActive)
    updateLoadoutMenuRouting(configurationInputActive, dpadOwned)
    HUD.updateOverlay(buttons, player)
    if faulted then
        HUD.finishDirectEdit("script fault", dpad)
        if HUD.overlayGroup ~= nil then HUD.hideOwned() end
        restoreAllPatches()
        return
    end

    if nativeLimitActive then
        -- No JokCombat action may cancel a native Limit. The current input is
        -- still visible to KH1 (especially Triangle follow-ups), but every
        -- custom route and delayed pulse is neutralized until raw70 leaves the
        -- native >=0x20 state. This prevents the orphaned 0x27 lock observed
        -- when Dodge interrupted Strike Raid at ED/EE.
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        clearSyntheticAttackCommand(false)
        restoreActionRoutes()
        restoreNativeFinisherSelection()
        JokCombatBranch.reset("native Limit owns input", true)
        JokCombatGuardCounter.reset("native Limit owns input", true)
        JokCombatAirJump.reset("native Limit owns input", true, false)
        HUD.finishDirectEdit("native Limit owns input", dpad)
        if HUD.overlayGroup ~= nil then HUD.hideOwned() end
        forceCircleFrames = 0
        forceSquareFrames = 0
        forceGuardFrames = 0
        forceTriangleAttackFrames = 0
        setByte("forceCircle", ADDRESS.forceCircleBranch,
            NORMAL.forceCircle, { 0x74, 0x72 })
        updateDefenseRouting(buttons, false, false, true, player)
        updateLoadoutMenuRouting(false, false)
        setByte("triangleControlMap", ADDRESS.triangleControlMap,
            NORMAL.triangleControlMap, { 0xFF, 0xFE })
        setByte("attackControlMap", ADDRESS.attackControlMap,
            NORMAL.attackControlMap,
            { 0xFF, CONTROL_INDEX.TRIANGLE, 0xFE })
        lastButtons = buttons
        lastDpad = dpad
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
        JokCombatAirJump.restoreRoutes("loadout editor", true)
        JokCombatBranch.reset("loadout editor opened", true)
        JokCombatGuardCounter.reset("loadout editor opened", true)
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
    updateDefenseRouting(buttons, guardAvailable, dodgeActive, false, player)
    updateModifierFaceRouting(buttons)
    updateAttackControlRouting(buttons, player)
    if faulted then
        restoreAllPatches()
        return
    end

    local l2Held = (buttons & BUTTON.L2) ~= 0
    local r2Held = (buttons & BUTTON.R2) ~= 0
    local standardShortcutHeld =
        (buttons & (BUTTON.L1 | BUTTON.R1)) ~= 0
    local r2ShortcutHeld = CONFIG.r2MagicShortcuts
        and r2Held and not l2Held and not standardShortcutHeld
    local nativeShortcutHeld = standardShortcutHeld or r2ShortcutHeld
    local circlePressed = pressStarted(buttons, BUTTON.CIRCLE)
    local crossPressed = pressStarted(buttons, BUTTON.CROSS)
    local squarePressed = pressStarted(buttons, BUTTON.SQUARE)
    local trianglePressed = pressStarted(buttons, BUTTON.TRIANGLE)
    local guardPressed = not r2Held
        and chordStarted(buttons, BUTTON.L2, BUTTON.CIRCLE)
    local cancelWindowOpen = isCancelableAttack(player)
    local actionConsumed = false
    local chainWasArmed = groundChainFrames > 0
        or isGroundNormalContext(player)
    local directFinisherContext = isGroundNormalContext(player)
        or (groundChainFrames > 0 and not isAttackContext(player)
            and player.control == 0x03 and player.animation <= 0x07)

    if circlePressed and not player.airborne
        and not l2Held and not standardShortcutHeld then
        JokCombatAirJump.noteGroundJump(player)
    end

    -- Guard keeps first priority and can break any current action, including a
    -- Dodge Roll; Dodge itself cannot restart DC once the roll is active.
    if CONFIG.defensiveCancels and CONFIG.guardOnL2Circle and guardPressed
        and guardAvailable
        and (CONFIG.universalGuardCancel or cancelWindowOpen) then
        cancelPlayer(player, "guard-universal")
        forceSquareFrames = CONFIG.forcedInputFrames
        forceGuardFrames = CONFIG.forcedInputFrames
        JokCombatGuardCounter.begin()
        JokCombatBranch.reset("Guard cancel")
        clearComboIntent()
        clearTransitionCheck()
        clearDeferredAttackCommand()
        restoreActionRoutes()
        actionConsumed = true
    elseif circlePressed and not l2Held and not standardShortcutHeld then
        if player.airborne and not JokCombatAirJump.releaseRequired then
            -- The second jump is the only universal offensive jump cancel. It
            -- closes the current Musou family first, then Kinetic Step owns
            -- one byte-only aerial route and one synthetic Attack edge.
            actionConsumed = true
            if JokCombatAirJump.canBegin(player, true) then
                JokCombatBranch.reset("second jump")
                JokCombatGuardCounter.reset("second jump", true)
                clearComboIntent()
                clearTransitionCheck()
                clearDeferredAttackCommand()
                restoreActionRoutes()
                JokCombatAirJump.begin(player)
            end
        elseif not player.airborne then
            -- Every other normal jump breaks the local chain. It only cancels
            -- an attack after the configured link window; it is not universal.
            JokCombatBranch.reset("jump")
            JokCombatGuardCounter.reset("jump", true)
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
        end
    elseif CONFIG.fixedDodgeOnSquare and squarePressed and dodgeAvailable
        and not player.airborne
        and not l2Held and not r2Held and not nativeShortcutHeld then
        actionConsumed = true
        if dodgeActive then
            -- Dodge Roll is intentionally not self-cancellable: a second
            -- Square cannot reset DC to frame zero or extend its invulnerability.
            log("Dodge input ignored: Dodge Roll is already active.")
        else
            -- From every other state, universal Dodge can release the current
            -- action. The forced Square window then selects Dodge Roll.
            JokCombatBranch.reset("Dodge cancel")
            JokCombatGuardCounter.reset("Dodge", true)
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

    -- Counterattack belongs only to a confirmed successful Guard. It consumes
    -- a modifier-free physical A before either the Musou tree or R2 magic page
    -- can interpret the same edge.
    if not actionConsumed and crossPressed
        and (buttons & (BUTTON.L1 | BUTTON.R1 | BUTTON.L2 | BUTTON.R2)) == 0
        and JokCombatGuardCounter.ready(player) then
        actionConsumed = JokCombatGuardCounter.dispatch(player)
    end

    -- Modifier-free Triangle selects Strong/C2/C3/C4/C5 from neutral or from
    -- the validated native combo position. While a family owns a node, X and
    -- Triangle are read as raw edges: Triangle advances to the next named
    -- Action, while X closes the family and requests one physical attack.
    if not actionConsumed then
        actionConsumed = JokCombatBranch.update(
            player, buttons, crossPressed, trianglePressed)
    end

    -- Once the second native Shortcut page is active, Y/X/A belong wholly to
    -- KH1. Mark their edge consumed only for JokCombat's later attack/finisher
    -- branches; the physical input remains untouched for the native dispatcher.
    if not actionConsumed and r2ShortcutHeld
        and (trianglePressed or squarePressed or crossPressed) then
        actionConsumed = true
        if not r2MagicActive then
            log("R2 magic input ignored: native Shortcut page is unavailable.")
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
    updateModifierFaceRouting(buttons)
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
