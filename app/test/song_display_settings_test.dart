import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/settings/song_display_settings.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

void main() {
  Future<TestApp> pumpSettings(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-songDisplay')));
    await tester.pumpAndSettle();
    return app;
  }

  SongDisplay display(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(SongDisplaySettings)),
  ).read(settingsProvider).songDisplay;

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a personal category with a preview, classic by default', (
    tester,
  ) async {
    final app = await pumpSettings(tester);
    expect(find.text('Song display'), findsWidgets);
    expect(find.byKey(const Key('song-display-preview')), findsOneWidget);
    expect(display(tester), SongDisplay.classic);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('song-display-preset-classic')),
          )
          .selected,
      isTrue,
    );
    // Standard has no parent to choose.
    expect(find.byKey(const Key('song-display-inherit')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('choosing a preset and changing a style makes it custom', (
    tester,
  ) async {
    final app = await pumpSettings(tester);
    await tap(tester, 'song-display-preset-guitar');
    expect(display(tester).preset, SongDisplayPreset.guitar);

    await tap(tester, 'song-display-type-chorus');
    await tap(tester, 'song-display-text-bold');
    await tap(tester, 'song-display-barColor-teal');
    final custom = display(tester);
    expect(custom.preset, SongDisplayPreset.custom);
    expect(custom.styleOf(SectionRole.chorus).textBold, isTrue);
    expect(custom.styleOf(SectionRole.chorus).barColor, SongColor.teal);
    // The rest of the guitar preset is kept.
    expect(custom.styleOf(SectionRole.bridge).chordColor, SongColor.red);

    // Another preset asks before discarding the custom styles.
    await tap(tester, 'song-display-preset-minimal');
    expect(find.text('Discard custom styles?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(display(tester), custom);
    await tap(tester, 'song-display-preset-minimal');
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(display(tester).preset, SongDisplayPreset.minimal);
    await app.dispose(tester);
  });

  testWidgets('a type inherits from a chosen type; cycles are disabled', (
    tester,
  ) async {
    final app = await pumpSettings(tester);
    // Intro inherits from the interlude by default: no style controls.
    await tap(tester, 'song-display-type-intro');
    expect(
      find.textContaining('Takes everything from: Interlude → Standard'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('song-display-chord-bold')), findsNothing);

    // The interlude cannot inherit from the intro (a cycle).
    await tap(tester, 'song-display-type-interlude');
    await tap(tester, 'song-display-inherit');
    final intro = find.text('Like Intro').last;
    final item = tester.widget<DropdownMenuItem<SectionRole?>>(
      find.ancestor(
        of: intro,
        matching: find.byType(DropdownMenuItem<SectionRole?>),
      ),
    );
    expect(item.enabled, isFalse);
    await tester.tap(find.text('Like Verse').last);
    await tester.pumpAndSettle();
    expect(
      display(tester).allTypes[SectionRole.interlude]!.from,
      SectionRole.verse,
    );

    // Own style starts from the inherited look and can be changed.
    await tap(tester, 'song-display-inherit');
    await tester.tap(find.text('Own style').last);
    await tester.pumpAndSettle();
    await tap(tester, 'song-display-chord-italic');
    final d = display(tester);
    expect(d.allTypes[SectionRole.interlude]!.from, isNull);
    expect(d.styleOf(SectionRole.interlude).chordItalic, isTrue);
    expect(d.styleOf(SectionRole.outro).chordItalic, isTrue);
    await app.dispose(tester);
  });
}
