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
  /// **'setDING'**
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
  /// **'Unterstützt werden .cho, .chordpro, .chopro, .crd, .pro, .txt, ZIP-Archive mit solchen Dateien und setDING-Sicherungen.'**
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
  /// **'Meine Notizen'**
  String get notes;

  /// No description provided for @notesHint.
  ///
  /// In de, this message translates to:
  /// **'Nur du siehst diese Notiz.'**
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

  /// No description provided for @noAttachments.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Anhänge.'**
  String get noAttachments;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist grösser als 20 MB und kann nicht angehängt werden.'**
  String get attachmentTooLarge;

  /// No description provided for @songLinks.
  ///
  /// In de, this message translates to:
  /// **'Quellen'**
  String get songLinks;

  /// No description provided for @noSongLinks.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Quellen. Füge Aufnahmen auf YouTube, Spotify usw. hinzu.'**
  String get noSongLinks;

  /// No description provided for @addSongLink.
  ///
  /// In de, this message translates to:
  /// **'Link hinzufügen'**
  String get addSongLink;

  /// No description provided for @editSongLink.
  ///
  /// In de, this message translates to:
  /// **'Link bearbeiten'**
  String get editSongLink;

  /// No description provided for @deleteSongLink.
  ///
  /// In de, this message translates to:
  /// **'Quelle entfernen'**
  String get deleteSongLink;

  /// No description provided for @deleteSongLinkMessage.
  ///
  /// In de, this message translates to:
  /// **'Diese Quelle aus dem Song entfernen?'**
  String get deleteSongLinkMessage;

  /// No description provided for @songLinkUrl.
  ///
  /// In de, this message translates to:
  /// **'Link (URL)'**
  String get songLinkUrl;

  /// No description provided for @songLinkLabel.
  ///
  /// In de, this message translates to:
  /// **'Beschriftung (optional)'**
  String get songLinkLabel;

  /// No description provided for @songLinkLabelHint.
  ///
  /// In de, this message translates to:
  /// **'Live 2009'**
  String get songLinkLabelHint;

  /// No description provided for @songLinkInvalid.
  ///
  /// In de, this message translates to:
  /// **'Gib einen Weblink ein, der mit https:// beginnt (ohne |).'**
  String get songLinkInvalid;

  /// No description provided for @songLinkFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Link konnte nicht geöffnet werden.'**
  String get songLinkFailed;

  /// No description provided for @attachmentName.
  ///
  /// In de, this message translates to:
  /// **'Name des Anhangs'**
  String get attachmentName;

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

  /// No description provided for @live.
  ///
  /// In de, this message translates to:
  /// **'Live'**
  String get live;

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

  /// No description provided for @scopePersonal.
  ///
  /// In de, this message translates to:
  /// **'Nur für dich – für alle anderen bleibt der Song unverändert.'**
  String get scopePersonal;

  /// No description provided for @scopeSet.
  ///
  /// In de, this message translates to:
  /// **'Für dieses Set – gilt für die ganze Band.'**
  String get scopeSet;

  /// No description provided for @scopeBand.
  ///
  /// In de, this message translates to:
  /// **'Für die ganze Band – gilt in allen ihren Sets.'**
  String get scopeBand;

  /// No description provided for @scopeSong.
  ///
  /// In de, this message translates to:
  /// **'Für den Song – ändert ihn für alle in der Organisation.'**
  String get scopeSong;

  /// No description provided for @keyPickerPersonal.
  ///
  /// In de, this message translates to:
  /// **'Meine Tonart – nur für mich'**
  String get keyPickerPersonal;

  /// No description provided for @keyPickerSet.
  ///
  /// In de, this message translates to:
  /// **'Tonart in diesem Set – für die ganze Band'**
  String get keyPickerSet;

  /// No description provided for @keyPickerBand.
  ///
  /// In de, this message translates to:
  /// **'Tonart der Band – für alle ihre Sets'**
  String get keyPickerBand;

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

  /// No description provided for @firstVerseChordsOnly.
  ///
  /// In de, this message translates to:
  /// **'Akkorde nur in Verse 1'**
  String get firstVerseChordsOnly;

  /// No description provided for @noVersesForFirstVerseChords.
  ///
  /// In de, this message translates to:
  /// **'Der Song hat keine weiteren Verses mit Akkorden.'**
  String get noVersesForFirstVerseChords;

  /// No description provided for @verseChords.
  ///
  /// In de, this message translates to:
  /// **'Akkorde in Verses'**
  String get verseChords;

  /// No description provided for @verseChordsAll.
  ///
  /// In de, this message translates to:
  /// **'Akkorde in allen Verses'**
  String get verseChordsAll;

  /// No description provided for @verseChordsStacked.
  ///
  /// In de, this message translates to:
  /// **'Verses untereinander'**
  String get verseChordsStacked;

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
  /// **'Verse einfügen'**
  String get insertVerse;

  /// No description provided for @insertChorus.
  ///
  /// In de, this message translates to:
  /// **'Chorus einfügen'**
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
  /// **'Verse'**
  String get sectionVerse;

  /// No description provided for @sectionChorus.
  ///
  /// In de, this message translates to:
  /// **'Chorus'**
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
  /// **'Grid'**
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

  /// No description provided for @liveMidiConnected.
  ///
  /// In de, this message translates to:
  /// **'Keyboard verbunden: {name}'**
  String liveMidiConnected(String name);

  /// No description provided for @liveMidiNotConnected.
  ///
  /// In de, this message translates to:
  /// **'Keyboard nicht verbunden'**
  String get liveMidiNotConnected;

  /// No description provided for @liveMidiSendAgain.
  ///
  /// In de, this message translates to:
  /// **'Programm erneut senden'**
  String get liveMidiSendAgain;

  /// No description provided for @liveMidiButton.
  ///
  /// In de, this message translates to:
  /// **'Keyboard-Programm (lange drücken: erneut senden)'**
  String get liveMidiButton;

  /// No description provided for @liveMidiChange.
  ///
  /// In de, this message translates to:
  /// **'Programm ändern'**
  String get liveMidiChange;

  /// No description provided for @liveMidiSameAsPrevious.
  ///
  /// In de, this message translates to:
  /// **'Wie vorheriger Song'**
  String get liveMidiSameAsPrevious;

  /// No description provided for @liveMidiPreviousProgram.
  ///
  /// In de, this message translates to:
  /// **'{program} – aus «{title}»'**
  String liveMidiPreviousProgram(String program, String title);

  /// No description provided for @liveMidiNoPrevious.
  ///
  /// In de, this message translates to:
  /// **'Kein früherer Song mit Programm'**
  String get liveMidiNoPrevious;

  /// No description provided for @liveMidiSaved.
  ///
  /// In de, this message translates to:
  /// **'Keyboard-Programm gespeichert'**
  String get liveMidiSaved;

  /// No description provided for @liveMidiRemoved.
  ///
  /// In de, this message translates to:
  /// **'Keyboard-Programm entfernt'**
  String get liveMidiRemoved;

  /// No description provided for @liveMidiTakeOverWaiting.
  ///
  /// In de, this message translates to:
  /// **'Wähle am Keyboard einen Klang'**
  String get liveMidiTakeOverWaiting;

  /// No description provided for @liveMidiTakeOver.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen: {program}'**
  String liveMidiTakeOver(String program);

  /// No description provided for @liveMidiTakeOverHint.
  ///
  /// In de, this message translates to:
  /// **'setDING übernimmt das Programm, das das Keyboard sendet.'**
  String get liveMidiTakeOverHint;

  /// No description provided for @liveMidiTakeOverNordHint.
  ///
  /// In de, this message translates to:
  /// **'Kommt nichts an? Stelle am Nord im MIDI-Menü «Program Change» auf «Send» oder «Send & Receive».'**
  String get liveMidiTakeOverNordHint;

  /// No description provided for @liveMidiTakeOverSame.
  ///
  /// In de, this message translates to:
  /// **'Das ist bereits das Programm des Songs'**
  String get liveMidiTakeOverSame;

  /// No description provided for @liveWakeLockNotice.
  ///
  /// In de, this message translates to:
  /// **'Bildschirm kann sich ausschalten – Energieeinstellungen des Geräts prüfen'**
  String get liveWakeLockNotice;

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
  /// **'Bildschirm & Live-Modus'**
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
  /// **'Anmeldung, Server und Synchronisation'**
  String get settingsCategoryAccountHint;

  /// No description provided for @settingsCategoryGeneralHint.
  ///
  /// In de, this message translates to:
  /// **'Sprache und Design'**
  String get settingsCategoryGeneralHint;

  /// No description provided for @settingsCategoryMusicianHint.
  ///
  /// In de, this message translates to:
  /// **'Instrument, Stimme, Akkorddiagramme, Takt'**
  String get settingsCategoryMusicianHint;

  /// No description provided for @settingsCategoryDisplayHint.
  ///
  /// In de, this message translates to:
  /// **'Akkord-Notation, Nashville-Zahlen, Inhalt, Chorus, Fortschritt'**
  String get settingsCategoryDisplayHint;

  /// No description provided for @settingsCategoryLiveHint.
  ///
  /// In de, this message translates to:
  /// **'Schriftgrösse, an Bildschirm anpassen, Spalten, Blättern'**
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

  /// No description provided for @instrumentDrums.
  ///
  /// In de, this message translates to:
  /// **'Schlagzeug'**
  String get instrumentDrums;

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

  /// No description provided for @settingsAccent.
  ///
  /// In de, this message translates to:
  /// **'Akzentfarbe'**
  String get settingsAccent;

  /// No description provided for @accentBrand.
  ///
  /// In de, this message translates to:
  /// **'setDING-Blau'**
  String get accentBrand;

  /// No description provided for @accentRed.
  ///
  /// In de, this message translates to:
  /// **'Rot'**
  String get accentRed;

  /// No description provided for @accentAmber.
  ///
  /// In de, this message translates to:
  /// **'Bernstein'**
  String get accentAmber;

  /// No description provided for @accentGreen.
  ///
  /// In de, this message translates to:
  /// **'Grün'**
  String get accentGreen;

  /// No description provided for @accentTeal.
  ///
  /// In de, this message translates to:
  /// **'Petrol'**
  String get accentTeal;

  /// No description provided for @accentPurple.
  ///
  /// In de, this message translates to:
  /// **'Violett'**
  String get accentPurple;

  /// No description provided for @accentPink.
  ///
  /// In de, this message translates to:
  /// **'Rosa'**
  String get accentPink;

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
  /// **'Wiederholter Chorus'**
  String get settingsChorusRepeat;

  /// No description provided for @settingsChorusRepeatHint.
  ///
  /// In de, this message translates to:
  /// **'Automatisch: Ein wiederholter Chorus wird nur dann als kurzer Hinweis angezeigt, wenn der Song sonst nicht gut auf den Bildschirm passt.'**
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
  /// **'Tippe links oder rechts auf den Bildschirm, um zurück oder weiter zu blättern. Seitenwender (Fusspedal) und Tastatur: Pfeil rechts, Pfeil ab, Bild ab und Leertaste blättern weiter, Pfeil links, Pfeil auf und Bild auf zurück. Mit Takt (Tempo und Taktanzeige oder Klick eingeschaltet) startet und stoppt ihn langes Drücken von Vorwärts oder Enter.'**
  String get settingsPageTurnHint;

  /// No description provided for @settingsSetProgress.
  ///
  /// In de, this message translates to:
  /// **'Fortschrittsbalken des Sets'**
  String get settingsSetProgress;

  /// No description provided for @settingsSetProgressHint.
  ///
  /// In de, this message translates to:
  /// **'Ein schmaler Balken über der Fusszeile zeigt die Songs des Sets und die Seiten des aktuellen Songs: die aktuelle Seite in der Akzentfarbe, noch folgende Seiten heller. Pausen und Texte sind gestrichelt.'**
  String get settingsSetProgressHint;

  /// No description provided for @settingsBeatSection.
  ///
  /// In de, this message translates to:
  /// **'Takt und Klick'**
  String get settingsBeatSection;

  /// No description provided for @settingsBeatSectionHint.
  ///
  /// In de, this message translates to:
  /// **'Tempo und Taktart des Songs oder das Tempo des Band-Arrangements. Standardmässig eingeschaltet, wenn dein Instrument Schlagzeug ist.'**
  String get settingsBeatSectionHint;

  /// No description provided for @settingsBeatDisplay.
  ///
  /// In de, this message translates to:
  /// **'Taktanzeige'**
  String get settingsBeatDisplay;

  /// No description provided for @settingsBeatDisplayHint.
  ///
  /// In de, this message translates to:
  /// **'Punkte neben Tempo und Taktart leuchten auf jedem Schlag; beim Einzählen erscheinen grosse Zahlen.'**
  String get settingsBeatDisplayHint;

  /// No description provided for @settingsEdgeFlash.
  ///
  /// In de, this message translates to:
  /// **'Bildschirmrand blinken lassen'**
  String get settingsEdgeFlash;

  /// No description provided for @settingsEdgeFlashHint.
  ///
  /// In de, this message translates to:
  /// **'Der Rand blinkt auf jedem Schlag, die 1 in einer anderen Farbe – sichtbar aus dem Augenwinkel.'**
  String get settingsEdgeFlashHint;

  /// No description provided for @settingsClick.
  ///
  /// In de, this message translates to:
  /// **'Klick'**
  String get settingsClick;

  /// No description provided for @settingsClickHint.
  ///
  /// In de, this message translates to:
  /// **'Spielt einen Klick über den Audio-Ausgang des Geräts, z. B. in den In-Ear-Mix.'**
  String get settingsClickHint;

  /// No description provided for @settingsClickStart.
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get settingsClickStart;

  /// No description provided for @settingsClickStartHint.
  ///
  /// In de, this message translates to:
  /// **'Manuell: aufs Tempo tippen, das Vorwärts-Pedal halten oder Enter drücken. Der Wechsel zu einem anderen Song des Sets stoppt den Takt.'**
  String get settingsClickStartHint;

  /// No description provided for @clickStartAutomatic.
  ///
  /// In de, this message translates to:
  /// **'Bei jedem Song'**
  String get clickStartAutomatic;

  /// No description provided for @clickStartManual.
  ///
  /// In de, this message translates to:
  /// **'Manuell'**
  String get clickStartManual;

  /// No description provided for @settingsClickDuration.
  ///
  /// In de, this message translates to:
  /// **'Dauer'**
  String get settingsClickDuration;

  /// No description provided for @clickDurationSong.
  ///
  /// In de, this message translates to:
  /// **'Ganzer Song'**
  String get clickDurationSong;

  /// No description provided for @clickDurationCountIn.
  ///
  /// In de, this message translates to:
  /// **'Nur Einzählen'**
  String get clickDurationCountIn;

  /// No description provided for @settingsClickInBackground.
  ///
  /// In de, this message translates to:
  /// **'Im Hintergrund'**
  String get settingsClickInBackground;

  /// No description provided for @settingsClickInBackgroundHint.
  ///
  /// In de, this message translates to:
  /// **'Wenn die App verkleinert, eine andere App geöffnet oder der Bildschirm gesperrt wird.'**
  String get settingsClickInBackgroundHint;

  /// No description provided for @clickInBackgroundStop.
  ///
  /// In de, this message translates to:
  /// **'Stoppen'**
  String get clickInBackgroundStop;

  /// No description provided for @clickInBackgroundKeepPlaying.
  ///
  /// In de, this message translates to:
  /// **'Weiterspielen'**
  String get clickInBackgroundKeepPlaying;

  /// No description provided for @settingsCountIn.
  ///
  /// In de, this message translates to:
  /// **'Einzählen'**
  String get settingsCountIn;

  /// No description provided for @countInOff.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get countInOff;

  /// No description provided for @countInOneBar.
  ///
  /// In de, this message translates to:
  /// **'1 Takt'**
  String get countInOneBar;

  /// No description provided for @countInTwoBars.
  ///
  /// In de, this message translates to:
  /// **'2 Takte'**
  String get countInTwoBars;

  /// No description provided for @settingsClickVolume.
  ///
  /// In de, this message translates to:
  /// **'Lautstärke'**
  String get settingsClickVolume;

  /// No description provided for @settingsClickAccent.
  ///
  /// In de, this message translates to:
  /// **'Betonung auf der 1'**
  String get settingsClickAccent;

  /// No description provided for @settingsClickSound.
  ///
  /// In de, this message translates to:
  /// **'Klang'**
  String get settingsClickSound;

  /// No description provided for @clickSoundClick.
  ///
  /// In de, this message translates to:
  /// **'Klick'**
  String get clickSoundClick;

  /// No description provided for @clickSoundWoodblock.
  ///
  /// In de, this message translates to:
  /// **'Woodblock'**
  String get clickSoundWoodblock;

  /// No description provided for @clickSoundBeep.
  ///
  /// In de, this message translates to:
  /// **'Piep'**
  String get clickSoundBeep;

  /// No description provided for @settingsClickSubdivision.
  ///
  /// In de, this message translates to:
  /// **'Unterteilung'**
  String get settingsClickSubdivision;

  /// No description provided for @settingsClickSubdivisionHint.
  ///
  /// In de, this message translates to:
  /// **'Leisere Klicks zwischen den Schlägen: Achtel, im 6/8 Triolen.'**
  String get settingsClickSubdivisionHint;

  /// No description provided for @settingsAudioLatency.
  ///
  /// In de, this message translates to:
  /// **'Audio-Verzögerung'**
  String get settingsAudioLatency;

  /// No description provided for @settingsAudioLatencyHint.
  ///
  /// In de, this message translates to:
  /// **'Verschiebt die Anzeige, damit sie zum Gehörten passt. Kabel-Kopfhörer brauchen wenig, Bluetooth-Kopfhörer 100–300 ms.'**
  String get settingsAudioLatencyHint;

  /// No description provided for @audioLatencyValue.
  ///
  /// In de, this message translates to:
  /// **'{ms} ms'**
  String audioLatencyValue(int ms);

  /// No description provided for @audioLatencyCalibrate.
  ///
  /// In de, this message translates to:
  /// **'Audio-Verzögerung messen'**
  String get audioLatencyCalibrate;

  /// No description provided for @audioLatencyCalibrateTitle.
  ///
  /// In de, this message translates to:
  /// **'Audio-Verzögerung messen'**
  String get audioLatencyCalibrateTitle;

  /// No description provided for @audioLatencyCalibrateHint.
  ///
  /// In de, this message translates to:
  /// **'Setze die Kopfhörer auf, die du auf der Bühne trägst, und tippe auf jeden Schlag des Klicks mit.'**
  String get audioLatencyCalibrateHint;

  /// No description provided for @audioLatencyTap.
  ///
  /// In de, this message translates to:
  /// **'Tippen'**
  String get audioLatencyTap;

  /// No description provided for @audioLatencyTaps.
  ///
  /// In de, this message translates to:
  /// **'{count}-mal getippt'**
  String audioLatencyTaps(int count);

  /// No description provided for @audioLatencyResult.
  ///
  /// In de, this message translates to:
  /// **'Gemessen: {ms} ms'**
  String audioLatencyResult(int ms);

  /// No description provided for @audioLatencyApply.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get audioLatencyApply;

  /// No description provided for @clickNoAudio.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Gerät gibt es keinen Audio-Ausgang für den Klick.'**
  String get clickNoAudio;

  /// No description provided for @beatStart.
  ///
  /// In de, this message translates to:
  /// **'Takt starten'**
  String get beatStart;

  /// No description provided for @beatStop.
  ///
  /// In de, this message translates to:
  /// **'Takt stoppen'**
  String get beatStop;

  /// No description provided for @beatDisplayLabel.
  ///
  /// In de, this message translates to:
  /// **'Takt'**
  String get beatDisplayLabel;

  /// No description provided for @countInBar.
  ///
  /// In de, this message translates to:
  /// **'Takt {bar} von {count}'**
  String countInBar(int bar, int count);

  /// No description provided for @tempoSlower.
  ///
  /// In de, this message translates to:
  /// **'Langsamer'**
  String get tempoSlower;

  /// No description provided for @tempoFaster.
  ///
  /// In de, this message translates to:
  /// **'Schneller'**
  String get tempoFaster;

  /// No description provided for @tapTempo.
  ///
  /// In de, this message translates to:
  /// **'Tempo tippen'**
  String get tapTempo;

  /// No description provided for @tempoReset.
  ///
  /// In de, this message translates to:
  /// **'Zurück zum Tempo des Songs'**
  String get tempoReset;

  /// No description provided for @clickNoAudioLive.
  ///
  /// In de, this message translates to:
  /// **'Kein Audio für den Klick'**
  String get clickNoAudioLive;

  /// No description provided for @settingsSongMap.
  ///
  /// In de, this message translates to:
  /// **'Song-Landkarte statt Akkorde'**
  String get settingsSongMap;

  /// No description provided for @settingsSongMapHint.
  ///
  /// In de, this message translates to:
  /// **'Der Live-Modus zeigt die Teile des Songs mit einem Stichwort aus dem Text und den Schlagzeug-Notizen.'**
  String get settingsSongMapHint;

  /// No description provided for @songMapEmpty.
  ///
  /// In de, this message translates to:
  /// **'Dieser Song hat keine Teile (Verse, Chorus, …) für eine Song-Landkarte.'**
  String get songMapEmpty;

  /// No description provided for @songMapNoTempo.
  ///
  /// In de, this message translates to:
  /// **'Kein Tempo für diesen Song'**
  String get songMapNoTempo;

  /// No description provided for @settingsLiveAppearance.
  ///
  /// In de, this message translates to:
  /// **'Aussehen auf der Bühne'**
  String get settingsLiveAppearance;

  /// No description provided for @settingsLiveAppearanceHint.
  ///
  /// In de, this message translates to:
  /// **'Live-Modus unabhängig vom App-Design. Schwarz spart Strom auf OLED-Bildschirmen.'**
  String get settingsLiveAppearanceHint;

  /// No description provided for @liveAppearanceApp.
  ///
  /// In de, this message translates to:
  /// **'Wie App'**
  String get liveAppearanceApp;

  /// No description provided for @liveAppearanceDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get liveAppearanceDark;

  /// No description provided for @liveAppearanceBlack.
  ///
  /// In de, this message translates to:
  /// **'Schwarz'**
  String get liveAppearanceBlack;

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
  /// **'setDING läuft lokal auf diesem Gerät. Alle Daten sind offline verfügbar.'**
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
  /// **'Pre-chorus'**
  String get sectionPreChorus;

  /// No description provided for @sectionPostChorus.
  ///
  /// In de, this message translates to:
  /// **'Post-chorus'**
  String get sectionPostChorus;

  /// No description provided for @sectionInterlude.
  ///
  /// In de, this message translates to:
  /// **'Interlude'**
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

  /// No description provided for @sectionEnding.
  ///
  /// In de, this message translates to:
  /// **'Ending'**
  String get sectionEnding;

  /// No description provided for @sectionTurnaround.
  ///
  /// In de, this message translates to:
  /// **'Turnaround'**
  String get sectionTurnaround;

  /// No description provided for @sectionVamp.
  ///
  /// In de, this message translates to:
  /// **'Vamp'**
  String get sectionVamp;

  /// No description provided for @sectionRefrain.
  ///
  /// In de, this message translates to:
  /// **'Refrain'**
  String get sectionRefrain;

  /// No description provided for @sectionBreakdown.
  ///
  /// In de, this message translates to:
  /// **'Breakdown'**
  String get sectionBreakdown;

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

  /// No description provided for @searchMatchCase.
  ///
  /// In de, this message translates to:
  /// **'Gross-/Kleinschreibung beachten'**
  String get searchMatchCase;

  /// No description provided for @replaceToggle.
  ///
  /// In de, this message translates to:
  /// **'Ersetzen'**
  String get replaceToggle;

  /// No description provided for @replaceWith.
  ///
  /// In de, this message translates to:
  /// **'Ersetzen durch'**
  String get replaceWith;

  /// No description provided for @replace.
  ///
  /// In de, this message translates to:
  /// **'Ersetzen'**
  String get replace;

  /// No description provided for @replaceAll.
  ///
  /// In de, this message translates to:
  /// **'Alle ersetzen'**
  String get replaceAll;

  /// No description provided for @replacedCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 ersetzt} other{{count} ersetzt}}'**
  String replacedCount(int count);

  /// No description provided for @convertChordsOverLyrics.
  ///
  /// In de, this message translates to:
  /// **'Akkorde über Text umwandeln'**
  String get convertChordsOverLyrics;

  /// No description provided for @pastedChordsOverLyrics.
  ///
  /// In de, this message translates to:
  /// **'Der eingefügte Text hat Akkorde über dem Liedtext.'**
  String get pastedChordsOverLyrics;

  /// No description provided for @convert.
  ///
  /// In de, this message translates to:
  /// **'Umwandeln'**
  String get convert;

  /// No description provided for @convertCcliGrids.
  ///
  /// In de, this message translates to:
  /// **'Taktzeilen in Chord-Grid umwandeln'**
  String get convertCcliGrids;

  /// No description provided for @ccliGridsHint.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Ein Block mit Taktzeilen kann} other{{count} Blöcke mit Taktzeilen können}} als Chord-Grid dargestellt werden.'**
  String ccliGridsHint(int count);

  /// No description provided for @hideHint.
  ///
  /// In de, this message translates to:
  /// **'Hinweis ausblenden'**
  String get hideHint;

  /// No description provided for @searchInSong.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get searchInSong;

  /// No description provided for @searchNoMatches.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer'**
  String get searchNoMatches;

  /// No description provided for @searchPrevious.
  ///
  /// In de, this message translates to:
  /// **'Vorheriger Treffer'**
  String get searchPrevious;

  /// No description provided for @searchNext.
  ///
  /// In de, this message translates to:
  /// **'Nächster Treffer'**
  String get searchNext;

  /// No description provided for @searchClose.
  ///
  /// In de, this message translates to:
  /// **'Suche schliessen'**
  String get searchClose;

  /// No description provided for @searchMatchCount.
  ///
  /// In de, this message translates to:
  /// **'{current} von {total}'**
  String searchMatchCount(int current, int total);

  /// No description provided for @editorGroupLines.
  ///
  /// In de, this message translates to:
  /// **'Zeilen'**
  String get editorGroupLines;

  /// No description provided for @redo.
  ///
  /// In de, this message translates to:
  /// **'Wiederholen'**
  String get redo;

  /// No description provided for @moveLinesUp.
  ///
  /// In de, this message translates to:
  /// **'Zeile nach oben'**
  String get moveLinesUp;

  /// No description provided for @moveLinesDown.
  ///
  /// In de, this message translates to:
  /// **'Zeile nach unten'**
  String get moveLinesDown;

  /// No description provided for @moveChordLeft.
  ///
  /// In de, this message translates to:
  /// **'Akkord nach links'**
  String get moveChordLeft;

  /// No description provided for @moveChordRight.
  ///
  /// In de, this message translates to:
  /// **'Akkord nach rechts'**
  String get moveChordRight;

  /// No description provided for @duplicateLines.
  ///
  /// In de, this message translates to:
  /// **'Zeile duplizieren'**
  String get duplicateLines;

  /// No description provided for @deleteLines.
  ///
  /// In de, this message translates to:
  /// **'Zeile löschen'**
  String get deleteLines;

  /// No description provided for @toggleComment.
  ///
  /// In de, this message translates to:
  /// **'Zeile auskommentieren (#)'**
  String get toggleComment;

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
  /// **'Akkord-Grid'**
  String get insertGrid;

  /// No description provided for @insertChorusRecall.
  ///
  /// In de, this message translates to:
  /// **'Chorus wiederholen'**
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

  /// No description provided for @sequenceFromBand.
  ///
  /// In de, this message translates to:
  /// **'Abfolge der Band'**
  String get sequenceFromBand;

  /// No description provided for @bandArrangement.
  ///
  /// In de, this message translates to:
  /// **'Band-Arrangement'**
  String get bandArrangement;

  /// No description provided for @arrangementOf.
  ///
  /// In de, this message translates to:
  /// **'Arrangement von {band}'**
  String arrangementOf(String band);

  /// No description provided for @arrangementBand.
  ///
  /// In de, this message translates to:
  /// **'Band'**
  String get arrangementBand;

  /// No description provided for @arrangementAsWritten.
  ///
  /// In de, this message translates to:
  /// **'Wie im Song'**
  String get arrangementAsWritten;

  /// No description provided for @arrangementKey.
  ///
  /// In de, this message translates to:
  /// **'Tonart {key}'**
  String arrangementKey(String key);

  /// No description provided for @arrangementSequence.
  ///
  /// In de, this message translates to:
  /// **'Abfolge'**
  String get arrangementSequence;

  /// No description provided for @arrangementTempo.
  ///
  /// In de, this message translates to:
  /// **'Tempo'**
  String get arrangementTempo;

  /// No description provided for @arrangementTempoLabel.
  ///
  /// In de, this message translates to:
  /// **'Tempo in BPM (leer = wie im Song)'**
  String get arrangementTempoLabel;

  /// No description provided for @arrangementReset.
  ///
  /// In de, this message translates to:
  /// **'Band-Arrangement auf den Song zurücksetzen'**
  String get arrangementReset;

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
  /// **'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = zweimal'**
  String get sequenceAbbreviations;

  /// No description provided for @sequenceEmpty.
  ///
  /// In de, this message translates to:
  /// **'Tippe unten auf die Teile oder ziehe sie hierher, um den Ablauf zusammenzustellen.'**
  String get sequenceEmpty;

  /// No description provided for @sequenceReorderHint.
  ///
  /// In de, this message translates to:
  /// **'Teil lange drücken, um ihn an eine andere Stelle zu verschieben.'**
  String get sequenceReorderHint;

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
  /// **'Melde dich an, um Songs und Sets mit deiner Band zu teilen. Ohne Konto funktioniert setDING weiterhin lokal auf diesem Gerät.'**
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

  /// No description provided for @accountPasswordShow.
  ///
  /// In de, this message translates to:
  /// **'Passwort anzeigen'**
  String get accountPasswordShow;

  /// No description provided for @accountPasswordHide.
  ///
  /// In de, this message translates to:
  /// **'Passwort verbergen'**
  String get accountPasswordHide;

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

  /// No description provided for @accountErrorUpdateRequired.
  ///
  /// In de, this message translates to:
  /// **'Diese Version von setDING ist zu alt für den Server. Bitte aktualisiere die App.'**
  String get accountErrorUpdateRequired;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In de, this message translates to:
  /// **'Bitte setDING aktualisieren'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In de, this message translates to:
  /// **'Der Server akzeptiert diese Version nicht mehr, deshalb wird nichts synchronisiert. Deine Änderungen bleiben auf diesem Gerät und werden nach dem Update übertragen.'**
  String get updateRequiredBody;

  /// No description provided for @updateRequiredVersions.
  ///
  /// In de, this message translates to:
  /// **'Installiert: {current}, benötigt: {minimum} oder neuer.'**
  String updateRequiredVersions(String current, String minimum);

  /// No description provided for @updateRequiredHowTo.
  ///
  /// In de, this message translates to:
  /// **'Auf Android aktualisierst du sie in Obtainium, sonst lädst du die neue Version bei den setDING-Releases auf GitHub herunter.'**
  String get updateRequiredHowTo;

  /// No description provided for @updateRequiredReload.
  ///
  /// In de, this message translates to:
  /// **'Neu laden'**
  String get updateRequiredReload;

  /// No description provided for @updateRequiredCopyLink.
  ///
  /// In de, this message translates to:
  /// **'Download-Link kopieren'**
  String get updateRequiredCopyLink;

  /// No description provided for @updateRequiredCopied.
  ///
  /// In de, this message translates to:
  /// **'Link kopiert.'**
  String get updateRequiredCopied;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In de, this message translates to:
  /// **'setDING {version} ist verfügbar'**
  String updateAvailableTitle(String version);

  /// No description provided for @updateAvailableDetails.
  ///
  /// In de, this message translates to:
  /// **'Details'**
  String get updateAvailableDetails;

  /// No description provided for @updateAvailableInstalled.
  ///
  /// In de, this message translates to:
  /// **'Installiert: {current}.'**
  String updateAvailableInstalled(String current);

  /// No description provided for @settingsServer.
  ///
  /// In de, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsServerHint.
  ///
  /// In de, this message translates to:
  /// **'Beim Wechsel wirst du abgemeldet.'**
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
  /// **'Teile den Link, z. B. im Gruppenchat, oder lass den QR-Code scannen. Gültig bis {date}. Du kannst ihn in der Liste der Einladungslinks wieder anzeigen.'**
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

  /// No description provided for @inviteDates.
  ///
  /// In de, this message translates to:
  /// **'Erstellt am {created}, gültig bis {expires}'**
  String inviteDates(String created, String expires);

  /// No description provided for @inviteOrganizationOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur Organisation'**
  String get inviteOrganizationOnly;

  /// No description provided for @inviteShow.
  ///
  /// In de, this message translates to:
  /// **'Link anzeigen'**
  String get inviteShow;

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

  /// No description provided for @inviteErrorNotStored.
  ///
  /// In de, this message translates to:
  /// **'Dieser Link kann nicht mehr angezeigt werden. Erstelle einen neuen.'**
  String get inviteErrorNotStored;

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

  /// No description provided for @openAttachment.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get openAttachment;

  /// No description provided for @imageMissing.
  ///
  /// In de, this message translates to:
  /// **'Das Bild ist nicht auf diesem Gerät.'**
  String get imageMissing;

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

  /// No description provided for @problemTextAfterDirective.
  ///
  /// In de, this message translates to:
  /// **'Zeile {line}: Nach der Direktive steht noch Text; die ganze Zeile wird als Liedtext angezeigt.'**
  String problemTextAfterDirective(int line);

  /// No description provided for @chordProProblemsTooltip.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Stelle im ChordPro wird wahrscheinlich nicht wie gewünscht angezeigt} other{{count} Stellen im ChordPro werden wahrscheinlich nicht wie gewünscht angezeigt}}'**
  String chordProProblemsTooltip(int count);

  /// No description provided for @chordProProblemsShow.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{ChordPro-Problem anzeigen} other{{count} ChordPro-Probleme anzeigen}}'**
  String chordProProblemsShow(int count);

  /// No description provided for @setChordProProblemsTooltip.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song mit ChordPro-Problemen} other{{count} Songs mit ChordPro-Problemen}}'**
  String setChordProProblemsTooltip(int count);

  /// No description provided for @importProblemsTitle.
  ///
  /// In de, this message translates to:
  /// **'Import prüfen'**
  String get importProblemsTitle;

  /// No description provided for @importProblemsMessage.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 importierter Song enthält Stellen} other{{count} importierte Songs enthalten Stellen}}, die wahrscheinlich nicht wie gewünscht angezeigt werden:'**
  String importProblemsMessage(int count);

  /// No description provided for @importProblemItem.
  ///
  /// In de, this message translates to:
  /// **'{title} ({count, plural, =1{1 Stelle} other{{count} Stellen}})'**
  String importProblemItem(String title, int count);

  /// No description provided for @importProblemsHint.
  ///
  /// In de, this message translates to:
  /// **'Die Songs sind in der Songliste markiert. Automatisch korrigiert werden nur Stellen mit eindeutiger Korrektur; den Rest im Editor beheben.'**
  String get importProblemsHint;

  /// No description provided for @songsFixed.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Kein Song korrigiert} =1{1 Song korrigiert} other{{count} Songs korrigiert}}'**
  String songsFixed(int count);

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

  /// No description provided for @fixProblems.
  ///
  /// In de, this message translates to:
  /// **'Automatisch korrigieren'**
  String get fixProblems;

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
  /// **'Titel, Tonart, Tempo und mehr des Songs bearbeiten – für alle'**
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

  /// No description provided for @noSequence.
  ///
  /// In de, this message translates to:
  /// **'Kein Songablauf'**
  String get noSequence;

  /// No description provided for @sequenceChange.
  ///
  /// In de, this message translates to:
  /// **'Songablauf ändern'**
  String get sequenceChange;

  /// No description provided for @sortSongs.
  ///
  /// In de, this message translates to:
  /// **'Sortieren'**
  String get sortSongs;

  /// No description provided for @sortByTitle.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get sortByTitle;

  /// No description provided for @sortByArtist.
  ///
  /// In de, this message translates to:
  /// **'Interpret'**
  String get sortByArtist;

  /// No description provided for @sortByKey.
  ///
  /// In de, this message translates to:
  /// **'Tonart'**
  String get sortByKey;

  /// No description provided for @sortByRecent.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt bearbeitet'**
  String get sortByRecent;

  /// No description provided for @noArtist.
  ///
  /// In de, this message translates to:
  /// **'Ohne Interpret'**
  String get noArtist;

  /// No description provided for @songConflictTooltip.
  ///
  /// In de, this message translates to:
  /// **'Hier und auf dem Server geändert – zum Entscheiden den Song öffnen'**
  String get songConflictTooltip;

  /// No description provided for @pdfOnlyTooltip.
  ///
  /// In de, this message translates to:
  /// **'Nur Noten (PDF), keine Akkorde'**
  String get pdfOnlyTooltip;

  /// No description provided for @upcomingGigTooltip.
  ///
  /// In de, this message translates to:
  /// **'In «{set}» am {date}'**
  String upcomingGigTooltip(String set, String date);

  /// No description provided for @foundInLyrics.
  ///
  /// In de, this message translates to:
  /// **'Im Liedtext gefunden'**
  String get foundInLyrics;

  /// No description provided for @hiddenParts.
  ///
  /// In de, this message translates to:
  /// **'Ausgeblendet (nicht im Ablauf): {parts}'**
  String hiddenParts(String parts);

  /// No description provided for @setsUpcoming.
  ///
  /// In de, this message translates to:
  /// **'Bevorstehend'**
  String get setsUpcoming;

  /// No description provided for @setsUndated.
  ///
  /// In de, this message translates to:
  /// **'Ohne Datum'**
  String get setsUndated;

  /// No description provided for @setsPast.
  ///
  /// In de, this message translates to:
  /// **'Vergangen ({count})'**
  String setsPast(int count);

  /// No description provided for @showPastSets.
  ///
  /// In de, this message translates to:
  /// **'Vergangene Sets anzeigen'**
  String get showPastSets;

  /// No description provided for @hidePastSets.
  ///
  /// In de, this message translates to:
  /// **'Vergangene Sets ausblenden'**
  String get hidePastSets;

  /// No description provided for @nextGig.
  ///
  /// In de, this message translates to:
  /// **'Nächster Auftritt'**
  String get nextGig;

  /// No description provided for @gigInDays.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =0{Heute} =1{Morgen} other{In {days} Tagen}}'**
  String gigInDays(int days);

  /// No description provided for @undo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get undo;

  /// No description provided for @songDeleted.
  ///
  /// In de, this message translates to:
  /// **'«{title}» gelöscht'**
  String songDeleted(String title);

  /// No description provided for @setDeleted.
  ///
  /// In de, this message translates to:
  /// **'Set «{name}» gelöscht'**
  String setDeleted(String name);

  /// No description provided for @attachmentDeleted.
  ///
  /// In de, this message translates to:
  /// **'Anhang «{name}» gelöscht'**
  String attachmentDeleted(String name);

  /// No description provided for @setItemRemoved.
  ///
  /// In de, this message translates to:
  /// **'«{title}» aus dem Set entfernt'**
  String setItemRemoved(String title);

  /// No description provided for @settingsGroupPersonal.
  ///
  /// In de, this message translates to:
  /// **'Persönlich – auf allen deinen Geräten'**
  String get settingsGroupPersonal;

  /// No description provided for @settingsGroupDevice.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät'**
  String get settingsGroupDevice;

  /// No description provided for @settingsGroupAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto & Organisation'**
  String get settingsGroupAccount;

  /// No description provided for @settingsScopePersonalHint.
  ///
  /// In de, this message translates to:
  /// **'Diese Einstellungen gehören zu deinem Konto und gelten auf allen Geräten, auf denen du angemeldet bist.'**
  String get settingsScopePersonalHint;

  /// No description provided for @settingsScopePersonalSignedOutHint.
  ///
  /// In de, this message translates to:
  /// **'Abgemeldet gelten diese Einstellungen nur auf diesem Gerät. Nach dem Anmelden werden sie mit deinem Konto synchronisiert.'**
  String get settingsScopePersonalSignedOutHint;

  /// No description provided for @settingsScopeDeviceHint.
  ///
  /// In de, this message translates to:
  /// **'Diese Einstellungen gelten nur auf diesem Gerät und werden nicht synchronisiert.'**
  String get settingsScopeDeviceHint;

  /// No description provided for @settingsTakenOver.
  ///
  /// In de, this message translates to:
  /// **'Die Einstellungen deines Kontos wurden übernommen.'**
  String get settingsTakenOver;

  /// No description provided for @annotationsDraw.
  ///
  /// In de, this message translates to:
  /// **'Freihand-Notizen zeichnen'**
  String get annotationsDraw;

  /// No description provided for @annotationsShow.
  ///
  /// In de, this message translates to:
  /// **'Notizen anzeigen'**
  String get annotationsShow;

  /// No description provided for @annotationsHide.
  ///
  /// In de, this message translates to:
  /// **'Notizen ausblenden'**
  String get annotationsHide;

  /// No description provided for @annotationPen.
  ///
  /// In de, this message translates to:
  /// **'Stift'**
  String get annotationPen;

  /// No description provided for @annotationHighlighter.
  ///
  /// In de, this message translates to:
  /// **'Leuchtstift'**
  String get annotationHighlighter;

  /// No description provided for @annotationText.
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get annotationText;

  /// No description provided for @annotationTextHint.
  ///
  /// In de, this message translates to:
  /// **'Text eingeben'**
  String get annotationTextHint;

  /// No description provided for @annotationEraser.
  ///
  /// In de, this message translates to:
  /// **'Radierer (ganzer Strich)'**
  String get annotationEraser;

  /// No description provided for @annotationPartialEraser.
  ///
  /// In de, this message translates to:
  /// **'Radierer (Teil eines Strichs)'**
  String get annotationPartialEraser;

  /// No description provided for @annotationLasso.
  ///
  /// In de, this message translates to:
  /// **'Auswählen (Lasso)'**
  String get annotationLasso;

  /// No description provided for @annotationStamps.
  ///
  /// In de, this message translates to:
  /// **'Stempel'**
  String get annotationStamps;

  /// No description provided for @annotationStampsMusic.
  ///
  /// In de, this message translates to:
  /// **'Musikzeichen'**
  String get annotationStampsMusic;

  /// No description provided for @annotationStampsRepeats.
  ///
  /// In de, this message translates to:
  /// **'Wiederholungen'**
  String get annotationStampsRepeats;

  /// No description provided for @annotationStampsCues.
  ///
  /// In de, this message translates to:
  /// **'Hinweise'**
  String get annotationStampsCues;

  /// No description provided for @annotationColor.
  ///
  /// In de, this message translates to:
  /// **'Farbe {number}'**
  String annotationColor(Object number);

  /// No description provided for @annotationSize.
  ///
  /// In de, this message translates to:
  /// **'Strichbreite'**
  String get annotationSize;

  /// No description provided for @annotationSmaller.
  ///
  /// In de, this message translates to:
  /// **'Kleiner'**
  String get annotationSmaller;

  /// No description provided for @annotationLarger.
  ///
  /// In de, this message translates to:
  /// **'Grösser'**
  String get annotationLarger;

  /// No description provided for @annotationDeleteSelection.
  ///
  /// In de, this message translates to:
  /// **'Auswahl löschen'**
  String get annotationDeleteSelection;

  /// No description provided for @annotationUndo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get annotationUndo;

  /// No description provided for @annotationRedo.
  ///
  /// In de, this message translates to:
  /// **'Wiederholen'**
  String get annotationRedo;

  /// No description provided for @annotationMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get annotationMore;

  /// No description provided for @annotationDrawWithFinger.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Finger zeichnen'**
  String get annotationDrawWithFinger;

  /// No description provided for @annotationDone.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get annotationDone;

  /// No description provided for @annotationsDeleteAll.
  ///
  /// In de, this message translates to:
  /// **'Alle Notizen dieses Songs löschen'**
  String get annotationsDeleteAll;

  /// No description provided for @annotationsDeleted.
  ///
  /// In de, this message translates to:
  /// **'Notizen gelöscht'**
  String get annotationsDeleted;

  /// No description provided for @annotationsOtherLayout.
  ///
  /// In de, this message translates to:
  /// **'Für eine andere Ansicht gezeichnet'**
  String get annotationsOtherLayout;

  /// No description provided for @annotationsOtherLayoutLandscape.
  ///
  /// In de, this message translates to:
  /// **'Im Querformat gezeichnet'**
  String get annotationsOtherLayoutLandscape;

  /// No description provided for @annotationsOtherLayoutPortrait.
  ///
  /// In de, this message translates to:
  /// **'Im Hochformat gezeichnet'**
  String get annotationsOtherLayoutPortrait;

  /// No description provided for @annotationsOrphaned.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Notiz ohne ihre Zeile} other{{count} Notizen ohne ihre Zeile}}'**
  String annotationsOrphaned(num count);

  /// No description provided for @annotationsFull.
  ///
  /// In de, this message translates to:
  /// **'Notizen voll: zum Weiterzeichnen etwas löschen'**
  String get annotationsFull;

  /// No description provided for @annotationsNearlyFull.
  ///
  /// In de, this message translates to:
  /// **'Notizen zu {percent} % voll'**
  String annotationsNearlyFull(int percent);

  /// No description provided for @annotationsPanelTitle.
  ///
  /// In de, this message translates to:
  /// **'Freihand-Notizen'**
  String get annotationsPanelTitle;

  /// No description provided for @annotationsPanelShow.
  ///
  /// In de, this message translates to:
  /// **'Meine Notizen anzeigen'**
  String get annotationsPanelShow;

  /// No description provided for @annotationsCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Noch keine: im Live-Modus zeichnen} =1{1 Notiz} other{{count} Notizen}}'**
  String annotationsCount(num count);

  /// No description provided for @settingsShowAnnotations.
  ///
  /// In de, this message translates to:
  /// **'Freihand-Notizen anzeigen'**
  String get settingsShowAnnotations;

  /// No description provided for @settingsShowAnnotationsHint.
  ///
  /// In de, this message translates to:
  /// **'Deine eigenen Zeichnungen auf Songs und Noten'**
  String get settingsShowAnnotationsHint;

  /// No description provided for @settingsShowOutsideSequence.
  ///
  /// In de, this message translates to:
  /// **'Teile ausserhalb des Ablaufs anzeigen'**
  String get settingsShowOutsideSequence;

  /// No description provided for @settingsShowOutsideSequenceHint.
  ///
  /// In de, this message translates to:
  /// **'Im Live-Modus abgeschwächt statt ausgeblendet'**
  String get settingsShowOutsideSequenceHint;

  /// No description provided for @settingsAnnotationFinger.
  ///
  /// In de, this message translates to:
  /// **'Notizen mit dem Finger zeichnen'**
  String get settingsAnnotationFinger;

  /// No description provided for @settingsAnnotationFingerHint.
  ///
  /// In de, this message translates to:
  /// **'Für Geräte ohne Stift; sonst blättern die Finger weiter'**
  String get settingsAnnotationFingerHint;

  /// No description provided for @stampFermata.
  ///
  /// In de, this message translates to:
  /// **'Fermate'**
  String get stampFermata;

  /// No description provided for @stampBreath.
  ///
  /// In de, this message translates to:
  /// **'Atemzeichen'**
  String get stampBreath;

  /// No description provided for @stampCrescendo.
  ///
  /// In de, this message translates to:
  /// **'Crescendo'**
  String get stampCrescendo;

  /// No description provided for @stampDecrescendo.
  ///
  /// In de, this message translates to:
  /// **'Decrescendo'**
  String get stampDecrescendo;

  /// No description provided for @stampRitardando.
  ///
  /// In de, this message translates to:
  /// **'Ritardando'**
  String get stampRitardando;

  /// No description provided for @stampAccent.
  ///
  /// In de, this message translates to:
  /// **'Akzent'**
  String get stampAccent;

  /// No description provided for @stampRepeat.
  ///
  /// In de, this message translates to:
  /// **'{times}× spielen'**
  String stampRepeat(Object times);

  /// No description provided for @stampRepeatStart.
  ///
  /// In de, this message translates to:
  /// **'Wiederholung Anfang'**
  String get stampRepeatStart;

  /// No description provided for @stampRepeatEnd.
  ///
  /// In de, this message translates to:
  /// **'Wiederholung Ende'**
  String get stampRepeatEnd;

  /// No description provided for @stampCoda.
  ///
  /// In de, this message translates to:
  /// **'Coda'**
  String get stampCoda;

  /// No description provided for @stampSegno.
  ///
  /// In de, this message translates to:
  /// **'Segno'**
  String get stampSegno;

  /// No description provided for @stampGlasses.
  ///
  /// In de, this message translates to:
  /// **'Aufpassen'**
  String get stampGlasses;

  /// No description provided for @stampStop.
  ///
  /// In de, this message translates to:
  /// **'Stopp'**
  String get stampStop;

  /// No description provided for @stampEye.
  ///
  /// In de, this message translates to:
  /// **'Hinschauen'**
  String get stampEye;

  /// No description provided for @stampExclamation.
  ///
  /// In de, this message translates to:
  /// **'Wichtig'**
  String get stampExclamation;

  /// No description provided for @stampStar.
  ///
  /// In de, this message translates to:
  /// **'Stern'**
  String get stampStar;

  /// No description provided for @settingsSectionBands.
  ///
  /// In de, this message translates to:
  /// **'Organisation & Bands'**
  String get settingsSectionBands;

  /// No description provided for @settingsCategoryBandsHint.
  ///
  /// In de, this message translates to:
  /// **'Organisationen, Bands, Mitglieder und Einladungen'**
  String get settingsCategoryBandsHint;

  /// No description provided for @settingsBandsJoinHint.
  ///
  /// In de, this message translates to:
  /// **'Mit einem Einladungslink einer Organisation oder Band beitreten.'**
  String get settingsBandsJoinHint;

  /// No description provided for @settingsSectionSongDisplay.
  ///
  /// In de, this message translates to:
  /// **'Songdarstellung'**
  String get settingsSectionSongDisplay;

  /// No description provided for @settingsCategorySongDisplayHint.
  ///
  /// In de, this message translates to:
  /// **'Stile pro Abschnitt: Akkorde, Text, Überschriften, Balken'**
  String get settingsCategorySongDisplayHint;

  /// No description provided for @songDisplayPreview.
  ///
  /// In de, this message translates to:
  /// **'Vorschau'**
  String get songDisplayPreview;

  /// No description provided for @songDisplayPreset.
  ///
  /// In de, this message translates to:
  /// **'Vorlage'**
  String get songDisplayPreset;

  /// No description provided for @songDisplayPresetClassic.
  ///
  /// In de, this message translates to:
  /// **'Klassisch'**
  String get songDisplayPresetClassic;

  /// No description provided for @songDisplayPresetColorCoded.
  ///
  /// In de, this message translates to:
  /// **'Farbcodiert'**
  String get songDisplayPresetColorCoded;

  /// No description provided for @songDisplayPresetChorusFocus.
  ///
  /// In de, this message translates to:
  /// **'Chorus im Fokus'**
  String get songDisplayPresetChorusFocus;

  /// No description provided for @songDisplayPresetSinger.
  ///
  /// In de, this message translates to:
  /// **'Gesang'**
  String get songDisplayPresetSinger;

  /// No description provided for @songDisplayPresetGuitar.
  ///
  /// In de, this message translates to:
  /// **'Gitarre'**
  String get songDisplayPresetGuitar;

  /// No description provided for @songDisplayPresetMinimal.
  ///
  /// In de, this message translates to:
  /// **'Minimal'**
  String get songDisplayPresetMinimal;

  /// No description provided for @songDisplayPresetBlackWhite.
  ///
  /// In de, this message translates to:
  /// **'Schwarz/Weiss'**
  String get songDisplayPresetBlackWhite;

  /// No description provided for @songDisplayPresetCustom.
  ///
  /// In de, this message translates to:
  /// **'Eigene'**
  String get songDisplayPresetCustom;

  /// No description provided for @songDisplayDiscardTitle.
  ///
  /// In de, this message translates to:
  /// **'Eigene Stile verwerfen?'**
  String get songDisplayDiscardTitle;

  /// No description provided for @songDisplayDiscardMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Vorlage «{name}» ersetzt deine angepassten Stile.'**
  String songDisplayDiscardMessage(String name);

  /// No description provided for @songDisplayDiscard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get songDisplayDiscard;

  /// No description provided for @songDisplayFont.
  ///
  /// In de, this message translates to:
  /// **'Schrift'**
  String get songDisplayFont;

  /// No description provided for @songDisplayFontStandard.
  ///
  /// In de, this message translates to:
  /// **'Standard'**
  String get songDisplayFontStandard;

  /// No description provided for @songDisplayFontMonospace.
  ///
  /// In de, this message translates to:
  /// **'Monospace'**
  String get songDisplayFontMonospace;

  /// No description provided for @songDisplaySection.
  ///
  /// In de, this message translates to:
  /// **'Abschnitt'**
  String get songDisplaySection;

  /// No description provided for @songDisplayTypeStandard.
  ///
  /// In de, this message translates to:
  /// **'Standard'**
  String get songDisplayTypeStandard;

  /// No description provided for @songDisplayTypeIntro.
  ///
  /// In de, this message translates to:
  /// **'Intro'**
  String get songDisplayTypeIntro;

  /// No description provided for @songDisplayTypeVerse.
  ///
  /// In de, this message translates to:
  /// **'Verse'**
  String get songDisplayTypeVerse;

  /// No description provided for @songDisplayTypePreChorus.
  ///
  /// In de, this message translates to:
  /// **'Pre-chorus'**
  String get songDisplayTypePreChorus;

  /// No description provided for @songDisplayTypeChorus.
  ///
  /// In de, this message translates to:
  /// **'Chorus'**
  String get songDisplayTypeChorus;

  /// No description provided for @songDisplayTypeBridge.
  ///
  /// In de, this message translates to:
  /// **'Bridge'**
  String get songDisplayTypeBridge;

  /// No description provided for @songDisplayTypeInterlude.
  ///
  /// In de, this message translates to:
  /// **'Interlude'**
  String get songDisplayTypeInterlude;

  /// No description provided for @songDisplayTypeOutro.
  ///
  /// In de, this message translates to:
  /// **'Outro'**
  String get songDisplayTypeOutro;

  /// No description provided for @songDisplayStandardHint.
  ///
  /// In de, this message translates to:
  /// **'Grundstil für alle Abschnitte ohne eigenen Stil und für Abschnitte, die nicht erkannt werden (z. B. Tab, Grid, eigene Namen).'**
  String get songDisplayStandardHint;

  /// No description provided for @songDisplayStyle.
  ///
  /// In de, this message translates to:
  /// **'Stil'**
  String get songDisplayStyle;

  /// No description provided for @songDisplayOwnStyle.
  ///
  /// In de, this message translates to:
  /// **'Eigener Stil'**
  String get songDisplayOwnStyle;

  /// No description provided for @songDisplayLike.
  ///
  /// In de, this message translates to:
  /// **'Wie {name}'**
  String songDisplayLike(String name);

  /// No description provided for @songDisplayInheritsHint.
  ///
  /// In de, this message translates to:
  /// **'Übernimmt alles von: {chain}. Änderungen dort wirken auch hier.'**
  String songDisplayInheritsHint(String chain);

  /// No description provided for @songDisplayChords.
  ///
  /// In de, this message translates to:
  /// **'Akkorde'**
  String get songDisplayChords;

  /// No description provided for @songDisplayLyrics.
  ///
  /// In de, this message translates to:
  /// **'Liedtext'**
  String get songDisplayLyrics;

  /// No description provided for @songDisplayHeading.
  ///
  /// In de, this message translates to:
  /// **'Überschrift'**
  String get songDisplayHeading;

  /// No description provided for @songDisplayBar.
  ///
  /// In de, this message translates to:
  /// **'Einrückungsbalken'**
  String get songDisplayBar;

  /// No description provided for @songDisplayBold.
  ///
  /// In de, this message translates to:
  /// **'Fett'**
  String get songDisplayBold;

  /// No description provided for @songDisplayItalic.
  ///
  /// In de, this message translates to:
  /// **'Kursiv'**
  String get songDisplayItalic;

  /// No description provided for @songDisplaySize.
  ///
  /// In de, this message translates to:
  /// **'Grösse'**
  String get songDisplaySize;

  /// No description provided for @songDisplayColor.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get songDisplayColor;

  /// No description provided for @songDisplayShowHeading.
  ///
  /// In de, this message translates to:
  /// **'Überschrift anzeigen'**
  String get songDisplayShowHeading;

  /// No description provided for @songDisplayShowBar.
  ///
  /// In de, this message translates to:
  /// **'Balken anzeigen'**
  String get songDisplayShowBar;

  /// No description provided for @songDisplayBarWidth.
  ///
  /// In de, this message translates to:
  /// **'Breite'**
  String get songDisplayBarWidth;

  /// No description provided for @songDisplayIndent.
  ///
  /// In de, this message translates to:
  /// **'Einrückung'**
  String get songDisplayIndent;

  /// No description provided for @songDisplayTint.
  ///
  /// In de, this message translates to:
  /// **'Hintergrund tönen'**
  String get songDisplayTint;

  /// No description provided for @songDisplaySizeSmall.
  ///
  /// In de, this message translates to:
  /// **'S'**
  String get songDisplaySizeSmall;

  /// No description provided for @songDisplaySizeMedium.
  ///
  /// In de, this message translates to:
  /// **'M'**
  String get songDisplaySizeMedium;

  /// No description provided for @songDisplaySizeLarge.
  ///
  /// In de, this message translates to:
  /// **'L'**
  String get songDisplaySizeLarge;

  /// No description provided for @songDisplaySizeExtraLarge.
  ///
  /// In de, this message translates to:
  /// **'XL'**
  String get songDisplaySizeExtraLarge;

  /// No description provided for @songDisplayBarThin.
  ///
  /// In de, this message translates to:
  /// **'Dünn'**
  String get songDisplayBarThin;

  /// No description provided for @songDisplayBarMedium.
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get songDisplayBarMedium;

  /// No description provided for @songDisplayBarWide.
  ///
  /// In de, this message translates to:
  /// **'Breit'**
  String get songDisplayBarWide;

  /// No description provided for @songDisplayIndentNone.
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get songDisplayIndentNone;

  /// No description provided for @songDisplayIndentNormal.
  ///
  /// In de, this message translates to:
  /// **'Normal'**
  String get songDisplayIndentNormal;

  /// No description provided for @songDisplayIndentLarge.
  ///
  /// In de, this message translates to:
  /// **'Gross'**
  String get songDisplayIndentLarge;

  /// No description provided for @songColorAuto.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get songColorAuto;

  /// No description provided for @songColorBlue.
  ///
  /// In de, this message translates to:
  /// **'Blau'**
  String get songColorBlue;

  /// No description provided for @songColorAmber.
  ///
  /// In de, this message translates to:
  /// **'Bernstein'**
  String get songColorAmber;

  /// No description provided for @songColorRed.
  ///
  /// In de, this message translates to:
  /// **'Rot'**
  String get songColorRed;

  /// No description provided for @songColorGreen.
  ///
  /// In de, this message translates to:
  /// **'Grün'**
  String get songColorGreen;

  /// No description provided for @songColorTeal.
  ///
  /// In de, this message translates to:
  /// **'Türkis'**
  String get songColorTeal;

  /// No description provided for @songColorPurple.
  ///
  /// In de, this message translates to:
  /// **'Violett'**
  String get songColorPurple;

  /// No description provided for @songColorPink.
  ///
  /// In de, this message translates to:
  /// **'Pink'**
  String get songColorPink;

  /// No description provided for @songColorGrey.
  ///
  /// In de, this message translates to:
  /// **'Grau'**
  String get songColorGrey;

  /// No description provided for @songColorBlackWhite.
  ///
  /// In de, this message translates to:
  /// **'Schwarz/Weiss'**
  String get songColorBlackWhite;

  /// No description provided for @songDisplayCustomise.
  ///
  /// In de, this message translates to:
  /// **'Anpassen'**
  String get songDisplayCustomise;

  /// No description provided for @songDisplayEditorTitle.
  ///
  /// In de, this message translates to:
  /// **'Songdarstellung anpassen'**
  String get songDisplayEditorTitle;

  /// No description provided for @songDisplayDemoSong.
  ///
  /// In de, this message translates to:
  /// **'Demo-Song'**
  String get songDisplayDemoSong;

  /// No description provided for @songDisplayLibrarySong.
  ///
  /// In de, this message translates to:
  /// **'Song aus der Bibliothek …'**
  String get songDisplayLibrarySong;

  /// No description provided for @songDisplayPickSong.
  ///
  /// In de, this message translates to:
  /// **'Song für die Vorschau'**
  String get songDisplayPickSong;

  /// No description provided for @songDisplayResizePreview.
  ///
  /// In de, this message translates to:
  /// **'Vorschau grösser oder kleiner ziehen'**
  String get songDisplayResizePreview;

  /// No description provided for @appUpdateInstall.
  ///
  /// In de, this message translates to:
  /// **'Installieren'**
  String get appUpdateInstall;

  /// No description provided for @appUpdateInstallTitle.
  ///
  /// In de, this message translates to:
  /// **'setDING {version} installieren?'**
  String appUpdateInstallTitle(String version);

  /// No description provided for @appUpdateInstallBody.
  ///
  /// In de, this message translates to:
  /// **'setDING wird geschlossen, die neue Version installiert und wieder gestartet. Deine Daten bleiben auf diesem Gerät.'**
  String get appUpdateInstallBody;

  /// No description provided for @appUpdateDownloading.
  ///
  /// In de, this message translates to:
  /// **'Update wird heruntergeladen …'**
  String get appUpdateDownloading;

  /// No description provided for @appUpdateFailed.
  ///
  /// In de, this message translates to:
  /// **'Das Update konnte nicht installiert werden. Bitte versuche es später nochmals.'**
  String get appUpdateFailed;

  /// No description provided for @whatsNewTitle.
  ///
  /// In de, this message translates to:
  /// **'Was ist neu'**
  String get whatsNewTitle;

  /// No description provided for @whatsNewAvailable.
  ///
  /// In de, this message translates to:
  /// **'Neu in setDING {version}'**
  String whatsNewAvailable(String version);

  /// No description provided for @whatsNewShow.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get whatsNewShow;

  /// No description provided for @whatsNewVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String whatsNewVersion(String version);

  /// No description provided for @whatsNewAllChanges.
  ///
  /// In de, this message translates to:
  /// **'Alle Änderungen'**
  String get whatsNewAllChanges;

  /// No description provided for @midiTestTitle.
  ///
  /// In de, this message translates to:
  /// **'MIDI-Test (Prototyp)'**
  String get midiTestTitle;

  /// No description provided for @midiTestTileHint.
  ///
  /// In de, this message translates to:
  /// **'Einen Programmwechsel an ein per USB verbundenes Keyboard senden, z. B. einen Nord Stage 3'**
  String get midiTestTileHint;

  /// No description provided for @midiTestHint.
  ///
  /// In de, this message translates to:
  /// **'Sendet einen Programmwechsel an ein per USB verbundenes Keyboard, um MIDI auf diesem Gerät zu testen. Was das Keyboard sendet, z. B. wenn du darauf ein Programm oder einen Song wählst, erscheint im Protokoll.'**
  String get midiTestHint;

  /// No description provided for @midiTestDevices.
  ///
  /// In de, this message translates to:
  /// **'Geräte'**
  String get midiTestDevices;

  /// No description provided for @midiTestRefresh.
  ///
  /// In de, this message translates to:
  /// **'Erneut suchen'**
  String get midiTestRefresh;

  /// No description provided for @midiTestNoDevices.
  ///
  /// In de, this message translates to:
  /// **'Kein MIDI-Gerät gefunden. Verbinde das Keyboard per USB und suche erneut.'**
  String get midiTestNoDevices;

  /// No description provided for @midiTestConnect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get midiTestConnect;

  /// No description provided for @midiTestDisconnect.
  ///
  /// In de, this message translates to:
  /// **'Trennen'**
  String get midiTestDisconnect;

  /// No description provided for @midiTestConnected.
  ///
  /// In de, this message translates to:
  /// **'Verbunden'**
  String get midiTestConnected;

  /// No description provided for @midiTestChannel.
  ///
  /// In de, this message translates to:
  /// **'MIDI-Kanal'**
  String get midiTestChannel;

  /// No description provided for @midiTestModeNordProgram.
  ///
  /// In de, this message translates to:
  /// **'Nord-Programm'**
  String get midiTestModeNordProgram;

  /// No description provided for @midiTestModeNordSong.
  ///
  /// In de, this message translates to:
  /// **'Nord-Song'**
  String get midiTestModeNordSong;

  /// No description provided for @midiTestModeNordLive.
  ///
  /// In de, this message translates to:
  /// **'Nord Live'**
  String get midiTestModeNordLive;

  /// No description provided for @midiTestModeRaw.
  ///
  /// In de, this message translates to:
  /// **'Rohwerte'**
  String get midiTestModeRaw;

  /// No description provided for @midiTestBank.
  ///
  /// In de, this message translates to:
  /// **'Bank'**
  String get midiTestBank;

  /// No description provided for @midiTestLive.
  ///
  /// In de, this message translates to:
  /// **'Live-Speicher'**
  String get midiTestLive;

  /// No description provided for @midiTestMsb.
  ///
  /// In de, this message translates to:
  /// **'Bank Select MSB (CC 0, 0–127)'**
  String get midiTestMsb;

  /// No description provided for @midiTestLsb.
  ///
  /// In de, this message translates to:
  /// **'Bank Select LSB (CC 32, 0–127)'**
  String get midiTestLsb;

  /// No description provided for @midiTestProgram.
  ///
  /// In de, this message translates to:
  /// **'Programm (1–128)'**
  String get midiTestProgram;

  /// No description provided for @midiTestEmptyNotSent.
  ///
  /// In de, this message translates to:
  /// **'Ein leeres Bank Select wird nicht gesendet.'**
  String get midiTestEmptyNotSent;

  /// No description provided for @midiTestInvalid.
  ///
  /// In de, this message translates to:
  /// **'Werte prüfen'**
  String get midiTestInvalid;

  /// No description provided for @midiTestSend.
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get midiTestSend;

  /// No description provided for @midiTestLog.
  ///
  /// In de, this message translates to:
  /// **'Protokoll'**
  String get midiTestLog;

  /// No description provided for @midiTestCopy.
  ///
  /// In de, this message translates to:
  /// **'Protokoll kopieren'**
  String get midiTestCopy;

  /// No description provided for @midiTestCopied.
  ///
  /// In de, this message translates to:
  /// **'Protokoll kopiert'**
  String get midiTestCopied;

  /// No description provided for @midiTestClear.
  ///
  /// In de, this message translates to:
  /// **'Protokoll leeren'**
  String get midiTestClear;

  /// No description provided for @midiTestSent.
  ///
  /// In de, this message translates to:
  /// **'Gesendet: {bytes}'**
  String midiTestSent(String bytes);

  /// No description provided for @midiTestReceivedCc.
  ///
  /// In de, this message translates to:
  /// **'Empfangen: CC {controller} = {value} (Kanal {channel}) – {bytes}'**
  String midiTestReceivedCc(
    int controller,
    int value,
    int channel,
    String bytes,
  );

  /// No description provided for @midiTestReceivedPc.
  ///
  /// In de, this message translates to:
  /// **'Empfangen: Programmwechsel {number} (Wert {program}, Kanal {channel}) – {bytes}'**
  String midiTestReceivedPc(int number, int program, int channel, String bytes);

  /// No description provided for @midiTestReceivedOther.
  ///
  /// In de, this message translates to:
  /// **'Empfangen: {bytes}'**
  String midiTestReceivedOther(String bytes);

  /// No description provided for @midiTestError.
  ///
  /// In de, this message translates to:
  /// **'Fehler: {message}'**
  String midiTestError(String message);

  /// No description provided for @midiTestModeCc.
  ///
  /// In de, this message translates to:
  /// **'Controller'**
  String get midiTestModeCc;

  /// No description provided for @midiTestController.
  ///
  /// In de, this message translates to:
  /// **'Controller (CC 0–127)'**
  String get midiTestController;

  /// No description provided for @midiTestValue.
  ///
  /// In de, this message translates to:
  /// **'Wert (0–127)'**
  String get midiTestValue;

  /// No description provided for @midiTestCcHint.
  ///
  /// In de, this message translates to:
  /// **'Nord Stage 3 laut midi.guide: CC 2 Live-Modus, CC 3 Song-Modus, CC 5 Song-Teil. Welche Werte was bewirken, gehört zum Test.'**
  String get midiTestCcHint;

  /// No description provided for @midiGuideTitle.
  ///
  /// In de, this message translates to:
  /// **'Geführter Test'**
  String get midiGuideTitle;

  /// No description provided for @midiGuideHint.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf «Senden», schau aufs Display des Nord und tippe an, was passiert ist. Am Nord musst du nichts einstellen. Die Antworten stehen im Protokoll.'**
  String get midiGuideHint;

  /// No description provided for @midiGuideNordSend.
  ///
  /// In de, this message translates to:
  /// **'Nord Stage 3 – senden'**
  String get midiGuideNordSend;

  /// No description provided for @midiGuideNordReceive.
  ///
  /// In de, this message translates to:
  /// **'Nord Stage 3 – empfangen'**
  String get midiGuideNordReceive;

  /// No description provided for @midiGuideMotifSend.
  ///
  /// In de, this message translates to:
  /// **'Motif XF – senden'**
  String get midiGuideMotifSend;

  /// No description provided for @midiGuideMotifReceive.
  ///
  /// In de, this message translates to:
  /// **'Motif XF – empfangen'**
  String get midiGuideMotifReceive;

  /// No description provided for @midiGuideNordReceiveHint.
  ///
  /// In de, this message translates to:
  /// **'Stelle am Nord im MIDI-Menü «Program Change» auf «Send» oder «Send & Receive» und den Kanal hier auf den globalen Kanal des Nord. Wähle dann am Nord irgendein Programm, einen Live-Speicher oder einen Song-Teil, z. B. mit dem Drehregler oder den Modus-Tasten. setDING zeigt, was angekommen ist; tippe an, ob es mit dem Display übereinstimmt. Die Ergebnisse stehen im Protokoll.'**
  String get midiGuideNordReceiveHint;

  /// No description provided for @midiGuideMotifSendHint.
  ///
  /// In de, this message translates to:
  /// **'Stelle am Motif XF unter Utility → MIDI: MIDI IN/OUT auf USB, den Empfang von Bank Select und Program Change ein, den Basic Receive Channel auf den Kanal hier und die Device Number auf «all» oder 1. Tippe auf «Senden», schau aufs Display des Motif und tippe an, was passiert ist. Die Antworten stehen im Protokoll.'**
  String get midiGuideMotifSendHint;

  /// No description provided for @midiGuideMotifReceiveHint.
  ///
  /// In de, this message translates to:
  /// **'Stelle am Motif XF unter Utility → MIDI: MIDI IN/OUT auf USB, das Senden von Bank Select und Program Change ein und den Transmit Channel auf den Kanal hier. Wähle dann am Motif irgendeine Voice oder Performance, auch in verschiedenen Bänken und zweimal in derselben Bank. setDING zeigt, was angekommen ist; tippe an, ob es mit dem Display übereinstimmt. Die Ergebnisse stehen im Protokoll.'**
  String get midiGuideMotifReceiveHint;

  /// No description provided for @midiGuideMotifExpected.
  ///
  /// In de, this message translates to:
  /// **'Der Motif zeigt {name}.'**
  String midiGuideMotifExpected(String name);

  /// No description provided for @midiGuideWaiting.
  ///
  /// In de, this message translates to:
  /// **'Wähle am Keyboard einen Klang …'**
  String get midiGuideWaiting;

  /// No description provided for @midiGuideFreeReceived.
  ///
  /// In de, this message translates to:
  /// **'Empfangen: {name}'**
  String midiGuideFreeReceived(String name);

  /// No description provided for @midiGuideMatches.
  ///
  /// In de, this message translates to:
  /// **'Stimmt mit dem Display'**
  String get midiGuideMatches;

  /// No description provided for @midiGuideNoMatch.
  ///
  /// In de, this message translates to:
  /// **'Stimmt nicht'**
  String get midiGuideNoMatch;

  /// No description provided for @midiGuideFreeResult.
  ///
  /// In de, this message translates to:
  /// **'Empfangen {name} ({values}): {answer}'**
  String midiGuideFreeResult(String name, String values, String answer);

  /// No description provided for @midiGuideChecked.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Noch nichts geprüft} =1{1 Klang geprüft} other{{count} Klänge geprüft}}'**
  String midiGuideChecked(int count);

  /// No description provided for @midiGuideStep.
  ///
  /// In de, this message translates to:
  /// **'Schritt {current} von {total}: {title}'**
  String midiGuideStep(int current, int total, String title);

  /// No description provided for @midiGuideExpected.
  ///
  /// In de, this message translates to:
  /// **'Erwartet: {expected}'**
  String midiGuideExpected(String expected);

  /// No description provided for @midiGuideDone.
  ///
  /// In de, this message translates to:
  /// **'Test fertig. Die Antworten stehen im Protokoll.'**
  String get midiGuideDone;

  /// No description provided for @midiGuideRestart.
  ///
  /// In de, this message translates to:
  /// **'Neu beginnen'**
  String get midiGuideRestart;

  /// No description provided for @midiGuideBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get midiGuideBack;

  /// No description provided for @midiGuideSkip.
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get midiGuideSkip;

  /// No description provided for @midiGuideResult.
  ///
  /// In de, this message translates to:
  /// **'Schritt {current} ({title}): {answer}'**
  String midiGuideResult(int current, String title, String answer);

  /// No description provided for @midiGuideProgram.
  ///
  /// In de, this message translates to:
  /// **'Programm {name}'**
  String midiGuideProgram(String name);

  /// No description provided for @midiGuideProgramExpected.
  ///
  /// In de, this message translates to:
  /// **'Das Nord zeigt {name}.'**
  String midiGuideProgramExpected(String name);

  /// No description provided for @midiGuideLive.
  ///
  /// In de, this message translates to:
  /// **'Live-Speicher {number}'**
  String midiGuideLive(int number);

  /// No description provided for @midiGuideLiveExpected.
  ///
  /// In de, this message translates to:
  /// **'Das Nord zeigt Live {number}.'**
  String midiGuideLiveExpected(int number);

  /// No description provided for @midiGuideSongModeOn.
  ///
  /// In de, this message translates to:
  /// **'Song-Modus ein (CC 3 = 127)'**
  String get midiGuideSongModeOn;

  /// No description provided for @midiGuideSongModeOnExpected.
  ///
  /// In de, this message translates to:
  /// **'Das Nord wechselt in den Song-Modus.'**
  String get midiGuideSongModeOnExpected;

  /// No description provided for @midiGuideSongModeOff.
  ///
  /// In de, this message translates to:
  /// **'Song-Modus aus (CC 3 = 0)'**
  String get midiGuideSongModeOff;

  /// No description provided for @midiGuideSongModeOffExpected.
  ///
  /// In de, this message translates to:
  /// **'Das Nord verlässt den Song-Modus.'**
  String get midiGuideSongModeOffExpected;

  /// No description provided for @midiGuideAnswerAsExpected.
  ///
  /// In de, this message translates to:
  /// **'Wie erwartet'**
  String get midiGuideAnswerAsExpected;

  /// No description provided for @midiGuideAnswerDifferent.
  ///
  /// In de, this message translates to:
  /// **'Etwas anderes'**
  String get midiGuideAnswerDifferent;

  /// No description provided for @midiGuideAnswerNothing.
  ///
  /// In de, this message translates to:
  /// **'Nichts passiert'**
  String get midiGuideAnswerNothing;

  /// No description provided for @midiTestFree.
  ///
  /// In de, this message translates to:
  /// **'Frei senden'**
  String get midiTestFree;

  /// No description provided for @midiTestPage.
  ///
  /// In de, this message translates to:
  /// **'Seite'**
  String get midiTestPage;

  /// No description provided for @midiTestButton.
  ///
  /// In de, this message translates to:
  /// **'Taste'**
  String get midiTestButton;

  /// No description provided for @midiGuideSong.
  ///
  /// In de, this message translates to:
  /// **'Song {song}, Teil {part}'**
  String midiGuideSong(int song, int part);

  /// No description provided for @midiGuideSongExpected.
  ///
  /// In de, this message translates to:
  /// **'Das Nord zeigt Song {song}, Teil {part}.'**
  String midiGuideSongExpected(int song, int part);

  /// No description provided for @midiTestSong.
  ///
  /// In de, this message translates to:
  /// **'Song'**
  String get midiTestSong;

  /// No description provided for @midiTestPart.
  ///
  /// In de, this message translates to:
  /// **'Teil'**
  String get midiTestPart;

  /// No description provided for @settingsDeveloperMode.
  ///
  /// In de, this message translates to:
  /// **'Entwickler-Modus'**
  String get settingsDeveloperMode;

  /// No description provided for @settingsDeveloperModeHint.
  ///
  /// In de, this message translates to:
  /// **'Zeigt die Kategorie «Entwicklung» mit experimentellen Funktionen zum Testen. Für den normalen Gebrauch nicht nötig.'**
  String get settingsDeveloperModeHint;

  /// No description provided for @settingsGroupDevelopment.
  ///
  /// In de, this message translates to:
  /// **'Entwicklung'**
  String get settingsGroupDevelopment;

  /// No description provided for @settingsSectionDevelopment.
  ///
  /// In de, this message translates to:
  /// **'Test-Funktionen'**
  String get settingsSectionDevelopment;

  /// No description provided for @settingsCategoryDevelopmentHint.
  ///
  /// In de, this message translates to:
  /// **'Experimentell, nur zum Testen'**
  String get settingsCategoryDevelopmentHint;

  /// No description provided for @settingsDevelopmentNoteTitle.
  ///
  /// In de, this message translates to:
  /// **'Experimentelle Funktionen'**
  String get settingsDevelopmentNoteTitle;

  /// No description provided for @settingsDevelopmentNote.
  ///
  /// In de, this message translates to:
  /// **'Diese Funktionen sind zum Testen da. Sie können sich ändern, fehlerhaft sein oder wieder verschwinden. Nicht für Auftritte gedacht. Ausblenden mit «Entwickler-Modus» unter Allgemein.'**
  String get settingsDevelopmentNote;

  /// No description provided for @settingsSectionMidi.
  ///
  /// In de, this message translates to:
  /// **'Keyboard (MIDI)'**
  String get settingsSectionMidi;

  /// No description provided for @settingsCategoryMidiHint.
  ///
  /// In de, this message translates to:
  /// **'Programmwechsel an ein per USB verbundenes Keyboard'**
  String get settingsCategoryMidiHint;

  /// No description provided for @settingsMidiEnabled.
  ///
  /// In de, this message translates to:
  /// **'MIDI-Programmwechsel'**
  String get settingsMidiEnabled;

  /// No description provided for @settingsMidiEnabledHint.
  ///
  /// In de, this message translates to:
  /// **'Im Live-Modus wechselt das Keyboard zum Programm, das beim Song hinterlegt ist.'**
  String get settingsMidiEnabledHint;

  /// No description provided for @settingsMidiConnected.
  ///
  /// In de, this message translates to:
  /// **'Verbunden mit {name}'**
  String settingsMidiConnected(String name);

  /// No description provided for @settingsMidiNotConnected.
  ///
  /// In de, this message translates to:
  /// **'Nicht verbunden'**
  String get settingsMidiNotConnected;

  /// No description provided for @settingsMidiOutput.
  ///
  /// In de, this message translates to:
  /// **'Ausgang'**
  String get settingsMidiOutput;

  /// No description provided for @settingsMidiOutputHint.
  ///
  /// In de, this message translates to:
  /// **'Das per USB verbundene Keyboard. setDING verbindet sich von selbst wieder, wenn es eingesteckt wird.'**
  String get settingsMidiOutputHint;

  /// No description provided for @settingsMidiNoDevices.
  ///
  /// In de, this message translates to:
  /// **'Kein MIDI-Gerät gefunden. Verbinde das Keyboard per USB und suche erneut.'**
  String get settingsMidiNoDevices;

  /// No description provided for @settingsMidiSearch.
  ///
  /// In de, this message translates to:
  /// **'Erneut suchen'**
  String get settingsMidiSearch;

  /// No description provided for @settingsMidiOutputMissing.
  ///
  /// In de, this message translates to:
  /// **'{name} (nicht eingesteckt)'**
  String settingsMidiOutputMissing(String name);

  /// No description provided for @settingsMidiProfile.
  ///
  /// In de, this message translates to:
  /// **'Geräteprofil'**
  String get settingsMidiProfile;

  /// No description provided for @settingsMidiProfileHint.
  ///
  /// In de, this message translates to:
  /// **'Wie Keyboard-Programme eingegeben und angezeigt werden. «Allgemein» verwendet Bank Select und Programmnummer und funktioniert mit jedem Keyboard.'**
  String get settingsMidiProfileHint;

  /// No description provided for @midiProfileNordStage3.
  ///
  /// In de, this message translates to:
  /// **'Nord Stage 3'**
  String get midiProfileNordStage3;

  /// No description provided for @midiProfileGeneric.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get midiProfileGeneric;

  /// No description provided for @settingsMidiChannel.
  ///
  /// In de, this message translates to:
  /// **'MIDI-Kanal'**
  String get settingsMidiChannel;

  /// No description provided for @settingsMidiChannelHint.
  ///
  /// In de, this message translates to:
  /// **'Der Kanal, auf dem das Keyboard empfängt.'**
  String get settingsMidiChannelHint;

  /// No description provided for @settingsMidiTakeOver.
  ///
  /// In de, this message translates to:
  /// **'Programme vom Keyboard übernehmen'**
  String get settingsMidiTakeOver;

  /// No description provided for @settingsMidiTakeOverHint.
  ///
  /// In de, this message translates to:
  /// **'Ist im Live-Modus das Keyboard-Programm offen, zeigt setDING den Klang, den du am Keyboard wählst, und übernimmt ihn auf Wunsch in den Song. Das Keyboard muss dafür Bank Select und Program Change senden.'**
  String get settingsMidiTakeOverHint;

  /// No description provided for @settingsMidiTakeOverNordHint.
  ///
  /// In de, this message translates to:
  /// **'Ist im Live-Modus das Keyboard-Programm offen, zeigt setDING den Klang, den du am Nord wählst, und übernimmt ihn auf Wunsch in den Song. Stelle dafür am Nord im MIDI-Menü «Program Change» auf «Send» oder «Send & Receive».'**
  String get settingsMidiTakeOverNordHint;

  /// No description provided for @settingsMidiNordHint.
  ///
  /// In de, this message translates to:
  /// **'Schalte am Nord Stage 3 im MIDI-Menü den Empfang von «Program Change» ein und stelle hier den globalen Kanal des Nord ein. Die Nummerierung der Nord-Songs hängt von der OS-Version des Nord ab (geprüft mit OS 2.54); passt ein Song nicht, verwende das Profil «Allgemein».'**
  String get settingsMidiNordHint;

  /// No description provided for @midiProgramTitle.
  ///
  /// In de, this message translates to:
  /// **'Keyboard-Programm'**
  String get midiProgramTitle;

  /// No description provided for @midiProgramHint.
  ///
  /// In de, this message translates to:
  /// **'Wird im Live-Modus ans Keyboard gesendet, wenn dieser Song an der Reihe ist.'**
  String get midiProgramHint;

  /// No description provided for @midiProgramNone.
  ///
  /// In de, this message translates to:
  /// **'Keines: das Keyboard behält seinen Klang'**
  String get midiProgramNone;

  /// No description provided for @midiProgramChoose.
  ///
  /// In de, this message translates to:
  /// **'Programm wählen'**
  String get midiProgramChoose;

  /// No description provided for @midiProgramPreviewSwitch.
  ///
  /// In de, this message translates to:
  /// **'Beim Auswählen senden'**
  String get midiProgramPreviewSwitch;

  /// No description provided for @midiProgramPreviewHint.
  ///
  /// In de, this message translates to:
  /// **'Jede Auswahl geht sofort ans Keyboard; «Abbrechen» stellt das bisherige Programm wieder her.'**
  String get midiProgramPreviewHint;

  /// No description provided for @midiProgramRemove.
  ///
  /// In de, this message translates to:
  /// **'Programm entfernen'**
  String get midiProgramRemove;

  /// No description provided for @midiProgramTest.
  ///
  /// In de, this message translates to:
  /// **'Test'**
  String get midiProgramTest;

  /// No description provided for @midiProgramTestHint.
  ///
  /// In de, this message translates to:
  /// **'Sendet das Programm einmal ans Keyboard'**
  String get midiProgramTestHint;

  /// No description provided for @midiProgramNotConnected.
  ///
  /// In de, this message translates to:
  /// **'Keyboard nicht verbunden'**
  String get midiProgramNotConnected;

  /// No description provided for @midiProgramOff.
  ///
  /// In de, this message translates to:
  /// **'MIDI-Programmwechsel sind auf diesem Gerät ausgeschaltet (Einstellungen: Keyboard (MIDI)).'**
  String get midiProgramOff;

  /// No description provided for @midiProgramSent.
  ///
  /// In de, this message translates to:
  /// **'An {device} gesendet'**
  String midiProgramSent(String device);

  /// No description provided for @midiProgramSendFailed.
  ///
  /// In de, this message translates to:
  /// **'Das Programm konnte nicht gesendet werden'**
  String get midiProgramSendFailed;

  /// No description provided for @midiProgramKindProgram.
  ///
  /// In de, this message translates to:
  /// **'Programm'**
  String get midiProgramKindProgram;

  /// No description provided for @midiProgramKindLive.
  ///
  /// In de, this message translates to:
  /// **'Live-Speicher'**
  String get midiProgramKindLive;

  /// No description provided for @midiProgramKindSong.
  ///
  /// In de, this message translates to:
  /// **'Song'**
  String get midiProgramKindSong;

  /// No description provided for @midiProgramKindGeneric.
  ///
  /// In de, this message translates to:
  /// **'Andere Werte'**
  String get midiProgramKindGeneric;

  /// No description provided for @midiProgramBank.
  ///
  /// In de, this message translates to:
  /// **'Bank'**
  String get midiProgramBank;

  /// No description provided for @midiProgramPageButton.
  ///
  /// In de, this message translates to:
  /// **'Seite (Zeile) und Taste'**
  String get midiProgramPageButton;

  /// No description provided for @midiProgramSongNumber.
  ///
  /// In de, this message translates to:
  /// **'Song'**
  String get midiProgramSongNumber;

  /// No description provided for @midiProgramPreviousSong.
  ///
  /// In de, this message translates to:
  /// **'Vorheriger Song'**
  String get midiProgramPreviousSong;

  /// No description provided for @midiProgramNextSong.
  ///
  /// In de, this message translates to:
  /// **'Nächster Song'**
  String get midiProgramNextSong;

  /// No description provided for @midiProgramPart.
  ///
  /// In de, this message translates to:
  /// **'Teil'**
  String get midiProgramPart;

  /// No description provided for @midiProgramSongHint.
  ///
  /// In de, this message translates to:
  /// **'Die Nummerierung der Nord-Songs hängt von der OS-Version des Nord ab (geprüft mit OS 2.54). Passt ein Song nicht, verwende in den Einstellungen das Profil «Allgemein».'**
  String get midiProgramSongHint;

  /// No description provided for @midiProgramsTitle.
  ///
  /// In de, this message translates to:
  /// **'Keyboard-Programme'**
  String get midiProgramsTitle;

  /// Above the keyboard programs of a song: the MIDI profile set on this device.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät: {profile}'**
  String midiProgramDevice(String profile);

  /// No description provided for @midiProgramForOtherKeyboard.
  ///
  /// In de, this message translates to:
  /// **'Programm für ein anderes Keyboard'**
  String get midiProgramForOtherKeyboard;

  /// No description provided for @midiProgramUnknownKeyboard.
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Keyboard ({id})'**
  String midiProgramUnknownKeyboard(String id);

  /// No description provided for @midiProgramMsb.
  ///
  /// In de, this message translates to:
  /// **'Bank Select MSB (optional)'**
  String get midiProgramMsb;

  /// No description provided for @midiProgramLsb.
  ///
  /// In de, this message translates to:
  /// **'Bank Select LSB (optional)'**
  String get midiProgramLsb;

  /// No description provided for @midiProgramNumber.
  ///
  /// In de, this message translates to:
  /// **'Programm'**
  String get midiProgramNumber;

  /// No description provided for @midiProgramRange.
  ///
  /// In de, this message translates to:
  /// **'{min}–{max}'**
  String midiProgramRange(int min, int max);

  /// No description provided for @midiProgramOutOfRange.
  ///
  /// In de, this message translates to:
  /// **'Eine Zahl von {min} bis {max} eingeben'**
  String midiProgramOutOfRange(int min, int max);

  /// No description provided for @midiProgramValueNord.
  ///
  /// In de, this message translates to:
  /// **'Programm {name}'**
  String midiProgramValueNord(String name);

  /// No description provided for @midiProfileMotifXf.
  ///
  /// In de, this message translates to:
  /// **'Yamaha Motif XF'**
  String get midiProfileMotifXf;

  /// No description provided for @settingsMidiMotifHint.
  ///
  /// In de, this message translates to:
  /// **'Stelle am Motif XF unter Utility → MIDI: MIDI IN/OUT auf USB, den Empfang von Bank Select und Program Change ein, den Basic Receive Channel auf den Kanal hier und die Device Number auf «all» oder 1. setDING schaltet den Motif vor jedem Programm selbst in den Voice- oder Performance-Modus.'**
  String get settingsMidiMotifHint;

  /// No description provided for @midiProgramKindPerformance.
  ///
  /// In de, this message translates to:
  /// **'Performance'**
  String get midiProgramKindPerformance;

  /// No description provided for @midiProgramKindVoice.
  ///
  /// In de, this message translates to:
  /// **'Voice'**
  String get midiProgramKindVoice;

  /// No description provided for @midiProgramGroup.
  ///
  /// In de, this message translates to:
  /// **'Gruppe'**
  String get midiProgramGroup;

  /// No description provided for @midiProgramMotifNumber.
  ///
  /// In de, this message translates to:
  /// **'Nummer'**
  String get midiProgramMotifNumber;

  /// No description provided for @midiProgramMotifHint.
  ///
  /// In de, this message translates to:
  /// **'Wie auf dem Display des Motif XF, z.B. USR1 A01. setDING schaltet den Motif vor dem Senden in den Voice- oder Performance-Modus.'**
  String get midiProgramMotifHint;

  /// No description provided for @midiProgramValueMotifVoice.
  ///
  /// In de, this message translates to:
  /// **'Voice {name}'**
  String midiProgramValueMotifVoice(String name);

  /// No description provided for @midiProgramValueMotifPerformance.
  ///
  /// In de, this message translates to:
  /// **'Performance {name}'**
  String midiProgramValueMotifPerformance(String name);

  /// No description provided for @midiTestModeMotif.
  ///
  /// In de, this message translates to:
  /// **'Motif XF'**
  String get midiTestModeMotif;

  /// Short form of a program in the keyboard program list (#599): a Nord live memory.
  ///
  /// In de, this message translates to:
  /// **'Live {number}'**
  String midiProgramShortLive(int number);

  /// No description provided for @midiProgramShortSong.
  ///
  /// In de, this message translates to:
  /// **'S{song}:{part}'**
  String midiProgramShortSong(int song, int part);

  /// No description provided for @midiProgramShortPerformance.
  ///
  /// In de, this message translates to:
  /// **'P {name}'**
  String midiProgramShortPerformance(String name);

  /// No description provided for @midiProgramShortGeneric.
  ///
  /// In de, this message translates to:
  /// **'{program} ({msb}/{lsb})'**
  String midiProgramShortGeneric(int program, String msb, String lsb);

  /// No description provided for @midiProgramValueLive.
  ///
  /// In de, this message translates to:
  /// **'Live-Speicher {number}'**
  String midiProgramValueLive(int number);

  /// No description provided for @midiProgramValueSong.
  ///
  /// In de, this message translates to:
  /// **'Song {song}, Teil {part}'**
  String midiProgramValueSong(int song, int part);

  /// No description provided for @midiProgramValueGeneric.
  ///
  /// In de, this message translates to:
  /// **'Programm {program}'**
  String midiProgramValueGeneric(int program);

  /// No description provided for @midiProgramValueMsb.
  ///
  /// In de, this message translates to:
  /// **'MSB {value}'**
  String midiProgramValueMsb(int value);

  /// No description provided for @midiProgramValueLsb.
  ///
  /// In de, this message translates to:
  /// **'LSB {value}'**
  String midiProgramValueLsb(int value);

  /// No description provided for @trash.
  ///
  /// In de, this message translates to:
  /// **'Papierkorb'**
  String get trash;

  /// No description provided for @trashSongsTitle.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Songs'**
  String get trashSongsTitle;

  /// No description provided for @trashSetsTitle.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Sets'**
  String get trashSetsTitle;

  /// No description provided for @trashEmpty.
  ///
  /// In de, this message translates to:
  /// **'Der Papierkorb ist leer. Gelöschte Songs und Sets lassen sich hier {days} Tage lang wiederherstellen.'**
  String trashEmpty(int days);

  /// No description provided for @trashHint.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Songs und Sets lassen sich {days} Tage lang wiederherstellen. Danach werden sie endgültig entfernt.'**
  String trashHint(int days);

  /// No description provided for @trashDeletedOn.
  ///
  /// In de, this message translates to:
  /// **'gelöscht am {date}'**
  String trashDeletedOn(String date);

  /// No description provided for @trashDaysLeft.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =0{letzter Tag} =1{noch 1 Tag} other{noch {days} Tage}}'**
  String trashDaysLeft(int days);

  /// No description provided for @trashRestore.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get trashRestore;

  /// No description provided for @trashRestored.
  ///
  /// In de, this message translates to:
  /// **'«{title}» wiederhergestellt'**
  String trashRestored(String title);

  /// No description provided for @backupExport.
  ///
  /// In de, this message translates to:
  /// **'Bibliothek sichern'**
  String get backupExport;

  /// No description provided for @backupSyncing.
  ///
  /// In de, this message translates to:
  /// **'Mit dem Server synchronisieren …'**
  String get backupSyncing;

  /// No description provided for @backupCollecting.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wird erstellt …'**
  String get backupCollecting;

  /// No description provided for @backupSaved.
  ///
  /// In de, this message translates to:
  /// **'Sicherung gespeichert.'**
  String get backupSaved;

  /// No description provided for @backupFailedTitle.
  ///
  /// In de, this message translates to:
  /// **'Sichern nicht möglich'**
  String get backupFailedTitle;

  /// No description provided for @backupSyncDeferred.
  ///
  /// In de, this message translates to:
  /// **'Der Live-Modus ist offen. Schliesse ihn und versuche es noch einmal.'**
  String get backupSyncDeferred;

  /// No description provided for @backupSyncFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Abgleich mit dem Server ist fehlgeschlagen. Eine Sicherung einer Organisation braucht eine Verbindung, damit sie alles enthält. Versuche es wieder, wenn du online bist.'**
  String get backupSyncFailed;

  /// No description provided for @backupPendingChanges.
  ///
  /// In de, this message translates to:
  /// **'Änderungen auf diesem Gerät sind noch nicht auf dem Server. Warte den Abgleich ab und versuche es noch einmal.'**
  String get backupPendingChanges;

  /// No description provided for @backupConflicts.
  ///
  /// In de, this message translates to:
  /// **'Einige Songs haben einen Konflikt. Löse zuerst die Konflikte.'**
  String get backupConflicts;

  /// No description provided for @backupMissingFiles.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht alle Anhänge sind heruntergeladen. Warte den Download ab und versuche es noch einmal.'**
  String get backupMissingFiles;

  /// No description provided for @backupFileMissing.
  ///
  /// In de, this message translates to:
  /// **'Der Anhang «{name}» von «{song}» konnte nicht geladen werden.'**
  String backupFileMissing(String name, String song);

  /// No description provided for @backupInvalid.
  ///
  /// In de, this message translates to:
  /// **'Diese Datei ist keine setDING-Sicherung.'**
  String get backupInvalid;

  /// No description provided for @backupNewer.
  ///
  /// In de, this message translates to:
  /// **'Diese Sicherung stammt von einer neueren setDING-Version. Aktualisiere die App, um sie zu importieren.'**
  String get backupNewer;

  /// No description provided for @backupImportTitle.
  ///
  /// In de, this message translates to:
  /// **'Sicherung importieren'**
  String get backupImportTitle;

  /// No description provided for @backupImportSummary.
  ///
  /// In de, this message translates to:
  /// **'Sicherung von «{library}»: {songs, plural, =1{1 Song} other{{songs} Songs}}, {sets, plural, =1{1 Set} other{{sets} Sets}}.'**
  String backupImportSummary(String library, int songs, int sets);

  /// No description provided for @backupImportCopyHint.
  ///
  /// In de, this message translates to:
  /// **'Alles wird als Kopie in die aktuelle Bibliothek importiert. Bestehendes wird nicht verändert.'**
  String get backupImportCopyHint;

  /// No description provided for @backupImportIdentical.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song ist} other{{count} Songs sind}} schon mit gleichem Text hier und werden so verwendet.'**
  String backupImportIdentical(int count);

  /// No description provided for @backupImportDiffering.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song gibt} other{{count} Songs gibt}} es hier mit anderem Text:'**
  String backupImportDiffering(int count);

  /// No description provided for @backupKeepExisting.
  ///
  /// In de, this message translates to:
  /// **'Bestehende Songs behalten'**
  String get backupKeepExisting;

  /// No description provided for @backupAddAll.
  ///
  /// In de, this message translates to:
  /// **'Als zusätzliche Songs importieren'**
  String get backupAddAll;

  /// No description provided for @backupImportSetsTo.
  ///
  /// In de, this message translates to:
  /// **'Sets kommen nach:'**
  String get backupImportSetsTo;

  /// No description provided for @backupBandSets.
  ///
  /// In de, this message translates to:
  /// **'{band} ({count, plural, =1{1 Set} other{{count} Sets}})'**
  String backupBandSets(String band, int count);

  /// No description provided for @backupSkipSets.
  ///
  /// In de, this message translates to:
  /// **'Nicht importieren'**
  String get backupSkipSets;

  /// No description provided for @backupImportStart.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get backupImportStart;

  /// No description provided for @backupImportDone.
  ///
  /// In de, this message translates to:
  /// **'Sicherung importiert'**
  String get backupImportDone;

  /// No description provided for @backupResultSongs.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song importiert} other{{count} Songs importiert}}'**
  String backupResultSongs(int count);

  /// No description provided for @backupResultIdentical.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song war schon hier} other{{count} Songs waren schon hier}}'**
  String backupResultIdentical(int count);

  /// No description provided for @backupResultKept.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 bestehender Song behalten} other{{count} bestehende Songs behalten}}'**
  String backupResultKept(int count);

  /// No description provided for @backupResultSets.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Sets} =1{1 Set} other{{count} Sets}} importiert'**
  String backupResultSets(int count);

  /// No description provided for @backupResultFiles.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Anhang} other{{count} Anhänge}}'**
  String backupResultFiles(int count);

  /// No description provided for @backupResultAdditional.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Diesen Song gibt es jetzt zweimal. Vergleiche ihn mit dem bestehenden und lösche den, den du nicht brauchst:} other{Diese Songs gibt es jetzt zweimal. Vergleiche sie mit den bestehenden und lösche die, die du nicht brauchst:}}'**
  String backupResultAdditional(int count);

  /// No description provided for @bandDelete.
  ///
  /// In de, this message translates to:
  /// **'Band löschen'**
  String get bandDelete;

  /// No description provided for @bandDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'{band} löschen?'**
  String bandDeleteTitle(String band);

  /// No description provided for @bandDeleteMessage.
  ///
  /// In de, this message translates to:
  /// **'Ihre Sets, Band-Arrangements und Mitgliedschaften werden mitgelöscht und ihre offenen Einladungen widerrufen. Die Songs bleiben in der Bibliothek der Organisation. Admins der Organisation können die Band {days} Tage lang aus dem Papierkorb wiederherstellen. Für eine Kopie ausserhalb von setDING sichere vorher die Bibliothek.'**
  String bandDeleteMessage(int days);

  /// No description provided for @bandDeleteSets.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{keine Sets} =1{1 Set} other{{count} Sets}}'**
  String bandDeleteSets(int count);

  /// No description provided for @bandDeleteMembers.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{keine Mitglieder} =1{1 Mitglied} other{{count} Mitglieder}}'**
  String bandDeleteMembers(int count);

  /// No description provided for @bandDeleteInvites.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{keine offenen Einladungen} =1{1 offene Einladung} other{{count} offene Einladungen}}'**
  String bandDeleteInvites(int count);

  /// No description provided for @bandDeleteLastBand.
  ///
  /// In de, this message translates to:
  /// **'Das ist die letzte Band der Organisation. Die Organisation und ihre Song-Bibliothek bleiben bestehen.'**
  String get bandDeleteLastBand;

  /// No description provided for @bandDeleteConfirmName.
  ///
  /// In de, this message translates to:
  /// **'Zum Bestätigen «{band}» eintippen'**
  String bandDeleteConfirmName(String band);

  /// No description provided for @bandDeleted.
  ///
  /// In de, this message translates to:
  /// **'{band} gelöscht'**
  String bandDeleted(String band);

  /// No description provided for @trashBandsTitle.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Bands'**
  String get trashBandsTitle;

  /// No description provided for @trashBandsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine gelöschten Bands. Gelöschte Bands lassen sich hier {days} Tage lang wiederherstellen.'**
  String trashBandsEmpty(int days);

  /// No description provided for @trashBandsHint.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Bands lassen sich mit ihren Sets, Arrangements und Mitgliedern {days} Tage lang wiederherstellen. Danach werden sie endgültig entfernt.'**
  String trashBandsHint(int days);

  /// No description provided for @bandsGone.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{{names} ist für dich nicht mehr verfügbar: Die Band wurde gelöscht oder du bist kein Mitglied mehr.} other{{names} sind für dich nicht mehr verfügbar: Die Bands wurden gelöscht oder du bist kein Mitglied mehr.}}'**
  String bandsGone(int count, String names);

  /// No description provided for @backupAll.
  ///
  /// In de, this message translates to:
  /// **'Alles sichern'**
  String get backupAll;

  /// No description provided for @backupAllName.
  ///
  /// In de, this message translates to:
  /// **'alles'**
  String get backupAllName;

  /// No description provided for @backupAllHint.
  ///
  /// In de, this message translates to:
  /// **'Deine Bibliotheken mit Songs, Sets und Anhängen, deine persönlichen Anpassungen und Notizen und deine Einstellungen in einer Datei.'**
  String get backupAllHint;

  /// No description provided for @backupNever.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Gerät noch nie gesichert.'**
  String get backupNever;

  /// No description provided for @backupLast.
  ///
  /// In de, this message translates to:
  /// **'Letzte Sicherung: {date}'**
  String backupLast(String date);

  /// No description provided for @backupRestore.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wiederherstellen'**
  String get backupRestore;

  /// No description provided for @backupRestoreHint.
  ///
  /// In de, this message translates to:
  /// **'Importiert eine Sicherungsdatei als Kopie. Bestehendes wird nicht verändert.'**
  String get backupRestoreHint;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wiederherstellen'**
  String get backupRestoreTitle;

  /// No description provided for @backupLibraryTo.
  ///
  /// In de, this message translates to:
  /// **'«{library}» ({songs, plural, =1{1 Song} other{{songs} Songs}}, {sets, plural, =1{1 Set} other{{sets} Sets}}) nach'**
  String backupLibraryTo(String library, int songs, int sets);

  /// No description provided for @backupImportDifferingAll.
  ///
  /// In de, this message translates to:
  /// **'Songs, die es hier mit anderem Text gibt:'**
  String get backupImportDifferingAll;

  /// No description provided for @backupRestorePersonal.
  ///
  /// In de, this message translates to:
  /// **'Meine persönlichen Anpassungen und Notizen wiederherstellen'**
  String get backupRestorePersonal;

  /// No description provided for @backupPersonalOf.
  ///
  /// In de, this message translates to:
  /// **'{library}: {count, plural, =1{1 Song} other{{count} Songs}}'**
  String backupPersonalOf(String library, int count);

  /// No description provided for @backupRestoreSettings.
  ///
  /// In de, this message translates to:
  /// **'Meine Einstellungen übernehmen'**
  String get backupRestoreSettings;

  /// No description provided for @backupRestoreSettingsHint.
  ///
  /// In de, this message translates to:
  /// **'Ersetzt deine aktuellen Einstellungen durch die der Sicherung.'**
  String get backupRestoreSettingsHint;

  /// No description provided for @backupRestoreStart.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get backupRestoreStart;

  /// No description provided for @backupRestoreDone.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wiederhergestellt'**
  String get backupRestoreDone;

  /// No description provided for @backupResultPersonal.
  ///
  /// In de, this message translates to:
  /// **'Persönliche Anpassungen und Notizen von {count, plural, =1{1 Song} other{{count} Songs}} wiederhergestellt'**
  String backupResultPersonal(int count);

  /// No description provided for @backupResultSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen übernommen'**
  String get backupResultSettings;

  /// No description provided for @backupReminder.
  ///
  /// In de, this message translates to:
  /// **'Deine Bibliothek auf diesem Gerät ist seit {days} Tagen nicht gesichert.'**
  String backupReminder(int days);

  /// No description provided for @backupReminderAction.
  ///
  /// In de, this message translates to:
  /// **'Sichern'**
  String get backupReminderAction;

  /// No description provided for @orgClose.
  ///
  /// In de, this message translates to:
  /// **'Organisation schliessen'**
  String get orgClose;

  /// No description provided for @orgCloseTitle.
  ///
  /// In de, this message translates to:
  /// **'{org} schliessen?'**
  String orgCloseTitle(String org);

  /// No description provided for @orgCloseMessage.
  ///
  /// In de, this message translates to:
  /// **'Ihre Bands, Sets, Songs und Anhänge sowie die persönlichen Anpassungen aller zu ihren Songs werden entfernt und ihre Einladungen widerrufen. Die Mitglieder erfahren es beim nächsten Sync. Ihre Admins können sie {days} Tage lang aus dem Papierkorb wiederherstellen; danach wird alles endgültig gelöscht.'**
  String orgCloseMessage(int days);

  /// No description provided for @orgCloseBands.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{keine Bands} =1{1 Band} other{{count} Bands}}'**
  String orgCloseBands(int count);

  /// No description provided for @orgCloseSongs.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{keine Songs} =1{1 Song} other{{count} Songs}}'**
  String orgCloseSongs(int count);

  /// No description provided for @orgClosePeople.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Person} other{{count} Personen}}'**
  String orgClosePeople(int count);

  /// No description provided for @orgCloseBackup.
  ///
  /// In de, this message translates to:
  /// **'Vorher sichern'**
  String get orgCloseBackup;

  /// No description provided for @orgClosed.
  ///
  /// In de, this message translates to:
  /// **'{org} geschlossen'**
  String orgClosed(String org);

  /// No description provided for @orgsClosedTitle.
  ///
  /// In de, this message translates to:
  /// **'Geschlossene Organisationen'**
  String get orgsClosedTitle;

  /// No description provided for @orgsClosedEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine geschlossenen Organisationen. Ihre Admins können geschlossene Organisationen hier {days} Tage lang wiederherstellen.'**
  String orgsClosedEmpty(int days);

  /// No description provided for @orgsClosedHint.
  ///
  /// In de, this message translates to:
  /// **'Geschlossene Organisationen lassen sich mit allem, was darin war, {days} Tage lang wiederherstellen. Danach werden sie endgültig gelöscht.'**
  String orgsClosedHint(int days);

  /// No description provided for @orgClosedOn.
  ///
  /// In de, this message translates to:
  /// **'geschlossen am {date}'**
  String orgClosedOn(String date);

  /// No description provided for @orgClosedBy.
  ///
  /// In de, this message translates to:
  /// **'von {name}'**
  String orgClosedBy(String name);

  /// No description provided for @orgClosedNotice.
  ///
  /// In de, this message translates to:
  /// **'{org} wurde von {name} geschlossen. Ihre Admins können sie {days} Tage lang wiederherstellen.'**
  String orgClosedNotice(String org, String name, int days);

  /// No description provided for @orgClosedNoticeAnonymous.
  ///
  /// In de, this message translates to:
  /// **'{org} wurde geschlossen. Ihre Admins können sie {days} Tage lang wiederherstellen.'**
  String orgClosedNoticeAnonymous(String org, int days);

  /// No description provided for @navOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get navOverview;

  /// No description provided for @overviewNextSet.
  ///
  /// In de, this message translates to:
  /// **'Nächstes Set'**
  String get overviewNextSet;

  /// No description provided for @overviewLastEditedSet.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt bearbeitetes Set'**
  String get overviewLastEditedSet;

  /// No description provided for @overviewSongCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Songs} =1{1 Song} other{{count} Songs}}'**
  String overviewSongCount(int count);

  /// No description provided for @overviewStartLive.
  ///
  /// In de, this message translates to:
  /// **'Live starten'**
  String get overviewStartLive;

  /// No description provided for @overviewOpenSet.
  ///
  /// In de, this message translates to:
  /// **'Set öffnen'**
  String get overviewOpenSet;

  /// No description provided for @overviewTodo.
  ///
  /// In de, this message translates to:
  /// **'Zu erledigen'**
  String get overviewTodo;

  /// No description provided for @overviewTodoProblems.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song mit ChordPro-Problemen} other{{count} Songs mit ChordPro-Problemen}}'**
  String overviewTodoProblems(int count);

  /// No description provided for @overviewTodoConflicts.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song mit Sync-Konflikt} other{{count} Songs mit Sync-Konflikt}}'**
  String overviewTodoConflicts(int count);

  /// No description provided for @overviewTodoSheetMusicOnly.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song nur mit Noten (PDF)} other{{count} Songs nur mit Noten (PDF)}}'**
  String overviewTodoSheetMusicOnly(int count);

  /// No description provided for @attentionProblems.
  ///
  /// In de, this message translates to:
  /// **'ChordPro-Probleme'**
  String get attentionProblems;

  /// No description provided for @attentionConflicts.
  ///
  /// In de, this message translates to:
  /// **'Sync-Konflikte'**
  String get attentionConflicts;

  /// No description provided for @attentionSheetMusicOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur Noten (PDF)'**
  String get attentionSheetMusicOnly;

  /// No description provided for @songsFilterClear.
  ///
  /// In de, this message translates to:
  /// **'Filter entfernen'**
  String get songsFilterClear;

  /// No description provided for @songsFilterEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Songs mehr in diesem Filter.'**
  String get songsFilterEmpty;

  /// No description provided for @playHistory.
  ///
  /// In de, this message translates to:
  /// **'Gespielt'**
  String get playHistory;

  /// No description provided for @playHistoryOf.
  ///
  /// In de, this message translates to:
  /// **'Gespielt von {band}'**
  String playHistoryOf(String band);

  /// No description provided for @playHistoryNone.
  ///
  /// In de, this message translates to:
  /// **'{band} hat diesen Song noch in keinem vergangenen Set gespielt.'**
  String playHistoryNone(String band);

  /// No description provided for @playHistoryTotal.
  ///
  /// In de, this message translates to:
  /// **'gesamt'**
  String get playHistoryTotal;

  /// No description provided for @playHistoryLastYear.
  ///
  /// In de, this message translates to:
  /// **'letzte 12 Monate'**
  String get playHistoryLastYear;

  /// No description provided for @playHistoryLast.
  ///
  /// In de, this message translates to:
  /// **'zuletzt'**
  String get playHistoryLast;

  /// No description provided for @playHistoryFirst.
  ///
  /// In de, this message translates to:
  /// **'Erstmals am {date}'**
  String playHistoryFirst(String date);

  /// No description provided for @playHistoryShowAll.
  ///
  /// In de, this message translates to:
  /// **'Alle {count} anzeigen'**
  String playHistoryShowAll(int count);

  /// No description provided for @playHistoryDiffers.
  ///
  /// In de, this message translates to:
  /// **'Hervorgehoben: eine andere Tonart als heute ({key})'**
  String playHistoryDiffers(String key);

  /// No description provided for @playHistoryApproximate.
  ///
  /// In de, this message translates to:
  /// **'≈ abgeleitet aus dem heutigen Arrangement: das Set hat keine gespeicherten Werte'**
  String get playHistoryApproximate;

  /// No description provided for @keyHistoryLast.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt {key} am {date}'**
  String keyHistoryLast(String key, String date);

  /// No description provided for @keyHistoryMostly.
  ///
  /// In de, this message translates to:
  /// **'meist {key} ({count} von {total})'**
  String keyHistoryMostly(String key, int count, int total);

  /// No description provided for @songLastPlayed.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt gespielt am {date}'**
  String songLastPlayed(String date);

  /// No description provided for @songNeverPlayed.
  ///
  /// In de, this message translates to:
  /// **'Noch nie gespielt'**
  String get songNeverPlayed;

  /// No description provided for @overviewRecentChanges.
  ///
  /// In de, this message translates to:
  /// **'Letzte Änderungen'**
  String get overviewRecentChanges;

  /// No description provided for @overviewShowAll.
  ///
  /// In de, this message translates to:
  /// **'Alle anzeigen'**
  String get overviewShowAll;

  /// No description provided for @recentChangesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Änderungen von anderen in den letzten 30 Tagen.'**
  String get recentChangesEmpty;

  /// No description provided for @changeSongAdded.
  ///
  /// In de, this message translates to:
  /// **'Neuer Song'**
  String get changeSongAdded;

  /// No description provided for @changeSongText.
  ///
  /// In de, this message translates to:
  /// **'Text geändert'**
  String get changeSongText;

  /// No description provided for @changeSongPdf.
  ///
  /// In de, this message translates to:
  /// **'PDF geändert'**
  String get changeSongPdf;

  /// No description provided for @changeSongTextAndPdf.
  ///
  /// In de, this message translates to:
  /// **'Text und PDF geändert'**
  String get changeSongTextAndPdf;

  /// No description provided for @changeSetAdded.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song hinzugefügt} other{{count} Songs hinzugefügt}}'**
  String changeSetAdded(int count);

  /// No description provided for @changeSetRemoved.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Song entfernt} other{{count} Songs entfernt}}'**
  String changeSetRemoved(int count);

  /// No description provided for @changeSetAlsoRemoved.
  ///
  /// In de, this message translates to:
  /// **'{count} entfernt'**
  String changeSetAlsoRemoved(int count);

  /// No description provided for @changeSetSequence.
  ///
  /// In de, this message translates to:
  /// **'Ablauf von {songs} geändert'**
  String changeSetSequence(String songs);

  /// No description provided for @changeQuoted.
  ///
  /// In de, this message translates to:
  /// **'«{title}»'**
  String changeQuoted(String title);

  /// No description provided for @changeBy.
  ///
  /// In de, this message translates to:
  /// **'von {name}'**
  String changeBy(String name);
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
