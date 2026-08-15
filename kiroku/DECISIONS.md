# Decisions

## Active Decisions

### Decision: Keep native KH1 systems authoritative

Status: active
Area: combat architecture

Decision:
KH1 executes ordinary attacks, complete Actions, magic, Reaction Commands, Limit follow-ups, movement records, and save semantics whenever a native path exists; JokCombat selects context and owns only bounded routing state.

Rationale:
Animation-only or synthetic paths previously lost VFX, damage, hitboxes, movement, targeting, or recovery and could trap Sora in orphaned states.

Consequences:
- New moves require a validated complete native record or dispatcher.
- JokCombat must yield immediately when KH1 exposes native menu, Reaction, magic, or Limit ownership.

### Decision: Use Musou-style contextual A/Y families

Status: active
Area: combat design

Decision:
All-`A` strings remain vanilla; the native `A` depth selects one of five ground `Y` families, every `Y` executes a move immediately, and the aerial branch remains independent.

Rationale:
This creates distinct choices without hidden password sequences, duplicated specials, or artificial normal-attack queues.

Consequences:
- Eight ground Action Abilities and four active native Limits each have one contextual role.
- A real native `A` may carry depth after a terminal special, but C5 remains terminal and `comboPosition` is never written.

### Decision: Keep magic out of combo branches

Status: active
Area: magic and shortcuts

Decision:
Combo paths do not cast magic. `R2` instead exposes a second three-slot native Shortcut page containing only learned spells, while L1 remains KH1's normal page.

Rationale:
The attempted combo-magic adapter could not reproduce KH1's complete cast path reliably; the native Shortcut dispatcher already owns spell tier, MP, targeting, animation, VFX, and effect.

Consequences:
- R2 uses a signed edge bridge and temporary native slot swap rather than a custom cast implementation.
- `R2+B` remains jump or Kinetic Step, and the page contains only Y/X/A slots.

### Decision: Support Steam Global first and fail closed elsewhere

Status: active
Area: compatibility

Decision:
Only the validated Steam Global executable is supported until separate build profiles are mapped and tested.

Rationale:
The mod relies on fixed addresses and complete instruction/data signatures; a global Steam-to-Epic offset is unsafe.

Consequences:
- Unknown builds disable writes.
- Future Epic support must share gameplay logic but provide independently validated addresses and signatures.

### Decision: Separate persistent progression grants from runtime patches

Status: active
Area: save data

Decision:
Native abilities, party AP, and selected weapon ownership may persist after KH1 saves; combat state, R2 slot swapping, Limit cost borrowing, input patches, movement tuning, and drop multipliers remain process-local.

Rationale:
KH1's native menus and save model should represent learned abilities and equipment, while transient combat behavior must remain recoverable and bounded.

Consequences:
- Installation and release notes must require save backups and explain persistence.
- Persistent writers reconcile exact intended counts and preserve unrelated records.

### Decision: Preserve progression-critical exclusions

Status: active
Area: scope

Decision:
Ultima Weapon remains synthesis-only, Trinity Limit remains outside the combo map, and story flags, rewards, chests, synthesis, worlds, and Summons stay vanilla.

Rationale:
These systems carry progression or party ownership that the combat controller should not replace.

Consequences:
- The Keyblade module never writes Ultima or reward/synthesis flags.
- Trinity may retain recovery metadata only for stale journal cleanup, never as an active combo node.

### Decision: Restore only exact owned values

Status: active
Area: runtime safety

Decision:
Every temporary mutation snapshots or journals its original and restores only if the current value still equals JokCombat's exact owned value.

Rationale:
Conditional restoration prevents JokCombat from overwriting external changes or corrupting state after reload, cancellation, or coexistence conflicts.

Consequences:
- Every new patch needs ownership, verification, timeout, reload, exit, and conflict behavior.
- Another combat overhaul touching the same structures remains unsupported.

## Replaced Or Obsolete Decisions

- The configurable R2 Action Ability page was replaced by the native three-slot R2 magic page after Action shortcuts became redundant with the A/Y family map.
- Direct combo-magic casting and fake-ground airborne Actions were retired after they failed to reproduce complete native behavior.
