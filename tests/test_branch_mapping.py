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
    assert "branchMagic = false" in SOURCE
    assert "branchLimits = false" in SOURCE
    assert 'VERSION = "v0.9.0"' in SOURCE
    assert 'return string.rep("X", position) .. "T"' in SOURCE
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
        "+ A -> native physical continuation; no named ability dispatched",
        'if root == "T" then return JokCombatBranch.execute(player, root) end',
    )
    for guard in integration_guards:
        assert guard in SOURCE, f"missing branch integration guard: {guard}"
    guide_guards = (
        "comboGuide = true",
        "function JokCombatBranch.guideEntries",
        "function JokCombatBranch.branchGuideEntries",
        "function JokCombatBranch.familyGuideEntries",
        'local sequence = "[Y]"',
        'sequence = sequence .. "[Y]"',
        'if path == "T" then return nil end',
        'return HUD.showOverlay("guide", guideEntries, "Combo Guide")',
        "not JokCombatBranch.kindReady(node)",
    )
    for guard in guide_guards:
        assert guard in SOURCE, f"missing Combo Guide guard: {guard}"
    assert '"[A] Continua vanilla"' not in SOURCE
    print("PASS: 24 unique Y-ended moves; 11/11 Pirate Action slots enabled")


if __name__ == "__main__":
    main()
