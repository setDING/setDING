import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

/// Completes at the `|` in [marked].
CompletionResult? complete(String marked) =>
    completeChordPro(marked.replaceFirst('|', ''), marked.indexOf('|'));

/// Applies the suggestion [label] at `|` and marks the new cursor with `|`.
String accept(String marked, String label) {
  final source = marked.replaceFirst('|', '');
  final result = complete(marked)!;
  final item = result.items.firstWhere((c) => c.label == label);
  final (text, cursor) = result.apply(source, item);
  return text.replaceRange(cursor, cursor, '|');
}

List<String> labels(String marked) =>
    complete(marked)?.items.map((c) => c.label).toList() ?? const [];

void main() {
  group('directives', () {
    test('suggests names after {, long forms first', () {
      expect(labels('{ti|').take(2), ['title', 'time']);
      expect(labels('{start_of_c|'), ['start_of_chorus']);
      expect(labels('{x_|'), ['x_sequence', 'x_time_grouping']);
      expect(labels('{so|'), containsAll(['sorttitle', 'soc', 'sov']));
      expect(
        labels('{so|').indexOf('sorttitle'),
        lessThan(labels('{so|').indexOf('soc')),
      );
      // An exact short form comes first.
      expect(labels('{c|').first, 'c');
    });

    test('suggests all directives after an empty {', () {
      expect(labels('{|'), hasLength(chordProDirectives.length));
      expect(labels('  { |').first, 'title');
    });

    test('the catalog matches the parser', () {
      final names = chordProDirectives.map((d) => d.name).toList();
      expect(names.toSet(), hasLength(names.length));
      expect(
        names,
        containsAll([
          't',
          'st',
          'key',
          'capo',
          'meta',
          'comment',
          'ci',
          'chorus',
          'start_of_verse',
          'end_of_grid',
          'start_of_abc',
          'end_of_textblock',
          'sov',
          'eoc',
          'transpose',
          'define',
          'column_break',
          'np',
          'new_song',
          'textsize',
          'chordcolour',
          'cf',
          'x_sequence',
        ]),
      );
      for (final d in chordProDirectives) {
        expect(d.kind, isNot(SourceTokenKind.text), reason: d.name);
      }
    });

    test('inserting places the cursor at the argument', () {
      expect(accept('{ti|', 'title'), '{title: |}');
      expect(accept('{ti|}', 'title'), '{title: |}');
      expect(accept('{soc|', 'soc'), '{soc}|');
      expect(accept('{start|}\n', 'start_of_chorus'), '{start_of_chorus}|\n');
      // The rest of the name after the cursor is replaced too.
      expect(accept('{ti|tl}', 'title'), '{title: |}');
      // An existing argument is kept.
      expect(accept('{art|: Me}', 'artist'), '{artist|: Me}');
    });

    test('nothing after the name or outside a directive', () {
      expect(complete('{title: |'), isNull);
      expect(complete('la {ti|'), isNull);
      expect(complete('{zzz|'), isNull);
      expect(complete('# {ti|'), isNull);
    });
  });

  group('chords', () {
    test('chords of the song first, then common chords in the key', () {
      const song = '{key: G}\n[Em]la [Em]li [D]lo [Bb7]x\n[|';
      final l = labels(song);
      expect(l.take(3), ['Em', 'D', 'Bb7']);
      expect(l.skip(3), ['G', 'Am', 'Bm', 'C', 'D7']);
    });

    test('filters by the typed prefix, ignoring case', () {
      expect(labels('{key: G}\n[Em]la [a|'), ['Am']);
      expect(labels('[C]x [D]y [D|'), ['D', 'Dm']);
    });

    test('keys with flats and minor keys', () {
      expect(commonChords(Key.tryParse('F')), [
        'F',
        'Gm',
        'Am',
        'Bb',
        'C',
        'Dm',
        'C7',
      ]);
      expect(commonChords(Key.tryParse('Am')), [
        'Am',
        'C',
        'Dm',
        'Em',
        'F',
        'G',
        'E7',
      ]);
      expect(commonChords(null).first, 'C');
    });

    test('the chord being edited is not suggested from the song', () {
      expect(labels('[Xm|]').contains('Xm'), isFalse);
    });

    test('inserting closes the bracket and puts the cursor after it', () {
      expect(accept('[A|', 'Am'), '[Am]|');
      expect(accept('[A|]la', 'Am'), '[Am]|la');
      expect(accept('[A|m7]la', 'Am'), '[Am]|la');
      expect(accept('{chord: [D|', 'Dm'), '{chord: [Dm]|');
    });

    test('no chords in comments, tabs, delegates or after \\[', () {
      expect(complete('# [|'), isNull);
      expect(complete('{sot}\ne|-[|'), isNull);
      expect(complete('{start_of_abc}\n[|'), isNull);
      expect(complete(r'\[|'), isNull);
      expect(complete('[C] la|'), isNull);
    });
  });
}
