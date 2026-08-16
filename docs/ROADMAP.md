# JokCombat Roadmap

This roadmap records planned work and research candidates. It does not promise
a release date, and every runtime patch must pass the same fingerprint,
ownership, restoration, and live-game validation rules used by v2.2.0.

## Planned: Epic Games Store support

Target: a later JokCombat release after the exact supported Epic executable has
been selected and validated.

- Keep one shared combat implementation; do not maintain separate Steam and
  Epic gameplay forks.
- Introduce explicit Steam and Epic build profiles selected by executable
  fingerprint.
- Map and validate each address/signature independently. The Epic executable
  cannot safely be supported with one global Steam-to-Epic address delta.
- Port and test player/input state, native Action records, Guard/Dodge,
  Command Menu HUD, Limits, native ability/save changes, Kinetic Step, and the
  drop-rate patch.
- Disable all writes on an unknown executable or failed signature check.
- Run the complete ground, aerial, R2 magic-page, Limit, save/reload, room-change,
  death, and script-reload test matrix before declaring Epic support.
- Prefer one universal release archive once both profiles are validated.

## Research candidate: optional Solo Sora mode

Goal: let players fight with Sora alone while preserving normal story and
party behavior outside supported combat situations.

- The mode must be optional and disabled by default.
- Do not permanently overwrite the saved party lineup.
- First identify and validate the runtime battle-actor/AI state for Donald,
  Goofy, and world-specific guest members. Hiding only the HUD or setting ally
  HP to zero is not sufficient.
- Snapshot every value owned by the mode and restore it conditionally on room
  or world changes, cutscenes, menus, scripted encounters, death, F1 reload,
  and shutdown.
- Automatically suspend the mode anywhere KH1 requires a scripted party or
  guest character.
- Keep Trinity Limit excluded from JokCombat's combo map; it natively requires
  Donald and Goofy and remains available only through vanilla KH1 behavior.
- Validate targeting, enemy aggro, ally healing, Limit state, party swapping,
  cutscenes, and save/reload behavior before release.

This mode should be treated as a challenge/gameplay option rather than the
default JokCombat ruleset: removing two allies materially changes healing,
damage, aggro, and encounter balance.
