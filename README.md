# KH1 JokCombat

Mod combat-only sperimentale per **KINGDOM HEARTS FINAL MIX PC**. Il progetto
mantiene storia, progressione, reward, chest, synthesis, boss e world flags
vanilla.

## Stato attuale

> **Risultato live v0.2.3:** Guard e Dodge Roll restano validati. La route
> terrestre e' corretta: nel log sono state osservate transizioni reali
> `0xC8 -> 0xC9 -> 0xCA -> 0xC8`, anche senza target. Tuttavia molte richieste
> scadono perche' il dispatcher perde il trigger Attack inviato per un solo
> frame. Triangolo viene rilevato e prepara `0xCB`, ma la richiesta finisher
> viene persa nello stesso modo.
>
> **Risultato live v0.2.4:** la persistenza rende piu' facile il ciclo a terra
> e valida anche la finisher `0xCB`, ma il timing resta irregolare. Una lettura
> live ha mostrato entrambi i trigger Attack ancora a `1` dopo i timeout: le
> riscritture non erano nuovi impulsi e potevano lasciare un comando pendente.
>
> **Risultato live v0.2.5:** il ciclo `C9 -> CA -> C8` e `CB` vengono accettati
> senza timeout. I fronti reali e il cleanup risolvono la perdita intermittente
> dei normali. La finisher resta pero' sospesa finche' una nuova Croce porta il
> contatore dal valore `max` alla posizione finisher effettiva.
>
> **Risultato live v0.2.6:** `max+1` viene applicato correttamente (`4/3`) e la
> route attende `CB`, ma i pulse del command menu non generano un vero evento
> Attacco: `CB` coincide ancora con la Croce fisica successiva. Dodge e'
> universale, ma un nuovo Quadrato durante `DC` riapplica il cancel e riavvia il
> roll da frame zero.
>
> **Risultato live v0.2.7:** il lock di `DC` e' validato: Quadrato viene
> ignorato durante il roll e non ne riavvia piu' il tempo. La finisher diretta
> resta invece strutturalmente dipendente da Croce: `Attack<-Triangle`, `4/3`
> e route `CB` sono corretti, ma ogni `CB` osservato coincide ancora con un
> nuovo input Croce.
>
> **Baseline pubblicata v0.2.8:** la finisher su Triangolo e' parcheggiata e
> non puo' armare richieste ritardate. La sola Croce percorre la stringa
> terrestre completa `C8 -> C9 -> CA -> CB`; dopo `CB` la combo termina e una
> nuova Croce da neutrale riparte da `C8`.
>
> **Risultato live v0.2.9:** `L2 + Croce` raggiunge realmente Stun Impact
> (`0xD8`), ma la route viene scritta troppo tardi: il dispatcher entra prima
> in `C8` e il pulse successivo avvia la finisher. Il risultato visibile e'
> quindi attacco base seguito da Stun Impact.
>
> **Risultato live v0.2.10:** tenere L2 senza Croce prepara `0xD8` su un frame
> precedente. La Croce successiva usa esclusivamente il proprio fronte fisico
> e passa direttamente a Stun Impact senza l'attacco base `C8` osservato nella
> v0.2.9. Non vengono emessi pulse di fallback; rilascio di L2, cambio stato,
> Guard, Dodge, salto, reload e uscita ripristinano la route vanilla.
>
> **Risultato live v0.3.4:** il comando speciale singolo e'
> diventato un loadout di undici slot per le Action Ability di combo. L'editor
> separa i due modificatori: `L2 + R2 + D-pad Sinistra` gestisce i tre slot L2,
> `D-pad Su` i quattro slot L2+R2 e `D-pad Destra` i quattro slot R2.
> `L2 + R2 + D-pad Giu` ripristina tutti i default. Non modifica lista abilita',
> AP o save e salva soltanto `JokCombat_ActionLoadout.cfg` accanto allo script.
> Le route terra e aria vengono applicate per la singola richiesta e ripristinate
> appena l'animazione attesa viene osservata o la richiesta scade.
> La v0.3.3 corregge inoltre il prompt HUD dopo reload: la coppia puntatori
> colore `0/0` e' uno slot vuoto valido e viene inizializzata soltanto alla
> prima apertura dell'editor, invece di disabilitare il riquadro per la sessione.
> La prova del record completo da `0x14` byte ha falsificato l'ipotesi iniziale:
> da neutrale Stun Impact esegue ancora soltanto l'animazione, mentre dopo una
> vera combo bolla, hitbox e danno compaiono con la probabilita' vanilla del 30%.
> Il record viene sempre ripristinato, ma non determina da solo l'identita'
> dell'azione scelta dal dispatcher.
>
> **Risultato live v0.3.5:** il disassemblato Steam conferma
> due controlli distinti nel selettore nativo: `0x2A6F8A` richiede il contesto
> finisher e `0x2A6FAF` scarta Stun Impact quando il valore casuale non e'
> inferiore a `0.30`. Solo mentre una chord Croce assegnata a Stun Impact e'
> armata, JokCombat abilita il relativo bit runtime e sostituisce entrambe le
> branch a due byte con NOP. Il gioco puo' cosi' selezionare il vero Stun Impact
> anche da neutrale e con esito 100%; al rilascio vengono ripristinate le quattro
> istruzioni originali. Nessun byte di abilita', AP o progressione viene scritto
> nel salvataggio. Il test in combattimento ha confermato bolla, hitbox, danno e
> attivazione deterministica tramite chord senza una combo precedente.
>
> **Candidato v0.3.6:** la precedente voce Zantetsuken puntava per errore a
> `0xDB`, identificato negli script Critical Mix come Horizontal Strike della
> sequenza Limit/Shin Zantetsuken. Il record Action Ability nativo e' `0xD9` e
> il selettore Steam lo collega al bit runtime 28 e alla branch probabilistica
> `0x2A6FC5`. La scorciatoia ora forza temporaneamente quel ramo al 100%,
> disabilitando soltanto la precedenza runtime di Stun Impact durante la
> richiesta; tutti i bit e le istruzioni originali vengono poi ripristinati.
> Animazione completa, hitbox, danno e ritorno al controllo attendono conferma
> nel test live.
>
> **Candidato v0.3.8:** tenere `L2`, `R2` oppure `L2 + R2` sostituisce
> temporaneamente fino a quattro etichette del Command Menu nativo in basso a
> sinistra. L2 presenta le tre Action Ability e `Cerchio: Guard`; R2 e L2+R2
> presentano i rispettivi quattro slot. Comandi, selezione ed effetti vanilla
> non vengono modificati: soltanto i puntatori testuali sono deviati ai
> buffer JokCombat e ripristinati al rilascio. `L1 + R1 + L2 + R2` abilita o
> disabilita persistentemente il riepilogo.
>
> **Risultato v0.3.9:** il D-pad viene isolato dal cursore vanilla e il menu
> ricompare correttamente al rilascio. Il tentativo di usare `Summon` come
> supporto grafico per una quarta riga non ancora sbloccata non viene invece
> disegnato dal gioco.
>
> **Candidato v0.4.0:** il riepilogo nativo diventa anche l'editor. Tenendo
> `L2`, `R2` oppure `L2 + R2`, `D-pad Su/Giu` seleziona una delle righe
> configurabili e `D-pad Sinistra/Destra` scorre il catalogo Action Ability.
> La riga attiva e' marcata con `+` e il file viene salvato automaticamente al
> rilascio o al cambio del modificatore. `L2 + Circle: Guard` rimane visibile
> ma fisso e viene saltato dalla selezione. Durante ogni input D-pad, cursore
> vanilla, route Attack e tasti faccia restano neutralizzati.
>
> **Esperimenti v0.4.1-v0.4.3, rimossi:** copia del record `Summon`, scrittura
> dello slot portato da Critical Mix e ampliamento del loop root da tre a
> quattro iterazioni non hanno prodotto una quarta riga visibile. La struttura
> `com_fra_d` di Summon e' separata dalle tre righe root `com_fra_c`; la v0.4.4
> non mantiene nessuno di questi hack e non scrive record, slot Summon o codice
> del renderer.
>
> **Candidato v0.4.4:** l'overlay modifica esclusivamente i token testuali
> delle righe native realmente presenti. Un quarto ID `0x00`/`0xFF` viene
> trattato come Summon bloccato: vengono mostrate e configurate tre righe. Dopo
> lo sblocco naturale, il nuovo ID non nullo viene rilevato automaticamente e
> abilita la quarta riga senza cambiare progressione o salvataggio. Un cleanup
> di migrazione ripristina una sola volta eventuali scritture rimaste attive
> passando dalle versioni sperimentali precedenti.
>
> **Candidato v0.4.5:** le etichette usano una legenda Xbox universale e
> compatta dopo il nome della mossa: Croce=`[A]`, Triangolo=`[Y]`,
> Quadrato=`[X]`, Cerchio=`[B]`. Sono caratteri KHSCII, non sprite, quindi la
> stessa legenda viene mostrata con qualunque controller e non dipende dal
> rilevamento automatico del dispositivo.
>
> **Candidato v0.4.6:** il simbolo precede il nome e tutte le schermate seguono
> l'ordine del menu Shortcut nativo: `[Y]`, `[X]`, `[A]`, `[B]`. Le abilita'
> restano associate ai loro tasti reali; cambia soltanto l'ordine visuale e di
> navigazione dell'editor.
>
> **Risultato v0.4.8, rimosso:** scrivere insieme `controller +0x14` e lo slot
> logico `+0x2C` desatura correttamente la prima riga, ma non esegue la
> trasformazione completa del cursore: il simbolo finisce dentro il testo.
>
> **Candidato v0.4.9:** `Su/Giu` non forza piu' gli indici. Per il solo impulso
> verticale l'editor ripristina temporaneamente il control-map nativo e lascia
> che KH1 muova pannello e cursore con la propria animazione completa.
> `Sinistra/Destra` restano isolati e cambiano soltanto l'Action Ability; alla
> chiusura entrambi gli slot vengono recuperati su Attack.

