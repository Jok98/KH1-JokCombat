# JokCombat Development History

> Archived pre-1.0 development log. This document preserves the experiments,
> live test results, rejected approaches, and migration notes that led to the
> stable v1.0.0 design. For current installation and usage, see the repository
> README. For the release architecture, see `TECHNICAL_DESIGN.md`.

Mod combat-oriented sperimentale per **KINGDOM HEARTS FINAL MIX PC**. Il
progetto mantiene storia, reward fissi, chest, synthesis, boss e world flags
vanilla. Le sole eccezioni intenzionali sono il bootstrap nativo di High Jump,
Combo Plus, Air Combo Plus e Combo Master e il moltiplicatore globale dei drop
descritto sotto.

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
>
> **Candidato v0.6.12:** ogni Croce normale e' nuovamente posseduta da KH1.
> Combo Master decide la continuazione a vuoto, Combo Plus/Air Combo Plus
> lunghezza, attacchi intermedi e finisher; la pipeline JokCombat che forzava
> `C8/C9/CA/CB` e `CC/CD/CE` resta disabilitata. Soltanto una nuova Croce nella
> coda sicura di `CB` (tempo `67`) o `CE` (tempo `20`) resetta il cursore combo,
> rilascia il finisher per un frame e pulsa Attack senza modificare alcun record
> azione. Il dispatcher nativo sceglie quindi la nuova apertura terra/aria.
>
> **Candidato v0.9.0 — combo Pirate A/Y:** la stringa di sole `A` resta
> completamente nativa, comprese Combo Plus, Air Combo Plus, Combo Master e
> finisher. `Y` è invece l'unico tasto capace di eseguire una mossa nominata.
> Le undici Action Ability sono distribuite senza duplicati nelle famiglie
> Strong `YYY`, C2 `AYYY`, C3 `AAYYY`, C4 `AAAY` e C5 `AAAAY`. Ogni `Y`
> produce subito la propria Action Ability; non è una password attesa fino
> all'ultimo input. Un `A` dopo una mossa speciale chiude la famiglia e genera
> una sola continuazione fisica, senza poter attivare un'altra abilità.
>
> La Combo Guide riusa il Command Menu per mostrare soltanto i `Y` ancora
> disponibili nella famiglia della posizione corrente. Dopo `A`, per esempio,
> presenta `[Y] Slapshot`, `[Y][Y] Sliding Dash` e `[Y][Y][Y] Blitz`; dopo
> Slapshot rimuove la voce consumata e mostra i due follow-up. La normale
> continuazione con `A` resta implicita. Le reverse con magie e Limit sono già
> riservate nella mappa, sempre con `Y` finale, ma restano disabilitate finché
> non avranno dispatcher Steam completi per VFX, costo, bersaglio e follow-up.
>
> **Candidato v0.9.1 — reverse magiche native:** i sette percorsi Fire,
> Blizzard, Thunder, Aero, Cure, Gravity e Stop sono attivi. Ogni `A`
> intermedio resta un vero attacco fisico e conserva il prefisso soltanto se
> conduce ancora a una magia; il `Y` finale prende in prestito per un frame lo
> slot Shortcut nativo e lascia a KH1 animazione terra/aria, grado, bersaglio,
> VFX, hitbox ed effetto. I tre costi della sola famiglia lanciata vengono
> azzerati durante il cast combo e ripristinati condizionalmente alla fine:
> menu e shortcut normali continuano a consumare MP. Un journal separato copre
> anche F1/reload durante la finestra transitoria. I Limit restano disabilitati.
>
> **Collaudo v0.9.2 — Combo Guide corretta, input magico respinto:** la Guide
> nativa non dipende più dal layout colore delle notification box e il test live
> conferma `native Command Menu labels active`. Lo stesso test dimostra però che
> `0x22C9342 = 0x20` non genera un input: quel byte è la mappa del controllo
> Shortcut e `0x20` la assegna a L2. Senza L2 fisicamente premuto, KH1 termina
> quindi ancora in `native entry timeout`.
>
> **Collaudo v0.9.3 — prearm diretto respinto:** il log conferma che
> `Shortcut<-physical Y` viene scritto prima dell'ultimo input, ma KH1 non
> considera `0x04` un selettore valido per il modificatore Shortcut e termina
> ancora in timeout.
>
> **Fix v0.9.4 — due livelli di controllo coordinati:** Critical Mix mostra che
> `0x20` seleziona il controllo logico L2 come modificatore Shortcut, mentre
> `0x22C9340` decide quale controllo fisico produce L2. JokCombat prearma quindi
> `L2<-Y` (`0x04`) insieme a `Shortcut<-L2` (`0x20`) e lascia Y disponibile come
> selezione della prima casella. Entrambi i byte vengono trasferiti al journal
> del cast e ripristinati condizionalmente al frame successivo, al cancel, al
> timeout, al fault o a F1/reload.
>
> **Collaudo v0.9.5 — fake-ground ritirato:** il lock intercetta correttamente
> ogni direzione dello stick, ma il log mostra comunque `D3 -> 0x02/0x06` dopo
> un solo frame. La causa non è quindi l'input: è la conversione temporanea di
> Sora in stato terrestre a essere incompatibile con la catena aerea.
>
> **Fix v0.9.6 — dispatcher aerei nativi soltanto:** nessuna Action Ability
> ground-native modifica più `raw70`, quota o stick. La mappa terrestre conserva
> tutte le undici mosse; in aria il ramo speciale senza duplicati è
> `A A Y = Aerial Sweep`, seguito da `Y = Hurricane Blast`. Ogni altra posizione
> `Y` resta nativa e la Combo Guide non pubblicizza mosse incompatibili.
>
> **Fix v0.9.7 — ingresso aereo da ogni colpo intermedio:** dopo qualunque `A`
> della stringa aerea `CC/CD`, `Y` apre la stessa famiglia nativa con Aerial
> Sweep; il successivo `Y` richiama Hurricane Blast. Il numero di Combo Plus non
> cambia la combinazione e nessun colpo base deve essere consumato per raggiungere
> una posizione prefissata. `CE` resta protetto fino alla propria conclusione.
>
> **Fix v0.9.8 — Hurricane Blast terra/aria:** Hurricane Blast usa ora il proprio
> record completo anche nelle route terrestri. È quindi eseguibile direttamente
> a terra dalle combo e dallo slot configurabile, oltre a conservare la route
> aerea nativa; non vengono riattivati fake-ground o scritture di quota.
>
> **Fix v0.9.9 — shortcut Action solo R2:** il loadout diretto espone soltanto
> `R2 + Y/X/A/B`. `L2` non apre più un gruppo Action e `L2+R2` non esegue più
> Action Ability; `L2 + Cerchio` resta riservato esclusivamente a Guard. La mappa
> Pirate continua comunque a contenere tutte le undici Action Ability.
>
> **Fix v0.10.3 — chiusura discendente della combo aerea:** dopo qualunque colpo
> intermedio aereo, `Y` esegue Hurricane Blast e il successivo `Y` chiude con
> Aerial Sweep. L'ordine contestuale riusa i nodi canonici senza duplicare le
> abilità e lascia invariata la C3 terrestre `Aerial Sweep -> Hurricane Blast ->
> Ripple Drive`. Aerial Sweep non forza più quota, gate o velocità.
>
> **Fix v0.10.4 — finisher aerea nel ramo Y:** la combo speciale aerea inserisce
> il record nativo `CE` tra Hurricane Blast e Aerial Sweep. `CE` è un nodo
> virtuale escluso dall'Action Catalog e dalla combo normale su `A`; `Y` prima
> del tempo `20` viene scartato, mentre una nuova pressione valida instrada
> Aerial Sweep come chiusura discendente.
>
> **Fix v0.10.5 — finisher prima di Hurricane Blast:** il ramo aereo apre ora
> direttamente con `CE`; dopo la sua recovery, `Y` esegue Hurricane Blast e il
> successivo `Y` chiude con Aerial Sweep. La combo normale su `A` resta invariata.
>
> **Cleanup v0.10.6 — magia rimossa dalle combo:** i sette rami reverse magici
> e Chain Attack non appartengono più alla mappa Pirate. I test live hanno
> confermato che il remap di `Y` non entrava nel dispatcher Shortcut nativo. Le
> magie da menu e `R1` restano vanilla; sopravvive soltanto il recupero
> condizionale di un eventuale journal lasciato dalle versioni precedenti.
>
> **v0.11.0 — Sonic Blade nativo e gratuito in combo:** la reverse
> `Y A A A Y` è la prima foglia Limit attiva. Dopo il terzo `A`, JokCombat
> pubblica la Reaction nativa `0x004B`; l'ultimo `Y` rimane fisico e KH1 gestisce
> bersaglio, movimento, hitbox, danno e follow-up. Il costo Sonic viene portato
> a zero soltanto durante questa selezione e il Limit nativo, poi ripristinato
> condizionalmente a fine Limit, cancel, timeout, fault, uscita o `F1`/reload.
> Ars Arcanum, Strike Raid, Ragnarok e Trinity Limit restano parcheggiati.
>
> **v0.12.0 — tutti i Limit nativi e gratuiti in combo:** lo stesso dispatcher
> validato con Sonic Blade copre ora anche Ars Arcanum (`0x0057`), Strike Raid
> (`0x005E`), Ragnarok (`0x005A`) e Trinity Limit (`0x0052`). I primi quattro
> prendono in prestito a zero soltanto il proprio costo; Trinity conserva da un
> journal gli MP runtime di Sora, Donald e Goofy. Trinity viene proposta solo a
> terra e con Donald + Goofy nel party, perché l'animazione nativa dipende da
> entrambi. Il selettore è condiviso e può appartenere a un solo Limit per volta.
>
> **v0.13.0 — famiglie contestuali complete:** le vecchie reverse con `A` dopo
> una mossa speciale sono state rimosse. Strong/C2/C3 terminano ora
> rispettivamente in Ragnarok, Sonic Blade e Trinity Limit; C4 collega Slapshot
> a Strike Raid e C5 collega Zantetsuken ad Ars Arcanum. Le otto Action
> terrestri, i cinque Limit, Hurricane Blast/Aerial Sweep aerei e Counterattack
> dopo una Guard realmente riuscita hanno così ruoli distinti. `A` dopo un nodo
> speciale chiude sempre la famiglia e torna alla stringa vanilla.
>
> **Fix v0.13.1 — ingresso Limit dopo la fine del parent:** il `Y` finale può
> raggiungere il selector nativo nell'ultimo frame di Gravity Break o di
> un'altra Action, mentre lo stato Limit diventa visibile a LuaBackend soltanto
> dopo il ritorno intermedio a idle. Se il `Y` è stato realmente osservato,
> JokCombat conserva ora il selector per la finestra di grazia già limitata a
> 20 frame, invece di ripristinarlo appena termina il parent.
>
> **Fix v0.13.2 — ownership sicura dei Limit:** finche `raw70 >= 0x20`, KH1
> possiede completamente input e recovery del Limit. Guard, Dodge, Action
> Ability, route e pulse JokCombat vengono neutralizzati: interrompere Strike
> Raid in `ED/EE` cancellava la posa ma lasciava `raw70=0x27`, bloccando Sora.
>
> **Fix v0.13.3 — priorita ai comandi contestuali:** un Reaction ID nativo
> diverso da zero impedisce ora l'apertura della famiglia Strong nello stesso
> frame di Triangolo. Salva, Esamina e Parla restano quindi native e il primo
> Cross di conferma non viene piu soppresso da una route Vortex in attesa.
>
> **v0.14.0 — ruoli distinti e ciclo terra-aria-terra:** Strong resta burst,
> C2 diventa una famiglia corta di inseguimento, C3 conserva il controllo area,
> C4 diventa la Ultimate contestuale e C5 resta esecuzione singolo bersaglio.
> La Ultimate usa `AAAY` Slapshot, `B` per un vero jump-cancel, quindi
> Aerial Finisher -> Hurricane Blast -> Aerial Sweep. Solo dopo l'atterraggio
> naturale riprende su `Y` con Blitz e termina su `Y` con Strike Raid. Non
> scrive quota, stick o stato airborne.
>
> **v0.15.0 - High Jump:** KH1FM possiede una sola abilita' High Jump, che viene
> ora appresa ed equipaggiata al suo livello nativo pieno. Un vero primo salto
> arma inoltre una sola carica runtime per il secondo salto.
>
> **Ricerca v0.15.1-v0.15.2 ritirata:** i test hanno dimostrato che inoltrare il
> gestore Circle del salto terrestre negli stati aerei puo' mostrare `0x04`, ma
> non ricrea l'impulso fisico: KH1 torna subito a Fall. I puntatori dispatcher e
> il bridge `raw70=0` di questi due tentativi sono stati rimossi integralmente.
>
> **v0.15.3 - Multi Jump Kinetic Step:** viene portata l'architettura esatta del
> riferimento Critical Mix autorizzato. Per la sola richiesta posseduta cambia
> il byte animazione delle otto entry aeree (`0x0F`, con `0x09` per Flying),
> cancella l'azione e invia un vero comando Attack. Durante i primi 25 unita' di
> tempo di Kinetic Step applica il lift Critical Mix a `player+0x14`, scalato con
> `gameSpeed` e `player+0x284`; poi ripristina condizionalmente tutti i record.
> Non scrive `raw70`, velocita' o puntatori dispatcher. La carica resta singola,
> si sblocca soltanto dopo il rilascio del primo `B` e torna all'atterraggio.
>
> **v0.15.4 - caduta Kinetic Step controllata:** il test live ha mostrato che
> `0x0F` passa quasi subito alla caduta `0x06`, conservando un delta verso il
> terreno troppo aggressivo. Senza inventare un offset di velocita', JokCombat
> riduce al 55% soltanto il delta positivo di `player+0x14` durante quella
> caduta vanilla successiva al secondo salto. Il freno resta attivo fino a
> Landing, ma si sospende durante qualsiasi attacco aereo: Hurricane Blast,
> Aerial Sweep e le combo conservano quindi il movimento nativo. All'atterraggio
> il log riporta numero di frame e massimo delta grezzo/corretto per il tuning.
>
> **v0.15.5 - tuning caduta:** dopo il primo collaudo il fattore del freno
> post-Kinetic Step passa da `0.55` a `0.45`. La discesa risulta quindi ancora
> piu' controllata, mantenendo invariati ambito `0x06`, attacchi aerei e rilascio
> automatico su Landing.
>
> **v0.16.0 - permanenza durante gli attacchi aerei:** durante i soli attacchi
> normali `CC`, `CD` e `CE`, la componente discendente di `player+0x14` viene
> ridotta al 25%. Qualsiasi movimento verso l'alto rimane nativo. Hurricane
> Blast `D1` e Aerial Sweep `D6` sono escluse intenzionalmente, perche' la
> traiettoria verticale fa parte dell'identita' delle due Action Ability. Il
> freno viene rilasciato su Landing, Limit, stato aereo speciale o cambio del
> player object; non rende quindi persistente alcuna quota.
>
> **v0.16.1 - caduta uniforme fra i due salti:** il log live della v0.16.0 ha
> confermato `CC/CD/CE` a `20.00 -> 5.00` e la caduta post-Kinetic Step a
> `20.00 -> 9.00`. Lo stesso fattore `0.45` viene ora armato dal primo salto e
> resta valido per ogni `0x06` fino al Landing. Kinetic Step azzera soltanto il
> riferimento di quota: non aggiunge un secondo moltiplicatore, quindi dopo il
> secondo salto la caduta resta al 45% e non scende al 20.25%.

