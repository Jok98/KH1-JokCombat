# JokCombat v2.2.0 Technical Design

Status: release design for KH1 Final Mix, Steam Global.

This document records the implementation choices behind JokCombat v2.2.0.
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
| `JokCombat_CombatPrototype.lua` | Main v2.2.0 combat, input, HUD, movement, Action, Limit, native R2 magic-page, and melee-MP controller. The historical filename is retained to avoid breaking existing installations. |
| `JokCombat_NativeAbilities.lua` | Persistent native grant of Shared High Jump, Glide, Superglide, four Combo Plus, two Air Combo Plus, Combo Master, and 99 maximum AP for Sora, Donald, and Goofy. |
| `JokCombat_NativeKeyblades.lua` | Persistent native grant of the 17 genuine Sora Keyblades other than Ultima Weapon, plus Save the Queen and Save the King, with unique-count reconciliation. |
| `JokCombat_DropRate.lua` | Runtime-only 2.0x item and prize drop patch. |

`JokCombat_StateProbe.lua`, `JokCombat_InputProbe.lua`,
`JokCombat_CommandMenuProbe.lua`, and `JokCombat_MPHitProbe.lua` are read-only
development tools. They are not runtime dependencies and are not part of the
normal release installation.

The bundle is versioned as v2.2.0. Helper modules retain independent internal
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
addresses and are not supported by v2.2.0.

## 4. Ownership boundaries

The central architectural choice is to give each action to one owner:

- KH1 owns ordinary `A` attacks, attack selection, Combo Master whiff attacks,
  intermediate combo steps, target tracking, and normal finishers.
- JokCombat owns the contextual `Y` family selection and temporarily routes
  the selected complete native Action record.
- KH1 owns native magic, Reaction Commands, menu confirmation, and every
  internal follow-up after a Limit has begun.
- JokCombat owns universal Guard, ground-only Dodge admission, the
  successful-Guard Counterattack window, selection and reversible bridging of
  the second R2 magic page, and the Kinetic Step request. KH1 owns native
  magic casting and airborne Square/Superglide.
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

Confirmed native contact edges during owned normal attack animations `C8`
through `CE` contribute at most one melee-MP credit per animation. Ten credits
restore exactly 1 MP below the verified native cap. Whiffs, Actions, Limits,
magic, Guard, Counterattack, and low-secondary Limit reuse are excluded. Full
MP clears partial progress so credit cannot be banked before casting; the
counter is also cleared on reload and player-object changes. The capped MP
write is immediately verified and the subsystem fails closed until reload if
verification fails.

## 6. Contextual A/Y families

The count of native `A` attacks before the first `Y` selects a family. Every
accepted `Y` immediately performs the named move; the player never enters a
silent password sequence. A subsequent `A` closes the special family and
returns to native physical continuation.

| Family | Prefix | Role | Route |
|---|---|---|---|
| Strong | `Y` | Signature chain | Slapshot -> Vortex -> Blitz -> Zantetsuken -> Ars Arcanum |
| C2 | `A Y` | Pursuit | Sliding Dash -> Sonic Blade |
| C3 | `A A Y` | Crowd control | Stun Impact -> Ripple Drive |
| C4 | `A A A Y` | Ranged raid | Strike Raid |
| C5 | `A A A A Y` | Gravity burst | Gravity Break -> Ragnarok |

The five families contain eight unique ground Action Abilities and four active
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

Steam Global's native Attack candidate builder reaches RVA `0x2A70D5` after a
grounded target vector crosses its vertical threshold. Its stock seven-byte
block chooses candidate `0` (`D6`, Aerial Sweep) when transient ability bit
`0x02` is active, or candidate `1` (`CD`, the ordinary aerial hit) otherwise.
Clearing the bit only changes the selected aerial move and cannot prevent the
leap.

While Sora is grounded, JokCombat replaces that exact signed instruction with
`E9 01 01 00 00 90 90`, a near jump to KH1's existing ground-candidate scan at
`0x2A71DB`. The original bytes `F6 05 34 7B AB 02 02` are restored as soon as
Sora is genuinely airborne and during cleanup or unsupported contexts. Every
write validates either the exact stock or exact owned signature. No target
pointer, ability bit, airborne state, position or action record is modified,
and the complete native aerial selector remains available after a real jump. A
second state-machine guard releases all branch input ownership if a grounded
request was already committed before the gate changed, preventing the resulting
state from trapping both `A` and `Y` until Dodge Roll.

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

Sonic Blade, Ars Arcanum, and Ragnarok are pre-armed by their parent Actions.
Strike Raid begins C4 directly, so its selector and the same physical final-`Y`
edge are journaled and latched together before the generic root dispatcher can
reject an unprepared Limit.

Trinity Limit is excluded from the active combo map because its native sequence
owns Donald and Goofy. Its former catalog descriptor remains recovery-only so
an F1 reload can still restore a v2.0.0 journal safely; it can never be armed by
the current branch controller.

Once KH1 exposes an active Limit state, JokCombat stops intercepting combat
inputs until native recovery completes. This boundary prevents the orphaned
Limit state that can otherwise leave Sora unable to move.