La repository contiene tre probe read-only e il primo prototipo combat:

- `JokCombat_StateProbe.lua`: rileva la build Steam Global, usa il player
  pointer Steam verificato e registra lo stato action/animation senza scrivere
  memoria;
- `JokCombat_InputProbe.lua`: registra in sola lettura D-pad, L2/R2 e tasti
  faccia e valida gli indirizzi Steam portati prima che il prototipo scriva;
- `JokCombat_CommandMenuProbe.lua`: confronta in sola lettura controller,
  transizioni e strutture delle quattro righe native del Command Menu;
- `JokCombat_CombatPrototype.lua`: prototipo v0.4.9 con combo terrestre completa
  e finisher su Croce, undici slot Action Ability configurabili,
  Triangolo non modificato lasciato nativo,
  jump-cancel terra -> aria, Guard universale su L2 + Cerchio e Dodge Roll
  fisso su Quadrato;
- `docs/CMix_AnimCancel_AbilityHandler_analysis.md`: analisi tecnica dei primi
  due script Critical Mix e architettura minima proposta.

Il prototipo combat e' stato attivato dopo la conferma live della probe input.
Perfect Guard, counter, launcher del nemico e aerial chase non sono ancora
implementati.

Requisito di design confermato: JokCombat fornisce dall'inizio un loadout
runtime di sole Action Ability, indipendente dallo sblocco vanilla e senza
inserirle nel salvataggio. Guard e Dodge Roll restano comandi fissi; abilita'
passive, condivise, movimento, magia e Limit a consumo MP non compaiono
nell'editor v0.4.9. Queste ultime richiedono un dispatcher diverso dalla route
Attack e verranno analizzate separatamente, senza fingere che siano gia'
supportate.

