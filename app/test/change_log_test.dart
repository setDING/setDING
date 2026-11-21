import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/change_log.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/engine/arrangement_sync.dart';
import 'package:setding/sync/engine/change_recorder.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

RemoteSetItem _song(String id, String songId, {String? sequence}) =>
    RemoteSetItem(
      id: id,
      type: SetItemType.song,
      songId: songId,
      sequence: sequence,
    );

/// [diffSetItems] as a comparable record.
(int, int, String) _diff(
  List<RemoteSetItem> before,
  List<RemoteSetItem> after, {
  bool Function(String songId)? songExists,
}) {
  final d = diffSetItems(before, after, songExists: songExists);
  return (d.added, d.removed, d.sequenceSongIds.join(','));
}

/// The local change log of the recent changes (ADR-0045).
void main() {
  group('diffSetItems', () {
    test('counts songs added and removed, not a reordering', () {
      final before = [_song('1', 'a'), _song('2', 'b'), _song('3', 'c')];
      expect(
        _diff(before, [_song('3', 'c'), _song('1', 'a'), _song('2', 'b')]),
        (0, 0, ''),
      );
      expect(
        _diff(before, [
          _song('1', 'a'),
          _song('4', 'd'),
          _song('5', 'e'),
          const RemoteSetItem(
            id: '6',
            type: SetItemType.marker,
            icon: MarkerIcons.breakIcon,
          ),
        ]),
        (2, 2, ''),
      );
      // The same song twice counts twice.
      expect(_diff(before, [...before, _song('7', 'a')]), (1, 0, ''));
    });

    test('finds a changed sequence by item, otherwise by song', () {
      final before = [
        _song('1', 'a', sequence: 'V, C'),
        _song('2', 'b'),
        _song('3', 'a'),
      ];
      expect(
        _diff(before, [
          _song('3', 'a'),
          _song('1', 'a', sequence: 'V, C, C'),
          _song('2', 'b'),
        ]),
        (0, 0, 'a'),
      );
      // Items without ID (older clients) are matched by their song.
      expect(
        _diff(
          [_song('x', 'b', sequence: 'V')],
          [_song('', 'b', sequence: 'C')],
        ),
        (0, 0, 'b'),
      );
      expect(_diff([_song('1', 'a')], [_song('1', 'a', sequence: '')]), (
        0,
        0,
        '',
      ), reason: 'no sequence and an empty one are the same');
    });

    test('songs not on this device do not count', () {
      expect(
        _diff(
          [_song('1', 'a')],
          [_song('1', 'a'), _song('2', 'missing')],
          songExists: (id) => id != 'missing',
        ),
        (0, 0, ''),
      );
    });
  });

  group('ChangeDetails and grouping', () {
    test('details survive the JSON and merge', () {
      const details = ChangeDetails(added: 2, removed: 1, sequences: ['A']);
      expect(ChangeDetails.fromJson(details.toJson()), details);
      expect(ChangeDetails.fromJson('nonsense'), const ChangeDetails());
      expect(ChangeDetails.fromJson('[1]'), const ChangeDetails());
      expect(
        details.merge(const ChangeDetails(added: 1, sequences: ['A', 'B'])),
        const ChangeDetails(added: 3, removed: 1, sequences: ['A', 'B']),
      );
    });

    test('one entry per song or set, a new song stays new', () {
      final t = DateTime(2026, 11, 20, 12);
      ChangeLogRow row(
        int id,
        ChangeKind kind,
        String record,
        int minutes, {
        String user = 'bob',
        ChangeDetails details = const ChangeDetails(),
      }) => ChangeLogRow(
        id: id,
        at: t.add(Duration(minutes: minutes)),
        kind: kind,
        scopeId: 'o1',
        recordId: record,
        title: '$record $id',
        userId: user,
        details: details.toJson(),
      );
      final grouped = groupChanges([
        row(
          4,
          ChangeKind.songChanged,
          's1',
          4,
          user: 'carol',
          details: const ChangeDetails(pdf: true),
        ),
        row(
          3,
          ChangeKind.setChanged,
          'set1',
          3,
          details: const ChangeDetails(added: 1),
        ),
        row(2, ChangeKind.songAdded, 's1', 2),
        row(
          1,
          ChangeKind.setChanged,
          'set1',
          1,
          details: const ChangeDetails(removed: 1),
        ),
      ]);
      expect(grouped, hasLength(2));
      final song = grouped.first;
      expect(
        (song.kind, song.title, song.userId, song.details),
        (ChangeKind.songAdded, 's1 4', 'carol', const ChangeDetails(pdf: true)),
      );
      expect(grouped.last.details, const ChangeDetails(added: 1, removed: 1));
    });
  });

  group('sync', () {
    late AppDatabase db;
    late Directory dir;
    late FakeSyncBackend server;
    late SyncEngine engine;
    late SongRepository songs;

    Future<List<ChangeLogRow>> log() => (db.select(
      db.changeLog,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();

    RemoteSong song(String id, String source) =>
        RemoteSong(id: id, organizationId: 'o1', title: id, chordpro: source);

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      dir = Directory.systemTemp.createTempSync('setding_change_log');
      final storage = FileAttachmentStorage(dir);
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
      songs = SongRepository(db, storage, libraryId: 'o1');
      // The library and the band were synced before.
      server.putSong(song('s1', '{title: One}\n[C]x'), by: 'bob');
      server.putSong(song('s2', '{title: Two}\n[G]y'), by: 'bob');
      server.putSet(
        RemoteSet(
          id: 'set1',
          bandId: 'b1',
          name: 'Gig',
          items: [_song('i1', 's1')],
        ),
        by: 'bob',
      );
      await engine.sync();
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('the first sync of a library logs nothing', () async {
      expect(await songs.getSong('s1'), isNotNull);
      expect(await log(), isEmpty);
    });

    test('logs new and changed songs of other people', () async {
      server.putSong(song('s3', '{title: Three}'), by: 'bob');
      server.putSong(song('s1', '{title: One}\n[D]changed'), by: 'carol');
      await engine.sync();
      final rows = await log();
      expect(
        [
          for (final r in rows)
            (r.kind, r.scopeId, r.recordId, r.title, r.userId),
        ],
        [
          (ChangeKind.songAdded, 'o1', 's3', 'Three', 'bob'),
          (ChangeKind.songChanged, 'o1', 's1', 'One', 'carol'),
        ],
      );
      expect(
        ChangeDetails.fromJson(rows.last.details),
        const ChangeDetails(text: true),
      );
    });

    test('own changes, also from other devices, and changes without an '
        'editor are not logged', () async {
      server.putSong(song('s1', '{title: One}\n[D]mine'), by: 'ann');
      server.putSong(song('s2', '{title: Two}\n[D]nobody'));
      await songs.updateSource('s1', '{title: One}\n[E]local');
      await engine.sync();
      expect(await log(), isEmpty);
    });

    test('a changed title alone, without a change of the text, is not '
        'logged; a deleted song neither', () async {
      server.putSong(song('s1', '{title: One}\n[C]x'), by: 'bob');
      server.putSong(
        RemoteSong(
          id: 's2',
          organizationId: 'o1',
          title: 's2',
          chordpro: '{title: Two}\n[G]y',
          deleted: true,
        ),
        by: 'bob',
      );
      await engine.sync();
      expect(await log(), isEmpty);
    });

    test('a PDF added, replaced or removed is a change of its song', () async {
      RemoteAttachment pdf({String file = 'a.pdf', String name = 'Score'}) =>
          RemoteAttachment(
            id: 'a1',
            organizationId: 'o1',
            songId: 's1',
            name: name,
            file: file,
          );
      server.putAttachment(pdf(), by: 'bob');
      await engine.sync();
      server.putAttachment(pdf(name: 'Renamed'), by: 'bob');
      await engine.sync();
      expect(await log(), hasLength(1), reason: 'a new name is no change');
      server.putAttachment(pdf(file: 'b.pdf'), by: 'carol');
      await engine.sync();
      server.putAttachment(
        RemoteAttachment(
          id: 'a1',
          organizationId: 'o1',
          songId: 's1',
          name: 'Score',
          file: 'b.pdf',
          deleted: true,
        ),
        by: 'bob',
      );
      await engine.sync();
      final rows = await log();
      expect(
        [for (final r in rows) (r.kind, r.recordId, r.title, r.userId)],
        [
          (ChangeKind.songChanged, 's1', 'One', 'bob'),
          (ChangeKind.songChanged, 's1', 'One', 'carol'),
          (ChangeKind.songChanged, 's1', 'One', 'bob'),
        ],
      );
      expect(rows.map((r) => ChangeDetails.fromJson(r.details)).toSet(), {
        const ChangeDetails(pdf: true),
      });
    });

    test('a new set by someone else is one entry, not its songs added '
        '(#674)', () async {
      // The band was synced before (setUp), so its sets are logged.
      server.putSet(
        RemoteSet(
          id: 'set2',
          bandId: 'b1',
          name: 'Rehearsal',
          items: [_song('i1', 's1'), _song('i2', 's2')],
        ),
        by: 'carol',
      );
      await engine.sync();
      final row = (await log()).single;
      expect(
        (row.kind, row.scopeId, row.recordId, row.title, row.userId),
        (ChangeKind.setAdded, 'b1', 'set2', 'Rehearsal', 'carol'),
      );
      expect(ChangeDetails.fromJson(row.details), const ChangeDetails());

      // Changed afterwards: still one entry, and it stays a new set.
      server.putSet(
        RemoteSet(
          id: 'set2',
          bandId: 'b1',
          name: 'Rehearsal',
          items: [_song('i1', 's1')],
        ),
        by: 'bob',
      );
      await engine.sync();
      final rows = await log();
      expect(rows.map((r) => r.kind), [
        ChangeKind.setAdded,
        ChangeKind.setChanged,
      ]);
      final grouped = groupChanges(rows.reversed.toList());
      expect(
        (grouped.single.kind, grouped.single.details),
        (ChangeKind.setAdded, const ChangeDetails(removed: 1)),
      );
    });

    test('logs songs added to and removed from a set and changed '
        'sequences, not a reordering or a new gig date', () async {
      server.putSet(
        RemoteSet(
          id: 'set1',
          bandId: 'b1',
          name: 'Gig',
          gigDate: DateTime(2026, 12, 24),
          items: [_song('i1', 's1')],
        ),
        by: 'bob',
      );
      await engine.sync();
      expect(await log(), isEmpty);

      server.putSet(
        RemoteSet(
          id: 'set1',
          bandId: 'b1',
          name: 'Gig',
          items: [
            _song('i2', 's2'),
            _song('i1', 's1', sequence: 'V, C'),
          ],
        ),
        by: 'carol',
      );
      await engine.sync();
      server.putSet(
        RemoteSet(
          id: 'set1',
          bandId: 'b1',
          name: 'Gig',
          items: [
            _song('i1', 's1', sequence: 'V, C'),
            _song('i2', 's2'),
          ],
        ),
        by: 'carol',
      );
      await engine.sync();
      final row = (await log()).single;
      expect(
        (row.kind, row.scopeId, row.recordId, row.title, row.userId),
        (ChangeKind.setChanged, 'b1', 'set1', 'Gig', 'carol'),
      );
      expect(
        ChangeDetails.fromJson(row.details),
        const ChangeDetails(added: 1, sequences: ['One']),
      );

      server.putSet(
        const RemoteSet(id: 'set1', bandId: 'b1', name: 'Gig'),
        by: 'bob',
      );
      await engine.sync();
      expect(
        ChangeDetails.fromJson((await log()).last.details),
        const ChangeDetails(removed: 2),
      );
    });

    test('a new sequence of the band\'s arrangement is a change of the sets '
        'with the song', () async {
      server.putSet(
        RemoteSet(
          id: 'set2',
          bandId: 'b1',
          name: 'Rehearsal',
          items: [_song('i9', 's2')],
        ),
        by: 'bob',
      );
      await engine.sync();
      await db.delete(db.changeLog).go();
      RemoteArrangement arrangement(String songId, {String? sequence}) =>
          RemoteArrangement(
            id: ArrangementSync.serverId('b1', songId),
            bandId: 'b1',
            songId: songId,
            transpose: 2,
            sequence: sequence,
          );
      server.putArrangement(arrangement('s1'), by: 'bob');
      await engine.sync();
      expect(await log(), isEmpty, reason: 'transposition only');

      server.putArrangement(arrangement('s1', sequence: 'C, V'), by: 'dave');
      await engine.sync();
      final row = (await log()).single;
      expect(
        (row.kind, row.recordId, row.title, row.userId),
        (ChangeKind.setChanged, 'set1', 'Gig', 'dave'),
      );
      expect(
        ChangeDetails.fromJson(row.details),
        const ChangeDetails(sequences: ['One']),
      );
    });

    test('entries older than 30 days are removed', () async {
      final repo = ChangeLogRepository(db);
      final now = DateTime.now();
      for (final days in [31, 29]) {
        await repo.add(
          kind: ChangeKind.songChanged,
          scopeId: 'o1',
          recordId: 's$days',
          title: 'Old',
          at: now.subtract(Duration(days: days)),
        );
      }
      await engine.sync();
      expect((await log()).map((r) => r.recordId), ['s29']);
    });

    test('watch lists the changes of the band and its organization after '
        'a time, newest first', () async {
      final repo = ChangeLogRepository(db);
      final t = DateTime(2026, 11, 20, 12);
      for (final (i, (scope, record)) in [
        ('o1', 's1'),
        ('b1', 'set1'),
        ('other', 's2'),
      ].indexed) {
        await repo.add(
          kind: scope == 'b1' ? ChangeKind.setChanged : ChangeKind.songAdded,
          scopeId: scope,
          recordId: record,
          title: scope,
          at: t.add(Duration(hours: i)),
        );
      }
      expect((await repo.watch(['b1', 'o1']).first).map((c) => c.recordId), [
        'set1',
        's1',
      ]);
      expect(
        (await repo.watch(
          ['b1', 'o1'],
          since: t.add(const Duration(minutes: 30)),
        ).first).map((c) => c.recordId),
        ['set1'],
      );
    });

    test('a song or set deleted after its change was logged is not listed '
        'and comes back when restored (#701)', () async {
      final repo = ChangeLogRepository(db);
      server.putSong(song('s3', '{title: Three}'), by: 'bob');
      server.putSet(
        RemoteSet(
          id: 'set2',
          bandId: 'b1',
          name: 'Party',
          items: [_song('i2', 's3')],
        ),
        by: 'bob',
      );
      await engine.sync();
      final changes = repo.watch(['b1', 'o1']);
      final emitted = <List<String>>[];
      final subscription = changes.listen(
        (list) => emitted.add([for (final c in list) c.recordId]),
      );
      Future<List<String>> listed() async {
        await pumpEventQueue();
        return emitted.last;
      }

      expect(await listed(), ['set2', 's3']);

      // Deleted on the server: the entries drop out, the watch updates.
      server.putSong(
        RemoteSong(
          id: 's3',
          organizationId: 'o1',
          title: 's3',
          chordpro: '{title: Three}',
          deleted: true,
          deletedAt: DateTime.now(),
        ),
        by: 'bob',
      );
      server.putSet(
        RemoteSet(
          id: 'set2',
          bandId: 'b1',
          name: 'Party',
          items: const [],
          deleted: true,
          deletedAt: DateTime.now(),
        ),
        by: 'bob',
      );
      await engine.sync();
      expect(await listed(), isEmpty);
      // Still stored, only not listed.
      expect((await log()).map((r) => r.recordId), containsAll(['s3', 'set2']));

      // Restored from the trash: the earlier entries are back.
      server.putSong(song('s3', '{title: Three}'), by: 'bob');
      await engine.sync();
      expect(await listed(), contains('s3'));
      await subscription.cancel();
    });
  });
}
