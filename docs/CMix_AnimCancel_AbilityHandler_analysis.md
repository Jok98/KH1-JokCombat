# Analisi iniziale: Critical Mix 7.7

## Risultato

`CMix_AnimCancel.lua` conferma che lo stato d'azione di Sora e' accessibile
tramite un puntatore statico e un piccolo blocco di campi dinamici. E' un buon
riferimento concettuale, ma non e' portabile direttamente: combina ID legati al
moveset di Critical Mix, indirizzi della build EGS 1.0.0.8 e patch temporanee al
codice eseguibile.

`CMix_AbilityHandler.lua` non e' invece un riferimento utile per la state
machine di combattimento. Modifica AP, EXP, abilita', equipaggiamento e flag di
progressione: quasi tutto il file e' esplicitamente fuori dal perimetro di
JokCombat.

Il primo esperimento e' quindi solo lettura e logging dei valori grezzi. Non
riusa codice Critical Mix e non contiene chiamate `Write*`.

## Base address e versioni

La configurazione LuaBackend della copia downgraded contiene:

```toml
[kh1]
base = 0x3A0606
```

Gli script Critical Mix dichiarano lo stesso valore come `offset` e usano
`indirizzo - offset`. Le due operazioni si annullano: per esempio
`ReadLong(0x2534680 - offset)` legge in realta' `module + 0x2534680`.

La configurazione Steam corrente non dichiara `base`, quindi usa base `0`.
Gli indirizzi EGS non devono essere copiati nella Steam presumendo che siano
rimasti invariati. La directory runtime scelta per JokCombat e':

- `C:\Users\jok\Documents\KH_mod\scripts\kh1`

Dal 9 agosto 2026 il blocco `[kh1]` del `LuaBackend.toml` installato usa
soltanto la directory assoluta sopra indicata. La directory runtime contiene
unicamente `JokCombat_StateProbe.lua`; i 40 script Critical Mix sono stati
separati e conservati in
`C:\Users\jok\Documents\KH_mod\reference\CriticalMix`, fuori dal caricamento
runtime.

## `CMix_AnimCancel.lua`

### Indirizzi statici osservati

Gli indirizzi sotto sono RVA finali rispetto al modulo, cioe' i valori prima
della sottrazione di `offset`.

| RVA | Nome nel file | Uso osservato |
| --- | --- | --- |
| `0x2534680` | `soraPointer` | Puntatore a oggetto/stato corrente di Sora |
| `0x2A3406` | `forceSquareInput` | Byte di codice temporaneamente mutato per forzare l'azione difensiva |
| `0x2A33A4` | `forceCircleInput` | Byte di codice temporaneamente mutato per forzare l'azione Circle |
| `0x233D037` | `leftStickInput` | Stato movimento stick sinistro |
| `0x233CB4C` | `world` | World ID; `9` riceve logica Atlantica speciale |
| `0x22C5B31` | `realButtonCheck` | Bitmask input controller |
| `0x284EE2C` | `currentCommandMenuSlot` | Slot selezionato nel command menu |
| `0x525588` | `reactionFlag2` | Flag reazione; il controllo presente e' logicamente impossibile |
| `0x23D0600` | trigger menu 1 | Scrittura usata per riattivare l'attacco/menu |
| `0x232A444` | trigger menu 2 | Scrittura usata per riattivare l'attacco/menu |

`swapped`, `menuStatus`, `buttonPress` e `lastAnim` sono dichiarati ma non
contribuiscono al comportamento del file.

### Layout dinamico di Sora

Dato `player = ReadLong(soraPointer)`, il file usa:

| Offset | Tipo osservato | Significato provvisorio |
| --- | --- | --- |
| `+0x000` | byte | Controllo/cancel dell'azione; scrivere `0x03` interrompe o rilascia lo stato corrente |
| `+0x070` | float | Stato ground/air; il file tratta `0` come grounded e non-zero come airborne |
| `+0x164` | byte | Animation/action ID corrente |
| `+0x168` | byte | Stato/ID secondario usato per jump e limit |
| `+0x16C` | float | Tempo dell'animazione corrente |

Questi offset interni sono candidati migliori degli RVA statici a rimanere
stabili fra build, ma devono comunque essere verificati sulla Steam vanilla.

