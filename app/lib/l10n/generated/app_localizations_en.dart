// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BandChords';

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
  String get keyPickerTooltip => 'Choose key';

  @override
  String get keyOriginal => 'Original';

  @override
  String get capo => 'Capo';

  @override
  String capoValue(int fret) {
    return 'Capo $fret';
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
  String get notes => 'Notes';

  @override
  String get notesHint => 'Personal note for this song';

  @override
  String get editSource => 'Edit ChordPro';

  @override
  String get attachments => 'Attachments';

  @override
  String get addAttachment => 'Attach file';

  @override
  String get attachmentTooLarge =>
      'The file is larger than 20 MB and cannot be attached.';

  @override
  String get attachmentName => 'Attachment name';

  @override
  String get deleteAttachmentTitle => 'Delete attachment?';

  @override
  String deleteAttachmentMessage(String name) {
    return '\"$name\" will be deleted.';
  }

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
  String get resetAdjustments => 'Reset personal adjustments';

  @override
  String get personalAdjustments => 'Personal adjustments';

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
    return 'Key $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForNashville => 'Nashville numbers need a key in the song.';

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
  String get liveEnd => 'End of set';

  @override
  String get liveSetOverview => 'Set overview';

  @override
  String get liveExit => 'Exit live mode';

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionDisplay => 'Display';

  @override
  String get settingsSectionLive => 'Live mode';

  @override
  String get settingsSectionStorage => 'Storage';

  @override
  String get settingsSectionMusician => 'Musician';

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
  String get settingsPedalHint =>
      'Foot pedal and keyboard: arrow keys, Page Up/Down and Space turn pages. Tap the left or right side of the screen to go back or forward.';

  @override
  String settingsStorageUsed(String size) {
    return 'PDF attachments use $size';
  }

  @override
  String get settingsAbout =>
      'BandChords runs locally on this device. All data is available offline.';

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
}
