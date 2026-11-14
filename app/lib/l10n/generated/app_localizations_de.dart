// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'BandChords';

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
  String get newSong => 'Neuer Song';

  @override
  String get newPdfSong => 'Neuer PDF-Song';

  @override
  String get importFiles => 'Dateien importieren';

  @override
  String get importTitle => 'ChordPro-Dateien importieren';

  @override
  String get importDescription =>
      'Unterstützt werden .cho, .chordpro, .chopro, .crd, .pro, .txt und ZIP-Archive mit solchen Dateien.';

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
  String get keyPickerTooltip => 'Tonart wählen';

  @override
  String get keyOriginal => 'Original';

  @override
  String get capo => 'Kapo';

  @override
  String capoValue(int fret) {
    return 'Kapo $fret';
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
  String get notes => 'Notizen';

  @override
  String get notesHint => 'Persönliche Notiz zu diesem Song';

  @override
  String get editSource => 'ChordPro bearbeiten';

  @override
  String get attachments => 'Anhänge';

  @override
  String get addAttachment => 'Datei anhängen';

  @override
  String get attachmentTooLarge =>
      'Die Datei ist grösser als 20 MB und kann nicht angehängt werden.';

  @override
  String get attachmentName => 'Name des Anhangs';

  @override
  String get deleteAttachmentTitle => 'Anhang löschen?';

  @override
  String deleteAttachmentMessage(String name) {
    return '«$name» wird gelöscht.';
  }

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
  String get playLive => 'Live spielen';

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
  String get resetAdjustments => 'Persönliche Anpassungen zurücksetzen';

  @override
  String get personalAdjustments => 'Persönliche Anpassungen';

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
    return 'Tonart $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForNashville =>
      'Für Nashville-Nummern braucht der Song eine Tonart.';

  @override
  String get editorTitleNew => 'Neuer Song';

  @override
  String get editorTitleEdit => 'Song bearbeiten';

  @override
  String get editorTab => 'Text';

  @override
  String get previewTab => 'Vorschau';

  @override
  String get insertVerse => 'Strophe einfügen';

  @override
  String get insertChorus => 'Refrain einfügen';

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
  String get sectionVerse => 'Strophe';

  @override
  String get sectionChorus => 'Refrain';

  @override
  String get sectionBridge => 'Bridge';

  @override
  String get sectionTab => 'Tab';

  @override
  String get sectionGrid => 'Raster';

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
  String get offlineReady => 'Offline bereit';

  @override
  String get notOfflineReady => 'Nicht offline bereit';

  @override
  String get addSongs => 'Songs hinzufügen';

  @override
  String get addPause => 'Pause hinzufügen';

  @override
  String get addText => 'Text hinzufügen';

  @override
  String get pause => 'Pause';

  @override
  String get textItem => 'Text';

  @override
  String get textItemHint => 'z. B. Ansage oder Zugabe';

  @override
  String get setEmpty => 'Dieses Set ist leer. Füge Songs hinzu.';

  @override
  String get deleteSetTitle => 'Set löschen?';

  @override
  String deleteSetMessage(String name) {
    return '«$name» wird gelöscht. Die Songs bleiben erhalten.';
  }

  @override
  String get exportSet => 'Als ZIP exportieren';

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
  String get liveEnd => 'Ende des Sets';

  @override
  String get liveSetOverview => 'Set-Übersicht';

  @override
  String get liveExit => 'Live-Modus beenden';

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'Allgemein';

  @override
  String get settingsSectionDisplay => 'Darstellung';

  @override
  String get settingsSectionLive => 'Live-Modus';

  @override
  String get settingsSectionStorage => 'Speicher';

  @override
  String get settingsSectionMusician => 'Musiker';

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
  String get settingsChorusRepeat => 'Wiederholter Refrain';

  @override
  String get settingsChorusRepeatHint =>
      'Automatisch: Ein wiederholter Refrain wird nur dann als kurzer Hinweis angezeigt, wenn der Song sonst nicht gut auf den Bildschirm passt.';

  @override
  String get chorusRepeatAuto => 'Automatisch';

  @override
  String get chorusRepeatFull => 'Ganz anzeigen';

  @override
  String get chorusRepeatLabel => 'Nur Hinweis';

  @override
  String get settingsPedalHint =>
      'Fusspedal und Tastatur: Pfeiltasten, Bild auf/ab und Leertaste blättern. Tippe links oder rechts auf den Bildschirm, um zurück oder weiter zu blättern.';

  @override
  String settingsStorageUsed(String size) {
    return 'PDF-Anhänge belegen $size';
  }

  @override
  String get settingsAbout =>
      'BandChords läuft lokal auf diesem Gerät. Alle Daten sind offline verfügbar.';

  @override
  String get lilypondNotice =>
      'Lilypond-Noten können auf diesem Gerät nicht dargestellt werden. Quelltext:';

  @override
  String get sequenceLabel => 'Songablauf';

  @override
  String get sectionIntro => 'Intro';

  @override
  String get sectionPreChorus => 'Pre-Chorus';

  @override
  String get sectionPostChorus => 'Post-Chorus';

  @override
  String get sectionInterlude => 'Zwischenspiel';

  @override
  String get sectionInstrumental => 'Instrumental';

  @override
  String get sectionSolo => 'Solo';

  @override
  String get sectionTag => 'Tag';

  @override
  String get sectionOutro => 'Outro';

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
  String get insertGrid => 'Akkord-Raster';

  @override
  String get insertChorusRecall => 'Refrain wiederholen';

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
      'I Intro · V Strophe · PC Pre-Chorus · C Refrain · B Bridge · Int Zwischenspiel · Solo · T Tag · O Outro · C x2 = zweimal';
}