### Input

La bitmask `realButtonCheck` viene interpretata cosi':

| Bit | Interpretazione nel file |
| --- | --- |
| `0x80` | Square |
| `0x40` | X / Attack |
| `0x20` | Circle |
| `0x04` | L1, usato come modificatore/esclusione |
| `0x02` | R2, usato come modificatore/esclusione |

Square sceglie Guard o Dodge in base al movimento dello stick. Circle viene
usato come jump cancel solo a terra. Le variabili `squareReleased` e
`circleReleased` cercano di rendere l'input edge-triggered.

### State machine implicita

Per ogni frame il file:

1. ripristina eventuali byte di codice modificati tre frame prima;
2. legge input, animation ID, secondary ID, animation time e ground/air;
3. costruisce `canCancel` da una whitelist di animazioni e casi speciali;
4. esclude alcuni stati limit e il jump cancel in aria;
5. apre finestre temporali per specifici finisher/azioni;
6. se l'input e' valido, scrive `0x03` nel controllo azione e forza
   Guard/Dodge/Jump tramite patch o trigger del command menu.

Non esiste una vera astrazione `startup -> active -> recovery`. Le finestre
sono codificate come confronti diretti tra ID e `animationTime`.

### ID osservati e cross-reference degli altri script

Ora che il player object Steam e gli offset sono confermati, gli altri script
della release possono essere usati come dizionario. La chiave corretta non e'
pero' il solo `anim`: alcuni ID sono riutilizzati e vanno interpretati insieme
a `secondary`, `raw70` e, quando disponibile, al contesto della combo.

#### Confermati sulla Steam vanilla

| Anim | Secondary | raw70 | Interpretazione attuale | Evidenza |
| --- | --- | --- | --- | --- |
| `0x00` | `0x00`/`0x01` | `0` | idle/neutral | stato finale e heartbeat della cattura |
| `0x01`/`0x02` | `0x03`/`0x06` | `0` | locomotion/transizioni; distinzione esatta ancora aperta | cattura tra idle e azioni |
| `0x04` | `0x08` | `1` | ingresso nel salto | cattura Steam e `jump_iframes()` |
| `0x05` | `0x09` | `2` | fase aerea | cattura ripetuta tre volte |
| `0x06` | `0x0A` | `2` -> `0` | fase aerea e contatto col terreno | cattura ripetuta tre volte |
| `0x07` | `0x0B` | `0` | landing/recovery | cattura Steam e commento `Landing` |
| `0xC8` | `0x62` | `0` | prima azione ground combo / attacco singolo | input confermato e tabella `groundComboA1` |

`0xC8` non significa sempre attacco base. `CMix_GameSpeedup.lua` tratta
`0xC8`-`0xCA` come Sonic Blade soltanto con `secondary <= 10`, mentre
`CMix_AnimCancel.lua` riconosce il contesto limit con secondary `0x00`-`0x02`.
Il valore Steam osservato `0x62` identifica quindi un contesto diverso e rende
coerente l'etichetta ground-combo.

#### Dizionario ricavato dagli script Critical Mix

Queste etichette hanno evidenza diretta nei nomi delle tabelle, nei commenti o
nei confronti degli script, ma richiedono ancora una cattura Steam prima di
essere considerate definitive per JokCombat:

