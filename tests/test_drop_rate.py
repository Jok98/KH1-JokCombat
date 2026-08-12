"""Static safety checks for JokCombat's Steam Global drop-rate module."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_DropRate.lua").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
TECHNICAL_DESIGN = (
    ROOT / "docs" / "TECHNICAL_DESIGN.md"
).read_text(encoding="utf-8")


def test_fixed_multiplier_and_validated_steam_operands() -> None:
    assert "local TARGET_MULTIPLIER = 2.0" in SOURCE
    assert "itemDropMultiplier = 0x2A63E4" in SOURCE
    assert "prizeDropMultiplier = 0x2A63EE" in SOURCE
    assert "item = { 0xC7, 0x05, 0xC0, 0xAB, 0xAB, 0x02 }" in SOURCE
    assert "prize = { 0xC7, 0x05, 0xB2, 0xAB, 0xAB, 0x02 }" in SOURCE


def test_patch_is_bounded_and_reversible() -> None:
    assert "function _OnFrame()" not in SOURCE
    assert SOURCE.count("WriteFloat(") == 5
    assert "function _OnExit()" in SOURCE
    assert "changed externally" in SOURCE
    assert "leaving it untouched" in SOURCE
    assert "unsupported game/build; drop-rate patch disabled." in SOURCE
    assert "Steam operand signature mismatch; all writes disabled." in SOURCE


def test_documentation_distinguishes_jokcombat_from_critical_mix() -> None:
    assert "Fixed `200%` item and prize drop multipliers" in README
    assert "JokCombat_DropRate.lua" in README
    assert "## 14. Drop-rate policy" in TECHNICAL_DESIGN
    assert "difficulty-dependent base" in TECHNICAL_DESIGN
    assert "This is a fixed JokCombat rule" in TECHNICAL_DESIGN


def main() -> None:
    test_fixed_multiplier_and_validated_steam_operands()
    test_patch_is_bounded_and_reversible()
    test_documentation_distinguishes_jokcombat_from_critical_mix()
    print("PASS: fixed 2.0x item/prize drop patch is signed and reversible")


if __name__ == "__main__":
    main()
