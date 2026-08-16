# Decisions

## Active Decisions

### Decision: Reward confirmed normal hits at a fractional rate

Status: active
Area: track

Decision:
Use a process-local credit of 0.10 MP per eligible confirmed native normal
attack, paying 1 real MP whenever ten credits accumulate.

Rationale:
Normal attacks should support resource recovery without replacing MP economy.
Per-hit credit rewards active melee play; ten attacks per MP accounts for
JokCombat's long, repeatable and slightly accelerated native strings.

Consequences:
- Whiffs, special actions, magic, Limits, Guard, and Counterattack give no credit.
- One attack animation gives at most one credit even against multiple targets.
- Fractional progress is process-local and need not be persisted in save data.
- The rate is final for this track after M-03 live validation.

### Decision: Do not bank melee charge at full MP

Status: active
Area: track

Decision:
Any confirmed normal hit while current MP equals max MP clears local progress
and performs no write.

Rationale:
Preloading nine hits at full MP would allow nearly immediate recovery after a
spell and would make the nominal 1-per-10 balance misleading.

Consequences:
- Recovery rewards melee performed after spending MP, not preparation at cap.
- Reloads and player-object changes also clear process-local progress.

### Decision: Validate read-only before writing MP

Status: active
Area: track

Decision:
Ship a standalone diagnostic probe before modifying production combat code.

Rationale:
The existing connect byte is proven for Guard and referenced by Critical Mix,
but its complete Steam Global timing for ordinary attacks is not yet known.

Consequences:
- M-01 supplied the evidence used by the production writer.
- The probe and production controller never clear or force the connect byte.

## Replaced Or Obsolete Decisions

- None.
