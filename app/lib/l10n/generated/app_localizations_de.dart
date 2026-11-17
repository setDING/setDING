// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'RealChord';

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
  String get fitToPage => 'An Seite anpassen';

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
  String get liveWebNotice =>
      'Im Browser nicht offline-sicher – auf der Bühne die App verwenden';

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
  String get settingsSectionLive => 'Live-Modus';

  @override
  String get settingsSectionStorage => 'Speicher & Info';

  @override
  String get settingsSectionMusician => 'Musiker';

  @override
  String get settingsCategoryAccountHint =>
      'Anmeldung, Bands, Server und Synchronisation';

  @override
  String get settingsCategoryGeneralHint => 'Sprache und Design';

  @override
  String get settingsCategoryMusicianHint =>
      'Instrument, Name oder Stimme, Akkorddiagramme';

  @override
  String get settingsCategoryDisplayHint =>
      'Akkord-Notation, Nashville-Zahlen, Inhalt, Schriftgrösse';

  @override
  String get settingsCategoryLiveHint =>
      'An Bildschirm anpassen, Spalten, Refrain, Blättern';

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
  String get settingsPageTurnHint =>
      'Tippe links oder rechts auf den Bildschirm, um zurück oder weiter zu blättern.';

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
      'RealChord läuft lokal auf diesem Gerät. Alle Daten sind offline verfügbar.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

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

  @override
  String get sequenceEmpty =>
      'Tippe unten auf die Teile, um den Ablauf zusammenzustellen.';

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
  String get exportSetList => 'Set-Liste exportieren (Text)';

  @override
  String get copySetList => 'Set-Liste kopieren';

  @override
  String get setListCopied => 'Set-Liste kopiert';

  @override
  String get exportSetListPdf => 'Set-Liste exportieren (PDF zum Drucken)';

  @override
  String get settingsSectionAccount => 'Konto & Synchronisation';

  @override
  String get accountSignedOut => 'Nicht angemeldet';

  @override
  String get accountSignedOutHint =>
      'Melde dich an, um Songs und Sets mit deiner Band zu teilen. Ohne Konto funktioniert RealChord weiterhin lokal auf diesem Gerät.';

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
  String get settingsServer => 'Server';

  @override
  String get settingsServerHint =>
      'Nur für Tests ändern. Beim Wechsel wirst du abgemeldet.';

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
  String get bandMembersCanEdit => 'Mitglieder dürfen Songs bearbeiten';

  @override
  String get bandMembersCanEditHint =>
      'Songs erstellen, importieren und bearbeiten. Löschen und Sets bleiben den Admins vorbehalten.';

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
    return 'Teile den Link, z. B. im Gruppenchat, oder lass den QR-Code scannen. Gültig bis $date. Der Link wird nur jetzt angezeigt.';
  }

  @override
  String get inviteCopy => 'Link kopieren';

  @override
  String get inviteCopied => 'Link kopiert';

  @override
  String get invitesTitle => 'Einladungslinks';

  @override
  String inviteStatusValid(String date) {
    return 'Gültig bis $date';
  }

  @override
  String get inviteStatusExpired => 'Abgelaufen';

  @override
  String get inviteStatusRevoked => 'Widerrufen';

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
      'Für eine Einladung wende dich an einen Admin der Organisation.';

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
  String moreProblems(int count) {
    return '… und $count weitere.';
  }

  @override
  String get saveAnyway => 'Trotzdem speichern';

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
  String get songDetailsTooltip => 'Titel, Tonart, Tempo und mehr bearbeiten';

  @override
  String get noKey => 'Keine Tonart';

  @override
  String get timeHint => 'z. B. 4/4';
}