## Directory runtime prevista

La directory prevista per gli script KH1 e':

```text
C:\Users\<utente>\Documents\KH_mod\scripts\kh1
```

Dal 9 agosto 2026 il blocco `[kh1]` del `LuaBackend.toml` Steam usa soltanto
questa sorgente assoluta:

```toml
scripts = [{ path = "C:\\Users\\<utente>\\Documents\\KH_mod\\scripts\\kh1", relative = false }]
```

La directory runtime contiene `JokCombat_StateProbe.lua` e
`JokCombat_CombatPrototype.lua`. La Input Probe validata e i 40 script del
pacchetto Critical Mix sono conservati, ma non caricati, nelle directory
`reference` sotto
`C:\Users\<utente>\Documents\KH_mod\reference\CriticalMix`. Backup, log e
copie runtime restano locali e non fanno parte del repository.

Per verificare la v0.4.9, premi `F1` nella console LuaBackend. Il log iniziale
deve mostrare `v0.4.9`, `ground action route ready`, `aerial action route ready`,
`complete action records ready: 11/11`
`native Command Menu overlay ready` e
`native Stun Impact/Zantetsuken selectors ready`.

Tieni un modificatore per visualizzare e configurare il relativo gruppo: `L2`,
`R2` oppure entrambi per `L2+R2`. Il riepilogo mostra sempre un massimo di
quattro righe nel Command Menu originale in basso a sinistra. Premi `Su/Giu`
per selezionare lo slot: keyblade e riquadro colorato devono seguire la riga,
senza prefisso `+`. Premi `Sinistra/Destra` per scegliere l'Action Ability
precedente o successiva. Le
righe cambiano immediatamente e vengono salvate una sola volta quando rilasci
il modificatore o passi a un altro gruppo. Ogni gruppo segue l'ordine
`[Y]`, `[X]`, `[A]`, `[B]`; con i default L2 mostra `[Y] Slapshot`,
`[X] Sliding Dash`, `[A] Stun Impact` e `[B] Guard`. Nel gruppo L2, Su/Giu
attraversa soltanto Triangolo, Quadrato e Croce: Guard non viene modificato ed
e' la quarta etichetta quando Summon e' disponibile.

