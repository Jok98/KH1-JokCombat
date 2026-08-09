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

La repository contiene due probe read-only e il primo prototipo combat:

- `JokCombat_StateProbe.lua`: rileva la build Steam Global, usa il player
  pointer Steam verificato e registra lo stato action/animation senza scrivere
  memoria;
- `JokCombat_InputProbe.lua`: valida i bit fisici L2/Cerchio/Croce/Quadrato e
  gli indirizzi Steam portati prima che il prototipo possa scrivere memoria;
- `JokCombat_CombatPrototype.lua`: prototipo v0.2.10 con combo terrestre completa
  e finisher su Croce, Stun Impact deterministico su L2 + Croce,
  Triangolo lasciato nativo,
  jump-cancel terra -> aria, Guard universale su L2 + Cerchio e Dodge Roll
  fisso su Quadrato;
- `docs/CMix_AnimCancel_AbilityHandler_analysis.md`: analisi tecnica dei primi
  due script Critical Mix e architettura minima proposta.

Il prototipo combat e' stato attivato dopo la conferma live della probe input.
Perfect Guard, counter, launcher del nemico e aerial chase non sono ancora
implementati.

Requisito di design confermato: JokCombat deve fornire dall'inizio un proprio
loadout completo di azioni/mobilita' di Sora, indipendente dallo sblocco
vanilla, mantenendo pero' intatti save, reward e progressione della storia.
Guard e Dodge Roll sono il primo slice; High Jump, Glide e le altre action
ability verranno aggiunte tramite stato runtime validato, non inserendole nel
salvataggio.

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

Per verificare la v0.2.10, premi `F1` nella console LuaBackend per
ricaricare gli script. Il log iniziale deve mostrare `v0.2.10` e `ground action
route ready`. Da fermo e a terra tieni prima L2, quindi premi Croce: devono
comparire `stun-impact-prime route armed`, `Stun Impact route primed by L2`,
`Stun Impact requested by L2+Cross` e poi `stun-impact transition observed:
anim=0xD8`. Lo State Probe deve passare direttamente a `anim=0xD8`: non deve
piu' comparire `anim=0xC8` fra la richiesta e la finisher, e il log deve
riportare `command accepted after 0 pulse(s)`. Ripeti almeno dieci volte, prima
senza target e poi contro gruppi di nemici: ogni pressione valida deve eseguire
la mossa; contro i nemici vanno verificati anche hitbox, danno ad area e stato
stun, non soltanto l'animazione.
Durante `0xD8`, una nuova L2 + Croce deve produrre `Stun Impact input ignored`
senza riavviare il tempo della mossa. In aria L2 + Croce resta un normale
attacco aereo. Controlla infine la regressione: Croce deve conservare
`C8 -> C9 -> CA -> CB`, durante `DC` Quadrato deve produrre `Dodge input
ignored`, L2 + Cerchio deve dare Guard e Triangolo deve restare vanilla. `F2`
mostra o nasconde la console.

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
intermedio e senza pulse sintetici, quando L2 viene tenuto prima di Croce. Il
sistema puo' ora essere esteso ad altre action ability, launcher e collegamenti
aerei mantenendo lo stesso criterio: route preparata prima del fronte fisico e
cleanup completo su ogni uscita.
