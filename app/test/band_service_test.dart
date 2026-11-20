import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show TableUpdateQuery, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/annotation_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/band_view.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';

import 'fake_backend.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

void main() {
  late AppDatabase db;
  late FakeSyncBackend backend;
  late BandService service;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeSyncBackend(user: _ann);
    service = BandService(db, backend);
  });
  tearDown(() => db.close());

  Future<List<BandView>> bands([String userId = 'ann']) =>
      service.watchBands(userId).first;

  BandView band(List<BandView> all, String id) =>
      all.firstWhere((b) => b.id == id);

  test('signed out, only the local library is available', () async {
    expect(await service.watchBands(null).first, [BandView.local]);
  });

  test('stores organizations, bands and members from the server', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.organizations['o1'] = 'School';
    backend.addMember('b1', _bob, BandRole.member);
    await service.refresh();

    final all = await bands();
    expect(all.first, BandView.local);
    final rock = band(all, 'b1');
    expect(rock.organizationName, 'School');
    expect(rock.libraryId, 'o1');
    expect(rock.isBandAdmin, isTrue);
    expect(rock.isOrgAdmin, isTrue);
    final members = await service.watchMembers('b1').first;
    expect(members.map((m) => m.userName), ['Ann', 'Bob']);
    final people = await service.watchOrgMembers('o1').first;
    expect(people.map((m) => m.userId), unorderedEquals(['ann', 'bob']));
  });

  SongEntry song({String? createdBy, String? updatedBy}) => SongEntry(
    id: 's1',
    libraryId: 'o1',
    chordproSource: '',
    title: 'Song',
    revision: 1,
    updatedAt: DateTime(2026),
    deleted: false,
    purged: false,
    createdBy: createdBy,
    updatedBy: updatedBy,
    chordproProblems: 0,
  );

  test('permissions follow the roles (ADR-0023)', () async {
    // Ann administers the organization; Bob is a member of "Rock" only.
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addBand('b2', 'Jazz', admin: _ann, organizationId: 'o1');
    backend.addMember('b1', _bob, BandRole.member);

    backend.user = _bob;
    await service.refresh();
    var all = await bands('bob');
    expect(all.map((b) => b.id), [localBandId, 'b1']);
    final rock = band(all, 'b1');
    expect(rock.library.canCreateSongs, isFalse);
    expect(rock.library.canEditSong(song(createdBy: 'bob')), isFalse);
    expect(rock.library.canDeleteSongs, isFalse);
    expect(rock.canManageSets, isFalse);
    expect(rock.canManageBand, isFalse);

    // Leader of another band of the organization: creates songs and edits
    // only the own ones, as long as nobody else changed them.
    backend.addMember('b2', _bob, BandRole.admin);
    await service.refresh();
    all = await bands('bob');
    final library = band(all, 'b1').library;
    expect(library.canCreateSongs, isTrue);
    expect(
      library.canEditSong(song(createdBy: 'bob', updatedBy: 'bob')),
      isTrue,
    );
    expect(
      library.canEditSong(song(createdBy: 'bob', updatedBy: 'ann')),
      isFalse,
    );
    // The same rule for song lists, which have no full song (#314).
    expect(library.canEditSongBy(createdBy: 'bob', updatedBy: 'bob'), isTrue);
    expect(library.canEditSongBy(createdBy: 'bob', updatedBy: 'ann'), isFalse);
    expect(
      library.canEditSong(song(createdBy: 'ann', updatedBy: 'ann')),
      isFalse,
    );
    expect(library.canEditSong(song()), isFalse);
    expect(library.canDeleteSongs, isFalse);
    expect(band(all, 'b1').canManageSets, isFalse);
    expect(band(all, 'b2').canManageSets, isTrue);
  });

  test('set planners manage sets, not the band', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addMember('b1', _bob, BandRole.planner);
    backend.user = _bob;
    await service.refresh();
    final rock = band(await bands('bob'), 'b1');
    expect(rock.canManageSets, isTrue);
    expect(rock.canManageBand, isFalse);
    expect(rock.library.canCreateSongs, isFalse);
  });

  test('librarians maintain the whole library', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addMember('b1', _bob, BandRole.member);
    backend.orgMembers.singleWhere((m) => m.user.id == 'bob').role =
        OrgRole.librarian;
    backend.user = _bob;
    await service.refresh();
    final rock = band(await bands('bob'), 'b1');
    expect(rock.library.canCreateSongs, isTrue);
    expect(rock.library.canEditSong(song(createdBy: 'ann')), isTrue);
    expect(rock.library.canDeleteSongs, isTrue);
    expect(rock.canManageSets, isFalse);
    expect(rock.canManageBand, isFalse);
  });

  test('organization admins see all bands of their organization', () async {
    backend.addBand('b1', 'Rock', admin: _bob, organizationId: 'o1');
    backend.addOrgMember('o1', _ann, OrgRole.admin);
    await service.refresh();
    final rock = band(await bands(), 'b1');
    expect(rock.role, isNull);
    expect(rock.canManageBand, isTrue);
    expect(rock.canManageSets, isTrue);
    expect(rock.library.canDeleteSongs, isTrue);
  });

  test('an unchanged refresh writes nothing', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addMember('b1', _bob, BandRole.member);
    await service.refresh();

    final updates = <Object>[];
    final sub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.organizations,
            db.orgMemberships,
            db.bands,
            db.memberships,
          ]),
        )
        .listen(updates.add);
    await service.refresh();
    await pumpEventQueue();
    expect(updates, isEmpty);

    // Bob's membership is replaced: the old row is deleted, the new one
    // written.
    backend.members.removeWhere((m) => m.user.id == 'bob');
    backend.addMember('b1', _bob, BandRole.admin);
    await service.refresh();
    await pumpEventQueue();
    expect(updates, isNotEmpty);
    final members = await service.watchMembers('b1').first;
    expect(members.map((m) => (m.userId, m.role)), [
      ('ann', BandRole.admin),
      ('bob', BandRole.admin),
    ]);
    await sub.cancel();
  });

  test('rapid changes end with the latest state, never an older one', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await service.refresh();
    final names = <String>[];
    final sub = service
        .watchBands('ann')
        .listen((all) => names.add(band(all, 'b1').name));
    await pumpEventQueue();
    for (var i = 0; i < 10; i++) {
      await (db.update(db.bands)..where((b) => b.id.equals('b1'))).write(
        BandsCompanion(name: Value('Rock $i')),
      );
    }
    await pumpEventQueue(times: 50);
    expect(names.last, 'Rock 9');
    // Changes during a load are combined into one more load.
    expect(names.length, lessThan(11));
    final order = [for (final n in names.skip(1)) int.parse(n.split(' ')[1])];
    expect(order, orderedEquals([...order]..sort()));
    await sub.cancel();
  });

  test('concurrent refreshes share one request', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await Future.wait([service.refresh(), service.refresh()]);
    expect(backend.fetchOrganizationsCalls, 1);
    await service.refresh();
    expect(backend.fetchOrganizationsCalls, 2);
  });

  test('bands and organizations the user lost are hidden', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    backend.addBand('b2', 'Jazz', admin: _bob, organizationId: 'o2');
    backend.addMember('b2', _ann, BandRole.member);
    await service.refresh();
    expect((await bands()).map((b) => b.id), [localBandId, 'b2', 'b1']);

    final membership = backend.orgMembers.firstWhere(
      (m) => m.scopeId == 'o2' && m.user.id == 'ann',
    );
    await service.removeOrgMember(membership.id);
    expect((await bands()).map((b) => b.id), [localBandId, 'b1']);
    expect((await service.watchOrganizations('ann').first).map((o) => o.id), [
      'o1',
    ]);
  });

  test('creates a band in a new or an existing organization', () async {
    final first = await service.createBand('Rock');
    var all = await bands();
    final rock = band(all, first);
    expect(rock.organizationName, 'Rock');
    final second = await service.createBand(
      'Jazz',
      organizationId: rock.organizationId,
    );
    all = await bands();
    expect(band(all, second).organizationId, rock.organizationId);
    expect(await service.watchOrganizations('ann').first, hasLength(1));
  });

  test('reports the last admin and people outside the organization', () async {
    backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    await service.refresh();
    final own = backend.members.single;
    await expectLater(
      service.setRole(own.id, BandRole.member),
      throwsA(
        isA<BackendException>().having(
          (e) => e.kind,
          'kind',
          BackendErrorKind.lastAdmin,
        ),
      ),
    );
    await expectLater(
      service.addBandMember('b1', 'stranger', BandRole.member),
      throwsA(
        isA<BackendException>().having(
          (e) => e.kind,
          'kind',
          BackendErrorKind.notOrgMember,
        ),
      ),
    );
  });

  group('copy', () {
    late Directory dir;
    late AttachmentStorage storage;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('setding_copy');
      storage = FileAttachmentStorage(dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('a copy gets the adjustments of the person who copies', () async {
      final local = SongRepository(db, storage, userId: 'ann');
      final id = await local.createSong(source: '{title: Mine}');
      await local.saveOverlay((await local.getOverlay(id)).copyWith(capo: 2));

      final copy = (await BandCopyService(
        db,
        storage,
        userId: 'ann',
      ).copySongs([id], 'o1')).single;
      SongRepository org(String user) =>
          SongRepository(db, storage, libraryId: 'o1', userId: user);
      expect((await org('ann').getOverlay(copy)).capo, 2);
      expect((await org('bob').getOverlay(copy)).capo, 0);
    });

    test('a copy gets the annotations of the person who copies', () async {
      final local = SongRepository(db, storage, userId: 'ann');
      final id = await local.createSong(source: '{title: Mine}');
      const stroke = AnnotationStroke(
        id: 'x',
        tool: AnnotationTool.pen,
        width: 0.004,
        points: [0.1, 0.1, 0.2, 0.2],
      );
      await AnnotationRepository(db, userId: 'ann').apply(id, put: [stroke]);

      final copy = (await BandCopyService(
        db,
        storage,
        userId: 'ann',
      ).copySongs([id], 'o1')).single;
      final ann = await AnnotationRepository(
        db,
        userId: 'ann',
      ).watch(copy).first;
      expect(ann.single.points, stroke.points);
      expect(ann.single.id, isNot('x'), reason: 'a new stroke');
      expect(
        await AnnotationRepository(db, userId: 'bob').watch(copy).first,
        isEmpty,
      );
    });

    test('a copied attachment gets its own server file', () async {
      final org = SongRepository(db, storage, libraryId: 'o1');
      final id = await org.createSong(source: '{title: Synced}');
      final a = await org.addAttachment(
        id,
        name: 'Score',
        bytes: Uint8List.fromList([4, 5]),
      );
      // As after a sync: the original's file is on the server.
      await (db.update(db.attachments)..where((x) => x.id.equals(a))).write(
        const AttachmentsCompanion(remoteFile: Value('score_abc.pdf')),
      );
      // A second attachment whose file is not downloaded yet.
      final missing = await org.addAttachment(
        id,
        name: 'Missing',
        bytes: Uint8List.fromList([6]),
      );
      final missingFile = (await org.getAttachments(id))
          .firstWhere((x) => x.id == missing)
          .fileName;
      await storage.delete(missingFile);

      final copies = await BandCopyService(db, storage).copySongs([id], 'o2');
      final copied = await SongRepository(
        db,
        storage,
        libraryId: 'o2',
      ).getAttachments(copies.single);
      expect(copied.map((x) => x.remoteFile), [null, null]);
      final score = copied.firstWhere((x) => x.name == 'Score');
      expect(await storage.file(score.fileName).readAsBytes(), [4, 5]);
      final notThere = copied.firstWhere((x) => x.name == 'Missing');
      expect(await storage.exists(notThere.fileName), isFalse);
    });

    test(
      'copies songs with attachments and adjustments into a library',
      () async {
        final local = SongRepository(db, storage);
        final id = await local.createSong(source: '{title: Mine}\n[C]x');
        final pdf = await local.addAttachment(
          id,
          name: 'Score',
          bytes: Uint8List.fromList([1, 2, 3]),
        );
        await local.saveOverlay(
          (await local.getOverlay(id))
              .copyWith(transpose: 2, liveView: Value(pdf)),
        );

        final copies = await BandCopyService(db, storage).copySongs([id], 'o1');
        final org = SongRepository(db, storage, libraryId: 'o1');
        final copy = (await org.getSong(copies.single))!;
        expect(copy.title, 'Mine');
        final files = await org.getAttachments(copy.id);
        expect(files.single.name, 'Score');
        expect(await storage.file(files.single.fileName).readAsBytes(), [
          1,
          2,
          3,
        ]);
        final overlay = await org.getOverlay(copy.id);
        expect(overlay.transpose, 2);
        expect(overlay.liveView, files.single.id);
        // The original stays in the local library.
        expect((await local.watchSongs().first).map((s) => s.id), [id]);
      },
    );

    test(
      'copies a set with its songs into a band of another library',
      () async {
        await db
            .into(db.bands)
            .insert(BandsCompanion.insert(id: 'b1', name: 'Rock'));
        final songs = SongRepository(db, storage);
        final a = await songs.createSong(source: '{title: A}');
        final sets = SetRepository(db, storage);
        final setId = await sets.createSet(name: 'Gig');
        await sets.addSongs(setId, [a, a]);
        await sets.addMarker(setId, SetItemType.pause, 'Break');

        final copyId = await BandCopyService(
          db,
          storage,
        ).copySet(setId, targetBandId: 'b1', targetLibraryId: 'o1');
        final copied = SetRepository(db, storage, bandId: 'b1');
        final items = await copied.getItems(copyId);
        expect(items.map((i) => i.item.type), [
          SetItemType.song,
          SetItemType.song,
          SetItemType.pause,
        ]);
        // A song used twice is copied once, into the target library.
        expect(items[0].song!.id, items[1].song!.id);
        expect(items[0].song!.id, isNot(a));
        expect(items[0].song!.libraryId, 'o1');
      },
    );

    test('a set copied within the same library keeps its songs', () async {
      await db
          .into(db.bands)
          .insert(BandsCompanion.insert(id: 'b1', name: 'Rock'));
      final songs = SongRepository(db, storage);
      final a = await songs.createSong(source: '{title: A}');
      final sets = SetRepository(db, storage);
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a]);
      final copyId = await BandCopyService(db, storage).copySet(
        setId,
        targetBandId: 'b1',
        targetLibraryId: localBandId,
        copySongs: false,
      );
      final items = await SetRepository(
        db,
        storage,
        bandId: 'b1',
      ).getItems(copyId);
      expect(items.single.song!.id, a);
    });
  });
}