La repository contiene tre probe read-only e il primo prototipo combat:

- `JokCombat_StateProbe.lua`: rileva la build Steam Global, usa il player
  pointer Steam verificato, registra stato action/animation e lunghezze combo
  terra/aria e classifica i candidati `XT`, `XXT`, ecc. senza scrivere memoria
  né consumare Triangolo;
- `JokCombat_InputProbe.lua`: registra in sola lettura D-pad, L2/R2 e tasti
  faccia e valida gli indirizzi Steam portati prima che il prototipo scriva;
- `JokCombat_CommandMenuProbe.lua`: confronta in sola lettura controller,
  transizioni e strutture delle quattro righe native del Command Menu;
- `JokCombat_CombatPrototype.lua`: prototipo v0.16.1 con combo normali delegate
  a KH1 e un bridge post-finisher per i cicli infiniti terra/aria, quattro slot
  R2 configurabili, otto Action Ability e cinque Limit nativi nelle famiglie
  Pirate terrestri, due Action aeree separate e Counterattack contestuale,
  jump-cancel terra -> aria, Kinetic Step a carica singola, Guard
  universale su L2 + Cerchio e Dodge Roll fisso su Quadrato;
- `JokCombat_NativeAbilities.lua`: imposta 99 AP massimi e assegna tramite la
  lista abilita' nativa High Jump e le quantita' massime vanilla richieste:
  quattro Combo Plus, due Air Combo Plus e un Combo Master, tutte equipaggiate;
