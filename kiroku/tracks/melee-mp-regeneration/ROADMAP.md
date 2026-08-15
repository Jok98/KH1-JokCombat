# Roadmap

## Milestones

### M-01: Validate the native hit and MP signals

Status: completed

Objective:
Identify a reliable, read-only Steam Global signal for one confirmed native
normal attack and verify Sora's current/max MP fields.

Scope:
- Build a standalone read-only Lua probe.
- Capture normal hit, whiff, multi-target, special-action, Limit, and MP-change
  observations without altering game memory.

Expected artifacts:
- `JokCombat_MPHitProbe.lua`
- `tests/test_mp_hit_probe.py`
- User-provided live gameplay log

Dependencies:
- Supported Steam Global executable and a valid live Sora player object.

Validation:
- Static read-only test, full Python test suite, Lua compilation, then a live
  controlled capture containing both hits and whiffs.

Completion criteria:
- Logs distinguish one confirmed normal attack from a whiff and exclude special
  actions; current/max MP values match the in-game gauge before implementation.

Risks:
- `connectCounter` may be sticky or encode outcomes other than a clean hit.

### M-02: Implement capped MP regeneration

Status: completed

Objective:
Grant 1 MP after every 10 eligible confirmed normal attacks.

Scope:
- Add process-local fractional credit and a guarded current-MP write.
- Count at most once per native normal attack animation.

Expected artifacts:
- Production Lua implementation and focused static tests.

Dependencies:
- M-01 completed with a reliable hit signal and verified MP fields.

Validation:
- Static signature and ownership checks, full Python tests, Lua compilation.

Completion criteria:
- Code rewards only eligible hits, caps at max MP, and leaves unsupported or
  ambiguous states untouched.

Risks:
- Stale signals, duplicate rewards, or writes to an invalid battle slot.

### M-03: Validate behavior and balance live

Status: completed

Objective:
Confirm the feature is stable and the 1-per-10 rate feels useful without making
magic or Limits effectively free.

Scope:
- Test ground/air strings, finishers, misses, multi-target hits, blocks,
  invulnerable enemies, magic/Limit use, MP cap, death, rooms, menus, and F1.

Expected artifacts:
- Live validation log and any required balance/config adjustment.

Dependencies:
- M-02 completed.

Validation:
- User gameplay test covering the defined matrix.

Completion criteria:
- No false rewards or state corruption are observed and the user accepts the
  final recovery rate.

Risks:
- Encounter density and Combo Plus counts may make the provisional rate too
  generous or too weak.
