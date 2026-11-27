import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/auto_backup.dart';
import 'package:setding/data/band_providers.dart';
import 'package:setding/data/database.dart' show localBandId;
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/backup/full_backup.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/settings_screen.dart';

import 'test_app.dart';

const _ann = AuthUser(
  id: 'u-ann@example.test',
  email: 'ann@example.test',
  name: 'Ann',
);

/// Hiding the local library (ADR-0054 section 3).
void main() {
  Future<TestApp> start(
    WidgetTester tester, {
    AuthUser? user,
    Map<String, Object> prefs = const {},
  }) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', ...prefs},
      user: user,
    );
    app.backend.addBand('b1', 'The Band', admin: _ann);
    await tester.runAsync(() => app.songs.createSong(source: '{title: Mine}'));
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

  Future<void> openStorage(WidgetTester tester) async {
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await openSettingsCategory(tester, SettingsCategory.about);
  }

  testWidgets('switched off while signed in, it is hidden everywhere but '
      'stays on the device and in the full backup', (tester) async {
    final app = await start(
      tester,
      user: _ann,
      prefs: {
        // On, without a folder: nothing runs at the start.
        AutoBackupController.enabledKey: true,
      },
    );
    final c = container(tester);
    // Kept alive, as the full backup reads it.
    final all = c.listen(allLibrariesProvider, (_, _) {});
    await tester.pumpAndSettle();
    expect(
      c.read(librariesProvider).value!.map((l) => l.id),
      contains(localBandId),
    );

    await openStorage(tester);
    final tile = find.byKey(const Key('settings-show-local-library'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byKey(const Key('local-library-hidden')), findsOneWidget);
    expect(find.textContaining('1 song and 0 sets stay'), findsOneWidget);
    expect(
      find.textContaining('automatic backup keeps running'),
      findsOneWidget,
    );
    expect(c.read(settingsProvider).showLocalLibrary, isFalse);
    expect(c.read(localLibraryShownProvider), isFalse);
    await tester.pumpAndSettle();

    // Not in the lists of libraries and bands; the organization is current.
    expect(c.read(librariesProvider).value!.map((l) => l.id), ['org-b1']);
    expect(c.read(bandsProvider).value!.map((b) => b.id), ['b1']);
    expect(c.read(currentLibraryProvider).id, 'org-b1');
    expect(c.read(currentBandProvider).id, 'b1');
    // Still on the device, and in the full backup.
    expect(all.read().value!.map((l) => l.id), contains(localBandId));
    expect(
      await tester.runAsync(() => app.db.select(app.db.songs).get()),
      hasLength(1),
    );
    // No reminder of a backup while it is hidden.
    expect(await c.read(backupReminderProvider.future), isNull);

    // Shown again.
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(
      c.read(librariesProvider).value!.map((l) => l.id),
      contains(localBandId),
    );
    await app.dispose(tester);
  });

  testWidgets('signed out, it is always shown and cannot be switched off', (
    tester,
  ) async {
    final app = await start(tester, prefs: {'showLocalLibrary': false});
    final c = container(tester);
    expect(c.read(localLibraryShownProvider), isTrue);
    expect(c.read(currentLibraryProvider).id, localBandId);
    await openStorage(tester);
    final tile = find.byKey(const Key('settings-show-local-library'));
    await tester.ensureVisible(tile);
    final widget = tester.widget<SwitchListTile>(tile);
    expect(widget.value, isTrue);
    expect(widget.onChanged, isNull);
    expect(
      find.text('Signed out, the local library is always shown.'),
      findsOneWidget,
    );
    // The setting stays as it is.
    expect(c.read(settingsProvider).showLocalLibrary, isFalse);
    await app.dispose(tester);
  });
}
