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
  String get notes => 'Notizen';

  @override
  String get notesHint => 'Persönliche Notiz zu diesem Song';

  @override
  String get editSource => 'ChordPro bearbeiten';

  @override
  String get attachments => 'PDF-Anhänge';

  @override
  String get addAttachment => 'PDF hinzufügen';

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
}
