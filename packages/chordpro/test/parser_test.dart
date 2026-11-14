import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

const _song = '''
# A comment line
{title: Amazing Song}
{artist: The Band}
{key: G}
{tempo: 96}

{start_of_verse: Verse 1}
[G]Hello [C]world, [D]here we go
Second line without chords
{end_of_verse}

{soc}
[C]Sing a[G]long
{eoc}

{c: Guitar solo}
{chorus}

{start_of_tab}
e|---0---|
B|---1---|
{end_of_tab}

{define: G base-fret 1 frets 3 2 0 0 0 3}
{unknown_directive: whatever}
''';

void main() {
  group('parseChordPro', () {
    final song = parseChordPro(_song);

    test('extracts metadata', () {
      expect(song.title, 'Amazing Song');
      expect(song.artist, 'The Band');
      expect(song.keyName, 'G');
      expect(song.key!.tonic.pitch, 7);
      expect(song.tempo, 96);
    });

    test('builds sections', () {
      final sections = song.sections.toList();
      expect(sections[0].kind, SectionKind.verse);
      expect(sections[0].label, 'Verse 1');
      expect(sections[0].lines, hasLength(2));
      expect(sections[1].kind, SectionKind.chorus);
      expect(sections.last.kind, SectionKind.tab);
    });

    test('parses inline chords', () {
      final line = song.sections.first.lines.first as LyricLine;
      expect(line.segments.map((s) => s.chord?.raw), ['G', 'C', 'D']);
      expect(line.segments.map((s) => s.text), [
        'Hello ',
        'world, ',
        'here we go',
      ]);
      expect(line.text, 'Hello world, here we go');
    });

    test('lines without chords', () {
      final line = song.sections.first.lines[1] as LyricLine;
      expect(line.hasChords, isFalse);
    });

    test('comments end up in an implicit section', () {
      final comment = song.elements
          .whereType<Section>()
          .expand((s) => s.lines)
          .whereType<CommentLine>()
          .single;
      expect(comment.text, 'Guitar solo');
    });

    test('chorus recall references the last chorus', () {
      final recall = song.elements.whereType<ChorusRecall>().single;
      expect(recall.chorus, isNotNull);
      expect(recall.chorus!.kind, SectionKind.chorus);
    });

    test('tab lines are preformatted', () {
      final tab = song.sections.last;
      expect(tab.lines.first, isA<RawLine>());
      expect((tab.lines.first as RawLine).text, 'e|---0---|');
    });
  });

  test('ChordPro 6 label attribute', () {
    final song = parseChordPro(
      '{start_of_chorus label="Refrain"}\n[C]La\n{end_of_chorus}',
    );
    expect(song.sections.single.label, 'Refrain');
  });

  test('short aliases and meta directive', () {
    final song = parseChordPro('{t: Short}\n{st: Sub}\n{meta: artist Someone}');
    expect(song.title, 'Short');
    expect(song.subtitle, 'Sub');
    expect(song.artist, 'Someone');
  });

  test('unclosed section is closed implicitly', () {
    final song = parseChordPro('{sov}\n[A]One\n[D]Two');
    expect(song.sections.single.lines, hasLength(2));
  });

  test('blank lines split implicit paragraphs', () {
    final song = parseChordPro('[A]One\n\n[D]Two');
    expect(song.sections, hasLength(2));
  });

  test('annotations and unknown chords', () {
    final line = parseLyricLine('[*Riff]Go [N.C.]stop');
    expect(line.segments[0].chord!.isAnnotation, isTrue);
    expect(line.segments[0].chord!.annotationText, 'Riff');
    expect(line.segments[1].chord!.chord, isNull);
  });

  test('empty song', () {
    final song = parseChordPro('');
    expect(song.hasContent, isFalse);
    expect(song.title, isNull);
  });

  test('handles CRLF line endings', () {
    final song = parseChordPro('{title: X}\r\n[C]A\r\n');
    expect(song.title, 'X');
    expect(song.hasContent, isTrue);
  });
}
