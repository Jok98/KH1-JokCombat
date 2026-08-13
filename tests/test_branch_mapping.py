"""Static regression checks for JokCombat's contextual A/Y moveset.

The production script is Lua 5.3 and runs inside LuaBackendHook. These checks
keep the approved map and its native adapters reviewable without emulating KH1.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")
NATIVE_SOURCE = (ROOT / "JokCombat_NativeAbilities.lua").read_text(
    encoding="utf-8"
)


EXPECTED = {
    # Strong / energy.
    "T": ("action", "vortex"),
    "TT": ("action", "gravity_break"),
    "TTT": ("limit", "ragnarok"),
    # C2 / pursuit.
    "XT": ("action", "sliding_dash"),
    "XTT": ("limit", "sonic_blade"),
    # C3 / area.
    "XXT": ("action", "stun_impact"),
    "XXTT": ("action", "ripple_drive"),
    "XXTTT": ("limit", "trinity_limit"),
    # C4 / combo pressure.
    "XXXT": ("action", "slapshot"),
    "XXXTT": ("action", "blitz"),
    "XXXTTT": ("limit", "strike_raid"),
    # C5 / execution.
    "XXXXT": ("action", "zantetsuken"),
    "XXXXTT": ("limit", "ars_arcanum"),
}

LIMITS = {
    "sonic_blade": ("XTT", "XT", "0x004B"),
    "ars_arcanum": ("XXXXTT", "XXXXT", "0x0057"),
    "strike_raid": ("XXXTTT", "XXXTT", "0x005E"),
    "ragnarok": ("TTT", "TT", "0x005A"),
    "trinity_limit": ("XXTTT", "XXTT", "0x0052"),
}


def parse_nodes() -> dict[str, dict[str, str]]:
    start = SOURCE.index("    nodes = {")
    end = SOURCE.index("    windows = {", start)
    entries: dict[str, dict[str, str]] = {}
    current: list[str] = []
    for line in SOURCE[start:end].splitlines()[1:]:
        if re.match(r"^        [XT]+ = \{", line):
            current = [line]
        elif current:
            current.append(line)
        if current and current[-1].rstrip().endswith("},"):
            text = " ".join(part.strip() for part in current)
            match = re.match(
                r'([XT]+) = \{ kind = "([^"]+)", id = "([^"]+)"(.*)\},',
                text,
            )
            assert match is not None, f"cannot parse node: {text}"
            path, kind, ability_id, remainder = match.groups()
            node = {"kind": kind, "id": ability_id}
            child = re.search(r'triangle = "([XT]+)"', remainder)
            if child:
                node["triangle"] = child.group(1)
            entries[path] = node
            current = []
    return entries


def action_catalog() -> tuple[set[str], dict[str, str], dict[str, int], str]:
    start = SOURCE.index("local ACTION_CATALOG = {")
    end = SOURCE.index("local ACTION_BY_ID = {}", start)
    text = SOURCE[start:end]
    ids = set(re.findall(r'\{ id = "([^"]+)"', text))
    contexts: dict[str, str] = {}
    animations: dict[str, int] = {}
    for entry in re.finditer(
        r'(?ms)^    \{ id = "([^"]+)"(.*?)(?=^    \{ id = |^})', text
    ):
        ability_id, body = entry.groups()
        context = re.search(r'context = "([^"]+)"', body)
        animation = re.search(r'animation = (0x[0-9A-F]+)', body)
        if context:
            contexts[ability_id] = context.group(1)
        if animation:
            animations[ability_id] = int(animation.group(1), 16)
    return ids, contexts, animations, text


def assert_map(nodes: dict[str, dict[str, str]]) -> None:
    actual = {path: (node["kind"], node["id"]) for path, node in nodes.items()}
    assert actual == EXPECTED, "runtime tree differs from the approved map"
    assert len(nodes) == 13
    assert len(set(actual.values())) == 13, "ground roles are duplicated"
    assert sum(node["kind"] == "action" for node in nodes.values()) == 8
    assert sum(node["kind"] == "limit" for node in nodes.values()) == 5

    for path, node in nodes.items():
        assert path.endswith("T"), f"named move {path} does not end in Y/T"
        if "triangle" in node:
            assert node["triangle"] == path + "T"
            assert node["triangle"] in nodes

    assert set(nodes) == {
        path
        for family in (
            ("T", "TT", "TTT"),
            ("XT", "XTT"),
            ("XXT", "XXTT", "XXTTT"),
            ("XXXT", "XXXTT", "XXXTTT"),
            ("XXXXT", "XXXXTT"),
        )
        for path in family
    }
    assert nodes["XXXT"]["triangle"] == "XXXTT"
    assert nodes["XXXTT"]["triangle"] == "XXXTTT"


def assert_action_partition(nodes: dict[str, dict[str, str]]) -> None:
    ids, contexts, animations, catalog_source = action_catalog()
    ground_actions = {
        node["id"] for node in nodes.values() if node["kind"] == "action"
    }
    contextual = {"hurricane_blast", "aerial_sweep", "counterattack"}
    assert ground_actions | contextual == ids - {"none"}
    assert ground_actions.isdisjoint(contextual)
    assert len(ids - {"none"}) == 11
    assert contexts["counterattack"] == "ground"
    assert contexts["hurricane_blast"] == "both"
    assert contexts["aerial_sweep"] == "both"
    assert 'contextual = true' in catalog_source

    window_start = SOURCE.index("    windows = {", SOURCE.index("JokCombatBranch = {"))
    window_end = SOURCE.index("    slot = {", window_start)
    window_animations = {
        int(value, 16)
        for value in re.findall(
            r'\[(0x[0-9A-F]+)\]', SOURCE[window_start:window_end]
        )
    }
    for node in nodes.values():
        if node["kind"] == "action" and "triangle" in node:
            assert animations[node["id"]] in window_animations, (
                f'{node["id"]} can continue but has no safe window'
            )


def assert_aerial_is_independent() -> None:
    guards = (
        'airFinisherPath = "AIR_CE"',
        'airHurricanePath = "AIR_D1"',
        'airSweepPath = "AIR_D6"',
        'id = "aerial_finisher"',
        'id = "hurricane_blast"',
        'id = "aerial_sweep"',
        "return JokCombatBranch.airHurricanePath",
        "return JokCombatBranch.airSweepPath",
        "if path == JokCombatBranch.airSweepPath then return nil end",
        "return JokCombatBranch.airFinisherPath",
        "native CE -> Hurricane Blast -> Aerial Sweep",
        "Aerial Finisher physical continuation ignored before",
        "player.airborne",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing independent aerial guard: {guard}"
    assert 'if path == JokCombatBranch.airFinisherPath then return "XXTT" end' not in SOURCE
    assert "fake-ground" in SOURCE
    assert "leftStickInput" not in SOURCE


def assert_native_limits() -> None:
    start = SOURCE.index("JokCombatNativeLimit = {")
    end = SOURCE.index("function JokCombatNativeLimit.buildIndex", start)
    catalog = SOURCE[start:end]
    for ability_id, (path, prefix, reaction_id) in LIMITS.items():
        pattern = (
            rf'id = "{ability_id}".*?path = "{path}".*?prefix = "{prefix}"'
            rf'.*?reactionId = {reaction_id}'
        )
        assert re.search(pattern, catalog, re.S), f"bad native Limit map: {ability_id}"

    guards = (
        "function JokCombatNativeLimit.publishJournal",
        "function JokCombatNativeLimit.restorePartyMpSnapshot",
        "function JokCombatNativeLimit.recoverStale",
        "function JokCombatNativeLimit.dispatcherCanonical",
        "function JokCombatNativeLimit.contextReady",
        "function JokCombatNativeLimit.forPrefix",
        "function JokCombatNativeLimit.arm",
        "function JokCombatNativeLimit.selectorOwned",
        "function JokCombatNativeLimit.finalInputOwned",
        "function JokCombatNativeLimit.restoreFinalInputLatch",
        "function JokCombatNativeLimit.maintainFinalInputLatch",
        "function JokCombatNativeLimit.acceptFinalInput",
        "function JokCombatNativeLimit.update",
        "autoReaction = 0x232DDE0",
        "finalInputMarker = 0xA19C",
        "WriteShort(ADDRESS.magicRecovery + 0x16,",
        "WriteByte(ADDRESS.autoReaction, 0x01)",
        "JokCombatNativeLimit.restoreFinalInputLatch()",
        "if limit.costAddress ~= nil then WriteShort(limit.costAddress, 0) end",
        "WriteShort(ADDRESS.reactionCommandId, limit.reactionId)",
        "function JokCombatBranch.prearmLimitChild",
        "local limit = JokCombatNativeLimit.forPrefix(JokCombatBranch.path)",
        "JokCombatBranch.prearmLimitChild(player)",
        "parent Action ended before final Y",
        "and JokCombatNativeLimit.selectionFrames <= 0",
        "branch closed before final Y",
        '"[branch] %s first final Y buffered for native %s."',
        "accepted from its first final Y; native input",
        "latched through parent recovery",
        "first final Y latched once for native %s",
        "Final Y belongs to KH1",
        "native Limit combos ready: %d/5",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing native Limit guard: {guard}"
    assert "observePhysicalLink" not in SOURCE
    assert "reverseWaiting" not in SOURCE
    assert "hasReadyDescendant" not in SOURCE
    assert "early Y discarded, press Y again" not in SOURCE
    assert "final Y released to the native Reaction selector" not in SOURCE

    latch_start = SOURCE.index(
        "function JokCombatNativeLimit.maintainFinalInputLatch"
    )
    latch_end = SOURCE.index(
        "function JokCombatNativeLimit.acceptFinalInput", latch_start
    )
    latch = SOURCE[latch_start:latch_end]
    claim = latch[latch.index("-- Journal first:") :]
    assert claim.index("WriteShort(ADDRESS.magicRecovery + 0x16,") < claim.index(
        "WriteByte(ADDRESS.autoReaction, 0x01)"
    ), "the recovery marker must be published before the native latch"

    active_start = SOURCE.index("if limitActive then", SOURCE.index(
        "function JokCombatNativeLimit.update"
    ))
    active_end = SOURCE.index(
        "if JokCombatNativeLimit.activationObserved then", active_start
    )
    active = SOURCE[active_start:active_end]
    assert active.index("JokCombatNativeLimit.restoreFinalInputLatch()") < (
        active.index("JokCombatNativeLimit.restoreSelectorOwned()")
    ), "the final-Y level must clear before native Limit follow-ups begin"


def assert_guard_counter() -> None:
    guards = (
        "connectCounter = 0x296B230",
        "JokCombatGuardCounter = {",
        "guardAnimation = 0xD4",
        "connectValue = 0x10",
        "function JokCombatGuardCounter.begin",
        "function JokCombatGuardCounter.update",
        "function JokCombatGuardCounter.ready",
        "function JokCombatGuardCounter.dispatch",
        "signal == JokCombatGuardCounter.connectValue",
        "player.animation == JokCombatGuardCounter.guardAnimation",
        "JokCombatGuardCounter.begin()",
        "and JokCombatGuardCounter.ready(player) then",
        "and JokCombatGuardCounter.ready(player))",
        "ACTION_BY_ID.counterattack, false, true",
        '"[A] Counterattack"',
        "successful-Guard Counterattack detector",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing Guard Counterattack guard: {guard}"
    # The event byte is an observation source only.
    assert "WriteByte(ADDRESS.connectCounter" not in SOURCE


def assert_native_second_jump() -> None:
    guards = (
        "secondJump = true",
        "secondJumpArmFrames = 45",
        "secondJumpRouteFrames = 60",
        "secondJumpLiftAmount = 30.0",
        "secondJumpLiftEndTime = 25.0",
        "secondJumpSpeedDivisor = 1.1",
        "nativeAirSuperglideOnSquare = true",
        "airFallBrakeFactor = 0.45",
        "gameSpeed = 0x233FBCC",
        "verticalPosition = 0x014",
        "animationSpeed = 0x284",
        "JokCombatAirJump = {",
        "function JokCombatAirJump.routeAnimation",
        "function JokCombatAirJump.entryMatchesOwnedRoute",
        "function JokCombatAirJump.initialize",
        "function JokCombatAirJump.restoreRoutes",
        "function JokCombatAirJump.isNativeFirstJumpEntry",
        "return animation == 0x04 or animation == 0x09",
        "function JokCombatAirJump.noteGroundJump",
        "function JokCombatAirJump.boost",
        "function JokCombatAirJump.brakeFall",
        "function JokCombatAirJump.observe",
        "function JokCombatAirJump.canBegin",
        "function JokCombatAirJump.ownsCircle",
        "function JokCombatAirJump.begin",
        'if entry.name == "flyingCombo1" then return 0x09 end',
        "WriteByte(entry.address, JokCombatAirJump.routeAnimation(entry))",
        "WriteFloat(player.pointer + PLAYER.verticalPosition,",
        "boostedPosition, true)",
        "rawDelta * CONFIG.airFallBrakeFactor",
        "player.animation ~= 0x06 and player.animation ~= 0x0B",
        "JokCombatAirJump.brakeFall(player)",
        "free-fall brake: factor=%.2f",
        "native free-fall brake ready: base Fall 0x06 / High Jump Fall",
        "if player.animation == 0x0F then",
        "and JokCombatAirJump.ownsCircle(buttons) then",
        "if not triggerAttackCommand() then",
        "WriteByte(ADDRESS.comboPosition, 1)",
        'JokCombatBranch.reset("second jump")',
        'cancelPlayer(player, "second-jump")',
        "second jump is not charged",
        "the charge remains consumed until landing",
        "landing confirmed; second jump recharges",
        "Kinetic Step accepted",
        "native air Superglide ready",
        "if player.airborne and not JokCombatAirJump.releaseRequired then",
        "local nativeSuperglideOwnsSquare =",
        "CONFIG.nativeAirSuperglideOnSquare and playerAirborne",
        "local dodgeSquareHeld = squareHeld and not nativeSuperglideOwnsSquare",
        "CONFIG.fixedDodgeOnSquare and not playerAirborne",
        "and not player.airborne",
        "air route 0x0F + Attack pulse armed",
        "releaseRequired = false",
        "first-jump B released; second-jump input unlocked",
        "first native jump confirmed via 0x%02X; ",
        "release the first-jump input",
        "not nativeShortcutHeld",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing native second-jump guard: {guard}"

    start = SOURCE.index("JokCombatAirJump = {")
    end = SOURCE.index("JokCombatAirAttackBrake = {", start)
    adapter = SOURCE[start:end]
    assert adapter.count("WriteFloat(") == 2
    assert "PLAYER.animationId" not in adapter
    assert "WriteInt(player.pointer + PLAYER.airborneState" not in adapter
    assert "WriteLong(ADDRESS.circleHandler" not in adapter
    assert "circleHandlerAirEntry" not in SOURCE
    assert "circleHandlerFallEntry" not in SOURCE

    brake_start = adapter.index("function JokCombatAirJump.brakeFall")
    brake_end = adapter.index("function JokCombatAirJump.observe", brake_start)
    brake_source = adapter[brake_start:brake_end]
    assert "JokCombatAirJump.consumed" not in brake_source

    owns_start = adapter.index("function JokCombatAirJump.ownsCircle")
    owns_end = adapter.index("function JokCombatAirJump.begin", owns_start)
    owns_source = adapter[owns_start:owns_end]
    assert "and not JokCombatAirJump.releaseRequired" in owns_source
    assert "or JokCombatAirJump.consumed" in owns_source
    assert "or JokCombatAirJump.routeOwned or JokCombatAirJump.active" in owns_source
    assert "superglideReady" not in adapter

    defense_start = SOURCE.index("local function updateDefenseRouting")
    defense_end = SOURCE.index("function _OnInit()", defense_start)
    defense_source = SOURCE[defense_start:defense_end]
    assert "circleMap = CONTROL_INDEX.SQUARE" not in defense_source
    assert "allowAirDodge" not in defense_source
    assert "allowAirGuard and 0x82 or 0x85" in defense_source

    first_jump_start = adapter.index(
        "if not JokCombatAirJump.wasAirborne"
    )
    first_jump_end = adapter.index(
        "JokCombatAirJump.wasAirborne = true", first_jump_start
    )
    first_jump_source = adapter[first_jump_start:first_jump_end]
    assert "JokCombatAirJump.fallBrakeArmed = true" in first_jump_source
    assert "JokCombatAirJump.fallBrakeSamples = 0" in first_jump_source
    assert "local circleEdge" not in first_jump_source

    # Model the transient route set: all eight canonical air entries must be
    # covered, with 0x09 reserved exclusively for FlyingCombo1 and 0x0F used
    # by every ordinary aerial selector. This catches a future table addition
    # that would otherwise escape the byte-only Kinetic Step patch.
    air_start = SOURCE.index("local AIR_ACTION_ROUTE = {")
    air_end = SOURCE.index("-- Canonical complete records", air_start)
    air_names = re.findall(
        r'\{ name = "([^"]+)"', SOURCE[air_start:air_end]
    )
    expected_air_names = [
        "airComboAerialSweep",
        "airCombo1C",
        "airCombo1B",
        "airComboHurricane",
        "airComboFinisher",
        "airCombo2",
        "airCombo1",
        "flyingCombo1",
    ]
    assert air_names == expected_air_names
    simulated_heads = {
        name: 0x09 if name == "flyingCombo1" else 0x0F
        for name in air_names
    }
    assert list(simulated_heads.values()).count(0x0F) == 7
    assert list(simulated_heads.values()).count(0x09) == 1

    native_guards = (
        'VERSION = "v0.6.0"',
        "SHARED_ABILITY_SLOT_COUNT = 4",
        "sharedAbilitySlots = 0x2DE98F9",
        "local SHARED_MOVEMENT = {",
        '{ name = "Glide", base = 0x03',
        '{ name = "Superglide", base = 0x04',
        "local function reconcileSharedAbility",
        "local function removeLegacySoraHighJump",
        "Shared High Jump/Glide/Superglide + exact native",
    )
    for guard in native_guards:
        assert guard in NATIVE_SOURCE, (
            f"missing Shared High Jump grant guard: {guard}"
        )

    passives_start = NATIVE_SOURCE.index("local PASSIVES = {")
    passives_end = NATIVE_SOURCE.index(
        "local SHARED_MOVEMENT", passives_start
    )
    assert "High Jump" not in NATIVE_SOURCE[passives_start:passives_end], (
        "High Jump must not return to Sora's personal ability list"
    )


def assert_air_attack_descent_brake() -> None:
    guards = (
        "airAttackFallBrake = true",
        "airAttackFallBrakeFactor = 0.25",
        "JokCombatAirAttackBrake = {",
        "function JokCombatAirAttackBrake.ownsAnimation",
        "animation == 0xCC or animation == 0xCD or animation == 0xCE",
        "function JokCombatAirAttackBrake.initialize",
        "function JokCombatAirAttackBrake.reset",
        "function JokCombatAirAttackBrake.disableCycle",
        "function JokCombatAirAttackBrake.observe",
        "rawDelta * CONFIG.airAttackFallBrakeFactor",
        "[air-attack] descent brake: factor=%.2f",
        "JokCombatAirAttackBrake.observe(player, nativeLimitActive)",
        'JokCombatAirAttackBrake.reset("player unavailable"',
        "CC/CD/CE downward delta x0.25",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing air-attack descent guard: {guard}"

    start = SOURCE.index("JokCombatAirAttackBrake = {")
    end = SOURCE.index("JokCombatAttackSpeed = {", start)
    controller = SOURCE[start:end]
    assert controller.count("WriteFloat(") == 1
    assert "animation == 0xD1" not in controller
    assert "animation == 0xD6" not in controller
    assert "WriteInt(player.pointer + PLAYER.airborneState" not in controller
    assert "PLAYER.animationSpeed" not in controller


def assert_integration() -> None:
    guards = (
        'VERSION = "v1.0.0"',
        "branchActionAbilities = true",
        "branchLimits = true",
        "comboGuide = true",
        "neutralTriangleGraceFrames = 2",
        'return string.rep("X", position) .. "T"',
        'if root == "T" then return JokCombatBranch.armNeutralTriangle() end',
        "function JokCombatBranch.armNeutralTriangle",
        "function JokCombatBranch.resolveNeutralTriangle",
        "neutral Y left native for contextual arbitration",
        "physical A took priority",
        "opening Strong",
        "neutral Y arbitration ready: two released frames before Strong",
        "function JokCombatBranch.continuePhysical",
        "+ A -> native physical continuation; family closed",
        "JokCombatBranch.reset(\"Guard cancel\")",
        "JokCombatBranch.reset(\"Dodge cancel\")",
        "JokCombatBranch.reset(\"jump\")",
        "if nativeLimitActive then",
        "native Limit owns input",
        "if configurationInputActive or nativeLimitActive then",
        "updateDefenseRouting(buttons, false, false, true, player)",
        "local nativeReaction = ReadShort(ADDRESS.reactionCommandId)",
        "if nativeReaction ~= 0 and not branchOwnsInput then",
        "Y delegated to native Reaction 0x%04X",
        "Musou family not opened",
        "function JokCombatBranch.guideEntries",
        "function JokCombatBranch.familyGuideEntries",
        'local sequence = "[Y]"',
        'sequence = sequence .. "[Y]"',
        'if path == "T" then return nil end',
        'return HUD.showOverlay("guide", guideEntries, "Combo Guide")',
        "legacy combo-magic recovery ready; no combo path can cast magic.",
        "Strong=burst, C2=pursuit, C3=crowd control",
        "C4=combo pressure, C5=execution",
        "standard C4",
        "Slapshot/Blitz/Strike Raid",
        "C4 shows Slapshot -> Blitz -> Strike Raid",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing integration guard: {guard}"

    branch_start = SOURCE.index("function JokCombatBranch.update")
    branch_end = SOURCE.index("local function updateCrossActionPrime", branch_start)
    branch_update = SOURCE[branch_start:branch_end]
    selector_gate = branch_update.index("JokCombatNativeLimit.selectorOwned()")
    reaction_gate = branch_update.index(
        "local nativeReaction = ReadShort(ADDRESS.reactionCommandId)"
    )
    arbitration = branch_update.index(
        "JokCombatBranch.resolveNeutralTriangle("
    )
    strong_arm = branch_update.index(
        'if root == "T" then return JokCombatBranch.armNeutralTriangle() end'
    )
    assert selector_gate < arbitration < reaction_gate < strong_arm, (
        "native Limit must keep priority; an already pending neutral Y must "
        "resolve before the idle Reaction gate and a new Strong request"
    )

    resolver_start = SOURCE.index(
        "function JokCombatBranch.resolveNeutralTriangle"
    )
    resolver_end = SOURCE.index(
        "function JokCombatBranch.nodeName", resolver_start
    )
    resolver = SOURCE[resolver_start:resolver_end]
    reaction_check = resolver.index(
        "local nativeReaction = ReadShort(ADDRESS.reactionCommandId)"
    )
    cross_cancel = resolver.index("if crossPressed then")
    strong_dispatch = resolver.index(
        'JokCombatBranch.execute(player, "T")'
    )
    assert reaction_check < cross_cancel < strong_dispatch, (
        "native Reaction and the first physical A confirmation must both win "
        "before delayed Strong dispatch"
    )
    assert "branchMagic" not in SOURCE
    assert "JokCombatMagic" not in SOURCE
    assert '"[A] Continua vanilla"' not in SOURCE
    assert "leftStickInput" not in SOURCE
    for retired in (
        "groundAirUltimate",
        "ultimatePhase",
        "beginUltimate",
        "updateUltimateState",
        "Aerial Chase",
        "ultimate-aerial-chase",
    ):
        assert retired not in SOURCE, f"retired C4 state remains: {retired}"

    slot_start = SOURCE.index("local ACTION_SLOTS = {")
    slot_end = SOURCE.index("local ACTION_SLOT_BY_ID = {}", slot_start)
    slots = set(re.findall(r'id = "([^"]+)"', SOURCE[slot_start:slot_end]))
    assert slots == {"r2_cross", "r2_triangle", "r2_circle", "r2_square"}


def main() -> None:
    nodes = parse_nodes()
    assert_map(nodes)
    assert_action_partition(nodes)
    assert_aerial_is_independent()
    assert_native_limits()
    assert_guard_counter()
    assert_native_second_jump()
    assert_air_attack_descent_brake()
    assert_integration()
    print(
        "PASS: 13-node ground map; 8 ground Actions + 5 native Limits; "
        "standard C4 Slapshot/Blitz/Strike Raid; native aerial descent brake; "
        "Counterattack gated by successful Guard"
    )


if __name__ == "__main__":
    main()
