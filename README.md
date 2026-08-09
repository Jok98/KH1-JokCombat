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

La repository contiene due probe read-only e il primo prototipo combat:

- `JokCombat_StateProbe.lua`: rileva la build Steam Global, usa il player
  pointer Steam verificato e registra lo stato action/animation senza scrivere
  memoria;
- `JokCombat_InputProbe.lua`: registra in sola lettura D-pad, L2/R2 e tasti
  faccia e valida gli indirizzi Steam portati prima che il prototipo scriva;
- `JokCombat_CombatPrototype.lua`: prototipo v0.3.6 con combo terrestre completa
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
nell'editor v0.3.6. Queste ultime richiedono un dispatcher diverso dalla route
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

Per verificare la v0.3.6, premi `F1` nella console LuaBackend. Il log iniziale
deve mostrare `v0.3.6`, `ground action route ready`, `aerial action route ready`,
`complete action records ready: 11/11`
e `native Stun Impact/Zantetsuken selectors ready`. Tieni prima `L2 + R2`, quindi premi
`D-pad Sinistra` per gli slot L2, `D-pad Su` per gli slot L2+R2 oppure
`D-pad Destra` per gli slot R2. Usa `Su/Giu` per scegliere lo slot e
`Sinistra/Destra` senza shoulder per cambiare abilita'. Ripeti la combinazione
di apertura dello stesso gruppo
per salvare e chiudere; usa quella opposta per passare direttamente all'altro
gruppo. `L2 + R2 + D-pad Giu` ripristina e salva immediatamente tutti gli
undici default JokCombat.

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
Prima di aggiungere Limit, movement o magic cancel, ogni voce del catalogo
v0.3.6 deve essere validata live e le route devono
risultare sempre ripristinate dopo successo, timeout, Guard, Dodge, salto,
reload e perdita del player object.
