import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'RealChord'**
  String get appTitle;

  /// No description provided for @navSets.
  ///
  /// In de, this message translates to:
  /// **'Sets'**
  String get navSets;

  /// No description provided for @navSongs.
  ///
  /// In de, this message translates to:
  /// **'Songs'**
  String get navSongs;

  /// No description provided for @navSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get navSettings;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @ok.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schliessen'**
  String get close;

  /// No description provided for @rename.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get rename;

  /// No description provided for @discard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get discard;

  /// No description provided for @untitled.
  ///
  /// In de, this message translates to:
  /// **'Ohne Titel'**
  String get untitled;

  /// No description provided for @errorGeneric.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist schiefgelaufen: {error}'**
  String errorGeneric(String error);

  /// No description provided for @songsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Songs. Erstelle einen neuen Song oder importiere ChordPro-Dateien.'**
  String get songsEmpty;

  /// No description provided for @searchSongs.
  ///
  /// In de, this message translates to:
  /// **'Songs suchen'**
  String get searchSongs;

  /// No description provided for @newSong.
  ///
  /// In de, this message translates to:
  /// **'Neuer Song'**
  String get newSong;

  /// No description provided for @newPdfSong.
  ///
  /// In de, this message translates to:
  /// **'Neuer PDF-Song'**
  String get newPdfSong;

  /// No description provided for @importFiles.
  ///
  /// In de, this message translates to:
  /// **'Dateien importieren'**
  String get importFiles;

  /// No description provided for @importTitle.
  ///
  /// In de, this message translates to:
  /// **'ChordPro-Dateien importieren'**
  String get importTitle;

  /// No description provided for @importDescription.
  ///
  /// In de, this message translates to:
  /// **'Unterstützt werden .cho, .chordpro, .chopro, .crd, .pro, .txt und ZIP-Archive mit solchen Dateien.'**
  String get importDescription;

  /// No description provided for @importGermanNotation.
  ///
  /// In de, this message translates to:
  /// **'Dateien verwenden deutsche Notation (H/B)'**
  String get importGermanNotation;

  /// No description provided for @importGermanNotationHint.
  ///
  /// In de, this message translates to:
  /// **'Akkorde werden beim Import in internationale Notation umgewandelt.'**
  String get importGermanNotationHint;

  /// No description provided for @chooseFiles.
  ///
  /// In de, this message translates to:
  /// **'Dateien auswählen'**
  String get chooseFiles;

  /// No description provided for @importResult.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Songs importiert} =1{1 Song importiert} other{{count} Songs importiert}}'**
  String importResult(int count);

  /// No description provided for @importSkipped.
  ///
  /// In de, this message translates to:
  /// **'Übersprungen: {files}'**
  String importSkipped(String files);

  /// No description provided for @deleteSongTitle.
  ///
  /// In de, this message translates to:
  /// **'Song löschen?'**
  String get deleteSongTitle;

  /// No description provided for @deleteSongMessage.
  ///
  /// In de, this message translates to:
  /// **'«{title}» wird gelöscht und aus allen Sets entfernt.'**
  String deleteSongMessage(String title);

  /// No description provided for @attachmentsTooltip.
  ///
  /// In de, this message translates to:
  /// **'Hat PDF-Anhänge'**
  String get attachmentsTooltip;

  /// No description provided for @keyPickerTooltip.
  ///
  /// In de, this message translates to:
  /// **'Tonart wählen'**
  String get keyPickerTooltip;

  /// No description provided for @keyOriginal.
  ///
  /// In de, this message translates to:
  /// **'Original'**
  String get keyOriginal;

  /// No description provided for @capo.
  ///
  /// In de, this message translates to:
  /// **'Kapo'**
  String get capo;

  /// No description provided for @capoValue.
  ///
  /// In de, this message translates to:
  /// **'Kapo {fret}'**
  String capoValue(int fret);

  /// No description provided for @capoLabel.
  ///
  /// In de, this message translates to:
  /// **'Kapo: {fret}'**
  String capoLabel(int fret);

  /// No description provided for @capoLabelWithKey.
  ///
  /// In de, this message translates to:
  /// **'Kapo: {fret} ({key})'**
  String capoLabelWithKey(int fret, String key);

  /// No description provided for @capoAsInSongLabel.
  ///
  /// In de, this message translates to:
  /// **'{capo}, wie im Song'**
  String capoAsInSongLabel(String capo);

  /// No description provided for @noCapo.
  ///
  /// In de, this message translates to:
  /// **'Ohne Kapo'**
  String get noCapo;

  /// No description provided for @capoAsInSong.
  ///
  /// In de, this message translates to:
  /// **'Kapo {fret} (wie im Song)'**
  String capoAsInSong(int fret);

  /// No description provided for @allTags.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get allTags;

  /// No description provided for @notes.
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get notes;

  /// No description provided for @notesHint.
  ///
  /// In de, this message translates to:
  /// **'Persönliche Notiz zu diesem Song'**
  String get notesHint;

  /// No description provided for @editSource.
  ///
  /// In de, this message translates to:
  /// **'ChordPro bearbeiten'**
  String get editSource;

  /// No description provided for @attachments.
  ///
  /// In de, this message translates to:
  /// **'Anhänge'**
  String get attachments;

  /// No description provided for @addAttachment.
  ///
  /// In de, this message translates to:
  /// **'Datei anhängen'**
  String get addAttachment;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist grösser als 20 MB und kann nicht angehängt werden.'**
  String get attachmentTooLarge;

  /// No description provided for @attachmentName.
  ///
  /// In de, this message translates to:
  /// **'Name des Anhangs'**
  String get attachmentName;

  /// No description provided for @deleteAttachmentTitle.
  ///
  /// In de, this message translates to:
  /// **'Anhang löschen?'**
  String get deleteAttachmentTitle;

  /// No description provided for @deleteAttachmentMessage.
  ///
  /// In de, this message translates to:
  /// **'«{name}» wird gelöscht.'**
  String deleteAttachmentMessage(String name);

  /// No description provided for @pagesCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Seite} other{{count} Seiten}}'**
  String pagesCount(int count);

  /// No description provided for @liveView.
  ///
  /// In de, this message translates to:
  /// **'Im Live-Modus anzeigen'**
  String get liveView;

  /// No description provided for @liveViewChordPro.
  ///
  /// In de, this message translates to:
  /// **'ChordPro-Text'**
  String get liveViewChordPro;

  /// No description provided for @exportSong.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get exportSong;

  /// No description provided for @exported.
  ///
  /// In de, this message translates to:
  /// **'Exportiert'**
  String get exported;

  /// No description provided for @playLive.
  ///
  /// In de, this message translates to:
  /// **'Live spielen'**
  String get playLive;

  /// No description provided for @nashville.
  ///
  /// In de, this message translates to:
  /// **'Nashville-Nummern'**
  String get nashville;

  /// No description provided for @useDeviceSetting.
  ///
  /// In de, this message translates to:
  /// **'Wie in den Einstellungen'**
  String get useDeviceSetting;

  /// No description provided for @on.
  ///
  /// In de, this message translates to:
  /// **'Ein'**
  String get on;

  /// No description provided for @off.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get off;

  /// No description provided for @fontLarger.
  ///
  /// In de, this message translates to:
  /// **'Schrift grösser'**
  String get fontLarger;

  /// No description provided for @fontSmaller.
  ///
  /// In de, this message translates to:
  /// **'Schrift kleiner'**
  String get fontSmaller;

  /// No description provided for @fitToPage.
  ///
  /// In de, this message translates to:
  /// **'An Seite anpassen'**
  String get fitToPage;

  /// No description provided for @resetAdjustments.
  ///
  /// In de, this message translates to:
  /// **'Persönliche Anpassungen zurücksetzen'**
  String get resetAdjustments;

  /// No description provided for @personalAdjustments.
  ///
  /// In de, this message translates to:
  /// **'Persönliche Anpassungen'**
  String get personalAdjustments;

  /// No description provided for @editTitle.
  ///
  /// In de, this message translates to:
  /// **'Titel bearbeiten'**
  String get editTitle;

  /// No description provided for @title.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get title;

  /// No description provided for @artist.
  ///
  /// In de, this message translates to:
  /// **'Interpret'**
  String get artist;

  /// No description provided for @noContent.
  ///
  /// In de, this message translates to:
  /// **'Dieser Song hat noch keinen ChordPro-Text.'**
  String get noContent;

  /// No description provided for @addChordPro.
  ///
  /// In de, this message translates to:
  /// **'ChordPro-Text erfassen'**
  String get addChordPro;

  /// No description provided for @keyLabel.
  ///
  /// In de, this message translates to:
  /// **'Tonart: {key}'**
  String keyLabel(String key);

  /// No description provided for @bpm.
  ///
  /// In de, this message translates to:
  /// **'{tempo} BPM'**
  String bpm(int tempo);

  /// No description provided for @noKeyForNashville.
  ///
  /// In de, this message translates to:
  /// **'Für Nashville-Nummern braucht der Song eine Tonart.'**
  String get noKeyForNashville;

  /// No description provided for @editorTitleNew.
  ///
  /// In de, this message translates to:
  /// **'Neuer Song'**
  String get editorTitleNew;

  /// No description provided for @editorTitleEdit.
  ///
  /// In de, this message translates to:
  /// **'Song bearbeiten'**
  String get editorTitleEdit;

  /// No description provided for @editorTab.
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get editorTab;

  /// No description provided for @previewTab.
  ///
  /// In de, this message translates to:
  /// **'Vorschau'**
  String get previewTab;

  /// No description provided for @insertVerse.
  ///
  /// In de, this message translates to:
  /// **'Strophe einfügen'**
  String get insertVerse;

  /// No description provided for @insertChorus.
  ///
  /// In de, this message translates to:
  /// **'Refrain einfügen'**
  String get insertChorus;

  /// No description provided for @insertBridge.
  ///
  /// In de, this message translates to:
  /// **'Bridge einfügen'**
  String get insertBridge;

  /// No description provided for @insertComment.
  ///
  /// In de, this message translates to:
  /// **'Kommentar einfügen'**
  String get insertComment;

  /// No description provided for @insertChord.
  ///
  /// In de, this message translates to:
  /// **'Akkord einfügen'**
  String get insertChord;

  /// No description provided for @discardChangesTitle.
  ///
  /// In de, this message translates to:
  /// **'Änderungen verwerfen?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In de, this message translates to:
  /// **'Deine Änderungen wurden noch nicht gespeichert.'**
  String get discardChangesMessage;

  /// No description provided for @sectionVerse.
  ///
  /// In de, this message translates to:
  /// **'Strophe'**
  String get sectionVerse;

  /// No description provided for @sectionChorus.
  ///
  /// In de, this message translates to:
  /// **'Refrain'**
  String get sectionChorus;

  /// No description provided for @sectionBridge.
  ///
  /// In de, this message translates to:
  /// **'Bridge'**
  String get sectionBridge;

  /// No description provided for @sectionTab.
  ///
  /// In de, this message translates to:
  /// **'Tab'**
  String get sectionTab;

  /// No description provided for @sectionGrid.
  ///
  /// In de, this message translates to:
  /// **'Raster'**
  String get sectionGrid;

  /// No description provided for @setsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Sets. Erstelle ein Set für deinen nächsten Auftritt.'**
  String get setsEmpty;

  /// No description provided for @newSet.
  ///
  /// In de, this message translates to:
  /// **'Neues Set'**
  String get newSet;

  /// No description provided for @editSet.
  ///
  /// In de, this message translates to:
  /// **'Set bearbeiten'**
  String get editSet;

  /// No description provided for @setName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get setName;

  /// No description provided for @gigDate.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get gigDate;

  /// No description provided for @venue.
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get venue;

  /// No description provided for @noDate.
  ///
  /// In de, this message translates to:
  /// **'Kein Datum'**
  String get noDate;

  /// No description provided for @pickDate.
  ///
  /// In de, this message translates to:
  /// **'Datum wählen'**
  String get pickDate;

  /// No description provided for @clearDate.
  ///
  /// In de, this message translates to:
  /// **'Datum entfernen'**
  String get clearDate;

  /// No description provided for @itemCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Leer} =1{1 Eintrag} other{{count} Einträge}}'**
  String itemCount(int count);

  /// No description provided for @offlineReady.
  ///
  /// In de, this message translates to:
  /// **'Offline bereit'**
  String get offlineReady;

  /// No description provided for @notOfflineReady.
  ///
  /// In de, this message translates to:
  /// **'Nicht offline bereit'**
  String get notOfflineReady;

  /// No description provided for @addSongs.
  ///
  /// In de, this message translates to:
  /// **'Songs hinzufügen'**
  String get addSongs;

  /// No description provided for @addPause.
  ///
  /// In de, this message translates to:
  /// **'Pause hinzufügen'**
  String get addPause;

  /// No description provided for @addText.
  ///
  /// In de, this message translates to:
  /// **'Text hinzufügen'**
  String get addText;

  /// No description provided for @pause.
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @textItem.
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get textItem;

  /// No description provided for @textItemHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Ansage oder Zugabe'**
  String get textItemHint;

  /// No description provided for @setEmpty.
  ///
  /// In de, this message translates to:
  /// **'Dieses Set ist leer. Füge Songs hinzu.'**
  String get setEmpty;

  /// No description provided for @deleteSetTitle.
  ///
  /// In de, this message translates to:
  /// **'Set löschen?'**
  String get deleteSetTitle;

  /// No description provided for @deleteSetMessage.
  ///
  /// In de, this message translates to:
  /// **'«{name}» wird gelöscht. Die Songs bleiben erhalten.'**
  String deleteSetMessage(String name);

  /// No description provided for @exportSet.
  ///
  /// In de, this message translates to:
  /// **'Als ZIP exportieren'**
  String get exportSet;

  /// No description provided for @removeFromSet.
  ///
  /// In de, this message translates to:
  /// **'Aus dem Set entfernen'**
  String get removeFromSet;

  /// No description provided for @selectSongs.
  ///
  /// In de, this message translates to:
  /// **'Songs auswählen'**
  String get selectSongs;

  /// No description provided for @selectedCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine ausgewählt} =1{1 ausgewählt} other{{count} ausgewählt}}'**
  String selectedCount(int count);

  /// No description provided for @songMissing.
  ///
  /// In de, this message translates to:
  /// **'Song nicht mehr vorhanden'**
  String get songMissing;

  /// No description provided for @liveNext.
  ///
  /// In de, this message translates to:
  /// **'Nächster: {title}'**
  String liveNext(String title);

  /// No description provided for @liveWebNotice.
  ///
  /// In de, this message translates to:
  /// **'Im Browser nicht offline-sicher – auf der Bühne die App verwenden'**
  String get liveWebNotice;

  /// No description provided for @liveEnd.
  ///
  /// In de, this message translates to:
  /// **'Ende des Sets'**
  String get liveEnd;

  /// No description provided for @liveSetOverview.
  ///
  /// In de, this message translates to:
  /// **'Set-Übersicht'**
  String get liveSetOverview;

  /// No description provided for @liveExit.
  ///
  /// In de, this message translates to:
  /// **'Live-Modus beenden'**
  String get liveExit;

  /// No description provided for @liveChordNames.
  ///
  /// In de, this message translates to:
  /// **'Akkorde'**
  String get liveChordNames;

  /// No description provided for @liveNashville.
  ///
  /// In de, this message translates to:
  /// **'Nashville'**
  String get liveNashville;

  /// No description provided for @liveSongPage.
  ///
  /// In de, this message translates to:
  /// **'Seite {page}/{count}'**
  String liveSongPage(int page, int count);

  /// No description provided for @livePosition.
  ///
  /// In de, this message translates to:
  /// **'{current} / {total}'**
  String livePosition(int current, int total);

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionDisplay.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsSectionDisplay;

  /// No description provided for @settingsSectionLive.
  ///
  /// In de, this message translates to:
  /// **'Live-Modus'**
  String get settingsSectionLive;

  /// No description provided for @settingsSectionStorage.
  ///
  /// In de, this message translates to:
  /// **'Speicher & Info'**
  String get settingsSectionStorage;

  /// No description provided for @settingsSectionMusician.
  ///
  /// In de, this message translates to:
  /// **'Musiker'**
  String get settingsSectionMusician;

  /// No description provided for @settingsCategoryAccountHint.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung, Bands, Server und Synchronisation'**
  String get settingsCategoryAccountHint;

  /// No description provided for @settingsCategoryGeneralHint.
  ///
  /// In de, this message translates to:
  /// **'Sprache und Design'**
  String get settingsCategoryGeneralHint;

  /// No description provided for @settingsCategoryMusicianHint.
  ///
  /// In de, this message translates to:
  /// **'Instrument, Name oder Stimme, Akkorddiagramme'**
  String get settingsCategoryMusicianHint;

  /// No description provided for @settingsCategoryDisplayHint.
  ///
  /// In de, this message translates to:
  /// **'Akkord-Notation, Nashville-Zahlen, Inhalt, Schriftgrösse'**
  String get settingsCategoryDisplayHint;

  /// No description provided for @settingsCategoryLiveHint.
  ///
  /// In de, this message translates to:
  /// **'An Bildschirm anpassen, Spalten, Refrain, Blättern'**
  String get settingsCategoryLiveHint;

  /// No description provided for @settingsCategoryAboutHint.
  ///
  /// In de, this message translates to:
  /// **'Speicher, Diagnoseprotokoll und Version'**
  String get settingsCategoryAboutHint;

  /// No description provided for @settingsInstrument.
  ///
  /// In de, this message translates to:
  /// **'Mein Instrument'**
  String get settingsInstrument;

  /// No description provided for @settingsInstrumentHint.
  ///
  /// In de, this message translates to:
  /// **'Wird für bedingte Abschnitte (z. B. nur für Gitarre) und für Griffdiagramme verwendet.'**
  String get settingsInstrumentHint;

  /// No description provided for @instrumentGuitar.
  ///
  /// In de, this message translates to:
  /// **'Gitarre'**
  String get instrumentGuitar;

  /// No description provided for @instrumentUkulele.
  ///
  /// In de, this message translates to:
  /// **'Ukulele'**
  String get instrumentUkulele;

  /// No description provided for @instrumentBass.
  ///
  /// In de, this message translates to:
  /// **'Bass'**
  String get instrumentBass;

  /// No description provided for @instrumentKeyboard.
  ///
  /// In de, this message translates to:
  /// **'Keyboard'**
  String get instrumentKeyboard;

  /// No description provided for @instrumentVocals.
  ///
  /// In de, this message translates to:
  /// **'Gesang'**
  String get instrumentVocals;

  /// No description provided for @instrumentOther.
  ///
  /// In de, this message translates to:
  /// **'Anderes …'**
  String get instrumentOther;

  /// No description provided for @settingsUserName.
  ///
  /// In de, this message translates to:
  /// **'Mein Name oder meine Stimme'**
  String get settingsUserName;

  /// No description provided for @settingsUserNameHint.
  ///
  /// In de, this message translates to:
  /// **'Für bedingte Abschnitte, z. B. «alto» oder «tenor».'**
  String get settingsUserNameHint;

  /// No description provided for @settingsDiagrams.
  ///
  /// In de, this message translates to:
  /// **'Griffdiagramme'**
  String get settingsDiagrams;

  /// No description provided for @settingsDiagramsHint.
  ///
  /// In de, this message translates to:
  /// **'Zeigt die Griffe aller Akkorde des Songs für dein Instrument. Ein Song kann das mit der Direktive diagrams selbst festlegen.'**
  String get settingsDiagramsHint;

  /// No description provided for @diagramsOff.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get diagramsOff;

  /// No description provided for @diagramsTop.
  ///
  /// In de, this message translates to:
  /// **'Oben'**
  String get diagramsTop;

  /// No description provided for @diagramsBottom.
  ///
  /// In de, this message translates to:
  /// **'Unten'**
  String get diagramsBottom;

  /// No description provided for @notSet.
  ///
  /// In de, this message translates to:
  /// **'Nicht festgelegt'**
  String get notSet;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'Systemsprache'**
  String get languageSystem;

  /// No description provided for @languageDe.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageDe;

  /// No description provided for @languageEn.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @settingsTheme.
  ///
  /// In de, this message translates to:
  /// **'Design'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'Wie System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @settingsNotation.
  ///
  /// In de, this message translates to:
  /// **'Akkord-Notation'**
  String get settingsNotation;

  /// No description provided for @notationInternational.
  ///
  /// In de, this message translates to:
  /// **'International (B, Bb)'**
  String get notationInternational;

  /// No description provided for @notationGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch (H, B)'**
  String get notationGerman;

  /// No description provided for @settingsNashville.
  ///
  /// In de, this message translates to:
  /// **'Nashville-Nummern anzeigen'**
  String get settingsNashville;

  /// No description provided for @settingsNashvilleHint.
  ///
  /// In de, this message translates to:
  /// **'Akkorde als Stufen der Tonart, z. B. 1, 4, 5, 6m. Braucht eine Tonart im Song.'**
  String get settingsNashvilleHint;

  /// No description provided for @settingsChordStyle.
  ///
  /// In de, this message translates to:
  /// **'Akkordschreibweise'**
  String get settingsChordStyle;

  /// No description provided for @settingsChordStyleHint.
  ///
  /// In de, this message translates to:
  /// **'Wie Akkorde geschrieben werden, z. B. Am7, Cmaj7, Em7b5 (Standard) oder A−7, CΔ7, Eø7 (Jazz). Der Song selbst bleibt unverändert.'**
  String get settingsChordStyleHint;

  /// No description provided for @chordStyleAsWritten.
  ///
  /// In de, this message translates to:
  /// **'Wie geschrieben'**
  String get chordStyleAsWritten;

  /// No description provided for @chordStyleStandard.
  ///
  /// In de, this message translates to:
  /// **'Standard'**
  String get chordStyleStandard;

  /// No description provided for @chordStyleJazz.
  ///
  /// In de, this message translates to:
  /// **'Jazz'**
  String get chordStyleJazz;

  /// No description provided for @settingsChordSuperscript.
  ///
  /// In de, this message translates to:
  /// **'Erweiterungen hochstellen'**
  String get settingsChordSuperscript;

  /// No description provided for @settingsChordSuperscriptHint.
  ///
  /// In de, this message translates to:
  /// **'Erweiterungen und Alterationen klein und hochgestellt anzeigen, z. B. C⁷. Braucht die Schreibweise Standard oder Jazz.'**
  String get settingsChordSuperscriptHint;

  /// No description provided for @settingsDisplayMode.
  ///
  /// In de, this message translates to:
  /// **'Inhalt'**
  String get settingsDisplayMode;

  /// No description provided for @displayLyricsAndChords.
  ///
  /// In de, this message translates to:
  /// **'Text und Akkorde'**
  String get displayLyricsAndChords;

  /// No description provided for @displayLyricsOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur Text'**
  String get displayLyricsOnly;

  /// No description provided for @settingsFontSize.
  ///
  /// In de, this message translates to:
  /// **'Schriftgrösse'**
  String get settingsFontSize;

  /// No description provided for @settingsColumns.
  ///
  /// In de, this message translates to:
  /// **'Spalten'**
  String get settingsColumns;

  /// No description provided for @columnsAuto.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get columnsAuto;

  /// No description provided for @columnsOne.
  ///
  /// In de, this message translates to:
  /// **'Eine'**
  String get columnsOne;

  /// No description provided for @columnsTwo.
  ///
  /// In de, this message translates to:
  /// **'Zwei'**
  String get columnsTwo;

  /// No description provided for @settingsPageTurn.
  ///
  /// In de, this message translates to:
  /// **'Blättern'**
  String get settingsPageTurn;

  /// No description provided for @pageTurnFull.
  ///
  /// In de, this message translates to:
  /// **'Ganze Seite'**
  String get pageTurnFull;

  /// No description provided for @pageTurnHalf.
  ///
  /// In de, this message translates to:
  /// **'Halbe Seite'**
  String get pageTurnHalf;

  /// No description provided for @settingsAutoFit.
  ///
  /// In de, this message translates to:
  /// **'Song an den Bildschirm anpassen'**
  String get settingsAutoFit;

  /// No description provided for @settingsAutoFitHint.
  ///
  /// In de, this message translates to:
  /// **'Der ganze Song passt ohne Scrollen auf den Bildschirm. Die Abschnitte werden automatisch in Spalten angeordnet und die Schrift so gross wie möglich gewählt.'**
  String get settingsAutoFitHint;

  /// No description provided for @settingsColumnsHint.
  ///
  /// In de, this message translates to:
  /// **'Beim Anpassen an den Bildschirm die höchste erlaubte Anzahl Spalten.'**
  String get settingsColumnsHint;

  /// No description provided for @columnsThree.
  ///
  /// In de, this message translates to:
  /// **'Drei'**
  String get columnsThree;

  /// No description provided for @settingsChorusRepeat.
  ///
  /// In de, this message translates to:
  /// **'Wiederholter Refrain'**
  String get settingsChorusRepeat;

  /// No description provided for @settingsChorusRepeatHint.
  ///
  /// In de, this message translates to:
  /// **'Automatisch: Ein wiederholter Refrain wird nur dann als kurzer Hinweis angezeigt, wenn der Song sonst nicht gut auf den Bildschirm passt.'**
  String get settingsChorusRepeatHint;

  /// No description provided for @chorusRepeatAuto.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get chorusRepeatAuto;

  /// No description provided for @chorusRepeatFull.
  ///
  /// In de, this message translates to:
  /// **'Ganz anzeigen'**
  String get chorusRepeatFull;

  /// No description provided for @chorusRepeatLabel.
  ///
  /// In de, this message translates to:
  /// **'Nur Hinweis'**
  String get chorusRepeatLabel;

  /// No description provided for @settingsPageTurnHint.
  ///
  /// In de, this message translates to:
  /// **'Tippe links oder rechts auf den Bildschirm, um zurück oder weiter zu blättern.'**
  String get settingsPageTurnHint;

  /// No description provided for @settingsStorageUsed.
  ///
  /// In de, this message translates to:
  /// **'PDF-Anhänge belegen {size}'**
  String settingsStorageUsed(String size);

  /// No description provided for @settingsLogCopy.
  ///
  /// In de, this message translates to:
  /// **'Diagnoseprotokoll kopieren'**
  String get settingsLogCopy;

  /// No description provided for @settingsLogCopyHint.
  ///
  /// In de, this message translates to:
  /// **'Die letzten Meldungen der App, z. B. warum eine Synchronisation fehlschlug – zum Einfügen in eine Nachricht an den Support.'**
  String get settingsLogCopyHint;

  /// No description provided for @settingsLogCopied.
  ///
  /// In de, this message translates to:
  /// **'Diagnoseprotokoll kopiert'**
  String get settingsLogCopied;

  /// No description provided for @settingsAbout.
  ///
  /// In de, this message translates to:
  /// **'RealChord läuft lokal auf diesem Gerät. Alle Daten sind offline verfügbar.'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @lilypondNotice.
  ///
  /// In de, this message translates to:
  /// **'Lilypond-Noten können auf diesem Gerät nicht dargestellt werden. Quelltext:'**
  String get lilypondNotice;

  /// No description provided for @sequenceLabel.
  ///
  /// In de, this message translates to:
  /// **'Songablauf'**
  String get sequenceLabel;

  /// No description provided for @sectionIntro.
  ///
  /// In de, this message translates to:
  /// **'Intro'**
  String get sectionIntro;

  /// No description provided for @sectionPreChorus.
  ///
  /// In de, this message translates to:
  /// **'Pre-Chorus'**
  String get sectionPreChorus;

  /// No description provided for @sectionPostChorus.
  ///
  /// In de, this message translates to:
  /// **'Post-Chorus'**
  String get sectionPostChorus;

  /// No description provided for @sectionInterlude.
  ///
  /// In de, this message translates to:
  /// **'Zwischenspiel'**
  String get sectionInterlude;

  /// No description provided for @sectionInstrumental.
  ///
  /// In de, this message translates to:
  /// **'Instrumental'**
  String get sectionInstrumental;

  /// No description provided for @sectionSolo.
  ///
  /// In de, this message translates to:
  /// **'Solo'**
  String get sectionSolo;

  /// No description provided for @sectionTag.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get sectionTag;

  /// No description provided for @sectionOutro.
  ///
  /// In de, this message translates to:
  /// **'Outro'**
  String get sectionOutro;

  /// No description provided for @editorGroupChords.
  ///
  /// In de, this message translates to:
  /// **'Akkorde'**
  String get editorGroupChords;

  /// No description provided for @editorGroupSections.
  ///
  /// In de, this message translates to:
  /// **'Abschnitte'**
  String get editorGroupSections;

  /// No description provided for @editorGroupInfo.
  ///
  /// In de, this message translates to:
  /// **'Song-Infos'**
  String get editorGroupInfo;

  /// No description provided for @editorGroupText.
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get editorGroupText;

  /// No description provided for @editorGroupMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get editorGroupMore;

  /// No description provided for @insertOptionalChord.
  ///
  /// In de, this message translates to:
  /// **'Optionaler Akkord'**
  String get insertOptionalChord;

  /// No description provided for @insertAnnotation.
  ///
  /// In de, this message translates to:
  /// **'Anmerkung'**
  String get insertAnnotation;

  /// No description provided for @insertNoChord.
  ///
  /// In de, this message translates to:
  /// **'Kein Akkord (N.C.)'**
  String get insertNoChord;

  /// No description provided for @insertDefine.
  ///
  /// In de, this message translates to:
  /// **'Akkord-Definition'**
  String get insertDefine;

  /// No description provided for @insertChordDiagram.
  ///
  /// In de, this message translates to:
  /// **'Akkord-Diagramm'**
  String get insertChordDiagram;

  /// No description provided for @insertTranspose.
  ///
  /// In de, this message translates to:
  /// **'Transponieren'**
  String get insertTranspose;

  /// No description provided for @insertTab.
  ///
  /// In de, this message translates to:
  /// **'Tabulatur'**
  String get insertTab;

  /// No description provided for @insertGrid.
  ///
  /// In de, this message translates to:
  /// **'Akkord-Raster'**
  String get insertGrid;

  /// No description provided for @insertChorusRecall.
  ///
  /// In de, this message translates to:
  /// **'Refrain wiederholen'**
  String get insertChorusRecall;

  /// No description provided for @metaSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Untertitel'**
  String get metaSubtitle;

  /// No description provided for @metaComposer.
  ///
  /// In de, this message translates to:
  /// **'Komponist'**
  String get metaComposer;

  /// No description provided for @metaLyricist.
  ///
  /// In de, this message translates to:
  /// **'Texter'**
  String get metaLyricist;

  /// No description provided for @metaCopyright.
  ///
  /// In de, this message translates to:
  /// **'Copyright'**
  String get metaCopyright;

  /// No description provided for @metaCcli.
  ///
  /// In de, this message translates to:
  /// **'CCLI-Nummer'**
  String get metaCcli;

  /// No description provided for @metaTag.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get metaTag;

  /// No description provided for @metaYear.
  ///
  /// In de, this message translates to:
  /// **'Jahr'**
  String get metaYear;

  /// No description provided for @metaAlbum.
  ///
  /// In de, this message translates to:
  /// **'Album'**
  String get metaAlbum;

  /// No description provided for @metaDuration.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get metaDuration;

  /// No description provided for @metaTempo.
  ///
  /// In de, this message translates to:
  /// **'Tempo (BPM)'**
  String get metaTempo;

  /// No description provided for @metaTime.
  ///
  /// In de, this message translates to:
  /// **'Taktart'**
  String get metaTime;

  /// No description provided for @metaKey.
  ///
  /// In de, this message translates to:
  /// **'Tonart'**
  String get metaKey;

  /// No description provided for @insertCommentItalic.
  ///
  /// In de, this message translates to:
  /// **'Kommentar (kursiv)'**
  String get insertCommentItalic;

  /// No description provided for @insertCommentBox.
  ///
  /// In de, this message translates to:
  /// **'Kommentar (Rahmen)'**
  String get insertCommentBox;

  /// No description provided for @insertHighlight.
  ///
  /// In de, this message translates to:
  /// **'Hervorhebung'**
  String get insertHighlight;

  /// No description provided for @insertBold.
  ///
  /// In de, this message translates to:
  /// **'Fett'**
  String get insertBold;

  /// No description provided for @insertItalic.
  ///
  /// In de, this message translates to:
  /// **'Kursiv'**
  String get insertItalic;

  /// No description provided for @insertUnderline.
  ///
  /// In de, this message translates to:
  /// **'Unterstrichen'**
  String get insertUnderline;

  /// No description provided for @insertColour.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get insertColour;

  /// No description provided for @insertColumnBreak.
  ///
  /// In de, this message translates to:
  /// **'Spaltenumbruch'**
  String get insertColumnBreak;

  /// No description provided for @insertNewPage.
  ///
  /// In de, this message translates to:
  /// **'Seitenumbruch'**
  String get insertNewPage;

  /// No description provided for @insertColumns.
  ///
  /// In de, this message translates to:
  /// **'Spalten'**
  String get insertColumns;

  /// No description provided for @insertImage.
  ///
  /// In de, this message translates to:
  /// **'Bild'**
  String get insertImage;

  /// No description provided for @insertAbc.
  ///
  /// In de, this message translates to:
  /// **'ABC-Notation'**
  String get insertAbc;

  /// No description provided for @insertTextblock.
  ///
  /// In de, this message translates to:
  /// **'Textblock'**
  String get insertTextblock;

  /// No description provided for @insertNewSong.
  ///
  /// In de, this message translates to:
  /// **'Nächster Song in derselben Datei'**
  String get insertNewSong;

  /// No description provided for @sequenceEdit.
  ///
  /// In de, this message translates to:
  /// **'Songablauf für dieses Set'**
  String get sequenceEdit;

  /// No description provided for @sequenceFromSet.
  ///
  /// In de, this message translates to:
  /// **'Ablauf für dieses Set angepasst'**
  String get sequenceFromSet;

  /// No description provided for @sequenceOriginal.
  ///
  /// In de, this message translates to:
  /// **'Im Song: {sequence}'**
  String sequenceOriginal(Object sequence);

  /// No description provided for @sequenceNoneInSong.
  ///
  /// In de, this message translates to:
  /// **'Der Song hat keinen Ablauf.'**
  String get sequenceNoneInSong;

  /// No description provided for @sequenceRestore.
  ///
  /// In de, this message translates to:
  /// **'Ablauf des Songs verwenden'**
  String get sequenceRestore;

  /// No description provided for @sequenceHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. I, V1, C, V2, PC, C x2, B, O'**
  String get sequenceHint;

  /// No description provided for @sequenceAbbreviations.
  ///
  /// In de, this message translates to:
  /// **'I Intro · V Strophe · PC Pre-Chorus · C Refrain · B Bridge · Int Zwischenspiel · Solo · T Tag · O Outro · C x2 = zweimal'**
  String get sequenceAbbreviations;

  /// No description provided for @sequenceEmpty.
  ///
  /// In de, this message translates to:
  /// **'Tippe unten auf die Teile, um den Ablauf zusammenzustellen.'**
  String get sequenceEmpty;

  /// No description provided for @sequenceSongParts.
  ///
  /// In de, this message translates to:
  /// **'Teile des Songs'**
  String get sequenceSongParts;

  /// No description provided for @sequenceCommonParts.
  ///
  /// In de, this message translates to:
  /// **'Übliche Teile (der Song hat noch keine Abschnitte)'**
  String get sequenceCommonParts;

  /// No description provided for @sequenceClear.
  ///
  /// In de, this message translates to:
  /// **'Leeren'**
  String get sequenceClear;

  /// No description provided for @sequenceAsText.
  ///
  /// In de, this message translates to:
  /// **'Als Text bearbeiten'**
  String get sequenceAsText;

  /// No description provided for @exportSetList.
  ///
  /// In de, this message translates to:
  /// **'Set-Liste exportieren (Text)'**
  String get exportSetList;

  /// No description provided for @copySetList.
  ///
  /// In de, this message translates to:
  /// **'Set-Liste kopieren'**
  String get copySetList;

  /// No description provided for @setListCopied.
  ///
  /// In de, this message translates to:
  /// **'Set-Liste kopiert'**
  String get setListCopied;

  /// No description provided for @exportSetListPdf.
  ///
  /// In de, this message translates to:
  /// **'Set-Liste exportieren (PDF zum Drucken)'**
  String get exportSetListPdf;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto & Synchronisation'**
  String get settingsSectionAccount;

  /// No description provided for @accountSignedOut.
  ///
  /// In de, this message translates to:
  /// **'Nicht angemeldet'**
  String get accountSignedOut;

  /// No description provided for @accountSignedOutHint.
  ///
  /// In de, this message translates to:
  /// **'Melde dich an, um Songs und Sets mit deiner Band zu teilen. Ohne Konto funktioniert RealChord weiterhin lokal auf diesem Gerät.'**
  String get accountSignedOutHint;

  /// No description provided for @accountSignIn.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get accountSignIn;

  /// No description provided for @accountSignUp.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get accountSignUp;

  /// No description provided for @accountJoin.
  ///
  /// In de, this message translates to:
  /// **'Mit Einladung beitreten'**
  String get accountJoin;

  /// No description provided for @accountSignOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get accountSignOut;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In de, this message translates to:
  /// **'Abmelden?'**
  String get accountSignOutTitle;

  /// No description provided for @accountSignOutMessage.
  ///
  /// In de, this message translates to:
  /// **'Songs und Sets auf diesem Gerät bleiben erhalten.'**
  String get accountSignOutMessage;

  /// No description provided for @accountSignOutMessageWeb.
  ///
  /// In de, this message translates to:
  /// **'Die Daten in diesem Browser werden gelöscht. Songs und Sets bleiben auf dem Server.'**
  String get accountSignOutMessageWeb;

  /// No description provided for @accountEmail.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get accountEmail;

  /// No description provided for @accountPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get accountPassword;

  /// No description provided for @accountPasswordConfirm.
  ///
  /// In de, this message translates to:
  /// **'Passwort bestätigen'**
  String get accountPasswordConfirm;

  /// No description provided for @accountKeepSignedIn.
  ///
  /// In de, this message translates to:
  /// **'Angemeldet bleiben'**
  String get accountKeepSignedIn;

  /// No description provided for @accountKeepSignedInHint.
  ///
  /// In de, this message translates to:
  /// **'Nur auf deinem eigenen Gerät. Sonst endet die Anmeldung, wenn du den Browser schliesst.'**
  String get accountKeepSignedInHint;

  /// No description provided for @accountName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In de, this message translates to:
  /// **'So sehen dich deine Bandmitglieder.'**
  String get accountNameHint;

  /// No description provided for @accountToSignUp.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Konto? Konto erstellen'**
  String get accountToSignUp;

  /// No description provided for @accountToSignIn.
  ///
  /// In de, this message translates to:
  /// **'Bereits ein Konto? Anmelden'**
  String get accountToSignIn;

  /// No description provided for @accountForgotPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort vergessen?'**
  String get accountForgotPassword;

  /// No description provided for @accountResetTitle.
  ///
  /// In de, this message translates to:
  /// **'Passwort zurücksetzen'**
  String get accountResetTitle;

  /// No description provided for @accountResetSent.
  ///
  /// In de, this message translates to:
  /// **'Falls es ein Konto mit dieser Adresse gibt, wurde eine E-Mail zum Zurücksetzen gesendet.'**
  String get accountResetSent;

  /// No description provided for @accountFieldRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte ausfüllen.'**
  String get accountFieldRequired;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In de, this message translates to:
  /// **'Mindestens {min} Zeichen.'**
  String accountPasswordTooShort(int min);

  /// No description provided for @accountPasswordMismatch.
  ///
  /// In de, this message translates to:
  /// **'Die Passwörter stimmen nicht überein.'**
  String get accountPasswordMismatch;

  /// No description provided for @accountErrorNetwork.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung zum Server. Prüfe die Internetverbindung.'**
  String get accountErrorNetwork;

  /// No description provided for @accountErrorInvalidCredentials.
  ///
  /// In de, this message translates to:
  /// **'E-Mail oder Passwort ist falsch.'**
  String get accountErrorInvalidCredentials;

  /// No description provided for @accountErrorEmailTaken.
  ///
  /// In de, this message translates to:
  /// **'Mit dieser E-Mail-Adresse gibt es bereits ein Konto.'**
  String get accountErrorEmailTaken;

  /// No description provided for @accountErrorInvalidEmail.
  ///
  /// In de, this message translates to:
  /// **'Die E-Mail-Adresse ist ungültig.'**
  String get accountErrorInvalidEmail;

  /// No description provided for @accountErrorWeakPassword.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort erfüllt die Anforderungen des Servers nicht.'**
  String get accountErrorWeakPassword;

  /// No description provided for @accountErrorServer.
  ///
  /// In de, this message translates to:
  /// **'Der Server hat einen Fehler gemeldet. Versuche es später nochmals.'**
  String get accountErrorServer;

  /// No description provided for @settingsServer.
  ///
  /// In de, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsServerHint.
  ///
  /// In de, this message translates to:
  /// **'Nur für Tests ändern. Beim Wechsel wirst du abgemeldet.'**
  String get settingsServerHint;

  /// No description provided for @settingsServerInvalid.
  ///
  /// In de, this message translates to:
  /// **'Die Adresse muss mit http:// oder https:// beginnen.'**
  String get settingsServerInvalid;

  /// No description provided for @bandLocal.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Gerät'**
  String get bandLocal;

  /// No description provided for @bandLocalHint.
  ///
  /// In de, this message translates to:
  /// **'Nur auf diesem Gerät, wird nicht synchronisiert.'**
  String get bandLocalHint;

  /// No description provided for @bandSwitch.
  ///
  /// In de, this message translates to:
  /// **'Band wechseln'**
  String get bandSwitch;

  /// No description provided for @bandManage.
  ///
  /// In de, this message translates to:
  /// **'Bands verwalten'**
  String get bandManage;

  /// No description provided for @librarySwitch.
  ///
  /// In de, this message translates to:
  /// **'Songbibliothek wechseln'**
  String get librarySwitch;

  /// No description provided for @bandsTitle.
  ///
  /// In de, this message translates to:
  /// **'Bands'**
  String get bandsTitle;

  /// No description provided for @bandsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Du bist noch in keiner Band. Erstelle eine Band für deine Songs und Sets.'**
  String get bandsEmpty;

  /// No description provided for @bandsSignInHint.
  ///
  /// In de, this message translates to:
  /// **'Melde dich an, um Bands zu erstellen.'**
  String get bandsSignInHint;

  /// No description provided for @bandNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Band'**
  String get bandNew;

  /// No description provided for @bandName.
  ///
  /// In de, this message translates to:
  /// **'Bandname'**
  String get bandName;

  /// No description provided for @bandRoleAdmin.
  ///
  /// In de, this message translates to:
  /// **'Admin'**
  String get bandRoleAdmin;

  /// No description provided for @bandRoleMember.
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get bandRoleMember;

  /// No description provided for @bandMembers.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get bandMembers;

  /// No description provided for @bandYou.
  ///
  /// In de, this message translates to:
  /// **'{name} (du)'**
  String bandYou(String name);

  /// No description provided for @bandMakeAdmin.
  ///
  /// In de, this message translates to:
  /// **'Zum Admin machen'**
  String get bandMakeAdmin;

  /// No description provided for @bandMakeMember.
  ///
  /// In de, this message translates to:
  /// **'Zum Mitglied machen'**
  String get bandMakeMember;

  /// No description provided for @bandRoleLeader.
  ///
  /// In de, this message translates to:
  /// **'Leitung'**
  String get bandRoleLeader;

  /// No description provided for @bandRolePlanner.
  ///
  /// In de, this message translates to:
  /// **'Setplanung'**
  String get bandRolePlanner;

  /// No description provided for @orgRoleLibrarian.
  ///
  /// In de, this message translates to:
  /// **'Bibliothek'**
  String get orgRoleLibrarian;

  /// No description provided for @bandMakeLeader.
  ///
  /// In de, this message translates to:
  /// **'Zur Leitung machen'**
  String get bandMakeLeader;

  /// No description provided for @bandMakePlanner.
  ///
  /// In de, this message translates to:
  /// **'Für die Setplanung einsetzen'**
  String get bandMakePlanner;

  /// No description provided for @orgMakeLibrarian.
  ///
  /// In de, this message translates to:
  /// **'Für die Bibliothek einsetzen'**
  String get orgMakeLibrarian;

  /// No description provided for @orgLibrarianHint.
  ///
  /// In de, this message translates to:
  /// **'Die Bibliothek erstellt, bearbeitet und löscht die Songs der Organisation.'**
  String get orgLibrarianHint;

  /// No description provided for @bandPlannerHint.
  ///
  /// In de, this message translates to:
  /// **'Die Setplanung stellt die Sets der Band zusammen.'**
  String get bandPlannerHint;

  /// No description provided for @inviteBandHint.
  ///
  /// In de, this message translates to:
  /// **'Erstellt einen Link, der 7 Tage gilt. Wer ihn öffnet, wird Mitglied der Organisation und dieser Band.'**
  String get inviteBandHint;

  /// No description provided for @joinQuestionBand.
  ///
  /// In de, this message translates to:
  /// **'{band} ({org}) beitreten?'**
  String joinQuestionBand(String band, String org);

  /// No description provided for @joinExplanationBand.
  ///
  /// In de, this message translates to:
  /// **'Du wirst Mitglied der Organisation und der Band und siehst ihre Songs und Sets.'**
  String get joinExplanationBand;

  /// No description provided for @bandRemoveMember.
  ///
  /// In de, this message translates to:
  /// **'Aus der Band entfernen'**
  String get bandRemoveMember;

  /// No description provided for @bandRemoveTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} entfernen?'**
  String bandRemoveTitle(String name);

  /// No description provided for @bandRemoveMessage.
  ///
  /// In de, this message translates to:
  /// **'{name} sieht die Songs und Sets der Band danach nicht mehr.'**
  String bandRemoveMessage(String name);

  /// No description provided for @bandLeave.
  ///
  /// In de, this message translates to:
  /// **'Band verlassen'**
  String get bandLeave;

  /// No description provided for @bandLeaveTitle.
  ///
  /// In de, this message translates to:
  /// **'{band} verlassen?'**
  String bandLeaveTitle(String band);

  /// No description provided for @bandLeaveMessage.
  ///
  /// In de, this message translates to:
  /// **'Du siehst die Songs und Sets der Band danach nicht mehr. Ein Admin kann dich wieder einladen.'**
  String get bandLeaveMessage;

  /// No description provided for @bandRefresh.
  ///
  /// In de, this message translates to:
  /// **'Aktualisieren'**
  String get bandRefresh;

  /// No description provided for @bandErrorLastAdmin.
  ///
  /// In de, this message translates to:
  /// **'Eine Band braucht mindestens einen Admin.'**
  String get bandErrorLastAdmin;

  /// No description provided for @bandErrorNotAllowed.
  ///
  /// In de, this message translates to:
  /// **'Dazu fehlt die Berechtigung, oder die Band gibt es nicht mehr.'**
  String get bandErrorNotAllowed;

  /// No description provided for @accountErrorSignedOut.
  ///
  /// In de, this message translates to:
  /// **'Bitte melde dich an.'**
  String get accountErrorSignedOut;

  /// No description provided for @copyToBand.
  ///
  /// In de, this message translates to:
  /// **'In Band kopieren'**
  String get copyToBand;

  /// No description provided for @copyToBandTitle.
  ///
  /// In de, this message translates to:
  /// **'In welche Band kopieren?'**
  String get copyToBandTitle;

  /// No description provided for @copyToBandNoTarget.
  ///
  /// In de, this message translates to:
  /// **'Es gibt keine andere Band, in die du kopieren darfst.'**
  String get copyToBandNoTarget;

  /// No description provided for @copiedSongs.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song nach {band} kopiert} other{{count} Songs nach {band} kopiert}}'**
  String copiedSongs(int count, String band);

  /// No description provided for @copiedSet.
  ///
  /// In de, this message translates to:
  /// **'Set nach {band} kopiert'**
  String copiedSet(String band);

  /// No description provided for @songsSelected.
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String songsSelected(int count);

  /// No description provided for @selectAll.
  ///
  /// In de, this message translates to:
  /// **'Alle auswählen'**
  String get selectAll;

  /// No description provided for @selectMode.
  ///
  /// In de, this message translates to:
  /// **'Auswählen'**
  String get selectMode;

  /// No description provided for @bandRoleOrgAdmin.
  ///
  /// In de, this message translates to:
  /// **'Admin der Organisation'**
  String get bandRoleOrgAdmin;

  /// No description provided for @bandOrganization.
  ///
  /// In de, this message translates to:
  /// **'Organisation'**
  String get bandOrganization;

  /// No description provided for @bandNewOrganization.
  ///
  /// In de, this message translates to:
  /// **'Neue Organisation'**
  String get bandNewOrganization;

  /// No description provided for @bandNewHint.
  ///
  /// In de, this message translates to:
  /// **'Die Bands einer Organisation teilen ihre Songs.'**
  String get bandNewHint;

  /// No description provided for @bandAddMember.
  ///
  /// In de, this message translates to:
  /// **'Mitglied hinzufügen'**
  String get bandAddMember;

  /// No description provided for @bandAddMemberTitle.
  ///
  /// In de, this message translates to:
  /// **'Wen hinzufügen?'**
  String get bandAddMemberTitle;

  /// No description provided for @bandAddMemberNone.
  ///
  /// In de, this message translates to:
  /// **'Alle Personen der Organisation sind schon in dieser Band.'**
  String get bandAddMemberNone;

  /// No description provided for @bandOrgAdminHint.
  ///
  /// In de, this message translates to:
  /// **'Du verwaltest diese Band als Admin der Organisation.'**
  String get bandOrgAdminHint;

  /// No description provided for @bandErrorNotOrgMember.
  ///
  /// In de, this message translates to:
  /// **'Diese Person gehört nicht zur Organisation.'**
  String get bandErrorNotOrgMember;

  /// No description provided for @orgName.
  ///
  /// In de, this message translates to:
  /// **'Name der Organisation'**
  String get orgName;

  /// No description provided for @orgPeople.
  ///
  /// In de, this message translates to:
  /// **'Personen'**
  String get orgPeople;

  /// No description provided for @orgBands.
  ///
  /// In de, this message translates to:
  /// **'Bands'**
  String get orgBands;

  /// No description provided for @orgRemove.
  ///
  /// In de, this message translates to:
  /// **'Aus der Organisation entfernen'**
  String get orgRemove;

  /// No description provided for @orgRemoveTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} entfernen?'**
  String orgRemoveTitle(String name);

  /// No description provided for @orgRemoveMessage.
  ///
  /// In de, this message translates to:
  /// **'{name} verlässt damit auch alle Bands der Organisation und sieht ihre Songs nicht mehr.'**
  String orgRemoveMessage(String name);

  /// No description provided for @orgLeave.
  ///
  /// In de, this message translates to:
  /// **'Organisation verlassen'**
  String get orgLeave;

  /// No description provided for @orgLeaveTitle.
  ///
  /// In de, this message translates to:
  /// **'{org} verlassen?'**
  String orgLeaveTitle(String org);

  /// No description provided for @orgLeaveMessage.
  ///
  /// In de, this message translates to:
  /// **'Du verlässt damit auch alle ihre Bands und siehst ihre Songs nicht mehr.'**
  String get orgLeaveMessage;

  /// No description provided for @orgSongsShared.
  ///
  /// In de, this message translates to:
  /// **'Alle Bands der Organisation teilen dieselben Songs.'**
  String get orgSongsShared;

  /// No description provided for @copyToLibraryTitle.
  ///
  /// In de, this message translates to:
  /// **'In welche Songbibliothek kopieren?'**
  String get copyToLibraryTitle;

  /// No description provided for @inviteCreate.
  ///
  /// In de, this message translates to:
  /// **'Personen einladen'**
  String get inviteCreate;

  /// No description provided for @inviteCreateHint.
  ///
  /// In de, this message translates to:
  /// **'Erstellt einen Link, der 7 Tage gilt. Wer ihn öffnet, wird Mitglied der Organisation.'**
  String get inviteCreateHint;

  /// No description provided for @inviteLinkTitle.
  ///
  /// In de, this message translates to:
  /// **'Einladungslink'**
  String get inviteLinkTitle;

  /// No description provided for @inviteLinkHint.
  ///
  /// In de, this message translates to:
  /// **'Teile den Link, z. B. im Gruppenchat, oder lass den QR-Code scannen. Gültig bis {date}. Der Link wird nur jetzt angezeigt.'**
  String inviteLinkHint(String date);

  /// No description provided for @inviteCopy.
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get inviteCopy;

  /// No description provided for @inviteCopied.
  ///
  /// In de, this message translates to:
  /// **'Link kopiert'**
  String get inviteCopied;

  /// No description provided for @invitesTitle.
  ///
  /// In de, this message translates to:
  /// **'Einladungslinks'**
  String get invitesTitle;

  /// No description provided for @inviteStatusValid.
  ///
  /// In de, this message translates to:
  /// **'Gültig bis {date}'**
  String inviteStatusValid(String date);

  /// No description provided for @inviteStatusExpired.
  ///
  /// In de, this message translates to:
  /// **'Abgelaufen'**
  String get inviteStatusExpired;

  /// No description provided for @inviteStatusRevoked.
  ///
  /// In de, this message translates to:
  /// **'Widerrufen'**
  String get inviteStatusRevoked;

  /// No description provided for @inviteJoined.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Noch niemand beigetreten} =1{Beigetreten: {names}} other{{count} beigetreten: {names}}}'**
  String inviteJoined(int count, String names);

  /// No description provided for @inviteRevoke.
  ///
  /// In de, this message translates to:
  /// **'Widerrufen'**
  String get inviteRevoke;

  /// No description provided for @inviteRevokeTitle.
  ///
  /// In de, this message translates to:
  /// **'Link widerrufen?'**
  String get inviteRevokeTitle;

  /// No description provided for @inviteRevokeMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Link funktioniert danach nicht mehr. Wer schon beigetreten ist, bleibt Mitglied.'**
  String get inviteRevokeMessage;

  /// No description provided for @inviteAskAdmin.
  ///
  /// In de, this message translates to:
  /// **'Für eine Einladung wende dich an einen Admin der Organisation oder an die Leitung einer Band.'**
  String get inviteAskAdmin;

  /// No description provided for @inviteErrorUnknown.
  ///
  /// In de, this message translates to:
  /// **'Diese Einladung gibt es nicht. Prüfe den Link.'**
  String get inviteErrorUnknown;

  /// No description provided for @inviteErrorExpired.
  ///
  /// In de, this message translates to:
  /// **'Diese Einladung ist abgelaufen. Bitte um einen neuen Link.'**
  String get inviteErrorExpired;

  /// No description provided for @inviteErrorRevoked.
  ///
  /// In de, this message translates to:
  /// **'Diese Einladung wurde widerrufen. Bitte um einen neuen Link.'**
  String get inviteErrorRevoked;

  /// No description provided for @joinTitle.
  ///
  /// In de, this message translates to:
  /// **'Beitreten'**
  String get joinTitle;

  /// No description provided for @joinHint.
  ///
  /// In de, this message translates to:
  /// **'Füge den Einladungslink ein, den du erhalten hast.'**
  String get joinHint;

  /// No description provided for @joinLink.
  ///
  /// In de, this message translates to:
  /// **'Einladungslink'**
  String get joinLink;

  /// No description provided for @joinContinue.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get joinContinue;

  /// No description provided for @joinInvalidLink.
  ///
  /// In de, this message translates to:
  /// **'Das ist kein gültiger Einladungslink.'**
  String get joinInvalidLink;

  /// No description provided for @joinQuestion.
  ///
  /// In de, this message translates to:
  /// **'{org} beitreten?'**
  String joinQuestion(String org);

  /// No description provided for @joinExplanation.
  ///
  /// In de, this message translates to:
  /// **'Du wirst Mitglied der Organisation und siehst ihre Songs. Ein Admin kann dich danach in eine Band aufnehmen.'**
  String get joinExplanation;

  /// No description provided for @joinAlreadyMember.
  ///
  /// In de, this message translates to:
  /// **'Du bist bereits Mitglied von {org}.'**
  String joinAlreadyMember(String org);

  /// No description provided for @joinButton.
  ///
  /// In de, this message translates to:
  /// **'Beitreten'**
  String get joinButton;

  /// No description provided for @joinDone.
  ///
  /// In de, this message translates to:
  /// **'Du bist {org} beigetreten.'**
  String joinDone(String org);

  /// No description provided for @joinSignInFirst.
  ///
  /// In de, this message translates to:
  /// **'Melde dich an oder erstelle ein Konto, um beizutreten.'**
  String get joinSignInFirst;

  /// No description provided for @joinHaveAccount.
  ///
  /// In de, this message translates to:
  /// **'Ich habe schon ein Konto'**
  String get joinHaveAccount;

  /// No description provided for @inviteErrorUsed.
  ///
  /// In de, this message translates to:
  /// **'Diese Einladung wurde bereits verwendet. Bitte um einen neuen Link.'**
  String get inviteErrorUsed;

  /// No description provided for @accountErrorInvitationRequired.
  ///
  /// In de, this message translates to:
  /// **'Dieser Server nimmt neue Konten nur mit einem Einladungslink an.'**
  String get accountErrorInvitationRequired;

  /// No description provided for @accountErrorEmailNotVerified.
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige zuerst deine E-Mail-Adresse. Wir haben dir eine neue Mail geschickt.'**
  String get accountErrorEmailNotVerified;

  /// No description provided for @bandErrorFounderInvitationRequired.
  ///
  /// In de, this message translates to:
  /// **'Neue Organisationen brauchen eine Gründungs-Einladung vom Server-Betreiber.'**
  String get bandErrorFounderInvitationRequired;

  /// No description provided for @accountInviteOnlyHint.
  ///
  /// In de, this message translates to:
  /// **'Neue Konten brauchen auf diesem Server einen Einladungslink.'**
  String get accountInviteOnlyHint;

  /// No description provided for @accountVerifyEmail.
  ///
  /// In de, this message translates to:
  /// **'Fast geschafft: Wir haben eine Mail an {email} geschickt. Bestätige deine Adresse mit dem Link darin und melde dich dann an.'**
  String accountVerifyEmail(String email);

  /// No description provided for @accountVerifyResend.
  ///
  /// In de, this message translates to:
  /// **'Mail erneut senden'**
  String get accountVerifyResend;

  /// No description provided for @accountVerifySent.
  ///
  /// In de, this message translates to:
  /// **'Mail gesendet.'**
  String get accountVerifySent;

  /// No description provided for @joinFoundQuestion.
  ///
  /// In de, this message translates to:
  /// **'{org} gründen?'**
  String joinFoundQuestion(String org);

  /// No description provided for @joinFoundExplanation.
  ///
  /// In de, this message translates to:
  /// **'Du erstellst die Organisation und wirst ihr Admin. Danach kannst du Bands anlegen und Leute einladen.'**
  String get joinFoundExplanation;

  /// No description provided for @joinFoundButton.
  ///
  /// In de, this message translates to:
  /// **'Organisation gründen'**
  String get joinFoundButton;

  /// No description provided for @joinFoundDone.
  ///
  /// In de, this message translates to:
  /// **'Du hast {org} gegründet.'**
  String joinFoundDone(String org);

  /// No description provided for @syncTitle.
  ///
  /// In de, this message translates to:
  /// **'Synchronisation'**
  String get syncTitle;

  /// No description provided for @syncNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt synchronisieren'**
  String get syncNow;

  /// No description provided for @settingsSyncMode.
  ///
  /// In de, this message translates to:
  /// **'Synchronisieren'**
  String get settingsSyncMode;

  /// No description provided for @syncModeAutomatic.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get syncModeAutomatic;

  /// No description provided for @syncModeOnStart.
  ///
  /// In de, this message translates to:
  /// **'Beim Start'**
  String get syncModeOnStart;

  /// No description provided for @syncModeManual.
  ///
  /// In de, this message translates to:
  /// **'Manuell'**
  String get syncModeManual;

  /// No description provided for @syncModeAutomaticHint.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiert beim Start, wenige Sekunden nach Änderungen, bei Änderungen auf dem Server und alle 5 Minuten.'**
  String get syncModeAutomaticHint;

  /// No description provided for @syncModeOnStartHint.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiert einmal beim Start der App und nach dem Anmelden. Sonst mit «Jetzt synchronisieren».'**
  String get syncModeOnStartHint;

  /// No description provided for @syncModeManualHint.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiert nur, wenn du auf «Jetzt synchronisieren» tippst.'**
  String get syncModeManualHint;

  /// No description provided for @syncRunning.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiere …'**
  String get syncRunning;

  /// No description provided for @syncLast.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt synchronisiert: {time}'**
  String syncLast(String time);

  /// No description provided for @syncNever.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht synchronisiert'**
  String get syncNever;

  /// No description provided for @syncPending.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Alle Änderungen sind auf dem Server.} =1{1 Änderung ist noch nicht auf dem Server.} other{{count} Änderungen sind noch nicht auf dem Server.}}'**
  String syncPending(int count);

  /// No description provided for @syncOffline.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung – Änderungen werden später übertragen.'**
  String get syncOffline;

  /// No description provided for @syncConflicts.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song mit Konflikt – öffne ihn, um zu entscheiden.} other{{count} Songs mit Konflikt – öffne sie, um zu entscheiden.}}'**
  String syncConflicts(int count);

  /// No description provided for @conflictBanner.
  ///
  /// In de, this message translates to:
  /// **'Dieser Song wurde auf dem Server und auf diesem Gerät geändert.'**
  String get conflictBanner;

  /// No description provided for @conflictBannerDeleted.
  ///
  /// In de, this message translates to:
  /// **'Dieser Song wurde auf dem Server gelöscht und auf diesem Gerät geändert.'**
  String get conflictBannerDeleted;

  /// No description provided for @conflictKeepMine.
  ///
  /// In de, this message translates to:
  /// **'Meine Version behalten'**
  String get conflictKeepMine;

  /// No description provided for @conflictTakeServer.
  ///
  /// In de, this message translates to:
  /// **'Server-Version übernehmen'**
  String get conflictTakeServer;

  /// No description provided for @conflictKeepBoth.
  ///
  /// In de, this message translates to:
  /// **'Beide behalten'**
  String get conflictKeepBoth;

  /// No description provided for @conflictCompare.
  ///
  /// In de, this message translates to:
  /// **'Server-Version ansehen'**
  String get conflictCompare;

  /// No description provided for @conflictServerVersion.
  ///
  /// In de, this message translates to:
  /// **'Version auf dem Server'**
  String get conflictServerVersion;

  /// No description provided for @conflictKeptBoth.
  ///
  /// In de, this message translates to:
  /// **'Deine Version wurde als eigener Song gespeichert.'**
  String get conflictKeptBoth;

  /// No description provided for @accountErrorConflict.
  ///
  /// In de, this message translates to:
  /// **'Der Song wurde inzwischen auf dem Server geändert.'**
  String get accountErrorConflict;

  /// No description provided for @pdfMissing.
  ///
  /// In de, this message translates to:
  /// **'Das PDF ist noch nicht auf diesem Gerät. Es wird beim nächsten Sync geladen.'**
  String get pdfMissing;

  /// No description provided for @pdfLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Das PDF konnte nicht vom Server geladen werden. Prüfe die Verbindung und öffne den Song erneut.'**
  String get pdfLoadFailed;

  /// No description provided for @syncMissingFiles.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 PDF wird noch geladen.} other{{count} PDFs werden noch geladen.}}'**
  String syncMissingFiles(int count);

  /// No description provided for @invalidChordProTitle.
  ///
  /// In de, this message translates to:
  /// **'ChordPro prüfen?'**
  String get invalidChordProTitle;

  /// No description provided for @invalidChordProMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Song enthält Stellen, die wahrscheinlich nicht wie gewollt angezeigt werden:'**
  String get invalidChordProMessage;

  /// No description provided for @problemUnclosedDirective.
  ///
  /// In de, this message translates to:
  /// **'Zeile {line}: Eine geschweifte Klammer (Direktive) wird nicht geschlossen.'**
  String problemUnclosedDirective(int line);

  /// No description provided for @problemUnclosedChord.
  ///
  /// In de, this message translates to:
  /// **'Zeile {line}: Eine eckige Klammer (Akkord) wird nicht geschlossen.'**
  String problemUnclosedChord(int line);

  /// No description provided for @problemUnclosedEnvironment.
  ///
  /// In de, this message translates to:
  /// **'Zeile {line}: Der Block wird nie beendet und enthält den ganzen Rest des Songs.'**
  String problemUnclosedEnvironment(int line);

  /// No description provided for @moreProblems.
  ///
  /// In de, this message translates to:
  /// **'… und {count} weitere.'**
  String moreProblems(int count);

  /// No description provided for @saveAnyway.
  ///
  /// In de, this message translates to:
  /// **'Trotzdem speichern'**
  String get saveAnyway;

  /// No description provided for @keepEditing.
  ///
  /// In de, this message translates to:
  /// **'Weiter bearbeiten'**
  String get keepEditing;

  /// No description provided for @webSignInHint.
  ///
  /// In de, this message translates to:
  /// **'Melde dich an, um Organisationen, Bands, Songs und Sets im Browser zu verwalten.'**
  String get webSignInHint;

  /// No description provided for @webNoBandTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Band'**
  String get webNoBandTitle;

  /// No description provided for @webNoBandMessage.
  ///
  /// In de, this message translates to:
  /// **'Du bist noch in keiner Band. Erstelle eine Organisation mit einer Band oder tritt mit einem Einladungslink bei.'**
  String get webNoBandMessage;

  /// No description provided for @songDetails.
  ///
  /// In de, this message translates to:
  /// **'Songdetails'**
  String get songDetails;

  /// No description provided for @songDetailsTooltip.
  ///
  /// In de, this message translates to:
  /// **'Titel, Tonart, Tempo und mehr bearbeiten'**
  String get songDetailsTooltip;

  /// No description provided for @noKey.
  ///
  /// In de, this message translates to:
  /// **'Keine Tonart'**
  String get noKey;

  /// No description provided for @timeHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. 4/4'**
  String get timeHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
