# Work

## Ongoing

- The post-`v2.2.0` safe physical-continuation fix is implemented and validated, awaiting review and merge; no release work is active.

## TODO

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

- Published `v2.2.0` with reconciled documentation and metadata, nine passing Python tests, five passing Lua harnesses, eight compiled root scripts, deterministic conventional/OpenKH archives, and checksums.
- Replaced the retired R2 Action Ability page with a native three-slot learned-magic page, selected-row highlighting, and local `JokCombat_MagicShortcuts.cfg` persistence.
- Added confirmed-hit melee MP recovery at exactly 1 MP per 10 eligible native normal hits.
- Added OpenKH-native GitHub/archive installation while keeping direct
  LuaBackend deployment as a supported fallback.
- Replaced the machine-specific absolute KH1 script path with LuaBackend's
  standard relative path and added a verified runtime-only deploy helper.
- `v2.1.0` shipped the rebuilt five-family A/Y map, native Limit latching, depth continuation, and intentional-only ground-to-air entry.
- Post-tag work merged AP 99 for the full party and the functional native R2 magic page with selected-row highlighting.
- The project-level Kiroku hub was initialized from repository and test evidence on 2026-08-15.

## Cancelled

- Combo magic was cancelled because the adapter could not execute KH1's complete native cast path.
- Fake-ground airborne Action routing was cancelled because it could not preserve authored movement, effects, damage, and input control.
