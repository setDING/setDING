// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'setDING';

  @override
  String get navSets => 'Sets';

  @override
  String get navSongs => 'Songs';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Schliessen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get untitled => 'Ohne Titel';

  @override
  String errorGeneric(String error) {
    return 'Etwas ist schiefgelaufen: $error';
  }

  @override
  String get songsEmpty =>
      'Noch keine Songs. Erstelle einen neuen Song oder importiere ChordPro-Dateien.';

  @override
  String get searchSongs => 'Songs suchen';

  @override
  String get searchClear => 'Suche leeren';

  @override
  String get newSong => 'Neuer Song';

  @override
  String get newPdfSong => 'Neuer PDF-Song';

  @override
  String get importFiles => 'Dateien importieren';

  @override
  String get importTitle => 'ChordPro-Dateien importieren';

  @override
  String get importDescription =>
      'Unterstützt werden .cho, .chordpro, .chopro, .crd, .pro, .txt, ZIP-Archive mit solchen Dateien und setDING-Sicherungen.';

  @override
  String get importGermanNotation =>
      'Dateien verwenden deutsche Notation (H/B)';

  @override
  String get importGermanNotationHint =>
      'Akkorde werden beim Import in internationale Notation umgewandelt.';

  @override
  String get chooseFiles => 'Dateien auswählen';

  @override
  String importResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs importiert',
      one: '1 Song importiert',
      zero: 'Keine Songs importiert',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(String files) {
    return 'Übersprungen: $files';
  }

  @override
  String get deleteSongTitle => 'Song löschen?';

  @override
  String deleteSongMessage(String title) {
    return '«$title» wird gelöscht und aus allen Sets entfernt.';
  }

  @override
  String get attachmentsTooltip => 'Hat PDF-Anhänge';

  @override
  String get keyOriginal => 'Original';

  @override
  String get capo => 'Kapo';

  @override
  String capoValue(int fret) {
    return 'Kapo $fret';
  }

  @override
  String capoLabel(int fret) {
    return 'Kapo: $fret';
  }

  @override
  String capoLabelWithKey(int fret, String key) {
    return 'Kapo: $fret ($key)';
  }

  @override
  String capoAsInSongLabel(String capo) {
    return '$capo, wie im Song';
  }

  @override
  String get noCapo => 'Ohne Kapo';

  @override
  String capoAsInSong(int fret) {
    return 'Kapo $fret (wie im Song)';
  }

  @override
  String get allTags => 'Alle';

  @override
  String get tagsFilter => 'Tags';

  @override
  String get filterByTags => 'Nach Tags filtern';

  @override
  String tagsFilterMore(String tag, int count) {
    return '$tag +$count';
  }

  @override
  String get notes => 'Meine Notizen';

  @override
  String get notesHint => 'Nur du siehst diese Notiz.';

  @override
  String get editSource => 'ChordPro bearbeiten';

  @override
  String get attachments => 'Anhänge';

  @override
  String get addAttachment => 'Datei anhängen';

  @override
  String get noAttachments => 'Noch keine Anhänge.';

  @override
  String get attachmentTooLarge =>
      'Die Datei ist grösser als 20 MB und kann nicht angehängt werden.';

  @override
  String get songLinks => 'Quellen';

  @override
  String get noSongLinks =>
      'Noch keine Quellen. Füge Aufnahmen auf YouTube, Spotify usw. hinzu.';

  @override
  String get addSongLink => 'Link hinzufügen';

  @override
  String get editSongLink => 'Link bearbeiten';

  @override
  String get deleteSongLink => 'Quelle entfernen';

  @override
  String get deleteSongLinkMessage => 'Diese Quelle aus dem Song entfernen?';

  @override
  String get songLinkUrl => 'Link (URL)';

  @override
  String get songLinkLabel => 'Beschriftung (optional)';

  @override
  String get songLinkLabelHint => 'Live 2009';

  @override
  String get songLinkInvalid =>
      'Gib einen Weblink ein, der mit https:// beginnt (ohne |).';

  @override
  String get songLinkFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get attachmentName => 'Name des Anhangs';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seiten',
      one: '1 Seite',
    );
    return '$_temp0';
  }

  @override
  String get liveView => 'Im Live-Modus anzeigen';

  @override
  String get liveViewChordPro => 'ChordPro-Text';

  @override
  String get exportSong => 'Exportieren';

  @override
  String get exported => 'Exportiert';

  @override
  String get exportedOpen => 'Öffnen';

  @override
  String get openFileFailed => 'Keine App konnte die Datei öffnen.';

  @override
  String get playLive => 'Live spielen';

  @override
  String get live => 'Live';

  @override
  String get nashville => 'Nashville-Nummern';

  @override
  String get useDeviceSetting => 'Wie in den Einstellungen';

  @override
  String get on => 'Ein';

  @override
  String get off => 'Aus';

  @override
  String get fontLarger => 'Schrift grösser';

  @override
  String get fontSmaller => 'Schrift kleiner';

  @override
  String get fitToPage => 'An Seite anpassen';

  @override
  String get resetAdjustments => 'Persönliche Anpassungen zurücksetzen';

  @override
  String get personalAdjustments => 'Persönliche Anpassungen';

  @override
  String get scopePersonal =>
      'Nur für dich – für alle anderen bleibt der Song unverändert.';

  @override
  String get scopeSet => 'Für dieses Set – gilt für die ganze Band.';

  @override
  String get scopeBand => 'Für die ganze Band – gilt in allen ihren Sets.';

  @override
  String get scopeSong =>
      'Für den Song – ändert ihn für alle in der Organisation.';

  @override
  String get keyPickerPersonal => 'Meine Tonart – nur für mich';

  @override
  String get keyPickerSet => 'Tonart in diesem Set – für die ganze Band';

  @override
  String get keyPickerBand => 'Tonart der Band – für alle ihre Sets';

  @override
  String get editTitle => 'Titel bearbeiten';

  @override
  String get title => 'Titel';

  @override
  String get artist => 'Interpret';

  @override
  String get noContent => 'Dieser Song hat noch keinen ChordPro-Text.';

  @override
  String get addChordPro => 'ChordPro-Text erfassen';

  @override
  String keyLabel(String key) {
    return 'Tonart: $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForNashville =>
      'Für Nashville-Nummern braucht der Song eine Tonart.';

  @override
  String get firstVerseChordsOnly => 'Akkorde nur in Verse 1';

  @override
  String get noVersesForFirstVerseChords =>
      'Der Song hat keine weiteren Verses mit Akkorden.';

  @override
  String get verseChords => 'Akkorde in Verses';

  @override
  String get verseChordsAll => 'Akkorde in allen Verses';

  @override
  String get verseChordsStacked => 'Verses untereinander';

  @override
  String get editorTitleNew => 'Neuer Song';

  @override
  String get editorTitleEdit => 'Song bearbeiten';

  @override
  String get editorTab => 'Text';

  @override
  String get previewTab => 'Vorschau';

  @override
  String get insertVerse => 'Verse einfügen';

  @override
  String get insertChorus => 'Chorus einfügen';

  @override
  String get insertBridge => 'Bridge einfügen';

  @override
  String get insertComment => 'Kommentar einfügen';

  @override
  String get insertChord => 'Akkord einfügen';

  @override
  String get discardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get discardChangesMessage =>
      'Deine Änderungen wurden noch nicht gespeichert.';

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
      'Noch keine Sets. Erstelle ein Set für deinen nächsten Auftritt.';

  @override
  String get newSet => 'Neues Set';

  @override
  String get editSet => 'Set bearbeiten';

  @override
  String get setName => 'Name';

  @override
  String get gigDate => 'Datum';

  @override
  String get venue => 'Ort';

  @override
  String get noDate => 'Kein Datum';

  @override
  String get pickDate => 'Datum wählen';

  @override
  String get clearDate => 'Datum entfernen';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
      zero: 'Leer',
    );
    return '$_temp0';
  }

  @override
  String offlineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs nicht offline',
      one: '1 Song nicht offline',
    );
    return '$_temp0';
  }

  @override
  String get offlineMissingTooltip =>
      'Nicht alle Songs und PDFs dieses Sets sind auf dem Gerät. Verbinde es mit dem Netz und warte den Abgleich ab.';

  @override
  String syncStale(String time) {
    return 'Letzter Abgleich mit dem Server: $time. Die Sets auf diesem Gerät sind vielleicht nicht aktuell.';
  }

  @override
  String get syncStaleNever =>
      'Dieses Gerät hat sich noch nicht mit dem Server abgeglichen. Die Sets sind vielleicht nicht aktuell.';

  @override
  String syncUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen von diesem Gerät sind',
      one: '1 Änderung von diesem Gerät ist',
    );
    return '$_temp0 noch nicht auf dem Server.';
  }

  @override
  String get addSongs => 'Songs hinzufügen';

  @override
  String get pause => 'Pause';

  @override
  String get textItem => 'Text';

  @override
  String get markerIconBreak => 'Pause';

  @override
  String get markerIconDrinks => 'Getränke';

  @override
  String get markerIconAnnouncement => 'Ansage';

  @override
  String get markerIconMicrophone => 'Rede';

  @override
  String get markerIconGuest => 'Gast';

  @override
  String get markerIconEncore => 'Zugabe';

  @override
  String get markerIconTransition => 'Übergang';

  @override
  String get markerIconSolo => 'Solo';

  @override
  String get markerIconApplause => 'Applaus';

  @override
  String get markerIconInstrument => 'Instrumentwechsel';

  @override
  String get markerIconTuning => 'Stimmen';

  @override
  String get markerIconClick => 'Click';

  @override
  String get markerIconLight => 'Licht';

  @override
  String get markerIconEffects => 'Effekte';

  @override
  String get markerIconCelebration => 'Feier';

  @override
  String get markerIconInfo => 'Hinweis';

  @override
  String get markerIconWarning => 'Achtung';

  @override
  String get marker => 'Hinweis';

  @override
  String get addMarker => 'Hinweis hinzufügen';

  @override
  String get editMarker => 'Hinweis bearbeiten';

  @override
  String get markerText => 'Text';

  @override
  String get markerPreview => 'Vorschau';

  @override
  String get markerGroupBreak => 'Pause';

  @override
  String get markerGroupAnnouncement => 'Ansage';

  @override
  String get markerGroupFlow => 'Ablauf';

  @override
  String get markerGroupStage => 'Bühne';

  @override
  String get markerGroupShow => 'Show';

  @override
  String get markerGroupGeneral => 'Allgemein';

  @override
  String get setEmpty => 'Dieses Set ist leer. Füge Songs hinzu.';

  @override
  String get deleteSetTitle => 'Set löschen?';

  @override
  String deleteSetMessage(String name) {
    return '«$name» wird gelöscht. Die Songs bleiben erhalten.';
  }

  @override
  String get removeFromSet => 'Aus dem Set entfernen';

  @override
  String get selectSongs => 'Songs auswählen';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
      zero: 'Keine ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get songMissing => 'Song nicht mehr vorhanden';

  @override
  String liveNext(String title) {
    return 'Nächster: $title';
  }

  @override
  String get liveWebNotice =>
      'Im Browser nicht offline-sicher – auf der Bühne die App verwenden';

  @override
  String liveMidiConnected(String name) {
    return 'Keyboard verbunden: $name';
  }

  @override
  String get liveMidiNotConnected => 'Keyboard nicht verbunden';

  @override
  String get liveMidiSendAgain => 'Programm erneut senden';

  @override
  String get liveMidiButton =>
      'Keyboard-Programm (lange drücken: erneut senden)';

  @override
  String get liveMidiChange => 'Programm ändern';

  @override
  String get liveMidiSameAsPrevious => 'Wie vorheriger Song';

  @override
  String liveMidiPreviousProgram(String program, String title) {
    return '$program – aus «$title»';
  }

  @override
  String get liveMidiNoPrevious => 'Kein früherer Song mit Programm';

  @override
  String get liveMidiSaved => 'Keyboard-Programm gespeichert';

  @override
  String get liveMidiRemoved => 'Keyboard-Programm entfernt';

  @override
  String get liveMidiTakeOverWaiting => 'Wähle am Keyboard einen Klang';

  @override
  String liveMidiTakeOver(String program) {
    return 'Übernehmen: $program';
  }

  @override
  String get liveMidiTakeOverHint =>
      'setDING übernimmt das Programm, das das Keyboard sendet.';

  @override
  String get liveMidiTakeOverNordHint =>
      'Kommt nichts an? Stelle am Nord im MIDI-Menü «Program Change» auf «Send» oder «Send & Receive».';

  @override
  String get liveMidiTakeOverSame => 'Das ist bereits das Programm des Songs';

  @override
  String get liveWakeLockNotice =>
      'Bildschirm kann sich ausschalten – Energieeinstellungen des Geräts prüfen';

  @override
  String get liveEnd => 'Ende des Sets';

  @override
  String get liveSetOverview => 'Set-Übersicht';

  @override
  String get liveExit => 'Live-Modus beenden';

  @override
  String get liveChordNames => 'Akkorde';

  @override
  String get liveNashville => 'Nashville';

  @override
  String liveSongPage(int page, int count) {
    return 'Seite $page/$count';
  }

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'Allgemein';

  @override
  String get settingsSectionDisplay => 'Darstellung';

  @override
  String get settingsSectionLive => 'Bildschirm & Live-Modus';

  @override
  String get settingsSectionStorage => 'Speicher & Info';

  @override
  String get settingsSectionMusician => 'Musiker';

  @override
  String get settingsCategoryAccountHint =>
      'Anmeldung, Server und Synchronisation';

  @override
  String get settingsCategoryGeneralHint => 'Sprache und Design';

  @override
  String get settingsCategoryMusicianHint =>
      'Instrument, Stimme, Akkorddiagramme, Takt';

  @override
  String get settingsCategoryDisplayHint =>
      'Akkord-Notation, Nashville-Zahlen, Inhalt, Chorus, Fortschritt';

  @override
  String get settingsCategoryLiveHint =>
      'Schriftgrösse, an Bildschirm anpassen, Spalten, Blättern';

  @override
  String get settingsCategoryAboutHint =>
      'Speicher, Diagnoseprotokoll und Version';

  @override
  String get settingsInstrument => 'Mein Instrument';

  @override
  String get settingsInstrumentHint =>
      'Wird für bedingte Abschnitte (z. B. nur für Gitarre) und für Griffdiagramme verwendet.';

  @override
  String get instrumentGuitar => 'Gitarre';

  @override
  String get instrumentUkulele => 'Ukulele';

  @override
  String get instrumentBass => 'Bass';

  @override
  String get instrumentKeyboard => 'Keyboard';

  @override
  String get instrumentVocals => 'Gesang';

  @override
  String get instrumentDrums => 'Schlagzeug';

  @override
  String get instrumentOther => 'Anderes …';

  @override
  String get settingsUserName => 'Mein Name oder meine Stimme';

  @override
  String get settingsUserNameHint =>
      'Für bedingte Abschnitte, z. B. «alto» oder «tenor».';

  @override
  String get settingsDiagrams => 'Griffdiagramme';

  @override
  String get settingsDiagramsHint =>
      'Zeigt die Griffe aller Akkorde des Songs für dein Instrument. Ein Song kann das mit der Direktive diagrams selbst festlegen.';

  @override
  String get diagramsOff => 'Aus';

  @override
  String get diagramsTop => 'Oben';

  @override
  String get diagramsBottom => 'Unten';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'English';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeSystem => 'Wie System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get settingsAccent => 'Akzentfarbe';

  @override
  String get accentBrand => 'setDING-Blau';

  @override
  String get accentRed => 'Rot';

  @override
  String get accentAmber => 'Bernstein';

  @override
  String get accentGreen => 'Grün';

  @override
  String get accentTeal => 'Petrol';

  @override
  String get accentPurple => 'Violett';

  @override
  String get accentPink => 'Rosa';

  @override
  String get settingsNotation => 'Akkord-Notation';

  @override
  String get notationInternational => 'International (B, Bb)';

  @override
  String get notationGerman => 'Deutsch (H, B)';

  @override
  String get settingsNashville => 'Nashville-Nummern anzeigen';

  @override
  String get settingsNashvilleHint =>
      'Akkorde als Stufen der Tonart, z. B. 1, 4, 5, 6m. Braucht eine Tonart im Song.';

  @override
  String get settingsChordStyle => 'Akkordschreibweise';

  @override
  String get settingsChordStyleHint =>
      'Wie Akkorde geschrieben werden, z. B. Am7, Cmaj7, Em7b5 (Standard) oder A−7, CΔ7, Eø7 (Jazz). Der Song selbst bleibt unverändert.';

  @override
  String get chordStyleAsWritten => 'Wie geschrieben';

  @override
  String get chordStyleStandard => 'Standard';

  @override
  String get chordStyleJazz => 'Jazz';

  @override
  String get settingsChordSuperscript => 'Erweiterungen hochstellen';

  @override
  String get settingsChordSuperscriptHint =>
      'Erweiterungen und Alterationen klein und hochgestellt anzeigen, z. B. C⁷. Braucht die Schreibweise Standard oder Jazz.';

  @override
  String get settingsDisplayMode => 'Inhalt';

  @override
  String get displayLyricsAndChords => 'Text und Akkorde';

  @override
  String get displayLyricsOnly => 'Nur Text';

  @override
  String get settingsFontSize => 'Schriftgrösse';

  @override
  String get settingsColumns => 'Spalten';

  @override
  String get columnsAuto => 'Automatisch';

  @override
  String get columnsOne => 'Eine';

  @override
  String get columnsTwo => 'Zwei';

  @override
  String get settingsPageTurn => 'Blättern';

  @override
  String get pageTurnFull => 'Ganze Seite';

  @override
  String get pageTurnHalf => 'Halbe Seite';

  @override
  String get settingsAutoFit => 'Song an den Bildschirm anpassen';

  @override
  String get settingsAutoFitHint =>
      'Der ganze Song passt ohne Scrollen auf den Bildschirm. Die Abschnitte werden automatisch in Spalten angeordnet und die Schrift so gross wie möglich gewählt.';

  @override
  String get settingsColumnsHint =>
      'Beim Anpassen an den Bildschirm die höchste erlaubte Anzahl Spalten.';

  @override
  String get columnsThree => 'Drei';

  @override
  String get settingsChorusRepeat => 'Wiederholter Chorus';

  @override
  String get settingsChorusRepeatHint =>
      'Automatisch: Ein wiederholter Chorus wird nur dann als kurzer Hinweis angezeigt, wenn der Song sonst nicht gut auf den Bildschirm passt.';

  @override
  String get chorusRepeatAuto => 'Automatisch';

  @override
  String get chorusRepeatFull => 'Ganz anzeigen';

  @override
  String get chorusRepeatLabel => 'Nur Hinweis';

  @override
  String get settingsPageTurnHint =>
      'Tippe links oder rechts auf den Bildschirm, um zurück oder weiter zu blättern. Seitenwender (Fusspedal) und Tastatur: Pfeil rechts, Pfeil ab, Bild ab und Leertaste blättern weiter, Pfeil links, Pfeil auf und Bild auf zurück. Mit Takt (Tempo und Taktanzeige oder Klick eingeschaltet) startet und stoppt ihn langes Drücken von Vorwärts oder Enter.';

  @override
  String get settingsSetProgress => 'Fortschrittsbalken des Sets';

  @override
  String get settingsSetProgressHint =>
      'Ein schmaler Balken über der Fusszeile zeigt die Songs des Sets und die Seiten des aktuellen Songs: die aktuelle Seite in der Akzentfarbe, noch folgende Seiten heller. Hinweise wie Pausen sind gestrichelt.';

  @override
  String get settingsBeatSection => 'Takt und Klick';

  @override
  String get settingsBeatSectionHint =>
      'Tempo und Taktart des Songs oder das Tempo des Band-Arrangements. Standardmässig eingeschaltet, wenn dein Instrument Schlagzeug ist.';

  @override
  String get settingsBeatDisplay => 'Taktanzeige';

  @override
  String get settingsBeatDisplayHint =>
      'Punkte neben Tempo und Taktart leuchten auf jedem Schlag; beim Einzählen erscheinen grosse Zahlen.';

  @override
  String get settingsEdgeFlash => 'Bildschirmrand blinken lassen';

  @override
  String get settingsEdgeFlashHint =>
      'Der Rand blinkt auf jedem Schlag, die 1 in einer anderen Farbe – sichtbar aus dem Augenwinkel.';

  @override
  String get settingsClick => 'Klick';

  @override
  String get settingsClickHint =>
      'Spielt einen Klick über den Audio-Ausgang des Geräts, z. B. in den In-Ear-Mix.';

  @override
  String get settingsClickStart => 'Start';

  @override
  String get settingsClickStartHint =>
      'Manuell: aufs Tempo tippen, das Vorwärts-Pedal halten oder Enter drücken. Der Wechsel zu einem anderen Song des Sets stoppt den Takt.';

  @override
  String get clickStartAutomatic => 'Bei jedem Song';

  @override
  String get clickStartManual => 'Manuell';

  @override
  String get settingsClickDuration => 'Dauer';

  @override
  String get clickDurationSong => 'Ganzer Song';

  @override
  String get clickDurationCountIn => 'Nur Einzählen';

  @override
  String get settingsClickInBackground => 'Im Hintergrund';

  @override
  String get settingsClickInBackgroundHint =>
      'Wenn die App verkleinert, eine andere App geöffnet oder der Bildschirm gesperrt wird.';

  @override
  String get clickInBackgroundStop => 'Stoppen';

  @override
  String get clickInBackgroundKeepPlaying => 'Weiterspielen';

  @override
  String get settingsCountIn => 'Einzählen';

  @override
  String get countInOff => 'Aus';

  @override
  String get countInOneBar => '1 Takt';

  @override
  String get countInTwoBars => '2 Takte';

  @override
  String get settingsClickVolume => 'Lautstärke';

  @override
  String get settingsClickAccent => 'Betonung auf der 1';

  @override
  String get settingsClickSound => 'Klang';

  @override
  String get clickSoundClick => 'Klick';

  @override
  String get clickSoundWoodblock => 'Woodblock';

  @override
  String get clickSoundBeep => 'Piep';

  @override
  String get settingsClickSubdivision => 'Unterteilung';

  @override
  String get settingsClickSubdivisionHint =>
      'Leisere Klicks zwischen den Schlägen. Jeder Song kann in den persönlichen Anpassungen eine eigene Unterteilung haben.';

  @override
  String get subdivisionOff => 'Aus';

  @override
  String get subdivisionEighths => 'Achtel';

  @override
  String get subdivisionSixteenths => 'Sechzehntel';

  @override
  String get subdivisionTriplets => 'Triolen';

  @override
  String clickSubdivisionAsInSettings(String value) {
    return 'Wie in den Einstellungen ($value)';
  }

  @override
  String get clickGrouping => 'Gruppierung';

  @override
  String get clickGroupingNone => 'Ohne Gruppen';

  @override
  String clickGroupingAsInSong(String grouping) {
    return 'Wie im Song ($grouping)';
  }

  @override
  String get clickGroupingHint =>
      'Betonte Schläge im ungeraden Takt, nur für dich.';

  @override
  String get settingsAudioLatency => 'Audio-Verzögerung';

  @override
  String get settingsAudioLatencyHint =>
      'Verschiebt die Anzeige, damit sie zum Gehörten passt. Kabel-Kopfhörer brauchen wenig, Bluetooth-Kopfhörer 100–300 ms.';

  @override
  String audioLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get audioLatencyCalibrate => 'Audio-Verzögerung messen';

  @override
  String get audioLatencyCalibrateTitle => 'Audio-Verzögerung messen';

  @override
  String get audioLatencyCalibrateHint =>
      'Setze die Kopfhörer auf, die du auf der Bühne trägst, und tippe auf jeden Schlag des Klicks mit.';

  @override
  String get audioLatencyTap => 'Tippen';

  @override
  String audioLatencyTaps(int count) {
    return '$count-mal getippt';
  }

  @override
  String audioLatencyResult(int ms) {
    return 'Gemessen: $ms ms';
  }

  @override
  String get audioLatencyApply => 'Übernehmen';

  @override
  String get clickNoAudio =>
      'Auf diesem Gerät gibt es keinen Audio-Ausgang für den Klick.';

  @override
  String get beatStart => 'Takt starten';

  @override
  String get beatStop => 'Takt stoppen';

  @override
  String get beatDisplayLabel => 'Takt';

  @override
  String countInBar(int bar, int count) {
    return 'Takt $bar von $count';
  }

  @override
  String get tempoSlower => 'Langsamer';

  @override
  String get tempoFaster => 'Schneller';

  @override
  String get tapTempo => 'Tempo tippen';

  @override
  String get tempoReset => 'Zurück zum Tempo des Songs';

  @override
  String get clickNoAudioLive => 'Kein Audio für den Klick';

  @override
  String get settingsSongMap => 'Song-Landkarte statt Akkorde';

  @override
  String get settingsSongMapHint =>
      'Der Live-Modus zeigt die Teile des Songs mit einem Stichwort aus dem Text und den Schlagzeug-Notizen.';

  @override
  String get songMapEmpty =>
      'Dieser Song hat keine Teile (Verse, Chorus, …) für eine Song-Landkarte.';

  @override
  String get songMapNoTempo => 'Kein Tempo für diesen Song';

  @override
  String get settingsLiveAppearance => 'Aussehen auf der Bühne';

  @override
  String get settingsLiveAppearanceHint =>
      'Live-Modus unabhängig vom App-Design. Schwarz spart Strom auf OLED-Bildschirmen.';

  @override
  String get liveAppearanceApp => 'Wie App';

  @override
  String get liveAppearanceDark => 'Dunkel';

  @override
  String get liveAppearanceBlack => 'Schwarz';

  @override
  String settingsStorageUsed(String size) {
    return 'PDF-Anhänge belegen $size';
  }

  @override
  String get settingsLogCopy => 'Diagnoseprotokoll kopieren';

  @override
  String get settingsLogCopyHint =>
      'Die letzten Meldungen der App, z. B. warum eine Synchronisation fehlschlug – zum Einfügen in eine Nachricht an den Support.';

  @override
  String get settingsLogCopied => 'Diagnoseprotokoll kopiert';

  @override
  String get settingsAbout =>
      'setDING läuft lokal auf diesem Gerät. Alle Daten sind offline verfügbar.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get lilypondNotice =>
      'Diese Lilypond-Noten verwenden Funktionen, die setDING nicht darstellen kann. Quelltext:';

  @override
  String get sequenceLabel => 'Songablauf';

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
  String get editorGroupChords => 'Akkorde';

  @override
  String get editorGroupSections => 'Abschnitte';

  @override
  String get editorGroupInfo => 'Song-Infos';

  @override
  String get editorGroupText => 'Text';

  @override
  String get editorGroupMore => 'Mehr';

  @override
  String get searchMatchCase => 'Gross-/Kleinschreibung beachten';

  @override
  String get replaceToggle => 'Ersetzen';

  @override
  String get replaceWith => 'Ersetzen durch';

  @override
  String get replace => 'Ersetzen';

  @override
  String get replaceAll => 'Alle ersetzen';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ersetzt',
      one: '1 ersetzt',
    );
    return '$_temp0';
  }

  @override
  String get convertChordsOverLyrics => 'Akkorde über Text umwandeln';

  @override
  String get pastedChordsOverLyrics =>
      'Der eingefügte Text hat Akkorde über dem Liedtext.';

  @override
  String get convert => 'Umwandeln';

  @override
  String get convertCcliGrids => 'Taktzeilen in Chord-Grid umwandeln';

  @override
  String ccliGridsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Blöcke mit Taktzeilen können',
      one: 'Ein Block mit Taktzeilen kann',
    );
    return '$_temp0 als Chord-Grid dargestellt werden.';
  }

  @override
  String get remove => 'Entfernen';

  @override
  String get ccliFooterHint =>
      'Am Ende steht der CCLI-Footer von SongSelect. Entfernen übernimmt Songnummer und Copyright in die Songdetails.';

  @override
  String legacyLabelsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Abschnitts-Beschriftungen stehen',
      one: 'Eine Abschnitts-Beschriftung steht',
    );
    return '$_temp0 in der Kurzform. Die ChordPro-Spezifikation empfiehlt label=\"…\".';
  }

  @override
  String songSelectDirectivesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CCLI-Direktiven entsprechen',
      one: 'Eine CCLI-Direktive entspricht',
    );
    return '$_temp0 nicht der ChordPro-Spezifikation: ccli wird zu x_ccli, ccli_license wird entfernt.';
  }

  @override
  String importLegacyLabelsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count importierte Songs schreiben',
      one: '1 importierter Song schreibt',
    );
    return '$_temp0 Abschnitts-Beschriftungen in der Kurzform. Umwandeln schreibt sie als label=\"…\", wie es die ChordPro-Spezifikation empfiehlt; die Songs sehen gleich aus.';
  }

  @override
  String get convertLabels => 'Beschriftungen umwandeln';

  @override
  String songsLabelsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Beschriftungen in $count Songs umgewandelt',
      one: 'Beschriftungen in 1 Song umgewandelt',
      zero: 'Keine Beschriftungen umgewandelt',
    );
    return '$_temp0';
  }

  @override
  String get hideHint => 'Hinweis ausblenden';

  @override
  String get searchInSong => 'Suchen';

  @override
  String get searchNoMatches => 'Keine Treffer';

  @override
  String get searchPrevious => 'Vorheriger Treffer';

  @override
  String get searchNext => 'Nächster Treffer';

  @override
  String get searchClose => 'Suche schliessen';

  @override
  String searchMatchCount(int current, int total) {
    return '$current von $total';
  }

  @override
  String get editorGroupLines => 'Zeilen';

  @override
  String get redo => 'Wiederholen';

  @override
  String get moveLinesUp => 'Zeile nach oben';

  @override
  String get moveLinesDown => 'Zeile nach unten';

  @override
  String get moveChordLeft => 'Akkord nach links';

  @override
  String get moveChordRight => 'Akkord nach rechts';

  @override
  String get duplicateLines => 'Zeile duplizieren';

  @override
  String get deleteLines => 'Zeile löschen';

  @override
  String get toggleComment => 'Zeile auskommentieren (#)';

  @override
  String get insertOptionalChord => 'Optionaler Akkord';

  @override
  String get insertAnnotation => 'Anmerkung';

  @override
  String get insertNoChord => 'Kein Akkord (N.C.)';

  @override
  String get insertDefine => 'Akkord-Definition';

  @override
  String get insertChordDiagram => 'Akkord-Diagramm';

  @override
  String get insertTranspose => 'Transponieren';

  @override
  String get insertTab => 'Tabulatur';

  @override
  String get insertGrid => 'Akkord-Grid';

  @override
  String get insertChorusRecall => 'Chorus wiederholen';

  @override
  String get metaSubtitle => 'Untertitel';

  @override
  String get metaComposer => 'Komponist';

  @override
  String get metaLyricist => 'Texter';

  @override
  String get metaCopyright => 'Copyright';

  @override
  String get metaCcli => 'CCLI-Nummer';

  @override
  String get metaTag => 'Tag';

  @override
  String get metaYear => 'Jahr';

  @override
  String get metaAlbum => 'Album';

  @override
  String get metaDuration => 'Dauer';

  @override
  String get metaTempo => 'Tempo (BPM)';

  @override
  String get metaTime => 'Taktart';

  @override
  String get metaKey => 'Tonart';

  @override
  String get insertCommentItalic => 'Kommentar (kursiv)';

  @override
  String get insertCommentBox => 'Kommentar (Rahmen)';

  @override
  String get insertHighlight => 'Hervorhebung';

  @override
  String get insertBold => 'Fett';

  @override
  String get insertItalic => 'Kursiv';

  @override
  String get insertUnderline => 'Unterstrichen';

  @override
  String get insertColour => 'Farbe';

  @override
  String get insertColumnBreak => 'Spaltenumbruch';

  @override
  String get insertNewPage => 'Seitenumbruch';

  @override
  String get insertColumns => 'Spalten';

  @override
  String get insertImage => 'Bild';

  @override
  String get insertAbc => 'ABC-Notation';

  @override
  String get insertTextblock => 'Textblock';

  @override
  String get insertNewSong => 'Nächster Song in derselben Datei';

  @override
  String get sequenceEdit => 'Songablauf für dieses Set';

  @override
  String get sequenceFromSet => 'Ablauf für dieses Set angepasst';

  @override
  String get sequenceFromBand => 'Abfolge der Band';

  @override
  String get bandArrangement => 'Band-Arrangement';

  @override
  String arrangementOf(String band) {
    return 'Arrangement von $band';
  }

  @override
  String get arrangementBand => 'Band';

  @override
  String get arrangementAsWritten => 'Wie im Song';

  @override
  String arrangementKey(String key) {
    return 'Tonart $key';
  }

  @override
  String get arrangementSequence => 'Abfolge';

  @override
  String get arrangementTempo => 'Tempo';

  @override
  String get arrangementTempoLabel => 'Tempo in BPM (leer = wie im Song)';

  @override
  String get arrangementReset => 'Band-Arrangement auf den Song zurücksetzen';

  @override
  String sequenceOriginal(Object sequence) {
    return 'Im Song: $sequence';
  }

  @override
  String get sequenceNoneInSong => 'Der Song hat keinen Ablauf.';

  @override
  String get sequenceRestore => 'Ablauf des Songs verwenden';

  @override
  String get sequenceHint => 'z. B. I, V1, C, V2, PC, C x2, B, O';

  @override
  String get sequenceAbbreviations =>
      'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = zweimal';

  @override
  String get sequenceEmpty =>
      'Tippe unten auf die Teile oder ziehe sie hierher, um den Ablauf zusammenzustellen.';

  @override
  String get sequenceReorderHint =>
      'Teil lange drücken, um ihn an eine andere Stelle zu verschieben.';

  @override
  String get sequenceSongParts => 'Teile des Songs';

  @override
  String get sequenceCommonParts =>
      'Übliche Teile (der Song hat noch keine Abschnitte)';

  @override
  String get sequenceClear => 'Leeren';

  @override
  String get sequenceAsText => 'Als Text bearbeiten';

  @override
  String get settingsSectionAccount => 'Konto & Synchronisation';

  @override
  String get accountSignedOut => 'Nicht angemeldet';

  @override
  String get accountSignedOutHint =>
      'Melde dich an, um Songs und Sets mit deiner Band zu teilen. Ohne Konto funktioniert setDING weiterhin lokal auf diesem Gerät.';

  @override
  String get accountSignIn => 'Anmelden';

  @override
  String get accountSignUp => 'Konto erstellen';

  @override
  String get accountJoin => 'Mit Einladung beitreten';

  @override
  String get accountSignOut => 'Abmelden';

  @override
  String get accountSignOutTitle => 'Abmelden?';

  @override
  String get accountSignOutMessage =>
      'Songs und Sets auf diesem Gerät bleiben erhalten.';

  @override
  String get accountSignOutMessageWeb =>
      'Die Daten in diesem Browser werden gelöscht. Songs und Sets bleiben auf dem Server.';

  @override
  String get accountEmail => 'E-Mail';

  @override
  String get accountPassword => 'Passwort';

  @override
  String get accountPasswordConfirm => 'Passwort bestätigen';

  @override
  String get accountPasswordShow => 'Passwort anzeigen';

  @override
  String get accountPasswordHide => 'Passwort verbergen';

  @override
  String get accountKeepSignedIn => 'Angemeldet bleiben';

  @override
  String get accountKeepSignedInHint =>
      'Nur auf deinem eigenen Gerät. Sonst endet die Anmeldung, wenn du den Browser schliesst.';

  @override
  String get accountName => 'Name';

  @override
  String get accountNameHint => 'So sehen dich deine Bandmitglieder.';

  @override
  String get accountToSignUp => 'Noch kein Konto? Konto erstellen';

  @override
  String get accountToSignIn => 'Bereits ein Konto? Anmelden';

  @override
  String get accountForgotPassword => 'Passwort vergessen?';

  @override
  String get accountResetTitle => 'Passwort zurücksetzen';

  @override
  String get accountResetSent =>
      'Falls es ein Konto mit dieser Adresse gibt, wurde eine E-Mail zum Zurücksetzen gesendet.';

  @override
  String get accountFieldRequired => 'Bitte ausfüllen.';

  @override
  String accountPasswordTooShort(int min) {
    return 'Mindestens $min Zeichen.';
  }

  @override
  String get accountPasswordMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get accountChangeName => 'Name ändern';

  @override
  String get accountNameChanged => 'Name geändert.';

  @override
  String get accountChangePassword => 'Passwort ändern';

  @override
  String get accountChangePasswordHint =>
      'Auf diesem Gerät bleibst du angemeldet. Deine anderen Geräte werden abgemeldet.';

  @override
  String get accountCurrentPassword => 'Aktuelles Passwort';

  @override
  String get accountNewPassword => 'Neues Passwort';

  @override
  String get accountPasswordWrongCurrent => 'Das aktuelle Passwort ist falsch.';

  @override
  String get accountPasswordChanged =>
      'Passwort geändert. Melde dich auf deinen anderen Geräten neu an.';

  @override
  String get accountDelete => 'Konto löschen';

  @override
  String get accountDeleteHint =>
      'Löscht dein Konto und deine persönlichen Daten endgültig.';

  @override
  String get accountDeleteTitle => 'Konto löschen?';

  @override
  String get accountDeleteMessage =>
      'Dein Konto, deine persönlichen Anpassungen, Annotationen und Einstellungen werden endgültig gelöscht, und du wirst auf allen Geräten abgemeldet. Songs und Sets bleiben bei deinen Organisationen. Die Backups des Servers behalten bis zu 14 Tage eine Kopie. Gib zur Bestätigung dein Passwort ein.';

  @override
  String get accountDeleteSoleAdmin =>
      'Du bist der einzige Admin dieser Organisationen. Ernenne zuerst jemand anderen zum Admin oder schliesse die Organisation:';

  @override
  String get accountDeleted => 'Dein Konto wurde gelöscht.';

  @override
  String get dangerZone => 'Gefahrenzone';

  @override
  String get accountErrorNetwork =>
      'Keine Verbindung zum Server. Prüfe die Internetverbindung.';

  @override
  String get accountErrorInvalidCredentials =>
      'E-Mail oder Passwort ist falsch.';

  @override
  String get accountErrorEmailTaken =>
      'Mit dieser E-Mail-Adresse gibt es bereits ein Konto.';

  @override
  String get accountErrorInvalidEmail => 'Die E-Mail-Adresse ist ungültig.';

  @override
  String get accountErrorWeakPassword =>
      'Das Passwort erfüllt die Anforderungen des Servers nicht.';

  @override
  String get accountErrorServer =>
      'Der Server hat einen Fehler gemeldet. Versuche es später nochmals.';

  @override
  String get accountErrorUpdateRequired =>
      'Diese Version von setDING ist zu alt für den Server. Bitte aktualisiere die App.';

  @override
  String get updateRequiredTitle => 'Bitte setDING aktualisieren';

  @override
  String get updateRequiredBody =>
      'Der Server akzeptiert diese Version nicht mehr, deshalb wird nichts synchronisiert. Deine Änderungen bleiben auf diesem Gerät und werden nach dem Update übertragen.';

  @override
  String updateRequiredVersions(String current, String minimum) {
    return 'Installiert: $current, benötigt: $minimum oder neuer.';
  }

  @override
  String get updateRequiredHowTo =>
      'Auf Android aktualisierst du sie in Obtainium, sonst lädst du die neue Version bei den setDING-Releases auf GitHub herunter.';

  @override
  String get updateRequiredReload => 'Neu laden';

  @override
  String get updateRequiredCopyLink => 'Download-Link kopieren';

  @override
  String get updateRequiredCopied => 'Link kopiert.';

  @override
  String updateAvailableTitle(String version) {
    return 'setDING $version ist verfügbar';
  }

  @override
  String get updateAvailableDetails => 'Details';

  @override
  String updateAvailableInstalled(String current) {
    return 'Installiert: $current.';
  }

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerHint => 'Beim Wechsel wirst du abgemeldet.';

  @override
  String get settingsServerInvalid =>
      'Die Adresse muss mit http:// oder https:// beginnen.';

  @override
  String get bandLocal => 'Auf diesem Gerät';

  @override
  String get bandLocalHint =>
      'Nur auf diesem Gerät, wird nicht synchronisiert.';

  @override
  String get bandSwitch => 'Band wechseln';

  @override
  String get bandManage => 'Bands verwalten';

  @override
  String get bandNone => 'Keine Band';

  @override
  String noBandInLibrary(String organization) {
    return 'Du bist in keiner Band von $organization. Sets gehören zu einer Band: Erstelle eine oder lass dich hinzufügen.';
  }

  @override
  String get librarySwitch => 'Songbibliothek wechseln';

  @override
  String get bandsTitle => 'Bands';

  @override
  String get bandsEmpty =>
      'Du bist noch in keiner Band. Erstelle eine Band für deine Songs und Sets.';

  @override
  String get bandsSignInHint => 'Melde dich an, um Bands zu erstellen.';

  @override
  String get bandNew => 'Neue Band';

  @override
  String get bandName => 'Bandname';

  @override
  String get bandRoleAdmin => 'Admin';

  @override
  String get bandRoleMember => 'Mitglied';

  @override
  String get bandMembers => 'Mitglieder';

  @override
  String bandYou(String name) {
    return '$name (du)';
  }

  @override
  String get bandMakeAdmin => 'Zum Admin machen';

  @override
  String get bandMakeMember => 'Zum Mitglied machen';

  @override
  String get bandRoleLeader => 'Leitung';

  @override
  String get bandRolePlanner => 'Setplanung';

  @override
  String get orgRoleLibrarian => 'Bibliothek';

  @override
  String get bandMakeLeader => 'Zur Leitung machen';

  @override
  String get bandMakePlanner => 'Für die Setplanung einsetzen';

  @override
  String get orgMakeLibrarian => 'Für die Bibliothek einsetzen';

  @override
  String get orgLibrarianHint =>
      'Die Bibliothek erstellt, bearbeitet und löscht die Songs der Organisation.';

  @override
  String get bandPlannerHint =>
      'Die Setplanung stellt die Sets der Band zusammen.';

  @override
  String get inviteBandHint =>
      'Erstellt einen Link, der 7 Tage gilt. Wer ihn öffnet, wird Mitglied der Organisation und dieser Band.';

  @override
  String joinQuestionBand(String band, String org) {
    return '$band ($org) beitreten?';
  }

  @override
  String get joinExplanationBand =>
      'Du wirst Mitglied der Organisation und der Band und siehst ihre Songs und Sets.';

  @override
  String get bandRemoveMember => 'Aus der Band entfernen';

  @override
  String bandRemoveTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String bandRemoveMessage(String name) {
    return '$name sieht die Songs und Sets der Band danach nicht mehr.';
  }

  @override
  String get bandLeave => 'Band verlassen';

  @override
  String bandLeaveTitle(String band) {
    return '$band verlassen?';
  }

  @override
  String get bandLeaveMessage =>
      'Du siehst die Songs und Sets der Band danach nicht mehr. Ein Admin kann dich wieder einladen.';

  @override
  String get bandRefresh => 'Aktualisieren';

  @override
  String get bandErrorLastAdmin => 'Eine Band braucht mindestens einen Admin.';

  @override
  String get bandErrorNotAllowed =>
      'Dazu fehlt die Berechtigung, oder die Band gibt es nicht mehr.';

  @override
  String get accountErrorSignedOut => 'Bitte melde dich an.';

  @override
  String get copyToBand => 'In Band kopieren';

  @override
  String get copyToBandTitle => 'In welche Band kopieren?';

  @override
  String get copyToBandNoTarget =>
      'Es gibt keine andere Band, in die du kopieren darfst.';

  @override
  String copiedSongs(int count, String band) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs nach $band kopiert',
      one: '1 Song nach $band kopiert',
    );
    return '$_temp0';
  }

  @override
  String copiedSet(String band) {
    return 'Set nach $band kopiert';
  }

  @override
  String songsSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get selectMode => 'Auswählen';

  @override
  String get deleteSelected => 'Ausgewählte löschen';

  @override
  String deleteSongsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs löschen?',
      one: '1 Song löschen?',
    );
    return '$_temp0';
  }

  @override
  String deleteSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die $count ausgewählten Songs werden gelöscht und aus allen Sets entfernt.',
      one: 'Der ausgewählte Song wird gelöscht und aus allen Sets entfernt.',
    );
    return '$_temp0 Im Papierkorb kannst du sie wiederherstellen.';
  }

  @override
  String songsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs gelöscht',
      one: '1 Song gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get bandRoleOrgAdmin => 'Admin der Organisation';

  @override
  String get bandOrganization => 'Organisation';

  @override
  String get bandNewOrganization => 'Neue Organisation';

  @override
  String get bandNewHint => 'Die Bands einer Organisation teilen ihre Songs.';

  @override
  String get bandAddMember => 'Mitglied hinzufügen';

  @override
  String get bandAddMemberTitle => 'Wen hinzufügen?';

  @override
  String get bandAddMemberNone =>
      'Alle Personen der Organisation sind schon in dieser Band.';

  @override
  String get bandOrgAdminHint =>
      'Du verwaltest diese Band als Admin der Organisation.';

  @override
  String get bandErrorNotOrgMember =>
      'Diese Person gehört nicht zur Organisation.';

  @override
  String get orgName => 'Name der Organisation';

  @override
  String get orgPeople => 'Personen';

  @override
  String get orgBands => 'Bands';

  @override
  String get orgRemove => 'Aus der Organisation entfernen';

  @override
  String orgRemoveTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String orgRemoveMessage(String name) {
    return '$name verlässt damit auch alle Bands der Organisation und sieht ihre Songs nicht mehr.';
  }

  @override
  String get orgLeave => 'Organisation verlassen';

  @override
  String orgLeaveTitle(String org) {
    return '$org verlassen?';
  }

  @override
  String get orgLeaveMessage =>
      'Du verlässt damit auch alle ihre Bands und siehst ihre Songs nicht mehr.';

  @override
  String get orgSongsShared =>
      'Alle Bands der Organisation teilen dieselben Songs.';

  @override
  String get copyToLibraryTitle => 'In welche Songbibliothek kopieren?';

  @override
  String get inviteCreate => 'Personen einladen';

  @override
  String get inviteCreateHint =>
      'Erstellt einen Link, der 7 Tage gilt. Wer ihn öffnet, wird Mitglied der Organisation.';

  @override
  String get inviteLinkTitle => 'Einladungslink';

  @override
  String inviteLinkHint(String date) {
    return 'Teile den Link, z. B. im Gruppenchat, oder lass den QR-Code scannen. Gültig bis $date. Du kannst ihn in der Liste der Einladungslinks wieder anzeigen.';
  }

  @override
  String get inviteCopy => 'Link kopieren';

  @override
  String get inviteCopied => 'Link kopiert';

  @override
  String get invitesTitle => 'Einladungslinks';

  @override
  String inviteDates(String created, String expires) {
    return 'Erstellt am $created, gültig bis $expires';
  }

  @override
  String get inviteOrganizationOnly => 'Nur Organisation';

  @override
  String get inviteShow => 'Link anzeigen';

  @override
  String inviteJoined(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beigetreten: $names',
      one: 'Beigetreten: $names',
      zero: 'Noch niemand beigetreten',
    );
    return '$_temp0';
  }

  @override
  String get inviteRevoke => 'Widerrufen';

  @override
  String get inviteRevokeTitle => 'Link widerrufen?';

  @override
  String get inviteRevokeMessage =>
      'Der Link funktioniert danach nicht mehr. Wer schon beigetreten ist, bleibt Mitglied.';

  @override
  String get inviteAskAdmin =>
      'Für eine Einladung wende dich an einen Admin der Organisation oder an die Leitung einer Band.';

  @override
  String get inviteErrorUnknown =>
      'Diese Einladung gibt es nicht. Prüfe den Link.';

  @override
  String get inviteErrorExpired =>
      'Diese Einladung ist abgelaufen. Bitte um einen neuen Link.';

  @override
  String get inviteErrorRevoked =>
      'Diese Einladung wurde widerrufen. Bitte um einen neuen Link.';

  @override
  String get joinTitle => 'Beitreten';

  @override
  String get joinHint => 'Füge den Einladungslink ein, den du erhalten hast.';

  @override
  String get joinLink => 'Einladungslink';

  @override
  String get joinContinue => 'Weiter';

  @override
  String get joinInvalidLink => 'Das ist kein gültiger Einladungslink.';

  @override
  String joinQuestion(String org) {
    return '$org beitreten?';
  }

  @override
  String get joinExplanation =>
      'Du wirst Mitglied der Organisation und siehst ihre Songs. Ein Admin kann dich danach in eine Band aufnehmen.';

  @override
  String joinAlreadyMember(String org) {
    return 'Du bist bereits Mitglied von $org.';
  }

  @override
  String get joinButton => 'Beitreten';

  @override
  String joinDone(String org) {
    return 'Du bist $org beigetreten.';
  }

  @override
  String get joinSignInFirst =>
      'Melde dich an oder erstelle ein Konto, um beizutreten.';

  @override
  String get joinHaveAccount => 'Ich habe schon ein Konto';

  @override
  String get inviteErrorUsed =>
      'Diese Einladung wurde bereits verwendet. Bitte um einen neuen Link.';

  @override
  String get inviteErrorNotStored =>
      'Dieser Link kann nicht mehr angezeigt werden. Erstelle einen neuen.';

  @override
  String get accountErrorInvitationRequired =>
      'Dieser Server nimmt neue Konten nur mit einem Einladungslink an.';

  @override
  String get accountErrorEmailNotVerified =>
      'Bitte bestätige zuerst deine E-Mail-Adresse. Wir haben dir eine neue Mail geschickt.';

  @override
  String get bandErrorFounderInvitationRequired =>
      'Neue Organisationen brauchen eine Gründungs-Einladung vom Server-Betreiber.';

  @override
  String get accountInviteOnlyHint =>
      'Neue Konten brauchen auf diesem Server einen Einladungslink.';

  @override
  String accountVerifyEmail(String email) {
    return 'Fast geschafft: Wir haben eine Mail an $email geschickt. Bestätige deine Adresse mit dem Link darin und melde dich dann an.';
  }

  @override
  String get accountVerifyResend => 'Mail erneut senden';

  @override
  String get accountVerifySent => 'Mail gesendet.';

  @override
  String joinFoundQuestion(String org) {
    return '$org gründen?';
  }

  @override
  String get joinFoundExplanation =>
      'Du erstellst die Organisation und wirst ihr Admin. Danach kannst du Bands anlegen und Leute einladen.';

  @override
  String get joinFoundButton => 'Organisation gründen';

  @override
  String joinFoundDone(String org) {
    return 'Du hast $org gegründet.';
  }

  @override
  String get syncTitle => 'Synchronisation';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get settingsSyncMode => 'Synchronisieren';

  @override
  String get syncModeAutomatic => 'Automatisch';

  @override
  String get syncModeOnStart => 'Beim Start';

  @override
  String get syncModeManual => 'Manuell';

  @override
  String get syncModeAutomaticHint =>
      'Synchronisiert beim Start, wenige Sekunden nach Änderungen, bei Änderungen auf dem Server und alle 5 Minuten.';

  @override
  String get syncModeOnStartHint =>
      'Synchronisiert einmal beim Start der App und nach dem Anmelden. Sonst mit «Jetzt synchronisieren».';

  @override
  String get syncModeManualHint =>
      'Synchronisiert nur, wenn du auf «Jetzt synchronisieren» tippst.';

  @override
  String get syncRunning => 'Synchronisiere …';

  @override
  String syncLast(String time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String get syncNever => 'Noch nicht synchronisiert';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen sind noch nicht auf dem Server.',
      one: '1 Änderung ist noch nicht auf dem Server.',
      zero: 'Alle Änderungen sind auf dem Server.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline =>
      'Keine Verbindung – Änderungen werden später übertragen.';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs mit Konflikt – öffne sie, um zu entscheiden.',
      one: '1 Song mit Konflikt – öffne ihn, um zu entscheiden.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBanner =>
      'Dieser Song wurde auf dem Server und auf diesem Gerät geändert.';

  @override
  String get conflictBannerDeleted =>
      'Dieser Song wurde auf dem Server gelöscht und auf diesem Gerät geändert.';

  @override
  String get conflictKeepMine => 'Meine Version behalten';

  @override
  String get conflictTakeServer => 'Server-Version übernehmen';

  @override
  String get conflictKeepBoth => 'Beide behalten';

  @override
  String get conflictCompare => 'Server-Version ansehen';

  @override
  String get conflictServerVersion => 'Version auf dem Server';

  @override
  String get conflictKeptBoth =>
      'Deine Version wurde als eigener Song gespeichert.';

  @override
  String get accountErrorConflict =>
      'Der Song wurde inzwischen auf dem Server geändert.';

  @override
  String get pdfMissing =>
      'Das PDF ist noch nicht auf diesem Gerät. Es wird beim nächsten Sync geladen.';

  @override
  String get pdfLoadFailed =>
      'Das PDF konnte nicht vom Server geladen werden. Prüfe die Verbindung und öffne den Song erneut.';

  @override
  String get openAttachment => 'Anzeigen';

  @override
  String get imageMissing => 'Das Bild ist nicht auf diesem Gerät.';

  @override
  String syncMissingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs werden noch geladen.',
      one: '1 PDF wird noch geladen.',
    );
    return '$_temp0';
  }

  @override
  String get invalidChordProTitle => 'ChordPro prüfen?';

  @override
  String get invalidChordProMessage =>
      'Der Song enthält Stellen, die wahrscheinlich nicht wie gewollt angezeigt werden:';

  @override
  String problemUnclosedDirective(int line) {
    return 'Zeile $line: Eine geschweifte Klammer (Direktive) wird nicht geschlossen.';
  }

  @override
  String problemUnclosedChord(int line) {
    return 'Zeile $line: Eine eckige Klammer (Akkord) wird nicht geschlossen.';
  }

  @override
  String problemUnclosedEnvironment(int line) {
    return 'Zeile $line: Der Block wird nie beendet und enthält den ganzen Rest des Songs.';
  }

  @override
  String problemTextAfterDirective(int line) {
    return 'Zeile $line: Nach der Direktive steht noch Text; die ganze Zeile wird als Liedtext angezeigt.';
  }

  @override
  String chordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Stellen im ChordPro werden wahrscheinlich nicht wie gewünscht angezeigt',
      one: '1 Stelle im ChordPro wird wahrscheinlich nicht wie gewünscht angezeigt',
    );
    return '$_temp0';
  }

  @override
  String chordProProblemsShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ChordPro-Probleme anzeigen',
      one: 'ChordPro-Problem anzeigen',
    );
    return '$_temp0';
  }

  @override
  String setChordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs mit ChordPro-Problemen',
      one: '1 Song mit ChordPro-Problemen',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsTitle => 'Import prüfen';

  @override
  String importProblemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count importierte Songs enthalten Stellen',
      one: '1 importierter Song enthält Stellen',
    );
    return '$_temp0, die wahrscheinlich nicht wie gewünscht angezeigt werden:';
  }

  @override
  String importProblemItem(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stellen',
      one: '1 Stelle',
    );
    return '$title ($_temp0)';
  }

  @override
  String get importProblemsHint =>
      'Die Songs sind in der Songliste markiert. Automatisch korrigiert werden nur Stellen mit eindeutiger Korrektur; den Rest im Editor beheben.';

  @override
  String songsFixed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs korrigiert',
      one: '1 Song korrigiert',
      zero: 'Kein Song korrigiert',
    );
    return '$_temp0';
  }

  @override
  String moreProblems(int count) {
    return '… und $count weitere.';
  }

  @override
  String get saveAnyway => 'Trotzdem speichern';

  @override
  String get fixProblems => 'Automatisch korrigieren';

  @override
  String get keepEditing => 'Weiter bearbeiten';

  @override
  String get webSignInHint =>
      'Melde dich an, um Organisationen, Bands, Songs und Sets im Browser zu verwalten.';

  @override
  String get webNoBandTitle => 'Noch keine Band';

  @override
  String get webNoBandMessage =>
      'Du bist noch in keiner Band. Erstelle eine Organisation mit einer Band oder tritt mit einem Einladungslink bei.';

  @override
  String get songDetails => 'Songdetails';

  @override
  String get songDetailsTooltip =>
      'Titel, Tonart, Tempo und mehr des Songs bearbeiten – für alle';

  @override
  String get noKey => 'Keine Tonart';

  @override
  String get timeHint => 'z. B. 4/4';

  @override
  String get noSequence => 'Kein Songablauf';

  @override
  String get sequenceChange => 'Songablauf ändern';

  @override
  String get sortSongs => 'Sortieren';

  @override
  String get sortByTitle => 'Titel';

  @override
  String get sortByArtist => 'Interpret';

  @override
  String get sortByKey => 'Tonart';

  @override
  String get sortByRecent => 'Zuletzt bearbeitet';

  @override
  String get noArtist => 'Ohne Interpret';

  @override
  String get songConflictTooltip =>
      'Hier und auf dem Server geändert – zum Entscheiden den Song öffnen';

  @override
  String get pdfOnlyTooltip => 'Nur Noten (PDF), keine Akkorde';

  @override
  String upcomingGigTooltip(String set, String date) {
    return 'In «$set» am $date';
  }

  @override
  String get foundInLyrics => 'Im Liedtext gefunden';

  @override
  String hiddenParts(String parts) {
    return 'Ausgeblendet (nicht im Ablauf): $parts';
  }

  @override
  String get setsUpcoming => 'Bevorstehend';

  @override
  String get setsUndated => 'Ohne Datum';

  @override
  String setsPast(int count) {
    return 'Vergangen ($count)';
  }

  @override
  String get showPastSets => 'Vergangene Sets anzeigen';

  @override
  String get hidePastSets => 'Vergangene Sets ausblenden';

  @override
  String get nextGig => 'Nächster Auftritt';

  @override
  String gigInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days Tagen',
      one: 'Morgen',
      zero: 'Heute',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Rückgängig';

  @override
  String songDeleted(String title) {
    return '«$title» gelöscht';
  }

  @override
  String setDeleted(String name) {
    return 'Set «$name» gelöscht';
  }

  @override
  String attachmentDeleted(String name) {
    return 'Anhang «$name» gelöscht';
  }

  @override
  String setItemRemoved(String title) {
    return '«$title» aus dem Set entfernt';
  }

  @override
  String get settingsGroupPersonal => 'Persönlich – auf allen deinen Geräten';

  @override
  String get settingsGroupDevice => 'Dieses Gerät';

  @override
  String get settingsGroupAccount => 'Konto & Organisation';

  @override
  String get settingsScopePersonalHint =>
      'Diese Einstellungen gehören zu deinem Konto und gelten auf allen Geräten, auf denen du angemeldet bist.';

  @override
  String get settingsScopePersonalSignedOutHint =>
      'Abgemeldet gelten diese Einstellungen nur auf diesem Gerät. Nach dem Anmelden werden sie mit deinem Konto synchronisiert.';

  @override
  String get settingsScopeDeviceHint =>
      'Diese Einstellungen gelten nur auf diesem Gerät und werden nicht synchronisiert.';

  @override
  String get settingsTakenOver =>
      'Die Einstellungen deines Kontos wurden übernommen.';

  @override
  String get annotationsDraw => 'Freihand-Notizen zeichnen';

  @override
  String get annotationsShow => 'Notizen anzeigen';

  @override
  String get annotationsHide => 'Notizen ausblenden';

  @override
  String get annotationPen => 'Stift';

  @override
  String get annotationHighlighter => 'Leuchtstift';

  @override
  String get annotationText => 'Text';

  @override
  String get annotationTextHint => 'Text eingeben';

  @override
  String get annotationEraser => 'Radierer (ganzer Strich)';

  @override
  String get annotationPartialEraser => 'Radierer (Teil eines Strichs)';

  @override
  String get annotationLasso => 'Auswählen (Lasso)';

  @override
  String get annotationStamps => 'Stempel';

  @override
  String get annotationStampsMusic => 'Musikzeichen';

  @override
  String get annotationStampsRepeats => 'Wiederholungen';

  @override
  String get annotationStampsCues => 'Hinweise';

  @override
  String annotationColor(Object number) {
    return 'Farbe $number';
  }

  @override
  String get annotationSize => 'Strichbreite';

  @override
  String get annotationSmaller => 'Kleiner';

  @override
  String get annotationLarger => 'Grösser';

  @override
  String get annotationDeleteSelection => 'Auswahl löschen';

  @override
  String get annotationUndo => 'Rückgängig';

  @override
  String get annotationRedo => 'Wiederholen';

  @override
  String get annotationMore => 'Mehr';

  @override
  String get annotationDrawWithFinger => 'Mit dem Finger zeichnen';

  @override
  String get annotationDone => 'Fertig';

  @override
  String get annotationsDeleteAll => 'Alle Notizen dieses Songs löschen';

  @override
  String get annotationsDeleted => 'Notizen gelöscht';

  @override
  String get annotationsOtherLayout => 'Für eine andere Ansicht gezeichnet';

  @override
  String get annotationsOtherLayoutLandscape => 'Im Querformat gezeichnet';

  @override
  String get annotationsOtherLayoutPortrait => 'Im Hochformat gezeichnet';

  @override
  String annotationsOrphaned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen ohne ihre Zeile',
      one: '1 Notiz ohne ihre Zeile',
    );
    return '$_temp0';
  }

  @override
  String get annotationsFull =>
      'Notizen voll: zum Weiterzeichnen etwas löschen';

  @override
  String annotationsNearlyFull(int percent) {
    return 'Notizen zu $percent % voll';
  }

  @override
  String get annotationsPanelTitle => 'Freihand-Notizen';

  @override
  String get annotationsPanelShow => 'Meine Notizen anzeigen';

  @override
  String annotationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen',
      one: '1 Notiz',
      zero: 'Noch keine: im Live-Modus zeichnen',
    );
    return '$_temp0';
  }

  @override
  String get settingsShowAnnotations => 'Freihand-Notizen anzeigen';

  @override
  String get settingsShowAnnotationsHint =>
      'Deine eigenen Zeichnungen auf Songs und Noten';

  @override
  String get settingsShowOutsideSequence =>
      'Teile ausserhalb des Ablaufs anzeigen';

  @override
  String get settingsShowOutsideSequenceHint =>
      'Im Live-Modus abgeschwächt statt ausgeblendet';

  @override
  String get settingsAnnotationFinger => 'Notizen mit dem Finger zeichnen';

  @override
  String get settingsAnnotationFingerHint =>
      'Für Geräte ohne Stift; sonst blättern die Finger weiter';

  @override
  String get stampFermata => 'Fermate';

  @override
  String get stampBreath => 'Atemzeichen';

  @override
  String get stampCrescendo => 'Crescendo';

  @override
  String get stampDecrescendo => 'Decrescendo';

  @override
  String get stampRitardando => 'Ritardando';

  @override
  String get stampAccent => 'Akzent';

  @override
  String stampRepeat(Object times) {
    return '$times× spielen';
  }

  @override
  String get stampRepeatStart => 'Wiederholung Anfang';

  @override
  String get stampRepeatEnd => 'Wiederholung Ende';

  @override
  String get stampCoda => 'Coda';

  @override
  String get stampSegno => 'Segno';

  @override
  String get stampGlasses => 'Aufpassen';

  @override
  String get stampStop => 'Stopp';

  @override
  String get stampEye => 'Hinschauen';

  @override
  String get stampExclamation => 'Wichtig';

  @override
  String get stampStar => 'Stern';

  @override
  String get settingsSectionBands => 'Organisation & Bands';

  @override
  String get settingsCategoryBandsHint =>
      'Organisationen, Bands, Mitglieder und Einladungen';

  @override
  String get settingsBandsJoinHint =>
      'Mit einem Einladungslink einer Organisation oder Band beitreten.';

  @override
  String get settingsSectionSongDisplay => 'Songdarstellung';

  @override
  String get settingsCategorySongDisplayHint =>
      'Stile pro Abschnitt: Akkorde, Text, Überschriften, Balken';

  @override
  String get songDisplayPreview => 'Vorschau';

  @override
  String get songDisplayPreset => 'Vorlage';

  @override
  String get songDisplayPresetClassic => 'Klassisch';

  @override
  String get songDisplayPresetColorCoded => 'Farbcodiert';

  @override
  String get songDisplayPresetChorusFocus => 'Chorus im Fokus';

  @override
  String get songDisplayPresetSinger => 'Gesang';

  @override
  String get songDisplayPresetGuitar => 'Gitarre';

  @override
  String get songDisplayPresetMinimal => 'Minimal';

  @override
  String get songDisplayPresetBlackWhite => 'Schwarz/Weiss';

  @override
  String get songDisplayPresetCustom => 'Eigene';

  @override
  String get songDisplayDiscardTitle => 'Eigene Stile verwerfen?';

  @override
  String songDisplayDiscardMessage(String name) {
    return 'Die Vorlage «$name» ersetzt deine angepassten Stile.';
  }

  @override
  String get songDisplayDiscard => 'Verwerfen';

  @override
  String get songDisplayFont => 'Schrift';

  @override
  String get songDisplayFontStandard => 'Standard';

  @override
  String get songDisplayFontMonospace => 'Monospace';

  @override
  String get songDisplaySection => 'Abschnitt';

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
      'Grundstil für alle Abschnitte ohne eigenen Stil und für Abschnitte, die nicht erkannt werden (z. B. Tab, Grid, eigene Namen).';

  @override
  String get songDisplayStyle => 'Stil';

  @override
  String get songDisplayOwnStyle => 'Eigener Stil';

  @override
  String songDisplayLike(String name) {
    return 'Wie $name';
  }

  @override
  String songDisplayInheritsHint(String chain) {
    return 'Übernimmt alles von: $chain. Änderungen dort wirken auch hier.';
  }

  @override
  String get songDisplayChords => 'Akkorde';

  @override
  String get songDisplayLyrics => 'Liedtext';

  @override
  String get songDisplayHeading => 'Überschrift';

  @override
  String get songDisplayBar => 'Einrückungsbalken';

  @override
  String get songDisplayBold => 'Fett';

  @override
  String get songDisplayItalic => 'Kursiv';

  @override
  String get songDisplaySize => 'Grösse';

  @override
  String get songDisplayColor => 'Farbe';

  @override
  String get songDisplayShowHeading => 'Überschrift anzeigen';

  @override
  String get songDisplayShowBar => 'Balken anzeigen';

  @override
  String get songDisplayBarWidth => 'Breite';

  @override
  String get songDisplayIndent => 'Einrückung';

  @override
  String get songDisplayTint => 'Hintergrund tönen';

  @override
  String get songDisplaySizeSmall => 'S';

  @override
  String get songDisplaySizeMedium => 'M';

  @override
  String get songDisplaySizeLarge => 'L';

  @override
  String get songDisplaySizeExtraLarge => 'XL';

  @override
  String get songDisplayBarThin => 'Dünn';

  @override
  String get songDisplayBarMedium => 'Mittel';

  @override
  String get songDisplayBarWide => 'Breit';

  @override
  String get songDisplayIndentNone => 'Keine';

  @override
  String get songDisplayIndentNormal => 'Normal';

  @override
  String get songDisplayIndentLarge => 'Gross';

  @override
  String get songColorAuto => 'Automatisch';

  @override
  String get songColorBlue => 'Blau';

  @override
  String get songColorAmber => 'Bernstein';

  @override
  String get songColorRed => 'Rot';

  @override
  String get songColorGreen => 'Grün';

  @override
  String get songColorTeal => 'Türkis';

  @override
  String get songColorPurple => 'Violett';

  @override
  String get songColorPink => 'Pink';

  @override
  String get songColorGrey => 'Grau';

  @override
  String get songColorBlackWhite => 'Schwarz/Weiss';

  @override
  String get songDisplayCustomise => 'Darstellung anpassen';

  @override
  String get songDisplayCustomiseHint =>
      'Akkorde, Text, Überschriften, Balken und Farben';

  @override
  String get songDisplayEditorTitle => 'Songdarstellung anpassen';

  @override
  String get songDisplayDemoSong => 'Demo-Song';

  @override
  String get songDisplayLibrarySong => 'Song aus der Bibliothek …';

  @override
  String get songDisplayPickSong => 'Song für die Vorschau';

  @override
  String get songDisplayResizePreview => 'Vorschau grösser oder kleiner ziehen';

  @override
  String get appUpdateInstall => 'Installieren';

  @override
  String appUpdateInstallTitle(String version) {
    return 'setDING $version installieren?';
  }

  @override
  String get appUpdateInstallBody =>
      'setDING wird geschlossen, die neue Version installiert und wieder gestartet. Deine Daten bleiben auf diesem Gerät.';

  @override
  String get appUpdateDownloading => 'Update wird heruntergeladen …';

  @override
  String get appUpdateFailed =>
      'Das Update konnte nicht installiert werden. Bitte versuche es später nochmals.';

  @override
  String get whatsNewTitle => 'Was ist neu';

  @override
  String whatsNewAvailable(String version) {
    return 'Neu in setDING $version';
  }

  @override
  String get whatsNewShow => 'Anzeigen';

  @override
  String whatsNewVersion(String version) {
    return 'Version $version';
  }

  @override
  String get whatsNewAllChanges => 'Alle Änderungen';

  @override
  String get midiTestTitle => 'MIDI-Test (Prototyp)';

  @override
  String get midiTestTileHint =>
      'Einen Programmwechsel an ein per USB verbundenes Keyboard senden, z. B. einen Nord Stage 3';

  @override
  String get midiTestHint =>
      'Sendet einen Programmwechsel an ein per USB verbundenes Keyboard, um MIDI auf diesem Gerät zu testen. Was das Keyboard sendet, z. B. wenn du darauf ein Programm oder einen Song wählst, erscheint im Protokoll.';

  @override
  String get midiTestDevices => 'Geräte';

  @override
  String get midiTestRefresh => 'Erneut suchen';

  @override
  String get midiTestNoDevices =>
      'Kein MIDI-Gerät gefunden. Verbinde das Keyboard per USB und suche erneut.';

  @override
  String get midiTestConnect => 'Verbinden';

  @override
  String get midiTestDisconnect => 'Trennen';

  @override
  String get midiTestConnected => 'Verbunden';

  @override
  String get midiTestChannel => 'MIDI-Kanal';

  @override
  String get midiTestModeNordProgram => 'Nord-Programm';

  @override
  String get midiTestModeNordSong => 'Nord-Song';

  @override
  String get midiTestModeNordLive => 'Nord Live';

  @override
  String get midiTestModeRaw => 'Rohwerte';

  @override
  String get midiTestBank => 'Bank';

  @override
  String get midiTestLive => 'Live-Speicher';

  @override
  String get midiTestMsb => 'Bank Select MSB (CC 0, 0–127)';

  @override
  String get midiTestLsb => 'Bank Select LSB (CC 32, 0–127)';

  @override
  String get midiTestProgram => 'Programm (1–128)';

  @override
  String get midiTestEmptyNotSent =>
      'Ein leeres Bank Select wird nicht gesendet.';

  @override
  String get midiTestInvalid => 'Werte prüfen';

  @override
  String get midiTestSend => 'Senden';

  @override
  String get midiTestLog => 'Protokoll';

  @override
  String get midiTestCopy => 'Protokoll kopieren';

  @override
  String get midiTestCopied => 'Protokoll kopiert';

  @override
  String get midiTestClear => 'Protokoll leeren';

  @override
  String midiTestSent(String bytes) {
    return 'Gesendet: $bytes';
  }

  @override
  String midiTestReceivedCc(
    int controller,
    int value,
    int channel,
    String bytes,
  ) {
    return 'Empfangen: CC $controller = $value (Kanal $channel) – $bytes';
  }

  @override
  String midiTestReceivedPc(
    int number,
    int program,
    int channel,
    String bytes,
  ) {
    return 'Empfangen: Programmwechsel $number (Wert $program, Kanal $channel) – $bytes';
  }

  @override
  String midiTestReceivedOther(String bytes) {
    return 'Empfangen: $bytes';
  }

  @override
  String midiTestError(String message) {
    return 'Fehler: $message';
  }

  @override
  String get midiTestModeCc => 'Controller';

  @override
  String get midiTestController => 'Controller (CC 0–127)';

  @override
  String get midiTestValue => 'Wert (0–127)';

  @override
  String get midiTestCcHint =>
      'Nord Stage 3 laut midi.guide: CC 2 Live-Modus, CC 3 Song-Modus, CC 5 Song-Teil. Welche Werte was bewirken, gehört zum Test.';

  @override
  String get midiGuideTitle => 'Geführter Test';

  @override
  String get midiGuideHint =>
      'Tippe auf «Senden», schau aufs Display des Nord und tippe an, was passiert ist. Am Nord musst du nichts einstellen. Die Antworten stehen im Protokoll.';

  @override
  String get midiGuideNordSend => 'Nord Stage 3 – senden';

  @override
  String get midiGuideNordReceive => 'Nord Stage 3 – empfangen';

  @override
  String get midiGuideMotifSend => 'Motif XF – senden';

  @override
  String get midiGuideMotifReceive => 'Motif XF – empfangen';

  @override
  String get midiGuideNordReceiveHint =>
      'Stelle am Nord im MIDI-Menü «Program Change» auf «Send» oder «Send & Receive» und den Kanal hier auf den globalen Kanal des Nord. Wähle dann am Nord irgendein Programm, einen Live-Speicher oder einen Song-Teil, z. B. mit dem Drehregler oder den Modus-Tasten. setDING zeigt, was angekommen ist; tippe an, ob es mit dem Display übereinstimmt. Die Ergebnisse stehen im Protokoll.';

  @override
  String get midiGuideMotifSendHint =>
      'Stelle am Motif XF unter Utility → Control (F5) → MIDI (SF2): MIDI IN/OUT auf USB, den Empfang von Bank Select und Program Change ein, den Basic Receive Channel auf den Kanal hier und die Device Number auf «all» oder 1, dann mit Store speichern. Tippe auf «Senden», schau aufs Display des Motif und tippe an, was passiert ist. Die Antworten stehen im Protokoll.';

  @override
  String get midiGuideMotifReceiveHint =>
      'Stelle am Motif XF unter Utility → Control (F5) → MIDI (SF2): MIDI IN/OUT auf USB, das Senden von Bank Select und Program Change ein und den Transmit Channel auf den Kanal hier, dann mit Store speichern. Wähle dann am Motif irgendeine Voice oder Performance, auch in verschiedenen Bänken und zweimal in derselben Bank. setDING zeigt, was angekommen ist; tippe an, ob es mit dem Display übereinstimmt. Die Ergebnisse stehen im Protokoll.';

  @override
  String midiGuideMotifExpected(String name) {
    return 'Der Motif zeigt $name.';
  }

  @override
  String get midiGuideWaiting => 'Wähle am Keyboard einen Klang …';

  @override
  String midiGuideFreeReceived(String name) {
    return 'Empfangen: $name';
  }

  @override
  String get midiGuideMatches => 'Stimmt mit dem Display';

  @override
  String get midiGuideNoMatch => 'Stimmt nicht';

  @override
  String midiGuideFreeResult(String name, String values, String answer) {
    return 'Empfangen $name ($values): $answer';
  }

  @override
  String midiGuideChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Klänge geprüft',
      one: '1 Klang geprüft',
      zero: 'Noch nichts geprüft',
    );
    return '$_temp0';
  }

  @override
  String midiGuideStep(int current, int total, String title) {
    return 'Schritt $current von $total: $title';
  }

  @override
  String midiGuideExpected(String expected) {
    return 'Erwartet: $expected';
  }

  @override
  String get midiGuideDone => 'Test fertig. Die Antworten stehen im Protokoll.';

  @override
  String get midiGuideRestart => 'Neu beginnen';

  @override
  String get midiGuideBack => 'Zurück';

  @override
  String get midiGuideSkip => 'Überspringen';

  @override
  String midiGuideResult(int current, String title, String answer) {
    return 'Schritt $current ($title): $answer';
  }

  @override
  String midiGuideProgram(String name) {
    return 'Programm $name';
  }

  @override
  String midiGuideProgramExpected(String name) {
    return 'Das Nord zeigt $name.';
  }

  @override
  String midiGuideLive(int number) {
    return 'Live-Speicher $number';
  }

  @override
  String midiGuideLiveExpected(int number) {
    return 'Das Nord zeigt Live $number.';
  }

  @override
  String get midiGuideSongModeOn => 'Song-Modus ein (CC 3 = 127)';

  @override
  String get midiGuideSongModeOnExpected =>
      'Das Nord wechselt in den Song-Modus.';

  @override
  String get midiGuideSongModeOff => 'Song-Modus aus (CC 3 = 0)';

  @override
  String get midiGuideSongModeOffExpected =>
      'Das Nord verlässt den Song-Modus.';

  @override
  String get midiGuideAnswerAsExpected => 'Wie erwartet';

  @override
  String get midiGuideAnswerDifferent => 'Etwas anderes';

  @override
  String get midiGuideAnswerNothing => 'Nichts passiert';

  @override
  String get midiTestFree => 'Frei senden';

  @override
  String get midiTestPage => 'Seite';

  @override
  String get midiTestButton => 'Taste';

  @override
  String midiGuideSong(int song, int part) {
    return 'Song $song, Teil $part';
  }

  @override
  String midiGuideSongExpected(int song, int part) {
    return 'Das Nord zeigt Song $song, Teil $part.';
  }

  @override
  String get midiTestSong => 'Song';

  @override
  String get midiTestPart => 'Teil';

  @override
  String get settingsEditorTypingAids =>
      'Klammern und Abschnitte automatisch schliessen';

  @override
  String get settingsEditorTypingAidsHint =>
      'Im ChordPro-Editor: [ ergänzt ], Enter nach einem Abschnittsanfang ergänzt sein Ende, und ein umbenannter Abschnittsanfang benennt sein Ende mit um.';

  @override
  String get settingsDeveloperMode => 'Entwickler-Modus';

  @override
  String get settingsDeveloperModeHint =>
      'Zeigt die Kategorie «Entwicklung» mit experimentellen Funktionen zum Testen. Für den normalen Gebrauch nicht nötig.';

  @override
  String get settingsGroupDevelopment => 'Entwicklung';

  @override
  String get settingsSectionDevelopment => 'Test-Funktionen';

  @override
  String get settingsCategoryDevelopmentHint => 'Experimentell, nur zum Testen';

  @override
  String get settingsDevelopmentNoteTitle => 'Experimentelle Funktionen';

  @override
  String get settingsDevelopmentNote =>
      'Diese Funktionen sind zum Testen da. Sie können sich ändern, fehlerhaft sein oder wieder verschwinden. Nicht für Auftritte gedacht. Ausblenden mit «Entwickler-Modus» unter Allgemein.';

  @override
  String get settingsSectionMidi => 'Keyboard (MIDI)';

  @override
  String get settingsCategoryMidiHint =>
      'Programmwechsel an ein per USB verbundenes Keyboard';

  @override
  String get settingsMidiEnabled => 'MIDI-Programmwechsel';

  @override
  String get settingsMidiEnabledHint =>
      'Im Live-Modus wechselt das Keyboard zum Programm, das beim Song hinterlegt ist.';

  @override
  String settingsMidiConnected(String name) {
    return 'Verbunden mit $name';
  }

  @override
  String get settingsMidiNotConnected => 'Nicht verbunden';

  @override
  String get settingsMidiOutput => 'Ausgang';

  @override
  String get settingsMidiOutputHint =>
      'Das per USB verbundene Keyboard. setDING verbindet sich von selbst wieder, wenn es eingesteckt wird.';

  @override
  String get settingsMidiNoDevices =>
      'Kein MIDI-Gerät gefunden. Verbinde das Keyboard per USB und suche erneut.';

  @override
  String get settingsMidiSearch => 'Erneut suchen';

  @override
  String settingsMidiOutputMissing(String name) {
    return '$name (nicht eingesteckt)';
  }

  @override
  String get settingsMidiProfile => 'Geräteprofil';

  @override
  String get settingsMidiProfileHint =>
      'Wie Keyboard-Programme eingegeben und angezeigt werden. «Allgemein» verwendet Bank Select und Programmnummer und funktioniert mit jedem Keyboard.';

  @override
  String get midiProfileNordStage3 => 'Nord Stage 3';

  @override
  String get midiProfileGeneric => 'Allgemein';

  @override
  String get settingsMidiChannel => 'MIDI-Kanal';

  @override
  String get settingsMidiChannelHint =>
      'Der Kanal, auf dem das Keyboard empfängt.';

  @override
  String get settingsMidiTakeOver => 'Programme vom Keyboard übernehmen';

  @override
  String get settingsMidiTakeOverHint =>
      'Ist im Live-Modus das Keyboard-Programm offen, zeigt setDING den Klang, den du am Keyboard wählst, und übernimmt ihn auf Wunsch in den Song. Das Keyboard muss dafür Bank Select und Program Change senden.';

  @override
  String get settingsMidiTakeOverNordHint =>
      'Ist im Live-Modus das Keyboard-Programm offen, zeigt setDING den Klang, den du am Nord wählst, und übernimmt ihn auf Wunsch in den Song. Stelle dafür am Nord im MIDI-Menü «Program Change» auf «Send» oder «Send & Receive».';

  @override
  String get settingsMidiNordHint =>
      'Schalte am Nord Stage 3 im MIDI-Menü den Empfang von «Program Change» ein und stelle hier den globalen Kanal des Nord ein. Die Nummerierung der Nord-Songs hängt von der OS-Version des Nord ab (geprüft mit OS 2.54); passt ein Song nicht, verwende das Profil «Allgemein».';

  @override
  String get midiProgramTitle => 'Keyboard-Programm';

  @override
  String get midiProgramHint =>
      'Wird im Live-Modus ans Keyboard gesendet, wenn dieser Song an der Reihe ist.';

  @override
  String get midiProgramNone => 'Keines: das Keyboard behält seinen Klang';

  @override
  String get midiProgramChoose => 'Programm wählen';

  @override
  String get midiProgramPreviewSwitch => 'Beim Auswählen senden';

  @override
  String get midiProgramPreviewHint =>
      'Jede Auswahl geht sofort ans Keyboard; «Abbrechen» stellt das bisherige Programm wieder her.';

  @override
  String get midiProgramRemove => 'Programm entfernen';

  @override
  String get midiProgramTest => 'Test';

  @override
  String get midiProgramTestHint => 'Sendet das Programm einmal ans Keyboard';

  @override
  String get midiProgramNotConnected => 'Keyboard nicht verbunden';

  @override
  String get midiProgramOff =>
      'MIDI-Programmwechsel sind auf diesem Gerät ausgeschaltet (Einstellungen: Keyboard (MIDI)).';

  @override
  String midiProgramSent(String device) {
    return 'An $device gesendet';
  }

  @override
  String get midiProgramSendFailed =>
      'Das Programm konnte nicht gesendet werden';

  @override
  String get midiProgramKindProgram => 'Programm';

  @override
  String get midiProgramKindLive => 'Live-Speicher';

  @override
  String get midiProgramKindSong => 'Song';

  @override
  String get midiProgramKindGeneric => 'Andere Werte';

  @override
  String get midiProgramBank => 'Bank';

  @override
  String get midiProgramPageButton => 'Seite (Zeile) und Taste';

  @override
  String get midiProgramSongNumber => 'Song';

  @override
  String get midiProgramPreviousSong => 'Vorheriger Song';

  @override
  String get midiProgramNextSong => 'Nächster Song';

  @override
  String get midiProgramPart => 'Teil';

  @override
  String get midiProgramSongHint =>
      'Die Nummerierung der Nord-Songs hängt von der OS-Version des Nord ab (geprüft mit OS 2.54). Passt ein Song nicht, verwende in den Einstellungen das Profil «Allgemein».';

  @override
  String get midiProgramsTitle => 'Keyboard-Programme';

  @override
  String midiProgramDevice(String profile) {
    return 'Dieses Gerät: $profile';
  }

  @override
  String get midiProgramForOtherKeyboard => 'Programm für ein anderes Keyboard';

  @override
  String midiProgramUnknownKeyboard(String id) {
    return 'Unbekanntes Keyboard ($id)';
  }

  @override
  String get midiProgramMsb => 'Bank Select MSB (optional)';

  @override
  String get midiProgramLsb => 'Bank Select LSB (optional)';

  @override
  String get midiProgramNumber => 'Programm';

  @override
  String midiProgramRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String midiProgramOutOfRange(int min, int max) {
    return 'Eine Zahl von $min bis $max eingeben';
  }

  @override
  String midiProgramValueNord(String name) {
    return 'Programm $name';
  }

  @override
  String get midiProfileMotifXf => 'Yamaha Motif XF';

  @override
  String get settingsMidiMotifHint =>
      'Stelle am Motif XF unter Utility → Control (F5) → MIDI (SF2): MIDI IN/OUT auf USB, den Empfang von Bank Select und Program Change ein, den Basic Receive Channel auf den Kanal hier und die Device Number auf «all» oder 1, dann mit Store speichern. setDING schaltet den Motif vor jedem Programm selbst in den Voice- oder Performance-Modus.';

  @override
  String get midiProgramKindPerformance => 'Performance';

  @override
  String get midiProgramKindVoice => 'Voice';

  @override
  String get midiProgramGroup => 'Gruppe';

  @override
  String get midiProgramMotifNumber => 'Nummer';

  @override
  String get midiProgramMotifHint =>
      'Wie auf dem Display des Motif XF, z.B. USR1 A01. setDING schaltet den Motif vor dem Senden in den Voice- oder Performance-Modus.';

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
    return 'Live-Speicher $number';
  }

  @override
  String midiProgramValueSong(int song, int part) {
    return 'Song $song, Teil $part';
  }

  @override
  String midiProgramValueGeneric(int program) {
    return 'Programm $program';
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
  String get trash => 'Papierkorb';

  @override
  String get trashSongsTitle => 'Gelöschte Songs';

  @override
  String get trashSetsTitle => 'Gelöschte Sets';

  @override
  String trashEmpty(int days) {
    return 'Der Papierkorb ist leer. Gelöschte Songs und Sets lassen sich hier $days Tage lang wiederherstellen.';
  }

  @override
  String trashHint(int days) {
    return 'Gelöschte Songs und Sets lassen sich $days Tage lang wiederherstellen. Danach werden sie endgültig entfernt.';
  }

  @override
  String trashDeletedOn(String date) {
    return 'gelöscht am $date';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'noch $days Tage',
      one: 'noch 1 Tag',
      zero: 'letzter Tag',
    );
    return '$_temp0';
  }

  @override
  String get trashRestore => 'Wiederherstellen';

  @override
  String trashRestored(String title) {
    return '«$title» wiederhergestellt';
  }

  @override
  String get backupExport => 'Bibliothek sichern';

  @override
  String get backupSyncing => 'Mit dem Server synchronisieren …';

  @override
  String get backupCollecting => 'Sicherung wird erstellt …';

  @override
  String get backupSaved => 'Sicherung gespeichert.';

  @override
  String get backupFailedTitle => 'Sichern nicht möglich';

  @override
  String get backupSyncDeferred =>
      'Der Live-Modus ist offen. Schliesse ihn und versuche es noch einmal.';

  @override
  String get backupSyncFailed =>
      'Der Abgleich mit dem Server ist fehlgeschlagen. Eine Sicherung einer Organisation braucht eine Verbindung, damit sie alles enthält. Versuche es wieder, wenn du online bist.';

  @override
  String get backupPendingChanges =>
      'Änderungen auf diesem Gerät sind noch nicht auf dem Server. Warte den Abgleich ab und versuche es noch einmal.';

  @override
  String get backupConflicts =>
      'Einige Songs haben einen Konflikt. Löse zuerst die Konflikte.';

  @override
  String get backupMissingFiles =>
      'Noch nicht alle Anhänge sind heruntergeladen. Warte den Download ab und versuche es noch einmal.';

  @override
  String backupFileMissing(String name, String song) {
    return 'Der Anhang «$name» von «$song» konnte nicht geladen werden.';
  }

  @override
  String get backupInvalid => 'Diese Datei ist keine setDING-Sicherung.';

  @override
  String get backupNewer =>
      'Diese Sicherung stammt von einer neueren setDING-Version. Aktualisiere die App, um sie zu importieren.';

  @override
  String get backupImportTitle => 'Sicherung importieren';

  @override
  String backupImportSummary(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs Songs',
      one: '1 Song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets Sets',
      one: '1 Set',
    );
    return 'Sicherung von «$library»: $_temp0, $_temp1.';
  }

  @override
  String get backupImportCopyHint =>
      'Alles wird als Kopie in die aktuelle Bibliothek importiert. Bestehendes wird nicht verändert.';

  @override
  String backupImportIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs sind',
      one: '1 Song ist',
    );
    return '$_temp0 schon mit gleichem Text hier und werden so verwendet.';
  }

  @override
  String backupImportDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs gibt',
      one: '1 Song gibt',
    );
    return '$_temp0 es hier mit anderem Text:';
  }

  @override
  String get backupKeepExisting => 'Bestehende Songs behalten';

  @override
  String get backupAddAll => 'Als zusätzliche Songs importieren';

  @override
  String get backupImportSetsTo => 'Sets kommen nach:';

  @override
  String backupBandSets(String band, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sets',
      one: '1 Set',
    );
    return '$band ($_temp0)';
  }

  @override
  String get backupSkipSets => 'Nicht importieren';

  @override
  String get backupImportStart => 'Importieren';

  @override
  String get backupImportDone => 'Sicherung importiert';

  @override
  String backupResultSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs importiert',
      one: '1 Song importiert',
    );
    return '$_temp0';
  }

  @override
  String backupResultIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs waren schon hier',
      one: '1 Song war schon hier',
    );
    return '$_temp0';
  }

  @override
  String backupResultKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestehende Songs behalten',
      one: '1 bestehender Song behalten',
    );
    return '$_temp0';
  }

  @override
  String backupResultSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sets',
      one: '1 Set',
      zero: 'Keine Sets',
    );
    return '$_temp0 importiert';
  }

  @override
  String backupResultFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge',
      one: '1 Anhang',
    );
    return '$_temp0';
  }

  @override
  String backupResultAdditional(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese Songs gibt es jetzt zweimal. Vergleiche sie mit den bestehenden und lösche die, die du nicht brauchst:',
      one: 'Diesen Song gibt es jetzt zweimal. Vergleiche ihn mit dem bestehenden und lösche den, den du nicht brauchst:',
    );
    return '$_temp0';
  }

  @override
  String get bandDelete => 'Band löschen';

  @override
  String bandDeleteTitle(String band) {
    return '$band löschen?';
  }

  @override
  String bandDeleteMessage(int days) {
    return 'Ihre Sets, Band-Arrangements und Mitgliedschaften werden mitgelöscht und ihre offenen Einladungen widerrufen. Die Songs bleiben in der Bibliothek der Organisation. Admins der Organisation können die Band $days Tage lang aus dem Papierkorb wiederherstellen. Für eine Kopie ausserhalb von setDING sichere vorher die Bibliothek.';
  }

  @override
  String bandDeleteSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sets',
      one: '1 Set',
      zero: 'keine Sets',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
      zero: 'keine Mitglieder',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Einladungen',
      one: '1 offene Einladung',
      zero: 'keine offenen Einladungen',
    );
    return '$_temp0';
  }

  @override
  String get bandDeleteLastBand =>
      'Das ist die letzte Band der Organisation. Die Organisation und ihre Song-Bibliothek bleiben bestehen.';

  @override
  String bandDeleteConfirmName(String band) {
    return 'Zum Bestätigen «$band» eintippen';
  }

  @override
  String bandDeleted(String band) {
    return '$band gelöscht';
  }

  @override
  String get trashBandsTitle => 'Gelöschte Bands';

  @override
  String trashBandsEmpty(int days) {
    return 'Keine gelöschten Bands. Gelöschte Bands lassen sich hier $days Tage lang wiederherstellen.';
  }

  @override
  String trashBandsHint(int days) {
    return 'Gelöschte Bands lassen sich mit ihren Sets, Arrangements und Mitgliedern $days Tage lang wiederherstellen. Danach werden sie endgültig entfernt.';
  }

  @override
  String bandsGone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names sind für dich nicht mehr verfügbar: Die Bands wurden gelöscht oder du bist kein Mitglied mehr.',
      one:
          '$names ist für dich nicht mehr verfügbar: Die Band wurde gelöscht oder du bist kein Mitglied mehr.',
    );
    return '$_temp0';
  }

  @override
  String get backupAll => 'Alles sichern';

  @override
  String get backupAllName => 'alles';

  @override
  String get backupAllHint =>
      'Deine Bibliotheken mit Songs, Sets und Anhängen, deine persönlichen Anpassungen und Notizen und deine Einstellungen in einer Datei.';

  @override
  String get backupNever => 'Auf diesem Gerät noch nie gesichert.';

  @override
  String backupLast(String date) {
    return 'Letzte Sicherung: $date';
  }

  @override
  String get backupRestore => 'Sicherung wiederherstellen';

  @override
  String get backupRestoreHint =>
      'Importiert eine Sicherungsdatei als Kopie. Bestehendes wird nicht verändert.';

  @override
  String get backupRestoreTitle => 'Sicherung wiederherstellen';

  @override
  String backupLibraryTo(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs Songs',
      one: '1 Song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets Sets',
      one: '1 Set',
    );
    return '«$library» ($_temp0, $_temp1) nach';
  }

  @override
  String get backupImportDifferingAll =>
      'Songs, die es hier mit anderem Text gibt:';

  @override
  String get backupRestorePersonal =>
      'Meine persönlichen Anpassungen und Notizen wiederherstellen';

  @override
  String backupPersonalOf(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$library: $_temp0';
  }

  @override
  String get backupRestoreSettings => 'Meine Einstellungen übernehmen';

  @override
  String get backupRestoreSettingsHint =>
      'Ersetzt deine aktuellen Einstellungen durch die der Sicherung.';

  @override
  String get backupRestoreStart => 'Wiederherstellen';

  @override
  String get backupRestoreDone => 'Sicherung wiederhergestellt';

  @override
  String backupResultPersonal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return 'Persönliche Anpassungen und Notizen von $_temp0 wiederhergestellt';
  }

  @override
  String get backupResultSettings => 'Einstellungen übernommen';

  @override
  String backupReminder(int days) {
    return 'Deine Bibliothek auf diesem Gerät ist seit $days Tagen nicht gesichert.';
  }

  @override
  String get backupReminderAction => 'Sichern';

  @override
  String get orgClose => 'Organisation schliessen';

  @override
  String orgCloseTitle(String org) {
    return '$org schliessen?';
  }

  @override
  String orgCloseMessage(int days) {
    return 'Ihre Bands, Sets, Songs und Anhänge sowie die persönlichen Anpassungen aller zu ihren Songs werden entfernt und ihre Einladungen widerrufen. Die Mitglieder erfahren es beim nächsten Sync. Ihre Admins können sie $days Tage lang aus dem Papierkorb wiederherstellen; danach wird alles endgültig gelöscht.';
  }

  @override
  String orgCloseBands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bands',
      one: '1 Band',
      zero: 'keine Bands',
    );
    return '$_temp0';
  }

  @override
  String orgCloseSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
      zero: 'keine Songs',
    );
    return '$_temp0';
  }

  @override
  String orgClosePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '1 Person',
    );
    return '$_temp0';
  }

  @override
  String get orgCloseBackup => 'Vorher sichern';

  @override
  String orgClosed(String org) {
    return '$org geschlossen';
  }

  @override
  String get orgsClosedTitle => 'Geschlossene Organisationen';

  @override
  String orgsClosedEmpty(int days) {
    return 'Keine geschlossenen Organisationen. Ihre Admins können geschlossene Organisationen hier $days Tage lang wiederherstellen.';
  }

  @override
  String orgsClosedHint(int days) {
    return 'Geschlossene Organisationen lassen sich mit allem, was darin war, $days Tage lang wiederherstellen. Danach werden sie endgültig gelöscht.';
  }

  @override
  String orgClosedOn(String date) {
    return 'geschlossen am $date';
  }

  @override
  String orgClosedBy(String name) {
    return 'von $name';
  }

  @override
  String orgClosedNotice(String org, String name, int days) {
    return '$org wurde von $name geschlossen. Ihre Admins können sie $days Tage lang wiederherstellen.';
  }

  @override
  String orgClosedNoticeAnonymous(String org, int days) {
    return '$org wurde geschlossen. Ihre Admins können sie $days Tage lang wiederherstellen.';
  }

  @override
  String get navOverview => 'Übersicht';

  @override
  String get overviewNextSet => 'Nächstes Set';

  @override
  String get overviewLastEditedSet => 'Zuletzt bearbeitetes Set';

  @override
  String overviewSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
      zero: 'Keine Songs',
    );
    return '$_temp0';
  }

  @override
  String get overviewStartLive => 'Live starten';

  @override
  String get overviewOpenSet => 'Set öffnen';

  @override
  String get overviewTodo => 'Zu erledigen';

  @override
  String overviewTodoProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs mit ChordPro-Problemen',
      one: '1 Song mit ChordPro-Problemen',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs mit Sync-Konflikt',
      one: '1 Song mit Sync-Konflikt',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoSheetMusicOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs nur mit Noten (PDF)',
      one: '1 Song nur mit Noten (PDF)',
    );
    return '$_temp0';
  }

  @override
  String get attentionProblems => 'ChordPro-Probleme';

  @override
  String get attentionConflicts => 'Sync-Konflikte';

  @override
  String get attentionSheetMusicOnly => 'Nur Noten (PDF)';

  @override
  String chordProConversionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stellen im ChordPro umwandeln',
      one: '1 Stelle im ChordPro umwandeln',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs mit möglichen Umwandlungen',
      one: '1 Song mit möglichen Umwandlungen',
    );
    return '$_temp0';
  }

  @override
  String get attentionConversions => 'Umwandelbar';

  @override
  String get convertAllSongs => 'Alle umwandeln';

  @override
  String get convertAllSongsTitle => 'Alle Songs umwandeln?';

  @override
  String convertAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die $count Songs werden',
      one: 'Der Song wird',
    );
    return '$_temp0 für alle umgewandelt: CCLI-Direktiven und Abschnitts-Beschriftungen nach der ChordPro-Spezifikation, CCLI-Taktzeilen als Grid, der CCLI-Footer entfernt.';
  }

  @override
  String songsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs umgewandelt',
      one: '1 Song umgewandelt',
    );
    return '$_temp0';
  }

  @override
  String songConverted(String title) {
    return '«$title» umgewandelt';
  }

  @override
  String get songsFilterEmpty => 'Keine Songs mehr in diesem Filter.';

  @override
  String get playHistory => 'Gespielt';

  @override
  String playHistoryOf(String band) {
    return 'Gespielt von $band';
  }

  @override
  String playHistoryNone(String band) {
    return '$band hat diesen Song noch in keinem vergangenen Set gespielt.';
  }

  @override
  String get playHistoryTotal => 'gesamt';

  @override
  String get playHistoryLastYear => 'letzte 12 Monate';

  @override
  String get playHistoryLast => 'zuletzt';

  @override
  String playHistoryFirst(String date) {
    return 'Erstmals am $date';
  }

  @override
  String playHistoryShowAll(int count) {
    return 'Alle $count anzeigen';
  }

  @override
  String playHistoryDiffers(String key) {
    return 'Hervorgehoben: eine andere Tonart als heute ($key)';
  }

  @override
  String get playHistoryApproximate =>
      '≈ abgeleitet aus dem heutigen Arrangement: das Set hat keine gespeicherten Werte';

  @override
  String keyHistoryLast(String key, String date) {
    return 'Zuletzt $key am $date';
  }

  @override
  String keyHistoryMostly(String key, int count, int total) {
    return 'meist $key ($count von $total)';
  }

  @override
  String songLastPlayed(String date) {
    return 'Zuletzt gespielt am $date';
  }

  @override
  String get songNeverPlayed => 'Noch nie gespielt';

  @override
  String get overviewRecentChanges => 'Letzte Änderungen';

  @override
  String get overviewShowAll => 'Alle anzeigen';

  @override
  String get overviewMoreSets => 'Weitere Sets';

  @override
  String get overviewNewestSongs => 'Neueste Songs';

  @override
  String get recentChangesEmpty =>
      'Keine Änderungen von anderen in den letzten 30 Tagen.';

  @override
  String get changeSongAdded => 'Neuer Song';

  @override
  String get changeNewSet => 'Neues Set';

  @override
  String get changeSongText => 'Text geändert';

  @override
  String get changeSongPdf => 'PDF geändert';

  @override
  String get changeSongTextAndPdf => 'Text und PDF geändert';

  @override
  String changeSetAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs hinzugefügt',
      one: '1 Song hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String changeSetRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs entfernt',
      one: '1 Song entfernt',
    );
    return '$_temp0';
  }

  @override
  String changeSetAlsoRemoved(int count) {
    return '$count entfernt';
  }

  @override
  String changeSetSequence(String songs) {
    return 'Ablauf von $songs geändert';
  }

  @override
  String changeQuoted(String title) {
    return '«$title»';
  }

  @override
  String changeBy(String name) {
    return 'von $name';
  }

  @override
  String get repertoire => 'Repertoire';

  @override
  String repertoireOf(String band) {
    return 'Repertoire von $band';
  }

  @override
  String get repertoireLastYear => '12 Monate';

  @override
  String get repertoireAllTime => 'Gesamt';

  @override
  String get repertoireMostPlayed => 'Meistgespielt';

  @override
  String get repertoireStale => 'Länger nicht gespielt';

  @override
  String repertoireStaleHint(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Zuletzt vor mehr als $months Monaten gespielt',
      one: 'Zuletzt vor mehr als einem Monat gespielt',
    );
    return '$_temp0';
  }

  @override
  String get playedFilter => 'Gespielt';

  @override
  String get playedAll => 'Alle';

  @override
  String get filterByPlayed => 'Nach Einsätzen der Band filtern';

  @override
  String get repertoireNeverPlayed => 'Nie gespielt';

  @override
  String get repertoireNeverPlayedHint =>
      'Songs der Bibliothek, die in keinem vergangenen Set der Band waren';

  @override
  String get repertoireNone => 'Keine';

  @override
  String get repertoireEmpty =>
      'Die Band hat noch keine Songs in vergangenen Sets gespielt.';

  @override
  String repertoirePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-mal',
      one: '1-mal',
    );
    return '$_temp0';
  }

  @override
  String get repertoireThreshold =>
      'Wann gilt ein Song als länger nicht gespielt?';

  @override
  String repertoireMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Nach $months Monaten',
      one: 'Nach 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String repertoireDefault(int months) {
    return 'Standard: nach $months Monaten';
  }

  @override
  String get sortByLastPlayed => 'Zuletzt gespielt';

  @override
  String get playHistoryOtherBands => 'Andere Bands';

  @override
  String playHistoryFetched(String date) {
    return 'Stand: $date';
  }

  @override
  String get libraryUsage => 'Bibliothek · Nutzung';

  @override
  String libraryUsageSummary(int count, int total) {
    return '$count von $total Songs spielt keine Band';
  }

  @override
  String get libraryUsageHint =>
      'Songs, die in keinem vergangenen Set einer Band der Organisation waren. Was keine Band mehr braucht, kannst du in den Papierkorb legen.';

  @override
  String get libraryUsageNotLoaded =>
      'Noch nicht geladen: Synchronisiere einmal mit Verbindung zum Server.';

  @override
  String get libraryUsageAllPlayed =>
      'Jeder Song der Bibliothek wurde schon von einer Band gespielt.';

  @override
  String syncHintSongChanged(String title, String name) {
    return '«$title» wurde von $name geändert.';
  }

  @override
  String syncHintSongDeleted(String title, String name) {
    return '«$title» wurde von $name gelöscht.';
  }

  @override
  String syncHintSetChanged(String title, String name) {
    return 'Das Set «$title» wurde von $name geändert.';
  }

  @override
  String syncHintSetDeleted(String title, String name) {
    return 'Das Set «$title» wurde von $name gelöscht.';
  }

  @override
  String syncHintSongChangedAnonymous(String title) {
    return '«$title» wurde von jemand anderem geändert.';
  }

  @override
  String syncHintSongDeletedAnonymous(String title) {
    return '«$title» wurde von jemand anderem gelöscht.';
  }

  @override
  String syncHintSetChangedAnonymous(String title) {
    return 'Das Set «$title» wurde von jemand anderem geändert.';
  }

  @override
  String syncHintSetDeletedAnonymous(String title) {
    return 'Das Set «$title» wurde von jemand anderem gelöscht.';
  }

  @override
  String syncHintAfterLive(String changes) {
    return 'Während du live gespielt hast: $changes.';
  }

  @override
  String syncHintSongsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs geändert',
      one: '1 Song geändert',
    );
    return '$_temp0';
  }

  @override
  String syncHintSongsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs gelöscht',
      one: '1 Song gelöscht',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sets geändert',
      one: '1 Set geändert',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sets gelöscht',
      one: '1 Set gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get syncHintShowChanges => 'Anzeigen';

  @override
  String get setExportTitle => 'Set exportieren';

  @override
  String get setExportHint =>
      'Das ZIP enthält die ChordPro-Dateien der Songs und eine Beschreibung, mit der setDING das Set wieder als Set importiert.';

  @override
  String get setArchiveArrangements =>
      'Band-Arrangements der Songs (Tonart, Abfolge, Tempo)';

  @override
  String get setArchiveSetSettings =>
      'Tonart und Songablauf der Songs in diesem Set';

  @override
  String get setArchiveAttachments => 'Anhänge (PDFs, Bilder)';

  @override
  String get setArchivePersonal => 'Meine persönlichen Anpassungen und Notizen';

  @override
  String get setArchivePersonalHint =>
      'Lass das aus, wenn du die Datei weitergibst.';

  @override
  String get setExportStart => 'Exportieren';

  @override
  String get exportMenu => 'Exportieren …';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportFormatChordPro => 'ChordPro-Datei';

  @override
  String get exportFormatChordProHint =>
      'Für andere Apps, ohne Anhänge und Arrangements';

  @override
  String get exportFormatSetListPdf => 'Set-Liste als PDF';

  @override
  String get exportFormatSetListPdfHint => 'Zum Ausdrucken';

  @override
  String get exportFormatArchive => 'setDING-Archiv (ZIP)';

  @override
  String get exportFormatArchiveHint =>
      'Zum Importieren in setDING, wahlweise mit Anhängen und Arrangements';

  @override
  String get songExportHintChordPro =>
      'Die ChordPro-Datei enthält Text und Akkorde des Songs und lässt sich in jeder App öffnen, die ChordPro kennt.';

  @override
  String get setExportHintPdf =>
      'Die Set-Liste zeigt jeden Song mit Tonart und Ablauf, zum Ausdrucken für die Bühne.';

  @override
  String get setImport => 'Set importieren';

  @override
  String get setImportTitle => 'Set importieren';

  @override
  String get setImportBand => 'Band';

  @override
  String get setImportNoBand =>
      'In dieser Bibliothek gibt es keine Band, deren Sets du verwalten darfst.';

  @override
  String setImportExisting(String name) {
    return 'Die Band hat dieses Set schon als «$name».';
  }

  @override
  String get setImportReplace => 'Ersetzen';

  @override
  String get setImportCopy => 'Als Kopie hinzufügen';

  @override
  String setImportOverwriteArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return 'Band-Arrangements von $_temp0 überschreiben';
  }

  @override
  String get setImportDone => 'Set importiert';

  @override
  String get setImportReplaced => 'Das bestehende Set wurde ersetzt.';

  @override
  String setImportResultArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Band-Arrangements gespeichert',
      one: '1 Band-Arrangement gespeichert',
    );
    return '$_temp0';
  }

  @override
  String get setImportResultMissing =>
      'Nicht in der Bibliothek, im Set als Text:';

  @override
  String get setImportOpen => 'Set öffnen';

  @override
  String setImportMissingNote(String title) {
    return 'Fehlt: $title';
  }

  @override
  String get setArchiveInvalid => 'Diese Datei ist kein exportiertes Set.';

  @override
  String get setArchiveNewer =>
      'Dieses Set wurde mit einer neueren Version von setDING exportiert. Aktualisiere die App, um es zu importieren.';

  @override
  String setImportFrom(String band, int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs Songs',
      one: '1 Song',
      zero: 'keine Songs',
    );
    return 'von $band · $_temp0';
  }

  @override
  String get setImportHeadingTarget => 'Ziel';

  @override
  String get setImportHeadingExisting => 'Set schon vorhanden';

  @override
  String get setImportHeadingSongs => 'Songs';

  @override
  String get setImportHeadingInclude => 'Übernehmen';

  @override
  String get setExportHeadingInclude => 'Ins Archiv';

  @override
  String setImportNewName(String name) {
    return 'Wird angelegt als «$name».';
  }

  @override
  String setImportSongsHere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count schon hier mit gleichem Text',
      one: '1 schon hier mit gleichem Text',
    );
    return '$_temp0';
  }

  @override
  String setImportSongsNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neu, kommen in die Bibliothek',
      one: '1 neu, kommt in die Bibliothek',
    );
    return '$_temp0';
  }

  @override
  String setImportSongsDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hier mit anderem Text',
      one: '1 hier mit anderem Text',
    );
    return '$_temp0';
  }

  @override
  String setImportSongsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count nicht in der Bibliothek – du darfst keine Songs hinzufügen, sie werden Text im Set',
      one: '1 nicht in der Bibliothek – du darfst keine Songs hinzufügen, es wird Text im Set',
    );
    return '$_temp0';
  }

  @override
  String get setImportKeep => 'Bestehende behalten';

  @override
  String get setImportAddAll => 'Zusätzlich importieren';

  @override
  String setImportCopyName(String name) {
    return '$name (Kopie)';
  }

  @override
  String setImportCopyNameNumbered(String name, int number) {
    return '$name (Kopie $number)';
  }

  @override
  String get keyboardShortcuts => 'Tastenkürzel';

  @override
  String get shortcutsEverywhere => 'Überall';

  @override
  String get shortcutsSong => 'Song';

  @override
  String get shortcutsSet => 'Set';

  @override
  String get shortcutsSongList => 'Songliste';

  @override
  String get shortcutsLive => 'Live-Modus';

  @override
  String get shortcutBack => 'Zurück';

  @override
  String get shortcutHelp => 'Tastenkürzel anzeigen';

  @override
  String get shortcutEditSong => 'Song bearbeiten';

  @override
  String get shortcutEditSet => 'Set bearbeiten';

  @override
  String get shortcutLive => 'Live-Modus starten';

  @override
  String get shortcutTranspose => 'Höher / tiefer transponieren';

  @override
  String get shortcutPreviousNextSong => 'Vorheriger / nächster Song des Sets';

  @override
  String get shortcutSearch => 'Songs durchsuchen';

  @override
  String get shortcutNextPage => 'Nächste Seite';

  @override
  String get shortcutPreviousPage => 'Vorherige Seite';

  @override
  String get shortcutBeat => 'Takt starten / stoppen';

  @override
  String get shortcutKeyPageDown => 'Bild ab';

  @override
  String get shortcutKeyPageUp => 'Bild auf';

  @override
  String get shortcutKeySpace => 'Leertaste';

  @override
  String get shortcutCloseSelection => 'Auswahl schliessen';

  @override
  String get settingsHeadingLanguageTheme => 'Sprache & Design';

  @override
  String get settingsHeadingEditor => 'Editor';

  @override
  String get settingsHeadingAdvanced => 'Erweitert';

  @override
  String get settingsHeadingChords => 'Akkorde';

  @override
  String get settingsHeadingContent => 'Inhalt';

  @override
  String get settingsHeadingSetNotes => 'Set & Notizen';

  @override
  String get settingsHeadingInstrument => 'Instrument & Stimme';

  @override
  String get settingsHeadingScreen => 'Bildschirm';

  @override
  String get settingsHeadingControls => 'Bedienung';

  @override
  String get settingsHeadingClick => 'Klick auf diesem Gerät';

  @override
  String get settingsHeadingStorage => 'Speicher & Sicherung';

  @override
  String get settingsHeadingHelp => 'Hilfe & Info';

  @override
  String get settingsHeadingConnection => 'Verbindung';

  @override
  String get settingsHeadingKeyboard => 'Keyboard';

  @override
  String get settingsHeadingStyle => 'Stil';

  @override
  String get settingsHeadingPrototypes => 'Prototypen';

  @override
  String songExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs exportieren',
      one: 'Song exportieren',
    );
    return '$_temp0';
  }

  @override
  String get songExportHint =>
      'Das ZIP enthält die ChordPro-Dateien und eine Beschreibung, mit der setDING die Songs wieder importiert, dazu, was du unten auswählst.';

  @override
  String songExportArrangements(String band) {
    return 'Arrangements von «$band» (Tonart, Ablauf, Tempo)';
  }

  @override
  String get songImportTitle => 'Songs importieren';

  @override
  String songImportFrom(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return 'aus $library · $_temp0';
  }

  @override
  String songImportLibrary(String name) {
    return 'In die Bibliothek «$name»';
  }

  @override
  String get songImportArrangementsBand => 'Band für die Arrangements';

  @override
  String get songImportNoBand =>
      'In dieser Bibliothek gibt es keine Band, deren Arrangements du ändern darfst.';

  @override
  String get songImportDone => 'Songs importiert';

  @override
  String get songArchiveNewer =>
      'Diese Songs wurden mit einer neueren Version von setDING exportiert. Aktualisiere die App, um sie zu importieren.';

  @override
  String archiveImportAttachmentsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge werden',
      one: '1 Anhang wird',
    );
    return '$_temp0 bei Songs ergänzt, die schon hier sind';
  }

  @override
  String archiveResultCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge',
      one: '1 Anhang',
    );
    return '$_temp0 bei vorhandenen Songs ergänzt';
  }

  @override
  String songLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'Deutsch',
      'gsw': 'Schweizerdeutsch',
      'en': 'Englisch',
      'fr': 'Französisch',
      'it': 'Italienisch',
      'es': 'Spanisch',
      'pt': 'Portugiesisch',
      'nl': 'Niederländisch',
      'other': 'Andere',
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
  String get songLanguage => 'Sprache';

  @override
  String get songLanguageMenu => 'Sprache …';

  @override
  String get allLanguages => 'Alle Sprachen';

  @override
  String get noLanguage => 'Keine Sprache';

  @override
  String get filterByLanguage => 'Nach Sprache filtern';

  @override
  String songLanguageAutomatic(String language) {
    return 'Automatisch: $language';
  }

  @override
  String get songLanguageNotDetected => 'Automatisch (nicht erkannt)';

  @override
  String get songLanguageAutomaticHint =>
      'Aus dem Liedtext erkannt; eine Wahl von Hand gilt immer.';

  @override
  String songLanguageDetectedTooltip(String language) {
    return '$language (aus dem Text erkannt)';
  }

  @override
  String songLanguageByHandTooltip(String language) {
    return '$language (von Hand gesetzt)';
  }

  @override
  String get languageVersions => 'Sprachversionen';

  @override
  String get linkLanguageVersion => 'Sprachversionen …';

  @override
  String get unlinkLanguageVersion => 'Aus den Sprachversionen lösen';

  @override
  String get languageVersionPickerEmpty =>
      'Keine weiteren Songs, die du verknüpfen darfst';

  @override
  String languageVersionsOf(String title) {
    return 'Sprachversionen für $title';
  }

  @override
  String languageVersionsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verknüpfte Versionen ($count)',
      zero: 'Verknüpfte Versionen',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionsChosenEmpty =>
      'Noch keine anderen Versionen. Wähle Songs aus der Bibliothek.';

  @override
  String get languageVersionsSaved => 'Sprachversionen gespeichert';

  @override
  String languageVersionsNotAllowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Songs wurden nicht verknüpft: Du darfst ihre anderen Versionen nicht ändern.',
      one: 'Ein Song wurde nicht verknüpft: Du darfst seine anderen Versionen nicht ändern.',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionUnlinked => 'Aus den Sprachversionen gelöst';

  @override
  String otherLanguageVersionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Sprachversionen',
      one: 'Eine weitere Sprachversion',
    );
    return '$_temp0';
  }

  @override
  String get switchLanguageVersion => 'Sprachversion wechseln …';

  @override
  String switchedLanguageVersion(String version) {
    return 'Gewechselt zu: $version';
  }

  @override
  String switchedLanguageVersionKey(
    String version,
    String newKey,
    String oldKey,
  ) {
    return 'Gewechselt zu: $version, im Set in $newKey statt $oldKey';
  }

  @override
  String get switchedLanguageVersionSequence =>
      'Die eigene Reihenfolge des Sets passt nicht zur neuen Version und wurde entfernt.';

  @override
  String languageVersionInSet(String title, String key) {
    return '$title · im Set in $key';
  }

  @override
  String get switchLanguageVersionTitle => 'Sprachversion wechseln';

  @override
  String adjustmentOfferOne(String version, String what) {
    return 'Deine Anpassungen in «$version»: $what. Für diese Version übernehmen?';
  }

  @override
  String get adjustmentOfferMany =>
      'Andere Sprachversionen haben deine Anpassungen. Für diese Version übernehmen?';

  @override
  String get adjustmentKindTranspose => 'Tonart';

  @override
  String get adjustmentKindCapo => 'Capo';

  @override
  String get adjustmentKindMidi => 'Keyboard-Programm';

  @override
  String get adjustmentKindClick => 'Click';

  @override
  String get adjustmentOfferCopy => 'Übernehmen';

  @override
  String get adjustmentOfferDismiss => 'Nein danke';

  @override
  String get adjustmentOfferPick => 'Anpassungen übernehmen von';

  @override
  String adjustmentsCopied(String version) {
    return 'Anpassungen von «$version» übernommen';
  }

  @override
  String get autoBackup => 'Automatische Sicherung';

  @override
  String get autoBackupHint =>
      'Speichert die Bibliothek «Auf diesem Gerät» in einen Ordner deiner Wahl, höchstens einmal täglich nach Änderungen. Wähle einen Ordner in deinem Cloud-Speicher, damit sie auch sicher ist, wenn das Gerät verloren geht.';

  @override
  String get autoBackupFolder => 'Ordner';

  @override
  String get autoBackupFolderNone => 'Kein Ordner gewählt';

  @override
  String get autoBackupChooseFolder => 'Ordner wählen';

  @override
  String get autoBackupDevice => 'Gerätename';

  @override
  String get autoBackupDeviceHint =>
      'Teil der Dateinamen, damit mehrere Geräte denselben Ordner nutzen können.';

  @override
  String get autoBackupDeviceTitle => 'Gerätename für Sicherungen';

  @override
  String get autoBackupKeep => 'Aufbewahrte Sicherungen';

  @override
  String get autoBackupKeepHint =>
      'Ältere automatische Sicherungen dieses Geräts werden aus dem Ordner gelöscht.';

  @override
  String get autoBackupNow => 'Jetzt sichern';

  @override
  String get autoBackupRunning => 'Wird gesichert …';

  @override
  String get autoBackupNever => 'Noch keine automatische Sicherung.';

  @override
  String autoBackupLast(String date) {
    return 'Letzte automatische Sicherung: $date';
  }

  @override
  String autoBackupFailed(String date, String reason) {
    return 'Fehlgeschlagen am $date: $reason';
  }

  @override
  String get autoBackupErrorUnavailable => 'Der Ordner ist nicht erreichbar.';

  @override
  String get autoBackupErrorPermission =>
      'setDING darf nicht mehr in den Ordner schreiben. Wähle ihn erneut.';

  @override
  String get autoBackupErrorFailed =>
      'Die Sicherung konnte nicht geschrieben werden.';

  @override
  String autoBackupHintFailed(String reason) {
    return 'Automatische Sicherung fehlgeschlagen: $reason';
  }

  @override
  String autoBackupSaved(String file) {
    return 'Gespeichert als «$file»';
  }
}
