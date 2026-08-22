# State

## Project Purpose

JokCombat is a LuaBackendHook combat overhaul for KINGDOM HEARTS FINAL MIX. It keeps KH1's native combat machinery authoritative while adding contextual Musou-style branches, movement and defense options, progression grants, and reversible runtime patches.

## Current Status

- The current release baseline is `v2.2.0` from 2026-08-16.
- Donald and Goofy maximum AP are 99, matching Sora.
- Exact `R2` opens a second native three-slot magic Shortcut page with learned-spell editing, automatic saving, and gold highlighting for its selected row.
- Confirmed native normal attacks now restore 1 MP after every 10 eligible hits, at most once per attack animation, with no charge banking at full MP.
- A post-`v2.2.0` branch fix now holds one physical `A` edge until the current named Action reaches its safe release window; repeated inputs do not form a queue, and state/menu interruptions clear the pending edge.
- The release runtime payload consists of `JokCombat_CombatPrototype.lua`, `JokCombat_NativeAbilities.lua`, `JokCombat_NativeKeyblades.lua`, and `JokCombat_DropRate.lua`; four probe scripts remain optional diagnostics.
- Local deployment now targets LuaBackend's standard Steam Documents
  `scripts/kh1` directory and verifies the four runtime copies with SHA-256;
  release archives include the deployment helper.
- OpenKH is now the recommended player-facing installation: the repository has
  a KH1-only root manifest and release builds also emit a five-file OpenKH ZIP.
- Gameplay scope is Steam Global only. Epic support and optional Solo Sora mode remain future work.
- The first track, `melee-mp-regeneration`, is closed after successful live validation.

## Recently Verified

- On 2026-08-16 the OpenKH manifest parsed with OpenKH's bundled YamlDotNet,
  all nine Python tests and all five Lua harnesses passed, all eight root Lua
  scripts compiled, and the dedicated archive contained exactly the five
  expected root files.
- On 2026-08-15 all seven Python static tests passed, including focused melee-MP and read-only probe checks.
- All eight root Lua scripts compiled through Lua 5.4/Lupa.
- All five Lua regression harnesses passed, including MP payout and hit-probe simulations.
- The user previously confirmed the R2 second page, distinct spells, and selected-row highlight in live gameplay before merge.
- The user confirmed the final 1-MP-per-10-hits payout and balance in live Steam Global gameplay.
- The safe physical-continuation implementation passes all nine Python tests, and its staged OpenKH runtime copy matches the repository source by SHA-256.
- Canonical documentation, release metadata, controls, persistence rules, and packaging now agree on the `v2.2.0` runtime.

## Open Questions

- Should `JokCombat_MagicShortcuts.cfg` retain its current migration from the legacy overlay preference indefinitely or only for one release?
- Which exact Epic Games Store executable should become the first supported Epic profile?
- Is optional Solo Sora mode feasible without breaking scripted party ownership?

## Watch Points

- Passing release-metadata tests proves `v2.2.0` file and package consistency, but live game validation remains authoritative for runtime behavior.
- Live game validation remains necessary for input arbitration, native Limit recovery, menu transitions, and code-cave patches.
- The main Lua chunk is close to Lua's 200-local limit; new subsystem state should avoid adding many top-level locals.
- Fixed Steam addresses and code signatures must be revalidated after any executable update.
