import 'package:flutter/services.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/ui/widgets/docs_link.dart';
import 'package:setding/ui/widgets/side_panel.dart';

import 'test_app.dart';

/// In-app help (#993): the documentation pages the app links to and the
/// buttons that open them.
void main() {
  /// The URLs the app asked the platform to open.
  late List<String> launched;

  setUp(() {
    launched = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
  });

  test('a page in the language of the app', () {
    expect(
      DocsPage.chordViews.url(const Locale('de')).toString(),
      'https://setding.app/songs/chord-views/',
    );
    expect(
      DocsPage.chordViews.url(const Locale('en')).toString(),
      'https://setding.app/en/songs/chord-views/',
    );
  });

  test('UI languages without documentation get the English pages', () {
    for (final lang in ['it', 'fr', 'es']) {
      expect(
        DocsPage.roles.url(Locale(lang)).toString(),
        'https://setding.app/en/bands/roles/',
      );
    }
  });

  test('every page has a path below the language folder', () {
    for (final page in DocsPage.values) {
      expect(page.path, matches(RegExp(r'^[a-z-]+(/[a-z-]+)*$')));
    }
  });

  Widget localized(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('the help button names its topic and opens the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(
        const DocsHelpButton(page: DocsPage.roles, topic: 'Members'),
        locale: const Locale('de'),
      ),
    );
    expect(find.byTooltip('Hilfe: Members'), findsOneWidget);
    await tester.tap(find.byType(DocsHelpButton));
    await tester.pump();
    expect(launched, ['https://setding.app/bands/roles/']);
  });

  testWidgets('a side panel shows the help button of its page', (tester) async {
    await tester.pumpWidget(
      localized(
        const SidePanel(
          icon: Icons.groups_outlined,
          title: 'Arrangement',
          docs: DocsPage.keyAndSequence,
          children: [],
        ),
      ),
    );
    expect(find.byTooltip('Help: Arrangement'), findsOneWidget);
    await tester.tap(find.byKey(const Key('side-panel-docs')));
    await tester.pump();
    expect(launched, ['https://setding.app/en/sets/key-and-sequence/']);

    await tester.pumpWidget(
      localized(
        const SidePanel(icon: Icons.groups_outlined, title: 'X', children: []),
      ),
    );
    expect(find.byKey(const Key('side-panel-docs')), findsNothing);
  });

  testWidgets('the settings link to the documentation', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();

    // The open category has a help button next to its title.
    final help = find.byKey(const Key('settings-category-docs'));
    expect(help, findsOneWidget);
    expect(find.byTooltip('Help: General'), findsOneWidget);
    await tester.tap(help);
    await tester.pump();
    expect(launched.last, 'https://setding.app/en/settings/general/');

    // The documentation entry under Help & info opens the first steps.
    await openSettingsCategory(tester, SettingsCategory.about);
    final docs = find.byKey(const Key('settings-docs'));
    await tester.scrollUntilVisible(
      docs,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(docs);
    await tester.pumpAndSettle();
    await tester.tap(docs);
    await tester.pump();
    expect(launched.last, 'https://setding.app/en/start/overview/');
    await app.dispose(tester);
  });

  testWidgets('the test features have no help page', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'developerMode': true},
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.development);
    expect(find.byKey(const Key('settings-category-docs')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a category page on a phone has the help button in its app '
      'bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-display')));
    await tester.pumpAndSettle();
    final help = find.descendant(
      of: find.byType(AppBar),
      matching: find.byKey(const Key('settings-category-docs')),
    );
    expect(help, findsOneWidget);
    await tester.tap(help);
    await tester.pump();
    expect(launched.last, 'https://setding.app/en/settings/display/');
    await app.dispose(tester);
  });
}
