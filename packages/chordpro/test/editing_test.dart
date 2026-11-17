import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Text with `|` marking the cursor, or `<` … `>` marking a selection
/// (base `<`, extent `>`), split into text, base and extent.
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

/// The result as marked text, like the input of [_parse].
String? _mark(SourceEdit? edit) {
  if (edit == null) return null;
  final text = edit.text;
  if (edit.base == edit.extent) {
    return text.replaceRange(edit.base, edit.base, '|');
  }
  assert(edit.base < edit.extent);
  return text
      .replaceRange(edit.extent, edit.extent, '>')
      .replaceRange(edit.base, edit.base, '<');
}

String? _apply(
  String marked,
  SourceEdit? Function(String text, int base, int extent) command,
) {
  final (text, base, extent) = _parse(marked);
  return _mark(command(text, base, extent));
}

void main() {
  _searchTests();
  _convertTests();
  _dropTests();
  _columnTests();

  group('moveLines', () {
    SourceEdit? up(String t, int b, int e) => moveLines(t, b, e, up: true);
    SourceEdit? down(String t, int b, int e) => moveLines(t, b, e, up: false);

    test('moves the cursor line up and down', () {
      expect(_apply('a\nb|b\nc', up), 'b|b\na\nc');
      expect(_apply('a\nb|b\nc', down), 'a\nc\nb|b');
    });

    test('does nothing at the start or end of the text', () {
      expect(_apply('a|a\nb', up), isNull);
      expect(_apply('a\nb|b', down), isNull);
    });

    test('moves all selected lines and keeps the selection', () {
      expect(_apply('x\na<a\nb>b\ny', up), 'a<a\nb>b\nx\ny');
      expect(_apply('x\na<a\nb>b\ny', down), 'x\ny\na<a\nb>b');
    });

    test('a selection ending at a line start excludes that line', () {
      expect(_apply('x\n<aa\n>bb', up), '<aa\n>x\nbb');
    });

    test('moves the first line down over an empty line', () {
      expect(_apply('a|\n\nb', down), '\na|\nb');
    });
  });

  test('duplicateLines copies the lines below and selects the copy', () {
    expect(_apply('a\nb|b\nc', duplicateLines), 'a\nbb\nb|b\nc');
    expect(_apply('<a\nb>', duplicateLines), 'a\nb\n<a\nb>');
  });

  group('deleteLines', () {
    test('deletes the cursor line', () {
      expect(_apply('a\nb|b\nc', deleteLines), 'a\n|c');
    });

    test('deletes the last line with its line break', () {
      expect(_apply('a\nb\nc|c', deleteLines), 'a\n|b');
    });

    test('deletes all selected lines', () {
      expect(_apply('a<a\nb>b\nc', deleteLines), '|c');
    });

    test('deletes the only line', () {
      expect(_apply('a|a', deleteLines), '|');
      expect(_apply('|', deleteLines), isNull);
    });
  });

  group('toggleComment', () {
    test('comments and uncomments the cursor line', () {
      expect(_apply('a\nb|b', toggleComment), 'a\n# b|b');
      expect(_apply('a\n# b|b', toggleComment), 'a\nb|b');
    });

    test('comments all selected lines but not empty ones', () {
      expect(_apply('<a\n\nb>', toggleComment), '# <a\n\n# b>');
    });

    test('uncomments only when all lines are comments', () {
      expect(_apply('<# a\nb>', toggleComment), '# <# a\n# b>');
      expect(_apply('<# a\n  #b>', toggleComment), '<a\n  b>');
    });

    test('a cursor inside the removed prefix moves to the line start', () {
      expect(_apply('#| a', toggleComment), '|a');
    });

    test('does nothing on empty lines', () {
      expect(_apply('a\n|\nb', toggleComment), isNull);
    });
  });

  group('moveChords', () {
    SourceEdit? right(String t, int b, int e) =>
        moveChords(t, b, e, right: true);
    SourceEdit? left(String t, int b, int e) =>
        moveChords(t, b, e, right: false);

    test('moves the chord at the cursor through the lyrics', () {
      expect(_apply('He[C|]llo', right), 'Hel[C|]lo');
      expect(_apply('He[C|]llo', left), 'H[C|]ello');
    });

    test('finds the chord when the cursor is next to it', () {
      expect(_apply('He|[C]llo', right), 'Hel|[C]lo');
      expect(_apply('He[C]|llo', left), 'H[C]|ello');
    });

    test('does nothing without a chord at the cursor', () {
      expect(_apply('H|ello [C]x', right), isNull);
    });

    test('adds a space at the end of a line', () {
      expect(_apply('Hello[G|]\nnext', right), 'Hello [G|]\nnext');
      expect(_apply('Hello[G|]', right), 'Hello [G|]');
    });

    test('stops at the start of a line', () {
      expect(_apply('a\n[G|]b', left), isNull);
    });

    test('moves all chords in the selection', () {
      expect(_apply('<[C]ab [G]cd>', right), 'a<[C]b c[G]d>');
      expect(_apply('a<b[C]c [G]>d', left), 'a<[C]bc[G]> d');
    });

    test('chords next to each other move together', () {
      expect(_apply('x<[C][G]>yz', right), 'xy<[C][G]>z');
      expect(_apply('xy<[C][G]>z', left), 'x<[C][G]>yz');
    });

    test('annotations move too, directives do not', () {
      expect(_apply('a[*Riff|]b', right), 'ab[*Riff|]');
      expect(_apply('{c: [C|]x}', right), isNull);
    });
  });
}

