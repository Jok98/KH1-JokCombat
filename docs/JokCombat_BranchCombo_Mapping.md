# JokCombat — mappa combo contestuale A / Y

Stato: **v0.13.2 — MAPPA TERRA 13 NODI; ACTION 8/8 + LIMIT NATIVI 5/5; PROTEZIONE STATO LIMIT**

Ambito: KH1 Final Mix, Steam Global, Sora
Input abbreviati: `A` = Croce, `Y` = Triangolo

## 1. Regole

1. La stringa composta soltanto da `A` resta nativa. Combo Master, Combo Plus,
   Air Combo Plus, attacchi contestuali e finisher appartengono a KH1.
2. Il numero di `A` prima del primo `Y` sceglie la famiglia terrestre. Dopo il
   primo `Y`, soltanto `Y` avanza nella stessa famiglia.
3. Un `A` dopo una mossa nominata chiude immediatamente la famiglia e torna a
   una continuazione fisica vanilla. Non esistono prefissi reverse nascosti.
4. Ogni `Y` produce subito la mossa indicata: la sequenza non è una password
   attesa fino all'ultimo tasto.
5. Ogni Action Ability ha un solo ruolo contestuale. Le otto Action terrestri
   sono nella mappa offensiva; Hurricane Blast e Aerial Sweep restano nella
   famiglia aerea; Counterattack appartiene alla Guard riuscita.
6. I Reaction Command hanno priorità su `Y`. Magie, menu, shortcut e costi MP
   vanilla non vengono modificati. Summon è esclusa.

## 2. Mappa terrestre completa

### Strong — energia

| Sequenza | Mossa |
|---|---|
| `Y` | Vortex |
| `Y Y` | Gravity Break |
| `Y Y Y` | Ragnarok |

Ragnarok è terminale.

### C2 — mobilità

| Sequenza | Mossa |
|---|---|
| `A Y` | Sliding Dash |
| `A Y Y` | Blitz |
| `A Y Y Y` | Sonic Blade |

Sonic Blade è terminale.

### C3 — area

| Sequenza | Mossa |
|---|---|
| `A A Y` | Stun Impact |
| `A A Y Y` | Ripple Drive |
| `A A Y Y Y` | Trinity Limit |

Trinity Limit è terminale ed è disponibile soltanto a terra con Donald e Goofy
nel party. Se manca uno dei due, la Guide termina su Ripple Drive e non propone
né sostituisce Trinity.

### C4 — distanza

| Sequenza | Mossa |
|---|---|
| `A A A Y` | Slapshot |
| `A A A Y Y` | Strike Raid |

Strike Raid è terminale.

### C5 — esecuzione

| Sequenza | Mossa |
|---|---|
| `A A A A Y` | Zantetsuken |
| `A A A A Y Y` | Ars Arcanum |

Ars Arcanum è terminale. Se Combo Plus porta la stringa oltre il quarto `A`,
le posizioni successive restano vanilla: la mappa non inventa C6/C7.

### Copertura terrestre

| Tipo | Quantità |
|---|---:|
| Action Ability nella mappa | 8 |
| Limit nativi | 5 |
| Nodi terrestri totali | **13** |

Non ci sono mosse duplicate e nessuna mossa nominata viene eseguita da `A`.

## 3. Famiglia aerea invariata

Dopo qualunque colpo intermedio della combo aerea, `Y` apre sempre la stessa
catena già validata:

| Input contestuale | Mossa |
|---|---|
| primo `Y` | Aerial Finisher nativa `CE` |
| `Y` successivo | Hurricane Blast `D1` |
| `Y` successivo | Aerial Sweep `D6`, terminale |

La catena usa i nodi virtuali `AIR_CE -> AIR_D1 -> AIR_D6`. Hurricane Blast e
Aerial Sweep puntano ai loro record canonici, ma non occupano più nodi della
mappa terrestre. Restano disabilitati fake-ground, sospensione, scritture di
quota e manipolazione dello stick.

## 4. Counterattack contestuale

Counterattack non è una C4 offensiva. JokCombat osserva in sola lettura il byte
Steam `0x296B230`, port dello stesso segnale usato dal riferimento Critical Mix.
La finestra si apre soltanto quando sono vere insieme queste condizioni:

