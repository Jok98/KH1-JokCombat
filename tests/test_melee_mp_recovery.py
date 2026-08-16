"""Static safety checks for confirmed-normal-hit MP regeneration."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")


def controller_source() -> str:
    start = SOURCE.index("JokCombatMeleeMP = {")
    end = SOURCE.index("local function actionKind", start)
    return SOURCE[start:end]


def test_balance_is_exact_and_does_not_bank_at_full_mp() -> None:
    controller = controller_source()
    assert "meleeMPRecovery = true" in SOURCE
    assert "meleeHitsPerMP = 10" in SOURCE
    assert "JokCombatMeleeMP.credit = JokCombatMeleeMP.credit + 1" in controller
    assert "JokCombatMeleeMP.credit < JokCombatMeleeMP.hitsPerMP" in controller
    assert "if currentMP >= maxMP then" in controller
    full_block = controller[controller.index("if currentMP >= maxMP then") :]
    full_block = full_block[: full_block.index("end\n    JokCombatMeleeMP.fullLogged")]
    assert "JokCombatMeleeMP.credit = 0" in full_block
    assert "no charge banked" in full_block


def test_only_one_rising_contact_edge_per_native_normal_is_eligible() -> None:
    controller = controller_source()
    guards = (
        "player.animation < 0xC8",
        "player.animation > 0xCE",
        "player.animation <= 0xCA and player.secondary <= 0x02",
        "player.airborneState < 0x20",
        "not nativeLimitActive",
        "JokCombatMeleeMP.lastSignal ~= nil",
        "signal ~= JokCombatMeleeMP.lastSignal",
        "signal == 0x01 or signal == 0x40",
        "not JokCombatMeleeMP.hitSeen",
        "JokCombatMeleeMP.hitSeen = true",
        "player.time + 0.50 < JokCombatMeleeMP.lastTime",
    )
    for guard in guards:
        assert guard in controller, f"missing melee-hit ownership guard: {guard}"


def test_mp_write_is_capped_verified_and_is_the_only_controller_write() -> None:
    controller = controller_source()
    guards = (
        "currentMPOffset = 0x44",
        "maxMPOffset = 0x48",
        "ADDRESS.battleSlotBase + slot",
        "slot < 0x8000 or slot > 0xFFFF",
        "maxMP < 1 or maxMP > 99 or currentMP > maxMP",
        "local desired = math.min(maxMP, currentMP + 1)",
        "WriteByte(currentAddress, desired)",
        "local observed = ReadByte(currentAddress)",
        "if observed ~= desired then",
        "recovery disabled until reload",
    )
    for guard in guards:
        assert guard in controller, f"missing MP write guard: {guard}"
    assert controller.count("WriteByte(") == 1
    assert "WriteByte(ADDRESS.connectCounter" not in SOURCE
    for forbidden in ("comboPosition", "animationId", "airborneState"):
        assert f"WriteByte({forbidden}" not in controller


def test_controller_is_integrated_into_lifecycle() -> None:
    guards = (
        "JokCombatMeleeMP.initialize()",
        "JokCombatMeleeMP.observe(player, nativeLimitActive)",
        'JokCombatMeleeMP.reset("patch restore", true, true)',
        "1 MP every %d confirmed native normal hits",
        "full-MP hits are not banked",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing melee-MP lifecycle integration: {guard}"


def main() -> None:
    test_balance_is_exact_and_does_not_bank_at_full_mp()
    test_only_one_rising_contact_edge_per_native_normal_is_eligible()
    test_mp_write_is_capped_verified_and_is_the_only_controller_write()
    test_controller_is_integrated_into_lifecycle()
    print("PASS: melee MP recovery is edge-gated, capped, and 1-per-10")


if __name__ == "__main__":
    main()