void _searchTests() {
  group('findInSource', () {
    test('finds all occurrences ignoring case', () {
      expect(findInSource('Am [am] AM', 'am'), [(0, 2), (4, 6), (8, 10)]);
    });

    test('matches case exactly when asked to', () {
      expect(findInSource('Am [am] AM', 'Am', caseSensitive: true), [(0, 2)]);
    });

    test('does not overlap and ignores an empty query', () {
      expect(findInSource('aaaa', 'aa'), [(0, 2), (2, 4)]);
      expect(findInSource('abc', ''), isEmpty);
    });

    test('replaceInSource replaces all matches', () {
      const text = 'Am [am] AM';
      expect(
        replaceInSource(text, findInSource(text, 'am'), 'Em'),
        'Em [Em] Em',
      );
      expect(replaceInSource(text, const [], 'x'), text);
    });

    test('treats the query literally', () {
      expect(findInSource('[C] x', '[C]'), [(0, 3)]);
      expect(findInSource('a.b', '.'), [(1, 2)]);
    });
  });
}

void _convertTests() {
  group('convertChordsOverLyricsIn', () {
    test('converts the whole text without a selection', () {
      expect(
        _apply('|C   G\nla  la', convertChordsOverLyricsIn),
        '|[C]la  [G]la',
      );
    });

    test('converts only the selected lines and selects them', () {
      expect(
        _apply('C\nx\n<G\nla>', convertChordsOverLyricsIn),
        'C\nx\n<[G]la>',
      );
    });

    test('does nothing without chords over lyrics', () {
      expect(_apply('[C]la|', convertChordsOverLyricsIn), isNull);
    });
  });
}

void _dropTests() {
  group('dropText', () {
    SourceEdit? drop(String marked, int at, {bool copy = false}) {
      final (text, base, extent) = _parse(marked);
      return dropText(text, base, extent, drop: at, copy: copy);
    }

    test('moves text within a line, before and after itself', () {
      // 'one <two> three': move "two" to the end.
      expect(_mark(drop('one <two> three', 13)), 'one  three<two>');
      expect(_mark(drop('one two <three>', 0)), '<three>one two ');
    });

    test('copies text and keeps the original', () {
      expect(_mark(drop('<ab> cd', 7, copy: true)), 'ab cd<ab>');
    });

    test('dropping onto itself changes nothing', () {
      expect(drop('a<bc>d', 2), isNull);
      expect(drop('a|bc', 0), isNull);
    });

    test('whole lines drop between lines', () {
      // Dropped in the middle of "c": goes before the line "c".
      expect(_mark(drop('<a\n>b\nc\n', 5)), 'b\n<a\n>c\n');
      expect(_mark(drop('a\nb\n<c\n>', 1)), '<c\n>a\nb\n');
    });

    test('the last line without a line break moves as a line', () {
      expect(_mark(drop('a\nb\n<c>', 0)), '<c\n>a\nb');
    });

    test('whole lines dropped at the end of the last line go after it', () {
      expect(_mark(drop('<a\n>b', 3)), 'b\n<a>');
    });
  });
}

void _columnTests() {
  group('sourceColumn', () {
    test('skips chords and markup', () {
      const line = '[C]Hello <b>my</b> [G]friend';
      expect(sourceColumn(line, 0), 3); // H
      expect(sourceColumn(line, 6), 12); // m
      expect(sourceColumn(line, 9), 22); // f
      expect(sourceColumn(line, 99), line.length);
    });

    test('a chord tap goes before the bracket', () {
      const line = '[C]Hello [G]friend';
      expect(sourceColumn(line, 6, atChord: true), 9);
      expect(sourceColumn(line, 0, atChord: true), 0);
      // No chord at that position: the character itself.
      expect(sourceColumn(line, 2, atChord: true), 5);
    });

    test('directive lines map into their value', () {
      const line = '{comment: Play <i>soft</i>}';
      expect(sourceColumn(line, 0), 10);
      expect(sourceColumn(line, 5), 18);
      expect(sourceColumn(line, 99), line.length - 1);
    });
  });
}
