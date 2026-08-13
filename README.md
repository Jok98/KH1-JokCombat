# KH1 JokCombat

**Version 1.0.0**

JokCombat is a combat overhaul for **KINGDOM HEARTS FINAL MIX** on the Steam
Global release. It keeps KH1's native attacks at the center of combat, then
adds contextual `A`/`Y` combo families, configurable Action Ability shortcuts,
an extended ground-to-air cycle, universal defense, and faster progression.

## Highlights

- Native ground and aerial `A` combos with Combo Master, four Combo Plus, two
  Air Combo Plus, and an infinite post-finisher restart while Sora remains in
  the same ground or aerial state.
- Five role-based `Y` branches containing eight Action Abilities and all five
  native Limits, with no duplicated special move.
- Five direct ground families and a separate three-step aerial branch
  available after any normal aerial hit.
- One configurable `R2` Action Ability group, shown and edited through KH1's
  own Command Menu.
- Universal Guard on `L2 + B`, ground Dodge Roll on `X`, and Counterattack
  after a successful Guard.
- High Jump, a once-per-airtime Kinetic Step second jump, native Superglide on
  held airborne `X`, and reduced descent during free fall and aerial attacks.
- Fixed `200%` item and prize drop multipliers.

Normal magic shortcuts, Reaction Commands, story progression, rewards,
chests, synthesis, inventory, world flags, and Summons remain under vanilla
KH1 control.

## Controls

The documentation uses Xbox-style face-button labels:

| Input | Function |
|---|---|
| `A` | Native KH1 attack and normal combo continuation |
| `Y` | Contextual JokCombat branch based on the preceding `A` count |
| `B` | Native jump; release and press again for Kinetic Step |
| `X` | Dodge Roll while grounded; hold for native Superglide while airborne |
| `L2 + B` | Universal Guard |
| `R2 + A/Y/X/B` | Configured Action Ability |
| Hold `R2`, then D-pad | Select a slot with Up/Down and change its ability with Left/Right |
| Release `R2` | Save the Action Ability loadout automatically |
| Release `L1 + R1 + L2 + R2` | Toggle the Command Menu overlay and Combo Guide |

Magic and Reaction Commands keep priority over JokCombat inputs. A neutral `Y`
is left native through a two-frame release check before Strong opens, so Talk,
Examine, Save, and the following `A` confirmation are not captured by the combo
controller. Native magic shortcuts such as `R1 + X` do not trigger Dodge Roll.

High Jump keeps its native variable height: hold the first `B` for the full
ascent, release it, and press it again for Kinetic Step. Superglide already has
a separate native command in KH1, so hold `X` while airborne after either jump.
JokCombat never forces Dodge Roll while Sora is airborne.

The complete ground, aerial, and Limit routes are documented in
[the combo map](docs/JokCombat_BranchCombo_Mapping.md).

## Requirements

- KINGDOM HEARTS HD 1.5+2.5 ReMIX on Steam, Global executable.
- A working LuaBackendHook/LuaEngine installation for KH1.
- A controller layout compatible with KH1's standard face-button mapping.

Other regional builds and the Epic Games Store executable are not supported.

## Installation

1. Back up your KH1 save.
2. Create a clean script directory, for example:

   ```text
   C:\Users\<you>\Documents\KH_mod\scripts\kh1
   ```

3. Copy these release files into that directory:

   ```text
   JokCombat_CombatPrototype.lua
   JokCombat_NativeAbilities.lua
   JokCombat_DropRate.lua
   ```

4. Point the KH1 entry in `LuaBackend.toml` to that directory:

   ```toml
   [kh1]
   scripts = [
       { path = "C:\\Users\\<you>\\Documents\\KH_mod\\scripts\\kh1", relative = false }
   ]
   ```

5. Start KH1 or press `F1` in the LuaBackend console to reload all scripts.
   A successful load reports `JokCombat v1.0.0`, Native Abilities, and the
   `200%` Drop Rate module.

The three probe scripts in this repository are optional developer diagnostics
and are not required for normal play.

## Save-file changes

`JokCombat_NativeAbilities.lua` grants native High Jump, Glide, and Superglide
through KH1's Shared ability list, equips four Combo Plus, two Air Combo Plus,
and Combo Master in Sora's ability list, and sets Sora's maximum AP to `99`.
These changes become part of the save after KH1 saves normally. The combat
controller's ground-Dodge/air-Superglide ownership rule, Action Ability
loadout, second jump, descent tuning, Limit cost borrowing, and drop-rate patch
are runtime-only.

## Compatibility and known limits

- Steam Global is the only validated build.
- Do not load another combat overhaul that patches the same KH1 action,
  command, input, or ability structures.
- Combo magic and Summons are intentionally excluded from JokCombat branches.
- When KH1 exposes locked Summon as an existing fourth placeholder row,
  JokCombat temporarily borrows a normal command record so all four `R2`
  Action assignments remain visible and editable. The native row is restored
  as soon as the overlay closes.
- Perfect Guard and an enemy-launcher system are not part of v1.0.0.

## Documentation

- [Technical design and implementation decisions](docs/TECHNICAL_DESIGN.md)
- [Current combo map](docs/JokCombat_BranchCombo_Mapping.md)
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
