import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_app.dart';

/// The trash of ADR-0043: reached from the song and set lists, restores.
void main() {
  testWidgets('a deleted song is restored from the trash', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final id = await app.songs.createSong(source: '{title: Lost song}');
      await app.songs.deleteSong(id);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(find.text('Lost song'), findsNothing);

    await tester.tap(find.byKey(const Key('songs-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('songs-trash')));
    await tester.pumpAndSettle();
    expect(find.text('Deleted songs'), findsOneWidget);
    expect(find.text('Lost song'), findsOneWidget);
    expect(find.textContaining('30 days left'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('"Lost song" restored'), findsOneWidget);
    expect(find.textContaining('The trash is empty.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lost song'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a deleted set is restored from the trash', (tester) async {
    useTabletSize(tester, landscape: false);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      final id = await app.sets.createSet(name: 'Lost gig');
      await app.sets.deleteSet(id);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sets').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sets-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sets-trash')));
    await tester.pumpAndSettle();
    expect(find.text('Deleted sets'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lost gig'), findsOneWidget);
    await app.dispose(tester);
  });
}
