import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

const _tune = '''
X:1
T:Speed the Plough
M:4/4
L:1/8
K:G
|:"G"GABG DGBG|"D"A2 AB c2 Bc|"G"d^cdB "C"c2 =cB|1 "D7"A3 G A4:|2 "D7"A2 F2 G4||
w:one two three four
''';

List<AbcNote> notes(AbcTune t, [int line = 0]) =>
    t.lines[line].elements.whereType<AbcNote>().toList();

void main() {
  group('header and key', () {
    test('fields, meter and key signature', () {
      final t = parseAbc(_tune);
      expect(t.title, 'Speed the Plough');
      expect(t.meter, '4/4');
      expect(t.key.fifths, 1);
      expect(t.key.name, 'G');
      expect(t.key.alterationOf(3), 1); // F#
      expect(t.key.alterationOf(0), 0);
    });

    test('modes and flat keys', () {
      expect(AbcKey.parse('Dm').fifths, -1);
      expect(AbcKey.parse('Ador').fifths, 1); // A dorian = G major
      expect(AbcKey.parse('Bb').fifths, -2);
      expect(AbcKey.parse('F#m').fifths, 3);
      expect(AbcKey.parse('Gmix').fifths, 0);
      expect(AbcKey.parse('Eb').signatureLetters, [6, 2, 5]); // B E A
      expect(AbcKey.parse('none').fifths, 0);
    });
  });

  group('notes', () {
    final t = parseAbc(_tune);
    final n = notes(t);

    test('pitches, octaves and key signature', () {
      expect(n.first.pitches.single.toString(), 'G4');
      expect(n[4].pitches.single.toString(), 'D4');
      // c is C5; F in G major is F#.
      final c = n.firstWhere((x) => x.pitches.single.letter == 0);
      expect(c.pitches.single.toString(), 'C5');
      expect(
        parseAbc('K:G\nF').lines.single.elements
            .whereType<AbcNote>()
            .single
            .pitches
            .single
            .alter,
        1,
      );
    });

    test('durations with the unit length', () {
      expect(n.first.duration, 1 / 8);
      expect(n[8].duration, 2 / 8); // A2
      final a3 = n.firstWhere((x) => x.duration == 3 / 8);
      expect(a3.pitches.single.letter, 5);
    });

    test('accidentals persist in the measure and are shown once', () {
      final t2 = parseAbc('K:C\n^c c c | c');
      final ns = notes(t2);
      expect(ns.map((x) => x.pitches.single.alter), [1, 1, 1, 0]);
      expect(ns.map((x) => x.shownAccidentals.single), [1, null, null, null]);
      // A natural sign against the key signature lasts for the measure.
      final t3 = parseAbc('K:G\n=F F | F');
      expect(notes(t3).map((x) => x.pitches.single.alter), [0, 0, 1]);
      expect(notes(t3).map((x) => x.shownAccidentals.single), [0, null, null]);
    });

    test('chord symbols, bars and voltas', () {
      expect(n.first.chordSymbol, 'G');
      final bars = t.lines.single.elements.whereType<AbcBar>().toList();
      expect(bars.first.type, '|:');
      expect(bars.map((b) => b.volta).whereType<int>(), [1, 2]);
      expect(bars.last.type, '||');
    });

    test('lyrics are assigned to notes', () {
      expect(n.take(4).map((x) => x.lyric), ['one', 'two', 'three', 'four']);
    });
  });

  test('default unit length depends on the meter', () {
    expect(notes(parseAbc('M:3/4\nK:C\nC')).single.duration, 1 / 8);
    expect(notes(parseAbc('M:2/4\nK:C\nC')).single.duration, 1 / 16);
    expect(notes(parseAbc('M:C\nK:C\nC')).single.duration, 1 / 8);
  });

  test('chords, rests, ties, broken rhythm and tuplets', () {
    final t = parseAbc('L:1/4\nK:C\n[CEG]2 z/ C>D (3CDE C-C');
    final e = t.lines.single.elements;
    final chord = e.first as AbcNote;
    expect(chord.pitches, hasLength(3));
    expect(chord.duration, 0.5);
    expect((e[1] as AbcRest).duration, 1 / 8);
    final ns = e.whereType<AbcNote>().toList();
    expect(ns[1].duration, 0.25 * 1.5);
    expect(ns[2].duration, 0.25 * 0.5);
    expect(ns[3].tuplet, 3);
    expect(ns[3].duration, closeTo(0.25 * 2 / 3, 1e-9));
    expect(ns[5].duration, closeTo(0.25 * 2 / 3, 1e-9));
    expect(ns[6].tie, isTrue);
  });

  test('inline key change and comments', () {
    final t = parseAbc('K:C\nC D % comment\n[K:D] F');
    expect(t.lines, hasLength(2));
    final f = notes(t, 1).single;
    expect(f.pitches.single.alter, 1); // F# in D
  });

  group('transposeAbc', () {
    test('key, notes and chord symbols', () {
      final t = transposeAbc(parseAbc(_tune), 2);
      expect(t.key.name, 'A');
      expect(t.key.fifths, 3);
      final n = notes(t);
      expect(n.first.pitches.single.toString(), 'A4');
      expect(n.first.chordSymbol, 'A');
      // d^c in G (D, C#) becomes e^d (E, D#) in A.
      final sharp = n.firstWhere((x) => x.shownAccidentals.single == 1);
      expect(sharp.pitches.single.toString(), 'D5#');
    });

    test('down into a flat key', () {
      final t = transposeAbc(parseAbc('K:G\nG B d'), -2);
      expect(t.key.name, 'F');
      expect(notes(t).map((x) => x.pitches.single.toString()), [
        'F4',
        'A4',
        'C5',
      ]);
      final minor = transposeAbc(parseAbc('K:Em\nE'), 1);
      expect(minor.key.name, 'Fm');
      expect(minor.key.fifths, -4);
    });
  });

  test('a long music line parses in linear time', () {
    // 4000 bars on one line: matching at the position instead of copying
    // the rest of the line keeps this fast.
    final line = List.filled(4000, '[K:D] "G"(3ABc d2>e2 z2 |').join(' ');
    final watch = Stopwatch()..start();
    final tune = parseAbc('X:1\nM:4/4\nL:1/8\nK:G\n$line\n');
    watch.stop();
    final elements = tune.lines.single.elements;
    expect(elements.whereType<AbcBar>(), hasLength(4000));
    expect(elements.whereType<AbcNote>(), hasLength(4000 * 5));
    expect(elements.whereType<AbcNote>().first.tuplet, 3);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
