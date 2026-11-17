import 'dart:io';

import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

typedef K = SourceTokenKind;

/// The tokens of [source] as (text, kind), without plain text.
List<(String, K)> marked(String source) => [
  for (final t in highlightChordPro(source))
    if (t.kind != K.text) (source.substring(t.start, t.end), t.kind),
];

/// Checks that [tokens] cover [length] characters without gaps or overlaps.
void expectCoverage(List<SourceToken> tokens, int length) {
  var pos = 0;
  for (final t in tokens) {
    expect(t.start, pos, reason: 'gap or overlap at $t');
    expect(t.end, greaterThan(t.start), reason: 'empty token $t');
    pos = t.end;
  }
  expect(pos, length);
}

void main() {
  test('chords, annotations and unknown chords', () {
    expect(marked('[Am7]la [*Riff]li [Xyz]lo [N.C.] [(D/F#)] [Hm] [x]'), [
      ('[Am7]', K.chord),
      ('[*Riff]', K.annotation),
      ('[Xyz]', K.unknownChord),
      ('[N.C.]', K.chord),
      ('[(D/F#)]', K.chord),
      ('[Hm]', K.chord),
      ('[x]', K.chord),
    ]);
    expect(marked('[<b>Am</b>] [*<i>Rit.</i>]'), [
      ('[<b>Am</b>]', K.chord),
      ('[*<i>Rit.</i>]', K.annotation),
    ]);
  });

  test('escaped brackets are lyrics', () {
    expect(marked(r'\[not a chord\] [C]x'), [('[C]', K.chord)]);
  });

  test('directive kinds', () {
    expect(marked('{start_of_chorus}\n{soc}\n{eoc}\n{chorus}'), [
      ('{start_of_chorus}', K.sectionDirective),
      ('{soc}', K.sectionDirective),
      ('{eoc}', K.sectionDirective),
      ('{chorus}', K.sectionDirective),
    ]);
    expect(marked('{title: My Song}'), [
      ('{title: ', K.metaDirective),
      ('My Song', K.directiveValue),
      ('}', K.metaDirective),
    ]);
    expect(marked('{c: hello}'), [
      ('{c: ', K.metaDirective),
      ('hello', K.directiveValue),
      ('}', K.metaDirective),
    ]);
    expect(marked('{textsize: 12}'), [
      ('{textsize: ', K.otherDirective),
      ('12', K.directiveValue),
      ('}', K.otherDirective),
    ]);
    expect(marked('{x_sequence: V, C}'), [
      ('{x_sequence: ', K.customDirective),
      ('V, C', K.directiveValue),
      ('}', K.customDirective),
    ]);
  });

  test('selectors and attributes', () {
    expect(marked('{comment-alto!: hi}'), [
      ('{comment', K.metaDirective),
      ('-alto!', K.selector),
      (': ', K.metaDirective),
      ('hi', K.directiveValue),
      ('}', K.metaDirective),
    ]);
    expect(marked('  {start_of_verse: label="Verse 1" x=y}'), [
      ('{start_of_verse: ', K.sectionDirective),
      ('label', K.attributeName),
      ('="Verse 1"', K.attributeValue),
      (' ', K.directiveValue),
      ('x', K.attributeName),
      ('=y', K.attributeValue),
      ('}', K.sectionDirective),
    ]);
  });

  test('comment lines and markup', () {
    expect(marked('# note\n[G]<b>bold</b> <span color="red">x</span> a < b'), [
      ('# note', K.comment),
      ('[G]', K.chord),
      ('<b>', K.markup),
      ('</b>', K.markup),
      ('<span color="red">', K.markup),
      ('</span>', K.markup),
    ]);
  });

  test('tab and grid content', () {
    const source =
        '{sot}\ne|--0--|\n{eot}\n'
        '{start_of_grid}\nA || G7 . | % :|2>\n{end_of_grid}\n[C]x';
    expect(marked(source), [
      ('{sot}', K.sectionDirective),
      ('e|--0--|', K.tab),
      ('{eot}', K.sectionDirective),
      ('{start_of_grid}', K.sectionDirective),
      ('A', K.grid),
      ('||', K.gridBar),
      ('G7', K.grid),
      ('.', K.grid),
      ('|', K.gridBar),
      ('%', K.grid),
      (':|2>', K.gridBar),
      ('{end_of_grid}', K.sectionDirective),
      ('[C]', K.chord),
    ]);
  });

  test('delegate content is not analysed', () {
    const source = '{start_of_abc}\nX:1 [C] {c: x}\n# y\n{end_of_abc}\n[G]';
    expect(marked(source), [
      ('{start_of_abc}', K.sectionDirective),
      ('X:1 [C] {c: x}\n# y\n', K.delegate),
      ('{end_of_abc}', K.sectionDirective),
      ('[G]', K.chord),
    ]);
  });

  test('text after a directive (#309)', () {
    expect(marked('  {comment: Chorus} (first time a cappella) '), [
      ...marked('  {comment: Chorus}'),
      ('(first time a cappella) ', K.error),
    ]);
    const source = '{soc} [G]la\n{c: a} b}';
    expectCoverage(highlightChordPro(source), source.length);
    expect(marked(source), [
      ...marked('{soc}'),
      ('[G]la', K.error),
      ...marked('\n{c: a} b}').where((t) => t.$2 != K.error),
    ]);
  });

  test('incomplete input', () {
    expect(marked('{title: My'), [('{title: My', K.error)]);
    expect(marked('[G]la [Am'), [('[G]', K.chord), ('[Am', K.error)]);
    expect(marked('[\n{'), [('[', K.error), ('{', K.error)]);
    // {new_song} ends an open delegate, as in the parser.
    expect(marked('{start_of_ly}\nx\n{ns}\n[C]'), [
      ('{start_of_ly}', K.sectionDirective),
      ('x\n', K.delegate),
      ('{ns}', K.otherDirective),
      ('[C]', K.chord),
    ]);
    // A delegate that is never closed runs to the end.
    expect(marked('{start_of_svg}\n<svg'), [
      ('{start_of_svg}', K.sectionDirective),
      ('<svg', K.delegate),
    ]);
  });

  test('coverage with line breaks, CRLF and empty input', () {
    for (final source in ['', '\n', 'a\r\n[C]b\r\n', '{t: x}\n\n[C']) {
      expectCoverage(highlightChordPro(source), source.length);
    }
  });

  group('feature showcase', () {
    final source = File(
      '../../docs/examples/feature-showcase.cho',
    ).readAsStringSync();
    final tokens = highlightChordPro(source);

    test('tokens cover the whole text', () {
      expectCoverage(tokens, source.length);
    });

    test('every feature is recognized', () {
      final kinds = {for (final t in tokens) t.kind};
      expect(
        kinds,
        containsAll(K.values.where((k) => k != K.error && k != K.unknownChord)),
      );
      final found = {
        for (final t in tokens) source.substring(t.start, t.end): t.kind,
      };
      expect(found['[N.C.]'], K.chord);
      expect(found['[*<i>Rit.</i>]'], K.annotation);
      expect(found['{x_sequence: '], K.customDirective);
      expect(found['-guitar!'], K.selector);
      expect(found['<span color="red">'], K.markup);
      expect(found[':|:'], K.gridBar);
      expect(found['e|-----0---0-----|'], K.tab);
    });

    test('no errors in the showcase', () {
      expect(tokens.where((t) => t.kind == K.error), isEmpty);
    });
  });
}
