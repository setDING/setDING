import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/songs/editor_toolbar.dart';

/// Song section names (Verse, Chorus, Bridge, …) are musician terminology
/// and stay English in every UI language (#533). The editor also writes
/// them into the shared ChordPro text as labels, which must never be
/// localized (ADR-0008).
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  List<String> names(AppLocalizations l) => [
    l.sectionVerse,
    l.sectionChorus,
    l.sectionBridge,
    l.sectionTab,
    l.sectionGrid,
    l.sectionIntro,
    l.sectionPreChorus,
    l.sectionPostChorus,
    l.sectionInterlude,
    l.sectionInstrumental,
    l.sectionSolo,
    l.sectionTag,
    l.sectionOutro,
    l.sectionEnding,
    l.sectionTurnaround,
    l.sectionVamp,
    l.sectionRefrain,
    l.sectionBreakdown,
    l.songDisplayTypeIntro,
    l.songDisplayTypeVerse,
    l.songDisplayTypePreChorus,
    l.songDisplayTypeChorus,
    l.songDisplayTypeBridge,
    l.songDisplayTypeInterlude,
    l.songDisplayTypeOutro,
  ];

  test('section names are the same in German and English', () {
    expect(names(de), names(en));
  });

  test('the sequence legend uses the English section names', () {
    expect(de.sequenceAbbreviations, contains('V Verse'));
    expect(de.sequenceAbbreviations, contains('C Chorus'));
    expect(de.sequenceAbbreviations, contains('Int Interlude'));
  });

  test('the German editor inserts English section labels', () {
    final snippets = EditorSnippets(de);
    final inserted = [
      for (final group in snippets.groups)
        for (final s in group.items)
          if (s != null) s.before,
    ].join();
    for (final german in ['Strophe', 'Zwischenspiel', 'Schluss', 'Raster']) {
      expect(inserted, isNot(contains(german)));
    }
    expect(inserted, contains('Interlude'));
  });
}