| ID | Etichetta o famiglia nello script |
| --- | --- |
| `0x0D`/`0x0E` | stati hang/cling esclusi dal multi-jump |
| `0x0F` | Double/Multi Jump; riusato come Kinetic Step |
| `0x15`, `0x16`, `0x1E`, `0x1F` | climb |
| `0x36`-`0x3D` | Fire windup, Blizzard, Thunder, Cure, Gravity, Stop, Aero, Fire cast |
| `0x3E`/`0x3F` | uso item di Sora / uso item alleato |
| `0x4E`-`0x51` | Air Stagger |
| `0x71`, `0x73`, `0x74` | famiglia Glide |
| `0x84`-`0x8A` | magia aerea: Blizzard, Thunder, Cure, Gravity, Stop, Aero, Fire |
| `0xC9`/`0xCA` | altre entry delle combo normali; riusate anche da Sonic Blade/limit |
| `0xCB` | Basic Ground Finisher |
| `0xCC` | Air Combo 1 |
| `0xCD` | Air Combo 2; Rising Uppercut Launcher nel moveset Critical Mix |
| `0xCE` | Default Aerial Finisher |
| `0xCF` | Slapshot |
| `0xD0` | ground combo Slide |
| `0xD1` | Hurricane Blast |
| `0xD2` | Cleave |
| `0xD3` | Impulse |
| `0xD4` | Guard/Hyper Guard |
| `0xD5` | Judgement/Counter context |
| `0xD6` | Aerial Rush/Ars context, dipendente dal moveset |
| `0xD7` | Ripple Slide |
| `0xD8` | Stun Impact |
| `0xDB` | Horizontal Strike |
| `0xDC` | Dodge/Roll |
| `0xE6`-`0xEE` | fasi di Strike Raid, Judgement e recovery |
| `0xF0`-`0xF5` | Ragnarok |
| `0xFA` | Trinity Limit |

Gli ID introdotti o rimappati dalla `.mset` Critical Mix restano materiale di
progetto riutilizzabile, ma non descrivono automaticamente la `.mset` vanilla
Steam. La mappa JokCombat mantiene percio' separati `confermato Steam`,
`cross-reference forte` e `specifico Critical Mix`.

### Problemi da non ereditare

- `reactionFlag2 == 0xF9 and reactionFlag2 == 0xFB` non puo' mai essere vero.
- `cancelFinished` viene riarmato mentre l'input e' premuto; non e' un latch di
  rising edge pulito.
- I byte `0x82/0x84` e `0x72/0x74` mutano codice eseguibile per tre frame: sono
  fragili, build-specific e non adatti al primo MVP.
- World `9`, limit e command menu sono mescolati direttamente alla meccanica.
- ID, finestre e indirizzi sono magic numbers non validati.
- Non c'e' alcun Perfect Guard in questo file.

## `CMix_AbilityHandler.lua`

### Dipendenze statiche principali

| RVA | Ruolo osservato |
| --- | --- |
| `0x2534680` | Puntatore Sora; usato solo per calcolare un `currentAnim` poi inutilizzato |
| `0x2A342D` | Byte forzato a `0x72` ogni frame (`forceGuard`) |
| `0x233CADC` / `0x233CB44` / `0x233CB48` | World, room, event flag |
| `0x2A1C28` | Moltiplicatore EXP |
| `0x2DE5A14` | 48 slot abilita' di Sora |
| `0x2DE5F69` | 48 slot abilita' condivise |
| `0x2DE59ED` | 8 slot accessori |
| `0x2DE5A06` | Keyblade corrente |
| `0x2DE59D9` | AP base di Sora |
| `0x232A600` | Stato menu |
| `0x2DF18DA` / `0x2DF18DC` | Gummi inutilizzati riadattati come config/feature flag |
| `0x2DE6ED1` | Flag cutscene tutorial |
| `0x284EE8C` | Stato/visibilita' command menu usato per la notifica |

### Flusso implicito

Non legge input e non usa realmente animation/action state. Ogni frame:

1. mostra una notifica una sola volta in base a menu, world e Must Style;
2. forza AP base a `100` e il byte Guard a `0x72`;
3. modifica il moltiplicatore EXP e implementa una variante di EXP Zero;
4. nel menu rigenera abilita' derivate da accessori/keyblade;
5. nel Dive to the Heart assegna armi/abilita' starter e blocca EXP;
6. concede abilita' bonus in base a flag di avanzamento.

Sono tutte dipendenze specifiche di Critical Mix e molte violano direttamente
i vincoli vanilla-progression di JokCombat.

### ID abilita' osservati

Il file usa, fra gli altri:

- `0x16` Dodge Roll e `0x3D` Encounter Plus;
- `0xAB` Accelerate, `0xAD` Zero EXP, `0xBC` Must Style;
- `0x21/0xA1` Mage Style e `0x0A/0x8A` Aerial Recovery;
- `0x06` Combo Plus, `0x3E` Leaf Bracer, `0x1B` Jackpot;
- `0x08` Critical Plus, `0x17` MP Haste, `0x18` MP Rage.

