# State

## Project Purpose

JokCombat is a LuaBackendHook combat overhaul for KINGDOM HEARTS FINAL MIX. It keeps KH1's native combat machinery authoritative while adding contextual Musou-style branches, movement and defense options, progression grants, and reversible runtime patches.

## Current Status

- Repository baseline inspected on `main` at `a6ef687`; the only workspace addition from initialization is this `kiroku/` hub.
- The latest tagged release is `v2.1.0` from 2026-08-14.
- Three post-tag changes are merged: Donald and Goofy maximum AP set to 99, a second native magic shortcut page on `R2`, and gold highlighting for its selected row.
- The release bundle still consists of `JokCombat_CombatPrototype.lua`, `JokCombat_NativeAbilities.lua`, `JokCombat_NativeKeyblades.lua`, and `JokCombat_DropRate.lua`; three probe scripts remain optional diagnostics.
- Gameplay scope is Steam Global only. Epic support and optional Solo Sora mode remain future work.
- No track layer exists because current project work is global rather than split into independent active workstreams.

## Recently Verified

- On 2026-08-15 all five Python static tests passed, including the reversible R2 edge bridge and highlight checks.
- All seven root Lua scripts compiled through Lua 5.4/Lupa.
- The Native Abilities, Native Keyblades, and State Probe Lua harnesses passed.
- The user previously confirmed the R2 second page, distinct spells, and selected-row highlight in live gameplay before merge.
- `README.md` and `docs/TECHNICAL_DESIGN.md` still describe the replaced R2 Action Ability loadout, while the runtime and `tests/test_fourth_command_row.py` implement a three-slot native magic page.

## Open Questions

- Which version should contain the post-`v2.1.0` R2 magic and party-AP changes?
- Should `JokCombat_MagicShortcuts.cfg` retain its current migration from the legacy overlay preference indefinitely or only for one release?
- Which exact Epic Games Store executable should become the first supported Epic profile?
- Is optional Solo Sora mode feasible without breaking scripted party ownership?

## Watch Points

- Passing release-metadata tests currently proves `v2.1.0` consistency, not that post-tag behavior is fully documented.
- Live game validation remains necessary for input arbitration, native Limit recovery, menu transitions, and code-cave patches.
- The main Lua chunk is close to Lua's 200-local limit; new subsystem state should avoid adding many top-level locals.
- Fixed Steam addresses and code signatures must be revalidated after any executable update.
