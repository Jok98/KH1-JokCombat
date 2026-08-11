# JokCombat — mappa combo Pirate A / Y

Stato: **ACTION TERRA 11/11 + FINISHER CE + ACTION ARIA NATIVE 2/2 IN v0.10.6; MAGIE COMBO RITIRATE; LIMIT 5/5 PARCHEGGIATI**

Ambito: KH1 Final Mix, Steam Global, Sora
Input abbreviati: `A` = Croce, `Y` = Triangolo

## 1. Regole del nuovo sistema

1. La stringa composta soltanto da `A` resta completamente nativa: Combo
   Master, Combo Plus, Air Combo Plus, attacchi contestuali e finisher
   appartengono a KH1.
2. `Y` è l'unico input che può eseguire un'Action Ability o, dopo validazione,
   un Limit nominato. Le magie restano esclusivamente vanilla.
3. `A` dopo una mossa speciale produce sempre una continuazione fisica e non
   può selezionare un'altra abilità.
4. Ogni input della sequenza produce un'azione; le combinazioni non sono
   password eseguite soltanto all'ultimo tasto.
5. I Reaction Command conservano la priorità su `Y`. Lo Strong combo neutrale
   esiste soltanto quando il Command Menu non espone una reaction.
6. A terra resta disponibile la mappa completa. In aria vengono esposte soltanto
   Aerial Sweep e Hurricane Blast, le due Action Ability con record aereo nativo.
7. Summon resta esclusa.

La v0.9.6 rimuove interamente la sospensione fake-ground: nessuna mossa aerea
scrive `raw70`, quota o stick. Le Action Ability terrestri restano disponibili
nel loro loadout e nella mappa a terra, ma in aria non vengono mostrate né
richieste.

## 2. Core Action Ability

La struttura ispirata a Pirate Warriors offre esattamente undici posizioni
attivate da `Y`, tante quante le Action Ability disponibili.

### Strong combo — `Y Y Y`

| Sequenza | Mossa dell'ultimo `Y` |
|---|---|
| `Y` | Vortex |
| `Y Y` | Stun Impact |
| `Y Y Y` | Gravity Break |

Lo Strong combo può partire da neutrale. Dopo il primo colpo, la Guide mostra
soltanto i `Y` ancora disponibili nella famiglia.

### C2 — `A Y Y Y`

| Sequenza | Mossa dell'ultimo `Y` |
|---|---|
| `A Y` | Slapshot |
| `A Y Y` | Sliding Dash |
| `A Y Y Y` | Blitz |

È la famiglia rapida e di avanzamento.

### C3 — `A A Y Y Y`

| Sequenza | Mossa dell'ultimo `Y` |
|---|---|
| `A A Y` | Aerial Sweep |
| `A A Y Y` | Hurricane Blast |
| `A A Y Y Y` | Ripple Drive |

L'ordine mantiene il ponte Steam già validato: Aerial Sweep `D6` autorizza
Hurricane Blast `D1` anche quando la famiglia è iniziata a terra.
Da v0.9.8 Hurricane Blast è inoltre dichiarato `both`: la stessa route completa
`D1` può essere richiesta direttamente a terra da uno slot configurabile, senza
dover prima eseguire Aerial Sweep.

In aria questa è l'unica famiglia Action e può iniziare dopo qualunque colpo
intermedio della combo: `A Y`, `A A Y`, `A A A Y` e le posizioni aggiunte da Air
Combo Plus eseguono tutte la finisher aerea nativa `CE`. Gli input `Y` prima del
tempo `20` vengono scartati; una nuova pressione valida esegue Hurricane Blast e
il successivo `Y` esegue Aerial Sweep come chiusura discendente. La v0.10.5
realizza l'ordine contestuale con il nodo virtuale `AIR_CE`, poi il canonico
`XXTT` e infine `XXT`, senza duplicare abilità né cambiare la C3 terrestre.
Ripple Drive resta ground-only e non viene proposta dalla Guide aerea.

### C4 e C5

