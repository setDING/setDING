// Two devices sync songs and sets through a real PocketBase with the
// repository's schema (ADR-0004, ADR-0015, ADR-0017).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realchord/data/attachment_storage_io.dart';
import 'package:realchord/data/band_copy.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/sync/band_service.dart';
import 'package:realchord/sync/pocketbase_backend.dart';
import 'package:realchord/sync/session_store.dart';
import 'package:realchord/sync/sync_engine.dart';
import 'package:realchord_server/pocketbase_harness.dart';
import 'package:uuid/uuid.dart';

/// One device: its own database and session.
class Device {
  Device._(this.db, this.dir, this.backend, this.engine);

  final AppDatabase db;
  final Directory dir;
  final PocketBaseBackend backend;
  final SyncEngine engine;

  static Future<Device> create(String url) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final dir = Directory.systemTemp.createTempSync('realchord_device');
    final backend = PocketBaseBackend(
      serverUrl: url,
      store: MemorySessionStore(),
    );
    final storage = FileAttachmentStorage(dir);
    final engine = SyncEngine(
      db,
      backend,
      BandService(db, backend),
      copies: BandCopyService(db, storage),
    );
    return Device._(db, dir, backend, engine);
  }

  SongRepository songs(String org) => SongRepository(
    db,
    FileAttachmentStorage(dir),
    libraryId: org,
    userId: backend.currentUser?.id,
  );
  SetRepository sets(String band) =>
      SetRepository(db, FileAttachmentStorage(dir), bandId: band);

  Future<SyncReport> sync() async {
    final report = await engine.sync();
    expect(report.error, isNull);
    return report;
  }

  Future<void> close() async {
    backend.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  }
}

