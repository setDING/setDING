import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/backup.dart' show BackupFileMissingException;
import 'package:setding/ui/widgets/export_file.dart';

import 'test_app.dart';

/// The shared export flow: save, message, errors (#745).
void main() {
  Future<(TestApp, List<String>)> pumpExport(
    WidgetTester tester, {
    required Future<Uint8List> Function() build,
    bool saveSucceeds = true,
  }) async {
    final saved = <String>[];
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.pumpWidget(
      app.build(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => exportFile(
                context,
                ref,
                fileName: 'song.cho',
                mimeType: 'text/plain',
                build: build,
              ),
              child: const Text('export'),
            ),
          ),
        ),
        extra: [
          saveFileProvider.overrideWithValue((
            name,
            bytes, {
            mimeType = '',
          }) async {
            if (saveSucceeds) saved.add(name);
            return saveSucceeds;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('export'));
    await tester.pumpAndSettle();
    return (app, saved);
  }

  testWidgets('a saved file is reported without "Open"', (tester) async {
    final (app, saved) = await pumpExport(
      tester,
      build: () async => Uint8List.fromList([1, 2, 3]),
    );
    expect(saved, ['song.cho']);
    expect(find.text('Exported'), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a cancelled save shows nothing', (tester) async {
    final (app, saved) = await pumpExport(
      tester,
      build: () async => Uint8List(0),
      saveSucceeds: false,
    );
    expect(saved, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a failure is shown as a message', (tester) async {
    final (app, saved) = await pumpExport(
      tester,
      build: () async => throw StateError('broken'),
    );
    expect(saved, isEmpty);
    expect(
      find.text('Something went wrong: Bad state: broken'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('a missing attachment names the file and the song', (
    tester,
  ) async {
    final (app, _) = await pumpExport(
      tester,
      build: () async =>
          throw const BackupFileMissingException('Hello', 'chart.pdf'),
    );
    expect(
      find.text('The attachment "chart.pdf" of "Hello" could not be loaded.'),
      findsOneWidget,
    );
    await app.dispose(tester);
  });
}
