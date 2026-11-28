// Randomized multi-device convergence test of the sync (ADR-0004, #1245).
//
// Several simulated devices (each with its own database and attachment
// storage) of different people and roles share one fake server. They make
// random changes to songs, sets, attachments and personal adjustments, go
// offline and online and sync in random order, while the server fails some
// requests for a while (network, 5xx, 429), loses some answers after it
// stored the change, and refuses some attachment changes for good. After a
// final sync round of every device, each device must agree with the server,
// refused changes must have been reported, and personal adjustments must
// stay with their person.
//
// The seeds are fixed, so every run checks the same scenarios; a failure
// prints the seed and the operation log. FUZZ_ITERATIONS sets the number of
// random operations (docs/development/fuzz-tests.md); SYNC_FUZZ_SEED runs a
// single scenario again.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_memory.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/data/trash.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

/// Random operations per scenario.
const _opsPerScenario = 60;

/// Random operations of a run: few in `make check`, more with
/// FUZZ_ITERATIONS (`make fuzz`).
final _operations =
    int.tryParse(Platform.environment['FUZZ_ITERATIONS'] ?? '') ?? 600;

const _org = 'o1';
const _band = 'b1';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _carol = AuthUser(id: 'carol', email: 'carol@example.test', name: 'C');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

final _pdf = Uint8List.fromList('%PDF-1.4 convergence'.codeUnits);
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, //
]);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final single = int.tryParse(Platform.environment['SYNC_FUZZ_SEED'] ?? '');
  final seeds = single != null
      ? [single]
      : [
          for (var i = 0; i < max(1, _operations ~/ _opsPerScenario); i++)
            1245 + i,
        ];
  for (final seed in seeds) {
    test('devices converge with the server (seed $seed)', () async {
      final scenario = _Scenario(seed);
      try {
        await scenario.run();
      } catch (_) {
        // ignore: avoid_print
        print(scenario.describe());
        rethrow;
      } finally {
        await scenario.close();
      }
    });
  }
}

/// A server that fails requests now and then, as a real network and server
/// do (ADR-0004): for a while (network, 5xx, 429), after storing the change
/// (the answer got lost), or for good (an attachment change refused).
class _ChaosBackend extends FakeSyncBackend {
  _ChaosBackend(this.random);

  final Random random;

  /// Chances per request; zero in the final round.
  double transient = 0;
  double lost = 0;
  double refuse = 0;

  /// Lasting refusals given, by device: attachment IDs.
  final refusedCreates = <String, Set<String>>{};
  final refusedUpdates = <String, Set<String>>{};

  /// The device whose sync is running.
  String device = '';

  final log = <String>[];

  void quiet() => transient = lost = refuse = 0;

  /// Songs deleted on the server at some time.
  final everDeleted = <String>{};

  @override
  RemoteSong putSong(RemoteSong song, {String? by}) {
    if (song.deleted) everDeleted.add(song.id);
    return super.putSong(song, by: by);
  }

  static const _transientErrors = [
    BackendException(BackendErrorKind.network),
    BackendException(BackendErrorKind.server, null, 500),
    BackendException(BackendErrorKind.server, null, 503),
    BackendException(BackendErrorKind.server, null, 429),
  ];

  BackendException _pick() =>
      _transientErrors[random.nextInt(_transientErrors.length)];

  void _before(String what) {
    if (random.nextDouble() < transient) {
      final e = _pick();
      log.add('  ! $what failed before: $e');
      throw e;
    }
  }

  Future<T> _after<T>(String what, Future<T> Function() call) async {
    final result = await call();
    if (random.nextDouble() < lost) {
      final e = _pick();
      log.add('  ! $what stored, answer lost: $e');
      throw e;
    }
    return result;
  }

  @override
  Future<List<RemoteSong>> pullSongs(String organizationId, int since) {
    _before('pullSongs');
    return super.pullSongs(organizationId, since);
  }

  @override
  Future<List<RemoteSet>> pullSets(String bandId, int since) {
    _before('pullSets');
    return super.pullSets(bandId, since);
  }

  @override
  Future<List<RemoteAttachment>> pullAttachments(
    String organizationId,
    int since,
  ) {
    _before('pullAttachments');
    return super.pullAttachments(organizationId, since);
  }

