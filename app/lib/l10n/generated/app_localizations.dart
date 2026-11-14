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
  /// **'BandChords'**
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
  /// **'Tonart {key}'**
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
  /// **'Speicher'**
  String get settingsSectionStorage;

  /// No description provided for @settingsSectionMusician.
  ///
  /// In de, this message translates to:
  /// **'Musiker'**
  String get settingsSectionMusician;

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

  /// No description provided for @settingsPedalHint.
  ///
  /// In de, this message translates to:
  /// **'Fusspedal und Tastatur: Pfeiltasten, Bild auf/ab und Leertaste blättern. Tippe links oder rechts auf den Bildschirm, um zurück oder weiter zu blättern.'**
  String get settingsPedalHint;

  /// No description provided for @settingsStorageUsed.
  ///
  /// In de, this message translates to:
  /// **'PDF-Anhänge belegen {size}'**
  String settingsStorageUsed(String size);

  /// No description provided for @settingsAbout.
  ///
  /// In de, this message translates to:
  /// **'BandChords läuft lokal auf diesem Gerät. Alle Daten sind offline verfügbar.'**
  String get settingsAbout;

  /// No description provided for @lilypondNotice.
  ///
  /// In de, this message translates to:
  /// **'Lilypond-Noten können auf diesem Gerät nicht dargestellt werden. Quelltext:'**
  String get lilypondNotice;
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
