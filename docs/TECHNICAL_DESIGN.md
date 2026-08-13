# JokCombat v2.0.0 Technical Design

Status: release design for KH1 Final Mix, Steam Global.

This document records the implementation choices behind JokCombat v2.0.0.
It describes the current design rather than every experiment that preceded it.
The complete experimental record remains available in
`DEVELOPMENT_HISTORY.md`.

## 1. Design goals

JokCombat is designed around four principles:

1. Preserve KH1's native combat machinery whenever it already produces the
   correct animation, movement, targeting, VFX, hitbox, damage, and follow-up.
2. Add decisions to the combo without turning the input sequence into a
   password that produces nothing until its last button.
3. Make ground, aerial, defensive, and movement systems feed one another while
   retaining KH1's immediate feel.
4. Fail closed on an unsupported executable or an unexpected memory layout.

The project does not modify story progression, scripted rewards, chests,
synthesis state, world flags, bosses, or Summons. Its only inventory mutation
is the explicit native grant of one copy of each genuine Sora Keyblade except
Ultima Weapon, plus Save the Queen for Donald and Save the King for Goofy.
Magic remains native and is deliberately excluded from the combo dispatcher
after the attempted combo-magic adapter proved unable to reproduce KH1's
complete cast path.

## 2. Release modules

| File | Release role |
|---|---|
| `JokCombat_CombatPrototype.lua` | Main v2.0.0 combat, input, HUD, movement, Action, and Limit controller. The historical filename is retained to avoid breaking existing installations. |
| `JokCombat_NativeAbilities.lua` | Persistent native grant of Shared High Jump, Glide, Superglide, four Combo Plus, two Air Combo Plus, Combo Master, and 99 maximum AP. |
| `JokCombat_NativeKeyblades.lua` | Persistent native grant of the 17 genuine Sora Keyblades other than Ultima Weapon, plus Save the Queen and Save the King, with unique-count reconciliation. |
| `JokCombat_DropRate.lua` | Runtime-only 2.0x item and prize drop patch. |

`JokCombat_StateProbe.lua`, `JokCombat_InputProbe.lua`, and
`JokCombat_CommandMenuProbe.lua` are read-only development tools. They are not
runtime dependencies and are not part of the normal release installation.

The bundle is versioned as v2.0.0. Helper modules retain independent internal
versions because their memory contracts and release cadence are separate from
the main combat controller.

## 3. Supported build and fail-closed checks

All runtime addresses are validated for the current Steam Global executable.
Each module checks the expected `GAME_ID`, LuaBackend engine type, and an
executable fingerprint before enabling writes. Sensitive code patches also
verify their complete expected instruction bytes.

Dynamic player pointers are accepted only after range and state sanity checks.
If a fingerprint, signature, pointer, action record, or owned value differs
from the validated baseline, the relevant subsystem disables itself instead of
attempting a best-effort write.

The Epic Games Store executable and other regional builds use different
addresses and are not supported by v2.0.0.

## 4. Ownership boundaries

The central architectural choice is to give each action to one owner:

- KH1 owns ordinary `A` attacks, attack selection, Combo Master whiff attacks,
  intermediate combo steps, target tracking, and normal finishers.
- JokCombat owns the contextual `Y` family selection and temporarily routes
  the selected complete native Action record.
- KH1 owns native magic, Reaction Commands, menu confirmation, and every
  internal follow-up after a Limit has begun.
- JokCombat owns universal Guard, ground-only Dodge admission, the
  successful-Guard Counterattack window, the R2 Action loadout, and the
  Kinetic Step request. KH1 owns native airborne Square/Superglide.
- KH1 still executes the resulting Guard, Dodge, Counterattack, Action,
  jump, and Limit through native records or dispatchers.

This prevents two controllers from consuming the same physical press and
avoids animation-only actions that lack their native VFX, damage, or movement.

## 5. Native normal combo pipeline

Earlier versions routed every attack and maintained an artificial input queue.
That approach could skip middle attacks or replay a large backlog after the
finisher. The release instead leaves every normal `A` press to KH1.