  @override
  Future<List<RemoteOverlay>> pullOverlays(int since) {
    _before('pullOverlays');
    return super.pullOverlays(since);
  }

  @override
  Future<RemoteSong> pushSong(RemoteSong song, {required bool create}) {
    _before('pushSong ${song.id}');
    return _after(
      'pushSong ${song.id}',
      () => super.pushSong(song, create: create),
    );
  }

  @override
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create}) {
    _before('pushSet ${set.id}');
    return _after(
      'pushSet ${set.id}',
      () => super.pushSet(set, create: create),
    );
  }

  @override
  Future<RemoteOverlay> pushOverlay(
    RemoteOverlay overlay, {
    required bool create,
  }) {
    _before('pushOverlay ${overlay.songId}');
    return _after(
      'pushOverlay ${overlay.songId}',
      () => super.pushOverlay(overlay, create: create),
    );
  }

  @override
  Future<RemoteAttachment> pushAttachment(
    RemoteAttachment attachment, {
    required bool create,
    List<int>? bytes,
  }) {
    final what = 'pushAttachment ${attachment.id} (create: $create)';
    _before(what);
    if (random.nextDouble() < refuse) {
      final e = random.nextBool()
          ? const BackendException(BackendErrorKind.notAllowed)
          : const BackendException(BackendErrorKind.server, {
              'data': {
                'name': {'code': 'validation_invalid'},
              },
            }, 400);
      log.add('  ! $what refused: $e');
      (create ? refusedCreates : refusedUpdates)
          .putIfAbsent(device, () => {})
          .add(attachment.id);
      throw e;
    }
    return _after(
      what,
      () => super.pushAttachment(attachment, create: create, bytes: bytes),
    );
  }
}

/// One simulated device of [user].
class _Device {
  _Device(this.name, this.user, this.server) {
    db = AppDatabase(NativeDatabase.memory());
    storage = MemoryAttachmentStorage();
    bands = BandService(db, server);
    engine = SyncEngine(
      db,
      server,
      bands,
      copies: BandCopyService(db, storage),
    );
    songs = SongRepository(db, storage, libraryId: _org, userId: user.id);
    sets = SetRepository(db, storage, bandId: _band);
    trash = TrashRepository(db, storage);
  }

  final String name;
  final AuthUser user;
  final _ChaosBackend server;
  late final AppDatabase db;
  late final MemoryAttachmentStorage storage;
  late final BandService bands;
  late final SyncEngine engine;
  late final SongRepository songs;
  late final SetRepository sets;
  late final TrashRepository trash;

  bool online = true;

  /// Attachments reported as refused uploads and undone changes.
  final reportedRefused = <String>{};
  final reportedUndone = <String>{};

  bool get maintainsSongs => user.id != _bob.id;
  bool get deletesSongs => user.id == _ann.id;

  Future<SyncReport> sync({bool refreshBands = true}) async {
    server.user = user;
    server.device = name;
    final before = server.failWith;
    if (!online) server.failWith = BackendErrorKind.network;
    try {
      final report = await engine.sync(refreshBands: refreshBands);
      reportedRefused.addAll([
        for (final r in report.refusedUploads) r.attachmentId,
      ]);
      reportedUndone.addAll([
        for (final r in report.undoneChanges) r.attachmentId,
      ]);
      return report;
    } finally {
      server.failWith = before;
    }
  }
}

class _Scenario {
  _Scenario(this.seed) : random = Random(seed) {
    server = _ChaosBackend(random);
    server.addBand('b1', 'Band', admin: _ann, organizationId: _org);
    server.addMember(_band, _carol, BandRole.admin);
    server.addMember(_band, _bob, BandRole.member);
    devices = [
      _Device('ann-tablet', _ann, server),
      _Device('ann-phone', _ann, server),
      _Device('carol', _carol, server),
      _Device('bob', _bob, server),
    ];
  }

  final int seed;
  final Random random;
  late final _ChaosBackend server;
  late final List<_Device> devices;

  List<String> get log => server.log;
  var _songs = 0;
  var _sets = 0;
  var _attachments = 0;

