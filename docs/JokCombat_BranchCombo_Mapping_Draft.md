# JokCombat — mappatura combo ramificate X / Triangolo

Stato: **ARCHIVIATA — sostituita dalla mappa canonica univoca in
`docs/JokCombat_BranchCombo_Mapping.md`**

Ambito: KH1 Final Mix, Steam Global, Sora

Input abbreviati: `X` = Croce, `T` = Triangolo

## 1. Obiettivo

Creare un sistema nel quale ogni pressione di `X` o `Triangolo` esegue un
attacco e costruisce un percorso. La mossa successiva dipende dall'intera
sequenza già inserita, per esempio:

- `X → X → X`: ramo fisico base;
- `X → X → T`: terzo colpo alternativo;
- `X → T → T`: terzo colpo ancora diverso;
- un quarto input può trasformare il ramo in finisher, magia, Limit o attacco
  speciale concatenato.

La mappatura deve includere tutto il repertorio attivo utilizzabile da Sora,
senza confondere un'animazione con l'azione completa del gioco.

Decisione architetturale successiva alla prima bozza:

- una sequenza composta soltanto da `X` appartiene sempre a KH1 e percorre la
  combo vanilla completa;
- Sora usa quattro Combo Plus, due Air Combo Plus e un Combo Master;
- `T` da neutrale non avvia un ramo JokCombat e resta disponibile ai comandi
  contestuali nativi;
- il primo `T` dopo almeno una `X` apre la variante corrispondente alla posizione
  corrente (`XT`, `XXT`, `XXXT` e così via);
- dopo l'apertura, ulteriori `X/T` possono costruire continuazioni e finisher;
- la mappa binaria originale della sezione 4 è conservata soltanto come
  inventario preliminare e non deve essere implementata.

## 2. Tronco X nativo e punti di deviazione

La struttura non è più un albero binario che può iniziare con entrambi i tasti.
Esiste un solo tronco, formato dalle `X` vanilla, e Triangolo indica il momento
in cui abbandonarlo.

La cattura live con `groundMax=7` e `airMax=5` ha identificato questa sequenza
nativa completa:

| Posizione | Terra | Aria |
|---:|---|---|
| 1 | normale nativo fra `0xC8/0xC9/0xCA` | normale nativo osservato `0xCC/0xCD` |
| 2 | normale nativo fra `0xC8/0xC9/0xCA` | normale nativo osservato `0xCC/0xCD` |
| 3 | normale nativo fra `0xC8/0xC9/0xCA` | normale nativo osservato `0xCC/0xCD` |
| 4 | normale nativo fra `0xC8/0xC9/0xCA` | normale nativo osservato `0xCC/0xCD` |
| 5 | normale nativo fra `0xC8/0xC9/0xCA` | `0xCE` finisher |
| 6 | normale nativo fra `0xC8/0xC9/0xCA` | — |
| 7 | `0xCB` finisher | — |

La seconda cattura live ha mostrato `0xCA` alle posizioni 1, 2 e 3 e `0xC8` o
`0xC9` in posizioni differenti fra stringhe successive. KH1 sceglie quindi il
normale concreto in modo contestuale; non esiste una corrispondenza rigida fra
posizione e ID. Il controller deve usare `comboPosition` come identità del nodo
e conservare l'ID soltanto per scegliere la finestra di uscita corretta.

Le due catture del detector read-only hanno coperto tutti i prefissi:

| Contesto | Prefisso | Animazione e tempo osservati |
|---|---|---|
| terra | `XT` | `C8 @ 22` |
| terra | `XXT` | `C8 @ 17/23/28/35`, `C9 @ 32/41` |
| terra | `XXXT` | `C8 @ 26` |
| terra | `XXXXT` | `C9 @ 35/45` |
| terra | `XXXXXT` | `C8 @ 29` |
| terra | `XXXXXXT` | `C9 @ 28/40` |
| aria | `XT` | `CC @ 22/23` |
| aria | `XXT` | `CD @ 19` |
| aria | `XXXT` | `CC @ 21` |
| aria | `XXXXT` | `CD @ 23` |

