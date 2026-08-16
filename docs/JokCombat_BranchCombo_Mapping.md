# JokCombat — mappa combo contestuale A / Y

Stato: **v2.2.0 — 5 FAMIGLIE; ACTION 8/8 + LIMIT NATIVI 4/4**

Ambito: KH1 Final Mix, Steam Global, Sora
Input abbreviati: `A` = Croce, `Y` = Triangolo

## 1. Regole

1. La stringa composta soltanto da `A` resta nativa. Combo Master, Combo Plus,
   Air Combo Plus, attacchi contestuali e finisher appartengono a KH1.
2. Il numero di `A` prima del primo `Y` sceglie la famiglia terrestre. Dopo il
   primo `Y`, `Y` avanza nella stessa famiglia. `B` resta sempre il salto
   nativo e chiude l'eventuale famiglia terrestre attiva.
3. Un `A` dopo una mossa nominata chiude immediatamente la famiglia e torna a
   una continuazione fisica vanilla. Non esistono prefissi reverse nascosti.
4. Ogni `Y` produce subito la mossa indicata: la sequenza non è una password
   attesa fino all'ultimo tasto.
5. Ogni Action Ability ha un solo ruolo contestuale: Strong è la catena
   caratteristica completa, C2 inseguimento, C3 controllo area, C4 attacco
   a distanza e C5 potenza gravitazionale.
   Hurricane Blast e Aerial Sweep restano nella famiglia aerea condivisa;
   Counterattack appartiene alla Guard riuscita.
6. I Reaction Command hanno priorità su `Y`. Da neutrale il bordo fisico resta
   prima a KH1; Strong si apre soltanto dopo due frame a `Y` rilasciato senza un
   Reaction ID, un menu non-root o una successiva `A` di conferma. Salva, Esamina
   e Parla non possono quindi armare per errore `Y -> Slapshot`, mentre un valore
   Reaction transitorio pubblicato da una Action già accettata non chiude la
   propria famiglia. Magie, menu, shortcut e costi MP vanilla non vengono
   modificati. Summon è esclusa.
7. Dopo una mossa terminale completata, il primo `A` terrestre realmente
   accettato da KH1 conserva la profondità logica e apre con `Y` la famiglia
   successiva. Il contatore combo nativo non viene scritto; C5 resta terminale.

## 2. Mappa terrestre completa

### Strong — catena caratteristica

| Sequenza | Mossa |
|---|---|
| `Y` | Slapshot |
| `Y Y` | Vortex |
| `Y Y Y` | Blitz |
| `Y Y Y Y` | Zantetsuken |
| `Y Y Y Y Y` | Ars Arcanum |

Ars Arcanum è terminale.

### C2 — inseguimento

| Sequenza | Mossa |
|---|---|
| `A Y` | Sliding Dash |
| `A Y Y` | Sonic Blade |

Sonic Blade è terminale.

### C3 — area

| Sequenza | Mossa |
|---|---|
| `A A Y` | Stun Impact |
| `A A Y Y` | Ripple Drive |

Ripple Drive è terminale. Trinity Limit è escluso dalla mappa perché la sua
sequenza nativa controlla anche Paperino e Pippo.

### C4 — attacco a distanza

| Sequenza | Mossa |
|---|---|
| `A A A Y` | Strike Raid |

Strike Raid è terminale. Essendo il primo nodo della famiglia, il suo selettore
nativo viene armato e riceve lo stesso `Y` fisico sul medesimo frame.

### C5 — potenza gravitazionale

| Sequenza | Mossa |
|---|---|
| `A A A A Y` | Gravity Break |
| `A A A A Y Y` | Ragnarok |

Ragnarok è terminale. Se Combo Plus porta la stringa oltre il quarto `A`,
le posizioni successive restano vanilla: la mappa non inventa C6/C7.

### Copertura terrestre

| Tipo | Quantità |
|---|---:|
| Action Ability nella mappa | 8 |
| Limit nativi | 4 |
| Nodi terrestri totali | **12** |

Non ci sono mosse duplicate e nessuna mossa nominata viene eseguita da `A`.

## 3. Famiglia aerea indipendente

Dopo qualunque colpo intermedio della combo aerea, `Y` apre sempre la stessa
catena già validata:

| Input contestuale | Mossa |
|---|---|
| primo `Y` | Aerial Finisher nativa `CE` |
| `Y` successivo | Hurricane Blast `D1` |
| `Y` successivo | Aerial Sweep `D6`, terminale |