  String describe() =>
      'Sync convergence failed for seed $seed '
      '(run it again with SYNC_FUZZ_SEED=$seed).\n'
      'Operations:\n${log.join('\n')}';

  Future<void> close() async {
    for (final d in devices) {
      await d.db.close();
    }
  }

  T _any<T>(List<T> list) => list[random.nextInt(list.length)];

  Future<void> run() async {
    server.transient = random.nextDouble() * 0.15;
    server.lost = random.nextDouble() * 0.1;
    server.refuse = random.nextDouble() * 0.1;
    log.add(
      'faults: transient ${server.transient.toStringAsFixed(3)}, '
      'lost ${server.lost.toStringAsFixed(3)}, '
      'refused ${server.refuse.toStringAsFixed(3)}',
    );
    for (final d in devices) {
      await d.sync();
    }
    for (var i = 0; i < _opsPerScenario; i++) {
      final d = _any(devices);
      await _step(d);
    }
    await _settle();
    await _check();
  }

  // Operations ---------------------------------------------------------------

  /// Songs on [d] in a fixed order (IDs are numbered), so a seed always
  /// takes the same choices.
  Future<List<SongEntry>> _localSongs(_Device d, {bool? deleted}) async {
    final rows =
        await (d.db.select(d.db.songs)
              ..where((s) => s.libraryId.equals(_org))
              ..orderBy([(s) => OrderingTerm.asc(s.id)]))
            .get();
    return [
      for (final s in rows)
        if ((deleted == null || s.deleted == deleted) && !s.purged) s,
    ];
  }

  Future<List<SetlistEntry>> _localSets(_Device d, {bool? deleted}) async {
    final rows =
        await (d.db.select(d.db.setlists)
              ..where((s) => s.bandId.equals(_band))
              ..orderBy([(s) => OrderingTerm.asc(s.id)]))
            .get();
    return [
      for (final s in rows)
        if ((deleted == null || s.deleted == deleted) && !s.purged) s,
    ];
  }

  Future<List<AttachmentEntry>> _localAttachments(_Device d) async {
    final rows = await (d.db.select(
      d.db.attachments,
    )..orderBy([(a) => OrderingTerm.asc(a.id)])).get();
    final live = {for (final s in await _localSongs(d, deleted: false)) s.id};
    return [
      for (final a in rows)
        if (live.contains(a.songId)) a,
    ];
  }

  Future<void> _step(_Device d) async {
    final p = random.nextInt(100);
    final who = d.name;
    if (p < 22) {
      final refresh = random.nextInt(4) != 0;
      log.add('$who: sync${d.online ? '' : ' (offline)'}');
      final r = await d.sync(refreshBands: refresh);
      log.add(
        '  -> pulled ${r.pulled}, pushed ${r.pushed}, conflicts '
        '${r.conflicts}, error ${r.error?.name}',
      );
      return;
    }
    if (p < 27) {
      d.online = !d.online;
      log.add('$who: ${d.online ? 'online' : 'offline'}');
      return;
    }
    if (p < 32) return _resolveConflict(d);
    if (p < 45) return _adjust(d);
    if (!d.maintainsSongs) return _adjust(d);
    if (p < 52) {
      final id = 's${++_songs}';
      log.add('$who: create song $id');
      await d.songs.createSong(id: id, source: '{title: Song $id}\n[C]$id');
      return;
    }
    if (p < 62) {
      final songs = await _localSongs(d, deleted: false);
      if (songs.isEmpty) return;
      final s = _any(songs);
      final text = '{title: ${s.title}}\n[G]$who ${random.nextInt(1000)}';
      log.add('$who: edit song ${s.id}');
      await d.songs.updateSource(s.id, text);
      return;
    }
    if (p < 66) {
      if (!d.deletesSongs) return;
      final songs = await _localSongs(d, deleted: false);
      if (songs.isEmpty) return;
      final s = _any(songs);
      log.add('$who: delete song ${s.id}');
      await d.songs.deleteSong(s.id);
      return;
    }
    if (p < 69) {
      if (!d.deletesSongs) return;
      final songs = await _localSongs(d, deleted: true);
      if (songs.isEmpty) return;
      final s = _any(songs);
      log.add('$who: restore song ${s.id} from the trash');
      await d.trash.restoreSong(s.id);
      return;
    }
    if (p < 78) return _changeSet(d);
    return _changeAttachment(d);
  }

