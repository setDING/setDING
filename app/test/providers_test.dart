import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/providers.dart';
import 'package:realchord/ui/songs/songs_screen.dart';

import 'test_app.dart';

void main() {
  test('family providers are disposed when no longer listened to', () async {
    final app = await TestApp.create();
    final container = ProviderContainer(overrides: app.overrides);
    addTearDown(() async {
      container.dispose();
      await app.db.close();
      app.dir.deleteSync(recursive: true);
    });
    final id = await app.songs.createSong(source: '{title: One}');

    final providers = [
      songProvider(id),
      songsProvider((query: 'on', tag: null)),
      overlayProvider(id),
      attachmentsProvider(id),
    ];
    for (final provider in providers) {
      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(container.read(provider.exists), isTrue);
      sub.close();
      await container.pump();
      expect(container.read(provider.exists), isFalse, reason: '$provider');
    }
  });

  testWidgets('song search applies the text after a short delay', (
    tester,
  ) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'});
    await tester.runAsync(() async {
      await app.songs.createSong(source: '{title: Late Train Home}');
      await app.songs.createSong(source: '{title: Morning Song}');
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs').first);
    await tester.pumpAndSettle();
    expect(find.text('Morning Song'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(TextField),
      ),
      'train',
    );
    await tester.pump(const Duration(milliseconds: 50));
    // Not applied yet while typing.
    expect(find.text('Morning Song'), findsOneWidget);

    await tester.pump(songSearchDelay);
    await tester.pumpAndSettle();
    expect(find.text('Late Train Home'), findsOneWidget);
    expect(find.text('Morning Song'), findsNothing);
    await app.dispose(tester);
  });
}