Il D-pad pilota soltanto la posizione grafica del cursore root; non deve aprire
Magic, Items o Summon e, mentre una direzione e' tenuta, nessuna mossa o tasto
faccia deve raggiungere il dispatcher di combattimento.
Rilasciare prima il modificatore mantiene questo blocco fino al rilascio del
D-pad. La configurazione non richiede una conferma: rilasciare il modificatore
salva automaticamente. Limite live noto della v0.4.9: premere Croce mentre il
cursore si trova sulla seconda o terza riga permette ancora a KH1 di aprire
rispettivamente Magic o Items prima del ripristino su Attack. Fino alla fix,
torna sulla prima riga oppure rilascia e ripremi il modificatore prima di usare
la scorciatoia su Croce. Se Summon non e' ancora sbloccato, il menu espone
soltanto le prime tre righe e il log indica
`visible=3/4 (Summon locked)`. Il quarto shortcut R2/L2+R2 resta eseguibile con
il valore gia' presente nel file di configurazione, ma diventa selezionabile
nel menu solo quando KH1 crea naturalmente la quarta riga. Da quel momento il
log passa a `visible=4/4` e l'editor la include automaticamente.

Premi e rilascia `L1 + R1 + L2 + R2` senza D-pad per alternare persistentemente
il riepilogo. Per ripristinare gli undici default, tieni gli stessi quattro
shoulder, premi `D-pad Giu` e poi rilascia: il reset viene salvato e non cambia
lo stato on/off del riepilogo. Il precedente editor nei box di notifica e' stato
rimosso.

Gli undici default sono tutti differenti:

| Slot | Action Ability |
| --- | --- |
| `L2 + Croce` | Stun Impact |
| `L2 + Triangolo` | Slapshot |
| `L2 + Quadrato` | Sliding Dash |
| `R2 + Croce` | Gravity Break |
| `R2 + Triangolo` | Ripple Drive |
| `R2 + Cerchio` | Hurricane Blast, solo in aria |
| `R2 + Quadrato` | Zantetsuken |
| `L2 + R2 + Croce` | Blitz |
| `L2 + R2 + Triangolo` | Vortex |
| `L2 + R2 + Cerchio` | Aerial Sweep |
| `L2 + R2 + Quadrato` | Counterattack, contestuale |

