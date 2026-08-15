# Architecture

## Main Flows

1. Each runtime module checks the KH1 game ID, Steam Global fingerprint, pointers, and relevant instruction or data signatures before enabling writes.
2. `JokCombat_CombatPrototype.lua` arbitrates physical input, then delegates ordinary attacks, complete Action records, native Limit dispatch, magic, Reaction Commands, defense, and movement back to KH1 wherever possible.
3. Modifier-free `A` remains KH1's normal combo. The number of native `A` attacks before `Y` selects Strong, C2, C3, C4, or C5; accepted `Y` presses execute each named node immediately.
4. Exact `R2` temporarily swaps the three native Shortcut slots to a second learned-magic page. A signed input bridge maps only that physical R2 shoulder edge to KH1's complete L1 Shortcut dispatcher, while raw R2 remains visible for page ownership and editing.
5. Persistent helper modules reconcile native save structures for abilities, AP, and equipment. The drop-rate module owns only two runtime operands.
6. Rising native contact edges during owned `C8-CE` normal animations contribute at most one melee-MP credit per animation; ten credits restore exactly 1 MP while Sora is below the verified native cap.
7. Exit, reload, timeout, menu, state, and fault paths conditionally restore temporary values from signed journals or snapshots.

## Boundaries

- `JokCombat_CombatPrototype.lua`: combat state machine, A/Y families, Action and Limit routing, defense, movement, Command Menu guide, R2 magic page, melee-MP recovery, journals, and runtime recovery.
- `JokCombat_NativeAbilities.lua`: persistent Shared High Jump/Glide/Superglide, exact 4/2/1 combo-passive counts, and maximum AP 99 for Sora, Donald, and Goofy.
- `JokCombat_NativeKeyblades.lua`: persistent unique ownership for 17 non-Ultima Sora Keyblades plus Save the Queen and Save the King.
- `JokCombat_DropRate.lua`: reversible process-local 2.0x item and prize multipliers.
- `JokCombat_StateProbe.lua`, `JokCombat_InputProbe.lua`, `JokCombat_CommandMenuProbe.lua`, and `JokCombat_MPHitProbe.lua`: optional diagnostics, never release dependencies.
- KH1 owns story progression, rewards, chests, synthesis, world flags, Summons, native magic semantics, and internal Limit follow-ups.

## Patterns To Preserve

- Native-first execution: route complete native records or dispatchers rather than imitating animation IDs, VFX, hitboxes, or follow-ups.
- Fail closed: an unsupported build, implausible pointer, unknown value, or signature mismatch disables the affected writer.
- Exact ownership: capture originals before writing, journal temporary state, verify writes, and restore only exact JokCombat-owned values.
- Narrow patches: modify the smallest validated field or instruction and leave unrelated state untouched.
- Physical-edge arbitration: never manufacture an unbounded input backlog; Reaction Commands, menus, magic, and native Limit state retain priority.
- Separate persistent save changes from process-local combat behavior and document both explicitly.

## Important Details

- Grounded high-target attacks bypass KH1's native aerial-candidate branch only while Sora is genuinely grounded; the stock instruction returns after a real jump.
- The ground map has 12 nodes: eight unique Action Abilities and four active native Limits. Trinity Limit is recovery-only because its native sequence owns Donald and Goofy.
- The aerial branch is native Aerial Finisher, Hurricane Blast, then Aerial Sweep; no fake-ground or altitude writes are used.
- Combo Limits temporarily borrow zero MP cost only while their selected combo route is owned. Menu-launched Limits keep vanilla costs.
- Melee MP counts only confirmed native normal hits, never whiffs or specials; full MP clears partial progress so credits cannot be banked before casting.
- Post-special continuation carries logical family depth only after a real native `A`; `comboPosition` is never written.
- Kinetic Step grants one runtime-only second jump per airtime. Native airborne `X` remains Superglide; grounded `X` is Dodge Roll.
- The R2 page stores `R2+Y`, `R2+X`, and `R2+A` in `JokCombat_MagicShortcuts.cfg`; `B` remains jump or Kinetic Step. Defaults are learned spells absent from the current L1 page when possible.
- The R2 editor uses D-pad Up/Down to select and Left/Right to cycle learned spells, saves on release, and temporarily colors the selected spell name gold.

## Integration Points

- Runtime: LuaBackendHook/LuaEngine for KH1 with scripts loaded from the configured `scripts/kh1` directory.
- Local configuration: `JokCombat_MagicShortcuts.cfg`; the legacy `JokCombat_ActionLoadout.cfg` is read only for overlay-preference migration.
- Static verification: seven `tests/test_*.py` scripts.
- Lua harnesses: five `tests/*_test.lua` files; syntax compilation should cover all eight root Lua scripts.
- Packaging: `tools/Build-Release.ps1`, which builds a seven-file archive and SHA-256 checksum under ignored `dist/`.
- Canonical product documentation: `README.md`, `CHANGELOG.md`, `docs/TECHNICAL_DESIGN.md`, `docs/JokCombat_BranchCombo_Mapping.md`, and `docs/ROADMAP.md`.
- Attribution: Critical Mix by Xendra/KSX is an authorized technical inspiration/reference; its code is not distributed in this repository.