- `JokCombat_DropRate.lua`: imposta a `2.0x` sia il moltiplicatore degli item
  sia quello dei prize, con firma Steam verificata e ripristino condizionale;
- `docs/JokCombat_BranchCombo_Mapping.md`: mappa Pirate terrestre di 13 nodi,
  con otto Action Ability e cinque Limit nativi, famiglia aerea separata,
  Counterattack contestuale e nessuna magia combo, Chain Attack o Summon;
- `docs/JokCombat_BranchCombo_Mapping_Draft.md`: archivio delle proposte
  precedenti, incluse le matrici scartate perché duplicavano le abilità;
- `docs/CMix_AnimCancel_AbilityHandler_analysis.md`: analisi tecnica dei primi
  due script Critical Mix e architettura minima proposta.

Il prototipo combat e' stato attivato dopo la conferma live della probe input.
Perfect Guard e launcher fisico del nemico non sono ancora implementati. C4
offre invece un aerial chase tramite il salto nativo, senza simulare la quota.
Counterattack usa invece una finestra breve aperta esclusivamente dal segnale
reale di una Guard riuscita.

Il loadout Action Ability resta runtime-only e non inserisce le undici mosse
nel salvataggio. Guard e Dodge Roll restano comandi fissi; magie e Limit non
compaiono nell'editor. I cinque Limit sono accessibili soltanto dalle combo
Pirate e non vengono aggiunti alla lista abilità. High Jump e le tre famiglie
passive costituiscono una scelta strutturale del moveset e vengono
apprese/equipaggiate nativamente.

