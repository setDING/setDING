import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Kind, role, label and line count of every section, to compare what
/// the parser reads before and after the conversion.
List<(SectionKind, SectionRole, String?, int)> shape(String source) => [
  for (final e in parseChordPro(source).elements)
    if (e is Section) (e.kind, sectionRoleOf(e), e.label, e.lines.length),
];

void main() {
  test('headings become environments of their kind', () {
    const source =
        '{title: T}\n\n'
        '{comment: Verse 1}\n[G]La la\nla\n\n'
        '{c: Chorus}\n[C]Oh oh\n\n'
        '{comment: Bridge}\nHm\n\n'
        '{comment: Strophe 2:}\nDu du\n\n'
        '{comment: Refrain}\nJa ja\n';
    expect(
      convertCommentHeadings(source),
      '{title: T}\n\n'
      '{start_of_verse: label="Verse 1"}\n[G]La la\nla\n{end_of_verse}\n\n'
      '{start_of_chorus: label="Chorus"}\n[C]Oh oh\n{end_of_chorus}\n\n'
      '{start_of_bridge: label="Bridge"}\nHm\n{end_of_bridge}\n\n'
      '{start_of_verse: label="Strophe 2:"}\nDu du\n{end_of_verse}\n\n'
      '{start_of_chorus: label="Refrain"}\nJa ja\n{end_of_chorus}\n',
    );
    expect(findCommentHeadings(source).map((h) => h.line), [3, 7, 10, 13, 16]);
  });

  test('other names become environments of their own name', () {
    expect(
      convertCommentHeadings(
        '{comment: Intro}\n[G] [C]\n\n{comment: Pre-Chorus}\nUp\n\n'
        '{comment: Solo 2}\n[Em]\n',
      ),
      '{start_of_intro: label="Intro"}\n[G] [C]\n{end_of_intro}\n\n'
      '{start_of_pre_chorus: label="Pre-Chorus"}\nUp\n{end_of_pre_chorus}\n\n'
      '{start_of_solo: label="Solo 2"}\n[Em]\n{end_of_solo}\n',
    );
  });

  test('the parser reads the same sections before and after', () {
    const source =
        '{title: T}\n{comment_italic: a cappella}\n{comment: Verse 1}\n'
        '[G]La la\n{comment: Chorus}\n[C]Oh\n\n{comment: Chorus}\n\n'
        '{c: Pre-Chorus}\nup\n\n{c: Zwischenspiel}\n[Am]\n\n'
        '{c: Tag}\nla\n{chorus}\n{c: Outro}\n[G]\n{start_of_verse}\nx\n'
        '{end_of_verse}\n';
    final converted = convertCommentHeadings(source);
    expect(converted, isNot(source));
    expect(shape(converted), shape(source));
    expect(findCommentHeadings(converted), isEmpty);
  });

  test('left alone: comments, lone headings, explicit sections', () {
    expect(
      findCommentHeadings(
        '{comment: play softly}\nla\n\n'
        '{comment: Chorus}\n\n'
        '{comment: Chorus}\n{start_of_verse}\n'
        '{comment: Verse 2}\nla\n{end_of_verse}\n\n'
        'la\n{comment: Verse 3}\nlu\n\n'
        '{comment-alto: Verse 4}\nla\n\n'
        '{comment_italic: Verse 5}\nla\n',
      ),
      isEmpty,
    );
  });

  test('comments before the heading stay outside the section', () {
    expect(
      convertCommentHeadings('{comment: twice}\n{comment: Chorus}\nOh\n'),
      '{comment: twice}\n{start_of_chorus: label="Chorus"}\nOh\n'
      '{end_of_chorus}\n',
    );
  });

  test('a stray end directive becomes the end of the section', () {
    expect(
      convertCommentHeadings('{comment: Verse 1}\nla\n{end_of_chorus}\nx\n'),
      '{start_of_verse: label="Verse 1"}\nla\n{end_of_verse}\nx\n',
    );
  });

  test('CCLI bar lines are left to the grid conversion', () {
    const source = '{comment: Intro}\n[|][G]  [.]  [.]  [.][|]\n';
    expect(findCommentHeadings(source), isEmpty);
    expect(
      applyChordProConversions(source),
      contains('{start_of_grid shape="1x4" label="Intro"}'),
    );
  });

  test('labels with quotes and Windows line breaks', () {
    expect(
      convertCommentHeadings('{c: Chorus ("Big")}\r\nOh\r\n'),
      "{start_of_chorus: label='Chorus (\"Big\")'}\r\nOh\r\n{end_of_chorus}\r\n",
    );
    expect(findCommentHeadings('{c: Chorus (\'n\' "x")}\nOh\n'), isEmpty);
  });

  test('selection converts only the sections it touches', () {
    const text = '{c: Verse 1}\na\n\n{c: Verse 2}\nb\n';
    final edit = convertCommentHeadingsIn(text, 17, 18)!;
    expect(
      edit.text,
      '{c: Verse 1}\na\n\n{start_of_verse: label="Verse 2"}\nb\n'
      '{end_of_verse}\n',
    );
    expect(
      edit.text.substring(edit.base, edit.extent),
      '{start_of_verse: label="Verse 2"}\nb\n{end_of_verse}',
    );
    final all = convertCommentHeadingsIn(text, 0, 0)!;
    expect(findCommentHeadings(all.text), isEmpty);
    expect(all.base, 0);
    expect(convertCommentHeadingsIn('la\n', 0, 0), isNull);
  });
}