  Future<void> _adjust(_Device d) async {
    final songs = await _localSongs(d, deleted: false);
    if (songs.isEmpty) return;
    final s = _any(songs);
    final transpose = random.nextInt(11) - 5;
    final notes = random.nextBool() ? null : '${d.name} ${random.nextInt(99)}';
    log.add('${d.name}: adjust ${s.id}: transpose $transpose, notes $notes');
    final o = await d.songs.getOverlay(s.id);
    await d.songs.saveOverlay(
      o.copyWith(transpose: transpose, notes: Value(notes)),
    );
  }

  Future<void> _resolveConflict(_Device d) async {
    final conflicts = await (d.db.select(
      d.db.songConflicts,
    )..orderBy([(c) => OrderingTerm.asc(c.songId)])).get();
    if (conflicts.isEmpty) return;
    final c = _any(conflicts);
    switch (random.nextInt(3)) {
      case 0:
        log.add('${d.name}: conflict ${c.songId}: keep mine');
        await d.engine.keepLocal(c.songId);
      case 1:
        log.add('${d.name}: conflict ${c.songId}: take the server version');
        await d.engine.takeServer(c.songId);
      default:
        log.add('${d.name}: conflict ${c.songId}: keep both');
        final copy = await d.engine.keepBoth(c.songId);
        log.add('  -> copy $copy');
    }
  }

  Future<void> _changeSet(_Device d) async {
    final who = d.name;
    final sets = await _localSets(d, deleted: false);
    final kind = random.nextInt(7);
    if (kind == 0 || sets.isEmpty) {
      final id = 'set${++_sets}';
      log.add('$who: create set $id');
      await d.sets.createSet(id: id, name: 'Set $id');
      return;
    }
    final set = _any(sets);
    switch (kind) {
      case 1:
        final name = 'Set ${set.id} by $who ${random.nextInt(99)}';
        log.add('$who: rename set ${set.id} to "$name"');
        await d.sets.updateSet(set.id, name: name);
      case 2 || 3:
        final songs = await _localSongs(d, deleted: false);
        if (songs.isEmpty) return;
        final s = _any(songs);
        log.add('$who: add ${s.id} to set ${set.id}');
        await d.sets.addSongs(set.id, [s.id]);
      case 4:
        final items = await d.sets.getItems(set.id);
        if (items.isEmpty) return;
        final i = random.nextInt(items.length);
        log.add('$who: remove item $i from set ${set.id}');
        await d.sets.removeItem(set.id, items[i].item.id);
      case 5:
        final items = await d.sets.getItems(set.id);
        if (items.length < 2) return;
        final ids = [for (final i in items) i.item.id]..shuffle(random);
        log.add('$who: reorder set ${set.id}');
        await d.sets.reorder(set.id, ids);
      default:
        if (random.nextBool()) {
          log.add('$who: delete set ${set.id}');
          await d.sets.deleteSet(set.id);
        } else {
          final deleted = await _localSets(d, deleted: true);
          if (deleted.isEmpty) return;
          final s = _any(deleted);
          log.add('$who: restore set ${s.id} from the trash');
          await d.trash.restoreSet(s.id);
        }
    }
  }

