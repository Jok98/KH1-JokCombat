# KH1 JokCombat

**Version 2.2.0**

JokCombat is a combat overhaul for **KINGDOM HEARTS FINAL MIX** on the Steam
Global release. It keeps KH1's native attacks at the center of combat, then
adds contextual `A`/`Y` combo families, a second native magic Shortcut page,
an extended ground-to-air cycle, universal defense, and faster progression.

## Highlights

- Native ground and aerial `A` combos with Combo Master, four Combo Plus, two
  Air Combo Plus, and an infinite post-finisher restart while Sora remains in
  the same ground or aerial state.
- Five role-based `Y` branches containing eight Action Abilities and four
  native Limits, with no duplicated special move. Trinity Limit is excluded
  because its native sequence requires Donald and Goofy.
- Post-special depth continuation: after a terminal move, one real native `A`
  can advance into the following ground family; C5 remains the endpoint.
- Five direct ground families and a separate three-step aerial branch
  available after any normal aerial hit.
- Ground attacks never auto-chase an airborne target: a normal jump or Kinetic
  Step is required before the explicit aerial family becomes available.
- A second native three-slot magic Shortcut page on `R2`, independently
  editable from learned spells and executed by KH1's complete magic dispatcher.
- One MP restored after every ten confirmed native normal hits; whiffs and
  special moves never contribute.
- Universal Guard on `L2 + B`, ground Dodge Roll on `X`, and Counterattack
  after a successful Guard.
- High Jump, a once-per-airtime Kinetic Step second jump, native Superglide on
  held airborne `X`, and reduced descent during free fall and aerial attacks.
- All 17 genuine Keyblades except Ultima Weapon available through KH1's native
  Equipment menu; Ultima remains obtainable only through normal synthesis.
- Save the Queen for Donald and Save the King for Goofy available through
  their native Equipment menus.
- Fixed `200%` item and prize drop multipliers.

Normal magic shortcuts, Reaction Commands, story progression, rewards,
chests, synthesis, world flags, and Summons remain under vanilla KH1 control.
The Keyblade module modifies only the explicitly listed unique-weapon ownership
counts; it does not alter their story, reward, or synthesis flags.

## Controls

The documentation uses Xbox-style face-button labels:

| Input | Function |
|---|---|
| `A` | Native KH1 attack and normal combo continuation |
| `Y` | Contextual JokCombat branch based on the preceding `A` count |
| `B` | Native jump; release and press again for Kinetic Step |
| `X` | Dodge Roll while grounded; hold for native Superglide while airborne |
| `L2 + B` | Universal Guard |
| `L1 + Y/X/A` | KH1's original three magic shortcuts |
| `R2 + Y/X/A` | Cast the spell assigned to JokCombat's second magic page |
| Hold `R2`, then D-pad | Select a slot with Up/Down and cycle learned spells with Left/Right |
| Release `R2` | Save the second magic page automatically |
| Release `L1 + R1 + L2 + R2` | Toggle the Command Menu overlay and Combo Guide |

Magic and Reaction Commands keep priority over JokCombat inputs. A neutral `Y`
is left native through a two-frame release check before Strong opens, so Talk,
Examine, Save, and the following `A` confirmation are not captured by the combo
controller. Native magic shortcuts such as `L1 + X` do not trigger Dodge Roll.

High Jump keeps its native variable height: hold the first `B` for the full
ascent, release it, and press it again for Kinetic Step. Superglide already has
a separate native command in KH1, so hold `X` while airborne after either jump.
JokCombat never forces Dodge Roll while Sora is airborne.

The complete ground, aerial, and Limit routes are documented in
[the combo map](docs/JokCombat_BranchCombo_Mapping.md).

## Requirements

- KINGDOM HEARTS HD 1.5+2.5 ReMIX on Steam, Global executable.
- For the recommended installation: OpenKH Mod Manager with Panacea and
  LuaBackend configured for KH1.
- For direct installation: a working LuaBackendHook/LuaEngine installation
  for KH1.
- A controller layout compatible with KH1's standard face-button mapping.

Other regional builds and the Epic Games Store executable are not supported.

## Installation

Back up your KH1 save before using either installation method.

### OpenKH Mod Manager (recommended)

1. Open `OpenKh.Tools.ModsManager.exe`, select **PC Release**, **Steam**, and
   **Kingdom Hearts 1**. Complete OpenKH's setup wizard for both Panacea and
   LuaBackend if they are not already installed.
2. Add JokCombat using either source:

   - GitHub: enter `Jok98/KH1-JokCombat` in **Install a new mod from GitHub**.
   - Release: choose **Select and install Mod Archive or Lua Script**, then
     select `KH1-JokCombat-vX.Y.Z-OpenKH.zip`.

3. Enable JokCombat in the KH1 mod list, then choose **Mod Loader > Build and
   Run**. OpenKH stages all four runtime modules automatically; no individual
   file copy is required.