The native ability module equips the exact intended maxima:

- Shared High Jump x1;
- Shared Glide x1;
- Shared Superglide x1;
- Combo Plus x4;
- Air Combo Plus x2;
- Combo Master x1.

Combo Master is therefore responsible for starting and continuing attacks
without a target. Ground and aerial combo length, contextual normal attacks,
and finishers are calculated by KH1.

Infinite ground and aerial strings use one narrow bridge: after KH1 reaches
the completed phase of ground finisher `CB` or aerial finisher `CE`, a fresh
`A` reopens the native string. Presses made during earlier recovery are not
queued. This keeps the combo cyclic without recreating every normal attack in
Lua.

## 6. Contextual A/Y families

The count of native `A` attacks before the first `Y` selects a family. Every
accepted `Y` immediately performs the named move; the player never enters a
silent password sequence. A subsequent `A` closes the special family and
returns to native physical continuation.

| Family | Prefix | Role | Route |
|---|---|---|---|
| Strong | `Y` | Burst | Vortex -> Gravity Break -> Ragnarok |
| C2 | `A Y` | Pursuit | Sliding Dash -> Sonic Blade |
| C3 | `A A Y` | Crowd control | Stun Impact -> Ripple Drive -> Trinity Limit |
| C4 | `A A A Y` | Combo pressure | Slapshot -> Blitz -> Strike Raid |
| C5 | `A A A A Y` | Execution | Zantetsuken -> Ars Arcanum |

The five families contain eight unique ground Action Abilities and all five
native Limits without duplicate named moves. The full input map, independent
aerial family, availability rules, and Combo Guide examples are maintained in
`JokCombat_BranchCombo_Mapping.md`.

Reaction Commands are inspected before opening a `Y` family. Neutral `Y` uses
a two-released-frame arbitration: its physical edge reaches KH1 first, and
Strong opens only if no Reaction, non-root Command Menu state, or following
physical `A` claims the input. Once a JokCombat Action has entered, a transient
Reaction value published by that complete native record cannot close its own
family. Save, Examine, Talk, and their first confirmation therefore remain
native. Magic and Summons do not enter the branch state machine.

## 7. Independent aerial family

After any intermediate normal aerial `A`, the aerial `Y` family is:

1. native Aerial Finisher `CE`;
2. Hurricane Blast `D1`;
3. Aerial Sweep `D6`.

Only actions that KH1 can execute correctly while airborne are used. The
retired fake-ground implementation could show an animation but could not
reliably preserve VFX, hitboxes, damage, stick control, or altitude.

The aerial family is independent from every ground family. A normal jump closes
the current ground branch, while the second jump deliberately resets the air
string so it can begin again. No airborne flag or fake altitude is written to
force a ground-to-air transition.

## 8. Native Action Ability dispatch

An Action Ability is routed by copying its complete validated 0x14-byte native
action record into the relevant selection entries before the physical input is
handled. Routing only the animation ID was rejected because moves such as Stun
Impact, Ripple Drive, Gravity Break, and Zantetsuken then lost native effects,
damage, or control flow.

The release catalog contains the complete records and selectors for the eight
ground branch Actions plus Hurricane Blast, Aerial Sweep, and Counterattack in
their contextual roles. Unsupported ground-only records are never converted
into airborne actions.

## 9. Native Limit dispatch and MP policy

The Action immediately before a Limit pre-arms one validated native Reaction
Command. If the final physical `Y` arrives while that Action is still
recovering, JokCombat records that one real edge and holds Steam Global's
native Auto-Reaction level until KH1 can legally accept it. The level is
journaled before ownership, bounded by the selector timeout, and cleared before
Limit follow-ups begin. It does not manufacture a second raw-button press, so
one final `Y` is sufficient while KH1's own Limit dispatcher still owns
targeting, movement, animation, VFX, damage, and follow-up inputs.