After a terminal ground special completes, JokCombat preserves only its logical
family depth. The next modifier-free physical `A` remains entirely native and
must visibly enter a normal `C8`-`CA` attack before the following `Y` may select
the next family. If that `A` is buffered inside the safe recovery tail of a
terminal Action, the existing release/pulse pipeline carries the same depth;
the player does not have to press it again after the animation reaches neutral.
If the physical edge itself already opens `C8`-`CA`, that confirmation cancels
the still-pending target-free pulse before it can block `Y` or create a duplicate
attack after recovery.
The native `comboPosition` byte is never written. A timeout,
damage, jump, Guard, Dodge, shortcut, menu, timeout, or second physical `A`
clears the carry. A rejected `A` does not consume the saved depth; the
controller waits for another real native attempt within the same timeout. C5
is terminal and returns to a fresh vanilla chain.

## 10. Command Menu surfaces and R2 magic page

JokCombat does not create an external overlay. It temporarily reuses KH1's
native Command Menu or Shortcut surfaces.

Exact `R2` opens a second three-slot magic Shortcut page:

- `Y`, `X`, and `A` cast the three assigned learned spells; `B` remains native
  jump or Kinetic Step;
- D-pad Up/Down selects a row and Left/Right cycles learned spells;
- releasing `R2` saves the page once to `JokCombat_MagicShortcuts.cfg` beside
  the script;
- the selected spell name is temporarily colored gold.

The page snapshots KH1's native L1 Shortcut slots, temporarily swaps in the R2
assignments, and uses a signature-checked physical R2-to-Shortcut edge bridge.
KH1's own dispatcher therefore retains spell tier, MP cost, targeting,
animation, VFX, effect, and failure rules. L1 remains the original page.
Temporary slot bytes, input bridge state, and text colors are restored only
when they still contain JokCombat's exact owned values.

During a combo, the lower-left root Command Menu becomes a separate read-only
Combo Guide listing only the valid future `Y` actions. The native `A`
continuation is implicit. If the four-row root exposes locked Summon as
command `0x00` or unlocked Summon as `0x36`, JokCombat temporarily substitutes
command `0x06` only as a visual carrier for the fourth Guide row. Its original
command byte is journaled and restored conditionally when the Guide closes or
after F1 reload. An actual `0xFF` fourth slot remains a three-row surface.
Releasing `L1 + R1 + L2 + R2` without D-pad input toggles the Guide
persistently.

## 11. Defense and contextual Counterattack

Universal Guard is fixed to `L2 + B` and may cancel other ordinary actions.
Dodge Roll is fixed to grounded `X`, may cancel ordinary ground actions, and
cannot cancel itself. While airborne, JokCombat neither forces the Dodge
selector nor enables its air bypass: `X` stays entirely native for Superglide.
Native magic shortcut modifiers also keep priority, so `L1 + X` remains a magic
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
| 99 maximum AP for Sora, Donald, and Goofy | Saved by KH1 after a normal save |
| Shared High Jump, Glide, Superglide, and exact 4/2/1 combo passive counts | Saved by KH1 after a normal save |
| One total copy of each genuine non-Ultima Keyblade | Saved by KH1 after a normal save |
| Save the Queen and Save the King | Saved by KH1 after a normal save |
| R2 learned-magic assignments | Local `JokCombat_MagicShortcuts.cfg` |
| Branch state, Action routes, Limit selectors, grounded high-target branch bypass, second jump, input ownership, descent tuning, partial melee-MP credit | Process only |
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

## 16. Known v2.2.0 limits

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
python tests/test_local_deploy.py
python tests/test_melee_mp_recovery.py
python tests/test_mp_hit_probe.py
python tests/test_openkh_manifest.py
python tests/test_release_metadata.py
```

The distributable archives and checksums are built with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/Build-Release.ps1 -Version v2.2.0
```

The build produces a conventional archive containing documentation and the
direct deployment helper, plus a dedicated `-OpenKH.zip`. The OpenKH archive
places `mod.yml` and the four runtime Lua modules at its root so it can be
selected directly through **Select and install Mod Archive or Lua Script**.
The same root manifest allows GitHub installation with
`Jok98/KH1-JokCombat`; `game: kh1` prevents selection for another title and
each runtime module is declared as a game-agnostic `copy` asset under
`scripts/`. Diagnostic probes are excluded from both OpenKH inputs.

Local development and extracted releases deploy the four runtime modules with:

```powershell
.\tools\Deploy-Local.ps1
```

The default destination is LuaBackend's Steam Documents path,
`My Games\KINGDOM HEARTS HD 1.5+2.5 ReMIX\scripts\kh1`. The script performs no
cleanup, verifies every copied file with SHA-256, and includes the four
diagnostic probes only when `-IncludeDiagnostics` is explicit.

The v2.2.0 gameplay baseline has also been tested live for native ground and
aerial strings, all five branch families, all four active combo Limits, the
independent aerial family, the distinct R2 magic page and selected-row
highlight, Guard/Dodge/Counterattack, Kinetic Step, both descent profiles,
intentional ground-to-air entry, the 1-MP-per-10-hits payout, and the fixed
drop multiplier. The OpenKH manifest and both release archives are validated
statically; direct LuaBackend remains the live-tested runtime baseline.

## 18. Attribution

Critical Mix by Xendra/KSX was used with the authors' permission as a technical
reference for selected KH1 structures and concepts. JokCombat's Steam Global
ports, validation checks, state machines, recovery rules, and combat design
were implemented and tested for this project.
