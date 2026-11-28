import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/database.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/organization_screen.dart';
import 'package:setding/ui/songs/song_screen.dart';
import 'package:setding/ui/songs/storage_usage.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');
const _mb = 1024 * 1024;

/// The storage limit per organization in the app (ADR-0070): the maximum
/// size and the free storage before a file is picked, the usage for those
/// who upload, and the refusal of a file that is too large or does not fit.
void main() {
  group('checkAttachment', () {
    const storage = OrgStorage(usedBytes: 24 * _mb, limitBytes: 25 * _mb);

    test('a PDF over 1 MB is too large, also offline', () {
      expect(checkAttachment('a.pdf', _mb), AttachmentCheck.ok);
      expect(checkAttachment('a.pdf', _mb + 1), AttachmentCheck.tooLarge);
      expect(
        checkAttachment('a.PDF', _mb + 1, storage: storage),
        AttachmentCheck.tooLarge,
      );
      // Images stay on the device (ADR-0012) and may be larger.
      expect(checkAttachment('a.png', 2 * _mb), AttachmentCheck.ok);
      expect(
        checkAttachment('a.png', maxAttachmentBytes + 1),
        AttachmentCheck.tooLarge,
      );
    });

    test('a PDF that does not fit any more, with the ones picked before', () {
      expect(
        checkAttachment('a.pdf', 900 * 1024, storage: storage),
        AttachmentCheck.ok,
      );
      expect(
        checkAttachment('a.pdf', 900 * 1024, storage: storage, added: _mb ~/ 2),
        AttachmentCheck.doesNotFit,
      );
      // Images do not count against the storage.
      expect(
        checkAttachment('a.png', 2 * _mb, storage: storage),
        AttachmentCheck.ok,
      );
      // Without a limit, everything fits.
      expect(
        checkAttachment(
          'a.pdf',
          _mb,
          storage: const OrgStorage(usedBytes: 99 * _mb, limitBytes: null),
        ),
        AttachmentCheck.ok,
      );
    });
  });

  test('OrgStorage: free storage and the warning from 90 %', () {
    const s = OrgStorage(usedBytes: 22 * _mb, limitBytes: 25 * _mb);
    expect(s.freeBytes, 3 * _mb);
    expect(s.nearlyFull, isFalse);
    expect(
      const OrgStorage(usedBytes: 23 * _mb, limitBytes: 25 * _mb).nearlyFull,
      isTrue,
    );
    // Over the limit (the operator lowered it): nothing free.
    expect(
      const OrgStorage(usedBytes: 30 * _mb, limitBytes: 25 * _mb).freeBytes,
      0,
    );
    expect(const OrgStorage(usedBytes: 1, limitBytes: null).freeBytes, isNull);
    expect(formatLimit(_mb), '1 MB');
    expect(formatLimit(25 * _mb), '25 MB');
  });

  Future<TestApp> start(WidgetTester tester, AuthUser user) async {
    useTabletSize(tester);
    final app = await TestApp.create(
      prefs: {'language': 'en', 'currentBandId': 'b1'},
      user: user,
    );
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.organizations['o1'] = 'School';
    return app;
  }

  Future<String> songWithPdf(TestApp app, WidgetTester tester, int size) async {
    final songs = TestApp.songsIn(app, 'o1', userId: 'ann');
    final id = await songs.createSong(source: '{title: Song}\n[C]One');
    await tester.runAsync(
      () => songs.addAttachment(
        id,
        name: 'Score',
        bytes: Uint8List.fromList([
          ...'%PDF-1.4'.codeUnits,
          ...List.filled(size - 8, 32),
        ]),
      ),
    );
    return id;
  }

  testWidgets('the attachments show the maximum size and the free storage '
      'before a file is picked', (tester) async {
    final app = await start(tester, _ann);
    app.backend.storageLimitBytes = 25 * _mb;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pumpAndSettle();
    final song = await songWithPdf(app, tester, 600 * 1024);
    await syncNow(tester);
    await tester.pumpWidget(app.build(home: SongScreen(songId: song)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-attachments')));
    await tester.pumpAndSettle();
    expect(
      find.text('PDF, at most 1 MB · 24.4 MB of 25 MB free'),
      findsOneWidget,
    );
    expect(find.textContaining('nearly full'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('members who cannot upload see neither the hint nor the usage', (
    tester,
  ) async {
    final app = await start(tester, _bob);
    app.backend.addMember('b1', _bob, BandRole.member);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pumpWidget(
      app.build(home: const OrganizationScreen(organizationId: 'o1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-storage')), findsNothing);
    expect(app.backend.fetchOrgStorageCalls, 0);
    await app.dispose(tester);
  });

  testWidgets('the organization screen shows the usage with a warning from '
      '90 % and leads to the trash', (tester) async {
    final app = await start(tester, _ann);
    app.backend.storageLimitBytes = _mb;
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pumpAndSettle();
    await songWithPdf(app, tester, 950 * 1024);
    await syncNow(tester);
    await tester.pumpWidget(
      app.build(home: const OrganizationScreen(organizationId: 'o1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Storage: 950 KB of 1 MB'), findsOneWidget);
    expect(
      find.text(
        'The organization\'s storage is nearly full. Deleted PDFs count '
        'until they are deleted permanently.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('org-storage')));
    await tester.pumpAndSettle();
    expect(find.text('Deleted songs'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a refusal for a full storage names it (ADR-0070)', (
    tester,
  ) async {
    final app = await start(tester, _ann);
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    await syncNow(tester);
    await tester.pumpAndSettle();
    app.backend.storageLimitBytes = 1000;
    await songWithPdf(app, tester, 2000);
    await syncNow(tester);
    await tester.pump();
    expect(
      find.text(
        'The server did not accept “Score” of “Song” (the organization\'s '
        'storage is full). The attachment stays on this device only.',
      ),
      findsOneWidget,
    );
    final row = (await tester.runAsync(
      () => app.db.select(app.db.attachments).getSingle(),
    ))!;
    expect(row.uploadRefused, UploadRefusal.storageFull);
    await tester.pump(const Duration(seconds: 11));
    await app.dispose(tester);
  });
}
