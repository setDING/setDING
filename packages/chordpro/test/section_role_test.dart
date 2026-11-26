import 'package:chordpro/chordpro.dart';
import 'package:test/test.dart';

void main() {
  group('sectionRoleOfName', () {
    test('recognises the synonyms of every role', () {
      const cases = {
        'Intro': SectionRole.intro,
        'verse': SectionRole.verse,
        'Vers 2': SectionRole.verse,
        'Strophe 1:': SectionRole.verse,
        'Pre-Chorus': SectionRole.preChorus,
        'pre_chorus': SectionRole.preChorus,
        'Prechorus 2': SectionRole.preChorus,
        'Pre Refrain': SectionRole.preChorus,
        'Chorus 2': SectionRole.chorus,
        'Refrain': SectionRole.chorus,
        'Bridge': SectionRole.bridge,
        'Interlude': SectionRole.interlude,
        'Instrumental': SectionRole.interlude,
        'Zwischenspiel': SectionRole.interlude,
        'Solo 2 (Guitar)': SectionRole.interlude,
        'Turnaround': SectionRole.interlude,
        'Vamp': SectionRole.interlude,
        'Outro': SectionRole.outro,
        'Ending': SectionRole.outro,
        'Schluss': SectionRole.outro,
        'Coda': SectionRole.outro,
        'Tag': SectionRole.outro,
        'Post-Chorus': SectionRole.standard,
        // German and Swiss names (#1085).
        'Vorspiel': SectionRole.intro,
        'Einleitung': SectionRole.intro,
        'Ref. 2': SectionRole.chorus,
        'Kehrvers': SectionRole.chorus,
        'Vorrefrain': SectionRole.preChorus,
        'Brücke': SectionRole.bridge,
        'BRÜCKE': SectionRole.bridge,
        'Zwischenteil': SectionRole.bridge,
        'Überleitung': SectionRole.interlude,
        'Nachspiel': SectionRole.outro,
        'Abschluss': SectionRole.outro,
        'Ende': SectionRole.outro,
        'Nachrefrain': SectionRole.standard,
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(sectionRoleOfName(key), value, reason: key);
      }
    });

    test('returns null for other names', () {
      expect(sectionRoleOfName('Riff'), isNull);
      expect(sectionRoleOfName('Intro with drums'), isNull);
      expect(sectionRoleOfName(''), isNull);
    });
  });

  group('Section.role', () {
    Section only(String source) => parseChordPro(source).sections.single;

    test('environments keep their kind', () {
      expect(only('{sov}\na\n{eov}').role, SectionRole.verse);
      expect(only('{soc}\na\n{eoc}').role, SectionRole.chorus);
      expect(only('{sob}\na\n{eob}').role, SectionRole.bridge);
      // A verse labelled "Pre-Chorus" stays a verse: the kind wins.
      expect(
        only('{start_of_verse: Pre-Chorus}\na\n{end_of_verse}').role,
        SectionRole.verse,
      );
    });

    test('custom environments by name, then by label', () {
      expect(
        only('{start_of_intro}\na\n{end_of_intro}').role,
        SectionRole.intro,
      );
      expect(
        only('{start_of_pre_chorus}\na\n{end_of_pre_chorus}').role,
        SectionRole.preChorus,
      );
      expect(
        only('{start_of_solo}\na\n{end_of_solo}').role,
        SectionRole.interlude,
      );
      expect(
        only('{start_of_part: Outro\\nfade out}\na\n{end_of_part}').role,
        SectionRole.outro,
      );
      expect(
        only('{start_of_riff}\na\n{end_of_riff}').role,
        SectionRole.standard,
      );
    });

    test('comment headings', () {
      final song = parseChordPro(
        '{c: Intro}\n[G]a\n\n{c: Solo 2}\n[C]b\n\n{c: Outro:}\n[D]c',
      );
      expect(song.sections.map((s) => s.role), [
        SectionRole.intro,
        SectionRole.interlude,
        SectionRole.outro,
      ]);
    });

    test('tabs, grids and plain lyrics are standard', () {
      expect(only('{sot: Intro}\ne|---\n{eot}').role, SectionRole.standard);
      expect(
        only('{start_of_grid label="Intro"}\n| G . |\n{end_of_grid}').role,
        SectionRole.standard,
      );
      expect(only('[G]just lyrics').role, SectionRole.standard);
    });
  });
}
