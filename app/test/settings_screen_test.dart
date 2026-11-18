import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/theme.dart';

import 'test_app.dart';

void main() {
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
      // Organizations and bands only when signed in (see below).
      if (c == SettingsCategory.bands) continue;
      final category = find.byKey(Key('settings-category-${c.name}'));
      await reveal(tester, category);
      expect(category, findsOneWidget);
    }
    await reveal(
      tester,
      find.byKey(const Key('settings-category-account')),
      delta: -100,
    );
    // The account category is shown first.
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await tester.tap(find.byKey(const Key('settings-category-general')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Not signed in'), findsNothing);

    await reveal(tester, find.byKey(const Key('settings-category-live')));
    await tester.tap(find.byKey(const Key('settings-category-live')));
    await tester.pumpAndSettle();
    expect(find.text('Fit song to screen'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
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
    final account = find.byKey(const Key('settings-category-account'));
    expect(top(account), lessThan(top(personal)));
    expect(top(personal), lessThan(top(general)));
    expect(top(display), lessThan(top(device)));
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
    final account = find.byKey(const Key('settings-category-account'));
    final before = tester.widget(account);
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    await tester.pumpAndSettle();
    expect(identical(tester.widget(account), before), isTrue);
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
    expect(bands, findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(
      top(find.byKey(const Key('settings-category-account'))),
      lessThan(top(bands)),
    );
    expect(
      top(bands),
      lessThan(top(find.byKey(const Key('settings-group-personal')))),
    );

    await tester.tap(bands);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-o1')), findsOneWidget);
    expect(find.text('Rock'), findsWidgets);
    expect(find.byKey(const Key('settings-bands-join')), findsOneWidget);
    // An organization admin may create bands.
    expect(find.byKey(const Key('settings-bands-new')), findsOneWidget);

    // Signed out, the category disappears and the account is shown.
    await tester.runAsync(app.backend.signOut);
    await tester.pumpAndSettle();
    expect(bands, findsNothing);
    expect(find.text('Not signed in'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('settings-category-bands')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-o1')), findsOneWidget);
    expect(find.byKey(const Key('settings-bands-join')), findsOneWidget);
    expect(find.byKey(const Key('settings-bands-new')), findsNothing);
    await app.dispose(tester);
  });
}
