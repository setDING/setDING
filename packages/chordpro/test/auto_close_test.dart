import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Text with `|` marking the cursor, or `<` … `>` marking a selection.
(String, int, int) _parse(String marked) {
  if (marked.contains('|')) {
    final at = marked.indexOf('|');
    return (marked.replaceFirst('|', ''), at, at);
  }
  final base = marked.indexOf('<');
  final withoutBase = marked.replaceFirst('<', '');
  final extent = withoutBase.indexOf('>');
  return (withoutBase.replaceFirst('>', ''), base, extent);
}

String? _mark(SourceEdit? edit) {
  if (edit == null) return null;
  if (edit.base == edit.extent) {
    return edit.text.replaceRange(edit.base, edit.base, '|');
  }
  return edit.text
      .replaceRange(edit.extent, edit.extent, '>')
      .replaceRange(edit.base, edit.base, '<');
}

/// Types [typed] over the cursor or selection of [marked].
String? _type(String marked, String typed) {
  final (text, start, end) = _parse(marked);
  final after = text.replaceRange(start, end, typed);
  return _mark(autoClose(text, start, end, after, start + typed.length));
}

/// Presses Backspace at the cursor of [marked].
String? _backspace(String marked) {
  final (text, at, _) = _parse(marked);
  return _mark(
    autoClose(text, at, at, text.replaceRange(at - 1, at, ''), at - 1),
  );
}

void main() {
  group('brackets', () {
    test('[ and { insert their closing bracket after the cursor', () {
      expect(_type('Hel|lo', '['), 'Hel[|]lo');
      expect(_type('|', '{'), '{|}');
      expect(_type('x %|', '{'), 'x %{|}');
    });

    test('not before a closing bracket without its opening one', () {
      expect(_type('|Am]Hello', '['), isNull);
      expect(_type('|title: X}', '{'), isNull);
      expect(_type('{c: %|}', '{'), isNull);
      expect(_type('|[Am]Hello', '['), '[|][Am]Hello');
    });

    test('not after a backslash, in comments or tab sections', () {
      expect(_type(r'a\|', '['), isNull);
      expect(_type('# note |', '['), isNull);
      expect(_type('{start_of_tab}\ne|--\n{end_of_tab}', '['), isNull);
      expect(_type('{start_of_abc}\n|', '['), isNull);
    });

    test('directive lines of a tab section are ChordPro', () {
      expect(_type('{start_of_tab}|\ne--\n{end_of_tab}', '['), isNotNull);
      expect(
        _type('{start_of_tab}\ne--\n{end_of_tab}|', '{'),
        '{start_of_tab}\ne--\n{end_of_tab}{|}',
      );
      expect(_type('{start_of_tab}\ne--\n{end_of_tab}\n|', '['), isNotNull);
    });

    test('a selection within one line is wrapped', () {
      expect(_type('x <Am> y', '['), 'x [<Am>] y');
      expect(_type('<title: A>', '{'), '{<title: A>}');
      expect(_type('<a\nb>', '['), isNull);
    });

    test('a closing bracket steps over the same one', () {
      expect(_type('[Am|]x', ']'), '[Am]|x');
      expect(_type('{title: A|}', '}'), '{title: A}|');
      expect(_type('[Am|x', ']'), isNull);
    });

    test('Backspace in an empty pair deletes both', () {
      expect(_backspace('a[|]b'), 'a|b');
      expect(_backspace('{|}'), '|');
      expect(_backspace('[|Am]'), isNull);
      expect(_backspace(r'\[|]'), isNull);
    });

    test('other typing is left alone', () {
      expect(_type('a|', 'b'), isNull);
      expect(_type('a|', 'bc'), isNull);
      expect(_type('a|', '[]'), isNull);
    });
  });

  group('section blocks', () {
    test('Enter after a section start adds the end directive', () {
      expect(
        _type('{start_of_verse}|', '\n'),
        '{start_of_verse}\n|\n{end_of_verse}',
      );
      expect(
        _type('{start_of_chorus label="Refrain"}| \nx', '\n'),
        '{start_of_chorus label="Refrain"}\n|\n{end_of_chorus} \nx',
      );
      expect(_type('{soc}|', '\n'), '{soc}\n|\n{eoc}');
      expect(_type('{start_of_abc}|', '\n'), '{start_of_abc}\n|\n{end_of_abc}');
      expect(
        _type('  {start_of_bridge}|', '\n'),
        '  {start_of_bridge}\n  |\n  {end_of_bridge}',
      );
    });

    test('not when the section is already closed', () {
      expect(_type('{start_of_verse}|\nLa la\n{end_of_verse}', '\n'), isNull);
      expect(_type('{sov}|\n{end_of_verse}', '\n'), isNull);
    });

    test('when the next section directive is another one', () {
      expect(
        _type('{start_of_verse}|\n{start_of_chorus}\n{end_of_chorus}', '\n'),
        '{start_of_verse}\n|\n{end_of_verse}\n{start_of_chorus}\n'
        '{end_of_chorus}',
      );
      expect(
        _type('{start_of_verse}|\n{end_of_chorus}', '\n'),
        '{start_of_verse}\n|\n{end_of_verse}\n{end_of_chorus}',
      );
    });

    test('only at the end of a start directive line', () {
      expect(_type('{start_of_verse|}', '\n'), isNull);
      expect(_type('{start_of_verse} x|', '\n'), isNull);
      expect(_type('{end_of_verse}|', '\n'), isNull);
      expect(_type('{chorus}|', '\n'), isNull);
      expect(_type('{title: A}|', '\n'), isNull);
      expect(_type('<{start_of_verse}>', '\n'), isNull);
    });

    test('closeSectionBlock works at the cursor', () {
      const text = '{start_of_grid}';
      expect(
        _mark(closeSectionBlock(text, text.length)),
        '{start_of_grid}\n|\n{end_of_grid}',
      );
      expect(closeSectionBlock(text, 3), isNull);
    });
  });
}
