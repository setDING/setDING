import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Regression tests for the example songs of the website (#923) in
/// docs/examples: each one shows what its page says. The German and the
/// English version have the same chords.
void main() {
  String source(String name) =>
      File('../../docs/examples/$name.cho').readAsStringSync();

  List<String> chords(String src) => [
    for (final m in RegExp(r'\[([^\]]+)\]').allMatches(src)) m.group(1)!,
  ];

  for (final name in ['beat', 'sections', 'personal', 'chord-views']) {
    test('$name: German and English have the same chords', () {
      expect(chords(source('$name-de')), chords(source('$name-en')));
    });
  }

  for (final lang in ['de', 'en']) {
    group('beat-$lang.cho (live/beat)', () {
      final src = source('beat-$lang');

      test('tempo and an odd meter with a grouping', () {
        final song = parseChordPro(src);
        expect(song.tempo, 168);
        expect(song.meter.numerator, 7);
        expect(song.meter.denominator, 8);
        expect(song.meter.groups, [2, 2, 3]);
      });

      test('the song map has every part with a cue and drum notes', () {
        final drums = parseChordPro(
          src,
          selectors: const SelectorContext(instrument: 'drums'),
        );
        final map = songMap(drums, drums.sequence);
        expect(
          [for (final e in map) e.part.code],
          ['I', 'V1', 'C', 'V2', 'C', 'O'],
        );
        for (final e in map) {
          expect(e.cue, isNotNull, reason: e.part.code);
          expect(e.notes, hasLength(1), reason: e.part.code);
        }
      });

      test('other instruments do not see the drum notes', () {
        final guitar = parseChordPro(
          src,
          selectors: const SelectorContext(instrument: 'guitar'),
        );
        expect(
          songMap(guitar, guitar.sequence).expand((e) => e.notes),
          isEmpty,
        );
      });
    });

    group('sections-$lang.cho (song display, key and sequence)', () {
      final song = parseChordPro(source('sections-$lang'));

      test('every section role once, in song order', () {
        expect(
          [for (final s in song.sections) s.role],
          [
            SectionRole.intro,
            SectionRole.verse,
            SectionRole.verse,
            SectionRole.preChorus,
            SectionRole.chorus,
            SectionRole.interlude,
            SectionRole.bridge,
            SectionRole.outro,
          ],
        );
      });

      test('the sequence uses every part of the song', () {
        final codes = {for (final p in songParts(song)) p.code};
        expect(codes, {'I', 'V1', 'V2', 'PC', 'C', 'Solo', 'B', 'O'});
        expect(
          [for (final i in song.sequence) i.code],
          ['I', 'V1', 'PC', 'C', 'V2', 'PC', 'C', 'Solo', 'B', 'C x2', 'O'],
        );
        expect(
          filterBySequence(song, song.sequence, keepOutside: true).outside,
          isEmpty,
        );
      });
    });

    group('personal-$lang.cho (personal adjustments)', () {
      final song = parseChordPro(source('personal-$lang'));

      test('a capo', () => expect(song.capoFret, 2));

      test('chords in the first verse only and stacked verses change it', () {
        expect(identical(firstVerseChordsOnly(song), song), isFalse);
        expect(identical(stackVerses(song), song), isFalse);
      });

      test('the last chorus changes its words and can be stacked', () {
        expect(identical(stackChoruses(song), song), isFalse);
      });
    });
  }
}