## Abilita' native di movimento e combo

`JokCombat_NativeAbilities.lua` adatta il percorso `learn_ability` del
riferimento Critical Mix autorizzato alla build Steam verificata. Nel blocco
save Steam a `0x2DE9360`, il record `Character` di Sora segue l'header di 4
byte: gli AP massimi sono a `Character+0x05` (`0x2DE9369`) e la lista delle
abilita' parte da `Character+0x40` (`0x2DE93A4`). La lista contiene 48 byte: il
bit alto indica che l'abilita' e' appresa ma disattivata; la forma con il solo
ID base e' quella equipaggiata. Il primo `0x00` e' lo slot in cui KH1 aggiunge
la prossima abilita'. JokCombat assegna ed equipaggia quantità esatte di:

- un `0x01` High Jump (`0x81` quando disattivata); KH1FM non usa i livelli
  multipli di KH2, quindi questa singola voce e' il potenziamento nativo pieno;
- quattro `0x06` Combo Plus (`0x86` quando disattivata);
- due `0x07` Air Combo Plus (`0x87` quando disattivata);
- un `0x41` Combo Master (`0xC1` quando disattivata).

Le copie già apprese con il bit alto vengono equipaggiate nello stesso slot;
quelle mancanti vengono inserite nel primo slot libero. Se un futuro premio
vanilla aggiunge una quinta Combo Plus o una terza Air Combo Plus, la v0.4.0
rimuove la copia più recente e ricompatta i 48 byte, preservando ordine e primo
terminatore `0x00`. In questo modo la progressione non può superare i massimi
naturali dopo il bootstrap anticipato.

Il modulo porta inoltre gli AP massimi di Sora a `99`: in questo modo High Jump,
le passive e le future Action Ability possono essere realmente equipaggiate dal
motore nativo anche all'inizio della partita, senza dipendere dagli AP ancora
non ottenuti dalla progressione vanilla.

La v0.2.0 ripara inoltre in modo condizionale i quattro byte che la v0.1.x
aveva scritto dieci byte prima della lista reale a causa di una conversione
EGS -> Steam uniforme non valida. Vengono ripristinati soltanto se contengono
ancora gli esatti valori iniettati da JokCombat; qualsiasi valore inatteso
disattiva il modulo senza sovrascrivere dati.

La v0.2.1 corregge la polarita' del flag nativo: `0x80` significa disabilitata,
non equipaggiata. Le tre forme `0x86/0x87/0xC1` create dalla v0.2.0 vengono
quindi convertite in-place in `0x06/0x07/0x41`, senza aggiungere duplicati.

La v0.3.0 estende il grant alle quantità massime `4/2/1`. Le sette passive
costano complessivamente 9 AP; gli AP residui dipendono dalle altre abilità già
equipaggiate e non sono quindi un controllo affidabile del numero di copie.
La v0.4.0 aggiunge l'unica voce High Jump di KH1FM senza alterare i massimi
combo; il secondo salto resta invece una carica runtime del prototipo combat.
Il test live ha verificato `groundMax=7` e `airMax=5`: a terra KH1 sceglie
contestualmente `C8`, `C9` o `CA` nelle posizioni `1..6` e `CB` chiude alla 7;
in aria le posizioni `1..4` hanno mostrato `CC/CD` e `CE` chiude alla 5. Poiché
lo stesso ID può comparire in posizioni diverse, il controller Pirate usa
`comboPosition` per scegliere C2/C3/C4/C5 e l'animazione soltanto per il timing.

Questa assegnazione e' intenzionalmente persistente: dopo un salvataggio High
Jump e le passive fanno parte della partita. Prima del primo test e' stata creata una
copia locale di `KHFM_WW.png` sotto `KH_mod/backups/saves`.

## Drop rate globale al 200%

`JokCombat_DropRate.lua` porta a `2.0x` entrambi i moltiplicatori nativi: drop
degli item e drop dei prize. Gli operandi Steam Global `0x2A63E4` e
`0x2A63EE` sono stati verificati in sola lettura sul processo supportato: prima
della patch valevano entrambi `1.0`. Il modulo controlla inoltre la firma delle
due istruzioni, scrive una sola volta all'inizializzazione e ripristina i valori
precedenti all'uscita soltanto se nessun altro script li ha cambiati. Non scrive
nel salvataggio.

