import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  test('finds closed sections with long and short directives', () {
    const source =
        '{title: T}\n{start_of_verse: Intro}\nla\n{end_of_verse}\n\n{soc}\nx\n{eoc}';
    expect(sourceSections(source), [
      const SourceSection(11, 52, 'verse'),
      SourceSection(54, source.length, 'chorus'),
    ]);
    expect(
      source.substring(11, 52),
      '{start_of_verse: Intro}\nla\n{end_of_verse}',
    );
  });

  test('an unclosed section ends before the next one or at the end', () {
    const source = '{sov}\na\n{start_of_bridge}\nb';
    expect(sourceSections(source), [
      const SourceSection(0, 7, 'verse'),
      const SourceSection(8, 27, 'bridge'),
    ]);
  });

  test('other environments and chorus recalls', () {
    const source =
        '{chorus}\n{start_of_tab}\ne|--\n{end_of_tab}\n{start_of_abc}\nX:1\n{end_of_abc}';
    expect(sourceSections(source).map((s) => s.type), ['tab', 'abc']);
  });

  test('an end without a start is ignored', () {
    expect(sourceSections('{eoc}\nla'), isEmpty);
  });
}
