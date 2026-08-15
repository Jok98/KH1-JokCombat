# Risks

## Open Risks

### Risk: Runtime and release documentation have diverged

Condition:
`main` implements a native R2 magic page, but README and the v2.1 technical design still document the retired R2 Action Ability page; the changelog records only the party-AP post-tag change.

Impact:
Users may install or operate the feature incorrectly, and the next release could be packaged with misleading controls and upgrade guidance even while metadata tests pass.

Mitigation:
Complete the documentation-reconciliation task before choosing or publishing the next version, and add assertions for the new controls and configuration filename.

### Risk: Fixed executable addresses drift

Condition:
Steam updates, regional builds, or Epic executables may move code, pointers, save structures, action records, and code caves.

Impact:
Unchecked writes can corrupt state or crash the game.

Mitigation:
Keep build profiles explicit, verify complete signatures and pointer ranges, disable only the affected subsystem on mismatch, and repeat live validation per executable.

### Risk: Persistent grants alter saves

Condition:
KH1 saves after Native Abilities or Native Keyblades reconciles records.

Impact:
Removing JokCombat does not automatically restore prior AP, abilities, or equipment ownership.

Mitigation:
Require backups, document exact persistent fields, preserve unrelated records, and never write Ultima or progression flags.

### Risk: R2 native shortcut bridge conflicts with input or rendering state

Condition:
The signed call-site/cave bridge, temporary slot swap, journal, or selected-row color helper encounters an unexpected menu transition, reload, or external patch.

Impact:
R2 may show the wrong page, duplicate L1 spells, fail to cast, retain modified slots/colors, or interfere with other input.

Mitigation:
Require exact stock/owned signatures, resolve native storage dynamically, journal before slot changes, restore conditionally on every exit path, and test L1/R2/menu/F1 transitions live.

### Risk: Input ownership leaves Sora stuck or consumes interactions

Condition:
Branch, defense, depth-carry, Shortcut, Reaction, or native Limit state handles the same physical edge out of order.

Impact:
Attacks can stop, Talk/Save confirmation can need extra presses, or a Limit can leave an orphaned immobile state.

Mitigation:
Preserve native priority, use bounded one-edge latches, release ownership on state changes, and stop all JokCombat interception during active native Limits.

### Risk: Lua top-level local limit

Condition:
More top-level locals are added to the large combat script.

Impact:
Lua initialization aborts with the 200-local-variable compile error.

Mitigation:
Group subsystem state in deliberate global tables or refactor bounded code without weakening ownership boundaries; compile every root Lua script before merge.

## Accepted Risks

- Full KH1 runtime behavior cannot be automated; releases depend on a documented user-run live test matrix in addition to static checks.
- Native save mutations are intentional and accepted when the user has a backup and the writes stay within the documented records.

## Closed Risks

- Ground attacks following airborne targets was closed by the signature-checked grounded candidate-branch bypass in v2.1.0.
- Animation-only Action routing was closed by copying and validating complete native action records.
- Ground Dodge stealing airborne Superglide was closed by leaving airborne `X` entirely native.
