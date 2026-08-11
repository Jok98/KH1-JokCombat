# JokCombat — mappa combo Pirate A / Y

Stato: **CORE ACTION 11/11 IMPLEMENTATO IN v0.9.0**

Ambito: KH1 Final Mix, Steam Global, Sora
Input abbreviati: `A` = Croce, `Y` = Triangolo

## 1. Regole del nuovo sistema

1. La stringa composta soltanto da `A` resta completamente nativa: Combo
   Master, Combo Plus, Air Combo Plus, attacchi contestuali e finisher
   appartengono a KH1.
2. `Y` è l'unico input che può eseguire un'Action Ability, una magia o un
   Limit nominato.
3. `A` dopo una mossa speciale produce sempre una continuazione fisica e non
   può selezionare un'altra abilità.
4. Ogni input della sequenza produce un'azione; le combinazioni non sono
   password eseguite soltanto all'ultimo tasto.
5. I Reaction Command conservano la priorità su `Y`. Lo Strong combo neutrale
   esiste soltanto quando il Command Menu non espone una reaction.
6. Lo stesso schema viene usato a terra e in aria; gli adapter già validati
   gestiscono le differenze tecniche.
7. Summon resta esclusa.

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

Nessuna Action Ability è duplicata e nessuna viene eseguita da `A`.

## 3. Reverse ed estensioni riservate

La v0.9.0 rende già sicuro il primo passo delle reverse: premendo `A` dopo
un'Action Ability, il ramo speciale viene chiuso e KH1 riceve un nuovo attacco
fisico. Non viene eseguita alcuna abilità nominata.

Le estensioni seguenti sono dichiarate nella mappa, tutte con un `Y` finale,
ma restano disabilitate finché magia e Limit non possiedono dispatcher Steam
completi per effetto, costo, bersaglio e follow-up.

### Magie

| Sequenza riservata | Famiglia |
|---|---|
| `Y A Y` | Fire |
| `Y A A Y` | Blizzard |
| `Y Y A Y` | Thunder |
| `Y Y A A Y` | Aero |
| `Y Y Y A Y` | Cure |
| `A Y Y Y A Y` | Gravity |
| `A A Y Y Y A Y` | Stop |

### Limit e speciale

| Sequenza riservata | Mossa |
|---|---|
| `Y A A A Y` | Sonic Blade |
| `Y Y A A A Y` | Ars Arcanum |
| `Y Y Y A A Y` | Strike Raid |
| `A Y Y Y A A Y` | Ragnarok |
| `A A Y Y Y A A Y` | Trinity Limit |
| `Y Y Y A A A Y` | Chain Attack / Burst |

Queste assegnazioni sono riserve univoche, non funzionalità dichiarate come
già giocabili. La futura reverse manterrà il contesto durante i colpi fisici
intermedi e chiamerà la mossa soltanto sul `Y` conclusivo.

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

La Guide non mostra `[A] Continua vanilla`: la stringa fisica è sempre
implicita. Non rimane inoltre aperta mentre Sora è neutrale, evitando di
coprire permanentemente il Command Menu; dopo il primo `Y` dello Strong combo
mostra immediatamente i follow-up rimasti.

Il toggle condiviso con l'Action Loadout resta `L1+R1+L2+R2`, rilasciato senza
D-pad.

## 5. Timing, sicurezza e fallback

- Ogni Action Ability concatenabile conserva la propria finestra di prebuffer
  e release; viene memorizzato al massimo un input.
- Guard, Dodge, salto, modificatori, reaction command, menu, reload e perdita
  del player object chiudono sempre la famiglia.
- Un `A` durante una famiglia usa il percorso fisico target-free già validato:
  prima rilascia l'azione corrente, poi genera un singolo nuovo edge Attack.
- Se un adapter completo non è disponibile, la mossa riservata non compare
  nella Guide e non viene sostituita da un'altra abilità.
- I follow-up nativi dei Limit apparterranno al Limit dopo la sua attivazione.
