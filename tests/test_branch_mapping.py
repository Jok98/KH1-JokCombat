"""Static regression checks for the Pirate-style JokCombat X/T families.

The production script is Lua 5.3 and is loaded by LuaBackendHook.  This test
keeps the data table reviewable without emulating KH1 memory or dispatch code.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")


EXPECTED = {
    "T": ("action", "vortex"),
    "TT": ("action", "stun_impact"),
    "TTT": ("action", "gravity_break"),
    "XT": ("action", "slapshot"),
    "XTT": ("action", "sliding_dash"),
    "XTTT": ("action", "blitz"),
    "XXT": ("action", "aerial_sweep"),
    "XXTT": ("action", "hurricane_blast"),
    "XXTTT": ("action", "ripple_drive"),
    "XXXT": ("action", "counterattack"),
    "XXXXT": ("action", "zantetsuken"),
    "TXT": ("magic", "fire"),
    "TXXT": ("magic", "blizzard"),
    "TTXT": ("magic", "thunder"),
    "TTXXT": ("magic", "aero"),
    "TTTXT": ("magic", "cure"),
    "XTTTXT": ("magic", "gravity"),
    "XXTTTXT": ("magic", "stop"),
    "TXXXT": ("limit", "sonic_blade"),
    "TTXXXT": ("limit", "ars_arcanum"),
    "TTTXXT": ("limit", "strike_raid"),
    "XTTTXXT": ("limit", "ragnarok"),
    "XXTTTXXT": ("limit", "trinity_limit"),
    "TTTXXXT": ("experimental", "chain_attack_burst"),
}


def parse_nodes() -> dict[str, dict[str, str]]:
    start = SOURCE.index("    nodes = {")
    end = SOURCE.index("    windows = {", start)
    lines = SOURCE[start:end].splitlines()[1:]
    entries: dict[str, dict[str, str]] = {}
    current: list[str] = []
    for line in lines:
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
            for field in ("cross", "triangle"):
                child = re.search(rf'{field} = "([XT]+)"', remainder)
                if child:
                    node[field] = child.group(1)
            entries[path] = node
            current = []
    return entries


def main() -> None:
    nodes = parse_nodes()
    actual = {path: (node["kind"], node["id"]) for path, node in nodes.items()}
    assert actual == EXPECTED, "runtime tree differs from the approved map"
    assert len(nodes) == 24
    assert len(set(actual.values())) == 24, "canonical actions are duplicated"

    action_nodes = {
        node["id"] for node in nodes.values() if node["kind"] == "action"
    }
    assert len(action_nodes) == 11

    catalog_start = SOURCE.index("local ACTION_CATALOG = {")
    catalog_end = SOURCE.index("local ACTION_BY_ID = {}", catalog_start)
    catalog_source = SOURCE[catalog_start:catalog_end]
    catalog_ids = set(re.findall(r'\{ id = "([^"]+)"', catalog_source))
    assert action_nodes <= catalog_ids, "branch references an unknown Action Ability"

    action_contexts: dict[str, str] = {}
    for entry in re.finditer(
        r'(?ms)^    \{ id = "([^"]+)"(.*?)(?=^    \{ id = |^})',
        catalog_source,
    ):
        context = re.search(r'context = "([^"]+)"', entry.group(2))
        if context:
            action_contexts[entry.group(1)] = context.group(1)

    animations: dict[str, int] = {}
    for entry in re.finditer(
        r'(?ms)^    \{ id = "([^"]+)"(.*?)(?=^    \{ id = |^})',
        catalog_source,
    ):
        animation = re.search(r'animation = (0x[0-9A-F]+)', entry.group(2))
        if animation:
            animations[entry.group(1)] = int(animation.group(1), 16)
    window_start = SOURCE.index("    windows = {", catalog_end)
    window_end = SOURCE.index("    slot = {", window_start)
    window_animations = {
        int(value, 16)
        for value in re.findall(r'\[(0x[0-9A-F]+)\]', SOURCE[window_start:window_end])
    }
    for node in nodes.values():
        if node["kind"] == "action" and (
            "cross" in node or "triangle" in node
        ):
            assert animations[node["id"]] in window_animations, (
                f'{node["id"]} can continue but has no safe window'
            )

    for path, node in nodes.items():
        assert path.endswith("T"), f"named move {path} does not end in Y/T"
        assert "cross" not in node, f"A/X dispatches a named move at {path}"
        if "triangle" in node:
            assert node["triangle"] == path + "T"
            assert node["triangle"] in nodes

    action_families = {
        "strong": ("T", "TT", "TTT"),
        "c2": ("XT", "XTT", "XTTT"),
        "c3": ("XXT", "XXTT", "XXTTT"),
        "c4": ("XXXT",),
        "c5": ("XXXXT",),
    }
    family_actions = {
        path for family in action_families.values() for path in family
    }
    assert family_actions == {
        path for path, node in nodes.items() if node["kind"] == "action"
    }
    assert sum(len(family) for family in action_families.values()) == 11

    assert "branchActionAbilities = true" in SOURCE
    assert "branchMagic = true" in SOURCE
    assert "branchLimits = false" in SOURCE
    assert 'VERSION = "v0.9.7"' in SOURCE
    assert 'return string.rep("X", position) .. "T"' in SOURCE
    assert 'if isAirNormalContext(player) then' in SOURCE
    assert 'return "XXT"' in SOURCE
    assert "Every intermediate native aerial hit aliases" in SOURCE
    assert re.search(
        r'id = "hurricane_blast", name = "Hurricane Blast", context = "air"',
        catalog_source,
    ), "normal Hurricane Blast shortcut must remain air-only"

    hurricane_bridge_guards = (
        'path == "XXTT"',
        'JokCombatBranch.path == "XXT"',
        'player.animation == 0xD6',
        'and not player.airborne',
        'branchContextAuthorized)',
    )
    for guard in hurricane_bridge_guards:
        assert guard in SOURCE, f"missing Hurricane Blast bridge guard: {guard}"

    integration_guards = (
        "branchWindowAuthorized == true",
        "JokCombatBranch.reset(\"Guard cancel\")",
        "JokCombatBranch.reset(\"Dodge cancel\")",
        "JokCombatBranch.reset(\"jump\")",
        "JokCombatBranch.reset(\"loadout editor opened\", true)",
        "and JokCombatBranch.active",
        "new input discarded until recovery",
        "function JokCombatBranch.continuePhysical",
        "function JokCombatBranch.observePhysicalLink",
        "function JokCombatBranch.hasReadyDescendant",
        'JokCombatBranch.reverseWaitingKind = "pirate-light:" .. nextPrefix',
        "JokCombatBranch.observePhysicalLink(player, acceptedKind)",
        "+ A -> native physical continuation",
        "; no named ability dispatched.",
        'if root == "T" then return JokCombatBranch.execute(player, root) end',
    )
    for guard in integration_guards:
        assert guard in SOURCE, f"missing branch integration guard: {guard}"
    assert action_contexts == {
        "none": "none",
        "slapshot": "ground",
        "sliding_dash": "ground",
        "vortex": "ground",
        "aerial_sweep": "both",
        "counterattack": "ground",
        "blitz": "ground",
        "hurricane_blast": "air",
        "ripple_drive": "ground",
        "stun_impact": "ground",
        "gravity_break": "ground",
        "zantetsuken": "ground",
    }
    native_air_guards = (
        "function JokCombatBranch.nodeReady",
        'return not player.airborne and path == "XXTT"',
        "JokCombatBranch.nodeReady(node, player, root)",
        "JokCombatBranch.nodeReady(childNode, player, child)",
        "airborne Action Ability policy ready: native air records only",
        "fake-ground disabled",
    )
    for guard in native_air_guards:
        assert guard in SOURCE, f"missing native-air policy guard: {guard}"
    assert "airBridge" not in catalog_source
    assert "airGroundActionBridge" not in SOURCE
    assert "leftStickInput" not in SOURCE
    guide_guards = (
        "comboGuide = true",
        "function JokCombatBranch.guideEntries",
        "function JokCombatBranch.branchGuideEntries",
        "function JokCombatBranch.familyGuideEntries",
        "function JokCombatBranch.guideEntriesFromPrefix",
        'local sequence = "[Y]"',
        'sequence = sequence .. "[Y]"',
        'string.rep("[A]", count) .. "[Y]"',
        'if path == "T" then return nil end',
        'return HUD.showOverlay("guide", guideEntries, "Combo Guide")',
        "not JokCombatBranch.nodeReady(node, player, path)",
    )
    for guard in guide_guards:
        assert guard in SOURCE, f"missing Combo Guide guard: {guard}"

    magic_ids = {
        node["id"] for node in nodes.values() if node["kind"] == "magic"
    }
    assert magic_ids == {
        "fire", "blizzard", "thunder", "aero", "cure", "gravity", "stop"
    }
    magic_start = SOURCE.index("JokCombatMagic = {")
    magic_end = SOURCE.index(
        "-- Pirate-style modifier-free X/T families", magic_start
    )
    magic_source = SOURCE[magic_start:magic_end]
    for magic_id in magic_ids:
        assert re.search(rf'^        {magic_id} = \{{', magic_source, re.M), (
            f"missing native magic metadata for {magic_id}"
        )
    magic_guards = (
        "magicLevelBase = 0x2DE97E2",
        "nativeShortcutTriangle = 0x2DE9B94",
        "l2ControlMap = 0x22C9340",
        "shortcutControlSelector = 0x22C9342",
        "magicRecovery = 0x2DB79B0",
        "rawRecoverySignature = 0x313047414D4B4F4A",
        "carrierRecoverySignature = 0x323047414D4B4F4A",
        "directMapRecoverySignature = 0x333047414D4B4F4A",
        "recoverySignature = 0x343047414D4B4F4A",
        "function JokCombatMagic.recoverStale",
        "function JokCombatMagic.publishRecovery",
        "function JokCombatMagic.prearm",
        "function JokCombatMagic.restorePrearm",
        "function JokCombatMagic.restoreSyntheticInput",
        "function JokCombatMagic.request",
        "function JokCombatMagic.update",
        "JokCombatMagic.writeCost(family, address, 0)",
        "WriteByte(ADDRESS.l2ControlMap, CONTROL_INDEX.TRIANGLE)",
        "WriteByte(ADDRESS.shortcutControlSelector, 0x20)",
        "WriteByte(journal + 0x16, JokCombatMagic.l2ControlOriginal)",
        "JokCombatMagic.prearm(prefix)",
        "or JokCombatMagic.prearmed",
        "JokCombatMagic.recoverStale()",
        "local magicValid, magicCount = JokCombatMagic.initialize()",
        "native combo magic adapter %s: %d/7 families",
        "JokCombatMagic.inputRestorePending",
    )
    for guard in magic_guards:
        assert guard in SOURCE, f"missing native magic guard: {guard}"
    assert "shortcutControlCarrier" not in SOURCE
    assert "shortcutControlMap" not in SOURCE
    assert "WriteByte(ADDRESS.rawButtons, JokCombatMagic.rawInjected)" not in SOURCE
    assert "HUD.boxesClaimable(HUD.boxCount)" in SOURCE
    assert "notification buffers unavailable" not in SOURCE
    assert '"[A] Continua vanilla"' not in SOURCE
    print(
        "PASS: 24 unique Y-ended moves; 11/11 Action and 7/7 native magic "
        "routes enabled; Limits parked"
    )


if __name__ == "__main__":
    main()
