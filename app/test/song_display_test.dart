import 'package:chordpro/chordpro.dart' show FormatState;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TextStyle;
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/render/song_style.dart';

void main() {
  group('inheritance', () {
    test('defaults: intro and outro from the interlude, pre-chorus from '
        'the verse, all others from standard', () {
      for (final role in SectionRole.values) {
        expect(defaultParent(role), switch (role) {
          SectionRole.standard => isNull,
          SectionRole.intro || SectionRole.outro => SectionRole.interlude,
          SectionRole.preChorus => SectionRole.verse,
          _ => SectionRole.standard,
        }, reason: role.name);
      }
    });

    test('a type inherits along the chain', () {
      const solo = SectionStyle(chordColor: SongColor.amber);
      final display = SongDisplay.classic.withType(
        SectionRole.interlude,
        const TypeStyle(style: solo),
      );
      expect(display.preset, SongDisplayPreset.custom);
      expect(display.styleOf(SectionRole.interlude), solo);
      expect(display.styleOf(SectionRole.intro), solo);
      expect(display.styleOf(SectionRole.outro), solo);
      expect(display.styleOf(SectionRole.verse), const SectionStyle());
    });

    test('a chosen parent replaces the default', () {
      const verse = SectionStyle(textItalic: true);
      final display = SongDisplay.classic
          .withType(SectionRole.verse, const TypeStyle(style: verse))
          .withType(
            SectionRole.outro,
            const TypeStyle(from: SectionRole.verse),
          );
      expect(display.styleOf(SectionRole.outro), verse);
    });

    test('cycles are detected and never loop', () {
      var display = SongDisplay.classic.withType(
        SectionRole.verse,
        const TypeStyle(from: SectionRole.bridge),
      );
      expect(display.makesCycle(SectionRole.bridge, SectionRole.verse), isTrue);
      expect(
        display.makesCycle(SectionRole.bridge, SectionRole.chorus),
        isFalse,
      );
      // Stored data could still contain a cycle: it ends at standard.
      display = display.withType(
        SectionRole.bridge,
        const TypeStyle(from: SectionRole.verse),
      );
      expect(
        display.styleOf(SectionRole.verse),
        display.styleOf(SectionRole.standard),
      );
    });

    test('the standard type never inherits', () {
      final display = SongDisplay.classic.withType(
        SectionRole.standard,
        const TypeStyle(from: SectionRole.chorus),
      );
      expect(display.allTypes[SectionRole.standard]!.from, isNull);
      expect(display.styleOf(SectionRole.standard), const SectionStyle());
    });
  });

  group('presets', () {
    test('classic is today\'s look: only the chorus has a bar', () {
      final styles = SongDisplay.classic.resolve();
      for (final MapEntry(:key, :value) in styles.entries) {
        if (key == SectionRole.chorus) {
          expect(value.bar, isTrue);
          expect(value.barWidth, BarWidth.thin);
          expect(value.indent, SectionIndent.normal);
          expect(value.barColor, SongColor.auto);
        } else {
          expect(value, const SectionStyle(), reason: key.name);
        }
      }
    });

    test('every preset resolves all types', () {
      for (final preset in SongDisplayPreset.values) {
        final display = preset == SongDisplayPreset.custom
            ? SongDisplay.custom(const {})
            : SongDisplay.preset(preset);
        expect(display.resolve().keys, SectionRole.values, reason: preset.name);
      }
    });

    test('the guitar preset styles intro and outro like the solo', () {
      final display = const SongDisplay.preset(SongDisplayPreset.guitar);
      expect(
        display.styleOf(SectionRole.intro),
        display.styleOf(SectionRole.interlude),
      );
      expect(
        display.styleOf(SectionRole.interlude).chordColor,
        SongColor.amber,
      );
    });

    test('black/white: everything black/white, no tint, chords and large '
        'headings bold', () {
      final styles = const SongDisplay.preset(SongDisplayPreset.blackWhite)
          .resolve();
      for (final MapEntry(:key, :value) in styles.entries) {
        expect(value.chordColor, SongColor.blackWhite, reason: key.name);
        expect(value.textColor, SongColor.blackWhite, reason: key.name);
        expect(value.labelColor, SongColor.blackWhite, reason: key.name);
        expect(value.barColor, SongColor.blackWhite, reason: key.name);
        expect(value.tint, isFalse, reason: key.name);
        expect(value.chordBold, isTrue, reason: key.name);
        expect(value.textBold, isFalse, reason: key.name);
        expect(value.labelBold, isTrue, reason: key.name);
        expect(value.labelSize, LabelSize.large, reason: key.name);
        expect(value.bar, key == SectionRole.chorus, reason: key.name);
      }
    });
  });

  group('JSON', () {
    test('a preset is stored by its name only', () {
      const display = SongDisplay.preset(SongDisplayPreset.singer);
      expect(display.toJsonString(), '{"preset":"singer"}');
      expect(SongDisplay.fromJsonString(display.toJsonString()), display);
    });

    test('custom styles round trip', () {
      final display = SongDisplay.classic
          .withType(
            SectionRole.chorus,
            const TypeStyle(
              style: SectionStyle(
                textBold: true,
                labelSize: LabelSize.extraLarge,
                bar: true,
                barColor: SongColor.teal,
                tint: true,
              ),
            ),
          )
          .withType(
            SectionRole.intro,
            const TypeStyle(from: SectionRole.verse),
          );
      final again = SongDisplay.fromJsonString(display.toJsonString());
      expect(again, display);
      expect(again.styleOf(SectionRole.chorus).barColor, SongColor.teal);
      expect(again.allTypes[SectionRole.intro]!.from, SectionRole.verse);
    });

    test('unknown keys of a newer version are kept', () {
      const json =
          '{"preset":"custom","layout":"x","types":{"chorus":'
          '{"bar":true,"glow":"soft","from":null},"postChorus":{"bar":true}}}';
      final display = SongDisplay.fromJsonString(json);
      expect(display.styleOf(SectionRole.chorus).bar, isTrue);
      final again = display.toJsonString();
      expect(again, contains('"layout":"x"'));
      expect(again, contains('"glow":"soft"'));
    });

    test('unreadable values give classic or the default', () {
      expect(SongDisplay.fromJsonString(null), SongDisplay.classic);
      expect(SongDisplay.fromJsonString('nonsense'), SongDisplay.classic);
      expect(SongDisplay.fromJsonString('{"preset":"x"}'), SongDisplay.classic);
      final odd = SongDisplay.fromJsonString(
        '{"preset":"custom","types":{"verse":{"chordSize":"huge",'
        '"bar":"yes","from":"nowhere"}}}',
      );
      expect(odd.styleOf(SectionRole.verse), const SectionStyle());
    });

    test('the font is stored only when not standard and kept by presets '
        'and styles', () {
      expect(SongDisplay.classic.font, SongFont.standard);
      final mono = SongDisplay.classic.withFont(SongFont.monospace);
      expect(mono.preset, SongDisplayPreset.classic);
      expect(mono.toJsonString(), '{"preset":"classic","font":"monospace"}');
      expect(SongDisplay.fromJsonString(mono.toJsonString()), mono);
      expect(SongDisplay.fromJsonString(mono.toJsonString()).extra, isEmpty);

      final custom = mono.withType(
        SectionRole.chorus,
        const TypeStyle(style: SectionStyle(textBold: true)),
      );
      expect(custom.font, SongFont.monospace);
      expect(SongDisplay.fromJsonString(custom.toJsonString()), custom);
      expect(
        SongDisplay.fromJsonString('{"preset":"classic","font":"comic"}').font,
        SongFont.standard,
      );
    });

    test('the monospace font applies to lyrics, chords and headings', () {
      const base = TextStyle(fontFamily: 'Inter');
      final standard = SongTextStyles.fromBase(base, 20);
      expect(standard.lyrics.fontFamily, 'Inter');
      final mono = SongTextStyles.fromBase(
        base,
        20,
        display: SongDisplay.classic.withFont(SongFont.monospace),
      );
      final format = FormatState();
      for (final style in [
        mono.lyricsFor(format, role: SectionRole.verse),
        mono.chordFor(format, role: SectionRole.chorus),
        mono.labelFor(format),
      ]) {
        expect(style.fontFamily, 'monospace');
        expect(style.fontFamilyFallback, isNotEmpty);
      }
    });

    test('is a personal setting in AppSettings', () {
      final settings = const AppSettings().copyWith(
        songDisplay: const SongDisplay.preset(SongDisplayPreset.minimal),
      );
      final again = AppSettings.fromJson(settings.toJson());
      expect(again.songDisplay, settings.songDisplay);
      expect(AppSettings.scopes['songDisplay'], SettingSyncScope.personal);
    });
  });
}