Non e' esatto dire che Critical Mix sia sempre configurato al 200%: il suo
`CMix_StatHandler.lua` usa una base del 100%, 150% o 200% secondo la difficolta'
selezionata e applica poi bonus separati di Three Wishes e Lady Luck.
JokCombat sceglie invece intenzionalmente un valore base fisso del 200%,
indipendente dalla difficolta'.

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

La directory runtime contiene `JokCombat_StateProbe.lua`,
`JokCombat_CombatPrototype.lua`, `JokCombat_NativeAbilities.lua` e
`JokCombat_DropRate.lua`. La Input Probe validata e i 40 script del
pacchetto Critical Mix sono conservati, ma non caricati, nelle directory
`reference` sotto
`C:\Users\<utente>\Documents\KH_mod\reference\CriticalMix`. Backup, log e
copie runtime restano locali e non fanno parte del repository.

Per verificare la v0.16.1, premi `F1` nella console LuaBackend. Il log iniziale
deve mostrare `v0.16.1`, `Native Abilities v0.4.0 ready`,
`ground action route ready`, `aerial action route ready`,
`complete action records ready: 11/11`
`native Command Menu overlay + Combo Guide ready` e
`native Ripple Drive/Stun Impact/Gravity Break/Zantetsuken selectors ready`.
Deve inoltre comparire `Drop Rate v0.1.0 active` e
`Pirate Y map ready: 13 ground nodes, 8 ground Action routes + five native
Limits; two aerial Actions and Counterattack remain contextual`,
`native Limit combos ready: 5/5`, `successful-Guard Counterattack detector
ready` e `legacy combo-magic recovery ready`, oltre a
`family roles ready` e `ground-air Ultimate ready`. Dopo una `A`, il Command
Menu deve mostrare `[Y] Sliding Dash` e `[Y][Y] Sonic Blade`; dopo due `A`
deve mostrare Stun Impact, Ripple Drive e, con Donald e Goofy, Trinity Limit.
Dopo Sliding Dash, la Guide deve aggiornarsi a `[Y] Sonic Blade`, senza
proporre una Action Ability offensiva su `[A]`.
Nessuna sequenza deve più registrare `[magic]` o modificare lo slot Shortcut.
Solo il costo del Limit combo attivo può essere zero durante la sua finestra
posseduta e per la durata della sequenza nativa; per Trinity vengono invece
preservati gli MP dei tre membri. Ogni costo magia resta invariato. La Guide
deve aprirsi anche se i puntatori colore delle
notification box non coincidono con il baseline Steam, purché le box non siano
effettivamente in uso.
Deve inoltre comparire `native normal combo ownership ready`; durante i colpi
intermedi non devono piu' apparire `normal route armed` o
`target-free normal pulse`. Dopo una Croce valida su `CB`/`CE`, il solo bridge
registra `infinite combo restart requested natively` e poi una transizione
`restart` scelta dal dispatcher KH1.

Il primo collaudo delle famiglie Pirate va eseguito senza spammare: ogni input
successivo deve cadere nella coda visibile della mossa precedente. Verifica in
quest'ordine, prima senza bersaglio e poi contro un nemico:

- `YYY`: Vortex -> Gravity Break -> Ragnarok;
- `AYY`: attacco nativo -> Sliding Dash -> Sonic Blade;
- `AAYYY`: due attacchi nativi -> Stun Impact -> Ripple Drive -> Trinity Limit,
  soltanto a terra con Donald + Goofy nel party.
- Ultimate C4: `AAAY` -> Slapshot, poi `B` -> salto reale, quindi `YYY` ->
  Aerial Finisher -> Hurricane Blast -> Aerial Sweep; dopo l'atterraggio
  naturale `YY` -> Blitz -> Strike Raid;
- `AAAAYY`: quattro attacchi nativi -> Zantetsuken -> Ars Arcanum;
- combo aerea dopo qualunque colpo intermedio: Aerial Finisher `CE` ->
  Hurricane Blast -> Aerial Sweep;
- secondo salto: `B`, una o piu' `A` in aria, poi `B`; il log deve mostrare
  `first native jump confirmed`, `first-jump B released`, `Kinetic Step
  requested` e `Kinetic Step accepted`. Lo State Probe deve osservare
  `anim=0x0F`, Sora deve guadagnare quota e una nuova combo aerea deve ripartire
  dal primo colpo. Un terzo `B` non deve creare un altro Kinetic Step prima
  dell'atterraggio. Se Sora torna alla caduta `0x06`, il log di Landing deve
  includere `free-fall brake: factor=0.45` con almeno un frame corretto. La
  stessa riga deve comparire anche dopo un primo salto lasciato terminare senza
  usare Kinetic Step;
- durante una combo aerea `A`, `A`, `A`, la discesa di `CC/CD/CE` deve essere
  sensibilmente ridotta. Al Landing il log deve includere
  `[air-attack] descent brake: factor=0.25`; Hurricane Blast e Aerial Sweep
  devono invece mantenere la traiettoria verticale precedente;
- Guard riuscita `L2+Cerchio`, poi `A` senza modificatori: Counterattack.

Ogni passaggio Action valido registra `[branch] <sequenza> requested` e poi
`[branch] <sequenza> accepted`. Un input premuto troppo presto deve produrre
`ignored before prebuffer`; un secondo input durante lo stesso buffer deve
essere ignorato, non accodato. Per ogni Limit, il parent Action deve registrare
`native <Limit> pre-armed`; l'ultimo `Y` deve registrare
`delegated to native <Limit>` e poi `native <Limit> entered`. Verifica con MP a
zero che Sonic, Ars, Strike e Ragnarok partano comunque e che, terminata la
sequenza, lo stesso Limit lanciato dal menu conservi il costo vanilla. Trinity
deve lasciare invariati gli MP di Sora, Donald e Goofy; senza entrambi gli
alleati non deve comparire nella Guide né sostituirsi con un'altra mossa.
Una Guard mancata non deve mostrare Counterattack; una Guard che intercetta
realmente un colpo deve registrare `successful Guard observed`, mostrare
`[A] Counterattack` e accettare una sola Croce nella finestra di 35 frame.

