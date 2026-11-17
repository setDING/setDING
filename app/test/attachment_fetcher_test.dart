import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_memory.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/attachment_fetcher.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// The web client loads PDF attachments when they are opened instead of
/// preloading them (ADR-0018).
void main() {
  late AppDatabase db;
  late FakeSyncBackend server;
  late MemoryAttachmentStorage storage;
  late SyncEngine engine;
  late AttachmentFetcher fetcher;
  final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    storage = MemoryAttachmentStorage();
    server = FakeSyncBackend(user: _ann);
    server.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    final bands = BandService(db, server);
    await bands.refresh();
    engine = SyncEngine(
      db,
      server,
      bands,
      storage: storage,
      preloadAttachments: false,
    );
    fetcher = AttachmentFetcher(db, server, storage);
    server.putSong(
      const RemoteSong(
        id: 's1',
        organizationId: 'o1',
        title: 'Song',
        chordpro: '{title: Song}',
      ),
    );
    server.putAttachment(
      const RemoteAttachment(
        id: 'a1',
        organizationId: 'o1',
        songId: 's1',
        name: 'Lead sheet',
        sizeBytes: 13,
      ),
      bytes: pdf,
    );
  });
  tearDown(() => db.close());

  Future<String> localFileName() async =>
      (await SongRepository(db, storage, libraryId: 'o1').getAttachments('s1'))
          .single
          .fileName;

  test('the sync does not download attachment files', () async {
    final report = await engine.sync();
    expect(report.error, isNull);
    expect(report.downloaded, 0);
    expect(server.downloads, 0);
    expect(await storage.exists(await localFileName()), isFalse);
  });

  test('opening an attachment downloads it once', () async {
    await engine.sync();
    final results = await Future.wait([
      fetcher.fetch('a1'),
      fetcher.fetch('a1'),
    ]);
    expect(server.downloads, 1, reason: 'concurrent calls share a download');
    expect(await results.first!.readAsBytes(), pdf);
    expect(results.first!.name, await localFileName());

    // Stored now: opened again without a download.
    expect(await (await fetcher.fetch('a1'))!.readAsBytes(), pdf);
    expect(server.downloads, 1);
  });

  test('a failed download leaves nothing behind and can be retried', () async {
    await engine.sync();
    final remoteFile = server.attachments['a1']!.file!;
    server.offlineFiles.add(remoteFile);
    await expectLater(
      fetcher.fetch('a1'),
      throwsA(
        isA<BackendException>().having(
          (e) => e.kind,
          'kind',
          BackendErrorKind.network,
        ),
      ),
    );
    expect(await storage.exists(await localFileName()), isFalse);

    server.offlineFiles.clear();
    expect(await (await fetcher.fetch('a1'))!.readAsBytes(), pdf);
  });

  test('unknown attachments and files not uploaded yet give null', () async {
    await engine.sync();
    expect(await fetcher.fetch('nope'), isNull);

    final songs = SongRepository(db, storage, libraryId: 'o1', userId: 'ann');
    final id = await songs.createSong(source: '{title: Local}');
    final added = await songs.addAttachment(id, name: 'New', bytes: pdf);
    // Added in this browser: stored, not on the server yet.
    expect(await (await fetcher.fetch(added))!.readAsBytes(), pdf);
    await storage.deleteAll();
    expect(await fetcher.fetch(added), isNull);
  });
}