| Famiglia | Sequenza | Mossa |
|---|---|---|
| C4 | `A A A Y` | Counterattack |
| C5 | `A A A A Y` | Zantetsuken |

### Copertura

| Famiglia | Slot |
|---|---:|
| Strong | 3 |
| C2 | 3 |
| C3 | 3 |
| C4 | 1 |
| C5 | 1 |
| Totale | **11** |

Nessuna Action Ability è duplicata e nessuna viene eseguita da `A`. La copertura
terrestre resta 11/11; la copertura aerea intenzionale è 2/2 record nativi.

## 3. Reverse Limit (ancora riservate)

La v0.10.6 ritira le sette reverse magiche: il remap dell'ultimo `Y` non
generava un ingresso reale nel dispatcher Shortcut. Menu e shortcut magiche
restano vanilla e conservano i propri costi MP. Il codice runtime mantiene
soltanto il recupero condizionale di un journal eventualmente lasciato dalle
versioni precedenti; nessuna combo può più scrivere slot, livello o costi magia.

Le cinque sequenze reverse rimaste sono riservate ai Limit. Ogni `A` intermedio
sarà un vero attacco fisico KH1 e soltanto il `Y` finale potrà consegnare il
controllo alla Reaction nativa.

| Sequenza riservata | Mossa |
|---|---|
| `Y A A A Y` | Sonic Blade |
| `Y Y A A A Y` | Ars Arcanum |
| `Y Y Y A A Y` | Strike Raid |
| `A Y Y Y A A Y` | Ragnarok |
| `A A Y Y Y A A Y` | Trinity Limit |

Queste cinque assegnazioni restano riserve univoche, non funzionalità dichiarate
come già giocabili. Saranno abilitate soltanto dopo un collaudo separato del
dispatcher nativo completo e del costo MP transitorio dei Limit.

## 4. Combo Guide

La Guide usa le righe native del Command Menu e mostra la famiglia relativa
alla posizione vanilla corrente.

Dopo un `A`, per esempio:

```text
[Y] Slapshot
[Y][Y] Sliding Dash
[Y][Y][Y] Blitz
```

Dopo `A A`:

```text
[Y] Aerial Sweep
[Y][Y] Hurricane Blast
[Y][Y][Y] Ripple Drive
```

Dopo avere eseguito Slapshot, la prima voce già consumata scompare:

```text
[Y] Sliding Dash
[Y][Y] Blitz
```

Dopo Vortex, la v0.10.6 mostra soltanto il seguito Strong attivo:

```text
[Y] Stun Impact
[Y][Y] Gravity Break
-
-
```

La Guide non mostra `[A] Continua vanilla`: la stringa fisica è sempre
implicita. Non rimane inoltre aperta mentre Sora è neutrale, evitando di
coprire permanentemente il Command Menu; dopo il primo `Y` dello Strong combo
mostra immediatamente i follow-up rimasti.

Il toggle condiviso con l'Action Loadout resta `L1+R1+L2+R2`, rilasciato senza
D-pad.
Il loadout diretto v0.9.9 espone soltanto i quattro slot `R2`; L2 resta dedicato
a Guard e la combinazione L2+R2 non seleziona più un gruppo Action Ability.

## 5. Timing, sicurezza e fallback

- Ogni Action Ability concatenabile conserva la propria finestra di prebuffer
  e release; viene memorizzato al massimo un input.
- Guard, Dodge, salto, modificatori, reaction command, menu, reload e perdita
  del player object chiudono sempre la famiglia.
- Un `A` durante una famiglia usa il percorso fisico target-free già validato:
  prima rilascia l'azione corrente, poi genera un singolo nuovo edge Attack e
  conserverà il prefisso soltanto quando conduce a un Limit validato.
- Nessuna combo modifica slot Shortcut, livelli o costi magia. Il journal
  storico viene letto soltanto a reload e poi cancellato condizionalmente.
- Se un adapter completo non è disponibile, la mossa riservata non compare
  nella Guide e non viene sostituita da un'altra abilità.
- I follow-up nativi dei Limit apparterranno al Limit dopo la sua attivazione.
