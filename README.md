# KH1 JokCombat

Mod combat-only sperimentale per **KINGDOM HEARTS FINAL MIX PC**. Il progetto
mantiene storia, progressione, reward, chest, synthesis, boss e world flags
vanilla.

## Stato attuale

> **Prototipo di ricerca v0.2.2:** Guard e Dodge Roll sono validati in gioco.
> La catena aerea senza target avanza tra `0xCC` e `0xCD`, ma la catena a
> terra continua a riavviare il solo `0xC8` e la finisher non raggiunge ancora
> `0xCB`. I messaggi `command issued` indicano una scrittura tentata, non il
> successo della transizione.

La repository contiene due probe read-only e il primo prototipo combat:

- `JokCombat_StateProbe.lua`: rileva la build Steam Global, usa il player
  pointer Steam verificato e registra lo stato action/animation senza scrivere
  memoria;
- `JokCombat_InputProbe.lua`: valida i bit fisici L2/Cerchio/Croce/Quadrato e
  gli indirizzi Steam portati prima che il prototipo possa scrivere memoria;
- `JokCombat_CombatPrototype.lua`: prototipo v0.2.2 con controller sperimentale
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

Per riprodurre lo stato v0.2.2, premi `F1` nella console LuaBackend per
ricaricare gli script. Croce ripetuto a terra riavvia attualmente il primo
normale `0xC8`; Croce -> Triangolo emette la richiesta di finisher ma non entra
in `0xCB`; in aria sono state osservate transizioni `0xCC` <-> `0xCD`. Durante
un attacco, L2 + Cerchio deve interrompere l'azione con Guard. Quadrato resta
Dodge Roll e non riceve la cancellazione universale. `F2` mostra o nasconde la
console.

In v0.2.2 il ramo Dodge viene armato prima del primo frame di Quadrato, mentre L2
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
La prova live conferma questo comportamento soltanto per parte della catena
aerea: a terra il motore seleziona ancora il primo attacco. I log distinguono
rilascio e comando `issued`; il criterio `observed` della v0.2.2 considera
anche un restart di `0xC8`, che non equivale all'avanzamento verso `0xC9/CA`.

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
La prossima iterazione deve identificare il comando o il contesto nativo che
seleziona il link a terra e deve accettare come successo soltanto `0xC9/CA` per
un normale successivo o `0xCB` per la finisher.
