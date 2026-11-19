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
  String get newSong => 'New song';

  @override
  String get newPdfSong => 'New PDF song';

  @override
  String get importFiles => 'Import files';

  @override
  String get importTitle => 'Import ChordPro files';

  @override
  String get importDescription =>
      'Supported: .cho, .chordpro, .chopro, .crd, .pro, .txt and ZIP archives containing such files.';

  @override
  String get importGermanNotation => 'Files use German notation (H/B)';

  @override
  String get importGermanNotationHint =>
      'Chords are converted to international notation on import.';

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
  String get attachmentTooLarge =>
      'The file is larger than 20 MB and cannot be attached.';

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
  String get playLive => 'Play live';

  @override
  String get live => 'Live';

  @override
  String get nashville => 'Nashville numbers';

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
  String get noKeyForNashville => 'Nashville numbers need a key in the song.';

  @override
  String get firstVerseChordsOnly => 'Chords in verse 1 only';

  @override
  String get noVersesForFirstVerseChords =>
      'The song has no further verses with chords.';

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
  String get offlineReady => 'Offline ready';

  @override
  String get notOfflineReady => 'Not offline ready';

  @override
  String get addSongs => 'Add songs';

  @override
  String get addPause => 'Add break';

  @override
  String get addText => 'Add text';

  @override
  String get pause => 'Break';

  @override
  String get textItem => 'Text';

  @override
  String get textItemHint => 'e.g. announcement or encore';

  @override
  String get setEmpty => 'This set is empty. Add some songs.';

  @override
  String get deleteSetTitle => 'Delete set?';

  @override
  String deleteSetMessage(String name) {
    return '\"$name\" will be deleted. The songs are kept.';
  }

  @override
  String get exportSet => 'Export as ZIP';

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
  String get liveWakeLockNotice =>
      'The screen may turn off – check the device\'s power settings';

  @override
  String get liveEnd => 'End of set';

  @override
  String get liveSetOverview => 'Set overview';

  @override
  String get liveExit => 'Exit live mode';

  @override
  String get liveChordNames => 'Chords';

  @override
  String get liveNashville => 'Nashville';

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
      'Chord notation, Nashville numbers, content, chorus, progress';

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
  String get settingsUserName => 'My name or voice';

  @override
  String get settingsUserNameHint =>
      'For conditional parts, e.g. \"alto\" or \"tenor\".';

  @override
  String get settingsDiagrams => 'Chord diagrams';

  @override
  String get settingsDiagramsHint =>
      'Shows the fingerings of all chords of the song for your instrument. A song can set this itself with the diagrams directive.';

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
  String get settingsNashville => 'Show Nashville numbers';

  @override
  String get settingsNashvilleHint =>
      'Chords as scale degrees, e.g. 1, 4, 5, 6m. Needs a key in the song.';

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
      'A thin bar above the bottom bar shows the songs of the set and the pages of the current song: the current page in the accent colour, pages still to come in a lighter tone. Pauses and texts are dashed.';

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
      'Quieter clicks between the beats: eighths, triplets in 6/8.';

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
      'Lilypond notation cannot be rendered on this device. Source:';

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
  String get metaCcli => 'CCLI number';

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
  String get exportSetList => 'Export set list (text)';

  @override
  String get copySetList => 'Copy set list';

  @override
  String get setListCopied => 'Set list copied';

  @override
  String get exportSetListPdf => 'Export set list (PDF for printing)';

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
  String get accountName => 'Name';

  @override
  String get accountNameHint => 'How your bandmates see you.';

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
  String get bandLocal => 'On this device';

  @override
  String get bandLocalHint => 'Only on this device, not synced.';

  @override
  String get bandSwitch => 'Switch band';

  @override
  String get bandManage => 'Manage bands';

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
      'Creates a link that is valid for 7 days. Whoever opens it joins the organization and this band.';

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
      'Creates a link that is valid for 7 days. Whoever opens it becomes a member of the organization.';

  @override
  String get inviteLinkTitle => 'Invitation link';

  @override
  String inviteLinkHint(String date) {
    return 'Share the link, e.g. in a group chat, or let people scan the QR code. Valid until $date. The link is only shown now.';
  }

  @override
  String get inviteCopy => 'Copy link';

  @override
  String get inviteCopied => 'Link copied';

  @override
  String get invitesTitle => 'Invitation links';

  @override
  String inviteStatusValid(String date) {
    return 'Valid until $date';
  }

  @override
  String get inviteStatusExpired => 'Expired';

  @override
  String get inviteStatusRevoked => 'Revoked';

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
  String get settingsAnnotationFinger => 'Draw annotations with a finger';

  @override
  String get settingsAnnotationFingerHint =>
      'For devices without a stylus; otherwise fingers keep turning pages';

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
  String get songDisplayCustomise => 'Customise';

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
}
