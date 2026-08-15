# Work

## Ongoing

- No combat implementation is currently in progress; `main` contains merged post-`v2.1.0` changes awaiting release reconciliation.

## TODO

### Task: Reconcile documentation with the R2 magic page

Status: todo
Completion:
README, changelog, technical design, roadmap terminology, controls, configuration filename, persistence table, known limits, and validation text all describe the native three-slot R2 magic page and no current document presents the retired Action Ability page as active.

Notes:
- Preserve historical R2 Action details only in archived development history.
- Include the selected-row gold highlight and learned-spell/default behavior.

### Task: Prepare the next release

Status: todo
Completion:
A version is chosen, all version metadata and dates agree, static and Lua tests pass, the complete live-game regression matrix passes, the release archive/checksum are rebuilt, and the GitHub release is published.

Notes:
- Include Donald and Goofy AP 99 plus the R2 second magic page in release notes.
- Recheck upgrade guidance from `JokCombat_ActionLoadout.cfg` to `JokCombat_MagicShortcuts.cfg`.

### Task: Add Epic Games Store support

Status: todo
Completion:
One exact Epic executable has an independently validated build profile, every owned address/signature and recovery path is ported, unknown builds remain fail-closed, and the full Steam-equivalent gameplay/save/reload test matrix passes.

Notes:
- Keep one shared gameplay implementation; do not create separate behavior forks.

### Task: Research optional Solo Sora mode

Status: todo
Completion:
The runtime party actor/AI contract is mapped, scripted-party suspension and conditional restoration are proven, and a decision is recorded to implement or reject the optional mode.

Notes:
- The mode must remain disabled by default and must not persistently overwrite the saved party lineup.

## Blocked

- Epic support is blocked until an exact target executable is selected and available for mapping and live testing.
- Solo Sora mode is blocked on validated battle-actor, guest-party, cutscene, and restoration state.

## Done

- `v2.1.0` shipped the rebuilt five-family A/Y map, native Limit latching, depth continuation, and intentional-only ground-to-air entry.
- Post-tag work merged AP 99 for the full party and the functional native R2 magic page with selected-row highlighting.
- The project-level Kiroku hub was initialized from repository and test evidence on 2026-08-15.

## Cancelled

- Combo magic was cancelled because the adapter could not execute KH1's complete native cast path.
- Fake-ground airborne Action routing was cancelled because it could not preserve authored movement, effects, damage, and input control.
