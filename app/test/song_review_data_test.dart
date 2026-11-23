import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/organization_cleanup.dart';
import 'package:setding/data/outbox.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/data/song_review.dart';
import 'package:setding/data/trash.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

final _png = Uint8List.fromList(List.generate(64, (i) => i));

/// Song review status and mistake reports on the device and in the sync
/// (ADR-0060, #988).
void main() {
  late AppDatabase db;
  late Directory dir;
  late FileAttachmentStorage storage;
  late FakeSyncBackend server;
  late SyncEngine engine;
  late SongRepository songs;
  late SongReviewRepository review;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_review');
    storage = FileAttachmentStorage(dir);
    server = FakeSyncBackend(user: _ann);
    server.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    final bands = BandService(db, server);
    await bands.refresh();
    engine = SyncEngine(
      db,
      server,
      bands,
      copies: BandCopyService(db, storage),
      storage: storage,
    );
    songs = SongRepository(db, storage, libraryId: 'o1', userId: 'ann');
    review = SongReviewRepository(db, storage, userId: 'ann', backend: server);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<SongEntry> local(String id) =>
      (db.select(db.songs)..where((s) => s.id.equals(id))).getSingle();
  Future<SongReportRow> localReport(String id) =>
      (db.select(db.songReports)..where((r) => r.id.equals(id))).getSingle();
  Future<List<OutboxEntry>> outbox() => db.select(db.syncOutbox).get();

  Future<String> synced(String title) async {
    final id = await songs.createSong(source: '{title: $title}\n[G]La');
    await engine.sync();
    return id;
  }

  group('review status', () {
    test('to review and approved, by whom, with an outbox entry', () async {
      final id = await songs.createSong(source: '{title: A}');
      await review.setToReview(id, reason: '  After import  ');
      var song = await local(id);
      expect(song.reviewState, songToReview);
      expect(song.reviewReason, 'After import');
      expect(song.reviewedBy, 'ann');
      expect(song.reviewedAt, isNotNull);
      expect(
        (await outbox()).map((o) => (o.collection, o.recordId)),
        contains((SyncCollection.songReview, id)),
      );
      await review.approve(id);
      song = await local(id);
      expect(song.reviewState, isNull);
      expect(song.reviewReason, isNull, reason: 'no reason when approved');
    });

    test('the local library stays on the device', () async {
      final local = SongRepository(db, storage);
      final id = await local.createSong(source: '{title: L}');
      final localReview = SongReviewRepository(db, storage, userId: 'ann');
      await localReview.setToReview(id, reason: 'Check');
      await localReview.report(id, category: SongReportCategory.lyrics);
      expect(await outbox(), isEmpty);
      final row = await (db.select(
        db.songs,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(row.reviewedBy, localOwnerId);
    });

    test('a new song is created with its review status', () async {
      final id = await songs.createSong(source: '{title: A}');
      await review.setToReview(id, reason: 'After import');
      await engine.sync();
      expect(server.songs[id]!.reviewState, songToReview);
      expect(server.songs[id]!.reviewReason, 'After import');
      // Sent with the create; pushed again in the same run at most with
      // the same value (as the link fields of ADR-0053).
      expect(
        server.songReviewPushes,
        everyElement((id, songToReview, 'After import')),
      );
      expect((await local(id)).reviewedBy, 'ann');
      expect(await outbox(), isEmpty);
    });

    test('approving a synced song pushes only the review status, and the '
        'next text change is no conflict', () async {
      final id = await synced('A');
      server.putSongReview(id, songToReview, 'After import', by: 'bob');
      await engine.sync();
      expect((await local(id)).reviewState, songToReview);
      expect((await local(id)).reviewedBy, 'bob');

      final content = server.songs[id]!.contentRevision;
      await review.approve(id);
      await engine.sync();
      expect(server.songReviewPushes, [(id, null, null)]);
      expect(server.songs[id]!.reviewState, isNull);
      expect(server.songs[id]!.contentRevision, content);
      expect((await local(id)).revision, server.songs[id]!.revision);

      await songs.updateSource(id, '{title: A}\n[C]Changed');
      await engine.sync();
      expect(await db.select(db.songConflicts).get(), isEmpty);
      expect(server.songs[id]!.chordpro, contains('Changed'));
    });

    test('a local review status survives a pull of someone else\'s', () async {
      final id = await synced('A');
      await review.setToReview(id, reason: 'Mine');
      server.putSongReview(id, null, null, by: 'bob');
      server.putSong(
        RemoteSong(
          id: id,
          organizationId: 'o1',
          title: 'A',
          chordpro: '{title: A}\n[D]Theirs',
        ),
        by: 'bob',
      );
      await engine.sync();
      expect((await local(id)).chordproSource, contains('Theirs'));
      expect((await local(id)).reviewReason, 'Mine');
      expect(server.songs[id]!.reviewReason, 'Mine', reason: 'last writer');
    });

    test('a refused review change stays local and is not retried', () async {
      final id = await synced('A');
      server.refuseReview = true;
      await review.setToReview(id, reason: 'x');
      await engine.sync();
      expect(await outbox(), isEmpty);
      expect(server.songs[id]!.reviewState, isNull);
    });

    test('approve all, and undo', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      await review.setToReview(a, reason: 'After import');
      await review.setToReview(b, reason: 'Bridge');
      final before = await review.approveAll([a, b]);
      expect((await local(a)).reviewState, isNull);
      expect((await local(b)).reviewState, isNull);
      await review.restoreReview(before);
      expect((await local(a)).reviewReason, 'After import');
      expect((await local(b)).reviewReason, 'Bridge');
    });
  });

  group('reports', () {
    test('a report with a screenshot is stored and created on the server '
        'with it', () async {
      final id = await synced('A');
      final r = await review.report(
        id,
        category: SongReportCategory.chords,
        comment: 'Bar 3 is Em',
        location: const SongReportLocation(section: 'Verse 1', page: 2),
        screenshot: _png,
      );
      final row = await localReport(r);
      expect(row.authorId, 'ann');
      expect(row.statusValue, SongReportStatus.open);
      expect(row.locationValue?.section, 'Verse 1');
      expect(await storage.exists(row.screenshotFile!), isTrue);
      expect(await review.watchCounts('o1').first, (toReview: 0, reported: 1));

      await engine.sync();
      final stored = server.reports[r]!;
      expect(stored.comment, 'Bar 3 is Em');
      expect(stored.location?['page'], 2);
      expect(server.screenshots[stored.screenshot], _png);
      expect((await localReport(r)).remoteScreenshot, stored.screenshot);
      expect(await outbox(), isEmpty);
    });

    test('reports of a song not on the server yet wait for it', () async {
      final id = await songs.createSong(source: '{title: New}');
      final r = await review.report(id, category: SongReportCategory.key);
      await engine.sync();
      expect(server.songs, contains(id));
      expect(server.reports, contains(r));
    });

    test('a screenshot that did not reach the server is added later', () async {
      final id = await synced('A');
      final r = await review.report(id, category: SongReportCategory.other);
      await engine.sync();
      expect(server.reports[r]!.screenshot, isNull);
      // E.g. a report created before the screenshot was stored.
      await storage.write('report-$r.webp', _png);
      await (db.update(db.songReports)..where((x) => x.id.equals(r))).write(
        SongReportsCompanion(screenshotFile: Value('report-$r.webp')),
      );
      await review.updateReport(r, comment: 'With picture');
      await engine.sync();
      expect(server.reports[r]!.screenshot, isNotNull);
      expect(server.reportPushes.last.$5, isTrue);
    });

    test('the author withdraws; the approver resolves with an answer, '
        'sending only their part', () async {
      final id = await synced('A');
      final mine = await review.report(id, category: SongReportCategory.lyrics);
      await engine.sync();
      await review.withdraw(mine);
      await engine.sync();
      expect(server.reports[mine]!.status, 'withdrawn');
      expect(server.reportPushes.last.$3, isTrue, reason: 'as author');

      // Bob's report, pulled and resolved by Ann.
      server.putReport(
        RemoteSongReport(
          id: 'r-bob',
          songId: id,
          organizationId: 'o1',
          authorId: 'bob',
          category: 'chords',
          comment: 'Wrong',
        ),
      );
      await engine.sync();
      expect((await localReport('r-bob')).authorId, 'bob');
      await review.resolve('r-bob', resolution: 'Fixed, thanks');
      await engine.sync();
      final push = server.reportPushes.last;
      expect((push.$3, push.$4), (false, true));
      expect(server.reports['r-bob']!.status, 'resolved');
      expect(server.reports['r-bob']!.resolution, 'Fixed, thanks');
      expect(server.reports['r-bob']!.comment, 'Wrong');
      expect((await localReport('r-bob')).resolvedBy, 'ann');
    });

    test('a refused change gives way to the server version', () async {
      final id = await synced('A');
      server.putReport(
        RemoteSongReport(
          id: 'r1',
          songId: id,
          organizationId: 'o1',
          authorId: 'bob',
          category: 'chords',
          comment: 'Theirs',
        ),
      );
      await engine.sync();
      server.refuseReportUpdates = true;
      await review.resolve('r1', resolution: 'No');
      await engine.sync();
      expect(await outbox(), isEmpty);
      // The next run takes the server's version back.
      await engine.sync();
      final row = await localReport('r1');
      expect(row.statusValue, SongReportStatus.open);
      expect(row.resolution, isNull);
    });

    test('a pull keeps a pending local change', () async {
      final id = await synced('A');
      final r = await review.report(id, category: SongReportCategory.tempo);
      await engine.sync();
      await review.updateReport(r, comment: 'Mine');
      final s = server.reports[r]!;
      server.putReport(
        RemoteSongReport(
          id: r,
          songId: id,
          organizationId: 'o1',
          category: s.category,
          comment: 'Server',
        ),
      );
      await engine.sync();
      expect((await localReport(r)).comment, 'Mine');
      expect(server.reports[r]!.comment, 'Mine');
    });

    test('a screenshot is downloaded once when it is opened', () async {
      final id = await synced('A');
      server.putReport(
        RemoteSongReport(
          id: 'r2',
          songId: id,
          organizationId: 'o1',
          authorId: 'bob',
          category: 'other',
        ),
        screenshot: _png,
      );
      await engine.sync();
      final row = await localReport('r2');
      expect(row.screenshotFile, isNull, reason: 'not downloaded by the sync');
      expect(await review.screenshot(row), _png);
      final again = await localReport('r2');
      expect(await storage.exists(again.screenshotFile!), isTrue);
      expect(await review.screenshot(again), _png);
    });

    test('a purged report loses its screenshot on this device', () async {
      final id = await synced('A');
      final r = await review.report(
        id,
        category: SongReportCategory.other,
        screenshot: _png,
      );
      await engine.sync();
      final file = (await localReport(r)).screenshotFile!;
      final s = server.reports[r]!;
      server.putReport(
        RemoteSongReport(
          id: r,
          songId: id,
          organizationId: 'o1',
          category: s.category,
          deleted: true,
          purged: true,
        ),
      );
      await engine.sync();
      final row = await localReport(r);
      expect(row.purged, isTrue);
      expect(row.screenshotFile, isNull);
      expect(await storage.exists(file), isFalse);
    });

    test('approving with resolving the open reports', () async {
      final id = await songs.createSong(source: '{title: A}');
      await review.setToReview(id, reason: 'After import');
      final r = await review.report(id, category: SongReportCategory.chords);
      await review.approve(id, resolveReports: true, resolution: 'Checked');
      expect((await local(id)).reviewState, isNull);
      final row = await localReport(r);
      expect(row.statusValue, SongReportStatus.resolved);
      expect(row.resolution, 'Checked');
      expect(await review.watchCounts('o1').first, (toReview: 0, reported: 0));
      await review.reopen(r);
      expect((await localReport(r)).resolvedBy, isNull);
    });
  });

  group('removal and archives', () {
    test(
      'purging the local trash removes the reports and screenshots',
      () async {
        final localSongs = SongRepository(db, storage);
        final localReview = SongReviewRepository(db, storage);
        final id = await localSongs.createSong(source: '{title: Old}');
        final r = await localReview.report(
          id,
          category: SongReportCategory.other,
          screenshot: _png,
        );
        final file = (await localReport(r)).screenshotFile!;
        await localSongs.deleteSong(id);
        await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
          SongsCompanion(deletedAt: Value(DateTime(2000))),
        );
        await TrashRepository(db, storage).purgeLocal();
        expect(await db.select(db.songReports).get(), isEmpty);
        expect(await storage.exists(file), isFalse);
      },
    );

    test('removing an organization removes its reports', () async {
      final id = await synced('A');
      final r = await review.report(
        id,
        category: SongReportCategory.other,
        screenshot: _png,
      );
      final file = (await localReport(r)).screenshotFile!;
      await removeOrganizationData(db, 'o1', storage: storage);
      expect(await db.select(db.songReports).get(), isEmpty);
      expect(await outbox(), isEmpty);
      expect(await storage.exists(file), isFalse);
    });

    test('archives carry the review status', () async {
      final id = await songs.createSong(source: '{title: A}');
      await review.setToReview(id, reason: 'Bridge');
      expect(BackupService.songFieldsJson(await local(id)), {
        'reviewState': songToReview,
        'reviewReason': 'Bridge',
      });
      final copy = await SongRepository(
        db,
        storage,
      ).createSong(source: '{title: Copy}');
      await BackupService.restoreReview(
        SongRepository(db, storage),
        copy,
        BackupService.songFieldsJson(await local(id)),
      );
      expect((await local(copy)).reviewReason, 'Bridge');
      final approved = await SongRepository(
        db,
        storage,
      ).createSong(source: '{title: Approved}');
      await BackupService.restoreReview(
        SongRepository(db, storage),
        approved,
        const {},
      );
      expect((await local(approved)).reviewState, isNull);
    });
  });
}