Tieni `R2` da solo per visualizzare e configurare l'unico gruppo Action. Il
riepilogo mostra sempre un massimo di quattro righe nel Command Menu originale
in basso a sinistra. Premi `Su/Giu`
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
salva automaticamente. Limite live noto della v0.6.10: premere Croce mentre il
cursore si trova sulla seconda o terza riga permette ancora a KH1 di aprire
rispettivamente Magic o Items prima del ripristino su Attack. Fino alla fix,
torna sulla prima riga oppure rilascia e ripremi il modificatore prima di usare
la scorciatoia su Croce. Se Summon non e' ancora sbloccato, il menu espone
soltanto le prime tre righe e il log indica
`visible=3/4 (Summon locked)`. Il quarto shortcut R2 resta eseguibile con
il valore gia' presente nel file di configurazione, ma diventa selezionabile
nel menu solo quando KH1 crea naturalmente la quarta riga. Da quel momento il
log passa a `visible=4/4` e l'editor la include automaticamente.

Premi e rilascia `L1 + R1 + L2 + R2` senza D-pad per alternare persistentemente
il riepilogo. Per ripristinare gli undici default, tieni gli stessi quattro
shoulder, premi `D-pad Giu` e poi rilascia: il reset viene salvato e non cambia
lo stato on/off del riepilogo. Il precedente editor nei box di notifica e' stato
rimosso.

I quattro default R2 sono tutti differenti; le altre Action Ability rimangono
disponibili nella mappa Pirate:

| Slot | Action Ability |
| --- | --- |
| `R2 + Croce` | Gravity Break |
| `R2 + Triangolo` | Ripple Drive |
| `R2 + Cerchio` | Hurricane Blast, terra e aria |
| `R2 + Quadrato` | Zantetsuken |

Il catalogo include tutte le azioni della tabella e anche `None`. Per eseguire
uno slot, tieni il modificatore almeno un frame prima del tasto faccia. Questo
e' obbligatorio per gli slot Croce: permette al dispatcher nativo di vedere la
route selezionata prima del fronte fisico ed evita l'attacco base intermedio.
Gli slot assegnati a un contesto incompatibile non forzano l'animazione: Croce
ricade sulla combo normale, mentre gli altri tasti restano consumati dalla
chord. Testare ogni azione prima senza target e poi su nemici, verificando
animazione, hitbox, danno e stati applicati.