Un Triangolo successivo al ritorno in neutrale è stato lasciato correttamente a
KH1. Le ripetizioni sullo stesso nodo confermano inoltre che il controller
esecutivo dovrà accettare un solo Triangolo per attacco.

Il primo controller può riusare le finestre conservative già validate per la
combo Croce: prebuffer da `14` su `C8/C9`, `16` su `CA`, `8` su `CC` e `10` su
`CD`; esecuzione non prima di `18`, `34`, `20`, `12` e `14` rispettivamente.
La separazione `C9: 14 -> 34` è intenzionale: ricorda un solo Triangolo ma non
tronca l'affondo visibile. Ogni input prima del prebuffer viene scartato, il
primo valido possiede il nodo e le ripetizioni vengono ignorate.

I punti iniziali disponibili per una deviazione sono:

- `XT`: deviazione immediata dopo il primo attacco;
- `XXT`: deviazione dopo il secondo;
- `XXXT`: deviazione dopo il terzo;
- `XXXXT`, `XXXXXT` e `XXXXXXT`: le altre tre aperture a terra;
- `XXXXT` è l'ultima apertura in aria prima di `0xCE`;
- nessun Triangolo significa combo e finisher interamente vanilla.

Le pressioni Croce inviate durante la parte iniziale di `CB` ai tempi `0`, `10`
e `22` sono state correttamente scartate; il bridge terrestre si apre al tempo
`67`. Il bridge aereo è stato confermato: a tempo `20` su `CE` riapre `CC` e
mantiene la combo infinita finché Sora resta in aria.

Il primo `T` deve eseguire subito una mossa: non è un semplice cambio modalità
invisibile. Una volta iniziata la variante, ulteriori `X/T` possono scegliere
continuazioni fisiche, magie o finisher, ma la loro profondità verrà decisa solo
dopo aver assegnato le aperture. Le magie resteranno raggruppate per famiglia:
per esempio il nodo `Fire` lancerà il grado disponibile fra Fire, Fira e Firaga.

## 3. Inventario completo dei candidati

### 3.1 Attacchi normali e difesa

| Candidato | Terra | Aria | Ruolo proposto | Stato tecnico |
|---|---|---|---|---|
| Attacco normale 1 | `0xC8` | `0xCC` | apertura | già gestito |
| Attacco normale 2 | `0xC9` | `0xCD` | continuazione | già gestito; il thrust richiede link tardivo |
| Attacco normale 3 | `0xCA` | `0xCE` | continuazione / finisher aerea | già gestito |
| Finisher fisica standard | `0xCB` | `0xCE` | terminale | già gestita |
| Finisher fisica ad area | variante nativa da identificare | variante nativa da identificare | terminale alternativo | da sondare |
| Launcher / ciclo aereo | variante da definire | ripartenza `0xCC` dopo `0xCE` | terminale di mobilità | parzialmente gestito |
| Guard | fisso su `L2 + O` | ponte a terra già supportato | priorità difensiva, non nodo combo | già gestito |
| Dodge Roll | fisso su Quadrato | non applicabile | priorità difensiva, non nodo combo | già gestito |

Le varianti visive vanilla della combo normale non vengono considerate azioni
separate finché una probe non dimostra record distinti e instradabili. Non basta
forzarne l'ID d'animazione.

### 3.2 Action Ability

Queste sono le 11 mosse già presenti nell'`ACTION_CATALOG` di JokCombat.

| Action Ability | Contesto nativo | Ruolo | Dispatcher JokCombat | Nota / fallback |
|---|---|---|---|---|
| Slapshot | terra | colpo rapido | record completo; ponte aereo | in aria usa il bridge già collaudato |
| Sliding Dash | terra | inseguimento | record completo; ponte aereo | adatta al ramo di mobilità |
| Vortex | terra | controllo ravvicinato | record completo; ponte aereo | non-finisher |
| Aerial Sweep | terra verso aria | launcher | record completo | naturale come passaggio terra/aria |
| Counterattack | dopo una difesa valida | contrattacco | record completo, contestuale | senza finestra valida: attacco normale 3 |
| Blitz | terra | finisher fisica | record completo; ponte aereo | deve produrre hit ed effetto nativi |
| Hurricane Blast | aria | finisher aerea | record completo | a terra: Aerial Sweep come fallback |
| Ripple Drive | terra | finisher ad area | record completo; selector nativo | effetto completo obbligatorio |
| Stun Impact | terra | finisher ad area / stun | record completo + selector al 100% | effetto completo obbligatorio |
| Gravity Break | terra | finisher con effetto Gravity | record completo; selector nativo | effetto completo obbligatorio |
| Zantetsuken | terra | finisher pesante | record completo; selector nativo | non deve condividere il dispatcher di Gravity Break |

