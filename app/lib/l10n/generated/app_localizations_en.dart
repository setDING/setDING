// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'setDING';

  @override
  String get navSets => 'Sets';

  @override
  String get navSongs => 'Songs';

  @override
  String get navSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Close';

  @override
  String get rename => 'Rename';

  @override
  String get discard => 'Discard';

  @override
  String get untitled => 'Untitled';

  @override
  String errorGeneric(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get songsEmpty =>
      'No songs yet. Create a new song or import ChordPro files.';

  @override
  String get searchSongs => 'Search songs';

  @override
  String get searchClear => 'Clear search';

  @override
  String get newSong => 'New song';

  @override
  String get newPdfSong => 'New PDF song';

  @override
  String get importFiles => 'Import files';

  @override
  String get importTitle => 'Import ChordPro files';

  @override
  String get importDescription =>
      'Supported: .cho, .chordpro, .chopro, .crd, .pro, .txt, ZIP archives containing such files, and setDING backups.';

  @override
  String get importGermanNotation => 'Files use German notation (H/B)';

  @override
  String get importGermanNotationHint =>
      'Chords are converted to international notation on import.';

  @override
  String get importOpenAfter => 'Open after import';

  @override
  String get importOpenAfterHint =>
      'If exactly one song is imported, it opens right away.';

  @override
  String get chooseFiles => 'Choose files';

  @override
  String importResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs imported',
      one: '1 song imported',
      zero: 'No songs imported',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(String files) {
    return 'Skipped: $files';
  }

  @override
  String get deleteSongTitle => 'Delete song?';

  @override
  String deleteSongMessage(String title) {
    return '\"$title\" will be deleted and removed from all sets.';
  }

  @override
  String get attachmentsTooltip => 'Has PDF attachments';

  @override
  String get keyOriginal => 'Original';

  @override
  String get capo => 'Capo';

  @override
  String capoValue(int fret) {
    return 'Capo $fret';
  }

  @override
  String capoLabel(int fret) {
    return 'Capo: $fret';
  }

  @override
  String capoLabelWithKey(int fret, String key) {
    return 'Capo: $fret ($key)';
  }

  @override
  String capoAsInSongLabel(String capo) {
    return '$capo, as in song';
  }

  @override
  String get noCapo => 'No capo';

  @override
  String capoAsInSong(int fret) {
    return 'Capo $fret (as in song)';
  }

  @override
  String get allTags => 'All';

  @override
  String get tagsFilter => 'Tags';

  @override
  String get filterByTags => 'Filter by tags';

  @override
  String tagsFilterMore(String tag, int count) {
    return '$tag +$count';
  }

  @override
  String get notes => 'My notes';

  @override
  String get notesHint => 'Only you see this note.';

  @override
  String get editSource => 'Edit ChordPro';

  @override
  String get attachments => 'Attachments';

  @override
  String get addAttachment => 'Attach file';

  @override
  String get noAttachments => 'No attachments yet.';

  @override
  String attachmentTooLarge(String limit) {
    return 'The file is larger than $limit and cannot be attached.';
  }

  @override
  String get songLinks => 'Sources';

  @override
  String get noSongLinks =>
      'No sources yet. Add recordings on YouTube, Spotify and the like.';

  @override
  String get addSongLink => 'Add link';

  @override
  String get editSongLink => 'Edit link';

  @override
  String get deleteSongLink => 'Remove source';

  @override
  String get deleteSongLinkMessage => 'Remove this source from the song?';

  @override
  String get songLinkUrl => 'Link (URL)';

  @override
  String get songLinkLabel => 'Label (optional)';

  @override
  String get songLinkLabelHint => 'Live 2009';

  @override
  String get songLinkInvalid =>
      'Enter a web link starting with https:// (without |).';

  @override
  String get songLinkFailed => 'The link could not be opened.';

  @override
  String songSelectNumber(String number) {
    return 'CCLI number $number';
  }

  @override
  String get attachmentName => 'Attachment name';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get liveView => 'Show in live mode';

  @override
  String get liveViewChordPro => 'ChordPro text';

  @override
  String get exportSong => 'Export';

  @override
  String get exported => 'Exported';

  @override
  String get fileSaved => 'Saved';

  @override
  String get exportedOpen => 'Open';

  @override
  String get openFileFailed => 'No app could open the file.';

  @override
  String get playLive => 'Play live';

  @override
  String get live => 'Live';

  @override
  String get chordView => 'Chord view';

  @override
  String get useDeviceSetting => 'As in settings';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get fontLarger => 'Larger text';

  @override
  String get fontSmaller => 'Smaller text';

  @override
  String get fitToPage => 'Fit to page';

  @override
  String get resetAdjustments => 'Reset personal adjustments';

  @override
  String get personalAdjustments => 'Personal adjustments';

  @override
  String get scopePersonal =>
      'Just for you – the song stays unchanged for everyone else.';

  @override
  String get scopeSet => 'For this set – applies to the whole band.';

  @override
  String get scopeBand => 'For the whole band – applies in all its sets.';

  @override
  String get scopeSong =>
      'For the song – changes it for everyone in the organization.';

  @override
  String get keyPickerPersonal => 'My key – just for me';

  @override
  String get keyPickerSet => 'Key in this set – for the whole band';

  @override
  String get keyPickerBand => 'Key of the band – for all its sets';

  @override
  String get editTitle => 'Edit title';

  @override
  String get title => 'Title';

  @override
  String get artist => 'Artist';

  @override
  String get noContent => 'This song has no ChordPro text yet.';

  @override
  String get addChordPro => 'Add ChordPro text';

  @override
  String keyLabel(String key) {
    return 'Key: $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForDegrees =>
      'Nashville numbers and numerals need a key in the song.';

  @override
  String get firstVerseChordsOnly => 'Chords in verse 1 only';

  @override
  String get noVersesForFirstVerseChords =>
      'The song has no further verses with chords.';

  @override
  String get verseChords => 'Chords in verses';

  @override
  String get verseChordsAll => 'Chords in all verses';

  @override
  String get verseChordsStacked => 'Verses stacked';

  @override
  String get chorusesStacked => 'Choruses stacked';

  @override
  String get editorTitleNew => 'New song';

  @override
  String get editorTitleEdit => 'Edit song';

  @override
  String get editorTab => 'Text';

  @override
  String get previewTab => 'Preview';

  @override
  String get insertVerse => 'Insert verse';

  @override
  String get insertChorus => 'Insert chorus';

  @override
  String get insertBridge => 'Insert bridge';

  @override
  String get insertComment => 'Insert comment';

  @override
  String get insertChord => 'Insert chord';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage => 'Your changes have not been saved yet.';

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
  String get setsEmpty => 'No sets yet. Create a set for your next gig.';

  @override
  String get newSet => 'New set';

  @override
  String get editSet => 'Edit set';

  @override
  String get setName => 'Name';

  @override
  String get gigDate => 'Date';

  @override
  String get venue => 'Venue';

  @override
  String get noDate => 'No date';

  @override
  String get pickDate => 'Pick date';

  @override
  String get clearDate => 'Remove date';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String offlineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs not offline',
      one: '1 song not offline',
    );
    return '$_temp0';
  }

  @override
  String get offlineMissingTooltip =>
      'Not all songs and PDFs of this set are on the device. Connect it to the network and wait for the sync.';

  @override
  String syncStale(String time) {
    return 'Last sync with the server: $time. The sets on this device may not be up to date.';
  }

  @override
  String get syncStaleNever =>
      'This device has not synced with the server yet. The sets may not be up to date.';

  @override
  String syncUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes from this device have',
      one: '1 change from this device has',
    );
    return '$_temp0 not reached the server yet.';
  }

  @override
  String get addSongs => 'Add songs';

  @override
  String get pause => 'Break';

  @override
  String get textItem => 'Text';

  @override
  String get markerIconBreak => 'Break';

  @override
  String get markerIconDrinks => 'Drinks';

  @override
  String get markerIconAnnouncement => 'Announcement';

  @override
  String get markerIconMicrophone => 'Speech';

  @override
  String get markerIconGuest => 'Guest';

  @override
  String get markerIconEncore => 'Encore';

  @override
  String get markerIconTransition => 'Transition';

  @override
  String get markerIconSolo => 'Solo';

  @override
  String get markerIconApplause => 'Applause';

  @override
  String get markerIconInstrument => 'Change of instrument';

  @override
  String get markerIconTuning => 'Tuning';

  @override
  String get markerIconClick => 'Click';

  @override
  String get markerIconLight => 'Light';

  @override
  String get markerIconEffects => 'Effects';

  @override
  String get markerIconCelebration => 'Celebration';

  @override
  String get markerIconInfo => 'Note';

  @override
  String get markerIconWarning => 'Attention';

  @override
  String get marker => 'Marker';

  @override
  String get addMarker => 'Add marker';

  @override
  String get editMarker => 'Edit marker';

  @override
  String get markerText => 'Text';

  @override
  String get markerPreview => 'Preview';

  @override
  String get markerGroupBreak => 'Break';

  @override
  String get markerGroupAnnouncement => 'Announcement';

  @override
  String get markerGroupFlow => 'Flow';

  @override
  String get markerGroupStage => 'Stage';

  @override
  String get markerGroupShow => 'Show';

  @override
  String get markerGroupGeneral => 'General';

  @override
  String get setEmpty => 'This set is empty. Add some songs.';

  @override
  String get deleteSetTitle => 'Delete set?';

  @override
  String deleteSetMessage(String name) {
    return '\"$name\" will be deleted. The songs are kept.';
  }

  @override
  String get removeFromSet => 'Remove from set';

  @override
  String get selectSongs => 'Select songs';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'None selected',
    );
    return '$_temp0';
  }

  @override
  String get songMissing => 'Song no longer exists';

  @override
  String liveNext(String title) {
    return 'Next: $title';
  }

  @override
  String get liveWebNotice =>
      'Not offline-safe in the browser – use the app on stage';

  @override
  String liveMidiConnected(String name) {
    return 'Keyboard connected: $name';
  }

  @override
  String get liveMidiNotConnected => 'Keyboard not connected';

  @override
  String get liveMidiSendAgain => 'Send program again';

  @override
  String get liveMidiButton => 'Keyboard program (long press: send again)';

  @override
  String get liveMidiChange => 'Change program';

  @override
  String get liveMidiSameAsPrevious => 'Same as previous song';

  @override
  String liveMidiPreviousProgram(String program, String title) {
    return '$program – from “$title”';
  }

  @override
  String get liveMidiNoPrevious => 'No earlier song with a program';

  @override
  String get liveMidiSaved => 'Keyboard program saved';

  @override
  String get liveMidiRemoved => 'Keyboard program removed';

  @override
  String get liveMidiTakeOverWaiting => 'Choose a sound on the keyboard';

  @override
  String liveMidiTakeOver(String program) {
    return 'Take over: $program';
  }

  @override
  String get liveMidiTakeOverHint =>
      'setDING takes over the program the keyboard sends.';

  @override
  String get liveMidiTakeOverNordHint =>
      'Nothing arriving? On the Nord, set “Program Change” in the MIDI menu to “Send” or “Send & Receive”.';

  @override
  String get liveMidiTakeOverSame => 'This is the song\'s program already';

  @override
  String get liveWakeLockNotice =>
      'The screen may turn off – check the device\'s power settings';

  @override
  String get liveEnd => 'End of set';

  @override
  String get liveSetOverview => 'Set overview';

  @override
  String get liveExit => 'Exit live mode';

  @override
  String get projectionFullScreen => 'Full screen';

  @override
  String get projectionStart => 'Project lyrics';

  @override
  String get projectionTitle => 'Lyrics projection';

  @override
  String get projectionHint =>
      'Open this address in the browser of a device in the same network (projector laptop, TV, OBS). The lyrics follow live mode.';

  @override
  String get projectionLowerThird => 'Lower third (OBS)';

  @override
  String get projectionNoNetwork =>
      'No network found. Connect this device to a Wi-Fi or turn on its hotspot.';

  @override
  String get projectionStop => 'Stop projection';

  @override
  String get projectionLinks => 'Projection: addresses';

  @override
  String get projectionCopyLink => 'Copy address';

  @override
  String get projectionLinkCopied => 'Address copied';

  @override
  String get projectionPrevious => 'Previous slide';

  @override
  String get projectionNext => 'Next slide';

  @override
  String get projectionFollow => 'Follow live mode again';

  @override
  String get projectionBlank => 'Blank the projection';

  @override
  String get projectionUnblank => 'Show the lyrics again';

  @override
  String get projectionNoCopyright =>
      'This song has no copyright and is projected without one.';

  @override
  String get projectionStartFailed => 'The projection could not be started.';

  @override
  String get settingsHeadingProjection => 'Projection';

  @override
  String get settingsProjectionHint =>
      'How the lyrics appear in the browser at the projector. For this device.';

  @override
  String get settingsProjectionColours => 'Colours';

  @override
  String get projectionThemeDark => 'White on black';

  @override
  String get projectionThemeLight => 'Black on white';

  @override
  String get settingsProjectionFont => 'Font';

  @override
  String get projectionFontSans => 'Sans serif';

  @override
  String get projectionFontSerif => 'Serif';

  @override
  String get settingsProjectionAlign => 'Alignment';

  @override
  String get projectionAlignCenter => 'Centred';

  @override
  String get projectionAlignLeft => 'Left';

  @override
  String get settingsProjectionLines => 'Lines per slide';

  @override
  String get settingsProjectionLinesHint =>
      'Longer sections are spread over several slides. For the lower third 2 to 4.';

  @override
  String get settingsProjectionCopyright => 'Copyright';

  @override
  String get projectionCopyrightEvery => 'On every slide';

  @override
  String get projectionCopyrightFirstAndLast => 'On the first and last slide';

  @override
  String get settingsProjectionSecondLanguage => 'Second language';

  @override
  String get settingsProjectionSecondLanguageHint =>
      'When a song has a version in this language, it is projected beside it.';

  @override
  String get projectionSecondLanguageOff => 'None';

  @override
  String get settingsProjectionMarkers => 'Markers as text';

  @override
  String get settingsProjectionMarkersHint =>
      'Shows the text of a marker (e.g. Prayer) instead of a black slide.';

  @override
  String get settingsProjectionPreview => 'Show the next slide';

  @override
  String get settingsProjectionPreviewHint =>
      'Small below the lyrics, for a stage monitor.';

  @override
  String get settingsProjectionTurnsSlides => 'Turning pages moves the slides';

  @override
  String get settingsProjectionTurnsSlidesHint =>
      'While projecting, forward (page turner, keyboard, tap) first goes to the next slide of the song and only after the last one to the next song. Back likewise.';

  @override
  String get projectionRenew => 'New address';

  @override
  String get projectionRenewed =>
      'New address created. The old one no longer works.';

  @override
  String get settingsProjectionAddress => 'New projection address';

  @override
  String get settingsProjectionAddressHint =>
      'The address stays the same on this device, so projector and OBS keep it. A new address locks out old links.';

  @override
  String get settingsProjectionShowLabel => 'Show the section';

  @override
  String get settingsProjectionShowLabelHint =>
      'Small above the lyrics, e.g. “Verse 1” or “Chorus”.';

  @override
  String liveSongPage(int page, int count) {
    return 'Page $page/$count';
  }

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionDisplay => 'Display';

  @override
  String get settingsSectionLive => 'Screen & live mode';

  @override
  String get settingsSectionStorage => 'Storage & info';

  @override
  String get settingsSectionMusician => 'Musician';

  @override
  String get settingsCategoryAccountHint => 'Sign-in, server and sync';

  @override
  String get settingsCategoryGeneralHint => 'Language and theme';

  @override
  String get settingsCategoryMusicianHint =>
      'Instrument, voice, chord diagrams, beat';

  @override
  String get settingsCategoryDisplayHint =>
      'Chord notation, Nashville and numerals, content, chorus, progress';

  @override
  String get settingsCategoryLiveHint =>
      'Font size, fit to screen, columns, page turn';

  @override
  String get settingsCategoryAboutHint => 'Storage, diagnostic log and version';

  @override
  String get settingsInstrument => 'My instrument';

  @override
  String get settingsInstrumentHint =>
      'Used for conditional parts (e.g. guitar only) and for chord diagrams.';

  @override
  String get instrumentGuitar => 'Guitar';

  @override
  String get instrumentUkulele => 'Ukulele';

  @override
  String get instrumentBass => 'Bass';

  @override
  String get instrumentKeyboard => 'Keyboard';

  @override
  String get instrumentVocals => 'Vocals';

  @override
  String get instrumentDrums => 'Drums';

  @override
  String get instrumentOther => 'Other …';

  @override
  String get settingsUserName => 'Voice or role (optional)';

  @override
  String get settingsUserNameHint =>
      'Your instrument already counts. Only needed when a song has parts for single voices or people, e.g. “alto” or “tenor”.';

  @override
  String settingsUserNameIsInstrument(String name) {
    return '“$name” is an instrument. The instrument setting covers it, so you can leave this field empty.';
  }

  @override
  String get settingsDiagrams => 'Chord diagrams';

  @override
  String get settingsDiagramsHint =>
      'Shows the fingerings of all chords of the song for your instrument. A song can set this itself with the diagrams directive.';

  @override
  String get settingsBassStrings => 'Bass strings';

  @override
  String get settingsBassStringsHint =>
      'The chord diagrams show a 4-string bass (E-A-D-G) or a 5-string bass with a low B string.';

  @override
  String bassStringCount(int count) {
    return '$count strings';
  }

  @override
  String get diagramsOff => 'Off';

  @override
  String get diagramsTop => 'Top';

  @override
  String get diagramsBottom => 'Bottom';

  @override
  String get notSet => 'Not set';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System language';

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
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'As system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get accentBrand => 'setDING blue';

  @override
  String get accentRed => 'Red';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentPink => 'Pink';

  @override
  String get settingsNotation => 'Chord notation';

  @override
  String get notationInternational => 'International (B, Bb)';

  @override
  String get notationGerman => 'German (H, B)';

  @override
  String get settingsChordView => 'Show chords as';

  @override
  String get settingsChordViewHint =>
      'Chords (Am7), Nashville numbers (6m7) or Roman numerals (vi7). Numbers and numerals need a key in the song.';

  @override
  String get settingsNumeralSpelling => 'Numeral spelling';

  @override
  String get settingsNumeralSpellingHint =>
      'How Roman numerals show the chord: by case, ii7 – V7 – IΔ7, or upper case with the chord symbol, IIm7 – V7 – Imaj7. The chord symbol follows the chord style.';

  @override
  String get numeralSpellingCasing => 'Case';

  @override
  String get numeralSpellingChordSymbol => 'Chord symbol';

  @override
  String get settingsChordStyle => 'Chord style';

  @override
  String get settingsChordStyleHint =>
      'How chords are spelled, e.g. Am7, Cmaj7, Em7b5 (standard) or A−7, CΔ7, Eø7 (jazz). The song itself is not changed.';

  @override
  String get chordStyleAsWritten => 'As written';

  @override
  String get chordStyleStandard => 'Standard';

  @override
  String get chordStyleJazz => 'Jazz';

  @override
  String get settingsChordSuperscript => 'Raise extensions';

  @override
  String get settingsChordSuperscriptHint =>
      'Show extensions and alterations smaller and raised, e.g. C⁷. Needs the standard or jazz style.';

  @override
  String get settingsDisplayMode => 'Content';

  @override
  String get displayLyricsAndChords => 'Lyrics and chords';

  @override
  String get displayLyricsOnly => 'Lyrics only';

  @override
  String get settingsFontSize => 'Font size';

  @override
  String get settingsColumns => 'Columns';

  @override
  String get columnsAuto => 'Automatic';

  @override
  String get columnsOne => 'One';

  @override
  String get columnsTwo => 'Two';

  @override
  String get settingsPageTurn => 'Page turn';

  @override
  String get pageTurnFull => 'Full page';

  @override
  String get pageTurnHalf => 'Half page';

  @override
  String get settingsAutoFit => 'Fit song to screen';

  @override
  String get settingsAutoFitHint =>
      'The whole song fits on the screen without scrolling. Sections are arranged in columns automatically and the text is as large as possible.';

  @override
  String get settingsColumnsHint =>
      'When fitting to the screen, the highest number of columns allowed.';

  @override
  String get columnsThree => 'Three';

  @override
  String get settingsChorusRepeat => 'Repeated chorus';

  @override
  String get settingsChorusRepeatHint =>
      'Automatic: a repeated chorus is shown as a short label only if the song would otherwise not fit well on the screen.';

  @override
  String get chorusRepeatAuto => 'Automatic';

  @override
  String get chorusRepeatFull => 'Show in full';

  @override
  String get chorusRepeatLabel => 'Label only';

  @override
  String get settingsPageTurnHint =>
      'Tap the left or right side of the screen to go back or forward. Page turner (foot pedal) and keyboard: right arrow, down arrow, Page Down and Space forward, left arrow, up arrow and Page Up back. With a beat (tempo and beat or click switched on), holding forward or pressing Enter starts and stops it.';

  @override
  String get settingsSetProgress => 'Progress bar of the set';

  @override
  String get settingsSetProgressHint =>
      'A thin bar above the bottom bar shows the songs of the set and the pages of the current song: the current page in the accent colour, pages still to come in a lighter tone. Markers such as breaks are dashed.';

  @override
  String get settingsBeatSection => 'Beat and click';

  @override
  String get settingsBeatSectionHint =>
      'Tempo and time signature of the song, or the tempo of the band\'s arrangement. On by default when your instrument is drums.';

  @override
  String get settingsBeatDisplay => 'Beat display';

  @override
  String get settingsBeatDisplayHint =>
      'Dots next to tempo and time signature light up on every beat; the count-in shows large numbers.';

  @override
  String get settingsEdgeFlash => 'Flash the edge of the screen';

  @override
  String get settingsEdgeFlashHint =>
      'The edge flashes on every beat, the 1 in another colour – visible from the corner of the eye.';

  @override
  String get settingsClick => 'Click';

  @override
  String get settingsClickHint =>
      'Plays a click on the device\'s audio output, e.g. into the in-ear mix.';

  @override
  String get settingsClickStart => 'Start';

  @override
  String get settingsClickStartHint =>
      'Manually: tap the tempo, hold the forward pedal or press Enter. Turning to another song of the set stops the beat.';

  @override
  String get clickStartAutomatic => 'With each song';

  @override
  String get clickStartManual => 'Manually';

  @override
  String get settingsClickDuration => 'Duration';

  @override
  String get clickDurationSong => 'Whole song';

  @override
  String get clickDurationCountIn => 'Count-in only';

  @override
  String get settingsClickInBackground => 'In the background';

  @override
  String get settingsClickInBackgroundHint =>
      'When the app is minimised, another app is opened or the screen is locked.';

  @override
  String get clickInBackgroundStop => 'Stop';

  @override
  String get clickInBackgroundKeepPlaying => 'Keep playing';

  @override
  String get settingsCountIn => 'Count-in';

  @override
  String get countInOff => 'Off';

  @override
  String get countInOneBar => '1 bar';

  @override
  String get countInTwoBars => '2 bars';

  @override
  String get settingsClickVolume => 'Volume';

  @override
  String get settingsClickAccent => 'Accent on the 1';

  @override
  String get settingsClickSound => 'Sound';

  @override
  String get clickSoundClick => 'Click';

  @override
  String get clickSoundWoodblock => 'Woodblock';

  @override
  String get clickSoundBeep => 'Beep';

  @override
  String get settingsClickSubdivision => 'Subdivisions';

  @override
  String get settingsClickSubdivisionHint =>
      'Quieter clicks between the beats. Each song can have its own in its personal adjustments.';

  @override
  String get subdivisionOff => 'Off';

  @override
  String get subdivisionEighths => 'Eighths';

  @override
  String get subdivisionSixteenths => 'Sixteenths';

  @override
  String get subdivisionTriplets => 'Triplets';

  @override
  String clickSubdivisionAsInSettings(String value) {
    return 'As in the settings ($value)';
  }

  @override
  String get clickGrouping => 'Grouping';

  @override
  String get clickGroupingNone => 'No groups';

  @override
  String clickGroupingAsInSong(String grouping) {
    return 'As in the song ($grouping)';
  }

  @override
  String get clickGroupingHint =>
      'Accented beats of an odd meter, only for you.';

  @override
  String get settingsAudioLatency => 'Audio delay';

  @override
  String get settingsAudioLatencyHint =>
      'Shifts the display so that it matches what you hear. Wired headphones need little, Bluetooth headphones 100–300 ms.';

  @override
  String audioLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get audioLatencyCalibrate => 'Measure the audio delay';

  @override
  String get audioLatencyCalibrateTitle => 'Measure the audio delay';

  @override
  String get audioLatencyCalibrateHint =>
      'Put on the headphones you use on stage and tap along with every beat of the click.';

  @override
  String get audioLatencyTap => 'Tap';

  @override
  String audioLatencyTaps(int count) {
    return '$count taps';
  }

  @override
  String audioLatencyResult(int ms) {
    return 'Measured: $ms ms';
  }

  @override
  String get audioLatencyApply => 'Apply';

  @override
  String get clickNoAudio =>
      'There is no audio output for the click on this device.';

  @override
  String get beatStart => 'Start the beat';

  @override
  String get beatStop => 'Stop the beat';

  @override
  String get beatDisplayLabel => 'Beat';

  @override
  String countInBar(int bar, int count) {
    return 'Bar $bar of $count';
  }

  @override
  String get tempoSlower => 'Slower';

  @override
  String get tempoFaster => 'Faster';

  @override
  String get tapTempo => 'Tap tempo';

  @override
  String get tempoReset => 'Back to the tempo of the song';

  @override
  String get clickNoAudioLive => 'No audio for the click';

  @override
  String get settingsSongMap => 'Song map instead of chords';

  @override
  String get settingsSongMapHint =>
      'Live mode shows the parts of the song with a cue from the lyrics and the drum notes.';

  @override
  String get songMapEmpty =>
      'This song has no parts (verse, chorus, …) to show as a song map.';

  @override
  String get songMapNoTempo => 'No tempo for this song';

  @override
  String get drumPanelSet => 'Set';

  @override
  String get drumPanelSongMap => 'Song map';

  @override
  String get settingsLiveAppearance => 'Appearance on stage';

  @override
  String get settingsLiveAppearanceHint =>
      'Live mode independent of the app theme. Black saves power on OLED screens.';

  @override
  String get liveAppearanceApp => 'As app';

  @override
  String get liveAppearanceDark => 'Dark';

  @override
  String get liveAppearanceBlack => 'Black';

  @override
  String settingsStorageUsed(String size) {
    return 'PDF attachments use $size';
  }

  @override
  String get appMenuEntryAdd => 'Add to application menu';

  @override
  String get appMenuEntryAddHint =>
      'setDING with its icon in your desktop\'s start menu';

  @override
  String get appMenuEntryInstalled => 'In the application menu';

  @override
  String get appMenuEntryInstalledHint =>
      'The start menu starts this AppImage file';

  @override
  String get appMenuEntryRemove => 'Remove';

  @override
  String get appMenuEntryAdded => 'setDING is now in the application menu';

  @override
  String get appMenuEntryRemoved => 'setDING removed from the application menu';

  @override
  String appMenuEntryFailed(String error) {
    return 'Application menu not changed: $error';
  }

  @override
  String get settingsLogCopy => 'Copy diagnostic log';

  @override
  String get settingsLogCopyHint =>
      'The app\'s recent messages, e.g. why a sync failed – to paste into a message to support.';

  @override
  String get settingsLogCopied => 'Diagnostic log copied';

  @override
  String get settingsAbout =>
      'setDING runs locally on this device. All data is available offline.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get lilypondNotice =>
      'This Lilypond notation uses features setDING cannot draw. Source:';

  @override
  String get sequenceLabel => 'Song sequence';

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
  String get editorGroupChords => 'Chords';

  @override
  String get editorGroupSections => 'Sections';

  @override
  String get editorGroupInfo => 'Song info';

  @override
  String get editorGroupText => 'Text';

  @override
  String get editorGroupMore => 'More';

  @override
  String get searchMatchCase => 'Match case';

  @override
  String get replaceToggle => 'Replace';

  @override
  String get replaceWith => 'Replace with';

  @override
  String get replace => 'Replace';

  @override
  String get replaceAll => 'Replace all';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replaced',
      one: '1 replaced',
    );
    return '$_temp0';
  }

  @override
  String get convertChordsOverLyrics => 'Convert chords above lyrics';

  @override
  String get pastedChordsOverLyrics =>
      'The pasted text has chords above the lyrics.';

  @override
  String get convert => 'Convert';

  @override
  String get convertCcliGrids => 'Convert bar lines to chord grids';

  @override
  String ccliGridsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks of bar lines',
      one: 'A block of bar lines',
    );
    return '$_temp0 can be shown as a chord grid.';
  }

  @override
  String get convertCommentHeadings => 'Convert comment headings to sections';

  @override
  String get translateSectionLabels => 'Translate section labels to English';

  @override
  String commentHeadingsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections are',
      one: 'A section is',
    );
    return '$_temp0 marked with a comment such as \"Verse 1\". Converting makes ChordPro sections out of them; the song looks the same.';
  }

  @override
  String get remove => 'Remove';

  @override
  String get ccliFooterHint =>
      'The song ends with the CCLI footer from SongSelect. Removing it keeps song number and copyright in the song details.';

  @override
  String legacyLabelsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count section labels are',
      one: 'A section label is',
    );
    return '$_temp0 in the short form. The ChordPro specification recommends label=\"…\".';
  }

  @override
  String songSelectDirectivesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CCLI directives do',
      one: 'A CCLI directive does',
    );
    return '$_temp0 not follow the ChordPro specification: ccli becomes x_ccli, footer becomes x_ccli_footer, ccli_license is removed.';
  }

  @override
  String importLegacyLabelsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imported songs write',
      one: '1 imported song writes',
    );
    return '$_temp0 section labels in the short form. Converting writes them as label=\"…\", as the ChordPro specification recommends; the songs look the same.';
  }

  @override
  String get convertLabels => 'Convert labels';

  @override
  String songsLabelsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Labels converted in $count songs',
      one: 'Labels converted in 1 song',
      zero: 'No labels converted',
    );
    return '$_temp0';
  }

  @override
  String get hideHint => 'Hide hint';

  @override
  String get searchInSong => 'Search';

  @override
  String get searchNoMatches => 'No matches';

  @override
  String get searchPrevious => 'Previous match';

  @override
  String get searchNext => 'Next match';

  @override
  String get searchClose => 'Close search';

  @override
  String searchMatchCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String get editorGroupLines => 'Lines';

  @override
  String get redo => 'Redo';

  @override
  String get moveLinesUp => 'Move line up';

  @override
  String get moveLinesDown => 'Move line down';

  @override
  String get moveChordLeft => 'Move chord left';

  @override
  String get moveChordRight => 'Move chord right';

  @override
  String get duplicateLines => 'Duplicate line';

  @override
  String get deleteLines => 'Delete line';

  @override
  String get toggleComment => 'Comment out line (#)';

  @override
  String get insertOptionalChord => 'Optional chord';

  @override
  String get insertAnnotation => 'Annotation';

  @override
  String get insertNoChord => 'No chord (N.C.)';

  @override
  String get insertDefine => 'Chord definition';

  @override
  String get insertChordDiagram => 'Chord diagram';

  @override
  String get insertTranspose => 'Transpose';

  @override
  String get insertTab => 'Tab';

  @override
  String get insertGrid => 'Chord grid';

  @override
  String get insertChorusRecall => 'Repeat chorus';

  @override
  String get metaSubtitle => 'Subtitle';

  @override
  String get metaComposer => 'Composer';

  @override
  String get metaLyricist => 'Lyricist';

  @override
  String get metaCopyright => 'Copyright';

  @override
  String get metaTag => 'Tag';

  @override
  String get metaYear => 'Year';

  @override
  String get metaAlbum => 'Album';

  @override
  String get metaDuration => 'Duration';

  @override
  String get metaTempo => 'Tempo (BPM)';

  @override
  String get metaTime => 'Time signature';

  @override
  String get metaKey => 'Key';

  @override
  String get insertCommentItalic => 'Comment (italic)';

  @override
  String get insertCommentBox => 'Comment (box)';

  @override
  String get insertHighlight => 'Highlight';

  @override
  String get insertBold => 'Bold';

  @override
  String get insertItalic => 'Italic';

  @override
  String get insertUnderline => 'Underline';

  @override
  String get insertColour => 'Colour';

  @override
  String get insertColumnBreak => 'Column break';

  @override
  String get insertNewPage => 'Page break';

  @override
  String get insertColumns => 'Columns';

  @override
  String get insertImage => 'Image';

  @override
  String get insertAbc => 'ABC notation';

  @override
  String get insertTextblock => 'Text block';

  @override
  String get insertNewSong => 'Next song in the same file';

  @override
  String get sequenceEdit => 'Song sequence for this set';

  @override
  String get sequenceFromSet => 'Sequence changed for this set';

  @override
  String get sequenceFromBand => 'Sequence of the band';

  @override
  String get bandArrangement => 'Band arrangement';

  @override
  String arrangementOf(String band) {
    return 'Arrangement of $band';
  }

  @override
  String get arrangementBand => 'Band';

  @override
  String get arrangementAsWritten => 'As in the song';

  @override
  String arrangementKey(String key) {
    return 'Key $key';
  }

  @override
  String get arrangementSequence => 'Sequence';

  @override
  String get arrangementTempo => 'Tempo';

  @override
  String get arrangementTempoLabel => 'Tempo in BPM (empty = as in the song)';

  @override
  String get arrangementReset => 'Reset the band arrangement to the song';

  @override
  String sequenceOriginal(Object sequence) {
    return 'In the song: $sequence';
  }

  @override
  String get sequenceNoneInSong => 'The song has no sequence.';

  @override
  String get sequenceRestore => 'Use the song\'s sequence';

  @override
  String get sequenceHint => 'e.g. I, V1, C, V2, PC, C x2, B, O';

  @override
  String get sequenceAbbreviations =>
      'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = twice';

  @override
  String get sequenceEmpty =>
      'Tap the parts below to build the sequence, or drag them here.';

  @override
  String get sequenceReorderHint =>
      'Long-press a part to move it to another position.';

  @override
  String get sequenceSongParts => 'Parts of the song';

  @override
  String get sequenceCommonParts =>
      'Common parts (the song has no sections yet)';

  @override
  String get sequenceClear => 'Clear';

  @override
  String get sequenceAsText => 'Edit as text';

  @override
  String get settingsSectionAccount => 'Account & sync';

  @override
  String get accountSignedOut => 'Not signed in';

  @override
  String get accountSignedOutHint =>
      'Sign in to share songs and sets with your band. Without an account, setDING keeps working locally on this device.';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignUp => 'Create account';

  @override
  String get accountJoin => 'Join with invitation';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutTitle => 'Sign out?';

  @override
  String get accountSignOutMessage => 'Songs and sets on this device are kept.';

  @override
  String get accountSignOutMessageWeb =>
      'The data in this browser is deleted. Songs and sets stay on the server.';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountPasswordConfirm => 'Confirm password';

  @override
  String get accountPasswordShow => 'Show password';

  @override
  String get accountPasswordHide => 'Hide password';

  @override
  String get accountKeepSignedIn => 'Stay signed in';

  @override
  String get accountKeepSignedInHint =>
      'Only on your own device. Otherwise you are signed out when you close the browser.';

  @override
  String get accountNameHint =>
      'E.g. “Andy”. Your bandmates see it in lists instead of your full name.';

  @override
  String get accountFirstName => 'First name';

  @override
  String get accountLastName => 'Last name';

  @override
  String get accountNickname => 'Display name (optional)';

  @override
  String get accountCompleteName => 'Add your full name';

  @override
  String get accountCompleteNameMessage =>
      'Please enter your first and last name, so your bandmates can find you more easily.';

  @override
  String get settingsHeadingPeople => 'People';

  @override
  String get settingsNameFormat => 'Show names as';

  @override
  String get settingsNameFormatHint =>
      'How other people appear in member lists, in lineups and in recent changes.';

  @override
  String get nameFormatNickname => 'Display name (otherwise full name)';

  @override
  String get nameFormatFirstLast => 'First Last';

  @override
  String get nameFormatLastFirst => 'Last First';

  @override
  String get nameFormatFullWithNickname => 'First Last (display name)';

  @override
  String get accountToSignUp => 'No account yet? Create one';

  @override
  String get accountToSignIn => 'Already have an account? Sign in';

  @override
  String get accountForgotPassword => 'Forgot password?';

  @override
  String get accountResetTitle => 'Reset password';

  @override
  String get accountResetSent =>
      'If an account with this address exists, a reset email has been sent.';

  @override
  String get accountFieldRequired => 'Required.';

  @override
  String accountPasswordTooShort(int min) {
    return 'At least $min characters.';
  }

  @override
  String get accountPasswordMismatch => 'The passwords do not match.';

  @override
  String get accountChangeName => 'Change name';

  @override
  String get accountNameChanged => 'Name changed.';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountChangePasswordHint =>
      'You stay signed in on this device. Your other devices sign out.';

  @override
  String get accountCurrentPassword => 'Current password';

  @override
  String get accountNewPassword => 'New password';

  @override
  String get accountPasswordWrongCurrent => 'The current password is wrong.';

  @override
  String get accountPasswordChanged =>
      'Password changed. Sign in again on your other devices.';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteHint =>
      'Deletes your account and your personal data for good.';

  @override
  String get accountDeleteTitle => 'Delete account?';

  @override
  String get accountDeleteMessage =>
      'Your account, your personal adjustments, annotations and settings are deleted for good, and you are signed out on all devices. Songs and sets stay with your organizations. The server\'s backups keep a copy for up to 14 days. Enter your password to confirm.';

  @override
  String get accountDeleteSoleAdmin =>
      'You are the only admin of these organizations. First make someone else admin or close the organization:';

  @override
  String get accountDeleted => 'Your account was deleted.';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get accountErrorNetwork =>
      'No connection to the server. Check your internet connection.';

  @override
  String get accountErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get accountErrorEmailTaken =>
      'An account with this email address already exists.';

  @override
  String get accountErrorInvalidEmail => 'The email address is not valid.';

  @override
  String get accountErrorWeakPassword =>
      'The password does not meet the server\'s requirements.';

  @override
  String get accountErrorServer =>
      'The server reported an error. Please try again later.';

  @override
  String get accountErrorUpdateRequired =>
      'This version of setDING is too old for the server. Please update the app.';

  @override
  String get updateRequiredTitle => 'Please update setDING';

  @override
  String get updateRequiredBody =>
      'The server no longer accepts this version, so nothing is synced. Your changes stay on this device and are sent after the update.';

  @override
  String updateRequiredVersions(String current, String minimum) {
    return 'Installed: $current, needed: $minimum or newer.';
  }

  @override
  String get updateRequiredHowTo =>
      'On Android, update it in Obtainium; otherwise download the new version from the setDING releases on GitHub.';

  @override
  String get updateHowToGooglePlay => 'Update it in Google Play.';

  @override
  String get updateOpenGooglePlay => 'Open in Google Play';

  @override
  String get updateRequiredReload => 'Reload';

  @override
  String get updateRequiredCopyLink => 'Copy download link';

  @override
  String get updateRequiredCopied => 'Link copied.';

  @override
  String updateAvailableTitle(String version) {
    return 'setDING $version is available';
  }

  @override
  String get updateAvailableDetails => 'Details';

  @override
  String updateAvailableInstalled(String current) {
    return 'Installed: $current.';
  }

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerHint => 'Changing it signs you out.';

  @override
  String get settingsServerInvalid =>
      'The address must start with http:// or https://.';

  @override
  String get settingsServerHttpTitle => 'Unencrypted connection?';

  @override
  String settingsServerHttpMessage(String host) {
    return '$host is not a local server. With http:// your password and your data go over the network unencrypted, and others can read them. Use https:// if the server supports it.';
  }

  @override
  String get settingsServerHttpUse => 'Use anyway';

  @override
  String get bandLocal => 'On this device';

  @override
  String get bandLocalHint => 'Only on this device, not synced.';

  @override
  String get bandSwitch => 'Switch band';

  @override
  String get bandManage => 'Manage bands';

  @override
  String get bandNone => 'No band';

  @override
  String noBandInLibrary(String organization) {
    return 'You are not in a band of $organization. Sets belong to a band: create one or ask to be added.';
  }

  @override
  String get librarySwitch => 'Switch song library';

  @override
  String get bandsTitle => 'Bands';

  @override
  String get bandsEmpty =>
      'You are not in a band yet. Create a band for your songs and sets.';

  @override
  String get bandsSignInHint => 'Sign in to create bands.';

  @override
  String get bandNew => 'New band';

  @override
  String get bandName => 'Band name';

  @override
  String get bandRoleAdmin => 'Admin';

  @override
  String get bandRoleMember => 'Member';

  @override
  String get bandMembers => 'Members';

  @override
  String bandYou(String name) {
    return '$name (you)';
  }

  @override
  String get bandMakeAdmin => 'Make admin';

  @override
  String get bandMakeMember => 'Make member';

  @override
  String get bandRoleLeader => 'Leader';

  @override
  String get bandRolePlanner => 'Set planner';

  @override
  String get orgRoleLibrarian => 'Librarian';

  @override
  String get bandMakeLeader => 'Make leader';

  @override
  String get bandMakePlanner => 'Make set planner';

  @override
  String get orgMakeLibrarian => 'Make librarian';

  @override
  String get orgLibrarianHint =>
      'Librarians create, edit and delete the organization\'s songs.';

  @override
  String get bandPlannerHint => 'Set planners put the band\'s sets together.';

  @override
  String get inviteBandHint =>
      'Creates a link that is valid for 7 days. Whoever opens it joins the organization and this band as a member. Under Members you can then change their role in the band.';

  @override
  String joinQuestionBand(String band, String org) {
    return 'Join $band ($org)?';
  }

  @override
  String get joinExplanationBand =>
      'You become a member of the organization and of the band and see its songs and sets.';

  @override
  String get bandRemoveMember => 'Remove from band';

  @override
  String bandRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String bandRemoveMessage(String name) {
    return '$name will no longer see the band\'s songs and sets.';
  }

  @override
  String get bandLeave => 'Leave band';

  @override
  String bandLeaveTitle(String band) {
    return 'Leave $band?';
  }

  @override
  String get bandLeaveMessage =>
      'You will no longer see the band\'s songs and sets. An admin can invite you again.';

  @override
  String get bandRefresh => 'Refresh';

  @override
  String get bandErrorLastAdmin => 'A band needs at least one admin.';

  @override
  String get bandErrorNotAllowed =>
      'Not allowed, or the band no longer exists.';

  @override
  String get accountErrorSignedOut => 'Please sign in.';

  @override
  String get copyToBand => 'Copy to band';

  @override
  String get copyToBandTitle => 'Copy to which band?';

  @override
  String get copyToBandNoTarget => 'There is no other band you may copy to.';

  @override
  String copiedSongs(int count, String band) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs copied to $band',
      one: '1 song copied to $band',
    );
    return '$_temp0';
  }

  @override
  String copiedSet(String band) {
    return 'Set copied to $band';
  }

  @override
  String songsSelected(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get selectMode => 'Select';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String deleteSongsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count songs?',
      one: 'Delete 1 song?',
    );
    return '$_temp0';
  }

  @override
  String deleteSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count selected songs will be deleted and removed from all sets.',
      one: 'The selected song will be deleted and removed from all sets.',
    );
    return '$_temp0 You can restore them from the trash.';
  }

  @override
  String songsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs deleted',
      one: '1 song deleted',
    );
    return '$_temp0';
  }

  @override
  String get bandRoleOrgAdmin => 'Organization admin';

  @override
  String get bandOrganization => 'Organization';

  @override
  String get bandNewOrganization => 'New organization';

  @override
  String get bandNewHint => 'The bands of an organization share their songs.';

  @override
  String get bandAddMember => 'Add member';

  @override
  String get bandAddMemberTitle => 'Add whom?';

  @override
  String get bandAddMemberNone =>
      'Everyone in the organization is already in this band.';

  @override
  String get bandOrgAdminHint =>
      'You manage this band as an admin of the organization.';

  @override
  String get bandErrorNotOrgMember =>
      'This person is not a member of the organization.';

  @override
  String get orgName => 'Organization name';

  @override
  String get orgPeople => 'People';

  @override
  String get orgBands => 'Bands';

  @override
  String get orgRemove => 'Remove from organization';

  @override
  String orgRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String orgRemoveMessage(String name) {
    return '$name will also leave all bands of the organization and no longer see its songs.';
  }

  @override
  String get orgLeave => 'Leave organization';

  @override
  String orgLeaveTitle(String org) {
    return 'Leave $org?';
  }

  @override
  String get orgLeaveMessage =>
      'You will also leave all its bands and no longer see its songs.';

  @override
  String get orgSongsShared =>
      'All bands of the organization share the same songs.';

  @override
  String get copyToLibraryTitle => 'Copy to which song library?';

  @override
  String get inviteCreate => 'Invite people';

  @override
  String get inviteCreateHint =>
      'Creates a link that is valid for 7 days. Whoever opens it joins the organization as a member, but no band yet. Then add them to a band; under People you can change their role.';

  @override
  String get inviteLinkTitle => 'Invitation link';

  @override
  String inviteLinkHint(String date) {
    return 'Share the link, e.g. in a group chat, or let people scan the QR code. Valid until $date. You can show it again from the list of links.';
  }

  @override
  String get inviteCopy => 'Copy link';

  @override
  String get inviteCopied => 'Link copied';

  @override
  String get invitesTitle => 'Invitation links';

  @override
  String inviteDates(String created, String expires) {
    return 'Created $created, valid until $expires';
  }

  @override
  String get inviteOrganizationOnly => 'Organization only';

  @override
  String get inviteShow => 'Show link';

  @override
  String inviteJoined(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count joined: $names',
      one: 'Joined: $names',
      zero: 'Nobody joined yet',
    );
    return '$_temp0';
  }

  @override
  String get inviteRevoke => 'Revoke';

  @override
  String get inviteRevokeTitle => 'Revoke link?';

  @override
  String get inviteRevokeMessage =>
      'The link will stop working. People who already joined stay members.';

  @override
  String get inviteAskAdmin =>
      'Ask an admin of the organization or a band leader for an invitation.';

  @override
  String get inviteErrorUnknown =>
      'This invitation does not exist. Check the link.';

  @override
  String get inviteErrorExpired =>
      'This invitation has expired. Please ask for a new link.';

  @override
  String get inviteErrorRevoked =>
      'This invitation was revoked. Please ask for a new link.';

  @override
  String get joinTitle => 'Join';

  @override
  String get joinHint => 'Paste the invitation link you received.';

  @override
  String get joinLink => 'Invitation link';

  @override
  String get joinContinue => 'Continue';

  @override
  String get joinInvalidLink => 'This is not a valid invitation link.';

  @override
  String get joinScan => 'Scan QR code';

  @override
  String get joinScanHint => 'Point the camera at the invitation\'s QR code';

  @override
  String get scannerClose => 'Close the scanner';

  @override
  String get scannerTorchOn => 'Turn on the light';

  @override
  String get scannerTorchOff => 'Turn off the light';

  @override
  String get scannerSwitchCamera => 'Switch camera';

  @override
  String get scannerPickImage => 'Read a code from a photo';

  @override
  String get scannerStarting => 'Starting the camera …';

  @override
  String get scannerPermissionTitle => 'No access to the camera';

  @override
  String get scannerPermissionMessage =>
      'Allow setDING to use the camera in the settings to scan QR codes.';

  @override
  String get scannerUnavailableTitle => 'The camera is not available';

  @override
  String get scannerUnavailableMessage =>
      'Another app may be using it, or this device has none.';

  @override
  String get scannerInUseMessage =>
      'Another app is using the camera. Close it and try again.';

  @override
  String get scannerPhotoFallback => 'You can also read the code from a photo.';

  @override
  String get scannerOpenSettings => 'Open settings';

  @override
  String get scannerTryAgain => 'Try again';

  @override
  String get scannerChoosePhoto => 'Choose a photo';

  @override
  String get scannerNoCodeInPhoto => 'There is no code in this photo';

  @override
  String joinQuestion(String org) {
    return 'Join $org?';
  }

  @override
  String get joinExplanation =>
      'You become a member of the organization and see its songs. An admin can then add you to a band.';

  @override
  String joinAlreadyMember(String org) {
    return 'You are already a member of $org.';
  }

  @override
  String get joinButton => 'Join';

  @override
  String joinDone(String org) {
    return 'You joined $org.';
  }

  @override
  String get joinSignInFirst => 'Sign in or create an account to join.';

  @override
  String get joinHaveAccount => 'I already have an account';

  @override
  String get inviteErrorUsed =>
      'This invitation was used already. Please ask for a new link.';

  @override
  String get inviteErrorNotStored =>
      'This link cannot be shown again. Create a new one.';

  @override
  String get accountErrorInvitationRequired =>
      'This server only accepts new accounts with an invitation link.';

  @override
  String get accountErrorEmailNotVerified =>
      'Please confirm your email address first. We sent you a new mail.';

  @override
  String get bandErrorFounderInvitationRequired =>
      'New organizations need a founder invitation from the server operator.';

  @override
  String get accountInviteOnlyHint =>
      'New accounts need an invitation link on this server.';

  @override
  String accountVerifyEmail(String email) {
    return 'Almost done: we sent a mail to $email. Confirm your address with the link in it, then sign in.';
  }

  @override
  String get accountVerifyResend => 'Send the mail again';

  @override
  String get accountVerifySent => 'Mail sent.';

  @override
  String joinFoundQuestion(String org) {
    return 'Found $org?';
  }

  @override
  String get joinFoundExplanation =>
      'You create the organization and become its admin. Then you can create bands and invite people.';

  @override
  String get joinFoundButton => 'Found organization';

  @override
  String joinFoundDone(String org) {
    return 'You founded $org.';
  }

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncNow => 'Sync now';

  @override
  String get settingsSyncMode => 'Sync';

  @override
  String get syncModeAutomatic => 'Automatic';

  @override
  String get syncModeOnStart => 'At start';

  @override
  String get syncModeManual => 'Manual';

  @override
  String get syncModeAutomaticHint =>
      'Syncs at start, a few seconds after changes, when something changes on the server and every 5 minutes.';

  @override
  String get syncModeOnStartHint =>
      'Syncs once when the app starts and after signing in. Otherwise with \"Sync now\".';

  @override
  String get syncModeManualHint => 'Syncs only when you tap \"Sync now\".';

  @override
  String get syncRunning => 'Syncing …';

  @override
  String syncLast(String time) {
    return 'Last synced: $time';
  }

  @override
  String get syncNever => 'Not synced yet';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes are not on the server yet.',
      one: '1 change is not on the server yet.',
      zero: 'All changes are on the server.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline => 'No connection – changes will be sent later.';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with a conflict – open them to decide.',
      one: '1 song with a conflict – open it to decide.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBanner =>
      'This song was changed on the server and on this device.';

  @override
  String get conflictBannerDeleted =>
      'This song was deleted on the server and changed on this device.';

  @override
  String get conflictKeepMine => 'Keep mine';

  @override
  String get conflictTakeServer => 'Use server version';

  @override
  String get conflictKeepBoth => 'Keep both';

  @override
  String get conflictCompare => 'Show server version';

  @override
  String get conflictServerVersion => 'Server version';

  @override
  String get conflictKeptBoth => 'Your version was saved as a separate song.';

  @override
  String get accountErrorConflict =>
      'The song was changed on the server in the meantime.';

  @override
  String get pdfMissing =>
      'The PDF is not on this device yet. It is downloaded with the next sync.';

  @override
  String get pdfLoadFailed =>
      'The PDF could not be loaded from the server. Check the connection and open the song again.';

  @override
  String get openAttachment => 'Open';

  @override
  String get imageMissing => 'The image is not on this device.';

  @override
  String syncMissingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs are still being downloaded.',
      one: '1 PDF is still being downloaded.',
    );
    return '$_temp0';
  }

  @override
  String get invalidChordProTitle => 'Check the ChordPro?';

  @override
  String get invalidChordProMessage =>
      'The song contains places that will probably not be shown as intended:';

  @override
  String problemUnclosedDirective(int line) {
    return 'Line $line: a curly bracket (directive) is not closed.';
  }

  @override
  String problemUnclosedChord(int line) {
    return 'Line $line: a square bracket (chord) is not closed.';
  }

  @override
  String problemUnclosedEnvironment(int line) {
    return 'Line $line: the block is never ended and contains the whole rest of the song.';
  }

  @override
  String problemTextAfterDirective(int line) {
    return 'Line $line: text after a directive; the whole line is shown as lyrics.';
  }

  @override
  String problemInvalidKey(int line) {
    return 'Line $line: the key directive names no key; the song has no key for transposing and the chord views.';
  }

  @override
  String chordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count places in the ChordPro will probably not be shown as intended',
      one: '1 place in the ChordPro will probably not be shown as intended',
    );
    return '$_temp0';
  }

  @override
  String chordProProblemsShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show the $count ChordPro problems',
      one: 'Show the ChordPro problem',
    );
    return '$_temp0';
  }

  @override
  String setChordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with ChordPro problems',
      one: '1 song with ChordPro problems',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsTitle => 'Check the import';

  @override
  String importProblemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imported songs contain places',
      one: '1 imported song contains places',
    );
    return '$_temp0 that will probably not be shown as intended:';
  }

  @override
  String importProblemItem(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$title ($_temp0)';
  }

  @override
  String get importProblemsHint =>
      'The songs are marked in the song list. Fixing automatically changes only places with a clear repair; fix the rest in the editor.';

  @override
  String songsFixed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs fixed',
      one: '1 song fixed',
      zero: 'No song fixed',
    );
    return '$_temp0';
  }

  @override
  String moreProblems(int count) {
    return '… and $count more.';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get fixProblems => 'Fix automatically';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get webSignInHint =>
      'Sign in to manage organizations, bands, songs and sets in the browser.';

  @override
  String get webNoBandTitle => 'No band yet';

  @override
  String get webNoBandMessage =>
      'You are not in a band yet. Create an organization with a band, or join with an invitation link.';

  @override
  String get songDetails => 'Song details';

  @override
  String get songDetailsTooltip =>
      'Edit title, key, tempo and more of the song – for everyone';

  @override
  String get noKey => 'No key';

  @override
  String get timeHint => 'e.g. 4/4';

  @override
  String get noSequence => 'No sequence';

  @override
  String get sequenceChange => 'Change song sequence';

  @override
  String get sortSongs => 'Sort';

  @override
  String get sortByTitle => 'Title';

  @override
  String get sortByArtist => 'Artist';

  @override
  String get sortByKey => 'Key';

  @override
  String get sortByRecent => 'Recently edited';

  @override
  String get noArtist => 'No artist';

  @override
  String get songConflictTooltip =>
      'Changed here and on the server – open the song to decide';

  @override
  String get pdfOnlyTooltip => 'Sheet music (PDF) only, no chords';

  @override
  String upcomingGigTooltip(String set, String date) {
    return 'In “$set” on $date';
  }

  @override
  String get foundInLyrics => 'Found in the lyrics';

  @override
  String hiddenParts(String parts) {
    return 'Hidden (not in the sequence): $parts';
  }

  @override
  String get setsUpcoming => 'Upcoming';

  @override
  String get setsUndated => 'Without date';

  @override
  String setsPast(int count) {
    return 'Past ($count)';
  }

  @override
  String get showPastSets => 'Show past sets';

  @override
  String get hidePastSets => 'Hide past sets';

  @override
  String get nextGig => 'Next gig';

  @override
  String gigInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'Tomorrow',
      zero: 'Today',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Undo';

  @override
  String songDeleted(String title) {
    return '“$title” deleted';
  }

  @override
  String setDeleted(String name) {
    return 'Set “$name” deleted';
  }

  @override
  String attachmentDeleted(String name) {
    return 'Attachment “$name” deleted';
  }

  @override
  String setItemRemoved(String title) {
    return '“$title” removed from the set';
  }

  @override
  String get settingsGroupPersonal => 'Personal – on all your devices';

  @override
  String get settingsGroupDevice => 'This device';

  @override
  String get settingsGroupAccount => 'Account & organization';

  @override
  String get settingsScopePersonalHint =>
      'These settings belong to your account and apply on all devices you are signed in on.';

  @override
  String get settingsScopePersonalSignedOutHint =>
      'While signed out, these settings apply on this device only. After signing in, they are synced with your account.';

  @override
  String get settingsScopeDeviceHint =>
      'These settings apply on this device only and are not synced.';

  @override
  String get settingsTakenOver =>
      'The settings of your account have been applied.';

  @override
  String get annotationsDraw => 'Draw annotations';

  @override
  String get annotationsShow => 'Show annotations';

  @override
  String get annotationsHide => 'Hide annotations';

  @override
  String get annotationPen => 'Pen';

  @override
  String get annotationHighlighter => 'Highlighter';

  @override
  String get annotationText => 'Text';

  @override
  String get annotationTextHint => 'Type text';

  @override
  String get annotationEraser => 'Eraser (whole stroke)';

  @override
  String get annotationPartialEraser => 'Eraser (part of a stroke)';

  @override
  String get annotationLasso => 'Select (lasso)';

  @override
  String get annotationStamps => 'Stamps';

  @override
  String get annotationStampsMusic => 'Music marks';

  @override
  String get annotationStampsRepeats => 'Repeats';

  @override
  String get annotationStampsCues => 'Cues';

  @override
  String annotationColor(Object number) {
    return 'Colour $number';
  }

  @override
  String get annotationSize => 'Line width';

  @override
  String get annotationSmaller => 'Smaller';

  @override
  String get annotationLarger => 'Larger';

  @override
  String get annotationDeleteSelection => 'Delete selection';

  @override
  String get annotationUndo => 'Undo';

  @override
  String get annotationRedo => 'Redo';

  @override
  String get annotationMore => 'More';

  @override
  String get annotationDrawWithFinger => 'Draw with finger';

  @override
  String get annotationDone => 'Done';

  @override
  String get annotationsDeleteAll => 'Delete all annotations of this song';

  @override
  String get annotationsDeleted => 'Annotations deleted';

  @override
  String get annotationsOtherLayout => 'Drawn for another view';

  @override
  String get annotationsOtherLayoutLandscape => 'Drawn in landscape';

  @override
  String get annotationsOtherLayoutPortrait => 'Drawn in portrait';

  @override
  String annotationsOrphaned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations without their line',
      one: '1 annotation without its line',
    );
    return '$_temp0';
  }

  @override
  String get annotationsFull => 'Annotations full: erase some to draw more';

  @override
  String annotationsNearlyFull(int percent) {
    return 'Annotations $percent % full';
  }

  @override
  String get annotationsPanelTitle => 'Freehand annotations';

  @override
  String get annotationsPanelShow => 'Show my annotations';

  @override
  String annotationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
      zero: 'None yet: draw them in live mode',
    );
    return '$_temp0';
  }

  @override
  String get settingsShowAnnotations => 'Show freehand annotations';

  @override
  String get settingsShowAnnotationsHint =>
      'Your own drawings on songs and sheet music';

  @override
  String get settingsRepeatedChorusOnce =>
      'Show a written-out chorus only once';

  @override
  String get settingsRepeatedChorusOnceHint =>
      'A chorus written out again word for word later is left out';

  @override
  String get settingsShowOutsideSequence => 'Show parts outside the sequence';

  @override
  String get settingsShowOutsideSequenceHint =>
      'Dimmed in live mode instead of hidden';

  @override
  String get settingsAnnotationFinger => 'Draw annotations with a finger';

  @override
  String get settingsAnnotationFingerHint =>
      'For devices without a stylus; otherwise fingers keep turning pages';

  @override
  String get settingsSpaceStartsBeat => 'Space starts the beat';

  @override
  String get settingsSpaceStartsBeatHint =>
      'Space starts and stops the beat and click like Enter, instead of turning forward';

  @override
  String get stampFermata => 'Fermata';

  @override
  String get stampBreath => 'Breath mark';

  @override
  String get stampCrescendo => 'Crescendo';

  @override
  String get stampDecrescendo => 'Decrescendo';

  @override
  String get stampRitardando => 'Ritardando';

  @override
  String get stampAccent => 'Accent';

  @override
  String stampRepeat(Object times) {
    return 'Play $times×';
  }

  @override
  String get stampRepeatStart => 'Repeat start';

  @override
  String get stampRepeatEnd => 'Repeat end';

  @override
  String get stampCoda => 'Coda';

  @override
  String get stampSegno => 'Segno';

  @override
  String get stampGlasses => 'Watch out';

  @override
  String get stampStop => 'Stop';

  @override
  String get stampEye => 'Look';

  @override
  String get stampExclamation => 'Important';

  @override
  String get stampStar => 'Star';

  @override
  String get settingsSectionBands => 'Organization & bands';

  @override
  String get settingsCategoryBandsHint =>
      'Organizations, bands, members and invitations';

  @override
  String get settingsBandsJoinHint =>
      'Join an organization or band with an invitation link.';

  @override
  String get settingsSectionSongDisplay => 'Song display';

  @override
  String get settingsCategorySongDisplayHint =>
      'Styles per section: chords, lyrics, headings, bars';

  @override
  String get songDisplayPreview => 'Preview';

  @override
  String get songDisplayPreset => 'Preset';

  @override
  String get songDisplayPresetClassic => 'Classic';

  @override
  String get songDisplayPresetColorCoded => 'Colour-coded';

  @override
  String get songDisplayPresetChorusFocus => 'Chorus focus';

  @override
  String get songDisplayPresetSinger => 'Vocals';

  @override
  String get songDisplayPresetGuitar => 'Guitar';

  @override
  String get songDisplayPresetMinimal => 'Minimal';

  @override
  String get songDisplayPresetBlackWhite => 'Black/White';

  @override
  String get songDisplayPresetCustom => 'Custom';

  @override
  String get songDisplayDiscardTitle => 'Discard custom styles?';

  @override
  String songDisplayDiscardMessage(String name) {
    return 'The preset “$name” replaces your custom styles.';
  }

  @override
  String get songDisplayDiscard => 'Discard';

  @override
  String get songDisplayFont => 'Font';

  @override
  String get songDisplayFontStandard => 'Standard';

  @override
  String get songDisplayFontMonospace => 'Monospace';

  @override
  String get songDisplaySection => 'Section';

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
      'Base style for every section without its own style and for sections that are not recognised (e.g. tabs, grids, custom names).';

  @override
  String get songDisplayStyle => 'Style';

  @override
  String get songDisplayOwnStyle => 'Own style';

  @override
  String songDisplayLike(String name) {
    return 'Like $name';
  }

  @override
  String songDisplayInheritsHint(String chain) {
    return 'Takes everything from: $chain. Changes there apply here too.';
  }

  @override
  String get songDisplayChords => 'Chords';

  @override
  String get songDisplayLyrics => 'Lyrics';

  @override
  String get songDisplayHeading => 'Heading';

  @override
  String get songDisplayBar => 'Indent bar';

  @override
  String get songDisplayBold => 'Bold';

  @override
  String get songDisplayItalic => 'Italic';

  @override
  String get songDisplaySize => 'Size';

  @override
  String get songDisplayColor => 'Colour';

  @override
  String get songDisplayShowHeading => 'Show heading';

  @override
  String get songDisplayShowBar => 'Show bar';

  @override
  String get songDisplayBarWidth => 'Width';

  @override
  String get songDisplayIndent => 'Indent';

  @override
  String get songDisplayTint => 'Tint background';

  @override
  String get songDisplaySizeSmall => 'S';

  @override
  String get songDisplaySizeMedium => 'M';

  @override
  String get songDisplaySizeLarge => 'L';

  @override
  String get songDisplaySizeExtraLarge => 'XL';

  @override
  String get songDisplayBarThin => 'Thin';

  @override
  String get songDisplayBarMedium => 'Medium';

  @override
  String get songDisplayBarWide => 'Wide';

  @override
  String get songDisplayIndentNone => 'None';

  @override
  String get songDisplayIndentNormal => 'Normal';

  @override
  String get songDisplayIndentLarge => 'Large';

  @override
  String get songColorAuto => 'Automatic';

  @override
  String get songColorBlue => 'Blue';

  @override
  String get songColorAmber => 'Amber';

  @override
  String get songColorRed => 'Red';

  @override
  String get songColorGreen => 'Green';

  @override
  String get songColorTeal => 'Teal';

  @override
  String get songColorPurple => 'Purple';

  @override
  String get songColorPink => 'Pink';

  @override
  String get songColorGrey => 'Grey';

  @override
  String get songColorBlackWhite => 'Black/White';

  @override
  String get songDisplayCustomise => 'Customise display';

  @override
  String get songDisplayCustomiseHint =>
      'Chords, lyrics, headings, bars and colours';

  @override
  String get songDisplayEditorTitle => 'Customise song display';

  @override
  String get songDisplayDemoSong => 'Demo song';

  @override
  String get songDisplayLibrarySong => 'Song from the library …';

  @override
  String get songDisplayPickSong => 'Song for the preview';

  @override
  String get songDisplayResizePreview => 'Drag to resize the preview';

  @override
  String get appUpdateInstall => 'Install';

  @override
  String appUpdateInstallTitle(String version) {
    return 'Install setDING $version?';
  }

  @override
  String get appUpdateInstallBody =>
      'setDING closes, installs the new version and starts again. Your data stays on this device.';

  @override
  String get appUpdateDownloading => 'Downloading the update …';

  @override
  String get appUpdateFailed =>
      'The update could not be installed. Please try again later.';

  @override
  String get whatsNewTitle => 'What\'s new';

  @override
  String whatsNewAvailable(String version) {
    return 'New in setDING $version';
  }

  @override
  String get whatsNewShow => 'Show';

  @override
  String whatsNewVersion(String version) {
    return 'Version $version';
  }

  @override
  String get whatsNewAllChanges => 'All changes';

  @override
  String get midiTestTitle => 'MIDI test (prototype)';

  @override
  String get midiTestTileHint =>
      'Send a program change to a keyboard connected by USB, e.g. a Nord Stage 3';

  @override
  String get midiTestHint =>
      'Sends a program change to a keyboard connected by USB, to test MIDI on this device. What the keyboard sends, e.g. when you select a program or song on it, appears in the log.';

  @override
  String get midiTestDevices => 'Devices';

  @override
  String get midiTestRefresh => 'Search again';

  @override
  String get midiTestNoDevices =>
      'No MIDI device found. Connect the keyboard by USB and search again.';

  @override
  String get midiTestConnect => 'Connect';

  @override
  String get midiTestDisconnect => 'Disconnect';

  @override
  String get midiTestConnected => 'Connected';

  @override
  String get midiTestChannel => 'MIDI channel';

  @override
  String get midiTestModeNordProgram => 'Nord program';

  @override
  String get midiTestModeNordSong => 'Nord song';

  @override
  String get midiTestModeNordLive => 'Nord live';

  @override
  String get midiTestModeRaw => 'Raw values';

  @override
  String get midiTestBank => 'Bank';

  @override
  String get midiTestLive => 'Live memory';

  @override
  String get midiTestMsb => 'Bank select MSB (CC 0, 0–127)';

  @override
  String get midiTestLsb => 'Bank select LSB (CC 32, 0–127)';

  @override
  String get midiTestProgram => 'Program (1–128)';

  @override
  String get midiTestEmptyNotSent => 'An empty bank select is not sent.';

  @override
  String get midiTestInvalid => 'Check the values';

  @override
  String get midiTestSend => 'Send';

  @override
  String get midiTestLog => 'Log';

  @override
  String get midiTestCopy => 'Copy log';

  @override
  String get midiTestCopied => 'Log copied';

  @override
  String get midiTestClear => 'Clear log';

  @override
  String midiTestSent(String bytes) {
    return 'Sent: $bytes';
  }

  @override
  String midiTestReceivedCc(
    int controller,
    int value,
    int channel,
    String bytes,
  ) {
    return 'Received: CC $controller = $value (channel $channel) – $bytes';
  }

  @override
  String midiTestReceivedPc(
    int number,
    int program,
    int channel,
    String bytes,
  ) {
    return 'Received: program change $number (value $program, channel $channel) – $bytes';
  }

  @override
  String midiTestReceivedOther(String bytes) {
    return 'Received: $bytes';
  }

  @override
  String midiTestError(String message) {
    return 'Error: $message';
  }

  @override
  String get midiTestModeCc => 'Control change';

  @override
  String get midiTestController => 'Controller (CC 0–127)';

  @override
  String get midiTestValue => 'Value (0–127)';

  @override
  String get midiTestCcHint =>
      'Nord Stage 3 according to midi.guide: CC 2 live mode, CC 3 song mode, CC 5 song part. Which values do what is part of the test.';

  @override
  String get midiGuideTitle => 'Guided test';

  @override
  String get midiGuideHint =>
      'Tap “Send”, look at the display of the Nord and tap what happened. Nothing has to be set on the Nord. The answers are kept in the log.';

  @override
  String get midiGuideNordSend => 'Nord Stage 3 – send';

  @override
  String get midiGuideNordReceive => 'Nord Stage 3 – receive';

  @override
  String get midiGuideMotifSend => 'Motif XF – send';

  @override
  String get midiGuideMotifReceive => 'Motif XF – receive';

  @override
  String get midiGuideNordReceiveHint =>
      'On the Nord, set “Program Change” in the MIDI menu to “Send” or “Send & Receive”, and set the channel here to the Nord\'s global channel. Then choose any program, live memory or song part on the Nord, e.g. with the dial or the mode buttons. setDING shows what arrived; tap whether it matches the display. The results are kept in the log.';

  @override
  String get midiGuideMotifSendHint =>
      'On the Motif XF, under Utility → Control (F5) → MIDI (SF2): set MIDI IN/OUT to USB, switch on receiving bank select and program change, set the Basic Receive Channel to the channel here and the Device Number to “all” or 1, then save with Store. Tap “Send”, look at the Motif\'s display and tap what happened. The answers are kept in the log.';

  @override
  String get midiGuideMotifReceiveHint =>
      'On the Motif XF, under Utility → Control (F5) → MIDI (SF2): set MIDI IN/OUT to USB, switch on sending bank select and program change and set the Transmit Channel to the channel here, then save with Store. Then choose any voice or performance on the Motif, also in different banks and twice in the same bank. setDING shows what arrived; tap whether it matches the display. The results are kept in the log.';

  @override
  String midiGuideMotifExpected(String name) {
    return 'The Motif shows $name.';
  }

  @override
  String get midiGuideWaiting => 'Choose a sound on the keyboard …';

  @override
  String midiGuideFreeReceived(String name) {
    return 'Received: $name';
  }

  @override
  String get midiGuideMatches => 'Matches the display';

  @override
  String get midiGuideNoMatch => 'Does not match';

  @override
  String midiGuideFreeResult(String name, String values, String answer) {
    return 'Received $name ($values): $answer';
  }

  @override
  String midiGuideChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sounds checked',
      one: '1 sound checked',
      zero: 'Nothing checked yet',
    );
    return '$_temp0';
  }

  @override
  String midiGuideStep(int current, int total, String title) {
    return 'Step $current of $total: $title';
  }

  @override
  String midiGuideExpected(String expected) {
    return 'Expected: $expected';
  }

  @override
  String get midiGuideDone => 'Test finished. The answers are in the log.';

  @override
  String get midiGuideRestart => 'Start again';

  @override
  String get midiGuideBack => 'Back';

  @override
  String get midiGuideSkip => 'Skip';

  @override
  String midiGuideResult(int current, String title, String answer) {
    return 'Step $current ($title): $answer';
  }

  @override
  String midiGuideProgram(String name) {
    return 'Program $name';
  }

  @override
  String midiGuideProgramExpected(String name) {
    return 'The Nord shows $name.';
  }

  @override
  String midiGuideLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiGuideLiveExpected(int number) {
    return 'The Nord shows Live $number.';
  }

  @override
  String get midiGuideSongModeOn => 'Song mode on (CC 3 = 127)';

  @override
  String get midiGuideSongModeOnExpected => 'The Nord switches to song mode.';

  @override
  String get midiGuideSongModeOff => 'Song mode off (CC 3 = 0)';

  @override
  String get midiGuideSongModeOffExpected => 'The Nord leaves song mode.';

  @override
  String get midiGuideAnswerAsExpected => 'As expected';

  @override
  String get midiGuideAnswerDifferent => 'Something else';

  @override
  String get midiGuideAnswerNothing => 'Nothing happened';

  @override
  String get midiTestFree => 'Send freely';

  @override
  String get midiTestPage => 'Page';

  @override
  String get midiTestButton => 'Button';

  @override
  String midiGuideSong(int song, int part) {
    return 'Song $song, part $part';
  }

  @override
  String midiGuideSongExpected(int song, int part) {
    return 'The Nord shows song $song, part $part.';
  }

  @override
  String get midiTestSong => 'Song';

  @override
  String get midiTestPart => 'Part';

  @override
  String get settingsEditorTypingAids =>
      'Close brackets and sections automatically';

  @override
  String get settingsEditorTypingAidsHint =>
      'In the ChordPro editor: [ adds ], Enter after a section start adds its end, and renaming a section start renames its end too.';

  @override
  String get settingsDeveloperMode => 'Developer mode';

  @override
  String get settingsDeveloperModeHint =>
      'Shows the “Development” category with experimental features for testing. Not needed for normal use.';

  @override
  String get settingsGroupDevelopment => 'Development';

  @override
  String get settingsSectionDevelopment => 'Test features';

  @override
  String get settingsCategoryDevelopmentHint =>
      'Experimental, for testing only';

  @override
  String get settingsDevelopmentNoteTitle => 'Experimental features';

  @override
  String get settingsDevelopmentNote =>
      'These features are for testing. They may change, have bugs or disappear again. Not meant for performances. Hide them with “Developer mode” under General.';

  @override
  String get settingsSectionMidi => 'Keyboard (MIDI)';

  @override
  String get settingsCategoryMidiHint =>
      'Program changes to a keyboard connected by USB';

  @override
  String get settingsMidiEnabled => 'MIDI program changes';

  @override
  String get settingsMidiEnabledHint =>
      'In live mode, the keyboard switches to the program stored for each song.';

  @override
  String settingsMidiConnected(String name) {
    return 'Connected to $name';
  }

  @override
  String get settingsMidiNotConnected => 'Not connected';

  @override
  String get settingsMidiOutput => 'Output';

  @override
  String get settingsMidiOutputHint =>
      'The keyboard connected by USB. setDING connects to it again by itself when it is plugged in.';

  @override
  String get settingsMidiNoDevices =>
      'No MIDI device found. Connect the keyboard by USB and search again.';

  @override
  String get settingsMidiSearch => 'Search again';

  @override
  String settingsMidiOutputMissing(String name) {
    return '$name (not plugged in)';
  }

  @override
  String get settingsMidiProfile => 'Device profile';

  @override
  String get settingsMidiProfileHint =>
      'How keyboard programs are entered and shown. “Generic” uses bank select and program number and works with any keyboard.';

  @override
  String get midiProfileNordStage3 => 'Nord Stage 3';

  @override
  String get midiProfileGeneric => 'Generic';

  @override
  String get settingsMidiChannel => 'MIDI channel';

  @override
  String get settingsMidiChannelHint => 'The channel the keyboard receives on.';

  @override
  String get settingsMidiTakeOver => 'Take over programs from the keyboard';

  @override
  String get settingsMidiTakeOverHint =>
      'While the keyboard program is open in live mode, setDING shows the sound you choose on the keyboard and takes it over into the song if you want. The keyboard has to send bank select and program change.';

  @override
  String get settingsMidiTakeOverNordHint =>
      'While the keyboard program is open in live mode, setDING shows the sound you choose on the Nord and takes it over into the song if you want. On the Nord, set “Program Change” in the MIDI menu to “Send” or “Send & Receive”.';

  @override
  String get settingsMidiNordHint =>
      'On the Nord Stage 3, switch on “Program Change” reception in its MIDI menu, and set the channel here to the Nord\'s global channel. The numbering of Nord songs depends on the Nord\'s OS version (checked with OS 2.54); if a song does not match, use the profile “Generic”.';

  @override
  String get midiProgramTitle => 'Keyboard program';

  @override
  String get midiProgramHint =>
      'Sent to the keyboard in live mode when this song comes up.';

  @override
  String get midiProgramNone => 'None: the keyboard keeps its sound';

  @override
  String get midiProgramChoose => 'Choose program';

  @override
  String get midiProgramPreviewSwitch => 'Send while selecting';

  @override
  String get midiProgramPreviewHint =>
      'Each choice goes to the keyboard at once; Cancel restores the previous program.';

  @override
  String get midiProgramRemove => 'Remove program';

  @override
  String get midiProgramTest => 'Test';

  @override
  String get midiProgramTestHint => 'Sends the program to the keyboard once';

  @override
  String get midiProgramNotConnected => 'Keyboard not connected';

  @override
  String get midiProgramOff =>
      'MIDI program changes are off on this device (settings: Keyboard (MIDI)).';

  @override
  String midiProgramSent(String device) {
    return 'Sent to $device';
  }

  @override
  String get midiProgramSendFailed => 'The program could not be sent';

  @override
  String get midiProgramKindProgram => 'Program';

  @override
  String get midiProgramKindLive => 'Live memory';

  @override
  String get midiProgramKindSong => 'Song';

  @override
  String get midiProgramKindGeneric => 'Other values';

  @override
  String get midiProgramBank => 'Bank';

  @override
  String get midiProgramPageButton => 'Page (row) and button';

  @override
  String get midiProgramSongNumber => 'Song';

  @override
  String get midiProgramPreviousSong => 'Previous song';

  @override
  String get midiProgramNextSong => 'Next song';

  @override
  String get midiProgramPart => 'Part';

  @override
  String get midiProgramSongHint =>
      'The numbering of Nord songs depends on the Nord\'s OS version (checked with OS 2.54). If a song does not match, use the profile “Generic” in the settings.';

  @override
  String get midiProgramsTitle => 'Keyboard programs';

  @override
  String midiProgramDevice(String profile) {
    return 'This device: $profile';
  }

  @override
  String get midiProgramForOtherKeyboard => 'Program for another keyboard';

  @override
  String midiProgramUnknownKeyboard(String id) {
    return 'Unknown keyboard ($id)';
  }

  @override
  String get midiProgramMsb => 'Bank select MSB (optional)';

  @override
  String get midiProgramLsb => 'Bank select LSB (optional)';

  @override
  String get midiProgramNumber => 'Program';

  @override
  String midiProgramRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String midiProgramOutOfRange(int min, int max) {
    return 'Enter a number from $min to $max';
  }

  @override
  String midiProgramValueNord(String name) {
    return 'Program $name';
  }

  @override
  String get midiProfileMotifXf => 'Yamaha Motif XF';

  @override
  String get settingsMidiMotifHint =>
      'On the Motif XF, under Utility → Control (F5) → MIDI (SF2): set MIDI IN/OUT to USB, switch on receiving Bank Select and Program Change, set the Basic Receive Channel to the channel here and the Device Number to “all” or 1, then save with Store. setDING switches the Motif to voice or performance mode itself before each program.';

  @override
  String get midiProgramKindPerformance => 'Performance';

  @override
  String get midiProgramKindVoice => 'Voice';

  @override
  String get midiProgramGroup => 'Group';

  @override
  String get midiProgramMotifNumber => 'Number';

  @override
  String get midiProgramMotifHint =>
      'As on the display of the Motif XF, e.g. USR1 A01. setDING switches the Motif to voice or performance mode before sending.';

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
    return 'Song $song, part $part';
  }

  @override
  String midiProgramValueGeneric(int program) {
    return 'Program $program';
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
  String get trash => 'Trash';

  @override
  String trashWithCount(int count) {
    return 'Trash ($count)';
  }

  @override
  String get trashSongsTitle => 'Deleted songs';

  @override
  String get trashSetsTitle => 'Deleted sets';

  @override
  String trashEmpty(int days) {
    return 'The trash is empty. Deleted songs and sets can be restored here for $days days.';
  }

  @override
  String trashHint(int days) {
    return 'Deleted songs and sets can be restored for $days days. After that they are removed for good.';
  }

  @override
  String trashDeletedOn(String date) {
    return 'deleted on $date';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'last day',
    );
    return '$_temp0';
  }

  @override
  String get trashRestore => 'Restore';

  @override
  String trashRestored(String title) {
    return '\"$title\" restored';
  }

  @override
  String get trashGroupToday => 'Today';

  @override
  String get trashGroupWeek => 'This week';

  @override
  String get trashGroupOlder => 'Older';

  @override
  String trashMenu(String title) {
    return 'Actions for \"$title\"';
  }

  @override
  String get trashPurge => 'Delete permanently';

  @override
  String get trashPurgeTitle => 'Delete permanently?';

  @override
  String trashPurgeOne(String title) {
    return '\"$title\" will be deleted permanently. This cannot be undone.';
  }

  @override
  String trashPurgeMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0 will be deleted permanently. This cannot be undone.';
  }

  @override
  String get trashEmptyAction => 'Empty trash';

  @override
  String get trashEmptyTitle => 'Empty the trash?';

  @override
  String trashPurged(String title) {
    return '\"$title\" deleted permanently';
  }

  @override
  String trashPurgedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0 deleted permanently';
  }

  @override
  String trashRestoredMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0 restored';
  }

  @override
  String get backupExport => 'Back up library';

  @override
  String get backupSyncing => 'Syncing with the server …';

  @override
  String get backupCollecting => 'Creating the backup …';

  @override
  String get backupSaved => 'Backup saved.';

  @override
  String get backupFailedTitle => 'Backup not possible';

  @override
  String get backupSyncDeferred => 'Live mode is open. Close it and try again.';

  @override
  String get backupSyncFailed =>
      'The sync with the server failed. A backup of an organization needs a working connection, so that it contains everything. Try again when you are online.';

  @override
  String get backupPendingChanges =>
      'Changes on this device have not reached the server yet. Wait for the sync and try again.';

  @override
  String get backupConflicts =>
      'Some songs have a sync conflict. Resolve the conflicts first.';

  @override
  String get backupMissingFiles =>
      'Not all attachments are downloaded yet. Wait for the download and try again.';

  @override
  String backupFileMissing(String name, String song) {
    return 'The attachment \"$name\" of \"$song\" could not be loaded.';
  }

  @override
  String get backupInvalid => 'This file is not a setDING backup.';

  @override
  String get backupNewer =>
      'This backup was made with a newer version of setDING. Update the app to import it.';

  @override
  String get backupImportTitle => 'Import backup';

  @override
  String backupImportSummary(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Backup of \"$library\": $_temp0, $_temp1.';
  }

  @override
  String get backupImportCopyHint =>
      'Everything is imported as a copy into the current library. Nothing existing is changed.';

  @override
  String backupImportIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs are',
      one: '1 song is',
    );
    return '$_temp0 already here with the same text and will be used as they are.';
  }

  @override
  String backupImportDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs exist',
      one: '1 song exists',
    );
    return '$_temp0 here with a different text:';
  }

  @override
  String get backupKeepExisting => 'Keep the existing songs';

  @override
  String get backupAddAll => 'Import as additional songs';

  @override
  String get backupImportSetsTo => 'Sets go to:';

  @override
  String backupBandSets(String band, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$band ($_temp0)';
  }

  @override
  String get backupSkipSets => 'Do not import';

  @override
  String get backupImportStart => 'Import';

  @override
  String get backupImportDone => 'Backup imported';

  @override
  String backupResultSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs imported',
      one: '1 song imported',
    );
    return '$_temp0';
  }

  @override
  String backupResultIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs were already here',
      one: '1 song was already here',
    );
    return '$_temp0';
  }

  @override
  String backupResultKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count existing songs kept',
      one: '1 existing song kept',
    );
    return '$_temp0';
  }

  @override
  String backupResultSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
      zero: 'No sets',
    );
    return '$_temp0 imported';
  }

  @override
  String backupResultFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String backupResultAdditional(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'These songs now exist twice. Compare them with the existing ones and delete the ones you do not need:',
      one: 'This song now exists twice. Compare it with the existing one and delete the one you do not need:',
    );
    return '$_temp0';
  }

  @override
  String get bandDelete => 'Delete band';

  @override
  String bandDeleteTitle(String band) {
    return 'Delete $band?';
  }

  @override
  String bandDeleteMessage(int days) {
    return 'Its sets, band arrangements and memberships are deleted with it, and its open invitations are revoked. The songs stay in the organization\'s library. Organization admins can restore the band from the trash for $days days. To keep a copy outside setDING, back up the library first.';
  }

  @override
  String bandDeleteSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
      zero: 'no sets',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'no members',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open invitations',
      one: '1 open invitation',
      zero: 'no open invitations',
    );
    return '$_temp0';
  }

  @override
  String get bandDeleteLastBand =>
      'This is the last band of the organization. The organization and its song library stay.';

  @override
  String bandDeleteConfirmName(String band) {
    return 'Type \"$band\" to confirm';
  }

  @override
  String bandDeleted(String band) {
    return '$band deleted';
  }

  @override
  String get trashBandsTitle => 'Deleted bands';

  @override
  String trashBandsEmpty(int days) {
    return 'No deleted bands. Deleted bands can be restored here for $days days.';
  }

  @override
  String trashBandsHint(int days) {
    return 'Deleted bands can be restored with their sets, arrangements and members for $days days. After that they are removed for good.';
  }

  @override
  String bandsGone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names are no longer available to you: the bands were deleted or you are no longer a member.',
      one:
          '$names is no longer available to you: the band was deleted or you are no longer a member.',
    );
    return '$_temp0';
  }

  @override
  String get backupAll => 'Back up everything';

  @override
  String get backupAllName => 'all';

  @override
  String get backupAllHint =>
      'Your libraries with songs, sets and attachments, your personal adjustments and notes, and your settings, in one file.';

  @override
  String get backupNever => 'Not backed up on this device yet.';

  @override
  String backupLast(String date) {
    return 'Last backup: $date';
  }

  @override
  String get backupRestore => 'Restore backup';

  @override
  String get backupRestoreHint =>
      'Imports a backup file as a copy, or replaces the library “On this device” by its backup.';

  @override
  String get backupRestoreTitle => 'Restore backup';

  @override
  String backupLibraryTo(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '\"$library\" ($_temp0, $_temp1) into';
  }

  @override
  String get backupImportDifferingAll =>
      'Songs that exist here with a different text:';

  @override
  String get backupRestorePersonal =>
      'Restore my personal adjustments and notes';

  @override
  String backupPersonalOf(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$library: $_temp0';
  }

  @override
  String get backupRestoreSettings => 'Restore my settings';

  @override
  String get backupRestoreSettingsHint =>
      'Replaces your current settings with those of the backup.';

  @override
  String get backupRestoreStart => 'Restore';

  @override
  String get backupRestoreDone => 'Backup restored';

  @override
  String backupResultPersonal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return 'Personal adjustments and notes of $_temp0 restored';
  }

  @override
  String get backupResultSettings => 'Settings restored';

  @override
  String backupReminder(int days) {
    return 'Your library on this device has not been backed up for $days days.';
  }

  @override
  String get backupReminderAction => 'Back up';

  @override
  String get orgClose => 'Close organization';

  @override
  String orgCloseTitle(String org) {
    return 'Close $org?';
  }

  @override
  String orgCloseMessage(int days) {
    return 'Its bands, sets, songs and attachments and everyone\'s personal adjustments for its songs are removed, and its invitations are revoked. Members are told the next time they sync. Its admins can restore it from the trash for $days days; after that everything is deleted for good.';
  }

  @override
  String orgCloseBands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bands',
      one: '1 band',
      zero: 'no bands',
    );
    return '$_temp0';
  }

  @override
  String orgCloseSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'no songs',
    );
    return '$_temp0';
  }

  @override
  String orgClosePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get orgCloseBackup => 'Back up first';

  @override
  String orgClosed(String org) {
    return '$org closed';
  }

  @override
  String get orgsClosedTitle => 'Closed organizations';

  @override
  String orgsClosedEmpty(int days) {
    return 'No closed organizations. Their admins can restore closed organizations here for $days days.';
  }

  @override
  String orgsClosedHint(int days) {
    return 'Closed organizations can be restored with everything in them for $days days. After that they are deleted for good.';
  }

  @override
  String orgClosedOn(String date) {
    return 'closed on $date';
  }

  @override
  String orgClosedBy(String name) {
    return 'by $name';
  }

  @override
  String orgClosedNotice(String org, String name, int days) {
    return '$org was closed by $name. Its admins can restore it for $days days.';
  }

  @override
  String orgClosedNoticeAnonymous(String org, int days) {
    return '$org was closed. Its admins can restore it for $days days.';
  }

  @override
  String get navOverview => 'Overview';

  @override
  String get overviewNextSet => 'Next set';

  @override
  String get overviewLastEditedSet => 'Last edited set';

  @override
  String overviewSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String get overviewStartLive => 'Start live';

  @override
  String get overviewOpenSet => 'Open set';

  @override
  String get overviewTodo => 'To do';

  @override
  String overviewTodoProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with ChordPro problems',
      one: '1 song with ChordPro problems',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with sync conflicts',
      one: '1 song with a sync conflict',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoSheetMusicOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with sheet music (PDF) only',
      one: '1 song with sheet music (PDF) only',
    );
    return '$_temp0';
  }

  @override
  String get attentionProblems => 'ChordPro problems';

  @override
  String get attentionConflicts => 'Sync conflicts';

  @override
  String get attentionSheetMusicOnly => 'Sheet music only';

  @override
  String chordProConversionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Convert $count places in the ChordPro',
      one: 'Convert 1 place in the ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with possible conversions',
      one: '1 song with possible conversions',
    );
    return '$_temp0';
  }

  @override
  String get attentionConversions => 'Convertible';

  @override
  String get convertAllSongs => 'Convert all';

  @override
  String get convertAllSongsTitle => 'Convert all songs?';

  @override
  String convertAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The $count songs are',
      one: 'The song is',
    );
    return '$_temp0 converted for everyone: CCLI directives and section labels as the ChordPro specification recommends, CCLI bar lines as grids, the CCLI footer removed.';
  }

  @override
  String songsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs converted',
      one: '1 song converted',
    );
    return '$_temp0';
  }

  @override
  String songConverted(String title) {
    return '“$title” converted';
  }

  @override
  String get songsFilterEmpty => 'No songs left in this filter.';

  @override
  String get playHistory => 'Played';

  @override
  String playHistoryOf(String band) {
    return 'Played by $band';
  }

  @override
  String playHistoryNone(String band) {
    return '$band has not played this song in a past set yet.';
  }

  @override
  String get playHistoryTotal => 'in total';

  @override
  String get playHistoryLastYear => 'last 12 months';

  @override
  String get playHistoryLast => 'last';

  @override
  String playHistoryFirst(String date) {
    return 'First on $date';
  }

  @override
  String playHistoryShowAll(int count) {
    return 'Show all $count';
  }

  @override
  String playHistoryDiffers(String key) {
    return 'Highlighted: a key other than today\'s ($key)';
  }

  @override
  String get playHistoryApproximate =>
      '≈ derived from today\'s arrangement: the set has no stored values';

  @override
  String keyHistoryLast(String key, String date) {
    return 'Last $key on $date';
  }

  @override
  String keyHistoryMostly(String key, int count, int total) {
    return 'mostly $key ($count of $total)';
  }

  @override
  String songLastPlayed(String date) {
    return 'Last played on $date';
  }

  @override
  String get songNeverPlayed => 'Never played';

  @override
  String get overviewRecentChanges => 'Recent changes';

  @override
  String get overviewShowAll => 'Show all';

  @override
  String get overviewMoreSets => 'More sets';

  @override
  String get overviewNewestSongs => 'Newest songs';

  @override
  String get recentChangesEmpty => 'No changes by others in the last 30 days.';

  @override
  String get changeSongAdded => 'New song';

  @override
  String get changeNewSet => 'New set';

  @override
  String get changeSongText => 'Text changed';

  @override
  String get changeSongPdf => 'PDF changed';

  @override
  String get changeSongTextAndPdf => 'Text and PDF changed';

  @override
  String changeSetAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs added',
      one: '1 song added',
    );
    return '$_temp0';
  }

  @override
  String changeSetRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs removed',
      one: '1 song removed',
    );
    return '$_temp0';
  }

  @override
  String changeSetAlsoRemoved(int count) {
    return '$count removed';
  }

  @override
  String changeSetSequence(String songs) {
    return 'sequence of $songs changed';
  }

  @override
  String changeQuoted(String title) {
    return '\"$title\"';
  }

  @override
  String changeBy(String name) {
    return 'by $name';
  }

  @override
  String get repertoire => 'Repertoire';

  @override
  String repertoireOf(String band) {
    return 'Repertoire of $band';
  }

  @override
  String get repertoireLastYear => '12 months';

  @override
  String get repertoireAllTime => 'All time';

  @override
  String get repertoireMostPlayed => 'Most played';

  @override
  String get repertoireStale => 'Not played for a while';

  @override
  String repertoireStaleHint(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Last played more than $months months ago',
      one: 'Last played more than a month ago',
    );
    return '$_temp0';
  }

  @override
  String get playedFilter => 'Played';

  @override
  String get playedAll => 'All';

  @override
  String get filterByPlayed => 'Filter by the band\'s plays';

  @override
  String get repertoireNeverPlayed => 'Never played';

  @override
  String get repertoireNeverPlayedHint =>
      'Songs of the library that were in no past set of the band';

  @override
  String get repertoireNone => 'None';

  @override
  String get repertoireEmpty =>
      'The band has not played any songs in past sets yet.';

  @override
  String repertoirePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String get repertoireThreshold =>
      'When does a song count as not played for a while?';

  @override
  String repertoireMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'After $months months',
      one: 'After 1 month',
    );
    return '$_temp0';
  }

  @override
  String repertoireDefault(int months) {
    return 'Default: after $months months';
  }

  @override
  String get sortByLastPlayed => 'Last played';

  @override
  String get playHistoryOtherBands => 'Other bands';

  @override
  String playHistoryFetched(String date) {
    return 'As of $date';
  }

  @override
  String get libraryUsage => 'Library usage';

  @override
  String libraryUsageSummary(int count, int total) {
    return 'No band plays $count of $total songs';
  }

  @override
  String get libraryUsageHint =>
      'Songs that were in no past set of any band of the organization. Move what no band needs any more to the trash.';

  @override
  String get libraryUsageNotLoaded =>
      'Not loaded yet: sync once while connected to the server.';

  @override
  String get libraryUsageAllPlayed =>
      'Every song of the library was played by a band.';

  @override
  String syncHintSongChanged(String title, String name) {
    return '\"$title\" was changed by $name.';
  }

  @override
  String syncHintSongDeleted(String title, String name) {
    return '\"$title\" was deleted by $name.';
  }

  @override
  String syncHintSetChanged(String title, String name) {
    return 'The set \"$title\" was changed by $name.';
  }

  @override
  String syncHintSetDeleted(String title, String name) {
    return 'The set \"$title\" was deleted by $name.';
  }

  @override
  String syncHintSongChangedAnonymous(String title) {
    return '\"$title\" was changed by someone else.';
  }

  @override
  String syncHintSongDeletedAnonymous(String title) {
    return '\"$title\" was deleted by someone else.';
  }

  @override
  String syncHintSetChangedAnonymous(String title) {
    return 'The set \"$title\" was changed by someone else.';
  }

  @override
  String syncHintSetDeletedAnonymous(String title) {
    return 'The set \"$title\" was deleted by someone else.';
  }

  @override
  String syncHintAfterLive(String changes) {
    return 'While you were playing live: $changes.';
  }

  @override
  String syncHintSongsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs changed',
      one: '1 song changed',
    );
    return '$_temp0';
  }

  @override
  String syncHintSongsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs deleted',
      one: '1 song deleted',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets changed',
      one: '1 set changed',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets deleted',
      one: '1 set deleted',
    );
    return '$_temp0';
  }

  @override
  String get syncHintShowChanges => 'Show';

  @override
  String get setExportTitle => 'Export set';

  @override
  String get setExportHint =>
      'The ZIP holds the ChordPro files of the songs and a description from which setDING imports the set again as a set.';

  @override
  String get setArchiveArrangements =>
      'Band arrangements of the songs (key, sequence, tempo)';

  @override
  String get setArchiveSetSettings =>
      'Key and sequence of the songs in this set';

  @override
  String get setArchiveAttachments => 'Attachments (PDFs, images)';

  @override
  String get setArchivePersonal => 'My personal adjustments and notes';

  @override
  String get setArchivePersonalHint =>
      'Leave this off if you pass the file on.';

  @override
  String get setExportStart => 'Export';

  @override
  String get exportMenu => 'Export …';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportFormatChordPro => 'ChordPro file';

  @override
  String get exportFormatChordProHint =>
      'For other apps, without attachments and arrangements';

  @override
  String get exportFormatSetListPdf => 'Set list as PDF';

  @override
  String get exportFormatSetListPdfHint => 'For printing';

  @override
  String get exportFormatArchive => 'setDING archive (ZIP)';

  @override
  String get exportFormatArchiveHint =>
      'For importing into setDING, with attachments and arrangements if you like';

  @override
  String get songExportHintChordPro =>
      'The ChordPro file holds the lyrics and chords of the song and opens in any app that knows ChordPro.';

  @override
  String get setExportHintPdf =>
      'The set list shows every song with its key and sequence, for printing for the stage.';

  @override
  String get setImport => 'Import set';

  @override
  String get setImportFromFile => 'Import from file …';

  @override
  String get setImportTitle => 'Import set';

  @override
  String get setImportBand => 'Band';

  @override
  String get setImportNoBand =>
      'There is no band in this library whose sets you may manage.';

  @override
  String setImportExisting(String name) {
    return 'The band already has this set as \"$name\".';
  }

  @override
  String get setImportReplace => 'Replace it';

  @override
  String get setImportCopy => 'Add as a copy';

  @override
  String setImportOverwriteArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return 'Overwrite the band\'s arrangements of $_temp0';
  }

  @override
  String get setImportDone => 'Set imported';

  @override
  String get setImportReplaced => 'The existing set was replaced.';

  @override
  String setImportResultArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count band arrangements saved',
      one: '1 band arrangement saved',
    );
    return '$_temp0';
  }

  @override
  String get setImportResultMissing =>
      'Not in the library, shown as text items in the set:';

  @override
  String get setImportOpen => 'Open set';

  @override
  String setImportMissingNote(String title) {
    return 'Missing: $title';
  }

  @override
  String get setArchiveInvalid => 'This file is not an exported set.';

  @override
  String get setArchiveNewer =>
      'This set was exported with a newer version of setDING. Update the app to import it.';

  @override
  String setImportFrom(String band, int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
      zero: 'no songs',
    );
    return 'from $band · $_temp0';
  }

  @override
  String get setImportHeadingTarget => 'Destination';

  @override
  String get setImportHeadingExisting => 'Set already here';

  @override
  String get setImportHeadingSongs => 'Songs';

  @override
  String get setImportHeadingInclude => 'Include';

  @override
  String get setExportHeadingInclude => 'Include in the archive';

  @override
  String setImportNewName(String name) {
    return 'Will be added as \"$name\".';
  }

  @override
  String setImportSongsHere(int count) {
    return '$count already here with the same text';
  }

  @override
  String setImportSongsNew(int count) {
    return '$count new, added to the library';
  }

  @override
  String setImportSongsDiffering(int count) {
    return '$count here with a different text';
  }

  @override
  String setImportSongsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return '$count not in the library – you may not add songs, so the set shows $_temp0 as text';
  }

  @override
  String get setImportKeep => 'Keep existing';

  @override
  String get setImportAddAll => 'Import as well';

  @override
  String setImportCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String setImportCopyNameNumbered(String name, int number) {
    return '$name (copy $number)';
  }

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get shortcutsEverywhere => 'Everywhere';

  @override
  String get shortcutsSong => 'Song';

  @override
  String get shortcutsSet => 'Set';

  @override
  String get shortcutsSongList => 'Song list';

  @override
  String get shortcutsLive => 'Live mode';

  @override
  String get shortcutBack => 'Back';

  @override
  String get shortcutHelp => 'Show the keyboard shortcuts';

  @override
  String get shortcutEditSong => 'Edit the song';

  @override
  String get shortcutEditSet => 'Edit the set';

  @override
  String get shortcutLive => 'Start live mode';

  @override
  String get shortcutTranspose => 'Transpose up / down';

  @override
  String get shortcutPreviousNextSong => 'Previous / next song of the set';

  @override
  String get shortcutSearch => 'Search songs';

  @override
  String get shortcutNextPage => 'Next page';

  @override
  String get shortcutPreviousPage => 'Previous page';

  @override
  String get shortcutBeat => 'Start / stop the beat';

  @override
  String get shortcutKeyPageDown => 'Page Down';

  @override
  String get shortcutKeyPageUp => 'Page Up';

  @override
  String get shortcutKeySpace => 'Space';

  @override
  String get shortcutCloseSelection => 'Close the selection';

  @override
  String get settingsHeadingLanguageTheme => 'Language & theme';

  @override
  String get settingsHeadingEditor => 'Editor';

  @override
  String get settingsHeadingAdvanced => 'Advanced';

  @override
  String get settingsHeadingChords => 'Chords';

  @override
  String get settingsHeadingContent => 'Content';

  @override
  String get settingsHeadingSetNotes => 'Set & notes';

  @override
  String get settingsHeadingInstrument => 'Instrument & voice';

  @override
  String get settingsHeadingScreen => 'Screen';

  @override
  String get settingsHeadingControls => 'Controls';

  @override
  String get settingsHeadingClick => 'Click on this device';

  @override
  String get settingsHeadingBackup => 'Backup';

  @override
  String get settingsHeadingThisDevice => 'This device';

  @override
  String get settingsHeadingHelp => 'Help & info';

  @override
  String get settingsHeadingConnection => 'Connection';

  @override
  String get settingsHeadingKeyboard => 'Keyboard';

  @override
  String get settingsHeadingStyle => 'Style';

  @override
  String get settingsHeadingPrototypes => 'Prototypes';

  @override
  String songExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Export $count songs',
      one: 'Export song',
    );
    return '$_temp0';
  }

  @override
  String get songExportHint =>
      'The ZIP holds the ChordPro files and a description from which setDING imports the songs again, plus what you choose below.';

  @override
  String songExportArrangements(String band) {
    return 'Arrangements of \"$band\" (key, sequence, tempo)';
  }

  @override
  String get songImportTitle => 'Import songs';

  @override
  String songImportFrom(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return 'from $library · $_temp0';
  }

  @override
  String songImportLibrary(String name) {
    return 'Into the library \"$name\"';
  }

  @override
  String get songImportArrangementsBand => 'Band for the arrangements';

  @override
  String get songImportNoBand =>
      'There is no band in this library whose arrangements you may change.';

  @override
  String get songImportDone => 'Songs imported';

  @override
  String get songArchiveNewer =>
      'These songs were exported with a newer version of setDING. Update the app to import them.';

  @override
  String archiveImportAttachmentsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0 added to songs that are already here';
  }

  @override
  String archiveResultCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0 added to existing songs';
  }

  @override
  String songLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'German',
      'gsw': 'Swiss German',
      'en': 'English',
      'fr': 'French',
      'it': 'Italian',
      'es': 'Spanish',
      'pt': 'Portuguese',
      'nl': 'Dutch',
      'other': 'Other',
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
  String get songLanguage => 'Language';

  @override
  String get songLanguageMenu => 'Language …';

  @override
  String get allLanguages => 'All languages';

  @override
  String get noLanguage => 'No language';

  @override
  String get filterByLanguage => 'Filter by language';

  @override
  String songLanguageAutomatic(String language) {
    return 'Automatic: $language';
  }

  @override
  String get songLanguageNotDetected => 'Automatic (not detected)';

  @override
  String get songLanguageAutomaticHint =>
      'Detected from the lyrics; a choice by hand always wins.';

  @override
  String songLanguageDetectedTooltip(String language) {
    return '$language (detected from the lyrics)';
  }

  @override
  String songLanguageByHandTooltip(String language) {
    return '$language (set by hand)';
  }

  @override
  String get languageVersions => 'Language versions';

  @override
  String get linkLanguageVersion => 'Language versions …';

  @override
  String get unlinkLanguageVersion => 'Remove from the language versions';

  @override
  String get languageVersionPickerEmpty => 'No other songs you may link';

  @override
  String languageVersionsOf(String title) {
    return 'Language versions of $title';
  }

  @override
  String languageVersionsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Linked versions ($count)',
      zero: 'Linked versions',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionsChosenEmpty =>
      'No other versions yet. Choose songs from the library.';

  @override
  String get languageVersionsSaved => 'Language versions saved';

  @override
  String languageVersionsNotAllowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count songs were not linked: you may not change their other versions.',
      one: 'One song was not linked: you may not change its other versions.',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionUnlinked => 'Removed from the language versions';

  @override
  String otherLanguageVersionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other language versions',
      one: 'One other language version',
    );
    return '$_temp0';
  }

  @override
  String get switchLanguageVersion => 'Switch language version …';

  @override
  String switchedLanguageVersion(String version) {
    return 'Switched to: $version';
  }

  @override
  String switchedLanguageVersionKey(
    String version,
    String newKey,
    String oldKey,
  ) {
    return 'Switched to: $version, in $newKey instead of $oldKey in this set';
  }

  @override
  String get switchedLanguageVersionSequence =>
      'The set’s own sequence does not fit the new version and was removed.';

  @override
  String languageVersionInSet(String title, String key) {
    return '$title · in $key in this set';
  }

  @override
  String get switchLanguageVersionTitle => 'Switch language version';

  @override
  String adjustmentOfferOne(String version, String what) {
    return 'Your adjustments in “$version”: $what. Use them for this version too?';
  }

  @override
  String get adjustmentOfferMany =>
      'Other language versions have your adjustments. Use them for this version too?';

  @override
  String get adjustmentKindTranspose => 'key';

  @override
  String get adjustmentKindCapo => 'capo';

  @override
  String get adjustmentKindMidi => 'keyboard program';

  @override
  String get adjustmentKindClick => 'click';

  @override
  String get adjustmentOfferCopy => 'Use them';

  @override
  String get adjustmentOfferDismiss => 'No thanks';

  @override
  String get adjustmentOfferPick => 'Use the adjustments of';

  @override
  String adjustmentsCopied(String version) {
    return 'Adjustments of “$version” used';
  }

  @override
  String get autoBackup => 'Automatic backup';

  @override
  String get autoBackupSwitch => 'Back up automatically';

  @override
  String get autoBackupHint =>
      'Saves the library “On this device” into a folder you choose, at most once a day after changes. Use a folder of your cloud storage to keep it safe when the device is lost.';

  @override
  String get autoBackupFolder => 'Folder';

  @override
  String get autoBackupFolderNone => 'No folder chosen';

  @override
  String get autoBackupChooseFolder => 'Choose folder';

  @override
  String get autoBackupDevice => 'Device name';

  @override
  String get autoBackupDeviceHint =>
      'Part of the file names, so several devices can use the same folder.';

  @override
  String get autoBackupDeviceTitle => 'Device name for backups';

  @override
  String get autoBackupKeep => 'Backups kept';

  @override
  String get autoBackupKeepHint =>
      'Older automatic backups of this device are deleted from the folder.';

  @override
  String get autoBackupNow => 'Back up to the folder now';

  @override
  String get autoBackupRunning => 'Backing up …';

  @override
  String get autoBackupNever => 'No automatic backup yet.';

  @override
  String autoBackupLast(String date) {
    return 'Last automatic backup: $date';
  }

  @override
  String autoBackupFailed(String date, String reason) {
    return 'Failed on $date: $reason';
  }

  @override
  String get autoBackupErrorUnavailable => 'The folder is not reachable.';

  @override
  String get autoBackupErrorPermission =>
      'setDING may no longer write into the folder. Choose it again.';

  @override
  String get autoBackupErrorFailed => 'The backup could not be written.';

  @override
  String autoBackupHintFailed(String reason) {
    return 'Automatic backup failed: $reason';
  }

  @override
  String autoBackupSaved(String file) {
    return 'Saved as “$file”';
  }

  @override
  String get backupModeCopy => 'Add as a copy';

  @override
  String get backupModeCopyHint =>
      'Songs and sets are added with new IDs; nothing existing is changed.';

  @override
  String get backupModeReplace => 'Replace the local library';

  @override
  String get backupModeReplaceHint =>
      'The library “On this device” becomes exactly as in the backup, e.g. on a new device or to go back to an earlier state.';

  @override
  String get backupReplaceTitle => 'Replace the local library?';

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
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Backup of “$device” from $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceFrom(String date, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Backup from $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceNow(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Now on this device: $_temp0, $_temp1. They are removed, also those in the trash.';
  }

  @override
  String get backupReplaceKeeps =>
      'The play history comes back with the sets of the backup. Settings and organizations are not changed.';

  @override
  String get backupReplaceSafety => 'Save a safety backup first';

  @override
  String backupReplaceSafetyFolder(String folder) {
    return 'Into the folder of the automatic backup ($folder).';
  }

  @override
  String get backupReplaceSafetyChoose => 'You choose where to save it.';

  @override
  String get backupReplaceSafetySkip =>
      'Without a safety backup, the current library cannot be restored.';

  @override
  String get backupReplaceAction => 'Replace';

  @override
  String get backupReplaceRunning => 'Replacing the local library …';

  @override
  String backupReplaceDone(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Local library replaced: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceSafetyFailed(String reason) {
    return 'The safety backup could not be saved, so nothing was replaced: $reason';
  }

  @override
  String get showLocalLibrary => 'Show the local library';

  @override
  String get showLocalLibraryHint =>
      '“On this device” in the lists of libraries and bands. If you play only in organizations, you can hide it; its songs and sets stay on this device.';

  @override
  String get showLocalLibrarySignedOut =>
      'Signed out, the local library is always shown.';

  @override
  String localLibraryHidden(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'The local library is hidden. Its $_temp0 and $_temp1 stay on this device and come back when you show it again.';
  }

  @override
  String get localLibraryHiddenAutoBackup =>
      'The automatic backup keeps running; you can switch it off here.';

  @override
  String get chordViewChords => 'Chords';

  @override
  String get chordViewNashville => 'Nashville';

  @override
  String get chordViewNumerals => 'Numerals';

  @override
  String get liveChordViewChords => 'C';

  @override
  String get liveChordViewNashville => '1';

  @override
  String get liveChordViewNumerals => 'I';

  @override
  String get chordViewDocs => 'How to read Nashville numbers and numerals';

  @override
  String docsHelp(String topic) {
    return 'Help: $topic';
  }

  @override
  String get editorDocsTopic => 'ChordPro editor';

  @override
  String get settingsDocs => 'User guide';

  @override
  String get settingsDocsHint =>
      'Open the setDING documentation on setding.app. The book icon at the top opens the page about the open section.';

  @override
  String get overviewReadiness => 'Ready to play';

  @override
  String readinessAllSet(String set) {
    return 'All set for “$set”';
  }

  @override
  String get readinessAllSetNoSet => 'All set';

  @override
  String get readinessShowDetails => 'Show details';

  @override
  String get readinessHideDetails => 'Hide details';

  @override
  String readinessMusician(String who) {
    return 'Musician: $who';
  }

  @override
  String get readinessNoInstrument => 'No instrument chosen';

  @override
  String readinessMidiConnected(String device) {
    return 'MIDI: $device connected';
  }

  @override
  String get readinessMidiNotConnected => 'MIDI: keyboard not connected';

  @override
  String get readinessMidiNoOutput => 'MIDI: no keyboard chosen';

  @override
  String readinessMidiProfile(String profile) {
    return 'Profile: $profile';
  }

  @override
  String get readinessOfflineReady => 'Next set available offline';

  @override
  String readinessOfflineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs of the next set are',
      one: '1 song of the next set is',
    );
    return '$_temp0 not available offline';
  }

  @override
  String readinessSynced(String time) {
    return 'Synced: $time';
  }

  @override
  String get readinessSyncNever => 'Not synced on this device yet';

  @override
  String get readinessSyncStale => 'Data may not be up to date';

  @override
  String get readinessSyncManual => 'Sync is manual: sync before the gig.';

  @override
  String get readinessPageTurnerResponds => 'Page turner responds';

  @override
  String readinessPageTurnerLastUsed(String time) {
    return 'Page turner: last used $time';
  }

  @override
  String get readinessPageTurnerNever =>
      'Page turner: not used on this device yet';

  @override
  String readinessPageTurnerDetail(String mode) {
    return 'Turns: $mode · press the pedal here to test it';
  }

  @override
  String get readinessBackupNoFolder => 'Automatic backup: no folder chosen';

  @override
  String get readinessBackupFailed => 'Automatic backup failed';

  @override
  String get keyGuessHint => 'Suggested from the chords:';

  @override
  String keyGuessUse(String key) {
    return 'Use $key as the key';
  }

  @override
  String get attentionNoKey => 'No key';

  @override
  String overviewTodoNoKey(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs without a key',
      one: '1 song without a key',
    );
    return '$_temp0';
  }

  @override
  String readinessPageTurnerConnected(String name) {
    return 'Page turner $name connected';
  }

  @override
  String readinessPageTurnerNotConnected(String name) {
    return 'Page turner $name not connected';
  }

  @override
  String get readinessKeyboardConnected => 'A keyboard is connected';

  @override
  String get readinessKeyboardNotConnected =>
      'Page turner: no keyboard connected';

  @override
  String get settingsPageTurner => 'Page turner';

  @override
  String get settingsPageTurnerNone => 'Not paired';

  @override
  String get settingsPageTurnerConnected => 'connected';

  @override
  String get settingsPageTurnerNotConnected => 'not connected';

  @override
  String get settingsPageTurnerHint =>
      'Pair your pedal so the overview shows whether it is connected.';

  @override
  String get settingsPageTurnerPair => 'Pair';

  @override
  String get settingsPageTurnerPairAgain => 'Pair again';

  @override
  String get settingsPageTurnerForget => 'Forget page turner';

  @override
  String get settingsPageTurnerKeyboardOnly =>
      'This device only tells whether a keyboard is connected, not which one. The overview shows that.';

  @override
  String get settingsPageTurnerUnsupported =>
      'Not possible on this platform. The overview shows when the page turner was last used.';

  @override
  String get pairPageTurnerTitle => 'Pair page turner';

  @override
  String get pairPageTurnerPrompt => 'Press the pedal now.';

  @override
  String pageTurnerPaired(String name) {
    return 'Page turner paired: $name';
  }

  @override
  String pageTurnerForgotten(String name) {
    return 'Page turner forgotten: $name';
  }

  @override
  String get pageTurnerUnnamed => 'Device without a name';

  @override
  String importKeySuggestionsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imported songs have',
      one: '1 imported song has',
    );
    return '$_temp0 no key. Suggested from the chords; a tap sets the key:';
  }

  @override
  String importKeySuggestionsMore(int count) {
    return '… and $count more: To do on the overview, No key.';
  }

  @override
  String importKeysSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keys set in $count songs',
      one: 'Key set in 1 song',
      zero: 'No key set',
    );
    return '$_temp0';
  }

  @override
  String get readinessPageTurnerNotPaired => 'Page turner not paired';

  @override
  String readinessPageTurnerPairDetail(String mode) {
    return 'Pair it so the overview shows whether it is connected · Turns: $mode';
  }

  @override
  String get settingsPageTurnerUse => 'I use a page turner';

  @override
  String get settingsPageTurnerUseHint =>
      'A foot pedal that turns the pages. Shows it on the overview and offers to pair one that is detected.';

  @override
  String pageTurnerDetected(String name) {
    return 'Page turner detected: $name';
  }

  @override
  String get attentionToReview => 'To review';

  @override
  String get attentionReported => 'Reported';

  @override
  String overviewTodoToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs to review',
      one: '1 song to review',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoReported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs with reported mistakes',
      one: '1 song with a reported mistake',
    );
    return '$_temp0';
  }

  @override
  String get songToReviewTooltip => 'Not checked yet';

  @override
  String get songReportedTooltip => 'Mistake reported';

  @override
  String get songToReviewHint => 'This song has not been checked yet.';

  @override
  String get songReportedHint => 'A mistake was reported in this song.';

  @override
  String reviewBannerToReview(String reason) {
    return 'To review: $reason';
  }

  @override
  String reviewBannerReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open reports',
      one: '1 open report',
    );
    return '$_temp0';
  }

  @override
  String get showReports => 'Show';

  @override
  String get approveSong => 'Approve';

  @override
  String get songApproved => 'Song approved';

  @override
  String get approveAllSongs => 'Approve all';

  @override
  String get approveAllSongsTitle => 'Approve all songs?';

  @override
  String approveAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs will count as checked.',
      one: '1 song will count as checked.',
    );
    return '$_temp0';
  }

  @override
  String songsApproved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs approved',
      one: '1 song approved',
    );
    return '$_temp0';
  }

  @override
  String get resolveReportsTitle => 'Resolve the reports?';

  @override
  String resolveReportsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The song has $count open reports. Mark them as resolved too?',
      one: 'The song has 1 open report. Mark it as resolved too?',
    );
    return '$_temp0';
  }

  @override
  String get resolveReports => 'Resolve';

  @override
  String get setToReviewMenu => 'Mark for review …';

  @override
  String get setToReviewTitle => 'Mark for review';

  @override
  String get reviewReasonLabel => 'Reason';

  @override
  String get reviewReasonHint => 'e.g. the bridge is wrong';

  @override
  String get reviewReasonAfterImport => 'After import';

  @override
  String setReviewHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs are not checked yet or have reported mistakes',
      one: '1 song is not checked yet or has a reported mistake',
    );
    return '$_temp0';
  }

  @override
  String get reportMistake => 'Report a mistake';

  @override
  String get reportMistakeMenu => 'Report a mistake …';

  @override
  String get reportCategoryChords => 'Chords';

  @override
  String get reportCategoryLyrics => 'Lyrics';

  @override
  String get reportCategoryKey => 'Key';

  @override
  String get reportCategorySequence => 'Sequence';

  @override
  String get reportCategoryTempo => 'Tempo';

  @override
  String get reportCategoryFormatting => 'Formatting';

  @override
  String get reportCategorySheetMusic => 'Sheet music (PDF)';

  @override
  String get reportCategoryOther => 'Other';

  @override
  String get reportComment => 'Comment';

  @override
  String get reportCommentHint => 'What\'s wrong?';

  @override
  String get reportSend => 'Send';

  @override
  String get reportSent => 'Mistake reported. Thank you!';

  @override
  String reportLocation(String place) {
    return 'Where: $place';
  }

  @override
  String reportLocationPage(int page) {
    return 'Page $page';
  }

  @override
  String reportLocationPdfPage(int page) {
    return 'PDF page $page';
  }

  @override
  String reportLocationLine(int line) {
    return 'Line $line';
  }

  @override
  String get reportsTitle => 'Mistake reports';

  @override
  String get reportsEmpty => 'No reports';

  @override
  String reportsClosed(int count) {
    return 'Resolved and withdrawn ($count)';
  }

  @override
  String get reportByYou => 'by you';

  @override
  String reportBy(String name) {
    return 'by $name';
  }

  @override
  String get reportWithdrawn => 'withdrawn';

  @override
  String get reportWithdraw => 'Withdraw';

  @override
  String get reportWithdrawnMessage => 'Report withdrawn';

  @override
  String get resolveReport => 'Resolve the report';

  @override
  String get reportAnswerLabel => 'Answer';

  @override
  String get reportAnswerHint => 'e.g. Fixed, thanks!';

  @override
  String get reportResolvedMessage => 'Report resolved';

  @override
  String get reportReopen => 'Reopen';

  @override
  String get reportReopenedMessage => 'Report reopened';

  @override
  String get reportResolvedNoAnswer => 'Resolved';

  @override
  String reportAnswer(String answer) {
    return 'Resolved: $answer';
  }

  @override
  String reportAnswered(String song, String answer) {
    return 'Your report on “$song” was resolved: $answer';
  }

  @override
  String reportAnsweredNoText(String song) {
    return 'Your report on “$song” was resolved.';
  }

  @override
  String reportsAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of your reports were resolved.',
      one: '1 of your reports was resolved.',
    );
    return '$_temp0';
  }

  @override
  String get screenshotAdd => 'Attach a screenshot';

  @override
  String get screenshotRemove => 'Remove';

  @override
  String get screenshotMarkTitle => 'Mark the place';

  @override
  String get screenshotMarkHint =>
      'Draw on the screenshot where the mistake is.';

  @override
  String get screenshotAttach => 'Attach';

  @override
  String get screenshotShow => 'Show the screenshot full size';

  @override
  String get screenshotLoading => 'Loading the screenshot …';

  @override
  String get screenshotUnavailable => 'Screenshot not available (offline?)';

  @override
  String get lineup => 'Lineup';

  @override
  String get lineupWholeBand => 'Whole band';

  @override
  String get lineupSubstitute => 'Substitute';

  @override
  String get lineupBandMembers => 'Band members';

  @override
  String get lineupSubstitutes => 'Substitutes';

  @override
  String get lineupNotPlanned => 'Not planned for you';

  @override
  String get lineupEdit => 'Choose lineup';

  @override
  String get lineupAddPeople => 'Add people';

  @override
  String get lineupSearchPeople => 'Search people';

  @override
  String get lineupNoMorePeople =>
      'Everyone in the organization is in the lineup already.';

  @override
  String get lineupNoAccount => 'No account';

  @override
  String get lineupPeopleWithoutAccount => 'People without an account';

  @override
  String get lineupNewContact => 'New person without an account';

  @override
  String get contactEmail => 'Mail address (optional)';

  @override
  String get contactEmailHint =>
      'Only people who plan sets see it. “Notify lineup” writes to this address.';

  @override
  String get contactNameHint => 'Only the first name is needed.';

  @override
  String get contactsHint =>
      'People who play with you but do not use setDING. They can be put in the lineup of sets.';

  @override
  String get contactEditTitle => 'Edit person';

  @override
  String get contactInvite => 'Invite to setDING';

  @override
  String get contactInviteChooseBand => 'Invite into which band?';

  @override
  String contactDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String contactDeleteMessage(String name) {
    return '$name is no longer offered for lineups, and the mail address is removed. Sets that name $name keep the name.';
  }

  @override
  String contactInviteTitle(String name) {
    return 'Personal invitation for $name';
  }

  @override
  String contactInviteHint(String date, String name) {
    return 'The link works once, until $date. Whoever creates an account with it takes over the sets $name is planned for.';
  }

  @override
  String get contactInviteSubject => 'Invitation to setDING';

  @override
  String contactInviteBody(String name, String organization, String url) {
    return 'Hello $name\n\nYou are invited to join $organization on setDING, where you find the chords of our songs and the sets you are planned for. Open this link to create your account:\n$url';
  }

  @override
  String joinPersonal(String name) {
    return 'This invitation is for $name.';
  }

  @override
  String joinPersonalExplanation(String name) {
    return 'Your account takes over the sets $name is planned for.';
  }

  @override
  String get joinPersonalButton => 'Accept invitation';

  @override
  String get lineupNobody => 'Nobody planned';

  @override
  String get lineupWholeBandHint =>
      'The lineup follows the band, new members included.';

  @override
  String get bandSubstituteHint =>
      'You play some sets of this band as a substitute and see only those sets.';

  @override
  String get overviewAsSubstitute => 'As a substitute';

  @override
  String get lineupNotify => 'Notify lineup';

  @override
  String get lineupCopy => 'Copy';

  @override
  String get lineupCopied => 'Text copied';

  @override
  String get lineupMail => 'By mail';

  @override
  String get lineupShare => 'Share …';

  @override
  String get lineupNoAddresses =>
      'No connection to the server: choose the recipients yourself.';

  @override
  String lineupMessageIntro(String set) {
    return 'You are planned for “$set”.';
  }

  @override
  String get lineupMessageFooter => 'You find the songs in setDING.';

  @override
  String get overviewPlanned => 'You are planned';

  @override
  String get overviewPlannedSeen => 'Got it';

  @override
  String linkSwitchedTo(String name) {
    return 'Switched to $name';
  }

  @override
  String get linkNotAvailableTitle => 'Not available on this device';

  @override
  String get linkNotAvailableMessage =>
      'It is not synced to this device yet, or you have no access to it.';

  @override
  String get linkNoAccessMessage =>
      'Not available: it was deleted, or you have no access to it.';

  @override
  String get linkSignInMessage => 'Sign in to see it.';

  @override
  String get linkShare => 'Share link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String attachmentOnlyHere(String reason) {
    return 'Only on this device: $reason';
  }

  @override
  String get uploadRefusalNotAllowed => 'no permission to upload';

  @override
  String get uploadRefusalTooLarge => 'the file is too large for the server';

  @override
  String get uploadRefusalOther => 'refused by the server';

  @override
  String attachmentUploadRefused(String name, String song, String reason) {
    return 'The server did not accept “$name” of “$song” ($reason). The attachment stays on this device only.';
  }

  @override
  String attachmentUploadsRefused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The server did not accept $count attachments. They stay on this device only.',
      one: 'The server did not accept 1 attachment. It stays on this device only.',
    );
    return '$_temp0';
  }

  @override
  String get retryUpload => 'Upload again';

  @override
  String get uploadRefusalStorageFull => 'the organization\'s storage is full';

  @override
  String attachmentPdfLimit(String limit) {
    return 'PDF, at most $limit';
  }

  @override
  String storageFree(String free, String limit) {
    return '$free of $limit free';
  }

  @override
  String get storageTitle => 'Storage';

  @override
  String storageUsage(String used, String limit) {
    return 'Storage: $used of $limit';
  }

  @override
  String storageUsageUnlimited(String used) {
    return 'Storage: $used';
  }

  @override
  String get storageTrashCounts =>
      'Deleted PDFs count until they are deleted permanently.';

  @override
  String get storageNearlyFull => 'The organization\'s storage is nearly full.';

  @override
  String attachmentDoesNotFit(
    String name,
    String size,
    String used,
    String limit,
  ) {
    return '“$name” ($size) no longer fits into the organization\'s storage: $used of $limit used. Deleted PDFs count until they are deleted permanently.';
  }

  @override
  String trashAttachmentOf(String song, String size) {
    return 'PDF in “$song” · $size';
  }

  @override
  String importSkippedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments were not imported because they are too large:',
      one: '1 attachment was not imported because it is too large:',
    );
    return '$_temp0';
  }

  @override
  String importSkippedFile(String song, String size, String limit) {
    return '“$song” · $size (at most $limit)';
  }
}
