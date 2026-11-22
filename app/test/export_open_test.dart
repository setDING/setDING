import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/widgets/export_file.dart';
import 'package:setding/ui/sets/set_screen.dart';

import 'test_app.dart';

/// "Open" in the message after a PDF export (#721, ADR-0048).
void main() {
  /// The PDF is built outside the fake clock (fonts, isolates): waits for
  /// [done] in real time.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue);
    await tester.pump();
  }

  Future<(TestApp, List<(String, Uint8List, String)>)> exportPdf(
    WidgetTester tester, {
    bool openSucceeds = true,
  }) async {
    useTabletSize(tester);
    final saved = <(String, Uint8List)>[];
    final opened = <(String, Uint8List, String)>[];
    final app = await TestApp.create(prefs: {'language': 'en'});
    final setId = (await tester.runAsync(() async {
      final song = await app.songs.createSong(source: '{title: Hello}\n[C]x');
      final set = await app.sets.createSet(name: 'Gig');
      await app.sets.addSongs(set, [song]);
      return set;
    }))!;
    await tester.pumpWidget(
      app.build(
        home: SetScreen(setId: setId),
        extra: [
          saveFileProvider.overrideWithValue((
            name,
            bytes, {
            mimeType = '',
          }) async {
            saved.add((name, bytes));
            return true;
          }),
          openFileProvider.overrideWithValue((
            name,
            bytes, {
            required mimeType,
          }) async {
            opened.add((name, bytes, mimeType));
            return openSucceeds;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export …'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-export-start')));
    await waitFor(tester, () => saved.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(saved.single.$1, 'Gig.pdf');
    return (app, opened);
  }

  testWidgets('the exported PDF opens from the message', (tester) async {
    final (app, opened) = await exportPdf(tester);
    expect(find.text('Exported'), findsOneWidget);
    expect(opened, isEmpty);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Open'));
    await tester.pump();
    expect(opened.single.$1, 'Gig.pdf');
    expect(opened.single.$3, 'application/pdf');
    // The same bytes that were saved: a PDF.
    expect(String.fromCharCodes(opened.single.$2.take(4)), '%PDF');
    await tester.pumpAndSettle();
    expect(find.text('No app could open the file.'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a file no app can open is reported', (tester) async {
    final (app, _) = await exportPdf(tester, openSucceeds: false);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Open'));
    await tester.pumpAndSettle();
    expect(find.text('No app could open the file.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the message with "Open" goes away on its own', (tester) async {
    final (app, _) = await exportPdf(tester);
    expect(find.text('Exported'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Exported'), findsNothing);
    await app.dispose(tester);
  });
}