1. JokCombat ha accettato `L2 + Cerchio` come Guard;
2. Sora è realmente nell'animazione Guard `D4`;
3. il segnale di contatto riporta `0x10`.

Dopo il blocco riuscito, una Croce fisica senza modificatori esegue
Counterattack `D5`. Una Guard a vuoto, un attacco dopo una parata mancata o un
generico deflect non aprono la finestra. JokCombat non scrive e non azzera mai
il segnale di contatto.

## 5. Limit nativi e gratuiti soltanto in combo

L'Action immediatamente precedente pre-arma una sola Reaction nativa; il `Y`
finale rimane fisico e KH1 gestisce bersaglio, movimento, animazione, VFX,
hitbox, danno e follow-up.

| Famiglia | Parent Action | Limit | Reaction |
|---|---|---|---:|
| Strong | Gravity Break | Ragnarok | `0x005A` |
| C2 | Blitz | Sonic Blade | `0x004B` |
| C3 | Ripple Drive | Trinity Limit | `0x0052` |
| C4 | Slapshot | Strike Raid | `0x005E` |
| C5 | Zantetsuken | Ars Arcanum | `0x0057` |

Sonic Blade, Ars Arcanum, Strike Raid e Ragnarok prendono in prestito a zero
soltanto il proprio costo durante la selezione e lo stato Limit. Trinity salva
gli MP runtime di Sora, Donald e Goofy e ripristina il consumo nativo. Il
journal conserva sempre gli originali prima di scrivere e ripristina soltanto
campi ancora posseduti da JokCombat, anche con cancel, timeout o `F1`/reload.
I Limit lanciati dal menu conservano il costo vanilla.

Se il parent Action termina senza un `Y` finale, la famiglia viene cancellata o
si preme `A`, il selettore pre-armato viene restituito subito. Dopo un `Y`
finale realmente osservato, resta invece disponibile per una grazia massima di
20 frame: alcune transizioni native diventano visibili soltanto dopo un frame
intermedio a idle. Se il pre-arm non è disponibile, il `Y` viene scartato e non
viene sostituito da un falso attacco fisico.

Quando `raw70 >= 0x20`, KH1 possiede lo stato Limit completo. JokCombat lascia
fisici gli input di follow-up ma neutralizza ogni propria route, pulse, Guard,
Dodge e Action Ability fino all'uscita nativa. Cancellare soltanto l'animazione
di un Limit puo lasciare `raw70` orfano e bloccare permanentemente il movimento,
come osservato interrompendo Strike Raid in `ED/EE`. Durante il collaudo il log
registra inoltre ogni variazione del Reaction Command nativo e ogni `Y` di
follow-up, cosi da isolare Impact senza forzarne l'ID alla cieca.

## 6. Combo Guide

La Guide usa al massimo quattro righe del Command Menu nativo e mostra soltanto
i `Y` ancora disponibili. Dopo un `A`:

```text
[Y] Sliding Dash
[Y][Y] Blitz
[Y][Y][Y] Sonic Blade
-
```

Dopo due `A` con Donald e Goofy:

```text
[Y] Stun Impact
[Y][Y] Ripple Drive
[Y][Y][Y] Trinity Limit
-
```

Dopo Sliding Dash:

```text
[Y] Blitz
[Y][Y] Sonic Blade
-
-
```

Durante la finestra di una Guard riuscita:

```text
[A] Counterattack
-
-
-
```

La continuazione vanilla su `A` resta implicita. La Guide non copre il Command
Menu mentre Sora è neutrale; lo Strong appare dopo il primo `Y`. Il toggle
condiviso resta `L1 + R1 + L2 + R2` rilasciato senza D-pad.

## 7. Timing e sicurezza

- Ogni Action concatenabile conserva la propria finestra di prebuffer/release
  e accetta al massimo un input.
- Guard, Dodge, salto, modificatori, reaction command, menu, reload e perdita
  del player object chiudono sempre la famiglia e ogni selector posseduto.
- La stringa `A` e il suo ciclo infinito post-finisher restano gestiti dal
  dispatcher KH1 con Combo Master/Combo Plus/Air Combo Plus.
- Nessuna combo modifica slot Shortcut, livelli magia, salvataggio, inventario
  o progressione.
- I follow-up dei Limit appartengono interamente allo stato nativo: dopo
  l'attivazione JokCombat non intercetta i loro input interni.
