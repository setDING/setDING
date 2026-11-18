import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/settings/song_display_settings.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

void main() {
  Future<TestApp> pumpSettings(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool narrow = false,
  }) async {
    if (narrow) {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    } else {
      useTabletSize(tester);
    }
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tapSettingsCategory(tester, 'songDisplay');
    return app;
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

  SongDisplay display(WidgetTester tester) =>
      container(tester).read(settingsProvider).songDisplay;

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) =>
      tap(tester, 'song-display-customise');

  testWidgets('a personal category with presets and a preview, classic by '
      'default', (tester) async {
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
    // The styles per section are edited on their own page.
    expect(find.byKey(const Key('song-display-type-chorus')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('choosing a preset and changing a style makes it custom', (
    tester,
  ) async {
    final app = await pumpSettings(tester);
    await tap(tester, 'song-display-preset-guitar');
    expect(display(tester).preset, SongDisplayPreset.guitar);

    await openEditor(tester);
    // Standard has no parent to choose.
    expect(find.byKey(const Key('song-display-inherit')), findsNothing);
    await tap(tester, 'song-display-type-chorus');
    await tap(tester, 'song-display-text-bold');
    await tap(tester, 'song-display-barColor-teal');
    final custom = display(tester);
    expect(custom.preset, SongDisplayPreset.custom);
    expect(custom.styleOf(SectionRole.chorus).textBold, isTrue);
    expect(custom.styleOf(SectionRole.chorus).barColor, SongColor.teal);
    // The rest of the guitar preset is kept.
    expect(custom.styleOf(SectionRole.bridge).chordColor, SongColor.red);

    // Another preset asks before discarding the custom styles; the presets
    // are at the top of the controls.
    await tester.drag(
      find.byKey(const Key('song-display-controls')),
      const Offset(0, 3000),
    );
    await tester.pumpAndSettle();
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
    await openEditor(tester);
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

  group('editor layout (#478)', () {
    final controls = find.byKey(const Key('song-display-controls'));
    final preview = find.byKey(const Key('song-display-preview'));

    testWidgets('tablet: the preview stands next to the controls', (
      tester,
    ) async {
      final app = await pumpSettings(tester);
      await openEditor(tester);
      final c = tester.getRect(controls);
      final p = tester.getRect(preview);
      expect(p.left, greaterThan(c.right));
      expect(c.width, SongDisplayEditorScreen.controlsWidth);
      // Scrolling the controls keeps the preview where it is.
      await tester.drag(controls, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(preview), p);
      await app.dispose(tester);
    });

    testWidgets('phone: the preview is pinned on top and resizable', (
      tester,
    ) async {
      final app = await pumpSettings(tester, narrow: true);
      await openEditor(tester);
      final c = tester.getRect(controls);
      final p = tester.getRect(preview);
      expect(p.bottom, lessThanOrEqualTo(c.top));
      await tester.drag(controls, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(preview), p);
      await tester.drag(
        find.byKey(const Key('song-display-resize')),
        const Offset(0, 100),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(preview).height, greaterThan(p.height + 50));
      await app.dispose(tester);
    });

    testWidgets('selecting a type scrolls the preview to it', (tester) async {
      final app = await pumpSettings(tester, narrow: true);
      await openEditor(tester);
      final scrollable = find.descendant(
        of: preview,
        matching: find.byType(Scrollable),
      );
      double offset() =>
          tester.state<ScrollableState>(scrollable.first).position.pixels;
      expect(offset(), 0);
      await tap(tester, 'song-display-type-outro');
      expect(offset(), greaterThan(0));
      expect(
        tester.getRect(find.textContaining('OUTRO', findRichText: true)).top,
        lessThan(tester.getRect(preview).bottom),
      );
      await app.dispose(tester);
    });
  });

  group('preview song (#478)', () {
    testWidgets('a song from the library, remembered on the device', (
      tester,
    ) async {
      final app = await pumpSettings(tester);
      await tester.runAsync(
        () => app.songs.createSong(
          source: '{title: Library Tune}\n{soc}\n[C]Only in the library\n{eoc}',
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'song-display-preview-song');
      await tester.tap(find.byKey(const Key('song-display-preview-library')));
      await tester.pumpAndSettle();
      expect(find.text('Song for the preview'), findsOneWidget);
      await tester.tap(find.text('Library Tune'));
      await tester.pumpAndSettle();
      expect(find.textContaining('library', findRichText: true), findsWidgets);
      expect(find.text('Library Tune'), findsOneWidget);
      final id = container(tester).read(songDisplayPreviewSongProvider);
      expect(id, isNotNull);
      expect(
        container(tester)
            .read(sharedPreferencesProvider)
            .getString(PreviewSongNotifier.prefsKey),
        id,
      );

      // Back to the demo song.
      await tap(tester, 'song-display-preview-song');
      await tester.tap(find.byKey(const Key('song-display-preview-demo')));
      await tester.pumpAndSettle();
      expect(container(tester).read(songDisplayPreviewSongProvider), isNull);
      expect(find.text('Demo song'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a missing song falls back to the demo song', (tester) async {
      final app = await pumpSettings(
        tester,
        prefs: {PreviewSongNotifier.prefsKey: 'gone'},
      );
      expect(find.text('Demo song'), findsOneWidget);
      expect(find.textContaining('Streetlights', findRichText: true), findsOne);
      await app.dispose(tester);
    });
  });
}
