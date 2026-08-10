"""Static regression checks for the canonical JokCombat X/T tree.

The production script is Lua 5.3 and is loaded by LuaBackendHook.  This test
keeps the data table reviewable without emulating KH1 memory or dispatch code.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")


EXPECTED = {
    "XT": ("action", "slapshot"),
    "XTX": ("action", "vortex"),
    "XTXX": ("magic", "fire"),
    "XTXT": ("magic", "blizzard"),
    "XTT": ("action", "sliding_dash"),
    "XTTX": ("action", "counterattack"),
    "XTTT": ("magic", "cure"),
    "XXT": ("action", "aerial_sweep"),
    "XXTX": ("action", "hurricane_blast"),
    "XXTXX": ("magic", "thunder"),
    "XXTXT": ("magic", "aero"),
    "XXTT": ("limit", "ragnarok"),
    "XXXT": ("action", "ripple_drive"),
    "XXXTX": ("action", "stun_impact"),
    "XXXTXX": ("magic", "gravity"),
    "XXXTXT": ("magic", "stop"),
    "XXXTT": ("action", "gravity_break"),
    "XXXTTX": ("limit", "ars_arcanum"),
    "XXXTTT": ("experimental", "chain_attack_burst"),
    "XXXXT": ("action", "blitz"),
    "XXXXTX": ("action", "zantetsuken"),
    "XXXXTT": ("limit", "strike_raid"),
    "XXXXXT": ("limit", "sonic_blade"),
    "XXXXXXT": ("limit", "trinity_limit"),
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
        if "cross" in node:
            assert node["cross"] == path + "X"
            assert node["cross"] in nodes
        if "triangle" in node:
            assert node["triangle"] == path + "T"
            assert node["triangle"] in nodes

    roots = {"XT", "XXT", "XXXT", "XXXXT", "XXXXXT", "XXXXXXT"}
    reachable = set(roots)
    frontier = list(roots)
    while frontier:
        path = frontier.pop()
        for field in ("cross", "triangle"):
            child = nodes[path].get(field)
            if child and child not in reachable:
                reachable.add(child)
                frontier.append(child)
    assert reachable == set(nodes), "one or more canonical nodes are unreachable"

    assert "branchActionAbilities = true" in SOURCE
    assert "branchMagic = false" in SOURCE
    assert "branchLimits = false" in SOURCE
    assert 'VERSION = "v0.7.1"' in SOURCE
    assert 'return string.rep("X", position) .. "T"' in SOURCE
    assert re.search(
        r'id = "hurricane_blast", name = "Hurricane Blast", context = "air"',
        catalog_source,
    ), "normal Hurricane Blast shortcut must remain air-only"

    hurricane_bridge_guards = (
        'path == "XXTX"',
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
    )
    for guard in integration_guards:
        assert guard in SOURCE, f"missing branch integration guard: {guard}"
    print("PASS: 24 unique reachable nodes; 11/11 Action Ability adapters enabled")


if __name__ == "__main__":
    main()
