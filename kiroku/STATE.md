# State

## Project Purpose

JokCombat is a LuaBackendHook combat overhaul for KINGDOM HEARTS FINAL MIX. It keeps KH1's native combat machinery authoritative while adding contextual Musou-style branches, movement and defense options, progression grants, and reversible runtime patches.

## Current Status

- Repository baseline inspected on `main` at `a6ef687`; current feature work is stacked on the Kiroku initialization branch.
- The latest tagged release is `v2.1.0` from 2026-08-14.
- Three post-tag changes are merged: Donald and Goofy maximum AP set to 99, a second native magic shortcut page on `R2`, and gold highlighting for its selected row.
- Confirmed native normal attacks now restore 1 MP after every 10 eligible hits, at most once per attack animation, with no charge banking at full MP.
- The release runtime payload consists of `JokCombat_CombatPrototype.lua`, `JokCombat_NativeAbilities.lua`, `JokCombat_NativeKeyblades.lua`, and `JokCombat_DropRate.lua`; four probe scripts remain optional diagnostics.
- Local deployment now targets LuaBackend's standard Steam Documents
  `scripts/kh1` directory and verifies the four runtime copies with SHA-256;
  release archives include the deployment helper.
- Gameplay scope is Steam Global only. Epic support and optional Solo Sora mode remain future work.
- The first track, `melee-mp-regeneration`, is closed after successful live validation.

## Recently Verified

- On 2026-08-15 all seven Python static tests passed, including focused melee-MP and read-only probe checks.
- All eight root Lua scripts compiled through Lua 5.4/Lupa.
- All five Lua regression harnesses passed, including MP payout and hit-probe simulations.
- The user previously confirmed the R2 second page, distinct spells, and selected-row highlight in live gameplay before merge.
- The user confirmed the final 1-MP-per-10-hits payout and balance in live Steam Global gameplay.
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
