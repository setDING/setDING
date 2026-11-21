import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

AbcTune ly(String source) {
  final tune = parseLilypond(source);
  expect(tune, isNotNull, reason: source);
  return tune!;
}

List<AbcElement> elements(AbcTune t) => [
  for (final line in t.lines) ...line.elements,
];

List<AbcNote> notes(AbcTune t) => elements(t).whereType<AbcNote>().toList();

List<String> pitches(AbcTune t) => [
  for (final n in notes(t)) n.pitches.join('+'),
];

List<String> bars(AbcTune t) => [
  for (final b in elements(t).whereType<AbcBar>()) '${b.type}${b.volta ?? ''}',
];

const _leadSheet = r'''
\version "2.24.0"
\header { title = "Twinkle" composer = "Trad." }

% The melody with chords and lyrics, as LilyPond lead sheets are written.
melody = \relative c' {
  \clef treble \key c \major \time 4/4
  c4 c g' g | a a g2 | \break
  f4 f e e | d d c2 \bar "|."
}
harmonies = \chordmode { c1 | f2 c | g2:7 c | g:7 c }
text = \lyricmode { Twin -- kle twin -- kle lit -- tle star }

\score {
  <<
    \new ChordNames \harmonies
    \new Staff { \new Voice = "mel" \melody }
    \new Lyrics \lyricsto "mel" \text
  >>
  \layout { }
  \midi { }
}
''';

