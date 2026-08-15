"""Static safety checks for the read-only melee-hit and MP probe."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_MPHitProbe.lua").read_text(encoding="utf-8")


def test_probe_is_strictly_read_only() -> None:
    writes = re.findall(
        r"\bWrite(?:Byte|Short|Int|Long|Float|Array)\s*\(", SOURCE
    )
    assert writes == [], f"diagnostic contains memory writes: {writes}"
    assert "MP recovery is OFF" in SOURCE
    assert "never clears the game's contact" in SOURCE


def test_supported_build_and_memory_layout_are_explicit() -> None:
    guards = (
        "EXPECTED_GAME_ID = 0xAF71841E",
        "FINGERPRINT = 0x7265737563697065",
        "fingerprint = 0x3B2271",
        "playerPointer = 0x2537E48",
        "battleSlotBase = 0x2D50000",
        "connectCounter = 0x296B230",
        "slotReference = 0x06C",
        "currentMP = 0x44",
        "maxMP = 0x48",
        "slotReference < SLOT_REFERENCE_MIN",
        "slotReference > SLOT_REFERENCE_MAX",
        "ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing fail-closed probe guard: {guard}"


def test_only_native_normal_animation_candidates_are_tracked() -> None:
    for animation in range(0xC8, 0xCF):
        assert f"[0x{animation:02X}]" in SOURCE
    assert "snapshot.animation <= 0xCA and snapshot.secondary <= 0x02" in SOURCE
    assert "reuse-excluded" in SOURCE
    assert "[0x01] = true" in SOURCE
    assert "[0x40] = true" in SOURCE


def test_probe_correlates_edges_once_per_attack_without_rewarding() -> None:
    guards = (
        "activeAttack.hitCandidate",
        "activeAttack.signalEdges",
        "snapshot.time + 0.50 < activeAttack.lastTime",
        "[JokCombat:mp-hit-probe:attack-start]",
        "[JokCombat:mp-hit-probe:attack-end]",
        "[JokCombat:mp-hit-probe:signal]",
        "[JokCombat:mp-hit-probe:hit-candidate]",
        "[JokCombat:mp-hit-probe:mp-change]",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing correlation telemetry: {guard}"


def main() -> None:
    test_probe_is_strictly_read_only()
    test_supported_build_and_memory_layout_are_explicit()
    test_only_native_normal_animation_candidates_are_tracked()
    test_probe_correlates_edges_once_per_attack_without_rewarding()
    print("PASS: MP hit probe is read-only, fail-closed, and edge-correlated")


if __name__ == "__main__":
    main()
