# JokCombat — mappatura combo ramificate X / Triangolo

Stato: **IN STANDBY — passive native validate; mappatura da revisionare insieme,
incluso il numero di copie Combo Plus/Air Combo Plus**

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

## 2. Perché servono fino a quattro input

Con due soli tasti, il numero di nodi disponibili è:

| Profondità | Nuove sequenze | Totale cumulativo |
|---:|---:|---:|
| 1 input | 2 | 2 |
| 2 input | 4 | 6 |
| 3 input | 8 | 14 |
| 4 input | 16 | 30 |

I primi 14 nodi bastano appena per tre stadi fisici normali e le 11 Action
Ability. Per integrare anche sette famiglie magiche, cinque Limit e terminali
fisici/speciali, la profondità 4 non è opzionale: è il minimo ragionevole.

La proposta usa quindi **30 nodi**. Le magie sono mappate per famiglia:

- `Fire` lancia il grado attualmente disponibile (`Fire`, `Fira` o `Firaga`).

Mappare separatamente tutti i 21 gradi magici, invece delle sette famiglie,
richiederebbe molti più nodi e toglierebbe spazio alle mosse fisiche. Un quinto
input porterebbe l'albero a 62 nodi, ma sarebbe molto meno leggibile e reattivo.

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
| Combo Plus | aggiunge un attacco alla combo terrestre e può essere cumulata | una copia equipaggiata e validata; decidere se restare a una o arrivare alle quattro copie vanilla |
| Air Combo Plus | aggiunge un attacco alla combo aerea e può essere cumulata | una copia equipaggiata e validata; decidere se aggiungere la seconda copia vanilla |
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
5. resta da confrontare una copia con le quantità massime vanilla: quattro
   Combo Plus e due Air Combo Plus.

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

## 4. Prima mappa completa da revisionare

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
2. **Guard prima di Dodge, Dodge prima della combo.** Entrambe interrompono e
   azzerano il ramo; un Dodge non può cancellare un altro Dodge.
3. **Le shortcut magia native restano native.** Per esempio `R1 + Quadrato` non
   deve diventare Dodge né alimentare l'albero.
4. **Un solo input anticipato.** Durante una mossa viene conservato al massimo
   il più recente input valido nella finestra di link; lo spam precedente viene
   scartato.
5. **Nessuna azione solo animata.** Action Ability, magia e Limit devono
   passare dal proprio record/selector/dispatcher completo.
6. **Fallback invece di soft-lock.** Se mancano MP, bersaglio, party, abilità,
   mondo o contesto, si esegue il fallback fisico associato e si registra la
   causa nel log.
7. **Terra e aria sono dispatcher distinti.** La stessa sequenza può avere una
   variante contestuale, ma non deve teletrasportare Sora a terra senza un ponte
   esplicitamente validato.
8. **Una finisher di profondità 3 accetta il quarto input solo tardi.** Il link
   può aprirsi dopo hit/effect attivo, mai prima; altrimenti si taglierebbero
   bolle, shockwave e hitbox come nei vecchi prototipi.
9. **I Limit possiedono i propri follow-up.** Durante Sonic Blade, Ars Arcanum,
   Strike Raid o Ragnarok, `X/T` viene consegnato alla macchina a stati nativa
   finché il Limit termina.
10. **Nessun bersaglio non blocca la combo.** Questa responsabilità va delegata
    prima a Combo Master; un fallback custom resterà solo per eventuali casi che
    il test nativo non copre.
11. **Persistenza limitata e dichiarata.** AP massimi e tre passive combo sono
    scritture native intenzionali; Action Ability, magie e Limit sbloccati da
    JokCombat restano runtime finché non viene approvata una politica diversa.

## 6. Rischi da validare prima del controller completo

### Rischio A — continuare dopo una finisher al terzo input

Cinque nodi di profondità 3 sono finisher. Per raggiungere il quarto nodo senza
tagliarne l'effetto serve una finestra di link tardiva, specifica per mossa. È
il rischio tecnico principale della proposta.

Se una mossa non offre un'uscita sicura, le alternative sono:

- spostarla alla profondità 4;
- attendere la conclusione completa e trattare il quarto input come avvio del
  ramo successivo;
- sostituire quel nodo di profondità 3 con una Action Ability non-finisher.

### Rischio B — Triangolo appartiene già al gioco

Triangolo controlla Reaction Command e altri prompt contestuali. Il branch
controller può usarlo soltanto quando nessun comando nativo valido è attivo.

### Rischio C — famiglie contro singole varianti

Sette nodi magici coprono 21 magie solo se il grado è risolto automaticamente.
Se vogliamo ogni grado come sequenza autonoma, quattro input non bastano senza
sacrificare molte mosse fisiche.

### Rischio D — costi e progressione

Va decisa una politica unica:

- mosse tutte disponibili da subito, ma con costi/requisiti nativi;
- oppure solo mosse già ottenute/equipaggiate nel salvataggio;
- oppure profilo ibrido configurabile.

## 7. Decisioni richieste nella revisione

Il test A/B delle tre passive è completato. Prima di implementare la mappatura
bisognerà approvare o cambiare questi punti:

1. scegliere se mantenere una copia di Combo Plus/Air Combo Plus oppure usare
   le quantità massime vanilla, rispettivamente quattro e due;
2. confermare la profondità massima di quattro input alla luce di Combo Plus e
   Air Combo Plus;
3. confermare che ogni famiglia magica usi il grado più alto disponibile;
4. scegliere se il primo `T` debba davvero essere Slapshot o una normale fisica
   alternativa;
5. approvare la posizione delle cinque Limit;
6. decidere il comportamento in aria di Sonic Blade, Strike Raid e Ars Arcanum;
7. scegliere i fallback di Counterattack, Hurricane Blast, Ragnarok, Chain
   Attack e Trinity Limit;
8. decidere se tutte le mosse sono runtime-unlocked dall'inizio;
9. confermare `TTTX = Chain Attack / Burst`, oppure scegliere un'altra mossa;
10. decidere quali altre capacità Critical Mix del pool fase B meritano un nodo e quale
   mossa canonica eventualmente sostituirebbero.

## 8. Ordine di implementazione dopo l'approvazione

1. **completato:** probe e test A/B nativo di Combo Master, Combo Plus e Air
   Combo Plus;
2. **completato:** rimozione dalla configurazione attiva della logica custom
   resa ridondante;
3. controller input/history senza nuove mosse;
4. albero fisico e 11 Action Ability con finestre di link individuali;
5. adapter magia nativo per le sette famiglie;
6. adapter Reaction/Limit, una mossa per volta;
7. Chain Attack / Burst e pool sperimentale Critical Mix fase B;
8. menu di configurazione e preset.

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