void main() {
  late PocketBase pb;
  late String url;

  setUpAll(() async {
    pb = await PocketBase.start();
    url = pb.baseUrl.toString().replaceAll(RegExp(r'/$'), '');
  });
  tearDownAll(() => pb.stop());

  var n = 0;
  String email() =>
      'sync${++n}-${DateTime.now().microsecondsSinceEpoch}@realchord.test';

  /// Ann (admin) and Bob (band member allowed to edit songs) on two devices.
  Future<(Device, Device, String org, String band)> twoDevices() async {
    final ann = await Device.create(url);
    final bob = await Device.create(url);
    await ann.backend.signUp(
      email: email(),
      password: 'password-123',
      name: 'Ann',
    );
    final bobUser = await bob.backend.signUp(
      email: email(),
      password: 'password-123',
      name: 'Bob',
    );
    final band = const Uuid().v4();
    await ann.backend.createBand(id: band, name: 'Rock');
    final org = (await ann.backend.fetchOrganizations()).single.id;
    // Bob maintains the library with Ann (ADR-0023).
    (await pb.superuser.post('org_memberships', {
      'user': bobUser.id,
      'organization': org,
      'role': 'librarian',
    })).expectStatus(200);
    await ann.backend.addBandMember(band, bobUser.id, BandRole.member);
    // Loads the organizations and bands on both devices.
    await ann.sync();
    await bob.sync();
    return (ann, bob, org, band);
  }

  test('songs and sets reach the other device', () async {
    final (ann, bob, org, band) = await twoDevices();
    final song = await ann
        .songs(org)
        .createSong(source: '{title: Shared}\n{key: G}\n[G]Hello');
    final set = await ann.sets(band).createSet(name: 'Gig', venue: 'Bern');
    await ann.sets(band).addSongs(set, [song]);
    await ann.sets(band).addMarker(set, SetItemType.pause, 'Break');
    expect((await ann.sync()).pushed, 2);

    await bob.sync();
    final bobSong = (await bob.songs(org).getSong(song))!;
    expect(bobSong.title, 'Shared');
    expect(bobSong.songKey, 'G');
    final items = await bob.sets(band).getItems(set);
    expect(items.map((i) => i.song?.title ?? i.item.note), ['Shared', 'Break']);
    expect((await bob.sets(band).watchSets().first).single.set.venue, 'Bern');

    // Bob fixes a typo; Ann gets it.
    await bob
        .songs(org)
        .updateSource(song, '{title: Shared}\n{key: G}\n[G]Hallo');
    await bob.sync();
    await ann.sync();
    expect(
      (await ann.songs(org).getSong(song))!.chordproSource,
      contains('Hallo'),
    );

    // Ann deletes the song; it disappears on Bob's device and from the set.
    await ann.songs(org).deleteSong(song);
    await ann.sync();
    await bob.sync();
    expect(await bob.songs(org).getSong(song), isNull);
    expect((await bob.sets(band).getItems(set)).map((i) => i.item.type), [
      SetItemType.pause,
    ]);
    await ann.close();
    await bob.close();
  });

  test(
    'concurrent edits of a song become a conflict, never a silent loss',
    () async {
      final (ann, bob, org, _) = await twoDevices();
      final song = await ann
          .songs(org)
          .createSong(source: '{title: Base}\n[C]base');
      await ann.sync();
      await bob.sync();

      await ann.songs(org).updateSource(song, '{title: Base}\n[C]ann');
      await bob.songs(org).updateSource(song, '{title: Base}\n[C]bob');
      await ann.sync(); // first one wins on the server
      final report = await bob.sync();
      expect(report.conflicts, 1);
      expect(
        (await bob.songs(org).getSong(song))!.chordproSource,
        contains('bob'),
      );

      // Bob keeps both: his version becomes a new song for everyone.
      final copy = await bob.engine.keepBoth(song);
      await bob.sync();
      await ann.sync();
      expect(
        (await ann.songs(org).getSong(song))!.chordproSource,
        contains('ann'),
      );
      expect(
        (await ann.songs(org).getSong(copy!))!.chordproSource,
        contains('bob'),
      );
      await ann.close();
      await bob.close();
    },
  );

  test('sets: last writer wins', () async {
    final (ann, bob, _, band) = await twoDevices();
    final set = await ann.sets(band).createSet(name: 'First');
    await ann.sync();
    await bob.sync();

    await ann.sets(band).updateSet(set, name: 'Ann');
    await ann.sync();
    // Bob is a member and cannot change sets; his device only reads.
    await bob.sync();
    expect((await bob.sets(band).watchSets().first).single.set.name, 'Ann');
    await ann.close();
    await bob.close();
  });

  test(
    'the server refuses sets from members; the change stays local',
    () async {
      final (ann, bob, _, band) = await twoDevices();
      final set = await bob.sets(band).createSet(name: 'Not allowed');
      final report = await bob.engine.sync();
      expect(report.error, isNull);
      await ann.sync();
      expect(await ann.sets(band).watchSets().first, isEmpty);
      expect((await bob.sets(band).watchSets().first).single.set.id, set);
      await ann.close();
      await bob.close();
    },
  );

  test('PDF attachments reach the other device (ADR-0009)', () async {
    final (ann, bob, org, _) = await twoDevices();
    final pdf = Uint8List.fromList(
      '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n'
          .codeUnits,
    );
    final song = await ann.songs(org).createSong(source: '{title: Score}');
    final a = await ann
        .songs(org)
        .addAttachment(song, name: 'Lead sheet', bytes: pdf, pages: 1);
    await ann.sync();

    final report = await bob.sync();
    expect(report.downloaded, 1);
    final bobs = (await bob.songs(org).getAttachments(song)).single;
    expect(bobs.id, a);
    expect(bobs.name, 'Lead sheet');
    expect(
      await FileAttachmentStorage(bob.dir).file(bobs.fileName).readAsBytes(),
      pdf,
    );

    await bob.songs(org).renameAttachment(a, 'Lead');
    await bob.sync();
    await ann.sync();
    expect((await ann.songs(org).getAttachments(song)).single.name, 'Lead');

    await ann
        .songs(org)
        .deleteAttachment((await ann.songs(org).getAttachments(song)).single);
    await ann.sync();
    await bob.sync();
    expect(await bob.songs(org).getAttachments(song), isEmpty);
    expect(await FileAttachmentStorage(bob.dir).exists(bobs.fileName), isFalse);
    await ann.close();
    await bob.close();
  });

  test('personal adjustments follow the person, not the device', () async {
    final (ann, bob, org, _) = await twoDevices();
    final song = await ann
        .songs(org)
        .createSong(source: '{title: Mine}\n[C]la');
    await ann.sync();
    await bob.sync();

    // Ann's second device: same account, new database.
    final annTablet = await Device.create(url);
    addTearDown(annTablet.close);
    await annTablet.backend.signIn(
      email: ann.backend.currentUser!.email,
      password: 'password-123',
    );
    await annTablet.sync();

    final repo = ann.songs(org);
    await repo.saveOverlay(
      (await repo.getOverlay(song))
          .copyWith(transpose: 2, notes: const Value('Solo after the bridge')),
    );
    expect((await ann.sync()).pushed, 1);

    await annTablet.sync();
    final there = await annTablet.songs(org).getOverlay(song);
    expect(there.transpose, 2);
    expect(there.notes, 'Solo after the bridge');

    // Private: Bob sees nothing of it.
    await bob.sync();
    expect((await bob.songs(org).getOverlay(song)).transpose, 0);
    await ann.close();
    await bob.close();
  });
}