Controlla infine la regressione: Croce senza modificatori deve conservare
`C8 -> C9 -> CA -> CB`, con quattro pressioni distinte. Il primo fronte che
KH1 ha gia' usato per entrare in `C8` deve produrre il log
`native Cross edge consumed by fresh 0xC8; next link not queued` e non deve
generare automaticamente anche `C9`. Le pressioni prima del tempo `14` su
`C8/C9` o del tempo `16` su `CA` devono dare
`Cross ignored before ground link prebuffer`; la prima pressione valida nella
parte finale prepara un solo link e le successive devono essere ignorate.
In aria, tre pressioni distinte devono produrre `CC -> CD -> CE`, anche senza
bersaglio. Le pressioni prima del tempo `8` su `CC` o del tempo `10` su `CD`
devono essere ignorate; la prima valida deve mostrare
`Aerial Cross input accepted` e la route attesa. Durante `CE`, Croce prima del
tempo `20` deve produrre `Cross ignored: combo finisher must end first` senza
essere conservata. Una nuova Croce da `20` in poi deve mostrare
`Aerial finisher cycle requested: CE -> CC`, quindi riaprire `CC` se Sora e'
ancora in aria. L'atterraggio deve interrompere il ciclo normalmente.
Per il test Action Ability aereo premi Croce una, due, tre o più volte prima del
finisher: da ognuna di queste posizioni `Y` deve eseguire la finisher aerea
nativa `CE`. Durante `CE`, `Y` prima del tempo `20` deve essere scartato; una
nuova pressione da `20` in poi deve eseguire Hurricane Blast `D1`; il successivo
`Y` nella sua finestra deve eseguire Aerial Sweep `D6` come chiusura.
Il log deve mostrare `context=air-native` e
una route aerea completa. La State Probe deve conservare `raw70=1/2`: non devono
più comparire `airborne action suspension armed`, `context=air-suspended` o
scritture di quota. Vortex, Slapshot, Ripple Drive, Stun Impact, Gravity Break,
Zantetsuken e le altre Action Ability terrestri non devono partire in aria e
non devono comparire nella Combo Guide aerea. Gli stessi slot restano invariati
a terra.
Durante `DC`, Quadrato senza modificatori deve produrre
`Dodge input ignored`; `L2 + Cerchio` deve dare Guard; Cerchio senza
modificatori deve saltare a terra e consumare l'unico secondo salto in aria;
Triangolo senza modificatori deve restare vanilla.
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
transizione C4 terra -> aria resta un jump-cancel nativo: Slapshot ne apre la
finestra e la state machine conserva soltanto il contesto Ultimate fino alla
chiusura dopo l'atterraggio. Per il primo test Guard e Dodge vengono resi disponibili
solo in RAM anche prima dello sblocco vanilla; il save non viene modificato.
La v0.2.10 ha confermato la transizione diretta a `0xD8`, senza uno stato `0xC8`
intermedio e senza pulse sintetici, quando L2 viene tenuto prima di Croce. La
v0.3.3 generalizza lo stesso criterio alle route configurabili e aggiunge un
dispatcher sintetico soltanto per i tasti faccia che vengono soppressi in
anticipo dal modificatore. La v0.3.4 usa record completi al posto della sola
animazione, ma il test ha dimostrato che gli effetti speciali dipendono anche
dal selettore nativo. La v0.3.5 forza temporaneamente gate finisher e tiro del
30% per Stun Impact, mantenendo vanilla il codice fuori dalla relativa chord.
La v0.3.6 applica lo stesso percorso nativo alla voce allora identificata come
Zantetsuken `0xD9` e rimuove dal
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
La v0.4.10 corregge la mappa del selettore finisher ricavata dal disassemblato
Steam: `0xD9` e il record index 4 appartengono a Gravity Break, mentre `0xDA` e
il record index 5 appartengono a Zantetsuken. Durante una shortcut mantiene
temporaneamente attivo soltanto il bit della finisher richiesta: Ripple Drive
usa il bit nativo diretto, mentre Stun Impact, Gravity Break e Zantetsuken
forzano al 100% soltanto il proprio ramo probabilistico. Al rilascio, i quattro
bit e tutte le istruzioni vengono ripristinati esattamente allo stato vanilla.
Questo dovrebbe permettere al dispatcher nativo di creare anche VFX, hitbox e
danno di Ripple Drive; la conferma finale richiede un test live sui nemici.
La v0.4.11 corregge il doppio consumo del fronte Croce nella combo terrestre.
LuaBackend puo' osservare una pressione nello stesso frame in cui KH1 l'ha gia'
usata per avviare una nuova animazione: prima quel singolo fronte apriva `C8` e
veniva anche accodato come richiesta di `C9`, portando la finisher un input in
anticipo. Ora una Croce coincidente con il frame iniziale di `C8`, `C9` o `CA`
vale soltanto per l'azione appena iniziata; gli input successivi continuano a
usare il buffer target-free e le finestre `18/18/20` restano invariate per
isolare questa correzione.
La v0.4.12 sostituisce il successivo buffer booleano one-deep con una coda di
tre fronti Croce. Se il prossimo link e' gia' preparato o in transizione, ogni
nuova pressione aumenta `normal input queued: depth=N`; a ogni nuova animazione
viene consumata una sola voce con
`queued normal input replayed on the new attack: remaining=N`. La coda viene
azzerata quando compare `CB`, evitando che lo spam oltre la finisher produca
un attacco ritardato nella combo successiva.
Il test live della v0.4.12 ha mostrato che proprio quell'azzeramento eliminava
tre input validi (`dropped=3`) e interrompeva lo spam. La v0.4.13 conserva
quindi fino a dodici fronti, non li consuma durante `CB` e ne usa uno quando
Sora torna neutrale per avviare la stringa successiva da `C8`. Il log
`queued Cross restarting ground string` identifica il riavvio; le altre voci
restano in coda e continuano a essere consumate una per ogni animazione.
La v0.4.14 rimuove questo modello dopo che il test ha mostrato attacchi
automatici prolungati oltre `CB`. Ogni animazione normale possiede ora un solo
slot, chiuso durante la parte iniziale e aperto quattro unita' prima della
finestra di link: `14` per `C8/C9`, `16` per `CA`. Lo spam anticipato non viene
registrato, una richiesta valida non puo' essere sovrascritta e `CB` non
conserva input per la stringa successiva.
La v0.4.15 separa l'apertura di quel singolo slot dal momento di rilascio
dell'animazione. `C9`, identificato dalla reference autorizzata come affondo
del Keyblade, continua ad accettare il prossimo input da tempo `14`, ma conserva
la richiesta fino a tempo `34`. In questo modo lo spam non accoda altri colpi e
non tronca la parte visibile dell'affondo; `C8` e `CA` mantengono le soglie
precedenti.
La v0.5.0 applica lo stesso modello alla combo aerea e instrada esplicitamente
i record completi `CC -> CD -> CE`. Il primo fronte Croce che avvia `CC` non
viene riutilizzato; `CC` accetta una sola richiesta da tempo `8`, `CD` da tempo
`10`, e `CE` chiude la stringa senza poter essere concatenata su se stessa.
La route non dipende dal valore di combo aerea sbloccato nel salvataggio, quindi
la finisher e' disponibile anche nelle prime sezioni del gioco.
La v0.5.1 rende la stringa ciclica mentre Sora resta realmente in aria:
`CC -> CD -> CE -> CC`. `CE` non usa il prebuffer; gli input prima del tempo
`20` vengono scartati e una nuova pressione valida instrada il record completo
`CC`. Il ciclo non modifica quota, velocita' verticale o stato airborne, quindi
la gravita' e l'atterraggio restano i limiti naturali della concatenazione.
La v0.6.0 introduce il primo gruppo di Action Ability realmente utilizzabili
in volo. Hurricane Blast conserva il proprio contesto aereo; Aerial Sweep e'
ora `both` e sceglie dinamicamente la route ground o air in base allo stato di
Sora. Entrambe usano il record completo nelle entry aeree. Le altre abilita'
restano ground-only in questa versione.
La v0.6.1 estende il contesto `both` alle altre nove Action Ability. Il port
Steam validato dell'opcode Critical Mix `0x29EF9D` e' `0x2A376D`: JokCombat lo
porta da `0x74` a `0x73` soltanto mentre una mossa ground-native viene richiesta
o resta attiva in aria, poi ripristina il byte vanilla. I quattro finisher
probabilistici conservano anche il selettore nativo e il contesto `max+1`, per
richiedere a KH1 VFX, hitbox ed effetti completi invece della sola animazione.
La patch non altera quota, gravita' o flag airborne; i risultati delle nove
nuove route devono essere confermati live una mossa alla volta.
La v0.6.2 corregge il primo test live: le route `D0`, `D7`, `D8` e `DA`
venivano accettate con `airborne=true`, ma Sora toccava terra tra i tempi
`15` e `22`, passando a Landing prima del frame attivo. Il puntatore Steam del
transform di Sora e' stato verificato in sola lettura a `0x23F09D0`. Durante
una sola mossa ground-native aerea, JokCombat conserva la coordinata verticale
`+0x14` e ne impedisce soltanto la discesa; non scrive lo stato airborne, non
blocca il movimento orizzontale e rilascia lo stall su fine azione,
atterraggio, annullamento, cambio puntatore, reload o fault.
Il test live della v0.6.2 ha poi mostrato che la coordinata catturata durante il
salto iniziale resta `0.000`, cioe' la quota del pavimento: conservarla non evita
Landing. La v0.6.3 applica quindi un sollevamento di 50 unita' soltanto nel frame
in cui l'animazione bridged richiesta viene realmente accettata, mai durante il
semplice prime del modificatore; da quel punto impedisce solo la discesa fino al
rilascio della route.
Il secondo test live ha confermato il lift `0.000 -> -50.000`, ma ha anche
individuato un conflitto separato: rilasciando Quadrato e continuando a tenere
L2, il prime passivo dello slot Croce sostituiva il bridge attivo `D0` con `D8`
al tempo `10`, interrompendo lo stall e causando Landing al tempo `20`. La
v0.6.4 assegna il bridge all'animazione realmente attiva: un prime passivo non
puo' piu' sostituirla. Durante la mossa conserva inoltre soltanto l'eventuale
selettore finisher appartenente alla stessa animazione.
Il terzo test live ha mostrato che, anche con bridge e quota correttamente
posseduti, KH1 portava `raw70` a zero durante `D0` (tempo `12`) e `D8` (tempo
`25`). La causa era il record completo terrestre copiato nelle entry aeree: i
suoi metadati comandavano direttamente il ritorno allo stato ground. La v0.6.5
segue la route usata dal riferimento autorizzato per `D0/D3/D5`: nelle entry
aeree sostituisce temporaneamente soltanto byte zero con l'animazione richiesta
e conserva tutti i metadati aerei. I record completi restano riservati alle
azioni realmente native del contesto scelto.
Il quarto test live ha validato questa separazione per Sliding Dash: con il solo
ID `D0` sui record aerei, la mossa resta airborne fino a tempo `31-35` e il
colpo fisico funziona. Ripple Drive e Stun Impact completano l'animazione fino a
tempo `35-36`, ma senza bolla/VFX: il record aereo non contiene il loro script
effetto e il selettore ground da solo non viene consultato dal dispatcher aereo.
Il quinto test live ha smentito la strategia v0.6.6: il record completo D7/D8
accoda Fall al tempo `20-22` e riscrivere `raw70` nello stesso frame arriva dopo
la decisione del motore. La v0.6.7 elimina quindi ogni scrittura dello stato
airborne. Il dispatcher legge separatamente l'ID animazione al byte zero e la
risorsa nativa nel dword `+4`; per `D7/D8/D9/DA` la route importa soltanto questi
campi e conserva movimento, stato e hit-dispatch del record aereo (`+8..+19`).
Inoltre lascia il branch `0x2A376D` al valore vanilla `0x74`: con `raw70=2`, KH1
raggiunge cosi' il proprio dispatcher risorsa aereo. Il bridge sempre-preso
`0x73` resta limitato alle mosse fisiche ground-native. In questo modo la mossa
puo' raggiungere i frame tardivi di VFX/hit senza portare con se' la transizione
terrestre a Fall.
Il sesto test live ha mostrato che la v0.6.7 mantiene correttamente D7/D8 in
aria fino al tempo `34`, ma il solo dispatcher risorsa aereo non genera ancora
VFX o danno. La v0.6.8 adotta quindi il comportamento richiesto di "terreno
sospeso": al trigger di ogni Action Ability ground-native salva stato e quota,
porta `raw70` a zero prima del comando sintetico, usa la route terrestre completa
e blocca soltanto la coordinata verticale. Alla fine o a un cancel ripristina lo
stato aereo catturato, lasciando riprendere la gravita'. Gli slot su Croce
disabilitano preventivamente l'edge fisico mentre il modificatore e' tenuto, poi
inviano un singolo pulse sintetico quando la sospensione e' gia' attiva.
Il primo test v0.6.8 ha pero' rilevato che il vecchio RVA globale posizione puo'
valere zero durante gameplay: la sospensione risultava indisponibile e, per
errore, annullava anche la route dell'abilita'. La v0.6.9 usa invece il vettore
posizione interno all'oggetto player gia' validato (`player+0x10`, verticale
`+0x14`). Se anche questa lettura fallisse, la sospensione viene saltata ma
l'Action Ability prosegue obbligatoriamente tramite la route aerea v0.6.7.
La v0.6.10 assegna priorita' alle shortcut magiche native quando L1 o R1 e'
tenuto: Quadrato non prearma piu' Dodge, non forza il dispatcher difensivo e
raggiunge invariato la magia associata. Senza modifier, Quadrato conserva il
Dodge Roll fisso e universale.
La v0.6.12 ritira dalla configurazione attiva il controller dei normali creato
fra v0.4.11 e v0.5.1. Le tre passive combo native gestiscono ora l'intera
stringa; JokCombat interviene esclusivamente dopo `CB`/`CE` per riaprire una
nuova stringa tramite un Attack nativo non instradato. Le vecchie funzioni
restano temporaneamente nel file dietro `nativeNormalAttacks=false` come
rollback diagnostico e non vengono eseguite nella configurazione distribuita.
Prima di aggiungere Limit, movement o magic cancel, ogni voce del catalogo
v0.6.10 deve essere validata live e le route devono
risultare sempre ripristinate dopo successo, timeout, Guard, Dodge, salto,
reload e perdita del player object.
