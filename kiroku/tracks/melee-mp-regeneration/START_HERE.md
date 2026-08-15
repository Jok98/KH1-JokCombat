# Start Here

## Mission

- Recover MP at a restrained rate from confirmed native normal A hits only.
- Keep the implementation native-first and fail closed on ambiguity.

## Current State

- The live capture validated rising contact edges for normal hits and excluded
  Strike Raid/Slapshot contacts outside the native `C8-CE` family.
- Production recovery is deployed: 1 MP per 10 confirmed native normal hits,
  capped at `+0x48`, with no charge banking at full MP.
- Static, simulated, and live Steam Global validation pass; the user accepted
  the final payout and balance.

## Next Action

- None. Reopen only for a confirmed balance or hit-classification regression.

## Hard Constraints

- Steam Global only; fingerprint and pointer checks are mandatory.
- Eligible candidates are native normals `C8-CE`, at most once per animation.
- Never clear/force the connect byte; preserve native A and existing Y/Limit.
- Eventual MP writes must cap at verified native max MP and fail closed.

## Read Only If Needed

- `STATE.md`, `ROADMAP.md`, and `WORK.md` for current execution context.
- `DECISIONS.md` and `RISKS.md` for local choices and fragile assumptions.
- Top-level `CONSTRAINTS.md` and `ARCHITECTURE.md` only for shared rules.