Le coppie con/senza bit alto suggeriscono stati learned/equipped, ma il file
non li normalizza in modo coerente. Non vanno trasformati in API JokCombat
prima di una verifica separata.

### Concetti genericamente utili

Solo tre idee meritano di essere reimplementate in modo originale:

- risolvere il player pointer a ogni frame/load anziche' conservarlo per sempre;
- leggere slot in un range limitato con controlli di sanita';
- separare eventi one-shot da logica per-frame.

Il codice delle funzioni non va copiato.

## Autorizzazione e riuso

L'archivio locale non contiene `LICENSE`, `COPYING` o note di permesso e la
pagina Nexus richiede normalmente il consenso dell'autore. Il 9 agosto 2026 il
proprietario di JokCombat ha confermato di avere ottenuto dall'autore di
Critical Mix e degli script analizzati l'autorizzazione a usare e adattare quel
materiale come base per la propria versione del combattimento.

Di conseguenza possiamo anche portare o rifattorizzare codice autorizzato, non
soltanto le idee generali. Manteniamo comunque:

- attribuzione a Xendra/Critical Mix per ogni parte derivata;
- distinzione chiara fra codice originale JokCombat e codice adattato;
- una copia privata della prova e dell'ambito dell'autorizzazione;
- validazione Steam specifica prima di caricare codice o asset nati per EGS.

Il probe corrente resta un'implementazione originale e non contiene codice
copiato da Critical Mix.

Riferimenti:

- [LuaBackend memory API](https://github.com/Sirius902/LuaBackend/blob/hook/DOCUMENT.md)
- [Critical Mix permissions](https://www.nexusmods.com/kingdomheartsfinalmix/mods/93?tab=description)

## Architettura minima proposta per v0.1

La prima iterazione resta intenzionalmente in un solo file. Dopo la conferma
degli indirizzi, la struttura minima sara':

```text
JokCombat.lua                 entry point e ordine di update
config/CombatConfig.lua      soli toggle e finestre configurabili
core/Build.lua               fingerprint e address set per build
core/PlayerState.lua         snapshot read-only del player
core/Input.lua               input normalizzato + pressed/released/held
debug/StateLogger.lua        log event-driven e heartbeat opzionale
mechanics/CancelSystem.lua    prima meccanica, solo dopo il probe
mechanics/GuardSystem.lua     guard/perfect guard, in una milestone successiva
```

Regole architetturali:

- una build non riconosciuta non legge/scrive indirizzi gameplay;
- `core` legge memoria ma non decide il design;
- ogni `mechanics` riceve snapshot e input, senza leggere flag di storia;
- le scritture future passano da una piccola API esplicita e validata;
- niente indirizzi di progressione in JokCombat;
- log su transizione di stato, non spam per frame.

## Esperimento 0: State Probe

`JokCombat_StateProbe.lua` supporta per ora solo il fingerprint Steam Global e
usa `0x2537E48` come player pointer della Steam corrente. Una lettura diretta
read-only del 9 agosto 2026 ha confermato che l'RVA risolve una struttura Sora
coerente: `control=0x03`, `raw70=0`, `anim=0x00`, `secondary=0x00` e animation
time finito. Il precedente sanity check falliva soltanto perche' la slot
reference Steam osservata e' `0xCC10`, fuori dalla fascia EGS
`0x9000`-`0xBFFF`; il probe accetta quindi la fascia alta `0x8000`-`0xFFFF`.

Il probe legge:

- action/control byte `+0x000`;
- slot reference `+0x06C` per sanity check;
- ground/air raw `+0x070`;
- animation ID `+0x164`;
- secondary animation ID `+0x168`;
- animation time `+0x16C`.

Registra una riga quando cambia lo stato e un heartbeat ogni 300 frame. Non
legge input, non forza animazioni e non contiene scritture.

### Baseline Steam confermata - sessione 2026-08-09

Una cattura vanilla durante gameplay ha confermato l'intera catena di lettura:

- RVA statico del player pointer: `0x2537E48`;
- pointer assoluto della sessione: `0x7FF656D272A0` (dato ASLR, non va
  hardcodato);
- slot reference osservata e stabile: `0xCC10`;
- `+0x000` alterna soprattutto `0x03` con transizioni `0x07`;
- `+0x070` usa almeno `0` a terra, `1` nella transizione iniziale e `2` in
  aria;
- `+0x164`, `+0x168` e `+0x16C` cambiano e si azzerano in modo coerente con
  le transizioni di animazione;
- l'heartbeat legge lo stesso player object anche senza cambi di stato.

La sequenza seguente si e' ripetuta tre volte senza variazioni:

| Control | Anim | Secondary | raw70 | Osservazione prudente |
| --- | --- | --- | --- | --- |
| `0x03` | `0x04` | `0x08` | `1` | ingresso nella sequenza aerea |
| `0x03` | `0x05` | `0x09` | `2` | fase aerea |
| `0x03` | `0x06` | `0x0A` | `2` | fase aerea successiva |
| `0x03` | `0x06` | `0x0A` | `0` | contatto col terreno |
| `0x07` -> `0x03` | `0x07` | `0x0B` | `0` | recovery/landing |

Sono stati inoltre osservati gli stati bassi `0x00`, `0x01`, `0x02`. L'utente
ha confermato che le tre occorrenze `0xC8`/secondary `0x62` corrispondono ai tre
attacchi singoli eseguiti; il dato coincide con la tabella `groundComboA1` degli
script e rende questa associazione confermata per la Steam vanilla testata.

### Matrice di test successiva

Su una save Steam vanilla, raccogliere i log per:

1. idle e corsa;
2. singolo attacco e combo completa;
3. salto, attacco aereo e atterraggio;
4. Guard e block riuscito;
5. Dodge Roll;
6. ricezione danno e stagger;
7. una magia disponibile all'inizio.

Solo dopo questa tabella possiamo nominare gli ID vanilla e progettare la prima
cancel window senza ereditare assunzioni dalla `.mset` di Critical Mix.

## Port input e routine difensiva Steam - 2026-08-09

Il confronto binario EGS/Steam e la lettura del processo Steam hanno prodotto
il seguente address set. Gli opcode e i valori inattivi sono stati verificati
anche nella memoria del processo; la semantica dei bit fisici resta da
confermare con `JokCombat_InputProbe.lua`.

| RVA Steam | Uso | Valore vanilla osservato |
| --- | --- | --- |
| `0x22C9301` | bitmask input fisico | `0x00` a riposo |
| `0x23407B5` | bitmask command/input secondaria | `0x00` a riposo |
| `0x22C9345` | override mapping fisico Cerchio | `0xFF` |
| `0x28527AC` | slot corrente command menu | `0x00` |
| `0x23D3F80` | trigger command 1 | `0` |
| `0x232DDC4` | trigger command 2 | `0` |
| `0x2D5EC10` | flag disponibilita' azioni difensive | dipende dallo stato |
| `0x2A7B74` | bypass azione Cerchio | `0x74` |
| `0x2A7BD6` | bypass azione Square | `0x84` |
| `0x2A7BFD` | test disponibilita' Guard / ingresso roll | `0x74` |
| `0x2A7C01` | scelta del ramo Guard | `0x74` |
| `0x2A7C1F` | test disponibilita' Dodge Roll | `0x84` |

La routine a `0x2A7B30` non richiede di forzare direttamente un animation ID:

- il ramo `0x2A7C51` inizializza Guard;
- il ramo `0x2A7C1C` inizializza Dodge Roll;
- `0x2A7C01: 74 -> EB` forza la scelta Guard dopo il normale controllo di
  disponibilita';
- `0x2A7BFD: 74 -> EB` salta Guard e sceglie il percorso Dodge, lasciando
  attivo il normale controllo di disponibilita' Dodge;
- i bypass `72`/`82` possono rendere le azioni disponibili senza modificare il
  save. Sono attivi nel primo test richiesto, così Guard e Dodge funzionano
  anche sulla save iniziale; restano un toggle configurabile da disattivare
  quando si vuole rispettare anche l'acquisizione vanilla delle abilita'.

`JokCombat_CombatPrototype.lua` usa queste modifiche soltanto mentre serve,
verifica prima gli opcode attesi e ripristina i byte vanilla su reload, perdita
del player object o callback di uscita. La prima transizione terra -> aria e'
un jump-cancel da una finestra configurabile: non lancia ancora il nemico e non
implementa aerial chase.

### Correzione dopo il primo test attivo

Il log del primo prototipo ha mostrato due problemi distinti:

- il cancel Attack scriveva `control=0x03` a `time=10`, riavviando `C8` prima
  che il flusso combo a terra potesse avanzare; v0.1.2 usa il trigger command
  ritardato di quattro frame senza azzerare il control byte;
- il bypass Square veniva armato tenendo semplicemente L2, causando Guard senza
  Cerchio, mentre la scelta Dodge arrivava dopo il primo frame di Quadrato;
  v0.1.2 pre-arma Dodge in stato neutro e attiva il bypass Guard soltanto con
  la chord completa L2 + Cerchio;
- la tabella control override e' orientata `azione virtuale -> controllo
  fisico`: mentre L2 e' tenuto, Circle/jump viene disabilitato e l'azione
  Square/defense viene temporaneamente associata al controllo fisico Cerchio.

Lo stesso log conferma che la combo aerea nativa alterna `CC/0x66` e
`CD/0x67`. Il nuovo requisito di progetto e' un loadout completo di action e
movement ability disponibile dall'inizio tramite stato runtime, senza
inserimento permanente nella lista abilita' del save.

## Port del contatore combo e controllo v0.2 - 2026-08-09

Il campo EGS `comboPosition` (`0x29678A1`) appartiene a un blocco globale il
cui riferimento base passa da `0x2967860` a `0x296B1E0` nella Steam. La stessa
relazione interna `+0x41` porta quindi al campo Steam `0x296B221`. La lunghezza
combo a terra di Sora passa da `0x2D59364` a `0x2D5CCE4`.

Una lettura diretta e read-only del processo Steam ha verificato valori
coerenti (`comboPosition=3`, `maxGroundComboLength=3`) insieme al fingerprint e
al player pointer gia' noti. Il prototipo applica inoltre limiti di sanita':
lunghezza `2..12` e posizione non oltre `max+2`; fuori da questi intervalli non
scrive il contatore combo.

La politica v0.2 e':

- una pressione Croce a terra mantiene la posizione sotto `max-1`; raggiunta
  la soglia finisher, la posizione torna a zero e la catena dei normali puo'
  continuare indefinitamente, un colpo per rising edge;
- Triangolo imposta `comboPosition=max-1` e richiama il comando Attack soltanto
  se esiste una catena locale aperta da una precedente pressione Croce;
- Triangolo senza tale precedente non sintetizza alcun attacco e lascia
  intatto l'eventuale comportamento vanilla delle reaction command;
- il buffer aspetta la finestra nativa e viene annullato se ID, tempo o
  posizione combo mostrano che il gioco ha gia' consumato l'input, evitando
  due colpi per una sola pressione;
- Guard L2 + Cerchio e' l'unico cancel universale. Il bypass aereo
  `0x2A7BE0: 85 -> 82` viene attivato soltanto per la chord Guard; Dodge e salto
  conservano le finestre conservative del prototipo.

### Risultato live v0.2 e correzione v0.2.1

La cattura live v0.2 ha contato 42 richieste di link normale e 10 richieste di
finisher, ma lo State Probe ha osservato soltanto `C8` a terra e `CC` in aria:
nessuna transizione `C9/CA/CB/CD/CE`. Guard `D4`, Air Guard `D4` e Dodge `DC`
sono invece entrati correttamente. Le Isole del Destino non spiegano il
risultato, perche' la combo vanilla a tre colpi e' gia' disponibile in quella
sezione.

La causa operativa e' che i due flag command da soli possono mantenere lo spam
del colpo base, ma il moveset Steam vanilla non li interpreta come un nuovo
link mentre `C8/CC` resta attivo. In v0.2.1 il fallback, solo dopo la normale
finestra attack-to-attack, scrive `control=0x03` e nello stesso frame invia il
comando Attack. Non viene letto alcun target pointer, lock-on, distanza o
hit-confirm: l'avvio deve quindi funzionare anche colpendo il vuoto. Questo non
allarga gli altri cancel; Guard rimane l'unica cancellazione universale.

Per evitare falsi positivi, `issued` significa ora soltanto che il comando e'
stato emesso. Un controllo separato di 12 frame registra `transition observed`
solo se il normale passa davvero a un altro stato/restart oppure se il
finisher entra in `CB`; in caso contrario registra esplicitamente
`transition was not observed`.

La prova live v0.2.1 ha poi isolato l'ordine di aggiornamento Steam: la
scrittura `control=0x03` veniva applicata, ma il comando inviato nello stesso
frame andava perso. Lo State Probe mostrava prima `control=0x03` ancora su
`C8`, poi locomotion/idle (`0x02`/`0x00`) senza `C9` o `CB`. v0.2.2 separa
quindi il link in due frame:

1. alla finestra valida scrive soltanto il release e conserva tipo di link e
   posizione combo desiderata;
2. dopo almeno un frame, quando `control=0x03` conferma il release, riapplica
   la posizione e invia i due flag Attack.

Il comando viene emesso anche se `C8/CC` e' ancora visibile, cosi' il motore
puo' conservare il contesto combo; se l'animazione e' gia' neutra, lo stesso
percorso avvia comunque l'attacco senza target. Un timeout di 30 frame evita
azioni ritardate se Sora entra invece in uno stato incompatibile.

### Risultato live v0.2.2

La prova live successiva conferma che la separazione in due frame applica il
release, ma non risolve la selezione del link a terra:

- dopo `C8`, `control=0x03` viene osservato e il comando target-free viene
  emesso, ma l'animazione resta `C8` oppure torna a locomotion/idle; non sono
  mai stati osservati `C9` o `CA`;
- il controller v0.2.2 registra talvolta `normal transition observed` quando
  vede `C8` ripartire da `time=0`. Questo e' un restart del primo normale, non
  una vera progressione della combo, quindi il criterio produce un falso
  positivo rispetto al requisito di gameplay;
- dopo Croce -> Triangolo, release e comando finisher vengono emessi, ma la
  verifica termina con `finisher transition was not observed` e `CB` non
  compare;
- in aria sono invece osservate piu' transizioni reali `CC -> CD` e `CD -> CC`
  senza dipendere da lock-on o hit-confirm. La parte target-free funziona
  quindi almeno per la catena aerea, pur con richieste occasionalmente perse.

La v0.2.2 va considerata parzialmente funzionante: Guard/Dodge e concatenazione
aerea costituiscono la baseline valida, mentre combo terrestre e finisher sono
problemi aperti. La prossima diagnosi deve separare esplicitamente restart e
avanzamento (`C9/CA`) e osservare quale stato o dispatcher nativo seleziona
l'entry terrestre; il solo `comboPosition` piu' i due flag Attack non e'
sufficiente sulla build Steam testata.

### Correzione candidata v0.2.3

Una lettura live read-only ha confermato `comboPosition=0` a riposo,
`maxGroundComboLength=3` e la tabella azioni Steam corrente. Le entry Critical
Mix sono traslate di `+0x3980` nella sezione dati di questa build:

| Entry | RVA Steam | Valore vanilla |
| --- | ---: | ---: |
| Ground Finisher Default | `0x2D2D7D0` | `0xCB` |
| Ground Combo Slide | `0x2D2D7E4` | `0xD0` |
| Ground Combo Impulse | `0x2D2D7F8` | `0xD3` |
| Ground Combo 2 | `0x2D2D80C` | `0xC9` |
| Ground Combo Slapshot | `0x2D2D820` | `0xCF` |
| Ground Combo A1 | `0x2D2D834` | `0xC8` |
| Ground Combo A2 | `0x2D2D848` | `0xCA` |

La v0.2.2 commetteva due errori di routing: conservava `comboPosition=1` per
ogni normale senza target, quindi il dispatcher ricreava `C8`, e impostava la
finisher a `max-1` invece che a `max`. La candidata v0.2.3:

1. mantiene Croce sotto la soglia finisher e cicla esplicitamente
   `C8 -> C9 -> CA -> C8`;
2. prima del comando sostitutivo instrada temporaneamente tutte le entry ground
   verso l'animazione desiderata, tecnica gia' usata dallo script autorizzato
   `CMix_AirRollGuardItem_Plus.lua` per gli attacchi forzati;
3. per Triangolo scrive `comboPosition=max` e instrada le entry verso `CB`;
4. ripristina i sette byte vanilla appena osserva l'animazione attesa o dopo
   otto frame; un fingerprint inatteso disabilita il routing;
5. accetta come successo soltanto l'ID richiesto, eliminando il falso positivo
   prodotto dal restart di `C8` nella v0.2.2.

Lo State Probe include ora `comboPosition/maxGroundComboLength` nella chiave di
stato e nei log, restando completamente read-only. Tutto questo e' ancora una
candidata: serve la conferma live prima di considerare risolti combo terrestre
e finisher.

### Risultato live v0.2.3 e correzione candidata v0.2.4

La cattura live v0.2.3 valida gli indirizzi e la tecnica di routing: sono state
osservate transizioni esatte `C8 -> C9`, `C9 -> CA` e `CA -> C8`. La stessa
richiesta pero' fallisce spesso con `route timed out`; il comando Attack veniva
scritto una sola volta e non sempre coincideva con il frame in cui il
dispatcher Steam lo legge. Triangolo era riconosciuto (`Triangle finisher
queued`), `comboPosition=max` e la route `CB` erano armati, ma anche quel
comando scadeva senza transizione. Il difetto quindi non era piu' la selezione
dell'animazione o il riconoscimento di Triangolo, ma l'affidabilita' del trigger
one-shot. La catena aerea usa lo stesso trigger ed e' soggetta alla medesima
perdita intermittente.

La candidata v0.2.4 sostituisce la verifica passiva con una richiesta
persistente e limitata:

1. dopo l'acknowledgement `control=0x03`, mantiene la route per un massimo di
   36 frame;
2. per un massimo di 30 frame riapplica il combo slot e pulsa Attack finche'
   l'animazione esatta viene osservata;
3. appena `actionControl` lascia `0x03`, smette di riscrivere Attack e attende
   soltanto la transizione, riducendo il rischio di un colpo duplicato;
4. blocca richieste normali sovrapposte; Triangolo puo' invece sostituire una
   richiesta normale pendente e conserva quindi la priorita' di finisher;
5. annulla e ripristina la route su cambio terra/aria, reaction command,
   timeout, Guard, Dodge, salto, reload o uscita.

Il prossimo test deve verificare non solo gli ID `C8/C9/CA/CB`, ma anche il
numero di impulsi registrato da `command accepted after N pulse(s)` e
l'assenza di colpi automatici aggiuntivi dopo una singola pressione.

### Risultato live v0.2.4 e correzione candidata v0.2.5

La v0.2.4 ha reso la concatenazione percepibilmente piu' facile e ha osservato
sia il ciclo terrestre sia `CB`. I tempi restano pero' irregolari: richieste
riuscite hanno riportato da 1 a 30 presunti impulsi, mentre numerosi link sono
scaduti al limite di 30. Una lettura esterna read-only del processo, eseguita a
riposo dopo il test, ha trovato `triggerMenu1=1` e `triggerMenu2=1`. Il retry
stava quindi mantenendo un livello alto, non generando nuovi fronti, e il
cleanup non riportava i flag allo stato neutro. Il log mostra inoltre che
ulteriori pressioni Triangle riarmavano `CB` durante un tentativo gia' attivo.

La candidata v0.2.5:

1. forza un frame basso prima della prima richiesta e alterna due frame alti a
   un frame basso, cosi' ogni retry produce un fronte `0 -> 1` reale;
2. prende ownership dei due flag soltanto durante la richiesta sintetica e li
   azzera su successo, timeout, cambio stato, reaction command, difesa, reload
   e uscita;
3. estende la finestra osservata, ma continua a smettere di pulsare quando
   `actionControl` lascia `0x03`;
4. conserva al massimo una Croce premuta durante un normale pendente e la
   riproduce sul nuovo attacco, senza convertire una pressione in piu' colpi;
5. ignora Triangle ripetuto finche' la finisher precedente e' pendente, invece
   di azzerarne il tentativo.

Il test v0.2.5 deve verificare fluidita' premendo Croce sia molto presto sia
molto tardi, una sola esecuzione per pressione, finisher con un solo Triangolo
e assenza di attacchi ritardati dopo un timeout o una reazione nemica.