4. A successful load reports `JokCombat v2.2.0`, Native Abilities, Native
   Keyblades, and the `200%` Drop Rate module in the LuaBackend console.

OpenKH installation uses the root [`mod.yml`](mod.yml), which deliberately
contains only the four required runtime modules. The optional developer probes
are not installed.

### Direct LuaBackend installation

1. Configure the KH1 entry in `LuaBackend.toml` to use LuaBackend's standard
   Steam Documents path:

   ```toml
   [kh1]
   scripts = [{ path = "scripts/kh1/", relative = true }]
   exe = "KINGDOM HEARTS FINAL MIX.exe"
   game_docs = "My Games/KINGDOM HEARTS HD 1.5+2.5 ReMIX"
   ```

   This resolves to:

   ```text
   C:\Users\<you>\Documents\My Games\KINGDOM HEARTS HD 1.5+2.5 ReMIX\scripts\kh1
   ```

2. Copy these release files into that directory:

   ```text
   JokCombat_CombatPrototype.lua
   JokCombat_NativeAbilities.lua
   JokCombat_NativeKeyblades.lua
   JokCombat_DropRate.lua
   ```

   From a source checkout or an extracted release, the same runtime-only
   deployment can be performed automatically from PowerShell:

   ```powershell
   .\tools\Deploy-Local.ps1
   ```

   Add `-IncludeDiagnostics` only when the four optional probes are needed.
   The deploy script verifies every copied file with SHA-256 and never removes
   unrelated files from the destination.

3. Start KH1 or press `F1` in the LuaBackend console to reload all scripts.
   A successful load reports `JokCombat v2.2.0`, Native Abilities, Native
   Keyblades, and the `200%` Drop Rate module.

The four probe scripts in this repository are optional developer diagnostics
and are not required for normal play.

## Upgrading

Back up the save. OpenKH users can update the GitHub installation or import the
new `-OpenKH.zip`, re-enable JokCombat, and rebuild the KH1 mod list. Direct
LuaBackend users can run `tools/Deploy-Local.ps1` from a source checkout or
extracted release, or replace the old runtime files with all four files listed
above. Users upgrading directly from 1.0.0 must also copy
`JokCombat_NativeKeyblades.lua`, introduced in 2.0.0.
`JokCombat_MagicShortcuts.cfg` is created automatically for the new R2 page.
When it is first created, JokCombat may read only the overlay preference from
the retired `JokCombat_ActionLoadout.cfg`; old Action assignments are never
imported. Native abilities and equipment granted by the mod can persist after
KH1 saves, so removing the scripts does not automatically undo those save-file
changes. See the [changelog](CHANGELOG.md) for the complete release history.

## Save-file changes

`JokCombat_NativeAbilities.lua` grants native High Jump, Glide, and Superglide
through KH1's Shared ability list, equips four Combo Plus, two Air Combo Plus,
and Combo Master in Sora's ability list, and sets the maximum AP of Sora,
Donald, and Goofy to `99` each.
`JokCombat_NativeKeyblades.lua` adds exactly one total copy of every genuine
Sora Keyblade except Ultima Weapon. It does not grant the Dream weapons or
Wooden Sword. The same module grants Save the Queen to Donald and Save the King
to Goofy. It never writes Ultima's inventory record, synthesis state, or any
currently equipped weapon. These changes become part of the save after KH1
saves normally. R2 spell assignments persist only in
`JokCombat_MagicShortcuts.cfg`; combat routing, the second jump, descent
tuning, partial melee-MP progress, Limit cost borrowing, and the drop-rate
patch are process-only.

## Compatibility and known limits

- Steam Global is the only validated build.
- Do not load another combat overhaul that patches the same KH1 action,
  command, input, or ability structures.
- Combo magic and Summons are intentionally excluded from JokCombat branches.
- When KH1 exposes locked Summon as an existing fourth placeholder row,
  JokCombat temporarily borrows a normal command record so the fourth Combo
  Guide row remains visible. The native row is restored as soon as the Guide
  closes.
- Perfect Guard and a dedicated enemy-launcher system are not part of v2.2.0.

## Documentation

- [Technical design and implementation decisions](docs/TECHNICAL_DESIGN.md)
- [Current combo map](docs/JokCombat_BranchCombo_Mapping.md)
- [Changelog](CHANGELOG.md)
- [Roadmap](docs/ROADMAP.md)
- [Archived development history](docs/DEVELOPMENT_HISTORY.md)
- [Critical Mix reference analysis](docs/CMix_AnimCancel_AbilityHandler_analysis.md)

## Credits

Created by Jok. JokCombat is inspired by Critical Mix by Xendra/KSX. Critical
Mix's scripts and combat concepts were studied while JokCombat was independently
developed and validated for the Steam Global release.

## License

JokCombat's original source code and documentation are released under the
[MIT License](LICENSE). KINGDOM HEARTS and its associated names, characters,
and assets remain the property of their respective rights holders. Critical
Mix is not included in this repository and is not covered by JokCombat's
license.
