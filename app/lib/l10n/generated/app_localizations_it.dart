// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'setDING';

  @override
  String get navSets => 'Set';

  @override
  String get navSongs => 'Brani';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get edit => 'Modifica';

  @override
  String get add => 'Aggiungi';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Chiudi';

  @override
  String get rename => 'Rinomina';

  @override
  String get discard => 'Scarta';

  @override
  String get untitled => 'Senza titolo';

  @override
  String errorGeneric(String error) {
    return 'Qualcosa è andato storto: $error';
  }

  @override
  String get songsEmpty =>
      'Ancora nessun brano. Crea un nuovo brano o importa file ChordPro.';

  @override
  String get searchSongs => 'Cerca brani';

  @override
  String get searchClear => 'Cancella ricerca';

  @override
  String get newSong => 'Nuovo brano';

  @override
  String get newPdfSong => 'Nuovo brano PDF';

  @override
  String get importFiles => 'Importa file';

  @override
  String get importTitle => 'Importa file ChordPro';

  @override
  String get importDescription =>
      'Supportati: .cho, .chordpro, .chopro, .crd, .pro, .txt, archivi ZIP con tali file e backup di setDING.';

  @override
  String get importGermanNotation => 'I file usano la notazione tedesca (H/B)';

  @override
  String get importGermanNotationHint =>
      'Gli accordi vengono convertiti nella notazione internazionale durante l\'importazione.';

  @override
  String get importOpenAfter => 'Apri dopo l\'importazione';

  @override
  String get importOpenAfterHint =>
      'Se viene importato un solo brano, si apre subito.';

  @override
  String get chooseFiles => 'Scegli file';

  @override
  String importResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani importati',
      one: '1 brano importato',
      zero: 'Nessun brano importato',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(String files) {
    return 'Saltati: $files';
  }

  @override
  String get deleteSongTitle => 'Eliminare il brano?';

  @override
  String deleteSongMessage(String title) {
    return '\"$title\" verrà eliminato e rimosso da tutti i set.';
  }

  @override
  String get attachmentsTooltip => 'Ha allegati PDF';

  @override
  String get keyOriginal => 'Originale';

  @override
  String get capo => 'Capotasto';

  @override
  String capoValue(int fret) {
    return 'Capotasto $fret';
  }

  @override
  String capoLabel(int fret) {
    return 'Capotasto: $fret';
  }

  @override
  String capoLabelWithKey(int fret, String key) {
    return 'Capotasto: $fret ($key)';
  }

  @override
  String capoAsInSongLabel(String capo) {
    return '$capo, come nel brano';
  }

  @override
  String get noCapo => 'Senza capotasto';

  @override
  String capoAsInSong(int fret) {
    return 'Capotasto $fret (come nel brano)';
  }

  @override
  String get allTags => 'Tutti';

  @override
  String get tagsFilter => 'Tag';

  @override
  String get filterByTags => 'Filtra per tag';

  @override
  String tagsFilterMore(String tag, int count) {
    return '$tag +$count';
  }

  @override
  String get notes => 'Le mie note';

  @override
  String get notesHint => 'Solo tu vedi questa nota.';

  @override
  String get editSource => 'Modifica ChordPro';

  @override
  String get attachments => 'Allegati';

  @override
  String get addAttachment => 'Allega file';

  @override
  String get noAttachments => 'Ancora nessun allegato.';

  @override
  String get attachmentTooLarge =>
      'Il file supera i 20 MB e non può essere allegato.';

  @override
  String get songLinks => 'Fonti';

  @override
  String get noSongLinks =>
      'Ancora nessuna fonte. Aggiungi registrazioni su YouTube, Spotify e simili.';

  @override
  String get addSongLink => 'Aggiungi link';

  @override
  String get editSongLink => 'Modifica link';

  @override
  String get deleteSongLink => 'Rimuovi fonte';

  @override
  String get deleteSongLinkMessage => 'Rimuovere questa fonte dal brano?';

  @override
  String get songLinkUrl => 'Link (URL)';

  @override
  String get songLinkLabel => 'Etichetta (facoltativa)';

  @override
  String get songLinkLabelHint => 'Live 2009';

  @override
  String get songLinkInvalid =>
      'Inserisci un link web che inizi con https:// (senza |).';

  @override
  String get songLinkFailed => 'Impossibile aprire il link.';

  @override
  String songSelectNumber(String number) {
    return 'Numero CCLI $number';
  }

  @override
  String get attachmentName => 'Nome dell\'allegato';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pagine',
      one: '1 pagina',
    );
    return '$_temp0';
  }

  @override
  String get liveView => 'Mostra in modalità live';

  @override
  String get liveViewChordPro => 'Testo ChordPro';

  @override
  String get exportSong => 'Esporta';

  @override
  String get exported => 'Esportato';

  @override
  String get fileSaved => 'Salvato';

  @override
  String get exportedOpen => 'Apri';

  @override
  String get openFileFailed => 'Nessuna app ha potuto aprire il file.';

  @override
  String get playLive => 'Suona live';

  @override
  String get live => 'Live';

  @override
  String get chordView => 'Vista accordi';

  @override
  String get useDeviceSetting => 'Come nelle impostazioni';

  @override
  String get on => 'Attivo';

  @override
  String get off => 'Disattivo';

  @override
  String get fontLarger => 'Testo più grande';

  @override
  String get fontSmaller => 'Testo più piccolo';

  @override
  String get fitToPage => 'Adatta alla pagina';

  @override
  String get resetAdjustments => 'Ripristina adattamenti personali';

  @override
  String get personalAdjustments => 'Adattamenti personali';

  @override
  String get scopePersonal =>
      'Solo per te – il brano resta invariato per tutti gli altri.';

  @override
  String get scopeSet => 'Per questo set – vale per tutta la band.';

  @override
  String get scopeBand => 'Per tutta la band – vale in tutti i suoi set.';

  @override
  String get scopeSong =>
      'Per il brano – lo modifica per tutti nell\'organizzazione.';

  @override
  String get keyPickerPersonal => 'La mia tonalità – solo per me';

  @override
  String get keyPickerSet => 'Tonalità in questo set – per tutta la band';

  @override
  String get keyPickerBand => 'Tonalità della band – per tutti i suoi set';

  @override
  String get editTitle => 'Modifica titolo';

  @override
  String get title => 'Titolo';

  @override
  String get artist => 'Artista';

  @override
  String get noContent => 'Questo brano non ha ancora un testo ChordPro.';

  @override
  String get addChordPro => 'Aggiungi testo ChordPro';

  @override
  String keyLabel(String key) {
    return 'Tonalità: $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForDegrees =>
      'I numeri Nashville e i numeri romani richiedono una tonalità nel brano.';

  @override
  String get firstVerseChordsOnly => 'Accordi solo nella strofa 1';

  @override
  String get noVersesForFirstVerseChords =>
      'Il brano non ha altre strofe con accordi.';

  @override
  String get verseChords => 'Accordi nelle strofe';

  @override
  String get verseChordsAll => 'Accordi in tutte le strofe';

  @override
  String get verseChordsStacked => 'Strofe impilate';

  @override
  String get chorusesStacked => 'Ritornelli impilati';

  @override
  String get editorTitleNew => 'Nuovo brano';

  @override
  String get editorTitleEdit => 'Modifica brano';

  @override
  String get editorTab => 'Testo';

  @override
  String get previewTab => 'Anteprima';

  @override
  String get insertVerse => 'Inserisci verse';

  @override
  String get insertChorus => 'Inserisci chorus';

  @override
  String get insertBridge => 'Inserisci bridge';

  @override
  String get insertComment => 'Inserisci commento';

  @override
  String get insertChord => 'Inserisci accordo';

  @override
  String get discardChangesTitle => 'Scartare le modifiche?';

  @override
  String get discardChangesMessage =>
      'Le tue modifiche non sono ancora state salvate.';

  @override
  String get sectionVerse => 'Verse';

  @override
  String get sectionChorus => 'Chorus';

  @override
  String get sectionBridge => 'Bridge';

  @override
  String get sectionTab => 'Tab';

  @override
  String get sectionGrid => 'Grid';

  @override
  String get setsEmpty =>
      'Ancora nessun set. Crea un set per il tuo prossimo concerto.';

  @override
  String get newSet => 'Nuovo set';

  @override
  String get editSet => 'Modifica set';

  @override
  String get setName => 'Nome';

  @override
  String get gigDate => 'Data';

  @override
  String get venue => 'Luogo';

  @override
  String get noDate => 'Nessuna data';

  @override
  String get pickDate => 'Scegli data';

  @override
  String get clearDate => 'Rimuovi data';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
      zero: 'Vuoto',
    );
    return '$_temp0';
  }

  @override
  String offlineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani non offline',
      one: '1 brano non offline',
    );
    return '$_temp0';
  }

  @override
  String get offlineMissingTooltip =>
      'Non tutti i brani e i PDF di questo set sono sul dispositivo. Collegalo alla rete e attendi la sincronizzazione.';

  @override
  String syncStale(String time) {
    return 'Ultima sincronizzazione con il server: $time. I set su questo dispositivo potrebbero non essere aggiornati.';
  }

  @override
  String get syncStaleNever =>
      'Questo dispositivo non si è ancora sincronizzato con il server. I set potrebbero non essere aggiornati.';

  @override
  String syncUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche di questo dispositivo non hanno',
      one: '1 modifica di questo dispositivo non ha',
    );
    return '$_temp0 ancora raggiunto il server.';
  }

  @override
  String get addSongs => 'Aggiungi brani';

  @override
  String get pause => 'Pausa';

  @override
  String get textItem => 'Testo';

  @override
  String get markerIconBreak => 'Pausa';

  @override
  String get markerIconDrinks => 'Bevande';

  @override
  String get markerIconAnnouncement => 'Annuncio';

  @override
  String get markerIconMicrophone => 'Discorso';

  @override
  String get markerIconGuest => 'Ospite';

  @override
  String get markerIconEncore => 'Bis';

  @override
  String get markerIconTransition => 'Transizione';

  @override
  String get markerIconSolo => 'Solo';

  @override
  String get markerIconApplause => 'Applausi';

  @override
  String get markerIconInstrument => 'Cambio di strumento';

  @override
  String get markerIconTuning => 'Accordatura';

  @override
  String get markerIconClick => 'Click';

  @override
  String get markerIconLight => 'Luci';

  @override
  String get markerIconEffects => 'Effetti';

  @override
  String get markerIconCelebration => 'Festa';

  @override
  String get markerIconInfo => 'Nota';

  @override
  String get markerIconWarning => 'Attenzione';

  @override
  String get marker => 'Segnaposto';

  @override
  String get addMarker => 'Aggiungi segnaposto';

  @override
  String get editMarker => 'Modifica segnaposto';

  @override
  String get markerText => 'Testo';

  @override
  String get markerPreview => 'Anteprima';

  @override
  String get markerGroupBreak => 'Pausa';

  @override
  String get markerGroupAnnouncement => 'Annuncio';

  @override
  String get markerGroupFlow => 'Svolgimento';

  @override
  String get markerGroupStage => 'Palco';

  @override
  String get markerGroupShow => 'Show';

  @override
  String get markerGroupGeneral => 'Generale';

  @override
  String get setEmpty => 'Questo set è vuoto. Aggiungi qualche brano.';

  @override
  String get deleteSetTitle => 'Eliminare il set?';

  @override
  String deleteSetMessage(String name) {
    return '\"$name\" verrà eliminato. I brani vengono mantenuti.';
  }

  @override
  String get removeFromSet => 'Rimuovi dal set';

  @override
  String get selectSongs => 'Seleziona brani';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionati',
      one: '1 selezionato',
      zero: 'Nessuno selezionato',
    );
    return '$_temp0';
  }

  @override
  String get songMissing => 'Il brano non esiste più';

  @override
  String liveNext(String title) {
    return 'Prossimo: $title';
  }

  @override
  String get liveWebNotice =>
      'Nel browser non è sicuro offline – sul palco usa l\'app';

  @override
  String liveMidiConnected(String name) {
    return 'Tastiera collegata: $name';
  }

  @override
  String get liveMidiNotConnected => 'Tastiera non collegata';

  @override
  String get liveMidiSendAgain => 'Invia di nuovo il programma';

  @override
  String get liveMidiButton =>
      'Programma della tastiera (pressione lunga: invia di nuovo)';

  @override
  String get liveMidiChange => 'Cambia programma';

  @override
  String get liveMidiSameAsPrevious => 'Come il brano precedente';

  @override
  String liveMidiPreviousProgram(String program, String title) {
    return '$program – da “$title”';
  }

  @override
  String get liveMidiNoPrevious => 'Nessun brano precedente con un programma';

  @override
  String get liveMidiSaved => 'Programma della tastiera salvato';

  @override
  String get liveMidiRemoved => 'Programma della tastiera rimosso';

  @override
  String get liveMidiTakeOverWaiting => 'Scegli un suono sulla tastiera';

  @override
  String liveMidiTakeOver(String program) {
    return 'Adotta: $program';
  }

  @override
  String get liveMidiTakeOverHint =>
      'setDING adotta il programma inviato dalla tastiera.';

  @override
  String get liveMidiTakeOverNordHint =>
      'Non arriva niente? Sul Nord, nel menu MIDI imposta “Program Change” su “Send” o “Send & Receive”.';

  @override
  String get liveMidiTakeOverSame => 'Questo è già il programma del brano';

  @override
  String get liveWakeLockNotice =>
      'Lo schermo potrebbe spegnersi – controlla le impostazioni di risparmio energetico del dispositivo';

  @override
  String get liveEnd => 'Fine del set';

  @override
  String get liveSetOverview => 'Panoramica del set';

  @override
  String get liveExit => 'Esci dalla modalità live';

  @override
  String get projectionFullScreen => 'Schermo intero';

  @override
  String liveSongPage(int page, int count) {
    return 'Pagina $page/$count';
  }

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'Generale';

  @override
  String get settingsSectionDisplay => 'Visualizzazione';

  @override
  String get settingsSectionLive => 'Schermo e modalità live';

  @override
  String get settingsSectionStorage => 'Memoria e info';

  @override
  String get settingsSectionMusician => 'Musicista';

  @override
  String get settingsCategoryAccountHint =>
      'Accesso, server e sincronizzazione';

  @override
  String get settingsCategoryGeneralHint => 'Lingua e tema';

  @override
  String get settingsCategoryMusicianHint =>
      'Strumento, voce, diagrammi degli accordi, battito';

  @override
  String get settingsCategoryDisplayHint =>
      'Notazione accordi, Nashville e numeri romani, contenuto, ritornello, avanzamento';

  @override
  String get settingsCategoryLiveHint =>
      'Dimensione del testo, adatta allo schermo, colonne, voltapagina';

  @override
  String get settingsCategoryAboutHint => 'Memoria, log diagnostico e versione';

  @override
  String get settingsInstrument => 'Il mio strumento';

  @override
  String get settingsInstrumentHint =>
      'Usato per le parti condizionali (p. es. solo chitarra) e per i diagrammi degli accordi.';

  @override
  String get instrumentGuitar => 'Chitarra';

  @override
  String get instrumentUkulele => 'Ukulele';

  @override
  String get instrumentBass => 'Basso';

  @override
  String get instrumentKeyboard => 'Tastiera';

  @override
  String get instrumentVocals => 'Voce';

  @override
  String get instrumentDrums => 'Batteria';

  @override
  String get instrumentOther => 'Altro …';

  @override
  String get settingsUserName => 'Voce o ruolo (facoltativo)';

  @override
  String get settingsUserNameHint =>
      'Il tuo strumento conta già. Serve solo se un brano ha parti per singole voci o persone, p. es. “alto” o “tenore”.';

  @override
  String settingsUserNameIsInstrument(String name) {
    return '“$name” è uno strumento. L\'impostazione dello strumento lo copre già, quindi puoi lasciare vuoto questo campo.';
  }

  @override
  String get settingsDiagrams => 'Diagrammi degli accordi';

  @override
  String get settingsDiagramsHint =>
      'Mostra le diteggiature di tutti gli accordi del brano per il tuo strumento. Un brano può impostarlo da sé con la direttiva diagrams.';

  @override
  String get settingsBassStrings => 'Corde del basso';

  @override
  String get settingsBassStringsHint =>
      'I diagrammi degli accordi mostrano un basso a 4 corde (E-A-D-G) o un basso a 5 corde con una corda di Si grave.';

  @override
  String bassStringCount(int count) {
    return '$count corde';
  }

  @override
  String get diagramsOff => 'Disattivi';

  @override
  String get diagramsTop => 'In alto';

  @override
  String get diagramsBottom => 'In basso';

  @override
  String get notSet => 'Non impostato';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get languageSystem => 'Lingua di sistema';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'English';

  @override
  String get languageIt => 'Italiano';

  @override
  String get languageFr => 'Français';

  @override
  String get languageEs => 'Español';

  @override
  String get languagePt => 'Português';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Come il sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get settingsAccent => 'Colore d\'accento';

  @override
  String get accentBrand => 'Blu setDING';

  @override
  String get accentRed => 'Rosso';

  @override
  String get accentAmber => 'Ambra';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentTeal => 'Verde acqua';

  @override
  String get accentPurple => 'Viola';

  @override
  String get accentPink => 'Rosa';

  @override
  String get settingsNotation => 'Notazione degli accordi';

  @override
  String get notationInternational => 'Internazionale (B, Bb)';

  @override
  String get notationGerman => 'Tedesca (H, B)';

  @override
  String get settingsChordView => 'Mostra gli accordi come';

  @override
  String get settingsChordViewHint =>
      'Accordi (Am7), numeri Nashville (6m7) o numeri romani (vi7). Numeri e numeri romani richiedono una tonalità nel brano.';

  @override
  String get settingsNumeralSpelling => 'Grafia dei numeri romani';

  @override
  String get settingsNumeralSpellingHint =>
      'Come i numeri romani mostrano l\'accordo: con maiuscole e minuscole, ii7 – V7 – IΔ7, oppure in maiuscolo con il simbolo dell\'accordo, IIm7 – V7 – Imaj7. Il simbolo dell\'accordo segue lo stile degli accordi.';

  @override
  String get numeralSpellingCasing => 'Maiuscole/minuscole';

  @override
  String get numeralSpellingChordSymbol => 'Simbolo dell\'accordo';

  @override
  String get settingsChordStyle => 'Stile degli accordi';

  @override
  String get settingsChordStyleHint =>
      'Come vengono scritti gli accordi, p. es. Am7, Cmaj7, Em7b5 (standard) o A−7, CΔ7, Eø7 (jazz). Il brano stesso non viene modificato.';

  @override
  String get chordStyleAsWritten => 'Come scritto';

  @override
  String get chordStyleStandard => 'Standard';

  @override
  String get chordStyleJazz => 'Jazz';

  @override
  String get settingsChordSuperscript => 'Estensioni in apice';

  @override
  String get settingsChordSuperscriptHint =>
      'Mostra estensioni e alterazioni più piccole e in apice, p. es. C⁷. Richiede lo stile standard o jazz.';

  @override
  String get settingsDisplayMode => 'Contenuto';

  @override
  String get displayLyricsAndChords => 'Testo e accordi';

  @override
  String get displayLyricsOnly => 'Solo testo';

  @override
  String get settingsFontSize => 'Dimensione del testo';

  @override
  String get settingsColumns => 'Colonne';

  @override
  String get columnsAuto => 'Automatico';

  @override
  String get columnsOne => 'Una';

  @override
  String get columnsTwo => 'Due';

  @override
  String get settingsPageTurn => 'Voltapagina';

  @override
  String get pageTurnFull => 'Pagina intera';

  @override
  String get pageTurnHalf => 'Mezza pagina';

  @override
  String get settingsAutoFit => 'Adatta il brano allo schermo';

  @override
  String get settingsAutoFitHint =>
      'L\'intero brano entra nello schermo senza scorrere. Le sezioni vengono disposte automaticamente in colonne e il testo è il più grande possibile.';

  @override
  String get settingsColumnsHint =>
      'Quando si adatta allo schermo, il numero massimo di colonne consentito.';

  @override
  String get columnsThree => 'Tre';

  @override
  String get settingsChorusRepeat => 'Ritornello ripetuto';

  @override
  String get settingsChorusRepeatHint =>
      'Automatico: un ritornello ripetuto viene mostrato solo come breve etichetta se altrimenti il brano non entrerebbe bene nello schermo.';

  @override
  String get chorusRepeatAuto => 'Automatico';

  @override
  String get chorusRepeatFull => 'Mostra per intero';

  @override
  String get chorusRepeatLabel => 'Solo etichetta';

  @override
  String get settingsPageTurnHint =>
      'Tocca il lato sinistro o destro dello schermo per tornare indietro o andare avanti. Voltapagina (pedale) e tastiera: freccia destra, freccia giù, Pagina giù e Spazio avanti, freccia sinistra, freccia su e Pagina su indietro. Con un battito (tempo e battito o click attivati), tenere premuto avanti o premere Invio lo avvia e lo ferma.';

  @override
  String get settingsSetProgress => 'Barra di avanzamento del set';

  @override
  String get settingsSetProgressHint =>
      'Una barra sottile sopra la barra inferiore mostra i brani del set e le pagine del brano attuale: la pagina attuale nel colore d\'accento, le pagine ancora da venire in una tonalità più chiara. I segnaposto come le pause sono tratteggiati.';

  @override
  String get settingsBeatSection => 'Battito e click';

  @override
  String get settingsBeatSectionHint =>
      'Tempo e metro del brano, o il tempo dell\'arrangiamento della band. Attivo per impostazione predefinita se il tuo strumento è la batteria.';

  @override
  String get settingsBeatDisplay => 'Indicatore del battito';

  @override
  String get settingsBeatDisplayHint =>
      'I punti accanto a tempo e metro si illuminano a ogni battito; il conteggio iniziale mostra numeri grandi.';

  @override
  String get settingsEdgeFlash => 'Fai lampeggiare il bordo dello schermo';

  @override
  String get settingsEdgeFlashHint =>
      'Il bordo lampeggia a ogni battito, l\'1 in un altro colore – visibile con la coda dell\'occhio.';

  @override
  String get settingsClick => 'Click';

  @override
  String get settingsClickHint =>
      'Riproduce un click sull\'uscita audio del dispositivo, p. es. nel mix in-ear.';

  @override
  String get settingsClickStart => 'Avvio';

  @override
  String get settingsClickStartHint =>
      'Manualmente: tocca il tempo, tieni premuto il pedale avanti o premi Invio. Passare a un altro brano del set ferma il battito.';

  @override
  String get clickStartAutomatic => 'Con ogni brano';

  @override
  String get clickStartManual => 'Manualmente';

  @override
  String get settingsClickDuration => 'Durata';

  @override
  String get clickDurationSong => 'Tutto il brano';

  @override
  String get clickDurationCountIn => 'Solo conteggio iniziale';

  @override
  String get settingsClickInBackground => 'In background';

  @override
  String get settingsClickInBackgroundHint =>
      'Quando l\'app è ridotta a icona, viene aperta un\'altra app o lo schermo è bloccato.';

  @override
  String get clickInBackgroundStop => 'Ferma';

  @override
  String get clickInBackgroundKeepPlaying => 'Continua a suonare';

  @override
  String get settingsCountIn => 'Conteggio iniziale';

  @override
  String get countInOff => 'Disattivo';

  @override
  String get countInOneBar => '1 battuta';

  @override
  String get countInTwoBars => '2 battute';

  @override
  String get settingsClickVolume => 'Volume';

  @override
  String get settingsClickAccent => 'Accento sull\'1';

  @override
  String get settingsClickSound => 'Suono';

  @override
  String get clickSoundClick => 'Click';

  @override
  String get clickSoundWoodblock => 'Woodblock';

  @override
  String get clickSoundBeep => 'Beep';

  @override
  String get settingsClickSubdivision => 'Suddivisioni';

  @override
  String get settingsClickSubdivisionHint =>
      'Click più leggeri tra i battiti. Ogni brano può averne di propri nei suoi adattamenti personali.';

  @override
  String get subdivisionOff => 'Disattive';

  @override
  String get subdivisionEighths => 'Ottavi';

  @override
  String get subdivisionSixteenths => 'Sedicesimi';

  @override
  String get subdivisionTriplets => 'Terzine';

  @override
  String clickSubdivisionAsInSettings(String value) {
    return 'Come nelle impostazioni ($value)';
  }

  @override
  String get clickGrouping => 'Raggruppamento';

  @override
  String get clickGroupingNone => 'Nessun gruppo';

  @override
  String clickGroupingAsInSong(String grouping) {
    return 'Come nel brano ($grouping)';
  }

  @override
  String get clickGroupingHint =>
      'Battiti accentati di un metro dispari, solo per te.';

  @override
  String get settingsAudioLatency => 'Ritardo audio';

  @override
  String get settingsAudioLatencyHint =>
      'Sposta la visualizzazione in modo che corrisponda a ciò che senti. Le cuffie con filo richiedono poco, le cuffie Bluetooth 100–300 ms.';

  @override
  String audioLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get audioLatencyCalibrate => 'Misura il ritardo audio';

  @override
  String get audioLatencyCalibrateTitle => 'Misura il ritardo audio';

  @override
  String get audioLatencyCalibrateHint =>
      'Indossa le cuffie che usi sul palco e tocca a tempo con ogni battito del click.';

  @override
  String get audioLatencyTap => 'Tocca';

  @override
  String audioLatencyTaps(int count) {
    return '$count tocchi';
  }

  @override
  String audioLatencyResult(int ms) {
    return 'Misurato: $ms ms';
  }

  @override
  String get audioLatencyApply => 'Applica';

  @override
  String get clickNoAudio =>
      'Su questo dispositivo non c\'è un\'uscita audio per il click.';

  @override
  String get beatStart => 'Avvia il battito';

  @override
  String get beatStop => 'Ferma il battito';

  @override
  String get beatDisplayLabel => 'Battito';

  @override
  String countInBar(int bar, int count) {
    return 'Battuta $bar di $count';
  }

  @override
  String get tempoSlower => 'Più lento';

  @override
  String get tempoFaster => 'Più veloce';

  @override
  String get tapTempo => 'Tap tempo';

  @override
  String get tempoReset => 'Torna al tempo del brano';

  @override
  String get clickNoAudioLive => 'Nessun audio per il click';

  @override
  String get settingsSongMap => 'Mappa del brano invece degli accordi';

  @override
  String get settingsSongMapHint =>
      'La modalità live mostra le parti del brano con un riferimento al testo e le note per la batteria.';

  @override
  String get songMapEmpty =>
      'Questo brano non ha parti (verse, chorus, …) da mostrare come mappa del brano.';

  @override
  String get songMapNoTempo => 'Nessun tempo per questo brano';

  @override
  String get drumPanelSet => 'Set';

  @override
  String get drumPanelSongMap => 'Mappa del brano';

  @override
  String get settingsLiveAppearance => 'Aspetto sul palco';

  @override
  String get settingsLiveAppearanceHint =>
      'La modalità live indipendente dal tema dell\'app. Il nero risparmia energia sugli schermi OLED.';

  @override
  String get liveAppearanceApp => 'Come l\'app';

  @override
  String get liveAppearanceDark => 'Scuro';

  @override
  String get liveAppearanceBlack => 'Nero';

  @override
  String settingsStorageUsed(String size) {
    return 'Gli allegati PDF occupano $size';
  }

  @override
  String get appMenuEntryAdd => 'Aggiungi al menu delle applicazioni';

  @override
  String get appMenuEntryAddHint =>
      'setDING con la sua icona nel menu di avvio del tuo desktop';

  @override
  String get appMenuEntryInstalled => 'Nel menu delle applicazioni';

  @override
  String get appMenuEntryInstalledHint =>
      'Il menu di avvio avvia questo file AppImage';

  @override
  String get appMenuEntryRemove => 'Rimuovi';

  @override
  String get appMenuEntryAdded => 'setDING è ora nel menu delle applicazioni';

  @override
  String get appMenuEntryRemoved =>
      'setDING rimosso dal menu delle applicazioni';

  @override
  String appMenuEntryFailed(String error) {
    return 'Menu delle applicazioni non modificato: $error';
  }

  @override
  String get settingsLogCopy => 'Copia log diagnostico';

  @override
  String get settingsLogCopyHint =>
      'I messaggi recenti dell\'app, p. es. perché una sincronizzazione non è riuscita – da incollare in un messaggio al supporto.';

  @override
  String get settingsLogCopied => 'Log diagnostico copiato';

  @override
  String get settingsAbout =>
      'setDING funziona localmente su questo dispositivo. Tutti i dati sono disponibili offline.';

  @override
  String settingsVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get lilypondNotice =>
      'Questa notazione Lilypond usa funzioni che setDING non sa disegnare. Sorgente:';

  @override
  String get sequenceLabel => 'Sequenza del brano';

  @override
  String get sectionIntro => 'Intro';

  @override
  String get sectionPreChorus => 'Pre-chorus';

  @override
  String get sectionPostChorus => 'Post-chorus';

  @override
  String get sectionInterlude => 'Interlude';

  @override
  String get sectionInstrumental => 'Instrumental';

  @override
  String get sectionSolo => 'Solo';

  @override
  String get sectionTag => 'Tag';

  @override
  String get sectionOutro => 'Outro';

  @override
  String get sectionEnding => 'Ending';

  @override
  String get sectionTurnaround => 'Turnaround';

  @override
  String get sectionVamp => 'Vamp';

  @override
  String get sectionRefrain => 'Refrain';

  @override
  String get sectionBreakdown => 'Breakdown';

  @override
  String get editorGroupChords => 'Accordi';

  @override
  String get editorGroupSections => 'Sezioni';

  @override
  String get editorGroupInfo => 'Info sul brano';

  @override
  String get editorGroupText => 'Testo';

  @override
  String get editorGroupMore => 'Altro';

  @override
  String get searchMatchCase => 'Maiuscole/minuscole';

  @override
  String get replaceToggle => 'Sostituisci';

  @override
  String get replaceWith => 'Sostituisci con';

  @override
  String get replace => 'Sostituisci';

  @override
  String get replaceAll => 'Sostituisci tutto';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sostituiti',
      one: '1 sostituito',
    );
    return '$_temp0';
  }

  @override
  String get convertChordsOverLyrics => 'Converti gli accordi sopra il testo';

  @override
  String get pastedChordsOverLyrics =>
      'Il testo incollato ha gli accordi sopra il testo.';

  @override
  String get convert => 'Converti';

  @override
  String get convertCcliGrids => 'Converti le stanghette in griglie di accordi';

  @override
  String ccliGridsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocchi di stanghette possono',
      one: 'Un blocco di stanghette può',
    );
    return '$_temp0 essere mostrati come griglia di accordi.';
  }

  @override
  String get convertCommentHeadings =>
      'Converti i titoli dei commenti in sezioni';

  @override
  String get translateSectionLabels =>
      'Traduci i nomi delle sezioni in inglese';

  @override
  String commentHeadingsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sezioni sono segnate',
      one: 'Una sezione è segnata',
    );
    return '$_temp0 con un commento come \"Verse 1\". La conversione ne fa sezioni ChordPro; il brano ha lo stesso aspetto.';
  }

  @override
  String get remove => 'Rimuovi';

  @override
  String get ccliFooterHint =>
      'Il brano termina con il piè di pagina CCLI di SongSelect. Rimuovendolo, numero del brano e copyright restano nei dettagli del brano.';

  @override
  String legacyLabelsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etichette di sezione sono',
      one: 'Un\'etichetta di sezione è',
    );
    return '$_temp0 nella forma breve. La specifica ChordPro raccomanda label=\"…\".';
  }

  @override
  String songSelectDirectivesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count direttive CCLI non seguono',
      one: 'Una direttiva CCLI non segue',
    );
    return '$_temp0 la specifica ChordPro: ccli diventa x_ccli, footer diventa x_ccli_footer, ccli_license viene rimossa.';
  }

  @override
  String importLegacyLabelsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani importati scrivono',
      one: '1 brano importato scrive',
    );
    return '$_temp0 le etichette di sezione nella forma breve. La conversione le scrive come label=\"…\", come raccomanda la specifica ChordPro; i brani hanno lo stesso aspetto.';
  }

  @override
  String get convertLabels => 'Converti etichette';

  @override
  String songsLabelsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Etichette convertite in $count brani',
      one: 'Etichette convertite in 1 brano',
      zero: 'Nessuna etichetta convertita',
    );
    return '$_temp0';
  }

  @override
  String get hideHint => 'Nascondi suggerimento';

  @override
  String get searchInSong => 'Cerca';

  @override
  String get searchNoMatches => 'Nessun risultato';

  @override
  String get searchPrevious => 'Risultato precedente';

  @override
  String get searchNext => 'Risultato successivo';

  @override
  String get searchClose => 'Chiudi ricerca';

  @override
  String searchMatchCount(int current, int total) {
    return '$current di $total';
  }

  @override
  String get editorGroupLines => 'Righe';

  @override
  String get redo => 'Ripeti';

  @override
  String get moveLinesUp => 'Sposta riga su';

  @override
  String get moveLinesDown => 'Sposta riga giù';

  @override
  String get moveChordLeft => 'Sposta accordo a sinistra';

  @override
  String get moveChordRight => 'Sposta accordo a destra';

  @override
  String get duplicateLines => 'Duplica riga';

  @override
  String get deleteLines => 'Elimina riga';

  @override
  String get toggleComment => 'Commenta riga (#)';

  @override
  String get insertOptionalChord => 'Accordo facoltativo';

  @override
  String get insertAnnotation => 'Annotazione';

  @override
  String get insertNoChord => 'Nessun accordo (N.C.)';

  @override
  String get insertDefine => 'Definizione di accordo';

  @override
  String get insertChordDiagram => 'Diagramma di accordo';

  @override
  String get insertTranspose => 'Trasponi';

  @override
  String get insertTab => 'Tab';

  @override
  String get insertGrid => 'Griglia di accordi';

  @override
  String get insertChorusRecall => 'Ripeti chorus';

  @override
  String get metaSubtitle => 'Sottotitolo';

  @override
  String get metaComposer => 'Compositore';

  @override
  String get metaLyricist => 'Paroliere';

  @override
  String get metaCopyright => 'Copyright';

  @override
  String get metaTag => 'Tag';

  @override
  String get metaYear => 'Anno';

  @override
  String get metaAlbum => 'Album';

  @override
  String get metaDuration => 'Durata';

  @override
  String get metaTempo => 'Tempo (BPM)';

  @override
  String get metaTime => 'Metro';

  @override
  String get metaKey => 'Tonalità';

  @override
  String get insertCommentItalic => 'Commento (corsivo)';

  @override
  String get insertCommentBox => 'Commento (riquadro)';

  @override
  String get insertHighlight => 'Evidenziazione';

  @override
  String get insertBold => 'Grassetto';

  @override
  String get insertItalic => 'Corsivo';

  @override
  String get insertUnderline => 'Sottolineato';

  @override
  String get insertColour => 'Colore';

  @override
  String get insertColumnBreak => 'Interruzione di colonna';

  @override
  String get insertNewPage => 'Interruzione di pagina';

  @override
  String get insertColumns => 'Colonne';

  @override
  String get insertImage => 'Immagine';

  @override
  String get insertAbc => 'Notazione ABC';

  @override
  String get insertTextblock => 'Blocco di testo';

  @override
  String get insertNewSong => 'Brano successivo nello stesso file';

  @override
  String get sequenceEdit => 'Sequenza del brano per questo set';

  @override
  String get sequenceFromSet => 'Sequenza modificata per questo set';

  @override
  String get sequenceFromBand => 'Sequenza della band';

  @override
  String get bandArrangement => 'Arrangiamento della band';

  @override
  String arrangementOf(String band) {
    return 'Arrangiamento di $band';
  }

  @override
  String get arrangementBand => 'Band';

  @override
  String get arrangementAsWritten => 'Come nel brano';

  @override
  String arrangementKey(String key) {
    return 'Tonalità $key';
  }

  @override
  String get arrangementSequence => 'Sequenza';

  @override
  String get arrangementTempo => 'Tempo';

  @override
  String get arrangementTempoLabel => 'Tempo in BPM (vuoto = come nel brano)';

  @override
  String get arrangementReset => 'Riporta l\'arrangiamento della band al brano';

  @override
  String sequenceOriginal(Object sequence) {
    return 'Nel brano: $sequence';
  }

  @override
  String get sequenceNoneInSong => 'Il brano non ha una sequenza.';

  @override
  String get sequenceRestore => 'Usa la sequenza del brano';

  @override
  String get sequenceHint => 'p. es. I, V1, C, V2, PC, C x2, B, O';

  @override
  String get sequenceAbbreviations =>
      'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = due volte';

  @override
  String get sequenceEmpty =>
      'Tocca le parti qui sotto per costruire la sequenza, o trascinale qui.';

  @override
  String get sequenceReorderHint =>
      'Tieni premuta una parte per spostarla in un\'altra posizione.';

  @override
  String get sequenceSongParts => 'Parti del brano';

  @override
  String get sequenceCommonParts =>
      'Parti comuni (il brano non ha ancora sezioni)';

  @override
  String get sequenceClear => 'Svuota';

  @override
  String get sequenceAsText => 'Modifica come testo';

  @override
  String get settingsSectionAccount => 'Account e sincronizzazione';

  @override
  String get accountSignedOut => 'Non hai effettuato l\'accesso';

  @override
  String get accountSignedOutHint =>
      'Accedi per condividere brani e set con la tua band. Senza account, setDING continua a funzionare localmente su questo dispositivo.';

  @override
  String get accountSignIn => 'Accedi';

  @override
  String get accountSignUp => 'Crea account';

  @override
  String get accountJoin => 'Unisciti con un invito';

  @override
  String get accountSignOut => 'Esci';

  @override
  String get accountSignOutTitle => 'Uscire?';

  @override
  String get accountSignOutMessage =>
      'I brani e i set su questo dispositivo vengono mantenuti.';

  @override
  String get accountSignOutMessageWeb =>
      'I dati in questo browser vengono eliminati. I brani e i set restano sul server.';

  @override
  String get accountEmail => 'E-mail';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountPasswordConfirm => 'Conferma password';

  @override
  String get accountPasswordShow => 'Mostra password';

  @override
  String get accountPasswordHide => 'Nascondi password';

  @override
  String get accountKeepSignedIn => 'Resta connesso';

  @override
  String get accountKeepSignedInHint =>
      'Solo sul tuo dispositivo. Altrimenti vieni disconnesso quando chiudi il browser.';

  @override
  String get accountNameHint =>
      'Ad es. «Andi». I tuoi compagni di band lo vedono negli elenchi al posto del nome completo.';

  @override
  String get accountFirstName => 'Nome';

  @override
  String get accountLastName => 'Cognome';

  @override
  String get accountNickname => 'Nome visualizzato (facoltativo)';

  @override
  String get accountCompleteName => 'Completa il tuo nome';

  @override
  String get accountCompleteNameMessage =>
      'Inserisci nome e cognome, così i tuoi compagni di band ti trovano più facilmente.';

  @override
  String get settingsHeadingPeople => 'Persone';

  @override
  String get settingsNameFormat => 'Mostra i nomi come';

  @override
  String get settingsNameFormatHint =>
      'Come appaiono le altre persone negli elenchi dei membri, nelle formazioni e nelle modifiche.';

  @override
  String get nameFormatNickname =>
      'Nome visualizzato (altrimenti nome completo)';

  @override
  String get nameFormatFirstLast => 'Nome Cognome';

  @override
  String get nameFormatLastFirst => 'Cognome Nome';

  @override
  String get nameFormatFullWithNickname => 'Nome Cognome (nome visualizzato)';

  @override
  String get accountToSignUp => 'Non hai ancora un account? Creane uno';

  @override
  String get accountToSignIn => 'Hai già un account? Accedi';

  @override
  String get accountForgotPassword => 'Password dimenticata?';

  @override
  String get accountResetTitle => 'Reimposta password';

  @override
  String get accountResetSent =>
      'Se esiste un account con questo indirizzo, è stata inviata un\'e-mail di reimpostazione.';

  @override
  String get accountFieldRequired => 'Obbligatorio.';

  @override
  String accountPasswordTooShort(int min) {
    return 'Almeno $min caratteri.';
  }

  @override
  String get accountPasswordMismatch => 'Le password non coincidono.';

  @override
  String get accountChangeName => 'Cambia nome';

  @override
  String get accountNameChanged => 'Nome cambiato.';

  @override
  String get accountChangePassword => 'Cambia password';

  @override
  String get accountChangePasswordHint =>
      'Resti connesso su questo dispositivo. Gli altri tuoi dispositivi vengono disconnessi.';

  @override
  String get accountCurrentPassword => 'Password attuale';

  @override
  String get accountNewPassword => 'Nuova password';

  @override
  String get accountPasswordWrongCurrent => 'La password attuale è sbagliata.';

  @override
  String get accountPasswordChanged =>
      'Password cambiata. Accedi di nuovo sugli altri tuoi dispositivi.';

  @override
  String get accountDelete => 'Elimina account';

  @override
  String get accountDeleteHint =>
      'Elimina definitivamente il tuo account e i tuoi dati personali.';

  @override
  String get accountDeleteTitle => 'Eliminare l\'account?';

  @override
  String get accountDeleteMessage =>
      'Il tuo account, i tuoi adattamenti personali, le annotazioni e le impostazioni vengono eliminati definitivamente e vieni disconnesso su tutti i dispositivi. Brani e set restano alle tue organizzazioni. I backup del server ne conservano una copia per un massimo di 14 giorni. Inserisci la password per confermare.';

  @override
  String get accountDeleteSoleAdmin =>
      'Sei l\'unico admin di queste organizzazioni. Prima nomina admin qualcun altro o chiudi l\'organizzazione:';

  @override
  String get accountDeleted => 'Il tuo account è stato eliminato.';

  @override
  String get dangerZone => 'Zona pericolosa';

  @override
  String get accountErrorNetwork =>
      'Nessuna connessione al server. Controlla la connessione a Internet.';

  @override
  String get accountErrorInvalidCredentials => 'E-mail o password errate.';

  @override
  String get accountErrorEmailTaken =>
      'Esiste già un account con questo indirizzo e-mail.';

  @override
  String get accountErrorInvalidEmail => 'L\'indirizzo e-mail non è valido.';

  @override
  String get accountErrorWeakPassword =>
      'La password non soddisfa i requisiti del server.';

  @override
  String get accountErrorServer =>
      'Il server ha segnalato un errore. Riprova più tardi.';

  @override
  String get accountErrorUpdateRequired =>
      'Questa versione di setDING è troppo vecchia per il server. Aggiorna l\'app.';

  @override
  String get updateRequiredTitle => 'Aggiorna setDING';

  @override
  String get updateRequiredBody =>
      'Il server non accetta più questa versione, quindi non viene sincronizzato nulla. Le tue modifiche restano su questo dispositivo e vengono inviate dopo l\'aggiornamento.';

  @override
  String updateRequiredVersions(String current, String minimum) {
    return 'Installata: $current, richiesta: $minimum o più recente.';
  }

  @override
  String get updateRequiredHowTo =>
      'Su Android aggiornala in Obtainium; altrimenti scarica la nuova versione dalle release di setDING su GitHub.';

  @override
  String get updateHowToGooglePlay => 'Aggiornala in Google Play.';

  @override
  String get updateOpenGooglePlay => 'Apri in Google Play';

  @override
  String get updateRequiredReload => 'Ricarica';

  @override
  String get updateRequiredCopyLink => 'Copia link di download';

  @override
  String get updateRequiredCopied => 'Link copiato.';

  @override
  String updateAvailableTitle(String version) {
    return 'setDING $version è disponibile';
  }

  @override
  String get updateAvailableDetails => 'Dettagli';

  @override
  String updateAvailableInstalled(String current) {
    return 'Installata: $current.';
  }

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerHint => 'Cambiarlo ti disconnette.';

  @override
  String get settingsServerInvalid =>
      'L\'indirizzo deve iniziare con http:// o https://.';

  @override
  String get bandLocal => 'Su questo dispositivo';

  @override
  String get bandLocalHint => 'Solo su questo dispositivo, non sincronizzato.';

  @override
  String get bandSwitch => 'Cambia band';

  @override
  String get bandManage => 'Gestisci band';

  @override
  String get bandNone => 'Nessuna band';

  @override
  String noBandInLibrary(String organization) {
    return 'Non fai parte di nessuna band di $organization. I set appartengono a una band: creane una o chiedi di essere aggiunto.';
  }

  @override
  String get librarySwitch => 'Cambia libreria di brani';

  @override
  String get bandsTitle => 'Band';

  @override
  String get bandsEmpty =>
      'Non fai ancora parte di una band. Crea una band per i tuoi brani e set.';

  @override
  String get bandsSignInHint => 'Accedi per creare band.';

  @override
  String get bandNew => 'Nuova band';

  @override
  String get bandName => 'Nome della band';

  @override
  String get bandRoleAdmin => 'Admin';

  @override
  String get bandRoleMember => 'Membro';

  @override
  String get bandMembers => 'Membri';

  @override
  String bandYou(String name) {
    return '$name (tu)';
  }

  @override
  String get bandMakeAdmin => 'Rendi admin';

  @override
  String get bandMakeMember => 'Rendi membro';

  @override
  String get bandRoleLeader => 'Leader';

  @override
  String get bandRolePlanner => 'Pianificatore di set';

  @override
  String get orgRoleLibrarian => 'Bibliotecario';

  @override
  String get bandMakeLeader => 'Rendi leader';

  @override
  String get bandMakePlanner => 'Rendi pianificatore di set';

  @override
  String get orgMakeLibrarian => 'Rendi bibliotecario';

  @override
  String get orgLibrarianHint =>
      'I bibliotecari creano, modificano ed eliminano i brani dell\'organizzazione.';

  @override
  String get bandPlannerHint =>
      'I pianificatori di set compongono i set della band.';

  @override
  String get inviteBandHint =>
      'Crea un link valido per 7 giorni. Chi lo apre entra nell\'organizzazione e in questa band come membro. Sotto Membri puoi poi cambiare il suo ruolo nella band.';

  @override
  String joinQuestionBand(String band, String org) {
    return 'Unirti a $band ($org)?';
  }

  @override
  String get joinExplanationBand =>
      'Diventi membro dell\'organizzazione e della band e vedi i suoi brani e set.';

  @override
  String get bandRemoveMember => 'Rimuovi dalla band';

  @override
  String bandRemoveTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String bandRemoveMessage(String name) {
    return '$name non vedrà più i brani e i set della band.';
  }

  @override
  String get bandLeave => 'Lascia la band';

  @override
  String bandLeaveTitle(String band) {
    return 'Lasciare $band?';
  }

  @override
  String get bandLeaveMessage =>
      'Non vedrai più i brani e i set della band. Un admin può invitarti di nuovo.';

  @override
  String get bandRefresh => 'Aggiorna';

  @override
  String get bandErrorLastAdmin => 'Una band ha bisogno di almeno un admin.';

  @override
  String get bandErrorNotAllowed =>
      'Non consentito, oppure la band non esiste più.';

  @override
  String get accountErrorSignedOut => 'Accedi.';

  @override
  String get copyToBand => 'Copia nella band';

  @override
  String get copyToBandTitle => 'Copiare in quale band?';

  @override
  String get copyToBandNoTarget =>
      'Non c\'è nessun\'altra band in cui puoi copiare.';

  @override
  String copiedSongs(int count, String band) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani copiati in $band',
      one: '1 brano copiato in $band',
    );
    return '$_temp0';
  }

  @override
  String copiedSet(String band) {
    return 'Set copiato in $band';
  }

  @override
  String songsSelected(int count) {
    return '$count selezionati';
  }

  @override
  String get selectAll => 'Seleziona tutto';

  @override
  String get selectMode => 'Seleziona';

  @override
  String get deleteSelected => 'Elimina selezionati';

  @override
  String deleteSongsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare $count brani?',
      one: 'Eliminare 1 brano?',
    );
    return '$_temp0';
  }

  @override
  String deleteSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'I $count brani selezionati verranno eliminati e rimossi da tutti i set.',
      one: 'Il brano selezionato verrà eliminato e rimosso da tutti i set.',
    );
    return '$_temp0 Puoi ripristinarli dal cestino.';
  }

  @override
  String songsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani eliminati',
      one: '1 brano eliminato',
    );
    return '$_temp0';
  }

  @override
  String get bandRoleOrgAdmin => 'Admin dell\'organizzazione';

  @override
  String get bandOrganization => 'Organizzazione';

  @override
  String get bandNewOrganization => 'Nuova organizzazione';

  @override
  String get bandNewHint =>
      'Le band di un\'organizzazione condividono i loro brani.';

  @override
  String get bandAddMember => 'Aggiungi membro';

  @override
  String get bandAddMemberTitle => 'Aggiungere chi?';

  @override
  String get bandAddMemberNone =>
      'Tutti nell\'organizzazione sono già in questa band.';

  @override
  String get bandOrgAdminHint =>
      'Gestisci questa band come admin dell\'organizzazione.';

  @override
  String get bandErrorNotOrgMember =>
      'Questa persona non è membro dell\'organizzazione.';

  @override
  String get orgName => 'Nome dell\'organizzazione';

  @override
  String get orgPeople => 'Persone';

  @override
  String get orgBands => 'Band';

  @override
  String get orgRemove => 'Rimuovi dall\'organizzazione';

  @override
  String orgRemoveTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String orgRemoveMessage(String name) {
    return '$name lascerà anche tutte le band dell\'organizzazione e non vedrà più i suoi brani.';
  }

  @override
  String get orgLeave => 'Lascia l\'organizzazione';

  @override
  String orgLeaveTitle(String org) {
    return 'Lasciare $org?';
  }

  @override
  String get orgLeaveMessage =>
      'Lascerai anche tutte le sue band e non vedrai più i suoi brani.';

  @override
  String get orgSongsShared =>
      'Tutte le band dell\'organizzazione condividono gli stessi brani.';

  @override
  String get copyToLibraryTitle => 'Copiare in quale libreria di brani?';

  @override
  String get inviteCreate => 'Invita persone';

  @override
  String get inviteCreateHint =>
      'Crea un link valido per 7 giorni. Chi lo apre entra nell\'organizzazione come membro, ma non ancora in una band. Poi aggiungilo a una band; sotto Persone puoi cambiare il suo ruolo.';

  @override
  String get inviteLinkTitle => 'Link d\'invito';

  @override
  String inviteLinkHint(String date) {
    return 'Condividi il link, p. es. in una chat di gruppo, o fai scansionare il codice QR. Valido fino al $date. Puoi mostrarlo di nuovo dall\'elenco dei link.';
  }

  @override
  String get inviteCopy => 'Copia link';

  @override
  String get inviteCopied => 'Link copiato';

  @override
  String get invitesTitle => 'Link d\'invito';

  @override
  String inviteDates(String created, String expires) {
    return 'Creato il $created, valido fino al $expires';
  }

  @override
  String get inviteOrganizationOnly => 'Solo organizzazione';

  @override
  String get inviteShow => 'Mostra link';

  @override
  String inviteJoined(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Si sono uniti in $count: $names',
      one: 'Si è unito: $names',
      zero: 'Ancora nessuno si è unito',
    );
    return '$_temp0';
  }

  @override
  String get inviteRevoke => 'Revoca';

  @override
  String get inviteRevokeTitle => 'Revocare il link?';

  @override
  String get inviteRevokeMessage =>
      'Il link smetterà di funzionare. Chi si è già unito resta membro.';

  @override
  String get inviteAskAdmin =>
      'Chiedi un invito a un admin dell\'organizzazione o a un leader di band.';

  @override
  String get inviteErrorUnknown =>
      'Questo invito non esiste. Controlla il link.';

  @override
  String get inviteErrorExpired =>
      'Questo invito è scaduto. Chiedi un nuovo link.';

  @override
  String get inviteErrorRevoked =>
      'Questo invito è stato revocato. Chiedi un nuovo link.';

  @override
  String get joinTitle => 'Unisciti';

  @override
  String get joinHint => 'Incolla il link d\'invito che hai ricevuto.';

  @override
  String get joinLink => 'Link d\'invito';

  @override
  String get joinContinue => 'Continua';

  @override
  String get joinInvalidLink => 'Questo non è un link d\'invito valido.';

  @override
  String get joinScan => 'Scansiona codice QR';

  @override
  String get joinScanHint => 'Punta la fotocamera sul codice QR dell\'invito';

  @override
  String get scannerClose => 'Chiudi lo scanner';

  @override
  String get scannerTorchOn => 'Accendi la luce';

  @override
  String get scannerTorchOff => 'Spegni la luce';

  @override
  String get scannerSwitchCamera => 'Cambia fotocamera';

  @override
  String get scannerPickImage => 'Leggi un codice da una foto';

  @override
  String get scannerStarting => 'Avvio della fotocamera …';

  @override
  String get scannerPermissionTitle => 'Nessun accesso alla fotocamera';

  @override
  String get scannerPermissionMessage =>
      'Consenti a setDING di usare la fotocamera nelle impostazioni per scansionare codici QR.';

  @override
  String get scannerUnavailableTitle => 'La fotocamera non è disponibile';

  @override
  String get scannerUnavailableMessage =>
      'Forse la usa un\'altra app, oppure questo dispositivo non ne ha una.';

  @override
  String get scannerInUseMessage =>
      'Un\'altra app usa la fotocamera. Chiudila e riprova.';

  @override
  String get scannerPhotoFallback =>
      'Puoi anche leggere il codice da una foto.';

  @override
  String get scannerOpenSettings => 'Apri le impostazioni';

  @override
  String get scannerTryAgain => 'Riprova';

  @override
  String get scannerChoosePhoto => 'Scegli una foto';

  @override
  String get scannerNoCodeInPhoto => 'In questa foto non c\'è nessun codice';

  @override
  String joinQuestion(String org) {
    return 'Unirti a $org?';
  }

  @override
  String get joinExplanation =>
      'Diventi membro dell\'organizzazione e vedi i suoi brani. Un admin può poi aggiungerti a una band.';

  @override
  String joinAlreadyMember(String org) {
    return 'Sei già membro di $org.';
  }

  @override
  String get joinButton => 'Unisciti';

  @override
  String joinDone(String org) {
    return 'Ti sei unito a $org.';
  }

  @override
  String get joinSignInFirst => 'Accedi o crea un account per unirti.';

  @override
  String get joinHaveAccount => 'Ho già un account';

  @override
  String get inviteErrorUsed =>
      'Questo invito è già stato usato. Chiedi un nuovo link.';

  @override
  String get inviteErrorNotStored =>
      'Questo link non può essere mostrato di nuovo. Creane uno nuovo.';

  @override
  String get accountErrorInvitationRequired =>
      'Questo server accetta nuovi account solo con un link d\'invito.';

  @override
  String get accountErrorEmailNotVerified =>
      'Conferma prima il tuo indirizzo e-mail. Ti abbiamo inviato una nuova e-mail.';

  @override
  String get bandErrorFounderInvitationRequired =>
      'Le nuove organizzazioni richiedono un invito da fondatore dal gestore del server.';

  @override
  String get accountInviteOnlyHint =>
      'Su questo server i nuovi account richiedono un link d\'invito.';

  @override
  String accountVerifyEmail(String email) {
    return 'Quasi fatto: abbiamo inviato un\'e-mail a $email. Conferma il tuo indirizzo con il link contenuto, poi accedi.';
  }

  @override
  String get accountVerifyResend => 'Invia di nuovo l\'e-mail';

  @override
  String get accountVerifySent => 'E-mail inviata.';

  @override
  String joinFoundQuestion(String org) {
    return 'Fondare $org?';
  }

  @override
  String get joinFoundExplanation =>
      'Crei l\'organizzazione e ne diventi admin. Poi puoi creare band e invitare persone.';

  @override
  String get joinFoundButton => 'Fonda organizzazione';

  @override
  String joinFoundDone(String org) {
    return 'Hai fondato $org.';
  }

  @override
  String get syncTitle => 'Sincronizzazione';

  @override
  String get syncNow => 'Sincronizza ora';

  @override
  String get settingsSyncMode => 'Sincronizzazione';

  @override
  String get syncModeAutomatic => 'Automatica';

  @override
  String get syncModeOnStart => 'All\'avvio';

  @override
  String get syncModeManual => 'Manuale';

  @override
  String get syncModeAutomaticHint =>
      'Sincronizza all\'avvio, pochi secondi dopo le modifiche, quando qualcosa cambia sul server e ogni 5 minuti.';

  @override
  String get syncModeOnStartHint =>
      'Sincronizza una volta all\'avvio dell\'app e dopo l\'accesso. Altrimenti con \"Sincronizza ora\".';

  @override
  String get syncModeManualHint =>
      'Sincronizza solo quando tocchi \"Sincronizza ora\".';

  @override
  String get syncRunning => 'Sincronizzazione …';

  @override
  String syncLast(String time) {
    return 'Ultima sincronizzazione: $time';
  }

  @override
  String get syncNever => 'Non ancora sincronizzato';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche non sono ancora sul server.',
      one: '1 modifica non è ancora sul server.',
      zero: 'Tutte le modifiche sono sul server.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline =>
      'Nessuna connessione – le modifiche verranno inviate più tardi.';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani con un conflitto – aprili per decidere.',
      one: '1 brano con un conflitto – aprilo per decidere.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBanner =>
      'Questo brano è stato modificato sul server e su questo dispositivo.';

  @override
  String get conflictBannerDeleted =>
      'Questo brano è stato eliminato sul server e modificato su questo dispositivo.';

  @override
  String get conflictKeepMine => 'Mantieni la mia';

  @override
  String get conflictTakeServer => 'Usa la versione del server';

  @override
  String get conflictKeepBoth => 'Mantieni entrambe';

  @override
  String get conflictCompare => 'Mostra la versione del server';

  @override
  String get conflictServerVersion => 'Versione del server';

  @override
  String get conflictKeptBoth =>
      'La tua versione è stata salvata come brano separato.';

  @override
  String get accountErrorConflict =>
      'Nel frattempo il brano è stato modificato sul server.';

  @override
  String get pdfMissing =>
      'Il PDF non è ancora su questo dispositivo. Verrà scaricato con la prossima sincronizzazione.';

  @override
  String get pdfLoadFailed =>
      'Impossibile caricare il PDF dal server. Controlla la connessione e apri di nuovo il brano.';

  @override
  String get openAttachment => 'Apri';

  @override
  String get imageMissing => 'L\'immagine non è su questo dispositivo.';

  @override
  String syncMissingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDF sono ancora in fase di download.',
      one: '1 PDF è ancora in fase di download.',
    );
    return '$_temp0';
  }

  @override
  String get invalidChordProTitle => 'Controllare il ChordPro?';

  @override
  String get invalidChordProMessage =>
      'Il brano contiene punti che probabilmente non verranno mostrati come previsto:';

  @override
  String problemUnclosedDirective(int line) {
    return 'Riga $line: una parentesi graffa (direttiva) non è chiusa.';
  }

  @override
  String problemUnclosedChord(int line) {
    return 'Riga $line: una parentesi quadra (accordo) non è chiusa.';
  }

  @override
  String problemUnclosedEnvironment(int line) {
    return 'Riga $line: il blocco non viene mai chiuso e contiene tutto il resto del brano.';
  }

  @override
  String problemTextAfterDirective(int line) {
    return 'Riga $line: testo dopo una direttiva; l\'intera riga viene mostrata come testo.';
  }

  @override
  String problemInvalidKey(int line) {
    return 'Riga $line: la direttiva key non indica nessuna tonalità; il brano non ha una tonalità per la trasposizione e le viste degli accordi.';
  }

  @override
  String chordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count punti nel ChordPro probabilmente non verranno mostrati come previsto',
      one:
          '1 punto nel ChordPro probabilmente non verrà mostrato come previsto',
    );
    return '$_temp0';
  }

  @override
  String chordProProblemsShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostra i $count problemi ChordPro',
      one: 'Mostra il problema ChordPro',
    );
    return '$_temp0';
  }

  @override
  String setChordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani con problemi ChordPro',
      one: '1 brano con problemi ChordPro',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsTitle => 'Controlla l\'importazione';

  @override
  String importProblemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani importati contengono punti',
      one: '1 brano importato contiene punti',
    );
    return '$_temp0 che probabilmente non verranno mostrati come previsto:';
  }

  @override
  String importProblemItem(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punti',
      one: '1 punto',
    );
    return '$title ($_temp0)';
  }

  @override
  String get importProblemsHint =>
      'I brani sono segnati nell\'elenco dei brani. La correzione automatica modifica solo i punti con una riparazione chiara; correggi il resto nell\'editor.';

  @override
  String songsFixed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani corretti',
      one: '1 brano corretto',
      zero: 'Nessun brano corretto',
    );
    return '$_temp0';
  }

  @override
  String moreProblems(int count) {
    return '… e altri $count.';
  }

  @override
  String get saveAnyway => 'Salva comunque';

  @override
  String get fixProblems => 'Correggi automaticamente';

  @override
  String get keepEditing => 'Continua a modificare';

  @override
  String get webSignInHint =>
      'Accedi per gestire organizzazioni, band, brani e set nel browser.';

  @override
  String get webNoBandTitle => 'Ancora nessuna band';

  @override
  String get webNoBandMessage =>
      'Non fai ancora parte di una band. Crea un\'organizzazione con una band, o unisciti con un link d\'invito.';

  @override
  String get songDetails => 'Dettagli del brano';

  @override
  String get songDetailsTooltip =>
      'Modifica titolo, tonalità, tempo e altro del brano – per tutti';

  @override
  String get noKey => 'Nessuna tonalità';

  @override
  String get timeHint => 'p. es. 4/4';

  @override
  String get noSequence => 'Nessuna sequenza';

  @override
  String get sequenceChange => 'Cambia sequenza del brano';

  @override
  String get sortSongs => 'Ordina';

  @override
  String get sortByTitle => 'Titolo';

  @override
  String get sortByArtist => 'Artista';

  @override
  String get sortByKey => 'Tonalità';

  @override
  String get sortByRecent => 'Modificati di recente';

  @override
  String get noArtist => 'Nessun artista';

  @override
  String get songConflictTooltip =>
      'Modificato qui e sul server – apri il brano per decidere';

  @override
  String get pdfOnlyTooltip => 'Solo spartito (PDF), senza accordi';

  @override
  String upcomingGigTooltip(String set, String date) {
    return 'In “$set” il $date';
  }

  @override
  String get foundInLyrics => 'Trovato nel testo';

  @override
  String hiddenParts(String parts) {
    return 'Nascoste (non nella sequenza): $parts';
  }

  @override
  String get setsUpcoming => 'Prossimi';

  @override
  String get setsUndated => 'Senza data';

  @override
  String setsPast(int count) {
    return 'Passati ($count)';
  }

  @override
  String get showPastSets => 'Mostra set passati';

  @override
  String get hidePastSets => 'Nascondi set passati';

  @override
  String get nextGig => 'Prossimo concerto';

  @override
  String gigInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Tra $days giorni',
      one: 'Domani',
      zero: 'Oggi',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Annulla';

  @override
  String songDeleted(String title) {
    return '“$title” eliminato';
  }

  @override
  String setDeleted(String name) {
    return 'Set “$name” eliminato';
  }

  @override
  String attachmentDeleted(String name) {
    return 'Allegato “$name” eliminato';
  }

  @override
  String setItemRemoved(String title) {
    return '“$title” rimosso dal set';
  }

  @override
  String get settingsGroupPersonal => 'Personale – su tutti i tuoi dispositivi';

  @override
  String get settingsGroupDevice => 'Questo dispositivo';

  @override
  String get settingsGroupAccount => 'Account e organizzazione';

  @override
  String get settingsScopePersonalHint =>
      'Queste impostazioni appartengono al tuo account e valgono su tutti i dispositivi su cui hai effettuato l\'accesso.';

  @override
  String get settingsScopePersonalSignedOutHint =>
      'Senza accesso, queste impostazioni valgono solo su questo dispositivo. Dopo l\'accesso vengono sincronizzate con il tuo account.';

  @override
  String get settingsScopeDeviceHint =>
      'Queste impostazioni valgono solo su questo dispositivo e non vengono sincronizzate.';

  @override
  String get settingsTakenOver =>
      'Sono state applicate le impostazioni del tuo account.';

  @override
  String get annotationsDraw => 'Disegna annotazioni';

  @override
  String get annotationsShow => 'Mostra annotazioni';

  @override
  String get annotationsHide => 'Nascondi annotazioni';

  @override
  String get annotationPen => 'Penna';

  @override
  String get annotationHighlighter => 'Evidenziatore';

  @override
  String get annotationText => 'Testo';

  @override
  String get annotationTextHint => 'Scrivi un testo';

  @override
  String get annotationEraser => 'Gomma (tratto intero)';

  @override
  String get annotationPartialEraser => 'Gomma (parte di un tratto)';

  @override
  String get annotationLasso => 'Seleziona (lazo)';

  @override
  String get annotationStamps => 'Timbri';

  @override
  String get annotationStampsMusic => 'Segni musicali';

  @override
  String get annotationStampsRepeats => 'Ripetizioni';

  @override
  String get annotationStampsCues => 'Segnali';

  @override
  String annotationColor(Object number) {
    return 'Colore $number';
  }

  @override
  String get annotationSize => 'Spessore della linea';

  @override
  String get annotationSmaller => 'Più piccolo';

  @override
  String get annotationLarger => 'Più grande';

  @override
  String get annotationDeleteSelection => 'Elimina selezione';

  @override
  String get annotationUndo => 'Annulla';

  @override
  String get annotationRedo => 'Ripeti';

  @override
  String get annotationMore => 'Altro';

  @override
  String get annotationDrawWithFinger => 'Disegna con il dito';

  @override
  String get annotationDone => 'Fatto';

  @override
  String get annotationsDeleteAll =>
      'Elimina tutte le annotazioni di questo brano';

  @override
  String get annotationsDeleted => 'Annotazioni eliminate';

  @override
  String get annotationsOtherLayout => 'Disegnate per un\'altra vista';

  @override
  String get annotationsOtherLayoutLandscape => 'Disegnate in orizzontale';

  @override
  String get annotationsOtherLayoutPortrait => 'Disegnate in verticale';

  @override
  String annotationsOrphaned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotazioni senza la loro riga',
      one: '1 annotazione senza la sua riga',
    );
    return '$_temp0';
  }

  @override
  String get annotationsFull =>
      'Annotazioni piene: cancellane alcune per disegnarne altre';

  @override
  String annotationsNearlyFull(int percent) {
    return 'Annotazioni piene al $percent %';
  }

  @override
  String get annotationsPanelTitle => 'Annotazioni a mano libera';

  @override
  String get annotationsPanelShow => 'Mostra le mie annotazioni';

  @override
  String annotationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotazioni',
      one: '1 annotazione',
      zero: 'Ancora nessuna: disegnale in modalità live',
    );
    return '$_temp0';
  }

  @override
  String get settingsShowAnnotations => 'Mostra annotazioni a mano libera';

  @override
  String get settingsShowAnnotationsHint =>
      'I tuoi disegni su brani e spartiti';

  @override
  String get settingsRepeatedChorusOnce =>
      'Mostra un ritornello scritto per esteso una sola volta';

  @override
  String get settingsRepeatedChorusOnceHint =>
      'Un ritornello riscritto più avanti parola per parola viene omesso';

  @override
  String get settingsShowOutsideSequence =>
      'Mostra le parti fuori dalla sequenza';

  @override
  String get settingsShowOutsideSequenceHint =>
      'Attenuate in modalità live invece che nascoste';

  @override
  String get settingsAnnotationFinger => 'Disegna annotazioni con il dito';

  @override
  String get settingsAnnotationFingerHint =>
      'Per dispositivi senza pennino; altrimenti le dita continuano a voltare pagina';

  @override
  String get settingsSpaceStartsBeat => 'Spazio avvia il battito';

  @override
  String get settingsSpaceStartsBeatHint =>
      'Spazio avvia e ferma battito e click come Invio, invece di andare avanti';

  @override
  String get stampFermata => 'Corona';

  @override
  String get stampBreath => 'Segno di respiro';

  @override
  String get stampCrescendo => 'Crescendo';

  @override
  String get stampDecrescendo => 'Decrescendo';

  @override
  String get stampRitardando => 'Ritardando';

  @override
  String get stampAccent => 'Accento';

  @override
  String stampRepeat(Object times) {
    return 'Suona $times×';
  }

  @override
  String get stampRepeatStart => 'Inizio ripetizione';

  @override
  String get stampRepeatEnd => 'Fine ripetizione';

  @override
  String get stampCoda => 'Coda';

  @override
  String get stampSegno => 'Segno';

  @override
  String get stampGlasses => 'Attenzione';

  @override
  String get stampStop => 'Stop';

  @override
  String get stampEye => 'Guarda';

  @override
  String get stampExclamation => 'Importante';

  @override
  String get stampStar => 'Stella';

  @override
  String get settingsSectionBands => 'Organizzazione e band';

  @override
  String get settingsCategoryBandsHint =>
      'Organizzazioni, band, membri e inviti';

  @override
  String get settingsBandsJoinHint =>
      'Unisciti a un\'organizzazione o a una band con un link d\'invito.';

  @override
  String get settingsSectionSongDisplay => 'Visualizzazione del brano';

  @override
  String get settingsCategorySongDisplayHint =>
      'Stili per sezione: accordi, testo, titoli, barre';

  @override
  String get songDisplayPreview => 'Anteprima';

  @override
  String get songDisplayPreset => 'Preimpostazione';

  @override
  String get songDisplayPresetClassic => 'Classico';

  @override
  String get songDisplayPresetColorCoded => 'A colori';

  @override
  String get songDisplayPresetChorusFocus => 'Focus sul ritornello';

  @override
  String get songDisplayPresetSinger => 'Voce';

  @override
  String get songDisplayPresetGuitar => 'Chitarra';

  @override
  String get songDisplayPresetMinimal => 'Minimale';

  @override
  String get songDisplayPresetBlackWhite => 'Bianco/nero';

  @override
  String get songDisplayPresetCustom => 'Personalizzato';

  @override
  String get songDisplayDiscardTitle => 'Scartare gli stili personalizzati?';

  @override
  String songDisplayDiscardMessage(String name) {
    return 'La preimpostazione “$name” sostituisce i tuoi stili personalizzati.';
  }

  @override
  String get songDisplayDiscard => 'Scarta';

  @override
  String get songDisplayFont => 'Carattere';

  @override
  String get songDisplayFontStandard => 'Standard';

  @override
  String get songDisplayFontMonospace => 'Monospaziato';

  @override
  String get songDisplaySection => 'Sezione';

  @override
  String get songDisplayTypeStandard => 'Standard';

  @override
  String get songDisplayTypeIntro => 'Intro';

  @override
  String get songDisplayTypeVerse => 'Verse';

  @override
  String get songDisplayTypePreChorus => 'Pre-chorus';

  @override
  String get songDisplayTypeChorus => 'Chorus';

  @override
  String get songDisplayTypeBridge => 'Bridge';

  @override
  String get songDisplayTypeInterlude => 'Interlude';

  @override
  String get songDisplayTypeOutro => 'Outro';

  @override
  String get songDisplayStandardHint =>
      'Stile di base per ogni sezione senza stile proprio e per le sezioni non riconosciute (p. es. tab, griglie, nomi personalizzati).';

  @override
  String get songDisplayStyle => 'Stile';

  @override
  String get songDisplayOwnStyle => 'Stile proprio';

  @override
  String songDisplayLike(String name) {
    return 'Come $name';
  }

  @override
  String songDisplayInheritsHint(String chain) {
    return 'Prende tutto da: $chain. Le modifiche lì valgono anche qui.';
  }

  @override
  String get songDisplayChords => 'Accordi';

  @override
  String get songDisplayLyrics => 'Testo';

  @override
  String get songDisplayHeading => 'Titolo';

  @override
  String get songDisplayBar => 'Barra di rientro';

  @override
  String get songDisplayBold => 'Grassetto';

  @override
  String get songDisplayItalic => 'Corsivo';

  @override
  String get songDisplaySize => 'Dimensione';

  @override
  String get songDisplayColor => 'Colore';

  @override
  String get songDisplayShowHeading => 'Mostra titolo';

  @override
  String get songDisplayShowBar => 'Mostra barra';

  @override
  String get songDisplayBarWidth => 'Larghezza';

  @override
  String get songDisplayIndent => 'Rientro';

  @override
  String get songDisplayTint => 'Colora lo sfondo';

  @override
  String get songDisplaySizeSmall => 'S';

  @override
  String get songDisplaySizeMedium => 'M';

  @override
  String get songDisplaySizeLarge => 'L';

  @override
  String get songDisplaySizeExtraLarge => 'XL';

  @override
  String get songDisplayBarThin => 'Sottile';

  @override
  String get songDisplayBarMedium => 'Media';

  @override
  String get songDisplayBarWide => 'Larga';

  @override
  String get songDisplayIndentNone => 'Nessuno';

  @override
  String get songDisplayIndentNormal => 'Normale';

  @override
  String get songDisplayIndentLarge => 'Grande';

  @override
  String get songColorAuto => 'Automatico';

  @override
  String get songColorBlue => 'Blu';

  @override
  String get songColorAmber => 'Ambra';

  @override
  String get songColorRed => 'Rosso';

  @override
  String get songColorGreen => 'Verde';

  @override
  String get songColorTeal => 'Verde acqua';

  @override
  String get songColorPurple => 'Viola';

  @override
  String get songColorPink => 'Rosa';

  @override
  String get songColorGrey => 'Grigio';

  @override
  String get songColorBlackWhite => 'Bianco/nero';

  @override
  String get songDisplayCustomise => 'Personalizza la visualizzazione';

  @override
  String get songDisplayCustomiseHint =>
      'Accordi, testo, titoli, barre e colori';

  @override
  String get songDisplayEditorTitle =>
      'Personalizza la visualizzazione del brano';

  @override
  String get songDisplayDemoSong => 'Brano demo';

  @override
  String get songDisplayLibrarySong => 'Brano dalla libreria …';

  @override
  String get songDisplayPickSong => 'Brano per l\'anteprima';

  @override
  String get songDisplayResizePreview =>
      'Trascina per ridimensionare l\'anteprima';

  @override
  String get appUpdateInstall => 'Installa';

  @override
  String appUpdateInstallTitle(String version) {
    return 'Installare setDING $version?';
  }

  @override
  String get appUpdateInstallBody =>
      'setDING si chiude, installa la nuova versione e si riavvia. I tuoi dati restano su questo dispositivo.';

  @override
  String get appUpdateDownloading => 'Download dell\'aggiornamento …';

  @override
  String get appUpdateFailed =>
      'Impossibile installare l\'aggiornamento. Riprova più tardi.';

  @override
  String get whatsNewTitle => 'Novità';

  @override
  String whatsNewAvailable(String version) {
    return 'Novità in setDING $version';
  }

  @override
  String get whatsNewShow => 'Mostra';

  @override
  String whatsNewVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get whatsNewAllChanges => 'Tutte le modifiche';

  @override
  String get midiTestTitle => 'Test MIDI (prototipo)';

  @override
  String get midiTestTileHint =>
      'Invia un program change a una tastiera collegata via USB, p. es. un Nord Stage 3';

  @override
  String get midiTestHint =>
      'Invia un program change a una tastiera collegata via USB, per testare il MIDI su questo dispositivo. Ciò che la tastiera invia, p. es. quando scegli un programma o un song su di essa, compare nel log.';

  @override
  String get midiTestDevices => 'Dispositivi';

  @override
  String get midiTestRefresh => 'Cerca di nuovo';

  @override
  String get midiTestNoDevices =>
      'Nessun dispositivo MIDI trovato. Collega la tastiera via USB e cerca di nuovo.';

  @override
  String get midiTestConnect => 'Collega';

  @override
  String get midiTestDisconnect => 'Scollega';

  @override
  String get midiTestConnected => 'Collegato';

  @override
  String get midiTestChannel => 'Canale MIDI';

  @override
  String get midiTestModeNordProgram => 'Programma Nord';

  @override
  String get midiTestModeNordSong => 'Song Nord';

  @override
  String get midiTestModeNordLive => 'Live Nord';

  @override
  String get midiTestModeRaw => 'Valori grezzi';

  @override
  String get midiTestBank => 'Banco';

  @override
  String get midiTestLive => 'Memoria live';

  @override
  String get midiTestMsb => 'Bank select MSB (CC 0, 0–127)';

  @override
  String get midiTestLsb => 'Bank select LSB (CC 32, 0–127)';

  @override
  String get midiTestProgram => 'Programma (1–128)';

  @override
  String get midiTestEmptyNotSent => 'Un bank select vuoto non viene inviato.';

  @override
  String get midiTestInvalid => 'Controlla i valori';

  @override
  String get midiTestSend => 'Invia';

  @override
  String get midiTestLog => 'Log';

  @override
  String get midiTestCopy => 'Copia log';

  @override
  String get midiTestCopied => 'Log copiato';

  @override
  String get midiTestClear => 'Svuota log';

  @override
  String midiTestSent(String bytes) {
    return 'Inviato: $bytes';
  }

  @override
  String midiTestReceivedCc(
    int controller,
    int value,
    int channel,
    String bytes,
  ) {
    return 'Ricevuto: CC $controller = $value (canale $channel) – $bytes';
  }

  @override
  String midiTestReceivedPc(
    int number,
    int program,
    int channel,
    String bytes,
  ) {
    return 'Ricevuto: program change $number (valore $program, canale $channel) – $bytes';
  }

  @override
  String midiTestReceivedOther(String bytes) {
    return 'Ricevuto: $bytes';
  }

  @override
  String midiTestError(String message) {
    return 'Errore: $message';
  }

  @override
  String get midiTestModeCc => 'Control change';

  @override
  String get midiTestController => 'Controller (CC 0–127)';

  @override
  String get midiTestValue => 'Valore (0–127)';

  @override
  String get midiTestCcHint =>
      'Nord Stage 3 secondo midi.guide: CC 2 modalità live, CC 3 modalità song, CC 5 parte del song. Quali valori fanno cosa fa parte del test.';

  @override
  String get midiGuideTitle => 'Test guidato';

  @override
  String get midiGuideHint =>
      'Tocca “Invia”, guarda il display del Nord e tocca cosa è successo. Sul Nord non serve impostare nulla. Le risposte vengono conservate nel log.';

  @override
  String get midiGuideNordSend => 'Nord Stage 3 – invio';

  @override
  String get midiGuideNordReceive => 'Nord Stage 3 – ricezione';

  @override
  String get midiGuideMotifSend => 'Motif XF – invio';

  @override
  String get midiGuideMotifReceive => 'Motif XF – ricezione';

  @override
  String get midiGuideNordReceiveHint =>
      'Sul Nord, nel menu MIDI imposta “Program Change” su “Send” o “Send & Receive” e imposta qui il canale sul canale globale del Nord. Poi scegli sul Nord un programma, una live memory o una parte di song qualsiasi, p. es. con la manopola o i tasti di modalità. setDING mostra cosa è arrivato; tocca se corrisponde al display. I risultati vengono conservati nel log.';

  @override
  String get midiGuideMotifSendHint =>
      'Sul Motif XF, in Utility → Control (F5) → MIDI (SF2): imposta MIDI IN/OUT su USB, attiva la ricezione di bank select e program change, imposta il Basic Receive Channel sul canale indicato qui e il Device Number su “all” o 1, poi salva con Store. Tocca “Invia”, guarda il display del Motif e tocca cosa è successo. Le risposte vengono conservate nel log.';

  @override
  String get midiGuideMotifReceiveHint =>
      'Sul Motif XF, in Utility → Control (F5) → MIDI (SF2): imposta MIDI IN/OUT su USB, attiva l\'invio di bank select e program change e imposta il Transmit Channel sul canale indicato qui, poi salva con Store. Poi scegli una voice o una performance qualsiasi sul Motif, anche in banchi diversi e due volte nello stesso banco. setDING mostra cosa è arrivato; tocca se corrisponde al display. I risultati vengono conservati nel log.';

  @override
  String midiGuideMotifExpected(String name) {
    return 'Il Motif mostra $name.';
  }

  @override
  String get midiGuideWaiting => 'Scegli un suono sulla tastiera …';

  @override
  String midiGuideFreeReceived(String name) {
    return 'Ricevuto: $name';
  }

  @override
  String get midiGuideMatches => 'Corrisponde al display';

  @override
  String get midiGuideNoMatch => 'Non corrisponde';

  @override
  String midiGuideFreeResult(String name, String values, String answer) {
    return 'Ricevuto $name ($values): $answer';
  }

  @override
  String midiGuideChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suoni controllati',
      one: '1 suono controllato',
      zero: 'Ancora niente controllato',
    );
    return '$_temp0';
  }

  @override
  String midiGuideStep(int current, int total, String title) {
    return 'Passo $current di $total: $title';
  }

  @override
  String midiGuideExpected(String expected) {
    return 'Previsto: $expected';
  }

  @override
  String get midiGuideDone => 'Test terminato. Le risposte sono nel log.';

  @override
  String get midiGuideRestart => 'Ricomincia';

  @override
  String get midiGuideBack => 'Indietro';

  @override
  String get midiGuideSkip => 'Salta';

  @override
  String midiGuideResult(int current, String title, String answer) {
    return 'Passo $current ($title): $answer';
  }

  @override
  String midiGuideProgram(String name) {
    return 'Programma $name';
  }

  @override
  String midiGuideProgramExpected(String name) {
    return 'Il Nord mostra $name.';
  }

  @override
  String midiGuideLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiGuideLiveExpected(int number) {
    return 'Il Nord mostra Live $number.';
  }

  @override
  String get midiGuideSongModeOn => 'Modalità song attiva (CC 3 = 127)';

  @override
  String get midiGuideSongModeOnExpected => 'Il Nord passa alla modalità song.';

  @override
  String get midiGuideSongModeOff => 'Modalità song disattiva (CC 3 = 0)';

  @override
  String get midiGuideSongModeOffExpected =>
      'Il Nord esce dalla modalità song.';

  @override
  String get midiGuideAnswerAsExpected => 'Come previsto';

  @override
  String get midiGuideAnswerDifferent => 'Altro';

  @override
  String get midiGuideAnswerNothing => 'Non è successo nulla';

  @override
  String get midiTestFree => 'Invio libero';

  @override
  String get midiTestPage => 'Pagina';

  @override
  String get midiTestButton => 'Tasto';

  @override
  String midiGuideSong(int song, int part) {
    return 'Song $song, parte $part';
  }

  @override
  String midiGuideSongExpected(int song, int part) {
    return 'Il Nord mostra il song $song, parte $part.';
  }

  @override
  String get midiTestSong => 'Song';

  @override
  String get midiTestPart => 'Parte';

  @override
  String get settingsEditorTypingAids =>
      'Chiudi automaticamente parentesi e sezioni';

  @override
  String get settingsEditorTypingAidsHint =>
      'Nell\'editor ChordPro: [ aggiunge ], Invio dopo l\'inizio di una sezione aggiunge la sua fine, e rinominare l\'inizio di una sezione rinomina anche la sua fine.';

  @override
  String get settingsDeveloperMode => 'Modalità sviluppatore';

  @override
  String get settingsDeveloperModeHint =>
      'Mostra la categoria “Sviluppo” con funzioni sperimentali da testare. Non serve per l\'uso normale.';

  @override
  String get settingsGroupDevelopment => 'Sviluppo';

  @override
  String get settingsSectionDevelopment => 'Funzioni di test';

  @override
  String get settingsCategoryDevelopmentHint => 'Sperimentale, solo per test';

  @override
  String get settingsDevelopmentNoteTitle => 'Funzioni sperimentali';

  @override
  String get settingsDevelopmentNote =>
      'Queste funzioni servono per i test. Possono cambiare, avere errori o sparire di nuovo. Non pensate per i concerti. Nascondile con “Modalità sviluppatore” in Generale.';

  @override
  String get settingsSectionMidi => 'Tastiera (MIDI)';

  @override
  String get settingsCategoryMidiHint =>
      'Program change a una tastiera collegata via USB';

  @override
  String get settingsMidiEnabled => 'Program change MIDI';

  @override
  String get settingsMidiEnabledHint =>
      'In modalità live la tastiera passa al programma salvato per ogni brano.';

  @override
  String settingsMidiConnected(String name) {
    return 'Collegato a $name';
  }

  @override
  String get settingsMidiNotConnected => 'Non collegato';

  @override
  String get settingsMidiOutput => 'Uscita';

  @override
  String get settingsMidiOutputHint =>
      'La tastiera collegata via USB. setDING si ricollega da solo quando viene collegata.';

  @override
  String get settingsMidiNoDevices =>
      'Nessun dispositivo MIDI trovato. Collega la tastiera via USB e cerca di nuovo.';

  @override
  String get settingsMidiSearch => 'Cerca di nuovo';

  @override
  String settingsMidiOutputMissing(String name) {
    return '$name (non collegato)';
  }

  @override
  String get settingsMidiProfile => 'Profilo del dispositivo';

  @override
  String get settingsMidiProfileHint =>
      'Come vengono inseriti e mostrati i programmi della tastiera. “Generico” usa bank select e numero di programma e funziona con qualsiasi tastiera.';

  @override
  String get midiProfileNordStage3 => 'Nord Stage 3';

  @override
  String get midiProfileGeneric => 'Generico';

  @override
  String get settingsMidiChannel => 'Canale MIDI';

  @override
  String get settingsMidiChannelHint => 'Il canale su cui riceve la tastiera.';

  @override
  String get settingsMidiTakeOver => 'Adotta i programmi dalla tastiera';

  @override
  String get settingsMidiTakeOverHint =>
      'Mentre il programma della tastiera è aperto in modalità live, setDING mostra il suono che scegli sulla tastiera e, se vuoi, lo adotta nel brano. La tastiera deve inviare bank select e program change.';

  @override
  String get settingsMidiTakeOverNordHint =>
      'Mentre il programma della tastiera è aperto in modalità live, setDING mostra il suono che scegli sul Nord e, se vuoi, lo adotta nel brano. Sul Nord, nel menu MIDI imposta “Program Change” su “Send” o “Send & Receive”.';

  @override
  String get settingsMidiNordHint =>
      'Sul Nord Stage 3 attiva la ricezione di “Program Change” nel suo menu MIDI e imposta qui il canale sul canale globale del Nord. La numerazione dei song del Nord dipende dalla versione OS del Nord (verificata con OS 2.54); se un song non corrisponde, usa il profilo “Generico”.';

  @override
  String get midiProgramTitle => 'Programma della tastiera';

  @override
  String get midiProgramHint =>
      'Inviato alla tastiera in modalità live quando arriva questo brano.';

  @override
  String get midiProgramNone => 'Nessuno: la tastiera mantiene il suo suono';

  @override
  String get midiProgramChoose => 'Scegli programma';

  @override
  String get midiProgramPreviewSwitch => 'Invia durante la selezione';

  @override
  String get midiProgramPreviewHint =>
      'Ogni scelta va subito alla tastiera; Annulla ripristina il programma precedente.';

  @override
  String get midiProgramRemove => 'Rimuovi programma';

  @override
  String get midiProgramTest => 'Prova';

  @override
  String get midiProgramTestHint =>
      'Invia una volta il programma alla tastiera';

  @override
  String get midiProgramNotConnected => 'Tastiera non collegata';

  @override
  String get midiProgramOff =>
      'I program change MIDI sono disattivati su questo dispositivo (impostazioni: Tastiera (MIDI)).';

  @override
  String midiProgramSent(String device) {
    return 'Inviato a $device';
  }

  @override
  String get midiProgramSendFailed => 'Impossibile inviare il programma';

  @override
  String get midiProgramKindProgram => 'Programma';

  @override
  String get midiProgramKindLive => 'Live memory';

  @override
  String get midiProgramKindSong => 'Song';

  @override
  String get midiProgramKindGeneric => 'Altri valori';

  @override
  String get midiProgramBank => 'Banco';

  @override
  String get midiProgramPageButton => 'Pagina (riga) e tasto';

  @override
  String get midiProgramSongNumber => 'Song';

  @override
  String get midiProgramPreviousSong => 'Song precedente';

  @override
  String get midiProgramNextSong => 'Song successivo';

  @override
  String get midiProgramPart => 'Parte';

  @override
  String get midiProgramSongHint =>
      'La numerazione dei song del Nord dipende dalla versione OS del Nord (verificata con OS 2.54). Se un song non corrisponde, usa il profilo “Generico” nelle impostazioni.';

  @override
  String get midiProgramsTitle => 'Programmi della tastiera';

  @override
  String midiProgramDevice(String profile) {
    return 'Questo dispositivo: $profile';
  }

  @override
  String get midiProgramForOtherKeyboard => 'Programma per un\'altra tastiera';

  @override
  String midiProgramUnknownKeyboard(String id) {
    return 'Tastiera sconosciuta ($id)';
  }

  @override
  String get midiProgramMsb => 'Bank select MSB (facoltativo)';

  @override
  String get midiProgramLsb => 'Bank select LSB (facoltativo)';

  @override
  String get midiProgramNumber => 'Programma';

  @override
  String midiProgramRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String midiProgramOutOfRange(int min, int max) {
    return 'Inserisci un numero da $min a $max';
  }

  @override
  String midiProgramValueNord(String name) {
    return 'Programma $name';
  }

  @override
  String get midiProfileMotifXf => 'Yamaha Motif XF';

  @override
  String get settingsMidiMotifHint =>
      'Sul Motif XF, in Utility → Control (F5) → MIDI (SF2): imposta MIDI IN/OUT su USB, attiva la ricezione di Bank Select e Program Change, imposta il Basic Receive Channel sul canale indicato qui e il Device Number su “all” o 1, poi salva con Store. setDING porta da solo il Motif in modalità voice o performance prima di ogni programma.';

  @override
  String get midiProgramKindPerformance => 'Performance';

  @override
  String get midiProgramKindVoice => 'Voice';

  @override
  String get midiProgramGroup => 'Gruppo';

  @override
  String get midiProgramMotifNumber => 'Numero';

  @override
  String get midiProgramMotifHint =>
      'Come sul display del Motif XF, p. es. USR1 A01. setDING porta il Motif in modalità voice o performance prima dell\'invio.';

  @override
  String midiProgramValueMotifVoice(String name) {
    return 'Voice $name';
  }

  @override
  String midiProgramValueMotifPerformance(String name) {
    return 'Performance $name';
  }

  @override
  String get midiTestModeMotif => 'Motif XF';

  @override
  String midiProgramShortLive(int number) {
    return 'Live $number';
  }

  @override
  String midiProgramShortSong(int song, int part) {
    return 'S$song:$part';
  }

  @override
  String midiProgramShortPerformance(String name) {
    return 'P $name';
  }

  @override
  String midiProgramShortGeneric(int program, String msb, String lsb) {
    return '$program ($msb/$lsb)';
  }

  @override
  String midiProgramValueLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiProgramValueSong(int song, int part) {
    return 'Song $song, parte $part';
  }

  @override
  String midiProgramValueGeneric(int program) {
    return 'Programma $program';
  }

  @override
  String midiProgramValueMsb(int value) {
    return 'MSB $value';
  }

  @override
  String midiProgramValueLsb(int value) {
    return 'LSB $value';
  }

  @override
  String get trash => 'Cestino';

  @override
  String trashWithCount(int count) {
    return 'Cestino ($count)';
  }

  @override
  String get trashSongsTitle => 'Brani eliminati';

  @override
  String get trashSetsTitle => 'Set eliminati';

  @override
  String trashEmpty(int days) {
    return 'Il cestino è vuoto. I brani e i set eliminati possono essere ripristinati qui per $days giorni.';
  }

  @override
  String trashHint(int days) {
    return 'I brani e i set eliminati possono essere ripristinati per $days giorni. Dopo vengono rimossi definitivamente.';
  }

  @override
  String trashDeletedOn(String date) {
    return 'eliminato il $date';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'ancora $days giorni',
      one: 'ancora 1 giorno',
      zero: 'ultimo giorno',
    );
    return '$_temp0';
  }

  @override
  String get trashRestore => 'Ripristina';

  @override
  String trashRestored(String title) {
    return '\"$title\" ripristinato';
  }

  @override
  String get trashGroupToday => 'Oggi';

  @override
  String get trashGroupWeek => 'Questa settimana';

  @override
  String get trashGroupOlder => 'Meno recenti';

  @override
  String trashMenu(String title) {
    return 'Azioni per \"$title\"';
  }

  @override
  String get trashPurge => 'Elimina definitivamente';

  @override
  String get trashPurgeTitle => 'Eliminare definitivamente?';

  @override
  String trashPurgeOne(String title) {
    return '\"$title\" verrà eliminato definitivamente. L\'operazione non può essere annullata.';
  }

  @override
  String trashPurgeMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi verranno eliminati',
      one: '1 elemento verrà eliminato',
    );
    return '$_temp0 definitivamente. L\'operazione non può essere annullata.';
  }

  @override
  String get trashEmptyAction => 'Svuota cestino';

  @override
  String get trashEmptyTitle => 'Svuotare il cestino?';

  @override
  String trashPurged(String title) {
    return '\"$title\" eliminato definitivamente';
  }

  @override
  String trashPurgedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi eliminati',
      one: '1 elemento eliminato',
    );
    return '$_temp0 definitivamente';
  }

  @override
  String trashRestoredMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi ripristinati',
      one: '1 elemento ripristinato',
    );
    return '$_temp0';
  }

  @override
  String get backupExport => 'Esegui backup della libreria';

  @override
  String get backupSyncing => 'Sincronizzazione con il server …';

  @override
  String get backupCollecting => 'Creazione del backup …';

  @override
  String get backupSaved => 'Backup salvato.';

  @override
  String get backupFailedTitle => 'Backup non possibile';

  @override
  String get backupSyncDeferred =>
      'La modalità live è aperta. Chiudila e riprova.';

  @override
  String get backupSyncFailed =>
      'La sincronizzazione con il server non è riuscita. Il backup di un\'organizzazione richiede una connessione funzionante, così contiene tutto. Riprova quando sei online.';

  @override
  String get backupPendingChanges =>
      'Le modifiche su questo dispositivo non hanno ancora raggiunto il server. Attendi la sincronizzazione e riprova.';

  @override
  String get backupConflicts =>
      'Alcuni brani hanno un conflitto di sincronizzazione. Risolvi prima i conflitti.';

  @override
  String get backupMissingFiles =>
      'Non tutti gli allegati sono ancora scaricati. Attendi il download e riprova.';

  @override
  String backupFileMissing(String name, String song) {
    return 'Impossibile caricare l\'allegato \"$name\" di \"$song\".';
  }

  @override
  String get backupInvalid => 'Questo file non è un backup di setDING.';

  @override
  String get backupNewer =>
      'Questo backup è stato creato con una versione più recente di setDING. Aggiorna l\'app per importarlo.';

  @override
  String get backupImportTitle => 'Importa backup';

  @override
  String backupImportSummary(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return 'Backup di \"$library\": $_temp0, $_temp1.';
  }

  @override
  String get backupImportCopyHint =>
      'Tutto viene importato come copia nella libreria attuale. Niente di esistente viene modificato.';

  @override
  String backupImportIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani sono',
      one: '1 brano è',
    );
    return '$_temp0 già qui con lo stesso testo e verranno usati così come sono.';
  }

  @override
  String backupImportDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani esistono',
      one: '1 brano esiste',
    );
    return '$_temp0 qui con un testo diverso:';
  }

  @override
  String get backupKeepExisting => 'Mantieni i brani esistenti';

  @override
  String get backupAddAll => 'Importa come brani aggiuntivi';

  @override
  String get backupImportSetsTo => 'I set vanno in:';

  @override
  String backupBandSets(String band, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count set',
      one: '1 set',
    );
    return '$band ($_temp0)';
  }

  @override
  String get backupSkipSets => 'Non importare';

  @override
  String get backupImportStart => 'Importa';

  @override
  String get backupImportDone => 'Backup importato';

  @override
  String backupResultSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani importati',
      one: '1 brano importato',
    );
    return '$_temp0';
  }

  @override
  String backupResultIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani erano già qui',
      one: '1 brano era già qui',
    );
    return '$_temp0';
  }

  @override
  String backupResultKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani esistenti mantenuti',
      one: '1 brano esistente mantenuto',
    );
    return '$_temp0';
  }

  @override
  String backupResultSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count set importati',
      one: '1 set importato',
      zero: 'Nessun set importato',
    );
    return '$_temp0';
  }

  @override
  String backupResultFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count allegati',
      one: '1 allegato',
    );
    return '$_temp0';
  }

  @override
  String backupResultAdditional(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Questi brani ora esistono due volte. Confrontali con quelli esistenti ed elimina quelli che non ti servono:',
      one: 'Questo brano ora esiste due volte. Confrontalo con quello esistente ed elimina quello che non ti serve:',
    );
    return '$_temp0';
  }

  @override
  String get bandDelete => 'Elimina band';

  @override
  String bandDeleteTitle(String band) {
    return 'Eliminare $band?';
  }

  @override
  String bandDeleteMessage(int days) {
    return 'I suoi set, gli arrangiamenti della band e le iscrizioni vengono eliminati con essa, e i suoi inviti aperti vengono revocati. I brani restano nella libreria dell\'organizzazione. Gli admin dell\'organizzazione possono ripristinare la band dal cestino per $days giorni. Per conservare una copia fuori da setDING, esegui prima il backup della libreria.';
  }

  @override
  String bandDeleteSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count set',
      one: '1 set',
      zero: 'nessun set',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri',
      one: '1 membro',
      zero: 'nessun membro',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti aperti',
      one: '1 invito aperto',
      zero: 'nessun invito aperto',
    );
    return '$_temp0';
  }

  @override
  String get bandDeleteLastBand =>
      'Questa è l\'ultima band dell\'organizzazione. L\'organizzazione e la sua libreria di brani restano.';

  @override
  String bandDeleteConfirmName(String band) {
    return 'Digita \"$band\" per confermare';
  }

  @override
  String bandDeleted(String band) {
    return '$band eliminata';
  }

  @override
  String get trashBandsTitle => 'Band eliminate';

  @override
  String trashBandsEmpty(int days) {
    return 'Nessuna band eliminata. Le band eliminate possono essere ripristinate qui per $days giorni.';
  }

  @override
  String trashBandsHint(int days) {
    return 'Le band eliminate possono essere ripristinate con i loro set, arrangiamenti e membri per $days giorni. Dopo vengono rimosse definitivamente.';
  }

  @override
  String bandsGone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names non sono più disponibili per te: le band sono state eliminate o non ne sei più membro.',
      one:
          '$names non è più disponibile per te: la band è stata eliminata o non ne sei più membro.',
    );
    return '$_temp0';
  }

  @override
  String get backupAll => 'Esegui backup di tutto';

  @override
  String get backupAllName => 'tutto';

  @override
  String get backupAllHint =>
      'Le tue librerie con brani, set e allegati, i tuoi adattamenti personali e le note, e le tue impostazioni, in un unico file.';

  @override
  String get backupNever => 'Ancora nessun backup su questo dispositivo.';

  @override
  String backupLast(String date) {
    return 'Ultimo backup: $date';
  }

  @override
  String get backupRestore => 'Ripristina backup';

  @override
  String get backupRestoreHint =>
      'Importa un file di backup come copia, oppure sostituisce la libreria “Su questo dispositivo” con il suo backup.';

  @override
  String get backupRestoreTitle => 'Ripristina backup';

  @override
  String backupLibraryTo(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return '\"$library\" ($_temp0, $_temp1) in';
  }

  @override
  String get backupImportDifferingAll =>
      'Brani che esistono qui con un testo diverso:';

  @override
  String get backupRestorePersonal =>
      'Ripristina i miei adattamenti personali e le note';

  @override
  String backupPersonalOf(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$library: $_temp0';
  }

  @override
  String get backupRestoreSettings => 'Ripristina le mie impostazioni';

  @override
  String get backupRestoreSettingsHint =>
      'Sostituisce le tue impostazioni attuali con quelle del backup.';

  @override
  String get backupRestoreStart => 'Ripristina';

  @override
  String get backupRestoreDone => 'Backup ripristinato';

  @override
  String backupResultPersonal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return 'Adattamenti personali e note di $_temp0 ripristinati';
  }

  @override
  String get backupResultSettings => 'Impostazioni ripristinate';

  @override
  String backupReminder(int days) {
    return 'Da $days giorni non è stato fatto un backup della tua libreria su questo dispositivo.';
  }

  @override
  String get backupReminderAction => 'Esegui backup';

  @override
  String get orgClose => 'Chiudi organizzazione';

  @override
  String orgCloseTitle(String org) {
    return 'Chiudere $org?';
  }

  @override
  String orgCloseMessage(int days) {
    return 'Le sue band, i set, i brani e gli allegati e gli adattamenti personali di tutti per i suoi brani vengono rimossi, e i suoi inviti vengono revocati. I membri vengono informati alla prossima sincronizzazione. I suoi admin possono ripristinarla dal cestino per $days giorni; dopo tutto viene eliminato definitivamente.';
  }

  @override
  String orgCloseBands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count band',
      one: '1 band',
      zero: 'nessuna band',
    );
    return '$_temp0';
  }

  @override
  String orgCloseSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
      zero: 'nessun brano',
    );
    return '$_temp0';
  }

  @override
  String orgClosePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persone',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get orgCloseBackup => 'Prima esegui il backup';

  @override
  String orgClosed(String org) {
    return '$org chiusa';
  }

  @override
  String get orgsClosedTitle => 'Organizzazioni chiuse';

  @override
  String orgsClosedEmpty(int days) {
    return 'Nessuna organizzazione chiusa. I loro admin possono ripristinare qui le organizzazioni chiuse per $days giorni.';
  }

  @override
  String orgsClosedHint(int days) {
    return 'Le organizzazioni chiuse possono essere ripristinate con tutto il loro contenuto per $days giorni. Dopo vengono eliminate definitivamente.';
  }

  @override
  String orgClosedOn(String date) {
    return 'chiusa il $date';
  }

  @override
  String orgClosedBy(String name) {
    return 'da $name';
  }

  @override
  String orgClosedNotice(String org, String name, int days) {
    return '$org è stata chiusa da $name. I suoi admin possono ripristinarla per $days giorni.';
  }

  @override
  String orgClosedNoticeAnonymous(String org, int days) {
    return '$org è stata chiusa. I suoi admin possono ripristinarla per $days giorni.';
  }

  @override
  String get navOverview => 'Panoramica';

  @override
  String get overviewNextSet => 'Prossimo set';

  @override
  String get overviewLastEditedSet => 'Ultimo set modificato';

  @override
  String overviewSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
      zero: 'Nessun brano',
    );
    return '$_temp0';
  }

  @override
  String get overviewStartLive => 'Avvia live';

  @override
  String get overviewOpenSet => 'Apri set';

  @override
  String get overviewTodo => 'Da fare';

  @override
  String overviewTodoProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani con problemi ChordPro',
      one: '1 brano con problemi ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani con conflitti di sincronizzazione',
      one: '1 brano con un conflitto di sincronizzazione',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoSheetMusicOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani solo con spartito (PDF)',
      one: '1 brano solo con spartito (PDF)',
    );
    return '$_temp0';
  }

  @override
  String get attentionProblems => 'Problemi ChordPro';

  @override
  String get attentionConflicts => 'Conflitti di sincronizzazione';

  @override
  String get attentionSheetMusicOnly => 'Solo spartito';

  @override
  String chordProConversionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Converti $count punti nel ChordPro',
      one: 'Converti 1 punto nel ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani con possibili conversioni',
      one: '1 brano con possibili conversioni',
    );
    return '$_temp0';
  }

  @override
  String get attentionConversions => 'Convertibili';

  @override
  String get convertAllSongs => 'Converti tutti';

  @override
  String get convertAllSongsTitle => 'Convertire tutti i brani?';

  @override
  String convertAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I $count brani vengono convertiti',
      one: 'Il brano viene convertito',
    );
    return '$_temp0 per tutti: direttive CCLI ed etichette di sezione come raccomanda la specifica ChordPro, stanghette CCLI come griglie, piè di pagina CCLI rimosso.';
  }

  @override
  String songsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani convertiti',
      one: '1 brano convertito',
    );
    return '$_temp0';
  }

  @override
  String songConverted(String title) {
    return '“$title” convertito';
  }

  @override
  String get songsFilterEmpty => 'Nessun brano rimasto in questo filtro.';

  @override
  String get playHistory => 'Suonato';

  @override
  String playHistoryOf(String band) {
    return 'Suonato da $band';
  }

  @override
  String playHistoryNone(String band) {
    return '$band non ha ancora suonato questo brano in un set passato.';
  }

  @override
  String get playHistoryTotal => 'in totale';

  @override
  String get playHistoryLastYear => 'ultimi 12 mesi';

  @override
  String get playHistoryLast => 'ultima volta';

  @override
  String playHistoryFirst(String date) {
    return 'La prima volta il $date';
  }

  @override
  String playHistoryShowAll(int count) {
    return 'Mostra tutti e $count';
  }

  @override
  String playHistoryDiffers(String key) {
    return 'Evidenziato: una tonalità diversa da quella di oggi ($key)';
  }

  @override
  String get playHistoryApproximate =>
      '≈ derivato dall\'arrangiamento di oggi: il set non ha valori salvati';

  @override
  String keyHistoryLast(String key, String date) {
    return 'Ultima volta $key il $date';
  }

  @override
  String keyHistoryMostly(String key, int count, int total) {
    return 'per lo più $key ($count su $total)';
  }

  @override
  String songLastPlayed(String date) {
    return 'Suonato l\'ultima volta il $date';
  }

  @override
  String get songNeverPlayed => 'Mai suonato';

  @override
  String get overviewRecentChanges => 'Modifiche recenti';

  @override
  String get overviewShowAll => 'Mostra tutto';

  @override
  String get overviewMoreSets => 'Altri set';

  @override
  String get overviewNewestSongs => 'Brani più recenti';

  @override
  String get recentChangesEmpty =>
      'Nessuna modifica da parte di altri negli ultimi 30 giorni.';

  @override
  String get changeSongAdded => 'Nuovo brano';

  @override
  String get changeNewSet => 'Nuovo set';

  @override
  String get changeSongText => 'Testo modificato';

  @override
  String get changeSongPdf => 'PDF modificato';

  @override
  String get changeSongTextAndPdf => 'Testo e PDF modificati';

  @override
  String changeSetAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani aggiunti',
      one: '1 brano aggiunto',
    );
    return '$_temp0';
  }

  @override
  String changeSetRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani rimossi',
      one: '1 brano rimosso',
    );
    return '$_temp0';
  }

  @override
  String changeSetAlsoRemoved(int count) {
    return '$count rimossi';
  }

  @override
  String changeSetSequence(String songs) {
    return 'sequenza di $songs modificata';
  }

  @override
  String changeQuoted(String title) {
    return '\"$title\"';
  }

  @override
  String changeBy(String name) {
    return 'da $name';
  }

  @override
  String get repertoire => 'Repertorio';

  @override
  String repertoireOf(String band) {
    return 'Repertorio di $band';
  }

  @override
  String get repertoireLastYear => '12 mesi';

  @override
  String get repertoireAllTime => 'Sempre';

  @override
  String get repertoireMostPlayed => 'Più suonati';

  @override
  String get repertoireStale => 'Non suonati da un po\'';

  @override
  String repertoireStaleHint(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Suonati l\'ultima volta più di $months mesi fa',
      one: 'Suonati l\'ultima volta più di un mese fa',
    );
    return '$_temp0';
  }

  @override
  String get playedFilter => 'Suonati';

  @override
  String get playedAll => 'Tutti';

  @override
  String get filterByPlayed => 'Filtra per esecuzioni della band';

  @override
  String get repertoireNeverPlayed => 'Mai suonati';

  @override
  String get repertoireNeverPlayedHint =>
      'Brani della libreria che non erano in nessun set passato della band';

  @override
  String get repertoireNone => 'Nessuno';

  @override
  String get repertoireEmpty =>
      'La band non ha ancora suonato brani in set passati.';

  @override
  String repertoirePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count volte',
      one: 'una volta',
    );
    return '$_temp0';
  }

  @override
  String get repertoireThreshold =>
      'Quando un brano conta come non suonato da un po\'?';

  @override
  String repertoireMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Dopo $months mesi',
      one: 'Dopo 1 mese',
    );
    return '$_temp0';
  }

  @override
  String repertoireDefault(int months) {
    return 'Predefinito: dopo $months mesi';
  }

  @override
  String get sortByLastPlayed => 'Ultima esecuzione';

  @override
  String get playHistoryOtherBands => 'Altre band';

  @override
  String playHistoryFetched(String date) {
    return 'Al $date';
  }

  @override
  String get libraryUsage => 'Utilizzo della libreria';

  @override
  String libraryUsageSummary(int count, int total) {
    return 'Nessuna band suona $count brani su $total';
  }

  @override
  String get libraryUsageHint =>
      'Brani che non erano in nessun set passato di nessuna band dell\'organizzazione. Sposta nel cestino ciò che nessuna band usa più.';

  @override
  String get libraryUsageNotLoaded =>
      'Non ancora caricato: sincronizza una volta mentre sei collegato al server.';

  @override
  String get libraryUsageAllPlayed =>
      'Ogni brano della libreria è stato suonato da una band.';

  @override
  String syncHintSongChanged(String title, String name) {
    return '\"$title\" è stato modificato da $name.';
  }

  @override
  String syncHintSongDeleted(String title, String name) {
    return '\"$title\" è stato eliminato da $name.';
  }

  @override
  String syncHintSetChanged(String title, String name) {
    return 'Il set \"$title\" è stato modificato da $name.';
  }

  @override
  String syncHintSetDeleted(String title, String name) {
    return 'Il set \"$title\" è stato eliminato da $name.';
  }

  @override
  String syncHintSongChangedAnonymous(String title) {
    return '\"$title\" è stato modificato da qualcun altro.';
  }

  @override
  String syncHintSongDeletedAnonymous(String title) {
    return '\"$title\" è stato eliminato da qualcun altro.';
  }

  @override
  String syncHintSetChangedAnonymous(String title) {
    return 'Il set \"$title\" è stato modificato da qualcun altro.';
  }

  @override
  String syncHintSetDeletedAnonymous(String title) {
    return 'Il set \"$title\" è stato eliminato da qualcun altro.';
  }

  @override
  String syncHintAfterLive(String changes) {
    return 'Mentre suonavi live: $changes.';
  }

  @override
  String syncHintSongsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani modificati',
      one: '1 brano modificato',
    );
    return '$_temp0';
  }

  @override
  String syncHintSongsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani eliminati',
      one: '1 brano eliminato',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count set modificati',
      one: '1 set modificato',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count set eliminati',
      one: '1 set eliminato',
    );
    return '$_temp0';
  }

  @override
  String get syncHintShowChanges => 'Mostra';

  @override
  String get setExportTitle => 'Esporta set';

  @override
  String get setExportHint =>
      'Lo ZIP contiene i file ChordPro dei brani e una descrizione da cui setDING reimporta il set come set.';

  @override
  String get setArchiveArrangements =>
      'Arrangiamenti della band per i brani (tonalità, sequenza, tempo)';

  @override
  String get setArchiveSetSettings =>
      'Tonalità e sequenza dei brani in questo set';

  @override
  String get setArchiveAttachments => 'Allegati (PDF, immagini)';

  @override
  String get setArchivePersonal => 'I miei adattamenti personali e le note';

  @override
  String get setArchivePersonalHint =>
      'Lascialo disattivato se passi il file ad altri.';

  @override
  String get setExportStart => 'Esporta';

  @override
  String get exportMenu => 'Esporta …';

  @override
  String get exportFormat => 'Formato';

  @override
  String get exportFormatChordPro => 'File ChordPro';

  @override
  String get exportFormatChordProHint =>
      'Per altre app, senza allegati e arrangiamenti';

  @override
  String get exportFormatSetListPdf => 'Scaletta in PDF';

  @override
  String get exportFormatSetListPdfHint => 'Per la stampa';

  @override
  String get exportFormatArchive => 'Archivio setDING (ZIP)';

  @override
  String get exportFormatArchiveHint =>
      'Per importare in setDING, con allegati e arrangiamenti se vuoi';

  @override
  String get songExportHintChordPro =>
      'Il file ChordPro contiene testo e accordi del brano e si apre in qualsiasi app che conosce ChordPro.';

  @override
  String get setExportHintPdf =>
      'La scaletta mostra ogni brano con tonalità e sequenza, da stampare per il palco.';

  @override
  String get setImport => 'Importa set';

  @override
  String get setImportFromFile => 'Importa da file …';

  @override
  String get setImportTitle => 'Importa set';

  @override
  String get setImportBand => 'Band';

  @override
  String get setImportNoBand =>
      'In questa libreria non c\'è nessuna band di cui puoi gestire i set.';

  @override
  String setImportExisting(String name) {
    return 'La band ha già questo set come \"$name\".';
  }

  @override
  String get setImportReplace => 'Sostituiscilo';

  @override
  String get setImportCopy => 'Aggiungi come copia';

  @override
  String setImportOverwriteArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return 'Sovrascrivi gli arrangiamenti della band di $_temp0';
  }

  @override
  String get setImportDone => 'Set importato';

  @override
  String get setImportReplaced => 'Il set esistente è stato sostituito.';

  @override
  String setImportResultArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrangiamenti della band salvati',
      one: '1 arrangiamento della band salvato',
    );
    return '$_temp0';
  }

  @override
  String get setImportResultMissing =>
      'Non nella libreria, mostrati come elementi di testo nel set:';

  @override
  String get setImportOpen => 'Apri set';

  @override
  String setImportMissingNote(String title) {
    return 'Mancante: $title';
  }

  @override
  String get setArchiveInvalid => 'Questo file non è un set esportato.';

  @override
  String get setArchiveNewer =>
      'Questo set è stato esportato con una versione più recente di setDING. Aggiorna l\'app per importarlo.';

  @override
  String setImportFrom(String band, int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
      zero: 'nessun brano',
    );
    return 'da $band · $_temp0';
  }

  @override
  String get setImportHeadingTarget => 'Destinazione';

  @override
  String get setImportHeadingExisting => 'Set già presente';

  @override
  String get setImportHeadingSongs => 'Brani';

  @override
  String get setImportHeadingInclude => 'Includi';

  @override
  String get setExportHeadingInclude => 'Includi nell\'archivio';

  @override
  String setImportNewName(String name) {
    return 'Verrà aggiunto come \"$name\".';
  }

  @override
  String setImportSongsHere(int count) {
    return '$count già qui con lo stesso testo';
  }

  @override
  String setImportSongsNew(int count) {
    return '$count nuovi, aggiunti alla libreria';
  }

  @override
  String setImportSongsDiffering(int count) {
    return '$count qui con un testo diverso';
  }

  @override
  String setImportSongsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'li mostra',
      one: 'lo mostra',
    );
    return '$count non nella libreria – non puoi aggiungere brani, quindi il set $_temp0 come testo';
  }

  @override
  String get setImportKeep => 'Mantieni esistenti';

  @override
  String get setImportAddAll => 'Importa comunque';

  @override
  String setImportCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String setImportCopyNameNumbered(String name, int number) {
    return '$name (copia $number)';
  }

  @override
  String get keyboardShortcuts => 'Scorciatoie da tastiera';

  @override
  String get shortcutsEverywhere => 'Ovunque';

  @override
  String get shortcutsSong => 'Brano';

  @override
  String get shortcutsSet => 'Set';

  @override
  String get shortcutsSongList => 'Elenco dei brani';

  @override
  String get shortcutsLive => 'Modalità live';

  @override
  String get shortcutBack => 'Indietro';

  @override
  String get shortcutHelp => 'Mostra le scorciatoie da tastiera';

  @override
  String get shortcutEditSong => 'Modifica il brano';

  @override
  String get shortcutEditSet => 'Modifica il set';

  @override
  String get shortcutLive => 'Avvia la modalità live';

  @override
  String get shortcutTranspose => 'Trasponi su / giù';

  @override
  String get shortcutPreviousNextSong =>
      'Brano precedente / successivo del set';

  @override
  String get shortcutSearch => 'Cerca brani';

  @override
  String get shortcutNextPage => 'Pagina successiva';

  @override
  String get shortcutPreviousPage => 'Pagina precedente';

  @override
  String get shortcutBeat => 'Avvia / ferma il battito';

  @override
  String get shortcutKeyPageDown => 'Pagina giù';

  @override
  String get shortcutKeyPageUp => 'Pagina su';

  @override
  String get shortcutKeySpace => 'Spazio';

  @override
  String get shortcutCloseSelection => 'Chiudi la selezione';

  @override
  String get settingsHeadingLanguageTheme => 'Lingua e tema';

  @override
  String get settingsHeadingEditor => 'Editor';

  @override
  String get settingsHeadingAdvanced => 'Avanzate';

  @override
  String get settingsHeadingChords => 'Accordi';

  @override
  String get settingsHeadingContent => 'Contenuto';

  @override
  String get settingsHeadingSetNotes => 'Set e note';

  @override
  String get settingsHeadingInstrument => 'Strumento e voce';

  @override
  String get settingsHeadingScreen => 'Schermo';

  @override
  String get settingsHeadingControls => 'Comandi';

  @override
  String get settingsHeadingClick => 'Click su questo dispositivo';

  @override
  String get settingsHeadingBackup => 'Backup';

  @override
  String get settingsHeadingThisDevice => 'Questo dispositivo';

  @override
  String get settingsHeadingHelp => 'Aiuto e info';

  @override
  String get settingsHeadingConnection => 'Connessione';

  @override
  String get settingsHeadingKeyboard => 'Tastiera';

  @override
  String get settingsHeadingStyle => 'Stile';

  @override
  String get settingsHeadingPrototypes => 'Prototipi';

  @override
  String songExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esporta $count brani',
      one: 'Esporta brano',
    );
    return '$_temp0';
  }

  @override
  String get songExportHint =>
      'Lo ZIP contiene i file ChordPro e una descrizione da cui setDING reimporta i brani, più ciò che scegli qui sotto.';

  @override
  String songExportArrangements(String band) {
    return 'Arrangiamenti di \"$band\" (tonalità, sequenza, tempo)';
  }

  @override
  String get songImportTitle => 'Importa brani';

  @override
  String songImportFrom(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return 'da $library · $_temp0';
  }

  @override
  String songImportLibrary(String name) {
    return 'Nella libreria \"$name\"';
  }

  @override
  String get songImportArrangementsBand => 'Band per gli arrangiamenti';

  @override
  String get songImportNoBand =>
      'In questa libreria non c\'è nessuna band di cui puoi modificare gli arrangiamenti.';

  @override
  String get songImportDone => 'Brani importati';

  @override
  String get songArchiveNewer =>
      'Questi brani sono stati esportati con una versione più recente di setDING. Aggiorna l\'app per importarli.';

  @override
  String archiveImportAttachmentsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count allegati aggiunti',
      one: '1 allegato aggiunto',
    );
    return '$_temp0 a brani già presenti';
  }

  @override
  String archiveResultCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count allegati aggiunti',
      one: '1 allegato aggiunto',
    );
    return '$_temp0 a brani esistenti';
  }

  @override
  String songLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'Tedesco',
      'gsw': 'Svizzero tedesco',
      'en': 'Inglese',
      'fr': 'Francese',
      'it': 'Italiano',
      'es': 'Spagnolo',
      'pt': 'Portoghese',
      'nl': 'Olandese',
      'other': 'Altra',
    });
    return '$_temp0';
  }

  @override
  String songLanguageShort(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'DE',
      'gsw': 'CH',
      'en': 'EN',
      'fr': 'FR',
      'it': 'IT',
      'es': 'ES',
      'pt': 'PT',
      'nl': 'NL',
      'other': '–',
    });
    return '$_temp0';
  }

  @override
  String get songLanguage => 'Lingua';

  @override
  String get songLanguageMenu => 'Lingua …';

  @override
  String get allLanguages => 'Tutte le lingue';

  @override
  String get noLanguage => 'Nessuna lingua';

  @override
  String get filterByLanguage => 'Filtra per lingua';

  @override
  String songLanguageAutomatic(String language) {
    return 'Automatica: $language';
  }

  @override
  String get songLanguageNotDetected => 'Automatica (non rilevata)';

  @override
  String get songLanguageAutomaticHint =>
      'Rilevata dal testo; una scelta manuale ha sempre la precedenza.';

  @override
  String songLanguageDetectedTooltip(String language) {
    return '$language (rilevata dal testo)';
  }

  @override
  String songLanguageByHandTooltip(String language) {
    return '$language (impostata a mano)';
  }

  @override
  String get languageVersions => 'Versioni linguistiche';

  @override
  String get linkLanguageVersion => 'Versioni linguistiche …';

  @override
  String get unlinkLanguageVersion => 'Rimuovi dalle versioni linguistiche';

  @override
  String get languageVersionPickerEmpty =>
      'Nessun altro brano che puoi collegare';

  @override
  String languageVersionsOf(String title) {
    return 'Versioni linguistiche di $title';
  }

  @override
  String languageVersionsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Versioni collegate ($count)',
      zero: 'Versioni collegate',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionsChosenEmpty =>
      'Ancora nessun\'altra versione. Scegli brani dalla libreria.';

  @override
  String get languageVersionsSaved => 'Versioni linguistiche salvate';

  @override
  String languageVersionsNotAllowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count brani non sono stati collegati: non puoi modificare le loro altre versioni.',
      one: 'Un brano non è stato collegato: non puoi modificare le sue altre versioni.',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionUnlinked => 'Rimosso dalle versioni linguistiche';

  @override
  String otherLanguageVersionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Altre $count versioni linguistiche',
      one: 'Un\'altra versione linguistica',
    );
    return '$_temp0';
  }

  @override
  String get switchLanguageVersion => 'Cambia versione linguistica …';

  @override
  String switchedLanguageVersion(String version) {
    return 'Passato a: $version';
  }

  @override
  String switchedLanguageVersionKey(
    String version,
    String newKey,
    String oldKey,
  ) {
    return 'Passato a: $version, in $newKey invece di $oldKey in questo set';
  }

  @override
  String get switchedLanguageVersionSequence =>
      'La sequenza propria del set non si adatta alla nuova versione ed è stata rimossa.';

  @override
  String languageVersionInSet(String title, String key) {
    return '$title · in $key in questo set';
  }

  @override
  String get switchLanguageVersionTitle => 'Cambia versione linguistica';

  @override
  String adjustmentOfferOne(String version, String what) {
    return 'I tuoi adattamenti in “$version”: $what. Usarli anche per questa versione?';
  }

  @override
  String get adjustmentOfferMany =>
      'Altre versioni linguistiche hanno i tuoi adattamenti. Usarli anche per questa versione?';

  @override
  String get adjustmentKindTranspose => 'tonalità';

  @override
  String get adjustmentKindCapo => 'capotasto';

  @override
  String get adjustmentKindMidi => 'programma della tastiera';

  @override
  String get adjustmentKindClick => 'click';

  @override
  String get adjustmentOfferCopy => 'Usali';

  @override
  String get adjustmentOfferDismiss => 'No, grazie';

  @override
  String get adjustmentOfferPick => 'Usa gli adattamenti di';

  @override
  String adjustmentsCopied(String version) {
    return 'Adattamenti di “$version” usati';
  }

  @override
  String get autoBackup => 'Backup automatico';

  @override
  String get autoBackupSwitch => 'Esegui il backup automaticamente';

  @override
  String get autoBackupHint =>
      'Salva la libreria “Su questo dispositivo” in una cartella a tua scelta, al massimo una volta al giorno dopo le modifiche. Usa una cartella del tuo cloud per tenerla al sicuro se perdi il dispositivo.';

  @override
  String get autoBackupFolder => 'Cartella';

  @override
  String get autoBackupFolderNone => 'Nessuna cartella scelta';

  @override
  String get autoBackupChooseFolder => 'Scegli cartella';

  @override
  String get autoBackupDevice => 'Nome del dispositivo';

  @override
  String get autoBackupDeviceHint =>
      'Parte dei nomi dei file, così più dispositivi possono usare la stessa cartella.';

  @override
  String get autoBackupDeviceTitle => 'Nome del dispositivo per i backup';

  @override
  String get autoBackupKeep => 'Backup conservati';

  @override
  String get autoBackupKeepHint =>
      'I backup automatici più vecchi di questo dispositivo vengono eliminati dalla cartella.';

  @override
  String get autoBackupNow => 'Esegui ora il backup nella cartella';

  @override
  String get autoBackupRunning => 'Backup in corso …';

  @override
  String get autoBackupNever => 'Ancora nessun backup automatico.';

  @override
  String autoBackupLast(String date) {
    return 'Ultimo backup automatico: $date';
  }

  @override
  String autoBackupFailed(String date, String reason) {
    return 'Non riuscito il $date: $reason';
  }

  @override
  String get autoBackupErrorUnavailable => 'La cartella non è raggiungibile.';

  @override
  String get autoBackupErrorPermission =>
      'setDING non può più scrivere nella cartella. Sceglila di nuovo.';

  @override
  String get autoBackupErrorFailed => 'Impossibile scrivere il backup.';

  @override
  String autoBackupHintFailed(String reason) {
    return 'Backup automatico non riuscito: $reason';
  }

  @override
  String autoBackupSaved(String file) {
    return 'Salvato come “$file”';
  }

  @override
  String get backupModeCopy => 'Aggiungi come copia';

  @override
  String get backupModeCopyHint =>
      'Brani e set vengono aggiunti con nuovi ID; niente di esistente viene modificato.';

  @override
  String get backupModeReplace => 'Sostituisci la libreria locale';

  @override
  String get backupModeReplaceHint =>
      'La libreria “Su questo dispositivo” diventa esattamente come nel backup, p. es. su un nuovo dispositivo o per tornare a uno stato precedente.';

  @override
  String get backupReplaceTitle => 'Sostituire la libreria locale?';

  @override
  String backupReplaceFromDevice(
    String device,
    String date,
    int songs,
    int sets,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return 'Backup di “$device” del $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceFrom(String date, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return 'Backup del $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceNow(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return 'Ora su questo dispositivo: $_temp0, $_temp1. Vengono rimossi, anche quelli nel cestino.';
  }

  @override
  String get backupReplaceKeeps =>
      'La cronologia delle esecuzioni torna con i set del backup. Impostazioni e organizzazioni non vengono modificate.';

  @override
  String get backupReplaceSafety => 'Salva prima un backup di sicurezza';

  @override
  String backupReplaceSafetyFolder(String folder) {
    return 'Nella cartella del backup automatico ($folder).';
  }

  @override
  String get backupReplaceSafetyChoose => 'Scegli tu dove salvarlo.';

  @override
  String get backupReplaceSafetySkip =>
      'Senza un backup di sicurezza, la libreria attuale non può essere ripristinata.';

  @override
  String get backupReplaceAction => 'Sostituisci';

  @override
  String get backupReplaceRunning => 'Sostituzione della libreria locale …';

  @override
  String backupReplaceDone(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return 'Libreria locale sostituita: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceSafetyFailed(String reason) {
    return 'Impossibile salvare il backup di sicurezza, quindi non è stato sostituito nulla: $reason';
  }

  @override
  String get showLocalLibrary => 'Mostra la libreria locale';

  @override
  String get showLocalLibraryHint =>
      '“Su questo dispositivo” negli elenchi di librerie e band. Se suoni solo in organizzazioni, puoi nasconderla; i suoi brani e set restano su questo dispositivo.';

  @override
  String get showLocalLibrarySignedOut =>
      'Senza accesso, la libreria locale viene sempre mostrata.';

  @override
  String localLibraryHidden(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets set',
      one: '1 set',
    );
    return 'La libreria locale è nascosta. I suoi $_temp0 e $_temp1 restano su questo dispositivo e tornano quando la mostri di nuovo.';
  }

  @override
  String get localLibraryHiddenAutoBackup =>
      'Il backup automatico continua; puoi disattivarlo qui.';

  @override
  String get chordViewChords => 'Accordi';

  @override
  String get chordViewNashville => 'Nashville';

  @override
  String get chordViewNumerals => 'Numeri romani';

  @override
  String get liveChordViewChords => 'C';

  @override
  String get liveChordViewNashville => '1';

  @override
  String get liveChordViewNumerals => 'I';

  @override
  String get chordViewDocs =>
      'Come leggere i numeri Nashville e i numeri romani';

  @override
  String docsHelp(String topic) {
    return 'Aiuto: $topic';
  }

  @override
  String get editorDocsTopic => 'Editor ChordPro';

  @override
  String get settingsDocs => 'Guida';

  @override
  String get settingsDocsHint =>
      'Apri la documentazione di setDING su setding.app (in inglese). L\'icona del libro in alto apre la pagina della sezione aperta.';

  @override
  String get overviewReadiness => 'Pronti a suonare';

  @override
  String readinessAllSet(String set) {
    return 'Tutto pronto per “$set”';
  }

  @override
  String get readinessAllSetNoSet => 'Tutto pronto';

  @override
  String get readinessShowDetails => 'Mostra dettagli';

  @override
  String get readinessHideDetails => 'Nascondi dettagli';

  @override
  String readinessMusician(String who) {
    return 'Musicista: $who';
  }

  @override
  String get readinessNoInstrument => 'Nessuno strumento scelto';

  @override
  String readinessMidiConnected(String device) {
    return 'MIDI: $device collegato';
  }

  @override
  String get readinessMidiNotConnected => 'MIDI: tastiera non collegata';

  @override
  String get readinessMidiNoOutput => 'MIDI: nessuna tastiera scelta';

  @override
  String readinessMidiProfile(String profile) {
    return 'Profilo: $profile';
  }

  @override
  String get readinessOfflineReady => 'Prossimo set disponibile offline';

  @override
  String readinessOfflineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani del prossimo set non sono disponibili',
      one: '1 brano del prossimo set non è disponibile',
    );
    return '$_temp0 offline';
  }

  @override
  String readinessSynced(String time) {
    return 'Sincronizzato: $time';
  }

  @override
  String get readinessSyncNever =>
      'Non ancora sincronizzato su questo dispositivo';

  @override
  String get readinessSyncStale => 'I dati potrebbero non essere aggiornati';

  @override
  String get readinessSyncManual =>
      'La sincronizzazione è manuale: sincronizza prima del concerto.';

  @override
  String get readinessPageTurnerResponds => 'Il voltapagina risponde';

  @override
  String readinessPageTurnerLastUsed(String time) {
    return 'Voltapagina: usato l\'ultima volta $time';
  }

  @override
  String get readinessPageTurnerNever =>
      'Voltapagina: non ancora usato su questo dispositivo';

  @override
  String readinessPageTurnerDetail(String mode) {
    return 'Volta: $mode · premi qui il pedale per provarlo';
  }

  @override
  String get readinessBackupNoFolder =>
      'Backup automatico: nessuna cartella scelta';

  @override
  String get readinessBackupFailed => 'Backup automatico non riuscito';

  @override
  String get keyGuessHint => 'Suggerita dagli accordi:';

  @override
  String keyGuessUse(String key) {
    return 'Usa $key come tonalità';
  }

  @override
  String get attentionNoKey => 'Nessuna tonalità';

  @override
  String overviewTodoNoKey(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani senza tonalità',
      one: '1 brano senza tonalità',
    );
    return '$_temp0';
  }

  @override
  String readinessPageTurnerConnected(String name) {
    return 'Voltapagina $name collegato';
  }

  @override
  String readinessPageTurnerNotConnected(String name) {
    return 'Voltapagina $name non collegato';
  }

  @override
  String get readinessKeyboardConnected => 'È collegata una tastiera';

  @override
  String get readinessKeyboardNotConnected =>
      'Voltapagina: nessuna tastiera collegata';

  @override
  String get settingsPageTurner => 'Voltapagina';

  @override
  String get settingsPageTurnerNone => 'Non abbinato';

  @override
  String get settingsPageTurnerConnected => 'collegato';

  @override
  String get settingsPageTurnerNotConnected => 'non collegato';

  @override
  String get settingsPageTurnerHint =>
      'Abbina il tuo pedale così la panoramica mostra se è collegato.';

  @override
  String get settingsPageTurnerPair => 'Abbina';

  @override
  String get settingsPageTurnerPairAgain => 'Abbina di nuovo';

  @override
  String get settingsPageTurnerForget => 'Dimentica voltapagina';

  @override
  String get settingsPageTurnerKeyboardOnly =>
      'Questo dispositivo indica solo se è collegata una tastiera, non quale. La panoramica lo mostra.';

  @override
  String get settingsPageTurnerUnsupported =>
      'Non possibile su questa piattaforma. La panoramica mostra quando il voltapagina è stato usato l\'ultima volta.';

  @override
  String get pairPageTurnerTitle => 'Abbina voltapagina';

  @override
  String get pairPageTurnerPrompt => 'Premi ora il pedale.';

  @override
  String pageTurnerPaired(String name) {
    return 'Voltapagina abbinato: $name';
  }

  @override
  String pageTurnerForgotten(String name) {
    return 'Voltapagina dimenticato: $name';
  }

  @override
  String get pageTurnerUnnamed => 'Dispositivo senza nome';

  @override
  String importKeySuggestionsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani importati non hanno',
      one: '1 brano importato non ha',
    );
    return '$_temp0 una tonalità. Suggerita dagli accordi; un tocco imposta la tonalità:';
  }

  @override
  String importKeySuggestionsMore(int count) {
    return '… e altri $count: Da fare nella panoramica, Nessuna tonalità.';
  }

  @override
  String importKeysSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tonalità impostate in $count brani',
      one: 'Tonalità impostata in 1 brano',
      zero: 'Nessuna tonalità impostata',
    );
    return '$_temp0';
  }

  @override
  String get readinessPageTurnerNotPaired => 'Voltapagina non abbinato';

  @override
  String readinessPageTurnerPairDetail(String mode) {
    return 'Abbinalo così la panoramica mostra se è collegato · Volta: $mode';
  }

  @override
  String get settingsPageTurnerUse => 'Uso un voltapagina';

  @override
  String get settingsPageTurnerUseHint =>
      'Un pedale che volta le pagine. Lo mostra nella panoramica e propone di abbinarne uno rilevato.';

  @override
  String pageTurnerDetected(String name) {
    return 'Voltapagina rilevato: $name';
  }

  @override
  String get attentionToReview => 'Da verificare';

  @override
  String get attentionReported => 'Segnalato';

  @override
  String overviewTodoToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani da verificare',
      one: '1 brano da verificare',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoReported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani con errori segnalati',
      one: '1 brano con un errore segnalato',
    );
    return '$_temp0';
  }

  @override
  String get songToReviewTooltip => 'Non ancora verificato';

  @override
  String get songReportedTooltip => 'Errore segnalato';

  @override
  String get songToReviewHint => 'Questo brano non è ancora stato verificato.';

  @override
  String get songReportedHint => 'In questo brano è stato segnalato un errore.';

  @override
  String reviewBannerToReview(String reason) {
    return 'Da verificare: $reason';
  }

  @override
  String reviewBannerReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segnalazioni aperte',
      one: '1 segnalazione aperta',
    );
    return '$_temp0';
  }

  @override
  String get showReports => 'Mostra';

  @override
  String get approveSong => 'Approva';

  @override
  String get songApproved => 'Brano approvato';

  @override
  String get approveAllSongs => 'Approva tutti';

  @override
  String get approveAllSongsTitle => 'Approvare tutti i brani?';

  @override
  String approveAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani saranno considerati verificati.',
      one: '1 brano sarà considerato verificato.',
    );
    return '$_temp0';
  }

  @override
  String songsApproved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani approvati',
      one: '1 brano approvato',
    );
    return '$_temp0';
  }

  @override
  String get resolveReportsTitle => 'Chiudere le segnalazioni?';

  @override
  String resolveReportsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il brano ha $count segnalazioni aperte. Chiuderle anche?',
      one: 'Il brano ha 1 segnalazione aperta. Chiuderla anche?',
    );
    return '$_temp0';
  }

  @override
  String get resolveReports => 'Chiudi';

  @override
  String get setToReviewMenu => 'Segna da verificare …';

  @override
  String get setToReviewTitle => 'Segna da verificare';

  @override
  String get reviewReasonLabel => 'Motivo';

  @override
  String get reviewReasonHint => 'es. il bridge è sbagliato';

  @override
  String get reviewReasonAfterImport => 'Dopo l\'importazione';

  @override
  String setReviewHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani non sono ancora verificati o hanno errori segnalati',
      one: '1 brano non è ancora verificato o ha un errore segnalato',
    );
    return '$_temp0';
  }

  @override
  String get reportMistake => 'Segnala un errore';

  @override
  String get reportMistakeMenu => 'Segnala un errore …';

  @override
  String get reportCategoryChords => 'Accordi';

  @override
  String get reportCategoryLyrics => 'Testo';

  @override
  String get reportCategoryKey => 'Tonalità';

  @override
  String get reportCategorySequence => 'Sequenza';

  @override
  String get reportCategoryTempo => 'Tempo';

  @override
  String get reportCategoryFormatting => 'Formattazione';

  @override
  String get reportCategorySheetMusic => 'Spartito (PDF)';

  @override
  String get reportCategoryOther => 'Altro';

  @override
  String get reportComment => 'Commento';

  @override
  String get reportCommentHint => 'Cosa non va?';

  @override
  String get reportSend => 'Invia';

  @override
  String get reportSent => 'Errore segnalato. Grazie!';

  @override
  String reportLocation(String place) {
    return 'Punto: $place';
  }

  @override
  String reportLocationPage(int page) {
    return 'Pagina $page';
  }

  @override
  String reportLocationPdfPage(int page) {
    return 'Pagina PDF $page';
  }

  @override
  String reportLocationLine(int line) {
    return 'Riga $line';
  }

  @override
  String get reportsTitle => 'Segnalazioni';

  @override
  String get reportsEmpty => 'Nessuna segnalazione';

  @override
  String reportsClosed(int count) {
    return 'Chiuse e ritirate ($count)';
  }

  @override
  String get reportByYou => 'da te';

  @override
  String reportBy(String name) {
    return 'da $name';
  }

  @override
  String get reportWithdrawn => 'ritirata';

  @override
  String get reportWithdraw => 'Ritira';

  @override
  String get reportWithdrawnMessage => 'Segnalazione ritirata';

  @override
  String get resolveReport => 'Chiudi la segnalazione';

  @override
  String get reportAnswerLabel => 'Risposta';

  @override
  String get reportAnswerHint => 'es. Corretto, grazie!';

  @override
  String get reportResolvedMessage => 'Segnalazione chiusa';

  @override
  String get reportReopen => 'Riapri';

  @override
  String get reportReopenedMessage => 'Segnalazione riaperta';

  @override
  String get reportResolvedNoAnswer => 'Chiusa';

  @override
  String reportAnswer(String answer) {
    return 'Chiusa: $answer';
  }

  @override
  String reportAnswered(String song, String answer) {
    return 'La tua segnalazione su «$song» è stata chiusa: $answer';
  }

  @override
  String reportAnsweredNoText(String song) {
    return 'La tua segnalazione su «$song» è stata chiusa.';
  }

  @override
  String reportsAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count delle tue segnalazioni sono state chiuse.',
      one: '1 delle tue segnalazioni è stata chiusa.',
    );
    return '$_temp0';
  }

  @override
  String get screenshotAdd => 'Allega uno screenshot';

  @override
  String get screenshotRemove => 'Rimuovi';

  @override
  String get screenshotMarkTitle => 'Segna il punto';

  @override
  String get screenshotMarkHint => 'Disegna sullo screenshot dov’è l’errore.';

  @override
  String get screenshotAttach => 'Allega';

  @override
  String get screenshotShow => 'Mostra lo screenshot a grandezza piena';

  @override
  String get screenshotLoading => 'Caricamento dello screenshot …';

  @override
  String get screenshotUnavailable => 'Screenshot non disponibile (offline?)';

  @override
  String get lineup => 'Formazione';

  @override
  String get lineupWholeBand => 'Tutta la band';

  @override
  String get lineupSubstitute => 'Sostituto';

  @override
  String get lineupBandMembers => 'Membri della band';

  @override
  String get lineupSubstitutes => 'Sostituti';

  @override
  String get lineupNotPlanned => 'Non sei in programma';

  @override
  String get lineupEdit => 'Scegli la formazione';

  @override
  String get lineupAddPeople => 'Aggiungi persone';

  @override
  String get lineupSearchPeople => 'Cerca persone';

  @override
  String get lineupNoMorePeople =>
      'Tutte le persone dell\'organizzazione sono già nella formazione.';

  @override
  String get lineupNoAccount => 'Senza account';

  @override
  String get lineupPeopleWithoutAccount => 'Persone senza account';

  @override
  String get lineupNewContact => 'Nuova persona senza account';

  @override
  String get contactEmail => 'Indirizzo e-mail (facoltativo)';

  @override
  String get contactEmailHint =>
      'La vedono solo le persone che pianificano i set. «Avvisa la formazione» scrive a questo indirizzo.';

  @override
  String get contactNameHint => 'Serve solo il nome.';

  @override
  String get contactsHint =>
      'Persone che suonano con voi ma non usano setDING. Possono far parte della formazione dei set.';

  @override
  String get contactEditTitle => 'Modifica persona';

  @override
  String get contactInvite => 'Invita su setDING';

  @override
  String get contactInviteChooseBand => 'Invitare in quale band?';

  @override
  String contactDeleteTitle(String name) {
    return 'Eliminare $name?';
  }

  @override
  String contactDeleteMessage(String name) {
    return '$name non viene più proposto per le formazioni e l’indirizzo e-mail viene rimosso. I set in cui figura $name mantengono il nome.';
  }

  @override
  String contactInviteTitle(String name) {
    return 'Invito personale per $name';
  }

  @override
  String contactInviteHint(String date, String name) {
    return 'Il link vale una volta, fino al $date. Chi crea un account con esso riprende i set in cui $name è previsto.';
  }

  @override
  String get contactInviteSubject => 'Invito su setDING';

  @override
  String contactInviteBody(String name, String organization, String url) {
    return 'Ciao $name\n\nSei invitato a unirti a $organization su setDING, dove trovi gli accordi delle nostre canzoni e i set in cui sei previsto. Apri questo link per creare il tuo account:\n$url';
  }

  @override
  String joinPersonal(String name) {
    return 'Questo invito è per $name.';
  }

  @override
  String joinPersonalExplanation(String name) {
    return 'Il tuo account riprende i set in cui $name è previsto.';
  }

  @override
  String get joinPersonalButton => 'Accetta l’invito';

  @override
  String get lineupNobody => 'Nessuno in programma';

  @override
  String get lineupWholeBandHint =>
      'La formazione segue la band, nuovi membri compresi.';

  @override
  String get bandSubstituteHint =>
      'Suoni alcuni set di questa band come sostituto e vedi solo quei set.';

  @override
  String get overviewAsSubstitute => 'Come sostituto';

  @override
  String get lineupNotify => 'Avvisa la formazione';

  @override
  String get lineupCopy => 'Copia';

  @override
  String get lineupCopied => 'Testo copiato';

  @override
  String get lineupMail => 'Via e-mail';

  @override
  String get lineupShare => 'Condividi …';

  @override
  String get lineupNoAddresses =>
      'Nessuna connessione al server: scegli tu i destinatari.';

  @override
  String lineupMessageIntro(String set) {
    return 'Siete in programma per «$set».';
  }

  @override
  String get lineupMessageFooter => 'Trovate i brani in setDING.';

  @override
  String get overviewPlanned => 'Sei in programma';

  @override
  String get overviewPlannedSeen => 'Ho capito';

  @override
  String linkSwitchedTo(String name) {
    return 'Passato a $name';
  }

  @override
  String get linkNotAvailableTitle => 'Non disponibile su questo dispositivo';

  @override
  String get linkNotAvailableMessage =>
      'Non è ancora sincronizzato su questo dispositivo, oppure non hai accesso.';

  @override
  String get linkNoAccessMessage =>
      'Non disponibile: è stato eliminato, oppure non hai accesso.';

  @override
  String get linkSignInMessage => 'Accedi per vederlo.';

  @override
  String get linkShare => 'Condividi link';

  @override
  String get linkCopied => 'Link copiato';
}
