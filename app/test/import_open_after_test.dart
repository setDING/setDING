import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/ui/songs/import_dialog.dart';
import 'package:setding/ui/songs/song_screen.dart';

import 'test_app.dart';

/// A single song imported from files opens after the import (#1027).
void main() {
  ImportFile file(String name, String text) =>
      ImportFile(name, Uint8List.fromList(utf8.encode(text)));

  // With a key and without problems: no import report.
  final plain = file('plain.cho', '{title: Plain}\n{key: C}\n[C]a [G]b');
  final other = file('other.cho', '{title: Other}\n{key: G}\n[G]a [D]b');

  Future<TestApp> start(
    WidgetTester tester,
    List<ImportFile> files, {
    Map<String, Object> prefs = const {},
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en', ...prefs});
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImportDialog(
                context,
                pick: ({extensions}) async => files,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return app;
  }

  // The import writes to the database outside the fake clock: wait for
  // [done] in real time.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
  }

  bool dialogClosed() => find.text('Choose files').evaluate().isEmpty;

  testWidgets('a single imported song opens', (tester) async {
    final app = await start(tester, [plain]);
    final box = find.byKey(const Key('import-open-after'));
    expect(box, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(box).value, isTrue);

    await tester.tap(find.text('Choose files'));
    await waitFor(tester, () => find.byType(SongScreen).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.byType(SongScreen), findsOneWidget);
    expect(find.text('Plain'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('with the import report the song opens once it is closed', (
    tester,
  ) async {
    // Without a key: the report suggests one.
    final app = await start(tester, [
      file('g.cho', '{title: In G}\n[G]a [C]b [D]c [G]d'),
    ]);
    final report = find.byKey(const Key('import-problems'));
    await tester.tap(find.text('Choose files'));
    await waitFor(tester, () => report.evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.byType(SongScreen), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(report, findsNothing);
    expect(find.byType(SongScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('several imported songs do not open', (tester) async {
    final app = await start(tester, [plain, other]);
    await tester.tap(find.text('Choose files'));
    await waitFor(tester, dialogClosed);
    await tester.pumpAndSettle();
    expect(find.text('2 songs imported'), findsOneWidget);
    expect(find.byType(SongScreen), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('unticked, the song does not open and the choice is kept', (
    tester,
  ) async {
    final app = await start(tester, [plain]);
    final box = find.byKey(const Key('import-open-after'));
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(box).value, isFalse);
    final container = ProviderScope.containerOf(tester.element(box));
    expect(container.read(settingsProvider).openAfterImport, isFalse);

    await tester.tap(find.text('Choose files'));
    await waitFor(tester, dialogClosed);
    await tester.pumpAndSettle();
    expect(find.text('1 song imported'), findsOneWidget);
    expect(find.byType(SongScreen), findsNothing);

    // The next import dialog remembers it.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(box).value, isFalse);
    await app.dispose(tester);
  });

  test('the setting is personal and survives JSON', () {
    expect(AppSettings.scopes['openAfterImport'], SettingSyncScope.personal);
    expect(const AppSettings().openAfterImport, isTrue);
    final off = const AppSettings(openAfterImport: false).toJson();
    expect(AppSettings.fromJson(off).openAfterImport, isFalse);
  });
}
