import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/theme.dart';
import 'package:setding/ui/widgets/docs_link.dart';

import 'test_app.dart';

void main() {
  test('documentation pages in the language of the app', () {
    expect(
      docsPageUrl('songs/chord-views', const Locale('de')).toString(),
      'https://setding.app/songs/chord-views/',
    );
    expect(
      docsPageUrl('songs/chord-views', const Locale('en')).toString(),
      'https://setding.app/en/songs/chord-views/',
    );
  });

  Future<TestApp> pumpSettings(WidgetTester tester) async {
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    return app;
  }

  /// Scrolls the category list (the first list) until [finder] is built
  /// and fully visible: not all categories fit on a landscape tablet.
  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    double delta = 100,
  }) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        delta,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('wide: categories on the left, the selected one next to them', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await pumpSettings(tester);

    for (final c in SettingsCategory.values) {
      // Organizations and bands only when signed in (see below), the test
      // features only in developer mode (#559), the keyboard MIDI settings
      // only for keyboard players (#578).
      if (c == SettingsCategory.bands ||
          c == SettingsCategory.development ||
          c == SettingsCategory.midi) {
        continue;
      }
      final category = find.byKey(Key('settings-category-${c.name}'));
      await reveal(tester, category);
      expect(category, findsOneWidget);
    }
    await reveal(
      tester,
      find.byKey(const Key('settings-category-general')),
      delta: -100,
    );
    // The first category, general, is shown first.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Not signed in'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-display')));
    await tester.pumpAndSettle();
    expect(find.text('Chord notation'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    // The chord view links to its documentation page (ADR-0055).
    expect(find.byKey(const Key('chord-view-docs')), findsOneWidget);

    await reveal(tester, find.byKey(const Key('settings-category-live')));
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    expect(find.text('Fit song to screen'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await reveal(tester, find.byKey(const Key('settings-category-account')));
    await tester.tap(find.byKey(const Key('settings-category-account')));
    await tester.pumpAndSettle();
    expect(find.text('Not signed in'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the most used categories come first, the account last '
      '(#548)', (tester) async {
    useTabletSize(tester);
    // Tall enough to list all categories without scrolling.
    tester.view.physicalSize = const Size(1280, 2000);
    const ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
    final app = await TestApp.create(prefs: {'language': 'en'}, user: ann);
    app.backend.addBand('b1', 'Rock', admin: ann, organizationId: 'o1');
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Account & organization'), findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    Finder group(String name) => find.byKey(Key('settings-group-$name'));
    Finder category(String name) => find.byKey(Key('settings-category-$name'));
    final order = [
      group('personal'),
      category('general'),
      category('display'),
      category('songDisplay'),
      category('musician'),
      group('device'),
      category('live'),
      category('about'),
      group('account'),
      category('account'),
      category('bands'),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i - 1]), lessThan(top(order[i])));
    }
    // The first category is selected.
    expect(find.text('Language'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('personal and device settings are grouped and explained '
      '(ADR-0027)', (tester) async {
    useTabletSize(tester);
    final app = await pumpSettings(tester);
    final personal = find.byKey(const Key('settings-group-personal'));
    final device = find.byKey(const Key('settings-group-device'));
    expect(find.text('Personal – on all your devices'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    final general = find.byKey(const Key('settings-category-general'));
    final display = find.byKey(const Key('settings-category-display'));
    final live = find.byKey(const Key('settings-category-live'));
    expect(top(personal), lessThan(top(display)));
    expect(top(general), lessThan(top(device)));
    expect(top(device), lessThan(top(live)));

    // Signed out: personal settings are synced after signing in.
    await tester.tap(display);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-scope-personal')), findsOneWidget);
    expect(find.textContaining('After signing in'), findsOneWidget);
    expect(find.text('Font size'), findsNothing);

    await reveal(tester, live);
    await tester.tap(live);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-scope-device')), findsOneWidget);
    expect(find.textContaining('not synced'), findsOneWidget);
    expect(find.text('Font size'), findsOneWidget);

    // Signed in: they belong to the account.
    app.backend.accounts['ann@example.test'] = 'secret';
    await tester.runAsync(
      () => app.backend.signIn(email: 'ann@example.test', password: 'secret'),
    );
    await reveal(tester, display, delta: -100);
    await tester.tap(display);
    await tester.pumpAndSettle();
    expect(find.textContaining('belong to your account'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the keyboard opening keeps the settings as built (#297)', (
    tester,
  ) async {
    // The settings stay built behind the other tabs of the home screen, so
    // they would otherwise be built again in each frame while the keyboard
    // opens for the song search.
    useTabletSize(tester);
    final app = await pumpSettings(tester);
    final display = find.byKey(const Key('settings-category-display'));
    final before = tester.widget(display);
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    await tester.pumpAndSettle();
    expect(identical(tester.widget(display), before), isTrue);
    await app.dispose(tester);
  });

  testWidgets('narrow: a category opens as its own page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await pumpSettings(tester);

    expect(find.text('Not signed in'), findsNothing);
    expect(find.text('Language and theme'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-category-display')));
    await tester.pumpAndSettle();
    expect(find.text('Chord notation'), findsOneWidget);
    expect(find.byKey(const Key('settings-category-general')), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Lyrics only'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // The sections are built as a whole, so the option may be built but
    // still below the screen.
    await tester.ensureVisible(find.text('Lyrics only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lyrics only'));
    await tester.pumpAndSettle();
    expect(app.personal()['displayMode'], 'lyricsOnly');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-category-general')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the accent colour is chosen from swatches (#300)', (
    tester,
  ) async {
    useTabletSize(tester);
    final semantics = tester.ensureSemantics();
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-category-general')));
    await tester.pumpAndSettle();

    expect(find.text('Accent colour'), findsOneWidget);
    for (final accent in AccentColor.values) {
      expect(find.byKey(Key('accent-${accent.name}')), findsOneWidget);
    }
    // The brand blue is the default.
    expect(find.text('setDING blue'), findsOneWidget);
    Color primary() =>
        Theme.of(tester.element(find.text('Accent colour')))
            .colorScheme
            .primary;
    expect(primary(), appColorScheme(Brightness.light).primary);

    await tester.tap(find.byKey(const Key('accent-teal')));
    await tester.pumpAndSettle();
    expect(app.personal()['accent'], 'teal');
    expect(find.text('Teal'), findsOneWidget);
    // The whole app follows the new accent.
    expect(
      primary(),
      appColorScheme(Brightness.light, AccentColor.teal).primary,
    );
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byKey(const Key('accent-teal')),
          matching: find.byType(InkResponse),
        ),
      ),
      matchesSemantics(
        label: 'Teal',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    await app.dispose(tester);
  });

  testWidgets('chord style and raised extensions', (tester) async {
    useTabletSize(tester);
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-category-display')));
    await tester.pumpAndSettle();

    SwitchListTile superscript() => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Raise extensions'),
    );
    expect(find.text('Chord style'), findsOneWidget);
    // Raising needs a style other than "as written".
    expect(superscript().onChanged, isNull);

    await tester.tap(find.text('Jazz'));
    await tester.pumpAndSettle();
    expect(app.personal()['chordStyle'], 'jazz');
    expect(superscript().onChanged, isNotNull);

    await tester.tap(find.text('Raise extensions'));
    await tester.pumpAndSettle();
    expect(app.personal()['chordSuperscript'], isTrue);
    await app.dispose(tester);
  });

  testWidgets('organizations and bands are their own category, only when '
      'signed in (#480)', (tester) async {
    useTabletSize(tester);
    const ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
    final app = await TestApp.create(prefs: {'language': 'en'}, user: ann);
    app.backend.addBand('b1', 'Rock', admin: ann, organizationId: 'o1');
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();

    // Account & sync no longer lists the bands.
    expect(find.text('Manage bands'), findsNothing);
    final bands = find.byKey(const Key('settings-category-bands'));
    await reveal(tester, bands);
    expect(bands, findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(
      top(find.byKey(const Key('settings-group-account'))),
      lessThan(top(find.byKey(const Key('settings-category-account')))),
    );
    expect(
      top(find.byKey(const Key('settings-category-account'))),
      lessThan(top(bands)),
    );

    await tester.tap(bands);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-o1')), findsOneWidget);
    expect(find.text('Rock'), findsWidgets);
    expect(find.byKey(const Key('settings-bands-join')), findsOneWidget);
    // An organization admin may create bands.
    expect(find.byKey(const Key('settings-bands-new')), findsOneWidget);

    // Signed out, the category disappears and the first one is shown.
    await tester.runAsync(app.backend.signOut);
    await tester.pumpAndSettle();
    expect(bands, findsNothing);
    expect(find.text('Language'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('members see their bands but cannot create one on an '
      'invite-only server (#480)', (tester) async {
    useTabletSize(tester);
    const ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
    const bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');
    final app = await TestApp.create(prefs: {'language': 'en'}, user: bob);
    app.backend.config = const ServerConfig(
      registration: RegistrationMode.inviteOnly,
    );
    app.backend.addBand('b1', 'Rock', admin: ann, organizationId: 'o1');
    app.backend.addOrgMember('o1', bob, OrgRole.member);
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('settings-category-bands')));
    await tester.tap(find.byKey(const Key('settings-category-bands')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-o1')), findsOneWidget);
    expect(find.byKey(const Key('settings-bands-join')), findsOneWidget);
    expect(find.byKey(const Key('settings-bands-new')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the editor typing aids are switched off in General (#757)', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-category-general')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('settings-editor-typing-aids'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Close brackets and sections automatically'), findsOne);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(container.read(settingsProvider).editorTypingAids, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).editorTypingAids, isFalse);
    expect(AppSettings.scopes['editorTypingAids'], SettingSyncScope.personal);
    await app.dispose(tester);
  });

  testWidgets('developer mode shows the test features, the MIDI test only '
      'there (#559)', (tester) async {
    useTabletSize(tester);
    // Tall enough to list all categories without scrolling.
    tester.view.physicalSize = const Size(1280, 2000);
    final app = await pumpSettings(tester);
    final development = find.byKey(const Key('settings-category-development'));
    final midi = find.byKey(const Key('settings-midi-test'));
    expect(development, findsNothing);
    expect(find.byKey(const Key('settings-group-development')), findsNothing);

    // Not in the live mode settings any more.
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    expect(midi, findsNothing);

    // Switched on in General: the category appears last, with the note.
    await tester.tap(find.byKey(const Key('settings-category-general')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('settings-developer-mode'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(container.read(settingsProvider).developerMode, isTrue);
    expect(development, findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-category-account'))).dy,
      lessThan(tester.getTopLeft(development).dy),
    );

    await tester.tap(development);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-experimental-note')), findsOneWidget);
    expect(find.text('Experimental features'), findsOneWidget);
    expect(midi, findsOneWidget);

    // Switched off while the category is shown: back to the first one.
    await tester.runAsync(
      () => container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(developerMode: false)),
    );
    await tester.pumpAndSettle();
    expect(development, findsNothing);
    expect(midi, findsNothing);
    expect(find.text('Language'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the keyboard MIDI settings only for keyboard players (#578)', (
    tester,
  ) async {
    useTabletSize(tester);
    // Tall enough to list all categories without scrolling.
    tester.view.physicalSize = const Size(1280, 2000);
    final app = await pumpSettings(tester);
    final midi = find.byKey(const Key('settings-category-midi'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    Future<void> instrument(String value) async {
      await tester.runAsync(
        () => container
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(instrument: value)),
      );
      await tester.pumpAndSettle();
    }

    // Guitar by default: not listed.
    expect(container.read(settingsProvider).instrument, 'guitar');
    expect(midi, findsNothing);

    await instrument('keyboard');
    expect(midi, findsOneWidget);
    await tester.tap(midi);
    await tester.pumpAndSettle();
    expect(find.text('MIDI program changes'), findsOneWidget);

    // Another instrument while the category is shown: back to the first one.
    await instrument('bass');
    expect(midi, findsNothing);
    expect(find.text('MIDI program changes'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    await app.dispose(tester);
  });
}
