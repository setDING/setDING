import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/app.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/update/whats_new.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// "What's new" notes after an update (ADR-0041).
void main() {
  const json = '''
{
  "0.13.0": {"de": ["Alt."], "en": ["Old."]},
  "0.15.0": {"de": ["Neu."], "en": ["New."]},
  "0.14.1": {"de": [], "en": []},
  "0.14.0": {"de": ["Mittel."], "en": ["Middle."]}
}''';
  final all = parseWhatsNew(json);
  List<String> versions(List<VersionNotes> notes) => [
    for (final v in notes) v.version,
  ];

  group('notes', () {
    test('are sorted newest first', () {
      expect(versions(all), ['0.15.0', '0.14.1', '0.14.0', '0.13.0']);
    });

    test('a wrong format is refused', () {
      expect(() => parseWhatsNew('[]'), throwsFormatException);
      expect(
        () => parseWhatsNew('{"1.0.0": {"en": [1]}}'),
        throwsFormatException,
      );
      expect(() => parseWhatsNew('{"1.0.0": []}'), throwsFormatException);
    });

    test('since the last seen version, without empty ones', () {
      expect(versions(notesSince(all, lastSeen: '0.13.0', current: '0.15.0')), [
        '0.15.0',
        '0.14.0',
      ]);
      expect(
        versions(notesSince(all, lastSeen: '0.14.0', current: '0.14.1')),
        isEmpty,
      );
      expect(
        versions(notesSince(all, lastSeen: '0.15.0', current: '0.15.0')),
        isEmpty,
      );
      // Downgrade.
      expect(
        versions(notesSince(all, lastSeen: '0.15.0', current: '0.14.0')),
        isEmpty,
      );
    });

    test('without a last seen version only the running one', () {
      expect(versions(notesSince(all, lastSeen: null, current: '0.14.0')), [
        '0.14.0',
      ]);
      expect(
        versions(notesSince(all, lastSeen: null, current: '0.14.1')),
        isEmpty,
      );
    });

    test('up to the running version for the settings', () {
      expect(versions(notesUpTo(all, '0.14.1')), ['0.14.0', '0.13.0']);
      expect(versions(notesUpTo(all, null)), ['0.15.0', '0.14.0', '0.13.0']);
    });

    test('in the app language, otherwise in English', () {
      final v = all.first;
      expect(v.inLanguage('de'), ['Neu.']);
      expect(v.inLanguage('fr'), ['New.']);
    });
  });

  group('first start', () {
    test('a new installation has seen the running version', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await recordFirstStart(prefs, '0.15.0');
      expect(prefs.getString(whatsNewSeenKey), '0.15.0');
    });

    test('a device used before counts as updated', () async {
      SharedPreferences.setMockInitialValues({'language': 'de'});
      final prefs = await SharedPreferences.getInstance();
      await recordFirstStart(prefs, '0.15.0');
      expect(prefs.getString(whatsNewSeenKey), isNull);
    });
  });

  group('bundled notes', () {
    final bundled = parseWhatsNew(
      File('assets/whats_new.json').readAsStringSync(),
    );

    test('exist for the version in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version:\s*([^\s+]+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1)!;
      expect(
        versions(bundled),
        contains(version),
        reason:
            'The release PR adds the notes of $version to '
            'app/assets/whats_new.json (ADR-0041); an empty list says nothing.',
      );
    });

    test('are in de-CH and en, equally long, without ß', () {
      for (final v in bundled) {
        expect(v.notes.keys.toSet(), {'de', 'en'}, reason: v.version);
        expect(v.notes['de']!.length, v.notes['en']!.length, reason: v.version);
        for (final note in [...v.notes['de']!, ...v.notes['en']!]) {
          expect(note.trim(), isNotEmpty, reason: v.version);
        }
        for (final note in v.notes['de']!) {
          expect(note, isNot(contains('ß')), reason: v.version);
        }
      }
    });
  });

  group('app', () {
    final snackbar = find.byKey(const Key('whats-new-snackbar'));
    final dialog = find.byKey(const Key('whats-new-dialog'));

    Widget build(TestApp app, {String version = '0.15.0'}) => ProviderScope(
      overrides: [
        ...app.overrides,
        clientVersionProvider.overrideWithValue(version),
        whatsNewProvider.overrideWith((ref) async => all),
      ],
      child: const SetdingApp(home: HomeScreen()),
    );

    Future<TestApp> create(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
    }) async {
      useTabletSize(tester);
      return TestApp.create(prefs: {'language': 'en', ...prefs});
    }

    testWidgets('after an update the notes are offered once', (tester) async {
      final app = await create(tester, prefs: {whatsNewSeenKey: '0.13.0'});
      await tester.pumpWidget(build(app));
      await tester.pumpAndSettle();
      expect(snackbar, findsOneWidget);
      expect(find.text('New in setDING 0.15.0'), findsOneWidget);
      expect(app.prefs.getString(whatsNewSeenKey), '0.15.0');

      await tester.tap(find.byKey(const Key('whats-new-show')));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(find.text('Version 0.15.0'), findsOneWidget);
      expect(find.text('New.'), findsOneWidget);
      expect(find.text('Version 0.14.0'), findsOneWidget);
      expect(find.text('Middle.'), findsOneWidget);
      // Seen before the update.
      expect(find.text('Old.'), findsNothing);
      await tester.tap(find.byKey(const Key('whats-new-close')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      // The next start says nothing.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(build(app));
      await tester.pumpAndSettle();
      expect(snackbar, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('in the app language', (tester) async {
      final app = await create(
        tester,
        prefs: {'language': 'de', whatsNewSeenKey: '0.14.0'},
      );
      await tester.pumpWidget(build(app));
      await tester.pumpAndSettle();
      expect(find.text('Neu in setDING 0.15.0'), findsOneWidget);
      await tester.tap(find.text('Anzeigen'));
      await tester.pumpAndSettle();
      expect(find.text('Neu.'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('nothing when the running version was seen', (tester) async {
      final app = await create(tester, prefs: {whatsNewSeenKey: '0.15.0'});
      await tester.pumpWidget(build(app));
      await tester.pumpAndSettle();
      expect(snackbar, findsNothing);
      await app.dispose(tester);
    });

    testWidgets('a version without notes is marked as seen silently', (
      tester,
    ) async {
      final app = await create(tester, prefs: {whatsNewSeenKey: '0.14.0'});
      await tester.pumpWidget(build(app, version: '0.14.1'));
      await tester.pumpAndSettle();
      expect(snackbar, findsNothing);
      expect(app.prefs.getString(whatsNewSeenKey), '0.14.1');
      await app.dispose(tester);
    });

    testWidgets('always available in the settings', (tester) async {
      final app = await create(tester, prefs: {whatsNewSeenKey: '0.15.0'});
      await tester.pumpWidget(build(app, version: '0.14.1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tapSettingsCategory(tester, 'about');
      await tester.tap(find.byKey(const Key('whats-new')));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(find.text('Middle.'), findsOneWidget);
      expect(find.text('Old.'), findsOneWidget);
      // Not yet installed.
      expect(find.text('New.'), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('the button next to the version fits on a phone', (
      tester,
    ) async {
      final app = await TestApp.create(
        prefs: {'language': 'de', whatsNewSeenKey: '0.15.0'},
      );
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(build(app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen').last);
      await tester.pumpAndSettle();
      await tapSettingsCategory(tester, 'about');
      final button = find.byKey(const Key('whats-new'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(tester.takeException(), isNull);
      await app.dispose(tester);
    });
  });
}
