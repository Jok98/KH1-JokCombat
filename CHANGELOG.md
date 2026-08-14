# Changelog

All notable player-facing changes to JokCombat are recorded here.

## Unreleased

### Changed

- Rebuilt the ground families without duplicate moves: the pure `Y` chain is
  now Slapshot -> Vortex -> Blitz -> Zantetsuken -> Ars Arcanum, C4 opens
  Strike Raid directly, and C5 is Gravity Break -> Ragnarok.
- Added same-frame native selector latching for the direct C4 Strike Raid root.
- Added a virtual post-special depth carry: after a completed terminal move,
  one real native `A` advances to the following ground family without writing
  KH1's combo counter. An `A` buffered in the safe recovery tail of a terminal
  Action uses the same handoff and does not require a second press. C5 remains
  terminal. Once KH1 accepts that native attack, its delayed fallback is
  cancelled so `Y` remains immediately available and no duplicate swing fires.
- Removed Trinity Limit from the combo map because its native sequence owns
  Donald and Goofy. Its old journal descriptor remains recovery-only so an
  interrupted v2.0.0 invocation can still be restored safely after reload.

### Fixed

- Prevented grounded `A` attacks and newly opened `Y` families from selecting
  either native Aerial Sweep `D6` or the normal aerial hit `CD` when the enemy
  is above Sora. A signature-checked branch bypass is active only while Sora is
  grounded; an independent recovery guard also releases branch input ownership
  if KH1 had already committed a stale airborne transition.

## 2.0.0 - 2026-08-13

### Added

- Musou-style contextual `A`/`Y` combat with five distinct ground families,
  eight Action Abilities, all five native Limits, and a separate aerial route.
- A journaled single-input latch so the first final `Y` starts its native Limit
  as soon as KH1 can accept it, without requiring a repeated press.
- Native Shared High Jump, Glide, and Superglide, plus the once-per-airtime
  Kinetic Step second jump.
- Native grants for every genuine Sora Keyblade except Ultima Weapon, which
  remains tied to normal synthesis progression.
- Save the Queen for Donald and Save the King for Goofy.
- A reproducible release packager with an accompanying SHA-256 checksum.

### Changed

- Simplified C4 into the standard Slapshot -> Blitz -> Strike Raid branch.
- Kept normal ground and aerial strings under KH1, including Combo Master,
  four Combo Plus, two Air Combo Plus, and native finishers.
- Added a light `1.15x` playback-speed increase only to native normal attacks.
- Refined neutral `Y` arbitration so Talk, Examine, Save, Reaction Commands,
  and the following confirmation input retain native priority.
- Preserved variable-height High Jump while moving Superglide to its native
  held-airborne `X` command.
- Reworked the locked fourth Command Menu row into a signed, reversible carrier
  for the fourth R2 assignment.
- Renamed the internal combo-family terminology to Musou throughout the code,
  logs, tests, and documentation.

### Fixed

- Removed the extra `Y` press previously needed to enter a combo Limit.
- Prevented neutral Triangle interaction from swallowing the first subsequent
  confirmation input.
- Restored double-jump behavior after KH1 naturally grants Shared High Jump.
- Prevented ground Dodge Roll from stealing native airborne Superglide input.
- Preserved native Limit ownership through startup, follow-ups, and recovery so
  Sora cannot be left in an orphaned immobile state.

### Upgrade notes

- Back up the KH1 save before installing or upgrading.
- Replace all four runtime modules; 2.0.0 adds
  `JokCombat_NativeKeyblades.lua` to the release bundle.
- `JokCombat_ActionLoadout.cfg` remains compatible with 1.0.0.
- Native ability and equipment grants can persist after KH1 saves. Removing the
  scripts does not automatically reverse those save-file changes.
- Steam Global remains the only validated executable.

## 1.0.0 - 2026-08-12

- First public JokCombat release for KH1 Final Mix on Steam Global.
