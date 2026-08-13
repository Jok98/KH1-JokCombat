"""Static safety checks for the bounded native-combo speed controller."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")


def test_speedup_is_light_and_limited_to_native_combo_ids() -> None:
    assert "normalAttackSpeedMultiplier = 1.15" in SOURCE
    assert "animationSpeed = 0x284" in SOURCE
    assert "player.animation < 0xC8" in SOURCE
    assert "player.animation > 0xCE" in SOURCE
    assert "player.animation <= 0xCA and player.secondary <= 0x02" in SOURCE


def test_speedup_has_conditional_ownership_and_restoration() -> None:
    assert "function JokCombatAttackSpeed.restore" in SOURCE
    assert "current, JokCombatAttackSpeed.ownedSpeed" in SOURCE
    assert "current, JokCombatAttackSpeed.originalSpeed" in SOURCE
    assert "playback speed changed externally" in SOURCE
    assert 'JokCombatAttackSpeed.restore("patch restore", true)' in SOURCE
    assert "JokCombatAttackSpeed.observe(player, nativeLimitActive)" in SOURCE


def test_noncombat_and_special_states_are_excluded() -> None:
    assert "nativeLimitActive or player.airborneState >= 0x20" in SOURCE
    assert "ReadByte(ADDRESS.world) == 0x09 or not normalPhysical" in SOURCE
    assert "Action Abilities, Limits, magic, defense, jumps and locomotion" in SOURCE


def main() -> None:
    test_speedup_is_light_and_limited_to_native_combo_ids()
    test_speedup_has_conditional_ownership_and_restoration()
    test_noncombat_and_special_states_are_excluded()
    print("PASS: native C8-CE attack speedup is bounded and reversible")


if __name__ == "__main__":
    main()
