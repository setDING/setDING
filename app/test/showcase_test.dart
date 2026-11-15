import 'dart:io';

import 'package:archive/archive.dart';
import 'package:realchord/data/import_export.dart';
import 'package:realchord/ui/live/live_screen.dart';
import 'package:realchord/ui/render/abc_view.dart';
import 'package:realchord/ui/render/chord_diagram.dart';
import 'package:realchord/ui/render/song_grid.dart';
import 'package:realchord/ui/songs/song_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// Regression test for docs/examples (feature-showcase.cho/.zip): the
/// example with every supported ChordPro feature imports and renders
/// without errors.
void main() {
  const examples = '../docs/examples';

  test('the ZIP contains the current example files', () {
    final zip = ZipDecoder().decodeBytes(
      File('$examples/feature-showcase.zip').readAsBytesSync(),
    );
    for (final name in ['feature-showcase.cho', 'stage-plan.svg']) {
      final entry = zip.files.firstWhere((f) => f.name == name);
      expect(
        entry.content,
        File('$examples/$name').readAsBytesSync(),
        reason: '$name changed: run "make examples" to update the ZIP',
      );
    }
  });

  testWidgets('imports and renders the feature showcase', (tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'instrument': 'guitar', 'diagrams': 'bottom'},
    );
    final ids = await tester.runAsync(() async {
      final bytes = Uint8List.fromList(
        File('$examples/feature-showcase.zip').readAsBytesSync(),
      );
      final result = await ImportExportService(
        app.songs,
        app.sets,
      ).importFiles([ImportFile('feature-showcase.zip', bytes)]);
      expect(result.imported, 2);
      final songs = await app.db.select(app.db.songs).get();
      final showcase = songs.firstWhere((s) => s.title == 'Feature Showcase');
      final attachments = await app.songs.getAttachments(showcase.id);
      expect(attachments.single.name, 'stage-plan.svg');
      return [for (final s in songs) s.id];
    });

    // Song screen.
    final showcaseId = await tester.runAsync(() async {
      final songs = await app.db.select(app.db.songs).get();
      return songs.firstWhere((s) => s.title == 'Feature Showcase').id;
    });
    await tester.pumpWidget(app.build(home: SongScreen(songId: showcaseId!)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(GridRowView), findsWidgets);
    expect(find.byKey(const ValueKey('sequence-chip')), findsNWidgets(8));
    expect(find.byType(ChordDiagramView, skipOffstage: false), findsWidgets);
    expect(find.byType(AbcView, skipOffstage: false), findsOneWidget);
    expect(find.byType(SvgPicture, skipOffstage: false), findsNWidgets(2));
    expect(
      find.text('Shown only for guitar', skipOffstage: false),
      findsOneWidget,
    );

    // Live mode with both songs.
    final items = await tester.runAsync(
      () async => [
        for (final id in ids!) LiveItem.song((await app.songs.getSong(id))!),
      ],
    );
    await tester.pumpWidget(app.build(home: LiveScreen(items: items!)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });
}
