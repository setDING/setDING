import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_memory.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

final _pdf = Uint8List.fromList('%PDF-1.4\n%%EOF\n'.codeUnits);

/// Closing organizations in the app (ADR-0044): who may, what devices
/// learn, and that the organization's data leaves the device.
void main() {
  late AppDatabase db;
  late MemoryAttachmentStorage storage;
  late FakeSyncBackend backend;
  late BandService service;
  late String song;
  late String file;
  late String otherSong;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    storage = MemoryAttachmentStorage();
    backend = FakeSyncBackend(user: _ann);
    service = BandService(db, backend, storage: storage);
    backend.addOrganization('o1', 'School', admin: _ann);
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addMember('b1', _bob, BandRole.member);
    backend.addOrganization('o2', 'Choir', admin: _ann);
    backend.addBand('b2', 'Voices', admin: _ann, organizationId: 'o2');
    await service.refresh();

    final songs = SongRepository(db, storage, libraryId: 'o1');
    song = await songs.createSong(source: '{title: Shared}');
    final attachment = await songs.addAttachment(
      song,
      name: 'Score',
      bytes: _pdf,
    );
    file = (await (db.select(
      db.attachments,
    )..where((a) => a.id.equals(attachment))).getSingle()).fileName;
    final sets = SetRepository(db, storage, bandId: 'b1');
    final set = await sets.createSet(name: 'Gig');
    await sets.addSongs(set, [song]);
    otherSong = await SongRepository(
      db,
      storage,
      libraryId: 'o2',
    ).createSong(source: '{title: Other}');
  });
  tearDown(() => db.close());

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  test('only organization admins may close it', () async {
    final orgs = await service.watchOrganizations('ann').first;
    expect(orgs.every((o) => o.canClose), isTrue);
    final bobs = await service.watchOrganizations('bob').first;
    expect(bobs.single.canClose, isFalse);
  });

  test('closing removes all of the organization from this device', () async {
    expect(await storage.exists(file), isTrue);
    await service.closeOrganization('o1');

    expect(
      await count("SELECT COUNT(*) AS n FROM songs WHERE library_id = 'o1'"),
      0,
    );
    expect(await count('SELECT COUNT(*) AS n FROM attachments'), 0);
    expect(
      await count("SELECT COUNT(*) AS n FROM setlists WHERE band_id = 'b1'"),
      0,
    );
    expect(await count('SELECT COUNT(*) AS n FROM set_items'), 0);
    expect(await count("SELECT COUNT(*) AS n FROM bands WHERE id = 'b1'"), 0);
    expect(
      await count("SELECT COUNT(*) AS n FROM memberships WHERE band_id = 'b1'"),
      0,
    );
    expect(
      await count("SELECT COUNT(*) AS n FROM organizations WHERE id = 'o1'"),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_outbox WHERE record_id = '$song'",
      ),
      0,
    );
    expect(await storage.exists(file), isFalse);
    // Other organizations stay.
    expect(
      await count("SELECT COUNT(*) AS n FROM songs WHERE id = '$otherSong'"),
      1,
    );
    expect(
      [for (final o in await service.watchOrganizations('ann').first) o.name],
      ['Choir'],
    );
  });

  test('members learn which organization was closed and by whom', () async {
    backend.user = _bob;
    await service.refresh();
    backend.user = _ann;
    await backend.closeOrganization('o1');
    backend.user = _bob;

    final changes = await service.refresh();
    expect(changes.closedOrganizations.single.name, 'School');
    expect(changes.closedOrganizations.single.closedBy, 'Ann');
    expect(changes.closedOrganizations.single.isAdmin, isFalse);
    // Its bands are not reported on their own.
    expect(changes.goneBands, isEmpty);
    expect(
      await count("SELECT COUNT(*) AS n FROM songs WHERE library_id = 'o1'"),
      0,
    );
  });

  test('a sync reports closed organizations', () async {
    final engine = SyncEngine(db, backend, service, storage: storage);
    expect((await engine.sync()).closedOrganizations, isEmpty);
    await backend.closeOrganization('o1');
    final report = await engine.sync();
    expect(report.closedOrganizations.single.id, 'o1');
    expect((await engine.sync()).closedOrganizations, isEmpty);
  });

  test('restoring brings the organization back', () async {
    await service.closeOrganization('o1');
    expect((await service.closedOrganizations()).single.id, 'o1');
    await service.restoreOrganization('o1');
    expect(await service.closedOrganizations(), isEmpty);
    expect([
      for (final o in await service.watchOrganizations('ann').first) o.name,
    ], containsAll(['School', 'Choir']));
  });

  test('leaving an organization keeps its data hidden as before', () async {
    backend.orgMembers.removeWhere(
      (m) => m.scopeId == 'o1' && m.user.id == 'ann',
    );
    final changes = await service.refresh();
    expect(changes.closedOrganizations, isEmpty);
    expect(
      await count("SELECT COUNT(*) AS n FROM songs WHERE library_id = 'o1'"),
      1,
    );
  });
}
