# Start Here

## Mission

- Maintain JokCombat as a native-first combat overhaul for KINGDOM HEARTS FINAL MIX on Steam Global.
- Extend Sora's combat options without taking ownership away from KH1 where the game already supplies complete actions, effects, targeting, and save behavior.

## Current State

- The current code and documentation baseline is `v2.2.1` dated 2026-09-05; publication status is tracked by GitHub releases.
- Normal ground and aerial `A` strings remain native and use Combo Master, four Combo Plus, and two Air Combo Plus.
- Contextual `Y` families expose eight unique Action Abilities and four native Limits; defense, movement, and the aerial family remain separate.
- `R2` now opens a second native three-slot magic page with learned-spell editing and a gold selected row.
- Native abilities, party AP, and weapon grants can persist after KH1 saves; combat routing and drop-rate changes are process-local.
- Steam Global is the only supported executable, and all writers fail closed on invalid signatures or state.
- Party AP 99, the second R2 magic page, 1 MP per 10 confirmed normal hits, standard local deployment, and OpenKH packaging remain part of the release.
- Physical `A` after a named `Y` Action waits for its safe release window through one bounded input, preventing premature cancellation without an attack backlog.
- Nine Python tests, five Lua harnesses, and compilation of all eight root Lua scripts pass with Lua 5.3 for `v2.2.1`; the last full live-tested baseline remains `v2.2.0`.
- OpenKH is the recommended installation path; direct LuaBackend deployment remains supported for development and fallback use.

## Next Action

- Verify GitHub release and PR state before the next publishing operation; start further combat work only from an explicitly selected issue.

## Hard Constraints

- Never write on an unknown executable, failed fingerprint, invalid pointer, or mismatched instruction/action signature.
- Preserve KH1 ownership of ordinary attacks, magic casts, Reaction Commands, Limit follow-ups, story progression, and rewards.
- Restore temporary patches only when memory still contains JokCombat's exact owned value.
- Never grant or modify Ultima Weapon, synthesis state, story flags, chests, or Summons.
- Do not reintroduce fake-ground airborne Actions, animation-only routing, artificial normal-attack queues, or direct combo-counter writes.
- Warn users to back up saves because native ability, AP, and equipment grants are persistent.
- Do not run another combat overhaul against the same input, action, command, ability, or Reaction structures.

## Read Only If Needed

- `STATE.md` and `WORK.md` for verified status, open questions, and the release backlog.
- `ARCHITECTURE.md` for module ownership and runtime flows.
- `DECISIONS.md` and `CONSTRAINTS.md` before changing combat or progression rules.
- `IDEAS.md`, `RISKS.md`, and `LOG.md` for deferred directions, fragile areas, or update history.
