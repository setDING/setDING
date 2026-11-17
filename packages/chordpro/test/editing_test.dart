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