### 3.3 Magie

La lista completa comprende sette famiglie e 21 gradi:

| Famiglia mappata | Gradi coperti | Terra | Aria | Requisito tecnico |
|---|---|---|---|---|
| Fire | Fire / Fira / Firaga | sì | sì | chiamata magica nativa |
| Blizzard | Blizzard / Blizzara / Blizzaga | sì | sì | chiamata magica nativa |
| Thunder | Thunder / Thundara / Thundaga | sì | sì | chiamata magica nativa |
| Cure | Cure / Cura / Curaga | sì | sì | chiamata magica nativa |
| Gravity | Gravity / Gravira / Graviga | sì | sì | chiamata magica nativa |
| Stop | Stop / Stopra / Stopga | sì | sì | chiamata magica nativa |
| Aero | Aero / Aerora / Aeroga | sì | sì | chiamata magica nativa |

La sequenza sceglie la famiglia; il gioco sceglie il grado disponibile. Il
dispatcher deve preservare MP, targeting, potenza, effetti, animazione aerea o
terrestre e fallimento nativo. Forzare soltanto le animazioni `0x36–0x3D` o
`0x84–0x8A` non è sufficiente.

### 3.4 Special Ability / Limit

| Candidato | Contesto | Avvio noto nei riferimenti autorizzati | Vincoli da conservare |
|---|---|---|---|
| Sonic Blade | principalmente terra, bersaglio a media distanza | Reaction `0x004B` | MP, bersaglio, sequenza di follow-up |
| Ars Arcanum | terra, distanza ravvicinata | Reaction `0x0057` | MP, bersaglio, Bash/Finish nativi |
| Strike Raid | principalmente terra, distanza | Reaction `0x005E` | MP, bersaglio, lanci e rientro del Keyblade |
| Ragnarok | aria / bersaglio aereo | Reaction `0x005A` | MP, lock-on e follow-up Impact |
| Trinity Limit | party disponibile | Reaction `0x0052` nei riferimenti CMix | stato alleati, MP e controllo completo del Limit |

Queste mosse devono possedere il controllo fino alla conclusione nativa. I loro
prompt interni e follow-up non devono essere interpretati come nuovi input del
generico albero X/T.

### 3.5 Passive strutturali validate prima dell'albero

Combo Plus, Air Combo Plus e Combo Master sono ora assegnate ed equipaggiate
nella lista abilità nativa di Sora. JokCombat v0.6.12 consegna a KH1 ogni Croce
normale e conserva soltanto un bridge post-finisher per riaprire il ciclo
infinito dopo `CB` o `CE`.

| Passiva | Effetto nativo | Risultato live / domanda residua |
|---|---|---|
| Combo Plus | aggiunge un attacco alla combo terrestre e può essere cumulata | quattro copie attive; live `groundMax=7`, selezione contestuale `C8/C9/CA`, `CB` alla posizione 7 |
| Air Combo Plus | aggiunge un attacco alla combo aerea e può essere cumulata | due copie attive; live `airMax=5`, normali osservati `CC/CD`, `CE` alla posizione 5 |
| Combo Master | continua la combo quando un attacco non colpisce | validata: sostituisce i pulse target-free e la memoria custom |

La richiesta iniziale di JokCombat era poter continuare la combo anche senza
target. Il test live ha confermato che Combo Master risolve nativamente la
continuazione dopo un mancato hit, evitando di duplicarla nel controller.

Il test A/B isolato ha prodotto questi risultati:

1. sono stati verificati gli offset Steam del record `Character`, degli AP e
   della lista abilità;
2. Combo Master continua la stringa senza bersaglio con normali interamente
   gestiti da KH1;