void main() {
  group('pitches', () {
    test('relative mode picks the nearest octave', () {
      final t = ly(r"\relative c' { \key g \major g4 a b c | d2 d }");
      expect(pitches(t), ['G3', 'A3', 'B3', 'C4', 'D4', 'D4']);
      expect(t.key.name, 'G');
    });

    test('octave marks, absolute and fixed mode', () {
      expect(pitches(ly(r"\relative c'' { c g' c,, }")), ['C5', 'G5', 'C4']);
      expect(pitches(ly(r"{ c c' c'' b, }")), ['C3', 'C4', 'C5', 'B2']);
      expect(pitches(ly(r"\fixed c' { c g b, }")), ['C4', 'G4', 'B3']);
      // Without a start pitch, the first note is absolute.
      expect(pitches(ly(r"\relative { e'' d }")), ['E5', 'D5']);
    });

    test('note names in Dutch, German and English', () {
      expect(pitches(ly(r"{ cis' es' as' bes' eeses' fisis' }")), [
        'C4#',
        'E4b',
        'A4b',
        'B4b',
        'E4bb',
        'F4##',
      ]);
      expect(pitches(ly(r'''\language "deutsch" { h' b' }''')), ['B4', 'B4b']);
      expect(pitches(ly(r'''\language "english" { cs' bf' fsharp' }''')), [
        'C4#',
        'B4b',
        'F4#',
      ]);
    });

    test('chords and q keep the relative reference', () {
      final t = ly(r"\relative c' { <c e g>2 q4 d }");
      expect(pitches(t), ['C4+E4+G4', 'C4+E4+G4', 'D4']);
      // Accidentals follow the key, as in ABC.
      final f = notes(ly(r"\relative c' { \key g \major fis f }"));
      expect(f[0].shownAccidentals, [null]);
      expect(f[1].shownAccidentals, [0]);
    });
  });

  group('durations and bar lines', () {
    test('durations carry over and dots lengthen', () {
      final t = ly(r"{ c'4. d'8 e'2 f' }");
      expect(notes(t).map((n) => n.duration), [0.375, 0.125, 0.5, 0.5]);
    });

    test('bar lines follow the time signature and the upbeat', () {
      final t = ly(r"\relative c' { \time 3/4 \partial 4 g4 | c2 e4 | g2. }");
      expect(t.meter, '3/4');
      expect(bars(t), ['|', '|', '|']);
      expect(elements(t)[1], isA<AbcBar>()); // after the upbeat
    });

    test('4/4 and 2/2 are shown as C and cut time unless numeric', () {
      expect(ly("{ c'1 }").meter, 'C');
      expect(ly(r"{ \time 2/2 c'1 }").meter, 'C|');
      expect(ly(r"{ \numericTimeSignature \time 4/4 c'1 }").meter, '4/4');
    });

    test('rests, spacers and full-measure rests', () {
      final t = ly(r"{ \time 3/4 r4 s2 R2.*2 c'2. }");
      final rests = elements(t).whereType<AbcRest>().toList();
      expect(rests.map((r) => r.duration), [0.25, 0.5, 0.75, 0.75]);
      expect(rests[1].invisible, isTrue);
      expect(bars(t), ['|', '|', '|', '|']);
    });

    test('explicit bar lines and line breaks', () {
      final t = ly(r"""{ c'1 \bar "||" \break d'1 \bar "|." }""");
      expect(t.lines, hasLength(2));
      expect(bars(t), ['||', '|]']);
    });

    test('ties, beams and tuplets', () {
      final t = ly(
        r"\relative c'' { c8 d e f g4~ g | \tuplet 3/2 { a8 b c } r4 c8[ b a g] }",
      );
      final n = notes(t);
      expect(n[4].tie, isTrue);
      // Eighths are beamed per beat; a tuplet shows its number.
      expect(n.take(4).map((x) => x.spaceBefore), [true, false, true, false]);
      expect(n[6].tuplet, 3);
      expect(n[6].duration, closeTo(1 / 12, 1e-9));
      expect(n.sublist(9, 13).map((x) => x.spaceBefore), [
        true,
        false,
        false,
        false,
      ]);
    });
  });

  group('repeats', () {
    test('volta repeats with alternatives', () {
      final t = ly(r'''\relative c'' {
        \repeat volta 2 { c2 d | e1 }
        \alternative { { d1 } { c1 } }
      }''');
      expect(bars(t), ['|:', '|', '|1', ':|2', '|']);
    });

    test('repeat without alternatives and unfolded repeats', () {
      expect(bars(ly(r"{ c'1 \repeat volta 2 { d'1 } e'1 }")), [
        '|:',
        ':|',
        '|',
      ]);
      expect(pitches(ly(r"\relative c' { \repeat unfold 2 { c4 g' } c2 }")), [
        'C4',
        'G4',
        'C4',
        'G4',
        'C5',
      ]);
    });
  });

  group('lead sheet', () {
    final t = parseLilypond(_leadSheet)!;
    final n = notes(t);

    test('title, key and lines from variables and \\score', () {
      expect(t.title, 'Twinkle');
      expect(t.key.name, 'C');
      expect(t.lines, hasLength(2));
      expect(n, hasLength(14));
      expect(bars(t).last, '|]');
    });

    test('chord names are placed above the notes', () {
      expect(n.map((x) => x.chordSymbol).whereType<String>(), [
        'C',
        'F',
        'C',
        'G7',
        'C',
        'G7',
        'C',
      ]);
    });

    test('lyrics are placed below the notes', () {
      expect(n.take(7).map((x) => x.lyric), [
        'Twin-',
        'kle',
        'twin-',
        'kle',
        'lit-',
        'tle',
        'star',
      ]);
    });

    test('transposition moves notes, key and chord names', () {
      final up = transposeAbc(t, 2);
      expect(up.key.name, 'D');
      expect(notes(up).first.pitches.single.toString(), 'D4');
      expect(notes(up).first.chordSymbol, 'D');
    });

    test('slurs and ties hold a syllable', () {
      final s = ly(r'''\relative c' { c4( d) e~ e f }
        \addlyrics { one two three }''');
      expect(notes(s).map((x) => x.lyric), ['one', null, 'two', null, 'three']);
    });

    test('chord modifiers become chord suffixes', () {
      final s = ly(r'''<<
        \chords { c1:m7.5- d:maj7 e:sus4/gis f:7.9- g:m7+ a:1.5 b:min }
        { c'1 d' e' f' g' a' b' }
      >>''');
      expect(notes(s).map((x) => x.chordSymbol), [
        'Cm7b5',
        'Dmaj7',
        'Esus4/G#',
        'F7b9',
        'Gmmaj7',
        'A5',
        'Bm',
      ]);
    });

    test('text scripts are shown above the note', () {
      final s = ly(r"""{ c'4^"Coda" d'_"below" }""");
      expect(notes(s)[0].annotations, ['Coda']);
      expect(notes(s)[1].annotations, isEmpty);
    });
  });

  group('ignored input', () {
    test('layout settings, dynamics and articulations', () {
      final t = ly(r'''
        \paper { indent = 0 }
        {
          \override Staff.TimeSignature.stencil = ##f
          \set Score.tempoHideNote = ##t
          \tempo "Allegro" 4 = 120
          \mark \default
          c'4\f-. d'-> e'8( f') g'4\fermata
        }''');
      expect(pitches(t), ['C4', 'D4', 'E4', 'F4', 'G4']);
    });

    test('grace notes are not drawn but move the reference', () {
      final t = ly(r"\relative c' { c2 \grace { d16 e } f2 }");
      expect(pitches(t), ['C4', 'F4']);
    });

    test('bass clef', () {
      expect(ly(r"{ \clef bass c1 }").bassClef, isTrue);
    });
  });

  test('incomplete input never throws (typing in the editor)', () {
    for (var k = 0; k <= _leadSheet.length; k++) {
      expect(() => parseLilypond(_leadSheet.substring(0, k)), returnsNormally);
    }
    for (final source in [
      r'\language',
      r'\bar',
      r'{ c4 \tuplet',
      '<c e',
      r'"a\',
    ]) {
      expect(() => parseLilypond(source), returnsNormally, reason: source);
    }
  });

  group('outside the subset', () {
    test('returns null', () {
      for (final source in [
        r"\relative c' { << { c d } \\ { e f } >> }",
        r"<< \new Staff { c'1 } \new Staff { e'1 } >>",
        r"\transpose c d { c'1 }",
        r'''\language "italiano" { do re mi }''',
        r'{ x y z }',
        r'\version "2.24.0"',
        '',
      ]) {
        expect(parseLilypond(source), isNull, reason: source);
      }
    });
  });
}