La catena usa i nodi virtuali `AIR_CE -> AIR_D1 -> AIR_D6`. Hurricane Blast e
Aerial Sweep puntano ai loro record canonici, ma non occupano nodi della mappa
terrestre. Il salto normale chiude qualsiasi famiglia terrestre; la famiglia
aerea parte soltanto quando il flag airborne nativo è realmente visibile.
Da terra, il selettore nativo può scegliere il candidato `D6` quando Aerial
Sweep è attivo oppure il normale colpo aereo `CD` quando non lo è. JokCombat
bypassa l'intero ramo di inseguimento verticale soltanto finché Sora è a terra,
lasciando al motore la scansione dei candidati terrestri. Il branch originale
viene ripristinato dopo un salto reale; se una transizione già accettata sfugge
al gate, il ramo terrestre rilascia immediatamente `A` e `Y` senza richiedere un
Dodge Roll.
Restano disabilitati fake-ground, sospensione, scritture di quota e
manipolazione dello stick.

## 4. Counterattack contestuale

Counterattack è contestuale alla difesa. JokCombat osserva in sola lettura il byte
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
hitbox, danno e follow-up. Strike Raid è l'unica eccezione strutturale: apre C4
direttamente, quindi selettore e primo `Y` vengono agganciati nello stesso frame.

| Famiglia | Parent Action | Limit | Reaction |
|---|---|---|---:|
| Strong | Zantetsuken | Ars Arcanum | `0x0057` |
| C2 | Sliding Dash | Sonic Blade | `0x004B` |
| C4 | radice diretta | Strike Raid | `0x005E` |
| C5 | Gravity Break | Ragnarok | `0x005A` |

Sonic Blade, Ars Arcanum, Strike Raid e Ragnarok prendono in prestito a zero
soltanto il proprio costo durante la selezione e lo stato Limit. Trinity non è
armabile dalla mappa corrente; il suo descrittore precedente resta soltanto per
ripristinare in sicurezza un journal v2.0.0 durante `F1`. Il journal dei Limit
attivi conserva sempre gli originali prima di scrivere e ripristina soltanto
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
come osservato interrompendo Strike Raid in `ED/EE`.

## 6. Combo Guide

La Guide usa al massimo quattro righe del Command Menu nativo e mostra soltanto
i `Y` ancora disponibili. Dopo un `A`:

```text
[Y] Sliding Dash
[Y][Y] Sonic Blade
-
-
```

Dopo due `A`:

```text
[Y] Stun Impact
[Y][Y] Ripple Drive
-
-
```

Dopo Sliding Dash:

```text
[Y] Sonic Blade
-
-
-
```

Dopo Slapshot:

```text
[Y] Vortex
[Y][Y] Blitz
[Y][Y][Y] Zantetsuken
[Y][Y][Y][Y] Ars Arcanum
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

## 7. Continuazione della profondità

Una mossa terminale completata prepara la famiglia successiva:

| Terminale completato | `A` nativo successivo + `Y` apre |
|---|---|
| Ars Arcanum | C2 — Sliding Dash |
| Sonic Blade | C3 — Stun Impact |
| Ripple Drive | C4 — Strike Raid |
| Strike Raid | C5 — Gravity Break |
| Ragnarok | nessuna: C5 chiude la catena |

Il primo `A` non viene simulato e non modifica `comboPosition`: KH1 deve entrare
realmente in `C8`, `C9` o `CA`. Se viene premuto nella coda sicura di una Action
terminale, lo stesso `A` viene mantenuto durante il rilascio dell'animazione:
non serve premerlo una seconda volta una volta tornati neutrali. Quando KH1 lo
accetta direttamente, l'impulso di riserva viene annullato: `Y` resta disponibile
e non parte un secondo attacco dopo la recovery. La profondità
viene cancellata da un secondo
`A`, danno, salto, Guard, Dodge, modificatori, menu o timeout. Un `A` respinto
non la consuma: resta possibile riprovare entro la stessa finestra. La Guide usa
la profondità virtuale soltanto durante l'attacco confermato.

## 8. Timing e sicurezza

- Ogni Action concatenabile conserva la propria finestra di prebuffer/release
  e accetta al massimo un input.
- Guard, Dodge, modificatori, reaction command, menu, reload e perdita del
  player object chiudono sempre la famiglia e ogni selector posseduto. Anche il
  salto chiude sempre la famiglia terrestre attiva.
- La stringa `A` e il suo ciclo infinito post-finisher restano gestiti dal
  dispatcher KH1 con Combo Master/Combo Plus/Air Combo Plus.
- Nessuna combo modifica slot Shortcut, livelli magia, salvataggio, inventario
  o progressione.
- I follow-up dei Limit appartengono interamente allo stato nativo: dopo
  l'attivazione JokCombat non intercetta i loro input interni.
