# Constraints

## Active Constraints

### Constraint: Validated executable only

Status: active

Rule:
Enable writes only for the expected KH1 game ID and validated Steam Global fingerprint, with subsystem-specific pointer and signature checks.

Why:
Fixed addresses and instruction patches can corrupt memory or crash a different executable.

### Constraint: Native execution ownership

Status: active

Rule:
Do not replace KH1's complete action, magic, Reaction, Limit-follow-up, or normal-combo machinery with animation-only or synthetic equivalents.

Why:
Partial emulation loses effects, hitboxes, damage, movement, targeting, or recovery and has previously produced immobile states.

### Constraint: Conditional restoration

Status: active

Rule:
Journal originals before temporary writes and restore only fields that still contain JokCombat's exact owned value.

Why:
Unconditional restoration can overwrite KH1 transitions or changes made by another system.

### Constraint: Persistent save changes require disclosure

Status: active

Rule:
Treat ability, AP, and equipment grants as persistent after a normal KH1 save and require a save backup in installation and upgrade guidance.

Why:
Removing the Lua scripts does not automatically undo native saved records.

### Constraint: Preserve vanilla progression boundaries

Status: active

Rule:
Never write story flags, scripted rewards, chests, world state, synthesis state, Summons, or Ultima Weapon ownership.

Why:
Those systems define progression and are outside the combat-overhaul contract.

### Constraint: Input priority remains coherent

Status: active

Rule:
Reaction Commands, menus, native magic shortcuts, active Limits, and confirmation inputs take priority over JokCombat branches; ground Dodge must never steal airborne Superglide.

Why:
One physical press consumed by two owners causes missed interactions, repeated confirmation, invalid branches, or stuck control state.

### Constraint: Combat map exclusions

Status: active

Rule:
Keep combo magic and Summons out of A/Y branches, keep Trinity Limit out of the active map, and use only genuinely airborne-compatible Actions in the aerial family.

Why:
The excluded systems lack a validated single-owner path or require party/progression state outside Sora's branch controller.

### Constraint: Release validation is both static and live

Status: active

Rule:
Do not publish solely because static tests pass; also validate gameplay, menus, room changes, death, save/reload, and F1 recovery on the supported executable.

Why:
The Python and Lua harnesses cannot reproduce KH1's complete runtime dispatcher and rendering behavior.

## Out Of Scope

- Epic Games Store and non-Global executables until a dedicated profile is validated.
- Summons, combo magic, Perfect Guard, and a dedicated enemy-launcher system.
- Trinity Limit as a JokCombat combo node.
- Solo Sora as a default gameplay rule.
- Other KINGDOM HEARTS games; they should use separate repositories when development begins.

## Forbidden Changes

- Do not port Steam addresses to Epic with one uniform delta.
- Do not write `comboPosition` to fake depth or queue many normal attacks.
- Do not fake grounded state, altitude, or ground-only Actions while airborne.
- Do not grant Ultima Weapon or alter its synthesis/reward path.
- Do not bypass a failed signature merely to keep a feature active.
- Do not ship Critical Mix code or represent JokCombat as derived by copy-paste; keep the documented inspiration/reference attribution.
