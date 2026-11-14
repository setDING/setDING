import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('parseMarkup', () {
    test('convenience tags and nesting', () {
      final m = parseMarkup('a <b>bold <i>both</i></b> c');
      expect(m.plain, 'a bold both c');
      expect(m.runs.map((r) => (r.text, r.style.bold, r.style.italic)), [
        ('a ', null, null),
        ('bold ', true, null),
        ('both', true, true),
        (' c', null, null),
      ]);
    });

    test('span attributes', () {
      final m = parseMarkup(
        '<span foreground="blue" size="120%" weight="bold" style="italic" '
        'underline="double" strikethrough="true" font_family="serif" '
        "background='#ff0000' rise=\"30%\">x</span>",
      );
      final s = m.runs.single.style;
      expect(s.foreground, 'blue');
      expect(s.size!.factor, 1.2);
      expect(s.bold, isTrue);
      expect(s.italic, isTrue);
      expect(s.underline, 'double');
      expect(s.strikethrough, isTrue);
      expect(s.family, 'serif');
      expect(s.background, '#ff0000');
      expect(s.rise, closeTo(0.3, 1e-9));
    });

    test('font_desc and symbolic sizes', () {
      final s = parseMarkup(
        '<span font_desc="Sans Italic 12">x</span>',
      ).runs.single.style;
      expect(s.family, 'Sans');
      expect(s.italic, isTrue);
      expect(s.size!.points, 12);
      final big = parseMarkup('<big><small>x</small></big>').runs.single.style;
      expect(big.size!.factor, closeTo(1.0, 1e-9));
      final sup = parseMarkup('x<sup>2</sup>').runs.last.style;
      expect(sup.rise, 0.3);
    });

    test('unknown tags, entities and struts', () {
      expect(parseMarkup('I <3 you').plain, 'I <3 you');
      expect(parseMarkup('a &lt;b&gt; &amp; c').plain, 'a <b> & c');
      expect(parseMarkup('Hello<strut w="20"/>world').plain, 'Helloworld');
      expect(
        parseMarkup('<tt>mono</tt>').runs.single.style.family,
        'monospace',
      );
    });

    test('maps source positions to plain positions and slices runs', () {
      const raw = 'ab<b>cd</b>ef';
      final m = parseMarkup(raw);
      expect(m.plainIndex(0), 0);
      expect(m.plainIndex(raw.indexOf('c')), 2);
      expect(m.plainIndex(raw.indexOf('e')), 4);
      expect(m.plainIndex(raw.length), 6);
      final slice = m.slice(1, 5);
      expect(slice.map((r) => r.text), ['b', 'cd', 'e']);
      expect(slice[1].style.bold, isTrue);
    });
  });

  test('markup in lyrics and chords', () {
    final song = parseChordPro('[<b>C</b>]Hello <i>[G]world</i>');
    final line = song.sections.single.lines.single as LyricLine;
    expect(line.plainText, 'Hello world');
    final chord = line.segments.first.chord!;
    expect(chord.chord, isNotNull);
    final f = ChordFormatter.forSong(song, transpose: 2);
    expect(f.format(chord), 'D');
    expect(chordMarkupStyle(chord).bold, isTrue);
    expect(ChordFormatter.forSong(song).format(chord), 'C');
  });

  group('FormatState', () {
    FormatLine fl(FormatTarget t, FormatProperty p, String? v) =>
        FormatLine(t, p, v);

    test('set and restore values', () {
      final s = FormatState()
        ..apply(fl(FormatTarget.text, FormatProperty.colour, 'blue'))
        ..apply(fl(FormatTarget.text, FormatProperty.colour, 'red'));
      expect(s.valuesFor(FormatTarget.text).colour, 'red');
      s.apply(fl(FormatTarget.text, FormatProperty.colour, null));
      expect(s.valuesFor(FormatTarget.text).colour, 'blue');
      s.apply(fl(FormatTarget.text, FormatProperty.colour, null));
      expect(s.valuesFor(FormatTarget.text).isDefault, isTrue);
    });

    test('percent sizes are relative, numbers absolute', () {
      final s = FormatState()
        ..apply(fl(FormatTarget.text, FormatProperty.size, '150%'))
        ..apply(fl(FormatTarget.text, FormatProperty.size, '200%'));
      expect(s.valuesFor(FormatTarget.text).size!.factor, 3.0);
      s.apply(fl(FormatTarget.chord, FormatProperty.size, '14'));
      expect(s.valuesFor(FormatTarget.chord).size!.points, 14);
    });

    test('textfont with size sets and resets both', () {
      final s = FormatState()
        ..apply(fl(FormatTarget.text, FormatProperty.font, 'sans 13'));
      expect(s.valuesFor(FormatTarget.text).font, 'sans');
      expect(s.valuesFor(FormatTarget.text).size!.points, 13);
      s.apply(fl(FormatTarget.text, FormatProperty.font, null));
      expect(s.valuesFor(FormatTarget.text).isDefault, isTrue);
    });

    test('chorus values fall back to text values', () {
      final s = FormatState()
        ..apply(fl(FormatTarget.text, FormatProperty.colour, 'blue'))
        ..apply(fl(FormatTarget.chorus, FormatProperty.font, 'serif'));
      final chorus = s.lyricsValues(inChorus: true);
      expect(chorus.colour, 'blue');
      expect(chorus.font, 'serif');
      expect(s.lyricsValues().font, isNull);
    });
  });
}
