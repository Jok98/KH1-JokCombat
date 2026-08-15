# Ideas

## Open Ideas

- Add Epic Games Store support through an explicit independently mapped build profile while sharing the combat implementation.
- Research an optional Solo Sora challenge mode that suspends ally actors without changing the saved party lineup.
- Reassess Perfect Guard or a dedicated launcher only after the current release state is documented and stable.

## Deferred Ideas

- Support later KINGDOM HEARTS games in separate repositories after the KH1 playthrough and mod are considered complete.
- Add a track layer to this Kiroku hub only when two or more independent non-trivial workstreams need separate continuation state.

## Rejected Ideas

### Rejected: Cast magic directly from A/Y combo branches

Reason:
The tested adapter could start incomplete behavior but did not reliably reproduce KH1's native spell tier, MP, targeting, animation, VFX, and effect path.

Keep in mind:
Reconsider only if the complete native cast dispatcher is mapped without stealing normal shortcuts or menu ownership.

### Rejected: Execute ground-only Actions through fake airborne state

Reason:
Fake-ground routing produced incomplete or incorrect vertical movement, effects, hitboxes, damage, and stick control.

Keep in mind:
Only add an airborne move when KH1 has a validated native airborne-compatible record and state transition.

### Rejected: Put Trinity Limit in the contextual combo map

Reason:
Its native sequence owns Donald and Goofy and conflicts with Sora-only branch ownership.

Keep in mind:
It remains available through vanilla KH1 behavior and may keep recovery metadata solely for stale-journal restoration.

### Rejected: Maintain a configurable R2 Action Ability page

Reason:
The A/Y families already expose the Action repertoire, making a second Action interface redundant; R2 now provides a distinct native magic page instead.

Keep in mind:
Historical implementation details belong only in development history.

### Rejected: Force Glide or Superglide onto the jump button

Reason:
Reusing held `B` broke native variable-height High Jump and conflicted with the Kinetic Step edge.

Keep in mind:
Airborne `X` remains KH1's native Superglide command.

## Forbidden Ideas

- Best-effort writes after build, pointer, action-record, or instruction-signature validation fails.
- Progression edits that grant Ultima Weapon, change synthesis, or alter story/reward flags.
- Unbounded input queues or forced repeated presses that replay spam after recovery.
