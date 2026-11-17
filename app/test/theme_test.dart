import 'dart:math';

import 'package:chordpro/chordpro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/ui/render/song_style.dart';
import 'package:realchord/ui/songs/chordpro_editing_controller.dart';
import 'package:realchord/ui/theme.dart';
import 'package:realchord/ui/widgets/logo.dart';

import 'test_app.dart';

/// WCAG contrast ratio of two colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// CIELAB (D65) of [c].
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

/// Colour difference (CIE76 ΔE); above about 20 two colours read as
/// different colours, not as shades of one.
double _deltaE(Color a, Color b) {
  final p = _lab(a), q = _lab(b);
  return sqrt(pow(p[0] - q[0], 2) + pow(p[1] - q[1], 2) + pow(p[2] - q[2], 2));
}

/// The colour scheme is derived from the logo red (issue #269).
void main() {
  test('the scheme is seeded with the logo red', () {
    expect(brandSeed, const Color(0xFFE8461C));
    expect(brandSeed, BrandColors.gradientBottom);
    for (final brightness in Brightness.values) {
      final seeded = ColorScheme.fromSeed(
        seedColor: brandSeed,
        brightness: brightness,
      );
      final scheme = appColorScheme(brightness);
      expect(scheme.primary, seeded.primary, reason: '$brightness');
      expect(scheme.surface, seeded.surface, reason: '$brightness');
      expect(appTheme(brightness).colorScheme, scheme);
    }
  });

  test('error colours stay apart from the primary colours', () {
    for (final brightness in Brightness.values) {
      final s = appColorScheme(brightness);
      final reason = '$brightness';
      expect(_deltaE(s.error, s.primary), greaterThan(30), reason: reason);
      expect(
        _deltaE(s.errorContainer, s.primaryContainer),
        greaterThan(15),
        reason: reason,
      );
      expect(
        _deltaE(s.errorContainer, s.secondaryContainer),
        greaterThan(15),
        reason: reason,
      );
      // Still readable.
      expect(_contrast(s.error, s.surface), greaterThan(4.5), reason: reason);
      expect(_contrast(s.onError, s.error), greaterThan(4.5), reason: reason);
      expect(
        _contrast(s.onErrorContainer, s.errorContainer),
        greaterThan(4.5),
        reason: reason,
      );
    }
  });

  test('lyrics, chords and editor colours have enough contrast', () {
    for (final brightness in Brightness.values) {
      final s = appColorScheme(brightness);
      final reason = '$brightness';
      // Lyrics and chords outside live mode (WCAG AA).
      expect(_contrast(s.onSurface, s.surface), greaterThan(4.5));
      expect(_contrast(s.primary, s.surface), greaterThan(4.5));
      for (final kind in [
        SourceTokenKind.chord,
        SourceTokenKind.sectionDirective,
        SourceTokenKind.metaDirective,
        SourceTokenKind.customDirective,
        SourceTokenKind.error,
      ]) {
        final color = chordProTokenStyle(kind, s)!.color!;
        expect(
          _contrast(color, s.surface),
          greaterThan(4.5),
          reason: '$reason $kind',
        );
      }
      // Editor errors are not mistaken for chords.
      expect(
        _deltaE(
          chordProTokenStyle(SourceTokenKind.error, s)!.color!,
          chordProTokenStyle(SourceTokenKind.chord, s)!.color!,
        ),
        greaterThan(30),
        reason: reason,
      );
    }
  });

  test('the light stage chord colour has the hue of the logo red', () {
    final brand = HSLColor.fromColor(brandSeed).hue;
    final chord = HSLColor.fromColor(StageColors.light.chord).hue;
    expect((chord - brand).abs(), lessThan(5));
    expect(
      _contrast(
        StageColors.light.chord,
        appColorScheme(Brightness.light).surface,
      ),
      greaterThan(7),
    );
    // Amber on dark and black (#263).
    expect(StageColors.dark.chord, const Color(0xFFFFC54D));
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('the conflict icon stands apart from the gig icon ($mode)', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'themeMode': mode},
      );
      await tester.runAsync(() async {
        final a = await app.songs.createSong(source: '{title: Alpha}\n[G]x');
        await app.db
            .into(app.db.songConflicts)
            .insert(
              SongConflictsCompanion.insert(
                songId: a,
                title: 'Alpha',
                chordproSource: '{title: Alpha}',
                revision: 2,
                detectedAt: DateTime.now(),
              ),
            );
        final set = await app.sets.createSet(
          name: 'Summer Festival',
          gigDate: DateTime.now().add(const Duration(days: 3)),
        );
        await app.sets.addSongs(set, [a]);
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Songs').first);
      await tester.pumpAndSettle();

      Icon icon(String name) => tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey('song-status-$name')),
          matching: find.byType(Icon),
        ),
      );
      final scheme = Theme.of(
        tester.element(find.byKey(const ValueKey('song-status-conflict'))),
      ).colorScheme;
      expect(scheme.brightness.name, mode);
      final conflict = icon('conflict');
      final gig = icon('gig');
      expect(conflict.color, scheme.error);
      expect(gig.color, scheme.primary);
      expect(conflict.icon, isNot(gig.icon));
      expect(_deltaE(conflict.color!, gig.color!), greaterThan(30));
      await app.dispose(tester);
    });
  }
}
