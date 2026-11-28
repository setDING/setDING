// Fuzz tests of the ChordPro parser and the functions on top of it (#1244):
// random and mutated input never throws, never hangs and keeps the
// properties the package promises. The seed is fixed, so a run is
// reproducible; FUZZ_ITERATIONS raises the number of inputs for a longer
// run (docs/development/fuzz-tests.md).
import 'dart:io';
import 'dart:math';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Inputs per property; FUZZ_ITERATIONS overrides it.
final _iterations =
    int.tryParse(Platform.environment['FUZZ_ITERATIONS'] ?? '') ?? 150;

/// Longest time one input may take for all functions together.
const _limit = Duration(seconds: 2);

/// The example songs the mutations start from.
final _seeds = [
  File('../../docs/examples/feature-showcase.cho').readAsStringSync(),
  for (final f
      in Directory('../../docs/examples')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.cho'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
    f.readAsStringSync(),
];

/// Pieces that hit the parser's syntax: directives, environments, chords,
/// markup, grids, delimiters and odd characters.
const _pieces = [
  '{',
  '}',
  '[',
  ']',
  ':',
  '|',
  '\n',
  '\r\n',
  '\r',
  '\t',
  ' ',
  '#',
  '%',
  '{title: ',
  '{t:',
  '{meta: title ',
  '{key: ',
  '{capo: ',
  '{tempo: ',
  '{time: ',
  '{x_sequence: ',
  '{x_',
  '{new_song}',
  '{ns}',
  '{c: ',
  '{ci:',
  '{start_of_chorus}',
  '{end_of_chorus}',
  '{soc}',
  '{eoc}',
  '{chorus}',
  '{start_of_verse: label="',
  '{end_of_verse}',
  '{start_of_grid ',
  '{start_of_grid shape="2x4"}',
  '{end_of_grid}',
  '{start_of_tab}',
  '{end_of_tab}',
  '{start_of_abc}',
  '{end_of_abc}',
  '{start_of_ly}',
  '{end_of_ly}',
  '{start_of_svg}',
  '{end_of_svg}',
  '{start_of_textblock}',
  '{define: ',
  ' base-fret ',
  ' frets ',
  ' fingers ',
  '{chord: ',
  '{image: ',
  '{textsize: ',
  '{chordcolour: ',
  '{+',
  '{-',
  '-tenor}',
  'label=',
  '"',
  "'",
  r'\',
  '[C]',
  '[Am7]',
  '[G/B]',
  '[*x2]',
  '[N.C.]',
  '[H7]',
  '[Bb]',
  '[C#m7b5/G#]',
  '[^',
  '[.]',
  '[|]',
  '[||]',
  '[:|',
  '|:',
  '%%',
  '~',
  '<span foreground="red">',
  '</span>',
  '<b>',
  '</b>',
  '<',
  '>',
  '&amp;',
  '&#',
  'X:1\nK:C\n',
  '\\relative c\' {',
  '}}}',
  '{{{',
  '[[[',
  ']]]',
  '\u0000',
  ' ',
  '﻿',
  '​',
  '‮',
  'ä',
  'ß',
  '😀',
  '\uD800',
  '\uDC00',
  '日本語',
  'x2',
  'Chorus',
  'Refrain:',
  '1.',
  'Intro',
];

/// [text] with a few random edits: a deleted range, an inserted piece, a
/// duplicated range, swapped lines or a cut.
String _mutate(Random random, String text) {
  var s = text;
  final edits = 1 + random.nextInt(6);
  for (var e = 0; e < edits; e++) {
    final at = s.isEmpty ? 0 : random.nextInt(s.length + 1);
    switch (random.nextInt(6)) {
      case 0:
        final end = min(s.length, at + random.nextInt(40));
        s = s.substring(0, at) + s.substring(end);
      case 1 || 2:
        s =
            s.substring(0, at) +
            _pieces[random.nextInt(_pieces.length)] +
            s.substring(at);
      case 3:
        final end = min(s.length, at + random.nextInt(200));
        final part = s.substring(at, end);
        s =
            s.substring(0, end) +
            part * (1 + random.nextInt(3)) +
            s.substring(end);
      case 4:
        final lines = s.split('\n');
        if (lines.length > 1) {
          final a = random.nextInt(lines.length);
          final b = random.nextInt(lines.length);
          final t = lines[a];
          lines[a] = lines[b];
          lines[b] = t;
          s = lines.join('\n');
        }
      default:
        s = s.substring(0, at);
    }
  }
  return s;
}

/// Text made only of [_pieces] and random characters.
String _random(Random random) {
  final b = StringBuffer();
  final n = random.nextInt(120);
  for (var i = 0; i < n; i++) {
    if (random.nextInt(4) == 0) {
      b.writeCharCode(random.nextInt(0x3000));
    } else {
      b.write(_pieces[random.nextInt(_pieces.length)]);
    }
  }
  return b.toString();
}

/// The inputs of a run: mutated example songs and random text.
Iterable<String> _inputs(int seed) sync* {
  final random = Random(seed);
  for (var i = 0; i < _iterations; i++) {
    yield i.isEven
        ? _mutate(random, _seeds[random.nextInt(_seeds.length)])
        : _random(random);
  }
}

/// Runs [check] on every input and fails with the input that throws or
/// takes longer than [_limit].
void _forAll(int seed, void Function(String input) check) {
  for (final input in _inputs(seed)) {
    final watch = Stopwatch()..start();
    try {
      check(input);
    } catch (e, stack) {
      fail('threw $e on input ${_show(input)}\n$stack');
    }
    if (watch.elapsed > _limit) {
      fail('took ${watch.elapsed} on input ${_show(input)}');
    }
  }
}

String _show(String input) => Uri.encodeComponent(
  input.length > 2000 ? '${input.substring(0, 2000)}…' : input,
);

void main() {
  test('the parser and the song functions never throw', () {
    _forAll(1244, (input) {
      final songs = parseChordProSongs(input);
      expect(songs, isNotEmpty);
      parseChordPro(input, selectors: const SelectorContext());
      for (final song in songs) {
        songParts(song);
        guessKey(song);
        stackVerses(song);
        stackChoruses(song);
        withoutRepeatedChoruses(song);
        firstVerseChordsOnly(song);
        lyricSlides(lyricSections(song), linesPerSlide: 4);
        final sequence = findSequence(input);
        if (sequence != null) {
          final items = parseSequence(sequence);
          songMap(song, items);
          lyricSections(song, sequence: items);
        }
      }
      sourceSections(input);
      splitChordProSongs(input);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('validation, fixes and conversions never throw', () {
    _forAll(2, (input) {
      final problems = validateChordPro(input);
      for (final problem in problems) {
        fixChordProProblem(input, problem);
      }
      final fixed = fixChordProProblems(input);
      parseChordPro(fixed);
      applyChordProConversions(input);
      convertChordsOverLyrics(input);
      convertLegacySectionLabels(input);
      convertGermanToInternational(input);
      removeCcliFooters(input);
      normalizeSongSelectDirectives(input);
      translateSectionLabels(input);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the highlighting tokens cover the whole text in order', () {
    _forAll(3, (input) {
      final tokens = highlightChordPro(input);
      var at = 0;
      for (final t in tokens) {
        expect(t.start, at, reason: _show(input));
        expect(t.end, greaterThanOrEqualTo(t.start), reason: _show(input));
        at = t.end;
      }
      expect(at, input.isEmpty ? 0 : input.length, reason: _show(input));
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the editor functions never throw at any cursor', () {
    _forAll(4, (input) {
      final random = Random(input.length);
      for (var k = 0; k < 5; k++) {
        final cursor = input.isEmpty ? 0 : random.nextInt(input.length + 1);
        final end = min(input.length, cursor + random.nextInt(30));
        completeChordPro(input, cursor);
        matchBracket(input, cursor);
        autoClose(
          input.substring(0, cursor),
          cursor,
          cursor,
          input.substring(cursor),
          cursor,
        );
        closeSectionBlock(input, cursor);
        moveLines(input, cursor, end, up: k.isEven);
        duplicateLines(input, cursor, end);
        deleteLines(input, cursor, end);
        toggleComment(input, cursor, end);
        convertChordsOverLyricsIn(input, cursor, end);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('metadata that is set reads back the same', () {
    _forAll(5, (input) {
      for (final name in ['title', 'artist', 'key', 'x_sequence']) {
        final value = 'Fuzz ${input.length}';
        final changed = setSourceMetadata(input, name, value);
        expect(sourceMetadata(changed, name), value, reason: _show(input));
        // Setting the same value again changes nothing.
        expect(setSourceMetadata(changed, name, value), changed);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a parsed chord reads back the same, also transposed', () {
    final random = Random(6);
    const roots = [
      'C',
      'C#',
      'Db',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
      'H',
      'c',
      'x',
      '',
    ];
    const parts = [
      '',
      'm',
      '7',
      'maj7',
      'm7b5',
      'sus4',
      'add9',
      'dim',
      '+',
      '6/9',
      '(b9)',
      '/E',
      '/F#',
      '13',
      'Δ',
      'ø',
      '°',
      '-',
      '#',
      'b',
      '/',
    ];
    for (var i = 0; i < _iterations * 10; i++) {
      final raw =
          roots[random.nextInt(roots.length)] +
          [
            for (var k = random.nextInt(4); k > 0; k--)
              parts[random.nextInt(parts.length)],
          ].join();
      final chord = Chord.tryParse(raw);
      if (chord == null) continue;
      final text = chord.toString();
      expect(Chord.tryParse(text)?.toString(), text, reason: raw);
      final steps = random.nextInt(23) - 11;
      final back = chord.transpose(steps).transpose(-steps);
      expect(
        Chord.tryParse(back.toString())?.transpose(0).toString(),
        back.toString(),
        reason: raw,
      );
    }
  });

  test('ABC, LilyPond and markup never throw', () {
    _forAll(7, (input) {
      parseAbc(input);
      parseLilypond(input);
      parseMarkup(input);
      stripMarkup(input);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