Sonic Blade, Ars Arcanum, Strike Raid, and Ragnarok temporarily borrow a zero
cost only for the selected combo route and active native Limit. Their original
costs are journaled and restored conditionally on completion, cancel, timeout,
fault, exit, or script reload. Launching the same Limit from KH1's menu keeps
its vanilla cost.

Trinity Limit is available only with Donald and Goofy present. Instead of
inventing a shared cost record, JokCombat snapshots the party MP state and
restores the native consumption for the combo invocation.

Once KH1 exposes an active Limit state, JokCombat stops intercepting combat
inputs until native recovery completes. This boundary prevents the orphaned
Limit state that can otherwise leave Sora unable to move.

## 10. Command Menu overlay and R2 loadout

The HUD does not create an external overlay. It temporarily reuses the text
tokens and selection behavior of KH1's Command Menu, showing at most four
rows in the lower-left corner.

Holding `R2` opens the only configurable Action group:

- D-pad Up/Down moves through editable rows using KH1's native cursor pulse;
- D-pad Left/Right cycles the available Action Abilities;
- releasing `R2` saves the configuration once to
  `JokCombat_ActionLoadout.cfg` beside the script.

Guard remains fixed and cannot be replaced. If the four-row root exposes
locked Summon as command `0x00` (or unlocked Summon as `0x36`), JokCombat
temporarily substitutes command `0x06` only as a visual carrier for the fourth
R2 Action label. The original command byte is stored in the signed recovery
journal and restored conditionally when the overlay closes or after F1 reload.
An actual `0xFF` fourth slot remains a three-row surface.

During a combo, the same Command Menu surface becomes a read-only Combo Guide
that lists only the valid future `Y` actions. The native `A` continuation is
implicit. Releasing `L1 + R1 + L2 + R2` without D-pad input toggles the overlay
and Guide persistently.

## 11. Defense and contextual Counterattack

Universal Guard is fixed to `L2 + B` and may cancel other ordinary actions.
Dodge Roll is fixed to grounded `X`, may cancel ordinary ground actions, and
cannot cancel itself. While airborne, JokCombat neither forces the Dodge
selector nor enables its air bypass: `X` stays entirely native for Superglide.
Native magic shortcut modifiers also keep priority, so `R1 + X` remains a magic
input rather than a Dodge request.

Counterattack is not an offensive combo node. A short `A` window opens only
after all three native conditions are observed: JokCombat accepted Guard,
Sora entered Guard animation `D4`, and KH1 reported a real Guard-connect
event. A whiffed Guard never exposes Counterattack.

## 12. Jump and descent model

High Jump, Glide, and Superglide are persistent native Shared abilities.
Kinetic Step is a separate runtime-only second jump with one charge per
airtime. The detector accepts both the base Jump entry (`0x04`) and High Jump
entry (`0x09`) as the real first jump:

1. a native first jump arms the charge;
2. holding that first `B` remains native for the complete variable-height High
   Jump, and releasing it arms input ownership for Kinetic Step;
3. a new airborne `B` may cancel an ordinary aerial action;
4. a bounded native air-action route enters the Kinetic Step animation and
   applies its validated lift;
5. after either jump, held airborne `X` remains KH1's native Superglide command;
6. landing is the only normal second-jump charge refill.

The controller suppresses later native Circle/Glide input only after the first
`B` is released, because that physical command is reserved for Kinetic Step.
It never remaps Square to Circle: Superglide already owns Square natively. A
timed-out second-jump request remains consumed until landing. The controller
never creates a third jump and resets on player changes, special aerial states,
Limits, faults, and reloads.

Descent is tuned through downward transform deltas only. Base Jump falls in
`0x06`, while Shared High Jump falls in `0x0B`; both feed the same controller:

- vanilla free fall after either jump retains 45% of its downward delta;
- ordinary aerial attacks `CC`, `CD`, and `CE` retain 25%;
- upward movement is untouched;
- Hurricane Blast and Aerial Sweep are excluded so their authored vertical
  trajectories remain intact.

The first- and second-jump fall profiles share one controller, preventing the
factor from being multiplied twice after Kinetic Step.

## 13. Persistent and runtime state

