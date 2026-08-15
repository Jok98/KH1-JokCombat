# Start Here

## Mission

- Maintain JokCombat as a native-first combat overhaul for KINGDOM HEARTS FINAL MIX on Steam Global.
- Extend Sora's combat options without taking ownership away from KH1 where the game already supplies complete actions, effects, targeting, and save behavior.

## Current State

- The latest public release is `v2.1.0`; `main` also contains unreleased party-AP and R2-magic changes.
- Normal ground and aerial `A` strings remain native and use Combo Master, four Combo Plus, and two Air Combo Plus.
- Contextual `Y` families expose eight unique Action Abilities and four native Limits; defense, movement, and the aerial family remain separate.
- `R2` now opens a second native three-slot magic page with learned-spell editing and a gold selected row.
- Native abilities, party AP, and weapon grants can persist after KH1 saves; combat routing and drop-rate changes are process-local.
- Steam Global is the only supported executable, and all writers fail closed on invalid signatures or state.
- Static tests, three Lua harnesses, and compilation of all seven Lua scripts passed on the inspected `main` baseline.
- Canonical release documentation still describes the retired R2 Action Ability page and must be reconciled before the next release.

## Next Action

- Update README, changelog, technical design, roadmap wording, and release metadata for the second R2 magic page and party AP changes.
- Decide the next version, repeat static and Lua validation, perform the live-game regression matrix, then build and publish the release archive.

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
- `IDEAS.md` and `RISKS.md` for deferred directions and fragile areas.
- `LOG.md` only when memory-update history matters.
