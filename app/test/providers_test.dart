import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:realchord/data/database.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/providers.dart';
import 'package:realchord/sync/auth_providers.dart';
import 'package:realchord/sync/sync_backend.dart';
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

  test('the first user signed in takes over local adjustments once', () async {
    final app = await TestApp.create(
      user: const AuthUser(id: 'ann', email: 'a@x.test', name: 'Ann'),
    );
    addTearDown(() async {
      await app.db.close();
      app.dir.deleteSync(recursive: true);
    });
    final org = SongRepository(app.db, app.storage, libraryId: 'o1');
    final first = await org.createSong(source: '{title: One}');
    final second = await org.createSong(source: '{title: Two}');
    Future<void> localOverlay(String id) => app.db
        .into(app.db.personalOverlays)
        .insert(
          PersonalOverlaysCompanion.insert(songId: id, capo: const Value(4)),
        );
    Future<String> owner(String id) async => (await (app.db.select(
      app.db.personalOverlays,
    )..where((o) => o.songId.equals(id))).getSingle()).ownerId;

    await localOverlay(first);
    var container = ProviderContainer(overrides: app.overrides);
    container.read(authProvider);
    await pumpEventQueue(times: 20);
    expect(await owner(first), 'ann');
    container.dispose();

    // Later local adjustments (e.g. from an older backup) are not taken.
    await localOverlay(second);
    container = ProviderContainer(overrides: app.overrides);
    container.read(authProvider);
    await pumpEventQueue(times: 20);
    expect(await owner(second), localOwnerId);
    container.dispose();
  });
}
