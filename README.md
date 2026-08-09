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
> **Candidata v0.2.5 da validare live:** genera fronti reali `0 -> 1`, azzera
> sempre entrambi i trigger e conserva una sola Croce premuta mentre il link
> precedente e' in attesa. Pressioni Triangle ripetute non riavviano piu' una
> finisher gia' pendente.

La repository contiene due probe read-only e il primo prototipo combat:

- `JokCombat_StateProbe.lua`: rileva la build Steam Global, usa il player
  pointer Steam verificato e registra lo stato action/animation senza scrivere
  memoria;
- `JokCombat_InputProbe.lua`: valida i bit fisici L2/Cerchio/Croce/Quadrato e
  gli indirizzi Steam portati prima che il prototipo possa scrivere memoria;
- `JokCombat_CombatPrototype.lua`: prototipo v0.2.5 con controller sperimentale
  dei normali su Croce, richiesta contestuale della finisher su Triangolo,
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

Per provare la candidata v0.2.5, premi `F1` nella console LuaBackend per
ricaricare gli script. Il log iniziale deve mostrare `ground action route
ready`. Premi Croce con pressioni separate, anche molto prima della fine del
colpo: lo State Probe deve mostrare il
ciclo `C8 -> C9 -> CA -> C8`. Dopo almeno un normale, premi Triangolo: deve
entrare in `CB`; Triangolo da solo deve restare ignorato. Ripeti senza target e
poi contro un bersaglio. Durante un attacco, L2 + Cerchio deve continuare a
interrompere l'azione con Guard; Quadrato resta Dodge Roll. `F2` mostra o
nasconde la console.

Il ramo Dodge viene armato prima del primo frame di Quadrato, mentre L2
disabilita il salto e prepara il mapping dell'azione difensiva sul Cerchio:
Guard parte esclusivamente con la chord completa. Il Guard e' l'unica azione
che puo' scrivere il cancel state in qualunque momento, anche in aria; Dodge,
salto e link d'attacco rispettano ancora le proprie finestre. Il controller
combo usa il contatore nativo: Croce avvolge la posizione prima della soglia
finisher, mentre Triangolo la porta alla soglia soltanto se una pressione
Croce precedente ha aperto la catena. Se il gioco non consuma da solo il link,
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
La v0.2.5 deve essere confermata da una cattura live completa. Il criterio di
successo non accetta piu' un semplice restart di `C8`: richiede l'animazione
instradata esatta e `CB` per la finisher. Se il test riesce, il passo seguente
e' trasformare la sequenza fissa in un controller configurabile per action
ability, launcher e collegamento terra -> aria.
