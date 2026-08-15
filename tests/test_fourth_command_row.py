"""Static guards for Command Menu row 4 and native R2 magic Shortcuts."""

import re
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

    # The failed mixed Action/Magic/Limit experiment must not return. The new
    # R2 feature is deliberately a native magic-only three-slot page.
    for retired in (
        "JokCombatR2Magic",
        "reactionAutoSelect",
        "guardOnR2Circle",
        "loaded R2 family loadout",
    ):
        assert retired not in SOURCE, f"retired R2 experiment remains: {retired}"

    native_magic_guards = (
        "local SHORTCUT_SLOTS = {",
        "nativeShortcutStoragePointer = 0x2868BA0",
        "nativeShortcutTriangle = 0x2DE9BA4",
        "nativeShortcutSquare = 0x2DE9BA5",
        "nativeShortcutCross = 0x2DE9BA6",
        "magicLevelBase = 0x2DE97F2",
        "recoverySignature = 0x313043534D32524A",
        "nativeShortcutInputBridge = 0x28B19A",
        "nativeShortcutInputCave = 0x3ADED8",
        "JokCombatR2NativeBridge = {",
        "function JokCombatR2NativeBridge.matches(expected)",
        "function JokCombatR2NativeBridge.activeOwned()",
        "function JokCombatR2NativeBridge.ensure()",
        "function JokCombatR2NativeBridge.restore(reason, quiet)",
        "function JokCombatR2NativeBridge.initialize()",
        "R2 native Shortcut edge bridge ready: physical R2 is mapped ",
        "R2 second magic page armed: three native Shortcut slots swapped; ",
        "edge bridge waiting for KH1's next controller sample.",
        "function JokCombatR2Shortcut.distinctLearnedDefaults()",
        "function JokCombatR2Shortcut.nextSelectable(current, delta)",
        "R2 magic defaults seeded away from L1: Y=%s X=%s A=%s.",
        'file:write("format_version=3\\n")',
        "invalid pre-v3 R2 magic preset detected; it will be replaced ",
        "function JokCombatR2Shortcut.resolveNativeAddresses()",
        "[JokCombat] native Shortcut storage resolved: ",
        '"slots=0x%X levels=0x%X."',
        "B remains jump or Kinetic Step",
    )
    for guard in native_magic_guards:
        assert guard in SOURCE, f"missing native R2 magic guard: {guard}"

    slot_start = SOURCE.index("local SHORTCUT_SLOTS = {")
    slot_end = SOURCE.index("local SHORTCUT_SLOT_BY_ID = {}", slot_start)
    slots = SOURCE[slot_start:slot_end]
    assert slots.count('id = "r2_') == 3
    assert 'id = "r2_circle"' not in slots
    arm_start = SOURCE.index("function JokCombatR2Shortcut.arm()")
    arm_end = SOURCE.index("function JokCombatR2Shortcut.update", arm_start)
    arm_source = SOURCE[arm_start:arm_end]
    assert "WriteByte(ADDRESS.l2ControlMap" not in arm_source
    assert "WriteByte(ADDRESS.shortcutControlSelector" not in arm_source
    assert "CONTROL_INDEX.R2" not in SOURCE
    assert "WriteByte(ADDRESS.commandButtons" not in SOURCE
    assert "injectNativeCarrier" not in SOURCE

    resolver_start = SOURCE.index(
        "function JokCombatR2Shortcut.resolveNativeAddresses()"
    )
    resolver_end = SOURCE.index(
        "function JokCombatR2Shortcut.distinctLearnedDefaults()",
        resolver_start,
    )
    resolver = SOURCE[resolver_start:resolver_end]
    assert "ReadLong(ADDRESS.nativeShortcutStoragePointer)" in resolver
    assert "local triangle = storage - BASE_ADDR + 0x844" in resolver
    assert "local levelBase = triangle - 0x3B2" in resolver
    assert "SHORTCUT_SLOT_BY_ID.r2_triangle.address = triangle" in resolver

    editor_start = SOURCE.index("function HUD.updateDirectEditor")
    editor_end = SOURCE.index("function HUD.updateOverlay", editor_start)
    editor = SOURCE[editor_start:editor_end]
    assert 'groupId == "r2" and JokCombatR2Shortcut.active' in editor
    assert "HUD.overlayEligible(buttons, player)" not in editor
    assert "JokCombatR2Shortcut.nextSelectable(current, delta)" in editor

    seed_start = SOURCE.index("function JokCombatR2Shortcut.arm()")
    seed_end = SOURCE.index("function JokCombatR2Shortcut.update", seed_start)
    seed = SOURCE[seed_start:seed_end]
    assert "JokCombatR2Shortcut.needsInitialSeed" in seed
    assert "resetLoadoutToDefaults()" in seed
    assert "saveActionLoadout()" in seed

    sync_start = SOURCE.index("function JokCombatR2Shortcut.syncPage()")
    sync_source = SOURCE[sync_start:arm_start]
    assert "WriteByte(ADDRESS.shortcutControlSelector" not in sync_source
    assert "WriteByte(ADDRESS.l2ControlMap" not in sync_source

    publish_start = SOURCE.index("function JokCombatR2Shortcut.publishJournal()")
    publish_end = SOURCE.index("function JokCombatR2Shortcut.restore", publish_start)
    publish = SOURCE[publish_start:publish_end]
    assert "WriteByte(journal + 0x0E, NORMAL.l2ControlMap)" in publish
    assert (
        "WriteByte(journal + 0x0F, NORMAL.shortcutControlSelector)"
        in publish
    )

    bridge_start = SOURCE.index("JokCombatR2NativeBridge = {")
    bridge_end = SOURCE.index("for index, magic in ipairs", bridge_start)
    bridge = SOURCE[bridge_start:bridge_end]

    def bytes_for(name: str) -> list[int]:
        match = re.search(
            rf"\n    {name} = \{{(.*?)\n    \}},", bridge, re.DOTALL
        )
        assert match is not None, f"missing {name} bridge bytes"
        return [
            int(value, 16)
            for value in re.findall(r"0x([0-9A-Fa-f]{2})", match.group(1))
        ]

    normal = bytes_for("normal")
    owned = bytes_for("owned")
    cave_normal = bytes_for("caveNormal")
    cave_owned = bytes_for("caveOwned")
    assert normal == [0xE8, 0x91, 0x02, 0x00, 0x00]
    assert len(owned) == 5 and owned[0] == 0xE8
    assert cave_normal == [0x00] * 28
    assert len(cave_owned) == 28

    patch_rva = 0x28B19A
    cave_rva = patch_rva + 5 + int.from_bytes(
        bytes(owned[1:5]), "little", signed=True
    )
    assert cave_rva == 0x3ADED8
    assert cave_owned[:7] == [
        0x80, 0x3D, 0xD9, 0x9A, 0xA0, 0x02, 0xC4
    ]
    marker_rva = cave_rva + 7 + int.from_bytes(
        bytes(cave_owned[2:6]), "little", signed=True
    )
    assert marker_rva == 0x2DB79B8
    assert cave_owned[7:23] == [
        0x75, 0x0E,              # inactive journal -> original builder
        0x88, 0xF0, 0x24, 0x0F, # copy DH and isolate shoulder nibble
        0x3C, 0x02, 0x75, 0x06, # accept physical R2 only
        0x80, 0xE6, 0xFD,        # clear R2
        0x80, 0xCE, 0x04,        # set L1
    ]
    assert cave_owned[23] == 0xE9
    edge_builder_rva = cave_rva + 28 + int.from_bytes(
        bytes(cave_owned[24:28]), "little", signed=True
    )
    assert edge_builder_rva == 0x28B430

    pre_normal = bytes_for("preDispatchNormal")
    pre_owned = bytes_for("preDispatchOwned")
    assert len(pre_normal) == len(pre_owned) == 75
    assert "preDispatchAddress = 0x18C870" in bridge

    legacy_normal = bytes_for("legacyNormal")
    legacy_owned = bytes_for("legacyOwned")
    assert len(legacy_normal) == len(legacy_owned) == 56
    assert "legacyAddress = 0x18C87C" in bridge
    assert "JokCombatR2NativeBridge.legacyOwned" in SOURCE
    assert "The two older bridge layouts are recovery-only" in SOURCE

    restore = SOURCE[
        SOURCE.index("function JokCombatR2NativeBridge.restore") :
        SOURCE.index("function JokCombatR2NativeBridge.ensure")
    ]
    ensure = SOURCE[
        SOURCE.index("function JokCombatR2NativeBridge.ensure") :
        SOURCE.index("function JokCombatR2NativeBridge.initialize")
    ]
    assert "JokCombatR2NativeBridge.normal" in restore
    assert restore.index(
        "WriteArray(JokCombatR2NativeBridge.address"
    ) < restore.index(
        "WriteArray(JokCombatR2NativeBridge.caveAddress"
    )
    assert "WriteArray(JokCombatR2NativeBridge.caveAddress" in ensure
    assert "WriteArray(JokCombatR2NativeBridge.address" in ensure
    assert ensure.index(
        "WriteArray(JokCombatR2NativeBridge.caveAddress"
    ) < ensure.index(
        "WriteArray(JokCombatR2NativeBridge.address"
    )
    initialize = SOURCE[
        SOURCE.index("function JokCombatR2NativeBridge.initialize") :
        SOURCE.index("function JokCombatR2Shortcut.validSlotValue")
    ]
    assert 'JokCombatR2NativeBridge.restore("retired bridge recovery", true)' in initialize
    assert 'JokCombatR2NativeBridge.restore("reload recovery", true)' in SOURCE
    assert "r2MagicReady = JokCombatR2NativeBridge.initialize()" in SOURCE

    print("PASS: fourth row and edge-bridged R2 magic page are reversible")


if __name__ == "__main__":
    main()