| Change | Persistence |
|---|---|
| 99 maximum AP | Saved by KH1 after a normal save |
| Shared High Jump, Glide, Superglide, and exact 4/2/1 combo passive counts | Saved by KH1 after a normal save |
| One total copy of each genuine non-Ultima Keyblade | Saved by KH1 after a normal save |
| Save the Queen and Save the King | Saved by KH1 after a normal save |
| R2 Action Ability assignments | Local `JokCombat_ActionLoadout.cfg` |
| Branch state, Action routes, Limit selectors, second jump, input ownership, descent tuning | Process only |
| 2.0x item/prize drop multipliers | Process only |

The native ability writer treats KH1's two stores separately. It preserves the
four-byte Shared movement list for High Jump, Glide, and Superglide and the
contiguous 48-byte Sora ability list for combo passives. It inserts only
missing entries, equips disabled personal copies in place, and removes later
vanilla surplus beyond the configured maxima without discarding unrelated
entries. Because those changes can persist, the installation instructions
require a save backup.

The Keyblade module follows KH1FM's native save layout: Sora's equipped weapon
is stored in his Character record while the 0x100-byte inventory-count array
starts at save offset `0x499`. For each of the 17 targets it keeps inventory
stock at zero when that weapon is equipped and one otherwise. This prevents
later vanilla rewards from creating duplicate unique weapons without changing
their reward or story flags. Ultima Weapon (`0x64`), Dream Sword, Dream Shield,
Dream Rod, Wooden Sword, and the equipped-weapon field are never written by the
module. Ultima therefore remains tied to KH1's normal synthesis progression.
The same ownership rule is applied to Save the Queen (`0x72`) using Donald's
equipped-weapon record and Save the King (`0x82`) using Goofy's. No other ally
weapon is granted or modified.

## 14. Drop-rate policy

`JokCombat_DropRate.lua` sets both native Steam operands to 2.0x after checking
their surrounding instruction signatures. It writes once at initialization,
does not edit the save, and restores the original values on exit only if they
are still owned by JokCombat.

This is a fixed JokCombat rule. It is not a claim that Critical Mix always uses
200%: that project selects a difficulty-dependent base and applies separate
weapon modifiers.

## 15. Recovery and coexistence policy

Every temporary patch keeps its original value and restores only memory that
still contains the exact value written by JokCombat. If another script changes
an owned field, JokCombat logs the conflict and leaves the external value
untouched.

Reload handlers normalize known legacy journals from earlier JokCombat builds
before enabling the release controller. This recovery exists for migration;
the retired combo-magic and fake-ground systems are not active code paths.

Running another combat overhaul against the same input, action, command,
ability, or Reaction structures is unsupported even with conditional restore.

## 16. Known v2.0.0 limits

- Steam Global is the only validated executable.
- Summons and combo magic are intentionally excluded.
- Perfect Guard and a dedicated enemy launcher are not implemented.
- A build or save that publishes no fourth root slot (`0xFF`) still exposes
  only three overlay rows; locked `0x00` and unlocked `0x36` rows are handled.
- The project uses fixed executable addresses and therefore requires a new
  validation pass after any game executable update.

## 17. Verification

Static release checks are run with:

```powershell
python tests/test_branch_mapping.py
python tests/test_attack_speed.py
python tests/test_drop_rate.py
python tests/test_fourth_command_row.py
python tests/test_release_metadata.py
```

The distributable archive and checksum are built with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/Build-Release.ps1 -Version v2.0.0
```

The v2.0.0 gameplay baseline has also been tested live for native ground and
aerial strings, all five branch families, all five Limits, the independent
aerial family, R2 Actions, Guard/Dodge/Counterattack, Kinetic Step, both descent profiles, and
the fixed drop multiplier.

## 18. Attribution

Critical Mix by Xendra/KSX was used with the authors' permission as a technical
reference for selected KH1 structures and concepts. JokCombat's Steam Global
ports, validation checks, state machines, recovery rules, and combat design
were implemented and tested for this project.
