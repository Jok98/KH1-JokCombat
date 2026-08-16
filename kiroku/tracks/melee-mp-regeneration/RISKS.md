# Risks

## Open Risks

- None.

## Accepted Risks

- Fractional credit resets when scripts reload or the process closes; this is
  intentional because it avoids save-format changes for at most 0.9 MP loss.

## Closed Risks

### Risk: Sticky or overloaded connect signal

Condition:
`connectCounter` can encode non-normal contacts and may expose untested blocked,
invulnerable, or multi-target behavior.

Impact:
The feature could grant MP for a miss or duplicate rewards.

Mitigation:
Require a rising `0x01/0x40` edge inside an owned C8-CE animation and accept at
most one edge per animation; focused simulation and live gameplay validated the
bounded behavior used by the shipped controller.

### Risk: Incorrect max-MP field

Condition:
Battle-slot `+0x48` may not be the active Sora MP cap in every gameplay state.

Impact:
An eventual write could overfill MP or use unrelated memory.

Mitigation:
Validate slot reference, current/max ordering and max range before every write;
cap by `+0x48`, verify the result immediately, and disable on failure.

### Risk: Animation ID reuse

Condition:
Limit contexts can reuse normal-looking `C8-CA` animation IDs.

Impact:
Limits could incorrectly earn melee MP credit.

Mitigation:
Capture secondary IDs and context; preserve the existing low-secondary Limit
exclusion when live evidence supports it.