Il catalogo include tutte le azioni della tabella e anche `None`. Per eseguire
uno slot, tieni il modificatore almeno un frame prima del tasto faccia. Questo
e' obbligatorio per gli slot Croce: permette al dispatcher nativo di vedere la
route selezionata prima del fronte fisico ed evita l'attacco base intermedio.
Gli slot assegnati a un contesto incompatibile non forzano l'animazione: Croce
ricade sulla combo normale, mentre gli altri tasti restano consumati dalla
chord. Testare ogni azione prima senza target e poi su nemici, verificando
animazione, hitbox, danno e stati applicati.

Controlla infine la regressione: Croce senza modificatori deve conservare
`C8 -> C9 -> CA -> CB`; durante `DC`, Quadrato senza modificatori deve produrre
`Dodge input ignored`; `L2 + Cerchio` deve dare Guard; Cerchio senza
modificatori deve saltare e Triangolo senza modificatori deve restare vanilla.
`F2` mostra o nasconde la console.

Il ramo Dodge viene armato prima del primo frame di Quadrato, mentre L2
disabilita il salto e prepara il mapping dell'azione difensiva sul Cerchio:
Guard parte esclusivamente con la chord completa. Guard e Dodge possono
scrivere il cancel state in qualunque altro momento, anche in aria; una volta
iniziato `DC`, Dodge non e' autocancellabile. Guard mantiene invece priorita'
e puo' ancora interromperlo. Salto e link d'attacco rispettano ancora le
proprie finestre. Il controller combo usa il contatore nativo: Croce percorre
i tre normali e porta a `max+1` soltanto il quarto ingresso destinato a `CB`.
Triangolo non partecipa al controller JokCombat. Se il gioco non consuma da solo il link,
il fallback rilascia l'attacco esclusivamente dopo la sua finestra. La Steam
richiede due fasi: il comando Attack viene inviato nel frame successivo, dopo
che `control=0x03` ha confermato il rilascio; la posizione combo viene
riapplicata immediatamente prima del comando. Il percorso non legge lock-on,
distanza o hit-confirm ed e' progettato per funzionare anche senza bersaglio.
La v0.2.3 ha confermato che il routing esplicito seleziona davvero `C9` e `CA`;
la v0.2.4 ha confermato `CB` e che una richiesta piu' lunga aiuta, ma chiamava
"pulse" ripetute scritture del valore `1`. La v0.2.5 alterna due frame alti e
un frame basso, mantiene route e osservazione per una finestra massima
controllata e riporta i trigger a zero su ogni uscita. Il log `command accepted
after N pulse(s)` conta ora fronti alti reali. Se Croce viene premuta durante
un link pendente, `normal input buffered behind the pending link` e poi
`buffered normal input replayed on the new attack` confermano il buffer
one-deep: una pressione produce ancora un solo colpo.
La v0.2.6 porta la posizione finisher a `max+1`: `max` e' ancora l'ultimo stato
prima della selezione, motivo per cui nella v0.2.5 una Croce successiva sembrava
necessaria ad avviare `CB`. Il test ha pero' dimostrato che i due interi del
command menu non equivalgono a un ingresso Attacco autonomo. La v0.2.7 usa
quindi il byte `xControl` adiacente ai mapping Circle/Square gia' validati e
associa temporaneamente l'azione Attacco al Triangolo fisico; il monitor della
finisher osserva `CB` senza emettere anche i vecchi pulse sintetici. Il test
live dimostra pero' che neppure quel mapping genera un fronte Attacco: `CB`
resta associato alla Croce successiva. La v0.2.8 disattiva quindi l'intero
percorso custom di Triangolo e aggiunge `CB` alla sequenza esplicita di Croce;
il valore `max+1` e' ammesso dai sanity check soltanto quando l'animazione attesa
e' proprio `CB`. La v0.2.9 riusa il vantaggio strutturale di un vero fronte
Croce: quando L2 e' tenuto, tutte le entry della route terrestre vengono
temporaneamente impostate a `0xD8` e `max+1` viene ammesso anche per la richiesta
`stun-impact`. Questo bypassa la selezione casuale soltanto per la chord e non
modifica la percentuale, le abilita' equipaggiate o il salvataggio vanilla. Il
test live mostra pero' che scrivere la route sullo stesso frame della Croce e'
troppo tardi: `C8` e' gia' stato selezionato. La v0.2.10 divide quindi il comando
in due fasi: un frame L2-only pre-arma `0xD8`, mentre la Croce successiva promuove
la prime a richiesta fisica monitorata senza alcun pulse sintetico.

