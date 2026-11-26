import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('englishSectionLabel', () {
    test('translates German section names and keeps the rest', () {
      expect(englishSectionLabel('Vers 1'), 'Verse 1');
      expect(englishSectionLabel('Strophe 2:'), 'Verse 2:');
      expect(englishSectionLabel('Refrain'), 'Chorus');
      expect(englishSectionLabel('Refrain 2 (leise)'), 'Chorus 2 (leise)');
      expect(englishSectionLabel('Pre-Refrain'), 'Pre-Chorus');
      expect(englishSectionLabel('prerefrain 1'), 'Pre-Chorus 1');
      expect(englishSectionLabel('Zwischenspiel'), 'Interlude');
      expect(englishSectionLabel('Schluss'), 'Outro');
      expect(englishSectionLabel('REFRAIN'), 'CHORUS');
    });

    test('translates the other German and Swiss names (#1085)', () {
      expect(englishSectionLabel('Vorspiel'), 'Intro');
      expect(englishSectionLabel('Einleitung:'), 'Intro:');
      expect(englishSectionLabel('Ref.'), 'Chorus');
      expect(englishSectionLabel('Ref. 2'), 'Chorus 2');
      expect(englishSectionLabel('Kehrvers'), 'Chorus');
      expect(englishSectionLabel('Vor-Refrain'), 'Pre-Chorus');
      expect(englishSectionLabel('Nachrefrain'), 'Post-Chorus');
      expect(englishSectionLabel('Brücke 1'), 'Bridge 1');
      expect(englishSectionLabel('BRÜCKE'), 'BRIDGE');
      expect(englishSectionLabel('Zwischenteil'), 'Bridge');
      expect(englishSectionLabel('Mittelteil'), 'Bridge');
      expect(englishSectionLabel('Überleitung'), 'Interlude');
      expect(englishSectionLabel('Nachspiel'), 'Outro');
      expect(englishSectionLabel('Abschluss'), 'Outro');
      expect(englishSectionLabel('Schluß'), 'Outro');
      expect(englishSectionLabel('Ausklang'), 'Outro');
      expect(englishSectionLabel('Ende'), 'Ending');
      expect(englishSectionLabel('VERS 2'), 'VERSE 2');
    });

    test('leaves English and other text alone', () {
      expect(englishSectionLabel('Verse 1'), isNull);
      expect(englishSectionLabel('Chorus'), isNull);
      expect(englishSectionLabel('Bridge'), isNull);
      expect(englishSectionLabel('Refrain des Lebens'), isNull);
      expect(englishSectionLabel('Versuch'), isNull);
      expect(englishSectionLabel('Intro'), isNull);
      expect(englishSectionLabel('Ending'), isNull);
      expect(englishSectionLabel('Referenz'), isNull);
      expect(englishSectionLabel('Ende gut'), isNull);
    });
  });

  group('translateSectionLabels', () {
    test('translates environment labels, recalls and comment headings', () {
      const source = '''
{title: Lied}
{start_of_verse: label="Vers 1"}
[C]Hallo
{end_of_verse}
{soc: Refrain}
[G]Ja
{eoc}
{start_of_bridge: label='Zwischenspiel' }
x
{end_of_bridge}
{chorus: label="Refrain"}
{c: Strophe 2}
y
{comment: Bitte leise}
''';
      expect(translateSectionLabels(source), '''
{title: Lied}
{start_of_verse: label="Verse 1"}
[C]Hallo
{end_of_verse}
{soc: Chorus}
[G]Ja
{eoc}
{start_of_bridge: label='Interlude' }
x
{end_of_bridge}
{chorus: label="Chorus"}
{c: Verse 2}
y
{comment: Bitte leise}
''');
    });

    test('skips other directives and delegated environments', () {
      const source =
          '{subtitle: Refrain}\n'
          '{start_of_textblock}\n{c: Refrain}\n{end_of_textblock}\n'
          'Refrain\n';
      expect(findGermanSectionLabels(source), isEmpty);
    });

    test('keeps CRLF line breaks and reports line numbers', () {
      const source = '{c: Vers 1}\r\nx\r\n{c: Refrain}\r\n';
      final labels = findGermanSectionLabels(source);
      expect([for (final l in labels) l.line], [1, 3]);
      expect(
        translateSectionLabels(source),
        '{c: Verse 1}\r\nx\r\n{c: Chorus}\r\n',
      );
    });
  });

  group('translateSectionLabelsIn', () {
    const source = '{c: Vers 1}\nx\n{c: Refrain}\ny\n';

    test('translates all labels without a selection', () {
      final edit = translateSectionLabelsIn(source, 0, 0)!;
      expect(edit.text, '{c: Verse 1}\nx\n{c: Chorus}\ny\n');
      expect(edit.base, 4);
    });

    test('translates only the selected lines', () {
      final start = source.indexOf('{c: Refrain}');
      final edit = translateSectionLabelsIn(source, start, start + 3)!;
      expect(edit.text, '{c: Vers 1}\nx\n{c: Chorus}\ny\n');
      expect(edit.text.substring(edit.base, edit.extent), '{c: Chorus}');
    });

    test('returns null when there is nothing to translate', () {
      expect(translateSectionLabelsIn('{c: Verse 1}\nx\n', 0, 0), isNull);
    });
  });
}
