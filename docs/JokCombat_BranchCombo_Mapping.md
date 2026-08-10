# JokCombat — mappa canonica X / Triangolo

Stato: **MAPPA APPROVATA; ACTION TREE 11/11 IMPLEMENTATO IN v0.7.1**

La tabella runtime contiene tutti i 24 nodi. La prima fase abilita le undici
Action Ability; magie e Limit restano dichiarati ma usano un fallback fisico
nativo finché i rispettivi dispatcher Steam completi non saranno validati.

Ambito: KH1 Final Mix, Steam Global, Sora

Input abbreviati: `X` = Croce, `T` = Triangolo

## 1. Regole definitive della mappa

1. Una sequenza canonica identifica una sola abilità.
2. Nessuna abilità compare in due sequenze diverse.
3. Ogni input del ramo esegue una mossa: la sequenza non è una password da
   completare prima di vedere un attacco.
4. Tutte le sole `X` restano la combo nativa completa gestita da KH1.
5. `T` neutrale resta nativo; il ramo esiste soltanto dopo almeno una `X`
   accettata.
6. La stessa sequenza identifica la stessa abilità a terra e in aria. Cambia
   soltanto l'adapter tecnico usato per eseguirla.
7. Magie, Limit, Counterattack e Zantetsuken sono foglie: dopo la loro
   esecuzione il ramo generico termina.
8. I Limit conservano il possesso dei propri follow-up nativi.
9. Le combinazioni non assegnate restano riservate a mosse future; non vengono
   riempite duplicando abilità esistenti.
10. Summon è esclusa.

La mappa contiene esattamente 24 azioni uniche:

- 11 Action Ability;
- sette famiglie magiche;
- cinque Limit;
- Chain Attack / Burst sperimentale.

## 2. Tronco X nativo

- Terra: le posizioni `1..6` sono normali contestuali e la posizione `7` è
  `CB`. Dopo la finestra sicura il bridge riapre una nuova stringa.
- Aria: le posizioni `1..4` sono normali e la posizione `5` è `CE`. Il bridge
  riapre `CC` finché Sora resta in aria.
- Le diramazioni fino a quattro `X` sono disponibili sia a terra sia in aria.
- `XXXXXT` e `XXXXXXT` sono terminali tardivi disponibili soltanto a terra,
  perché la combo aerea raggiunge la propria finisher alla quinta posizione.

## 3. Mappa canonica completa

La colonna «continuazione» indica quale input può essere premuto nella finestra
sicura della mossa corrente. Un trattino indica una foglia terminale.

### 3.1 Ramo `X` — rapido, elementale e supporto

| Sequenza | Mossa eseguita dall'ultimo input | Tipo | Continuazione |
|---|---|---|---|
| `XT` | Slapshot | Action Ability | `X` → `XTX`; `T` → `XTT` |
| `XTX` | Vortex | Action Ability | `X` → `XTXX`; `T` → `XTXT` |
| `XTXX` | Fire | Magia, grado più alto appreso | — |
| `XTXT` | Blizzard | Magia, grado più alto appreso | — |
| `XTT` | Sliding Dash | Action Ability | `X` → `XTTX`; `T` → `XTTT` |
| `XTTX` | Counterattack* | Action Ability contestuale | — |
| `XTTT` | Cure | Magia, grado più alto appreso | — |

Esecuzione di `XTTT`: attacco X nativo → Slapshot → Sliding Dash → Cure.

### 3.2 Ramo `XX` — mobilità aerea ed elementi

| Sequenza | Mossa eseguita dall'ultimo input | Tipo | Continuazione |
|---|---|---|---|
| `XXT` | Aerial Sweep | Action Ability | `X` → `XXTX`; `T` → `XXTT` |
| `XXTX` | Hurricane Blast | Action Ability | `X` → `XXTXX`; `T` → `XXTXT` |
| `XXTXX` | Thunder | Magia, grado più alto appreso | — |
| `XXTXT` | Aero | Magia, grado più alto appreso | — |
| `XXTT` | Ragnarok* | Limit | follow-up nativi Ragnarok |

Esecuzione di `XXTXT`: due X native → Aerial Sweep → Hurricane Blast → Aero.
Hurricane Blast resta `air-only` nel loadout normale; a terra `XXTX` usa un
ponte contestuale riservato esclusivamente al precedente Aerial Sweep `XXT`.

### 3.3 Ramo `XXX` — area, controllo e speciali

| Sequenza | Mossa eseguita dall'ultimo input | Tipo | Continuazione |
|---|---|---|---|
| `XXXT` | Ripple Drive | Action Ability | `X` → `XXXTX`; `T` → `XXXTT` |
| `XXXTX` | Stun Impact | Action Ability | `X` → `XXXTXX`; `T` → `XXXTXT` |
| `XXXTXX` | Gravity | Magia, grado più alto appreso | — |
| `XXXTXT` | Stop | Magia, grado più alto appreso | — |
| `XXXTT` | Gravity Break | Action Ability | `X` → `XXXTTX`; `T` → `XXXTTT` |
| `XXXTTX` | Ars Arcanum* | Limit | follow-up nativi Ars Arcanum |
| `XXXTTT` | Chain Attack / Burst* | Reaction sperimentale | follow-up nativi / sperimentali |

