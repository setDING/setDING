import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Structure of a ChordPro file as downloaded from CCLI SongSelect
/// (own placeholder text, not a real song).
const _songSelectStyle = '''{title: Test Song}
{artist: Writer One, Writer Two}
{subtitle: Deutsch: Translator}
{key: Bb}
{time: 4/4}
{tempo: 72}
{ccli_license: 1234567}
{ccli: 7654321}
{copyright: 2024 Example Publishing | Other Music}
{footer: For use solely with the SongSelect® Terms of Use. All rights reserved. www.ccli.com}

{comment: Intro}
[|][Eb] [.] [.] [Gm] [|] [Fsus] [|]

{comment: Vers 1}
[Bb]Line one of the [Eb2]verse [Bb]here
[Gm7]Line two [F(4)]goes on [Eb2]now

{comment: Pre-Chorus}
[Eb2]Building [Gm7]up
[F]and up

{comment: Chorus 1}
[(Bb/D)]Sing [Eb2]out [Gm7]loud [F]now
[Cm7]and [F]again

{comment: Tag}
[Cm7]Last [F]line [Bb]here

{comment: Play softly}
[Bb]Not a heading, a real comment

CCLI-Liednummer 7654321
© 2024 Example Publishing
''';

void main() {
  final song = parseChordPro(normalizeSongSelectDirectives(_songSelectStyle));

  group('normalizeSongSelectDirectives (#777)', () {
    test('renames ccli to x_ccli and removes ccli_license', () {
      final source = normalizeSongSelectDirectives(_songSelectStyle);
      expect(source, contains('{tempo: 72}\n{x_ccli: 7654321}\n{copyright:'));
      expect(source, contains('\n{x_ccli_footer: For use solely'));
      expect(source, isNot(contains('{footer')));
      expect(source, isNot(contains('ccli_license')));
      expect(source, isNot(contains('{ccli')));
      // The plain-text CCLI paragraph after the song stays as written.
      expect(source, contains('CCLI-Liednummer 7654321'));
    });

    test('handles spacing, case, meta form and CRLF', () {
      expect(
        normalizeSongSelectDirectives(
          '{title: T}\r\n  { CCLI_License : 1}\r\n{CCLI:2}\r\n'
          '{meta: ccli 3}\r\n{meta: ccli_license 4}\r\nLa\r\n',
        ),
        '{title: T}\r\n{x_ccli:2}\r\n{meta: x_ccli 3}\r\nLa\r\n',
      );
    });

    test('a license directive on the last line is removed', () {
      expect(normalizeSongSelectDirectives('La\n{ccli_license: 1}'), 'La\n');
    });

    test('counts the directives it changes', () {
      expect(countSongSelectDirectives(_songSelectStyle), 3);
      expect(countSongSelectDirectives('{meta: ccli 1}\n{x_ccli: 2}'), 1);
      expect(
        countSongSelectDirectives(
          normalizeSongSelectDirectives(_songSelectStyle),
        ),
        0,
      );
    });

    test('leaves other directives and text alone', () {
      const source =
          '{x_ccli: 1}\n{ccli_song: 2}\n{c: ccli 3}\n[C]{ccli: 4} in text\n'
          '{x_ccli_footer: 5}\n{footerfont: serif}\n{c: footer 6}\n';
      expect(normalizeSongSelectDirectives(source), source);
    });
  });

  test('ccli, ccli_license and footer are not standard metadata', () {
    final raw = parseChordPro(_songSelectStyle);
    expect(raw.metaValue('ccli'), isNull);
    expect(raw.metaValue('ccli_license'), isNull);
    expect(raw.metaValue('footer'), isNull);
  });

  test('reads SongSelect metadata', () {
    expect(song.title, 'Test Song');
    expect(song.keyName, 'Bb');
    expect(song.tempo, 72);
    expect(song.time, '4/4');
    expect(song.metaValue('x_ccli'), '7654321');
    expect(song.metaValue('ccli_license'), isNull);
    expect(song.metaValue('copyright'), startsWith('2024'));
    expect(song.metaValue('x_ccli_footer'), startsWith('For use solely'));
  });

  test('comment headings become labelled sections', () {
    final sections = song.sections.toList();
    expect(
      [for (final s in sections.take(5)) (s.kind, s.label)],
      [
        (SectionKind.custom, 'Intro'),
        (SectionKind.verse, 'Vers 1'),
        (SectionKind.custom, 'Pre-Chorus'),
        (SectionKind.chorus, 'Chorus 1'),
        (SectionKind.custom, 'Tag'),
      ],
    );
    // The heading itself is not repeated as a line.
    expect(sections[1].lines.first, isA<LyricLine>());
    expect(sections[1].lines, hasLength(2));
  });

  test('comments before a heading do not hide it', () {
    final sections = parseChordPro(
      '{comment_italic: (first time a cappella)}\n'
      '{comment: Chorus}\n'
      '[G]Line one\n'
      '[Em7]Line two\n',
    ).sections.toList();
    expect(
      [for (final s in sections) (s.kind, s.label, s.lines.length)],
      [(SectionKind.none, null, 1), (SectionKind.chorus, 'Chorus', 2)],
    );
    final note = sections.first.lines.single as CommentLine;
    expect(note.text, '(first time a cappella)');
    expect(note.style, CommentStyle.italic);
    expect(sourceLineOf(sections.last), 1);
  });

  test('lyrics before a heading comment keep the paragraph unlabelled', () {
    final sections = parseChordPro(
      '[G]Lyrics\n{comment: Chorus}\n[C]more\n',
    ).sections.toList();
    expect(sections.single.kind, SectionKind.none);
  });

  test('ordinary comments are not treated as headings', () {
    final section = song.sections.elementAt(5);
    expect(section.kind, SectionKind.none);
    expect((section.lines.first as CommentLine).text, 'Play softly');
  });

  test('trailing copyright text stays as plain lines', () {
    final last = song.sections.last;
    expect(last.kind, SectionKind.none);
    expect(last.lines.whereType<LyricLine>(), hasLength(2));
  });

  test('optional chords in parentheses are transposed', () {
    final f = ChordFormatter.forSong(song, transpose: 2);
    expect(f.format(ChordToken('(Bb/D)')), '(C/E)');
    expect(f.format(ChordToken('F(4)')), 'G(4)');
    expect(f.format(ChordToken('Eb2')), 'F2');
    final german = ChordFormatter.forSong(song, notation: ChordNotation.german);
    expect(german.format(ChordToken('(Bb/D)')), '(B/D)');
    final nashville = ChordFormatter.forSong(song, view: ChordView.nashville);
    expect(nashville.format(ChordToken('(Bb/D)')), '(1/3)');
  });

  test('bar and beat marks are kept as written', () {
    final f = ChordFormatter.forSong(song, transpose: 2);
    expect(f.format(ChordToken('|')), '|');
    expect(f.format(ChordToken('.')), '.');
  });

  test('heading variants', () {
    String? kindOf(String heading) {
      final s = parseChordPro('{c: $heading}\n[C]x').sections.first;
      return s.kind == SectionKind.none ? null : s.kind.name;
    }

    expect(kindOf('Verse 2'), 'verse');
    expect(kindOf('Strophe 1'), 'verse');
    expect(kindOf('Refrain'), 'chorus');
    expect(kindOf('Chorus 2 (2x)'), 'chorus');
    expect(kindOf('Bridge'), 'bridge');
    expect(kindOf('Outro'), 'custom');
    expect(kindOf('Guitar solo over verse chords'), isNull);
  });
}
