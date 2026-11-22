import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Regression test for docs/examples/chord-views-*.cho, the example songs of
/// the website page on chord views (ADR-0055, #920): the numerals and
/// Nashville numbers the page lists are the ones the app shows.
void main() {
  for (final lang in ['de', 'en']) {
    final song = parseChordPro(
      File('../../docs/examples/chord-views-$lang.cho').readAsStringSync(),
    );

    List<List<String>> lines(ChordView view) => [
      for (final section in song.sections)
        for (final line in section.lines.whereType<LyricLine>())
          [
            for (final s in line.segments)
              if (s.chord != null)
                ChordFormatter.forSong(song, view: view).format(s.chord!),
          ],
    ];

    group('chord-views-$lang.cho', () {
      test('every chord is understood', () {
        for (final section in song.sections) {
          for (final line in section.lines.whereType<LyricLine>()) {
            for (final s in line.segments) {
              final chord = s.chord?.chord;
              if (s.chord == null) continue;
              expect(chord, isNotNull, reason: s.chord!.raw);
              expect(chord!.parsedSuffix, isNotNull, reason: s.chord!.raw);
            }
          }
        }
      });

      test('Roman numerals', () {
        expect(lines(ChordView.numerals), [
          ['I', 'ii', 'iii', 'IV'],
          ['V', 'vi', 'vii°', 'I'],
          ['ii7', 'V7', 'IΔ7'],
          ['iii7', 'VI7', 'ii9'],
          ['V13', 'I6/9'],
          ['viΔ7', 'vi7', 'II7'],
          ['I', '♭VII7', '♭III', '♭VI'],
          ['♭II', 'V7♭9', 'V7♯11', 'I'],
          ['I+', 'Isus4', 'I'],
          ['I/3', 'IV', 'V/7', 'I'],
          ['I/♭7', 'IV/6', 'iv/♭6', 'V7'],
          ['III7', 'vi'],
          ['II7', 'V7'],
          // From {key: Am}: minor counted from the parallel major.
          ['i', 'iiø7', 'V7', 'i'],
          ['iv7', '♭VII', '♭III', '♭VI'],
          ['ii°7', 'V7♭9', 'i'],
        ]);
      });

      test('Nashville numbers of the table on the page', () {
        final all = lines(ChordView.nashville).expand((l) => l).toList();
        expect(all.take(7), ['1', '2m', '3m', '4', '5', '6m', '7dim']);
        expect(all, containsAll(['1maj7', '6m7', '2m7', '57', 'b77', '1/3']));
      });
    });
  }
}