  Future<void> _changeAttachment(_Device d) async {
    final who = d.name;
    final attachments = await _localAttachments(d);
    final kind = random.nextInt(7);
    if (kind <= 1 || attachments.isEmpty) {
      final songs = await _localSongs(d, deleted: false);
      if (songs.isEmpty) return;
      final s = _any(songs);
      final id = 'a${++_attachments}';
      final image = random.nextInt(3) == 0;
      log.add('$who: attach ${image ? 'image' : 'PDF'} $id to ${s.id}');
      await d.songs.addAttachment(
        s.id,
        id: id,
        name: 'File $id',
        bytes: image ? _png : _pdf,
        extension: image ? 'png' : 'pdf',
      );
      return;
    }
    final a = _any(attachments);
    switch (kind) {
      case 2:
        if (a.deleted) return;
        final name = '${a.id} by $who ${random.nextInt(99)}';
        log.add('$who: rename attachment ${a.id} to "$name"');
        await d.songs.renameAttachment(a.id, name);
      case 3:
        if (a.deleted) return;
        log.add('$who: delete attachment ${a.id}');
        await d.songs.deleteAttachment(a);
      case 4:
        // From the trash: attachments on the server only (ADR-0043).
        if (!a.deleted || a.purged || a.revision == 0) return;
        log.add('$who: restore attachment ${a.id} from the trash');
        await d.trash.restoreAttachments([a.id]);
      case 5:
        // Only who may delete songs purges (ADR-0070).
        if (!d.deletesSongs || !a.deleted || a.purged || a.revision == 0) {
          return;
        }
        log.add('$who: purge attachment ${a.id}');
        await d.trash.purgeAttachments([a.id]);
      default:
        if (a.uploadRefused == null) return;
        log.add('$who: upload attachment ${a.id} again');
        await d.songs.retryUpload(a.id);
    }
  }

  // Final round ----------------------------------------------------------------

  /// Brings every device online without faults and syncs them in turn,
  /// resolving conflicts, until a whole round changes nothing.
  Future<void> _settle() async {
    server.quiet();
    log.add('--- final rounds: online, no faults');
    for (final d in devices) {
      d.online = true;
    }
    for (var round = 0; round < 10; round++) {
      var quiet = true;
      for (final d in devices) {
        log.add('${d.name}: sync');
        final r = await d.sync();
        log.add(
          '  -> pulled ${r.pulled}, pushed ${r.pushed}, conflicts '
          '${r.conflicts}, error ${r.error?.name}',
        );
        expect(r.error, isNull, reason: '${d.name} synced without error');
        if (r.pushed > 0 || r.conflicts > 0) quiet = false;
        final conflicts = await d.db.select(d.db.songConflicts).get();
        for (final c in conflicts) {
          quiet = false;
          // Alternate, so that a round always ends the conflict.
          if (random.nextBool()) {
            log.add('${d.name}: conflict ${c.songId}: keep mine');
            await d.engine.keepLocal(c.songId);
          } else {
            log.add('${d.name}: conflict ${c.songId}: take the server');
            await d.engine.takeServer(c.songId);
          }
        }
        if ((await d.db.select(d.db.syncOutbox).get()).isNotEmpty) {
          quiet = false;
        }
      }
      if (quiet) return;
    }
    fail('The devices did not settle in 10 rounds');
  }

  // Checks -------------------------------------------------------------------

  Future<void> _check() async {
    for (final d in devices) {
      final outbox = await d.engine.describeOutbox();
      expect(outbox, '[]', reason: '${d.name}: nothing left to push');
      await _checkSongs(d);
      await _checkSets(d);
      await _checkAttachments(d);
      await _checkOverlays(d);
    }
  }

  Future<void> _checkSongs(_Device d) async {
    final local = {
      for (final s in await (d.db.select(
        d.db.songs,
      )..where((s) => s.libraryId.equals(_org))).get())
        // Deleted before it ever reached the server: never sent.
        if (!(s.revision == 0 && s.deleted))
          s.id: jsonEncode({
            'source': s.chordproSource,
            'deleted': s.deleted,
            'purged': s.purged,
            'revision': s.revision,
          }),
    };
    final remote = {
      for (final s in server.songs.values)
        if (s.organizationId == _org)
          s.id: jsonEncode({
            'source': s.chordpro,
            'deleted': s.deleted,
            'purged': s.purged,
            'revision': s.revision,
          }),
    };
    expect(local, remote, reason: '${d.name}: songs as on the server');
  }

  /// Items of songs that were deleted at some time are left out: a device
  /// that pulls the deletion of a song removes it from its sets without
  /// pushing them (`SongSync.writeSong`), while the server keeps the item
  /// another device added meanwhile, also after the song is restored. Which
  /// one is right is an open decision (#1245), not a sync error.
  bool _deletedOnce(String? songId) =>
      songId != null && server.everDeleted.contains(songId);

