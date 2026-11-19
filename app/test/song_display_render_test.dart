import 'dart:math' as math;

import 'package:chordpro/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/render/song_display_colors.dart';
import 'package:setding/ui/render/song_view.dart';
import 'package:setding/ui/theme.dart';

import 'test_app.dart';

/// Contrast ratio of two colours (WCAG).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The section block of [source] whose label is [label].
SongBlock blockOf(String source, String label) => buildSongBlocks(
  parseChordPro(source),
  lyricsOnly: false,
  labeler: (_) => null,
).firstWhere((b) => b.label == label);

SongDisplay chorusStyled(SectionStyle style) =>
    SongDisplay.classic.withType(SectionRole.chorus, TypeStyle(style: style));

void main() {
  group('palette', () {
    test('every tone has a contrast of at least 4.5:1', () {
      final light = [
        Colors.white,
        for (final accent in AccentColor.values)
          appColorScheme(Brightness.light, accent).surface,
      ];
      final dark = [
        Colors.black,
        for (final accent in AccentColor.values)
          appColorScheme(Brightness.dark, accent).surface,
      ];
      for (final MapEntry(key: color, value: tones) in songColorTones.entries) {
        for (final bg in light) {
          expect(
            contrast(tones.light, bg),
            greaterThanOrEqualTo(4.5),
            reason: '${color.name} on $bg',
          );
        }
        for (final bg in dark) {
          expect(
            contrast(tones.dark, bg),
            greaterThanOrEqualTo(4.5),
            reason: '${color.name} on $bg',
          );
        }
      }
    });

    test('every colour but automatic has tones', () {
      expect(
        songColorTones.keys.toSet(),
        SongColor.values.where((c) => c != SongColor.auto).toSet(),
      );
      expect(songColorValue(SongColor.auto, Brightness.dark), isNull);
      expect(
        songColorValue(SongColor.teal, Brightness.dark),
        songColorTones[SongColor.teal]!.dark,
      );
    });

    test('black/white is black on light and white on dark backgrounds', () {
      expect(
        songColorValue(SongColor.blackWhite, Brightness.light),
        const Color(0xFF000000),
      );
      expect(
        songColorValue(SongColor.blackWhite, Brightness.dark),
        const Color(0xFFFFFFFF),
      );
    });
  });

  group('precedence over the song (ADR-0033)', () {
    const source =
        '{chordcolour: #0000ff}\n{chordsize: 150%}\n{textcolour: #00ff00}\n'
        '{soc: Chorus}\n[<span foreground="#ff00ff">C</span>]la [G]la\n{eoc}';
    SongTextStyles styles(SongDisplay display) => SongTextStyles.fromBase(
      const TextStyle(),
      20,
      colors: appColorScheme(Brightness.light),
      display: display,
    );

    test('an explicit colour beats the directive, automatic lets it '
        'through', () {
      final block = blockOf(source, 'Chorus');
      final auto = styles(SongDisplay.classic);
      expect(
        auto.chordFor(block.startFormat, role: SectionRole.chorus).color,
        const Color(0xFF0000FF),
      );
      expect(
        auto.lyricsFor(block.startFormat, role: SectionRole.chorus).color,
        const Color(0xFF00FF00),
      );
      final red = styles(
        chorusStyled(
          const SectionStyle(
            chordColor: SongColor.red,
            textColor: SongColor.grey,
          ),
        ),
      );
      expect(
        red.chordFor(block.startFormat, role: SectionRole.chorus).color,
        songColorTones[SongColor.red]!.light,
      );
      expect(
        red.lyricsFor(block.startFormat, role: SectionRole.chorus).color,
        songColorTones[SongColor.grey]!.light,
      );
    });

    test('sizes multiply', () {
      final block = blockOf(source, 'Chorus');
      final large = styles(
        chorusStyled(const SectionStyle(chordSize: ChordSize.large)),
      );
      expect(
        large.chordFor(block.startFormat, role: SectionRole.chorus).fontSize,
        closeTo(20 * SongTextStyles.chordScale * 1.2 * 1.5, 0.001),
      );
    });

    test('inline markup wins over the style', () {
      final block = blockOf(source, 'Chorus');
      final red = styles(
        chorusStyled(const SectionStyle(chordColor: SongColor.red)),
      );
      final line = block.lines.whereType<LyricLine>().single;
      final piece = chordLinePieces(
        line,
        ChordFormatter.forSong(parseChordPro(source)),
      ).first;
      final chord = applyMarkupStyle(
        red.chordFor(block.startFormat, role: SectionRole.chorus),
        piece.chordMarkup,
      );
      expect(chord.color, const Color(0xFFFF00FF));
    });

    test('bold means 700 and not bold 400, also for labels', () {
      final s = styles(
        SongDisplay.classic.withType(
          SectionRole.verse,
          const TypeStyle(
            style: SectionStyle(
              chordBold: false,
              labelBold: false,
              textBold: true,
              labelItalic: true,
            ),
          ),
        ),
      );
      final format = FormatState();
      expect(s.chordFor(format).fontWeight, FontWeight.w700);
      expect(s.labelFor(format).fontWeight, FontWeight.w700);
      expect(
        s.chordFor(format, role: SectionRole.verse).fontWeight,
        FontWeight.w400,
      );
      expect(
        s.labelFor(format, role: SectionRole.verse).fontWeight,
        FontWeight.w400,
      );
      expect(
        s.labelFor(format, role: SectionRole.verse).fontStyle,
        FontStyle.italic,
      );
      expect(
        s.lyricsFor(format, role: SectionRole.verse).fontWeight,
        FontWeight.w700,
      );
      // Comments and notes stay neutral.
      expect(s.lyricsFor(format).fontWeight, isNot(FontWeight.w700));
    });
  });

  group('rendering', () {
    const source =
        '{c: Intro}\n[G]Intro line\n\n{sov: Verse 1}\n[G]Verse line\n{eov}\n\n'
        '{soc: Chorus}\n[C]Chorus line\n{eoc}';

    Future<void> pump(WidgetTester tester, SongDisplay display) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      final song = parseChordPro(source);
      await tester.pumpWidget(
        app.build(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SongBody(
                song: song,
                options: SongRenderOptions(
                  formatter: ChordFormatter.forSong(song),
                  display: display,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The left border width of the frame around the text [text].
    double? barWidth(WidgetTester tester, String text) {
      final frames = find.ancestor(
        of: find.textContaining(text, findRichText: true),
        matching: find.byType(Container),
      );
      for (final c in tester.widgetList<Container>(frames)) {
        final border = (c.decoration as BoxDecoration?)?.border;
        if (border is Border) return border.left.width;
      }
      return null;
    }

    testWidgets('classic: only the chorus has a bar', (tester) async {
      await pump(tester, SongDisplay.classic);
      expect(barWidth(tester, 'Chorus '), closeTo(0.15 * 20, 0.001));
      expect(barWidth(tester, 'Verse '), isNull);
      expect(barWidth(tester, 'Intro '), isNull);
      expect(find.textContaining('VERSE 1', findRichText: true), findsOne);
    });

    testWidgets('hidden labels are not shown', (tester) async {
      await pump(tester, const SongDisplay.preset(SongDisplayPreset.minimal));
      expect(find.textContaining('VERSE 1', findRichText: true), findsNothing);
      expect(find.textContaining('INTRO', findRichText: true), findsNothing);
      expect(find.textContaining('CHORUS', findRichText: true), findsOne);
    });

    testWidgets('intro inherits from the interlude', (tester) async {
      await pump(
        tester,
        SongDisplay.classic.withType(
          SectionRole.interlude,
          const TypeStyle(
            style: SectionStyle(bar: true, barWidth: BarWidth.wide),
          ),
        ),
      );
      expect(barWidth(tester, 'Intro '), closeTo(0.4 * 20, 0.001));
      expect(barWidth(tester, 'Verse '), isNull);
    });
  });
}
