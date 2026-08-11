"""Static regression checks for JokCombat's contextual A/Y moveset.

The production script is Lua 5.3 and runs inside LuaBackendHook. These checks
keep the approved map and its native adapters reviewable without emulating KH1.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")


EXPECTED = {
    # Strong / energy.
    "T": ("action", "vortex"),
    "TT": ("action", "gravity_break"),
    "TTT": ("limit", "ragnarok"),
    # C2 / mobility.
    "XT": ("action", "sliding_dash"),
    "XTT": ("action", "blitz"),
    "XTTT": ("limit", "sonic_blade"),
    # C3 / area.
    "XXT": ("action", "stun_impact"),
    "XXTT": ("action", "ripple_drive"),
    "XXTTT": ("limit", "trinity_limit"),
    # C4 / range.
    "XXXT": ("action", "slapshot"),
    "XXXTT": ("limit", "strike_raid"),
    # C5 / execution.
    "XXXXT": ("action", "zantetsuken"),
    "XXXXTT": ("limit", "ars_arcanum"),
}

LIMITS = {
    "sonic_blade": ("XTTT", "XTT", "0x004B"),
    "ars_arcanum": ("XXXXTT", "XXXXT", "0x0057"),
    "strike_raid": ("XXXTT", "XXXT", "0x005E"),
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
            ("XT", "XTT", "XTTT"),
            ("XXT", "XXTT", "XXTTT"),
            ("XXXT", "XXXTT"),
            ("XXXXT", "XXXXTT"),
        )
        for path in family
    }


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
        "function JokCombatNativeLimit.update",
        "if limit.costAddress ~= nil then WriteShort(limit.costAddress, 0) end",
        "WriteShort(ADDRESS.reactionCommandId, limit.reactionId)",
        "function JokCombatBranch.prearmLimitChild",
        "local limit = JokCombatNativeLimit.forPrefix(JokCombatBranch.path)",
        "JokCombatBranch.prearmLimitChild(player)",
        "parent Action ended before final Y",
        "and JokCombatNativeLimit.selectionFrames <= 0",
        "branch closed before final Y",
        '"[branch] %s final Y delegated to native %s."',
        "Final Y belongs to KH1",
        "native Limit combos ready: %d/5",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing native Limit guard: {guard}"
    assert "observePhysicalLink" not in SOURCE
    assert "reverseWaiting" not in SOURCE
    assert "hasReadyDescendant" not in SOURCE


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


def assert_integration() -> None:
    guards = (
        'VERSION = "v0.13.2"',
        "branchActionAbilities = true",
        "branchLimits = true",
        "comboGuide = true",
        'return string.rep("X", position) .. "T"',
        'if root == "T" then return JokCombatBranch.execute(player, root) end',
        "function JokCombatBranch.continuePhysical",
        "+ A -> native physical continuation; family closed",
        "JokCombatBranch.reset(\"Guard cancel\")",
        "JokCombatBranch.reset(\"Dodge cancel\")",
        "JokCombatBranch.reset(\"jump\")",
        "if nativeLimitActive then",
        "native Limit owns input",
        "if configurationInputActive or nativeLimitActive then",
        "updateDefenseRouting(buttons, false, false, true)",
        "function JokCombatBranch.guideEntries",
        "function JokCombatBranch.familyGuideEntries",
        'local sequence = "[Y]"',
        'sequence = sequence .. "[Y]"',
        'if path == "T" then return nil end',
        'return HUD.showOverlay("guide", guideEntries, "Combo Guide")',
        "legacy combo-magic recovery ready; no combo path can cast magic.",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing integration guard: {guard}"
    assert "branchMagic" not in SOURCE
    assert "JokCombatMagic" not in SOURCE
    assert '"[A] Continua vanilla"' not in SOURCE

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
    assert_integration()
    print(
        "PASS: 13-node ground map; 8 ground Actions + 5 native Limits; "
        "aerial family independent; Counterattack gated by successful Guard"
    )


if __name__ == "__main__":
    main()
