# State

## Track Purpose

Add a modest, deterministic MP reward for confirmed native normal-attack hits.

## Current Status

- M-01, M-02, and M-03 are complete; this track is closed.
- Production recovery is deployed in the live combat script at 1 MP per 10
  confirmed normal hits, with no full-MP banking.
- The feature branch is stacked on the open Kiroku hub PR #31.
- The user confirmed the 1-MP-per-10-hits payout and accepted its live balance.

## Scope

- In scope: Steam Global hit-signal validation, current/max MP validation,
  per-normal-attack crediting, MP cap behavior, balance and edge-case tests.
- Out of scope: MP recovery from Action Abilities, magic, Limits, Guard,
  Counterattack, damage dealt, multi-hit count, or passive ability redesign.

## Recently Verified

- `JokCombat_CombatPrototype.lua` reads Steam Global's connect byte at
  `0x296B230` without clearing it for Guard Counter.
- The existing native Limit recovery code resolves Sora's battle slot as
  `0x2D50000 + slotReference` and reads current MP at `+0x44`.
- The authorized Critical Mix reference uses connect values `0x01` and `0x40`
  for on-hit effects and stores current/max MP at slot offsets `+0x44/+0x48`.
- Candidate native normal animation IDs are `C8,C9,CA,CB,CC,CD,CE`; early
  `C8-CA` IDs can also be reused by Limit contexts with low secondary IDs.
- Static read-only checks, all Python tests, all Lua regression tests, Lua
  compilation, and the strict Kiroku checker passed on 2026-08-15.
- The live capture showed `0x01` edges on connected C8/C9 normals, no edge on
  observed whiffs, `0x40` during Strike Raid and `0x01` during Slapshot outside
  the eligible animation family, plus plausible Sora MP `7/7`.
- The production Lua harness verifies one credit per animation, aerial normals,
  multi-edge suppression, low-secondary exclusion, capped payout, no full-MP
  banking, and credit reset after player-object changes.
- Live gameplay verified the final 10-hit payout after the earlier 5-hit rate
  was judged too generous.

## Open Questions

- None for the completed track.

## Watch Points

- Never infer a hit only from animation acceptance.
- Do not count reused `C8-CA` Limit animations as native normal attacks.
- Do not let a stale nonzero connect byte credit a later attack.
- The main combat script is close to Lua's 200-local top-level limit; keep the
  diagnostic standalone and encapsulate production state when implemented.