3. una Combo Plus e una Air Combo Plus estendono le rispettive stringhe native;
4. la finisher e gli attacchi intermedi non richiedono più record normali
   forzati da JokCombat;
5. la configurazione scelta è il massimo vanilla: quattro Combo Plus e due Air
   Combo Plus; la stringa completa `7/5` è stata catturata e verificata.

La decisione è quindi usare abilità native realmente equipaggiate e persistenti
nel salvataggio. La precedente proposta delle «Core Passive virtuali» è
ritirata.

### 3.6 Altre capacità reali, ma non nodi eseguibili

Queste capacità fanno parte del repertorio di Sora, ma non sono mosse da
assegnare a una sequenza:

- Critical Plus, MP Rage, MP Haste, Leaf Bracer e simili: support/passive;
- High Jump, Mermaid Kick, Glide e Superglide: movimento condiviso;
- Scan, Treasure Magnet, Lucky Strike, Cheer e abilità economiche/statistiche;
- abilità dei membri del party;
- azioni contestuali del mondo e Reaction Command mostrate dal gioco.

Queste restano sistemi globali o contestuali. Possono influenzare JokCombat, ma
non consumano un nodo dell'albero.

### 3.7 Pool sperimentale derivato dai riferimenti Critical Mix

Nei file autorizzati compaiono inoltre:

- Unsealing Strikes;
- Sky Climber;
- Ripple Slide;
- Stun Blitz;
- Chain Attack;
- Zantetsu Prime;
- Overload;
- Critical Counter;
- Style: Limit;
- Streak;
- All For One / Trinity Limit;
- Mage Warp.

Non sono tutte azioni atomiche equivalenti alle Action Ability vanilla: alcune
sono passive, stance, modificatori o catene di Reaction Command. Vanno tenute
nel **pool fase B** e analizzate una per una. La sola eccezione proposta nella
prima mappa è `Chain Attack / Burst`, perché il riferimento autorizzato espone
già la Reaction `0x0063` e la abilita dopo specifiche finisher. Resta comunque
sperimentale. Non inserirei le altre sostituendo una mossa nota senza aver prima
isolato:

1. condizione di ingresso;
2. record o Reaction ID;
3. hitbox/effect dispatcher;
4. condizione di uscita;
5. compatibilità terra/aria.

## 4. Mappa completa proposta dopo la cattura live

### 4.1 Regola di lettura

Il tronco precedente al primo Triangolo è abbreviato con `P`:

| Simbolo | Sequenza nativa già eseguita | Disponibile |
|---|---|---|
| `P1` | `X` | terra e aria |
| `P2` | `XX` | terra e aria |
| `P3` | `XXX` | terra e aria |
| `P4` | `XXXX` | terra e aria |
| `P5` | `XXXXX` | solo terra |
| `P6` | `XXXXXX` | solo terra |

Dopo `P` il ramo ammette al massimo tre input e comprende tutte le sette
combinazioni possibili: `T`, `TX`, `TT`, `TXX`, `TXT`, `TTX`, `TTT`. La
sequenza completa si ottiene concatenando le due parti: per esempio
`P3 + TXT` significa `XXX` + `TXT`, cioè `XXXTXT`.

Ogni input esegue una mossa. `T`, `TX` e `TT` sono nodi interni formati da
Action Ability concatenabili; i quattro nodi di profondità 3 sono foglie e
chiudono il ramo. In questo modo i Limit compaiono soltanto come terminali e,
una volta iniziati, ricevono direttamente da KH1 i propri follow-up nativi.
Non serve un quarto input di ramo: sei ingressi a terra e quattro in aria
producono già 42 + 28 = 70 nodi completamente assegnati.

Il tronco senza Triangolo resta interamente nativo:

- terra: posizioni `1..6` normali contestuali, posizione `7` = `CB`;
- aria: posizioni `1..4` normali, posizione `5` = `CE`;
- il bridge post-finisher riapre poi una nuova stringa X;
- `T` neutrale non appartiene alla mappa e resta un comando KH1.

### 4.2 Terra — tutte le 42 combinazioni

Categorie mnemoniche dei prefissi:

- `P1`: rapidità e contrattacco;
- `P2`: mobilità e finisher fisiche;
- `P3`: magie elementali e cura;
- `P4`: magie di controllo e area;
- `P5`: Limit individuali;
- `P6`: terminali massimi e ramo sperimentale.

| Suffisso dopo P | `P1 = X` | `P2 = XX` | `P3 = XXX` | `P4 = XXXX` | `P5 = XXXXX` | `P6 = XXXXXX` |
|---|---|---|---|---|---|---|
| `T` | Slapshot | Sliding Dash | Slapshot | Vortex | Sliding Dash | Blitz |
| `TX` | Vortex | Aerial Sweep | Vortex | Sliding Dash | Slapshot | Ripple Drive |
| `TT` | Sliding Dash | Vortex | Aerial Sweep | Aerial Sweep | Aerial Sweep | Stun Impact |
| `TXX` | Counterattack* | Hurricane Blast | Fire | Gravity | Sonic Blade* | Trinity Limit* |
| `TXT` | Blitz | Blitz | Blizzard | Stop | Strike Raid* | Chain Attack / Burst* |
| `TTX` | Aerial Sweep | Gravity Break | Thunder | Aero | Ars Arcanum* | Gravity Break |
| `TTT` | Hurricane Blast | Zantetsuken | Cure | Stun Impact | Ragnarok* | Zantetsuken |

Esempi espansi:

- `XTT` = Sliding Dash;
- `XXTXX` = Hurricane Blast;
- `XXXTXX` = Fire;
- `XXXXTXT` = Stop;
- `XXXXXTXX` = Sonic Blade;
- `XXXXXXTXX` = Trinity Limit.

### 4.3 Aria — tutte le 28 combinazioni

In aria i quattro prefissi devono contenere lo stesso repertorio completo. Le
Action Ability ground-native usano la sospensione fake-ground già validata;
Hurricane Blast e Aerial Sweep conservano il percorso aereo nativo.

| Suffisso dopo P | `P1 = X` | `P2 = XX` | `P3 = XXX` | `P4 = XXXX` |
|---|---|---|---|---|
| `T` | Aerial Sweep | Vortex | Ripple Drive | Zantetsuken |
| `TX` | Slapshot | Blitz | Stun Impact | Counterattack* |
| `TT` | Sliding Dash | Hurricane Blast | Gravity Break | Aerial Sweep |
| `TXX` | Hurricane Blast | Blizzard | Stop | Ars Arcanum* |
| `TXT` | Blitz | Thunder | Aero | Ragnarok* |
| `TTX` | Counterattack* | Gravity | Sonic Blade* | Trinity Limit* |
| `TTT` | Fire | Cure | Strike Raid* | Chain Attack / Burst* |

Esempi espansi:

- `XTX` = Slapshot sospeso;
- `XXTT` = Hurricane Blast;
- `XXTXX` = Blizzard;
- `XXXTXX` = Stop;
- `XXXXTXT` = Ragnarok;
- `XXXXTTX` = Trinity Limit.

### 4.4 Copertura del repertorio

La mappa contiene, sia complessivamente sia nel contesto aereo:

- tutte le 11 Action Ability: Slapshot, Sliding Dash, Vortex, Aerial Sweep,
  Counterattack, Blitz, Hurricane Blast, Ripple Drive, Stun Impact, Gravity
  Break e Zantetsuken;
- tutte le sette famiglie magiche: Fire, Blizzard, Thunder, Cure, Gravity, Stop
  e Aero; KH1 sceglie il grado appreso più alto;
- tutti i cinque Limit: Sonic Blade, Strike Raid, Ars Arcanum, Ragnarok e
  Trinity Limit;
- Chain Attack / Burst come terminale sperimentale derivato dal riferimento
  autorizzato;
- nessuna Summon, come richiesto.

Guard, Dodge Roll, Combo Plus, Air Combo Plus, Combo Master e le abilità di
movimento/passive restano sistemi globali e non occupano nodi.

### 4.5 Terminali, fallback e reset

Le voci con `*` richiedono una condizione nativa o un adapter ancora da
validare. La mappa resta deterministica grazie a questi fallback:

| Voce richiesta | Condizione mancante | Fallback terra | Fallback aria |
|---|---|---|---|
| Counterattack | nessuna finestra di contrattacco | Slapshot | Aerial Sweep |
| Magia | magia non appresa o MP insufficienti | Blitz per `P3`, Stun Impact per `P4` | Hurricane Blast |
| Sonic Blade / Strike Raid / Ars Arcanum | bersaglio o contesto non valido | Blitz | Hurricane Blast |
| Ragnarok | bersaglio aereo/lock-on non valido | Aerial Sweep | Hurricane Blast |
| Trinity Limit | party o MP non validi | Stun Impact | Hurricane Blast |
| Chain Attack / Burst | Reaction sperimentale non disponibile | Blitz | Hurricane Blast |

Una foglia chiude sempre l'albero. Dopo un'Action Ability o una magia, la
prossima Croce apre una nuova stringa nativa; Triangolo torna vanilla finché non
è stata accettata almeno una nuova Croce. Durante un Limit, invece, ogni X/T
successivo appartiene esclusivamente alla macchina a stati del Limit. Guard,
Dodge, salto, danno subito, cambio stato terra/aria o Reaction Command azzerano
subito la cronologia JokCombat.

## Appendice A — prima mappa completa superata, solo riferimento

> Questa tabella precede la decisione «tutto X = vanilla, primo T = apertura».
> Non va implementata: è stata sostituita dalla mappa esaustiva della sezione 4,
> costruita dopo la cattura `groundMax=7` e `airMax=5`.

Ogni riga indica la mossa eseguita **sull'ultimo input della sequenza**. Gli
input precedenti hanno già eseguito i rispettivi nodi del loro prefisso.

### Profondità 1

| Sequenza | Terra | Aria | Tipo |
|---|---|---|---|
| `X` | Attacco normale 1 (`0xC8`) | Attacco normale 1 (`0xCC`) | fisico base |
| `T` | Slapshot | Slapshot con ponte aereo | Action Ability |

### Profondità 2

| Sequenza | Terra | Aria | Tipo |
|---|---|---|---|
| `XX` | Attacco normale 2 (`0xC9`) | Attacco normale 2 (`0xCD`) | fisico base |
| `XT` | Sliding Dash | Sliding Dash con ponte aereo | Action Ability / mobilità |
| `TX` | Vortex | Vortex con ponte aereo | Action Ability |
| `TT` | Aerial Sweep | Aerial Sweep | Action Ability / launcher |

### Profondità 3

| Sequenza | Terra | Aria | Tipo / fallback |
|---|---|---|---|
| `XXX` | Attacco normale 3 (`0xCA`) | Finisher aerea (`0xCE`) | fisico base |
| `XXT` | Blitz | Blitz con ponte aereo | Action Ability finisher |
| `XTX` | Counterattack se valido | Counterattack se valido | altrimenti attacco normale 3 |
| `XTT` | Stun Impact | Stun Impact sospeso | Action Ability finisher |
| `TXX` | Ripple Drive | Ripple Drive sospeso | Action Ability finisher |
| `TXT` | Gravity Break | Gravity Break sospeso | Action Ability finisher |
| `TTX` | Aerial Sweep | Hurricane Blast | variante contestuale terra/aria |
| `TTT` | Zantetsuken | Zantetsuken sospeso | Action Ability finisher |

### Profondità 4