Non installare il probe nella cartella Critical Mix EGS indicata come fonte di
analisi: le due installazioni usano base address e script path diversi.

## Autorizzazione Critical Mix

Il 9 agosto 2026 il proprietario del progetto ha confermato di avere ricevuto
dall'autore di Critical Mix e degli script analizzati l'autorizzazione a usare
e adattare quel materiale come base per JokCombat. Il codice autorizzato puo'
quindi essere studiato, portato e rifattorizzato mantenendo attribuzione e una
traccia chiara delle parti derivate. Asset o codice EGS non devono comunque
essere caricati sulla Steam senza un porting e una validazione specifici.

## Criterio per il prossimo passo

Le finestre iniziali sono intenzionalmente conservative e configurabili. La
prima transizione terra -> aria e' un jump-cancel, non ancora un
launcher/aerial chase. Per il primo test Guard e Dodge vengono resi disponibili
solo in RAM anche prima dello sblocco vanilla; il save non viene modificato.
La v0.2.10 ha confermato la transizione diretta a `0xD8`, senza uno stato `0xC8`
intermedio e senza pulse sintetici, quando L2 viene tenuto prima di Croce. La
v0.3.3 generalizza lo stesso criterio alle route configurabili e aggiunge un
dispatcher sintetico soltanto per i tasti faccia che vengono soppressi in
anticipo dal modificatore. La v0.3.4 usa record completi al posto della sola
animazione, ma il test ha dimostrato che gli effetti speciali dipendono anche
dal selettore nativo. La v0.3.5 forza temporaneamente gate finisher e tiro del
30% per Stun Impact, mantenendo vanilla il codice fuori dalla relativa chord.
La v0.3.6 applica lo stesso percorso nativo a Zantetsuken `0xD9` e rimuove dal
catalogo l'erronea route Limit `0xDB`.
La v0.3.7 aggiunge il primo riepilogo contestuale usando due box HUD. La v0.3.8
segue il renderer originale e devia i token testuali delle righe presenti verso
quattro buffer da 0x20 byte, con record di recupero per reload inattesi e toggle
persistente. La v0.3.9 impedisce al D-pad di alterare lo slot nativo mentre il
riepilogo e' attivo; il suo carrier grafico per la quarta riga non ha funzionato.
La v0.4.0 elimina il precedente editor a box e modifica direttamente il
loadout nelle righe native, con selezione marcata, isolamento completo
degli input durante il D-pad e salvataggio automatico alla chiusura del gruppo.
Le prove v0.4.1-v0.4.3 sulla quarta riga bloccata sono state falsificate dal
test live e rimosse. La v0.4.4 modifica soltanto i token delle tre righe
esistenti finche' Summon e' bloccato, poi riconosce automaticamente il quarto
ID creato dalla progressione vanilla e abilita anche quella riga.
La v0.4.5 sostituisce i nomi estesi dei pulsanti con la legenda universale
`[A]/[Y]/[X]/[B]`, lasciando piu' spazio al nome dell'Action Ability.
La v0.4.6 porta il simbolo davanti al nome e uniforma l'ordine di ogni gruppo a
quello del menu Shortcut: `[Y] -> [X] -> [A] -> [B]`.
La v0.4.7 ha verificato che scrivere soltanto lo slot logico non muove la
grafica. La v0.4.8 ha dimostrato che scrivere anche il selettore visuale avvia
solo una parte della transizione e corrompe la posizione del simbolo. La
v0.4.9 delega invece a KH1 il solo impulso verticale e ripristina entrambi gli
slot su Attack prima che un input di combattimento venga elaborato.
Prima di aggiungere Limit, movement o magic cancel, ogni voce del catalogo
v0.4.9 deve essere validata live e le route devono
risultare sempre ripristinate dopo successo, timeout, Guard, Dodge, salto,
reload e perdita del player object.
