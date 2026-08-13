"""Static guards for the reversible fourth Command Menu row carrier."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "JokCombat_CombatPrototype.lua").read_text(encoding="utf-8")


def main() -> None:
    guards = (
        "nativeFallbackCommandId = 0x06",
        "nativeCarrierSignature = 0x31444D43524B4A",
        "nativeCommandBackup = nil",
        "local visibleCount = commands[4] == 0xFF and 3 or 4",
        "commands[4] == 0x00 or commands[4] == 0x36",
        "HUD.writeNativeRecovery(patches, commandPatch)",
        "ReadByte(commandPatch.address, true) == commandPatch.patched",
        "carrierRestored and \" row4=restored\" or \"\"",
        "if fourthCommand ~= 0xFF then",
        "row4-carrier=06",
    )
    for guard in guards:
        assert guard in SOURCE, f"missing fourth-row safety guard: {guard}"

    # The failed R2 Magic/Limit experiment must not survive this rollback.
    for retired in (
        "JokCombatR2Magic",
        "reactionAutoSelect",
        "nativeShortcutSquare",
        "guardOnR2Circle",
        "loaded R2 family loadout",
    ):
        assert retired not in SOURCE, f"retired R2 experiment remains: {retired}"

    print("PASS: fourth Command Menu row uses a signed reversible carrier only")


if __name__ == "__main__":
    main()