| Sequenza | Azione terminale | Contesto / fallback | Dispatcher richiesto |
|---|---|---|---|
| `XXXX` | Finisher fisica standard | `0xCB` terra, `0xCE` aria | record completo già noto |
| `XXXT` | Fire | grado disponibile | magia nativa |
| `XXTX` | Blizzard | grado disponibile | magia nativa |
| `XXTT` | Thunder | grado disponibile | magia nativa |
| `XTXX` | Gravity | grado disponibile | magia nativa |
| `XTXT` | Stop | grado disponibile | magia nativa |
| `XTTX` | Aero | grado disponibile | magia nativa |
| `XTTT` | Cure | grado disponibile | magia nativa |
| `TXXX` | Finisher fisica ad area | fallback `0xCB` / `0xCE` finché non isolata | record da sondare |
| `TXXT` | Sonic Blade | in aria: fallback finisher aerea finché non validato | Limit / Reaction nativa |
| `TXTX` | Strike Raid | in aria: fallback finisher aerea finché non validato | Limit / Reaction nativa |
| `TXTT` | Ars Arcanum | in aria: fallback finisher aerea finché non validato | Limit / Reaction nativa |
| `TTXX` | Launcher / ciclo fisico | terra: Aerial Sweep; aria: riparte da `0xCC` | record completo |
| `TTXT` | Ragnarok | a terra: Aerial Sweep; in aria: Ragnarok | Limit / Reaction nativa |
| `TTTX` | Chain Attack / Burst | solo dopo finisher compatibile; altrimenti finisher fisica | Reaction `0x0063`, sperimentale |
| `TTTT` | Trinity Limit | se party/MP non validi: finisher fisica | Limit / Reaction nativa |

Questa distribuzione ha una logica mnemonica iniziale:

- il sottoramo `X...` conserva fisico e magie;
- il sottoramo `T...` concentra mosse speciali e Limit;
- `XXXX` resta la combo fisica più semplice;
- `TTTT` è la mossa di gruppo più impegnativa;
- `TTXT` conduce naturalmente a Ragnarok attraverso il ramo aereo.

Non è ancora una scelta definitiva: lo scopo del documento è permettere di
spostare le righe prima di scrivere il controller.

## 5. Regole di priorità e sicurezza

1. **Reaction Command nativo prima di Triangolo-combo.** Se il gioco mostra un
   comando contestuale reale, `T` lo attiva e il ramo JokCombat viene sospeso o
   azzerato.
2. **Nessun ramo da Triangolo neutrale.** JokCombat può catturare `T` soltanto
   dopo almeno una `X` valida della stringa nativa.
3. **Guard prima di Dodge, Dodge prima della combo.** Entrambe interrompono e
   azzerano il ramo; un Dodge non può cancellare un altro Dodge.
4. **Le shortcut magia native restano native.** Per esempio `R1 + Quadrato` non
   deve diventare Dodge né alimentare l'albero.
5. **Un solo input anticipato.** Durante una mossa viene conservato al massimo
   il più recente input valido nella finestra di link; lo spam precedente viene
   scartato.
6. **Nessuna azione solo animata.** Action Ability, magia e Limit devono
   passare dal proprio record/selector/dispatcher completo.
7. **Fallback invece di soft-lock.** Se mancano MP, bersaglio, party, abilità,
   mondo o contesto, si esegue il fallback fisico associato e si registra la
   causa nel log.
8. **Terra e aria sono dispatcher distinti.** La stessa sequenza può avere una
   variante contestuale, ma non deve teletrasportare Sora a terra senza un ponte
   esplicitamente validato.
9. **Una finisher interna accetta il follow-up solo tardi.** Il link può aprirsi
   dopo hit/effect attivo, mai prima; una finisher su foglia chiude invece il
   ramo. Così non si tagliano bolle, shockwave e hitbox come nei vecchi prototipi.
10. **I Limit possiedono i propri follow-up.** Durante Sonic Blade, Ars Arcanum,
   Strike Raid o Ragnarok, `X/T` viene consegnato alla macchina a stati nativa
   finché il Limit termina.
11. **Nessun bersaglio non blocca la combo.** Questa responsabilità va delegata
    prima a Combo Master; un fallback custom resterà solo per eventuali casi che
    il test nativo non copre.
12. **Persistenza limitata e dichiarata.** AP massimi e tre passive combo sono
    scritture native intenzionali; Action Ability, magie e Limit sbloccati da
    JokCombat restano runtime finché non viene approvata una politica diversa.

## 6. Rischi da validare prima del controller completo

### Rischio A — continuare dopo una finisher interna

Alcuni nodi `T`, `TX` o `TT` usano Blitz, Ripple Drive, Stun Impact, Gravity
Break o Zantetsuken. Per raggiungere la foglia successiva senza tagliarne
animazione, VFX o hitbox serve una finestra di link tardiva specifica per mossa.
È il rischio tecnico principale della proposta.

Se una mossa non offre un'uscita sicura, le alternative sono:

- spostarla su una delle foglie `TXX/TXT/TTX/TTT`;
- conservare un solo follow-up e lanciarlo soltanto dopo la conclusione completa;
- sostituire il nodo interno con una Action Ability non-finisher.

### Rischio B — Triangolo appartiene già al gioco

Triangolo controlla Reaction Command e altri prompt contestuali. Il branch
controller può usarlo soltanto quando nessun comando nativo valido è attivo.

### Rischio C — famiglie contro singole varianti

Sette foglie magiche coprono 21 magie solo se il grado è risolto automaticamente.
Se vogliamo ogni grado come sequenza autonoma, anche i 70 nodi attuali perderebbero
la leggibilità e richiederebbero di sacrificare molte mosse fisiche o Limit.

### Rischio D — costi e progressione

Va decisa una politica unica:

- mosse tutte disponibili da subito, ma con costi/requisiti nativi;
- oppure solo mosse già ottenute/equipaggiate nel salvataggio;
- oppure profilo ibrido configurabile.

## 7. Decisioni richieste nella revisione

Il test A/B delle tre passive e la mappa completa sono terminati. Prima di
implementare il dispatcher bisognerà approvare o cambiare questi punti:

1. **deciso:** usare le quantità massime vanilla, quattro Combo Plus e due Air
   Combo Plus;
2. **proposto:** massimo due follow-up dopo il primo Triangolo, cioè tutti i
   suffissi fino a `TXX/TXT/TTX/TTT`;
3. **proposto:** ogni famiglia magica usa il grado più alto appreso;
4. **proposto:** usare integralmente le matrici terra/aria delle sezioni 4.2 e
   4.3;
5. **proposto:** mantenere tutti i Limit esclusivamente sulle foglie terminali;
6. **proposto:** in aria gli adapter Limit tentano il contesto nativo e usano
   i fallback della sezione 4.5 se questo non è valido;
7. **proposto:** adottare i fallback deterministici della sezione 4.5;
8. decidere se tutte le mosse sono runtime-unlocked dall'inizio;
9. **proposto:** Chain Attack / Burst su `P6+TXT` a terra e `P4+TTT` in aria;
10. decidere quali altre capacità Critical Mix del pool fase B meritano un nodo e quale
   mossa canonica eventualmente sostituirebbero.

## 8. Ordine di implementazione dopo l'approvazione

1. **completato:** probe e test A/B nativo di Combo Master, Combo Plus e Air
   Combo Plus;
2. **completato:** rimozione dalla configurazione attiva della logica custom
   resa ridondante;
3. **completato:** cattura della stringa X completa con `groundMax=7` e
   `airMax=5`;
4. **completato:** detector input/history read-only che riconosce il primo
   Triangolo dopo X, senza consumare input né eseguire nuove mosse;
5. **completato:** mappa esaustiva dei 42 nodi terra e 28 nodi aria;
6. diramazioni fisiche e 11 Action Ability con finestre di link individuali;
7. adapter magia nativo per le sette famiglie;
8. adapter Reaction/Limit, una mossa per volta;
9. Chain Attack / Burst e pool sperimentale Critical Mix fase B;
10. menu di configurazione e preset.

## 9. Fonti di inventario

- codice attuale: `JokCombat_CombatPrototype.lua` (`ACTION_CATALOG`, route
  terra/aria e controller combo);
- riferimenti locali autorizzati: `CMix_MagicHandler.lua`,
  `CMix_FasterGroundMagic.lua`, `CMix_ChainAttackReactionCommand.lua`,
  `CMix_RewardReplacement.lua` e `CMix_StatHandler.lua`;
- catalogo KH1 delle abilità: [KHWiki — Abilities in Kingdom Hearts](https://www.khwiki.com/Special_abilities);
- comportamento delle passive: [Combo Plus](https://www.khwiki.com/Combo_Plus),
  [Air Combo Plus](https://www.khwiki.com/Air_Combo_Plus) e
  [Combo Master](https://www.khwiki.com/Combo_Master);
- aggiunte Final Mix: [KHWiki — Kingdom Hearts Final Mix](https://www.khwiki.com/Kingdom_Hearts_Final_Mix).