Esecuzione di `XXXTXT`: tre X native → Ripple Drive → Stun Impact → Stop.

### 3.4 Ramo `XXXX` — finisher fisiche pesanti

| Sequenza | Mossa eseguita dall'ultimo input | Tipo | Continuazione |
|---|---|---|---|
| `XXXXT` | Blitz | Action Ability | `X` → `XXXXTX`; `T` → `XXXXTT` |
| `XXXXTX` | Zantetsuken | Action Ability terminale | — |
| `XXXXTT` | Strike Raid* | Limit | follow-up nativi Strike Raid |

Esecuzione di `XXXXTX`: quattro X native → Blitz → Zantetsuken.

### 3.5 Terminali tardivi terrestri

| Sequenza | Mossa | Tipo | Continuazione |
|---|---|---|---|
| `XXXXXT` | Sonic Blade* | Limit | follow-up nativi Sonic Blade |
| `XXXXXXT` | Trinity Limit* | Limit | follow-up nativi Trinity Limit |

Questi due ingressi sostituiscono volontariamente una diramazione profonda con
un terminale immediato: dopo cinque X parte Sonic Blade; dopo sei X parte
Trinity Limit. Non sono raggiungibili dalla combo aerea, che chiude a cinque.

## 4. Verifica di unicità e copertura

### Action Ability — 11/11

| Action Ability | Unica sequenza canonica |
|---|---|
| Slapshot | `XT` |
| Vortex | `XTX` |
| Sliding Dash | `XTT` |
| Counterattack | `XTTX` |
| Aerial Sweep | `XXT` |
| Hurricane Blast | `XXTX` |
| Ripple Drive | `XXXT` |
| Stun Impact | `XXXTX` |
| Gravity Break | `XXXTT` |
| Blitz | `XXXXT` |
| Zantetsuken | `XXXXTX` |

Tutte sono entro `XXXX`, quindi tutte le Action Ability restano richiamabili
anche in aria con la medesima sequenza.

### Magie — 7/7

| Famiglia | Unica sequenza canonica |
|---|---|
| Fire | `XTXX` |
| Blizzard | `XTXT` |
| Cure | `XTTT` |
| Thunder | `XXTXX` |
| Aero | `XXTXT` |
| Gravity | `XXXTXX` |
| Stop | `XXXTXT` |

La famiglia sceglie il grado più alto appreso: Fire/Fira/Firaga e così via.

### Limit e speciale — 6/6

| Mossa | Unica sequenza canonica |
|---|---|
| Ragnarok | `XXTT` |
| Ars Arcanum | `XXXTTX` |
| Chain Attack / Burst | `XXXTTT` |
| Strike Raid | `XXXXTT` |
| Sonic Blade | `XXXXXT` |
| Trinity Limit | `XXXXXXT` |

## 5. Input non assegnati

Una combinazione non presente nelle tabelle non richiama un'altra abilità già
mappata. Il comportamento dipende dallo stato:

- dopo una foglia Action Ability o magia, il ramo si chiude e una nuova `X`
  avvia/riapre la stringa nativa;
- durante un Limit, X e T appartengono al Limit;
- un Triangolo successivo alla chiusura torna nativo;
- gli spazi liberi restano disponibili per Unsealing Strikes, Sky Climber,
  Ripple Slide, Stun Blitz, Zantetsu Prime e altre mosse future, soltanto dopo
  averne validato record, hitbox, effetti e uscita.

## 6. Timing e buffer

Il ramo usa un solo buffer; input ripetuti non creano una coda:

| Animazione corrente | Apertura prebuffer | Esecuzione minima |
|---|---:|---:|
| `C8` | 14 | 18 |
| `C9` | 14 | 34 |
| `CA` | 16 | 20 |
| `CC` | 8 | 12 |
| `CD` | 10 | 14 |

Le Action Ability interne con VFX o hitbox tardivi ricevono una finestra di
uscita individuale. Finché non si raggiunge quella finestra viene ricordato un
solo follow-up; lo spam precedente o successivo è ignorato.

## 7. Priorità e fallback

1. Reaction Command nativo prima del ramo Triangolo.
2. Guard e Dodge cancellano e azzerano la cronologia.
3. L1/R1/L2/R2 con un tasto faccia non alimentano questo albero.
4. Se Counterattack non possiede una finestra valida, oppure una magia/Limit
   non è disponibile, KH1 riceve un normale/finisher fisico del contesto e il
   ramo termina. Nessun'altra abilità canonica viene duplicata come fallback.
5. Se un adapter ground-native fallisce in aria, KH1 riceve la finisher aerea
   nativa e il ramo termina.
6. Un cambio terra/aria inatteso, danno subito, menu, reload o perdita del
   player object azzera il ramo e ripristina ogni route temporanea.

Le voci con `*` richiedono ancora la validazione del dispatcher nativo prima
dell'implementazione definitiva.