  Future<void> _checkSets(_Device d) async {
    final local = <String, String>{};
    for (final s in await (d.db.select(
      d.db.setlists,
    )..where((s) => s.bandId.equals(_band))).get()) {
      if (s.revision == 0 && s.deleted) continue; // never sent
      final items =
          await (d.db.select(d.db.setItems)
                ..where((i) => i.setId.equals(s.id))
                ..orderBy([(i) => OrderingTerm.asc(i.position)]))
              .get();
      local[s.id] = jsonEncode({
        'name': s.name,
        'deleted': s.deleted,
        'revision': s.revision,
        'items': [
          for (final i in items)
            if (!_deletedOnce(i.songId)) RemoteSetItem.fromEntry(i).toJson(),
        ],
      });
    }
    final remote = {
      for (final s in server.sets.values)
        if (s.bandId == _band)
          s.id: jsonEncode({
            'name': s.name,
            'deleted': s.deleted,
            'revision': s.revision,
            'items': [
              for (final i in s.items)
                if (!_deletedOnce(i.songId)) i.toJson(),
            ],
          }),
    };
    expect(local, remote, reason: '${d.name}: sets as on the server');
  }

  Future<void> _checkAttachments(_Device d) async {
    final rows = await d.db.select(d.db.attachments).get();
    final refused = {
      for (final a in rows)
        if (a.uploadRefused != null) a.id,
    };
    // Refused uploads stay on this device, marked, and were reported
    // (#1225); refused changes were undone and reported (#1229).
    expect(
      d.reportedRefused,
      containsAll(refused),
      reason: '${d.name}: every refused upload was reported',
    );
    for (final id in server.refusedUpdates[d.name] ?? const <String>{}) {
      expect(
        d.reportedUndone.contains(id) || refused.contains(id),
        isTrue,
        reason: '${d.name}: the refused change of $id was reported',
      );
    }
    for (final id in server.refusedCreates[d.name] ?? const <String>{}) {
      expect(
        d.reportedRefused.contains(id),
        isTrue,
        reason: '${d.name}: the refused upload of $id was reported',
      );
    }
    // Deleting a song deletes its attachments with it on the device that
    // deletes it; the server keeps them as they are (ADR-0043), so they
    // count as deleted while their song is.
    bool songGone(String songId) => server.songs[songId]?.deleted ?? false;
    final local = {
      for (final a in rows)
        // Deleted before it ever reached the server: never sent.
        if (!refused.contains(a.id) && !(a.revision == 0 && a.deleted))
          a.id: jsonEncode({
            'song': a.songId,
            'name': a.name,
            'deleted': a.deleted || songGone(a.songId),
            'purged': a.purged,
            'revision': a.revision,
          }),
    };
    final remote = {
      for (final a in server.attachments.values)
        if (a.organizationId == _org && !refused.contains(a.id))
          a.id: jsonEncode({
            'song': a.songId,
            'name': a.name,
            'deleted': a.deleted || songGone(a.songId),
            'purged': a.purged,
            'revision': a.revision,
          }),
    };
    expect(local, remote, reason: '${d.name}: attachments as on the server');
    // Every attachment in use is on the device (ADR-0009).
    final songs = {for (final s in await _localSongs(d, deleted: false)) s.id};
    for (final a in rows) {
      if (a.deleted || !songs.contains(a.songId)) continue;
      expect(
        await d.storage.exists(a.fileName),
        isTrue,
        reason: '${d.name}: the file of ${a.id} is on the device',
      );
    }
  }

  Future<void> _checkOverlays(_Device d) async {
    final rows = await d.db.select(d.db.personalOverlays).get();
    // Personal adjustments stay with their person (ADR-0006, ADR-0020).
    expect(
      {for (final o in rows) o.ownerId},
      everyElement(d.user.id),
      reason: '${d.name}: only adjustments of ${d.user.id}',
    );
    final live = {for (final s in await _localSongs(d, deleted: false)) s.id};
    final local = {
      for (final o in rows)
        if (live.contains(o.songId))
          o.songId: jsonEncode(SyncEngine.overlayData(o)),
    };
    final remote = {
      for (final o in server.overlays.values)
        if (o.userId == d.user.id && !o.deleted && live.contains(o.songId))
          o.songId: jsonEncode(o.data),
    };
    expect(local, remote, reason: '${d.name}: adjustments as on the server');
  }
}
