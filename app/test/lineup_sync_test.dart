import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';
import 'package:setding/ui/overview/overview_screen.dart'
    show moreSets, overviewSet;

import 'fake_backend.dart';

/// Lineup per set and substitutes on the device (ADR-0061, #1008).
const _leo = AuthUser(id: 'leo', email: 'leo@example.test', name: 'Leo');
const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend server;
  late BandService bands;
  late SyncEngine engine;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_lineup');
    server = FakeSyncBackend(user: _ann);
    server.addBand('b1', 'Rock', admin: _leo, organizationId: 'o1');
    bands = BandService(db, server);
    engine = SyncEngine(
      db,
      server,
      bands,
      copies: BandCopyService(db, FileAttachmentStorage(dir)),
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  void song(String id) => server.putSong(
    RemoteSong(
      id: id,
      organizationId: 'o1',
      title: id,
      chordpro: '{title: $id}',
    ),
  );

  RemoteSet set(
    String id, {
    List<String>? lineup,
    List<String> songs = const [],
    String band = 'b1',
    DateTime? gig,
  }) => server.putSet(
    RemoteSet(
      id: id,
      bandId: band,
      name: id,
      gigDate: gig,
      items: [
        for (final s in songs)
          RemoteSetItem(id: '$id-$s', type: SetItemType.song, songId: s),
      ],
      lineup: lineup ?? const [],
      lineupCustom: lineup != null,
    ),
    by: 'leo',
  );

  void arrangement(String songId, int transpose) => server.putArrangement(
    RemoteArrangement(
      id: 'a-$songId',
      bandId: 'b1',
      songId: songId,
      transpose: transpose,
    ),
    by: 'leo',
  );

  Future<List<String>> localSets() async => [
    for (final s in await (db.select(
      db.setlists,
    )..where((s) => s.deleted.equals(false))).get())
      s.id,
  ];

  Future<List<String>> localArrangements() async => [
    for (final a in await db.select(db.bandArrangements).get()) a.songId,
  ];

  group('as a substitute', () {
    setUp(() => server.addOrgMember('o1', _ann, OrgRole.member));

    test('gets the sets they are in the lineup of, the arrangements of their '
        'songs and the band as a substitute band', () async {
      song('s1');
      song('s2');
      arrangement('s1', 2);
      arrangement('s2', -1);
      set('gig', lineup: ['leo', 'ann'], songs: ['s1']);
      set('other', lineup: ['leo'], songs: ['s2']);
      set('whole', songs: ['s2']);

      final report = await engine.sync();
      expect(report.error, isNull);
      expect(await localSets(), ['gig']);
      expect(await localArrangements(), ['s1']);
      final stored = await (db.select(
        db.setlists,
      )..where((s) => s.id.equals('gig'))).getSingle();
      expect(stored.lineup, ['leo', 'ann']);
      expect(stored.lineupCustom, isTrue);
      final band = (await bands.watchBands('ann').first).singleWhere(
        (b) => b.id == 'b1',
      );
      expect(band.substitute, isTrue);
      expect(band.name, 'Rock');
      expect(band.canManageSets, isFalse);
      expect(band.canManageBand, isFalse);

      // A second sync keeps the band (the organizations do not list it).
      await engine.sync();
      expect(
        (await bands.watchBands('ann').first).map((b) => b.id),
        contains('b1'),
      );
      expect(await localSets(), ['gig']);
    });

    test('loses a set when taken out of the lineup, and the band with the '
        'last one', () async {
      song('s1');
      arrangement('s1', 2);
      set('gig', lineup: ['ann'], songs: ['s1']);
      set('gig2', lineup: ['ann']);
      await engine.sync();
      expect(await localSets(), unorderedEquals(['gig', 'gig2']));

      set('gig', lineup: ['leo'], songs: ['s1']);
      await engine.sync();
      expect(await localSets(), ['gig2']);
      expect(await localArrangements(), isEmpty);

      set('gig2'); // back to the whole band
      await engine.sync();
      expect(await localSets(), isEmpty);
      expect(
        (await bands.watchBands('ann').first).map((b) => b.id),
        isNot(contains('b1')),
      );
    });

    test('becomes a band member: the band is an ordinary band with all its '
        'sets', () async {
      set('gig', lineup: ['ann']);
      set('whole');
      await engine.sync();
      expect(await localSets(), ['gig']);

      server.addMember('b1', _ann, BandRole.member);
      await engine.sync();
      expect(await localSets(), unorderedEquals(['gig', 'whole']));
      final band = (await bands.watchBands('ann').first).singleWhere(
        (b) => b.id == 'b1',
      );
      expect(band.substitute, isFalse);
    });

    test(
      'a server without the lineup route keeps what the device has',
      () async {
        set('gig', lineup: ['ann']);
        await engine.sync();
        server.lineupFail = true;
        final report = await engine.sync();
        expect(report.error, isNull);
        expect(await localSets(), ['gig']);
      },
    );

    test('never pushes the sets they play', () async {
      set('gig', lineup: ['ann']);
      await engine.sync();
      final pushes = server.pushCount;
      await engine.sync();
      expect(server.pushCount, pushes);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    });
  });

  test('a band member taken out of the band but kept in a lineup keeps only '
      'that set', () async {
    final m = server.addMember('b1', _ann, BandRole.member);
    set('gig', lineup: ['ann']);
    set('whole');
    await engine.sync();
    expect(await localSets(), unorderedEquals(['gig', 'whole']));

    server.members.remove(m);
    await engine.sync();
    expect(await localSets(), ['gig']);
    final band = (await bands.watchBands('ann').first).singleWhere(
      (b) => b.id == 'b1',
    );
    expect(band.substitute, isTrue);
  });

  test('a set leader pushes the lineup, and the whole band again', () async {
    server.user = _leo;
    final storage = FileAttachmentStorage(dir);
    await engine.sync();
    final repo = SetRepository(db, storage, bandId: 'b1', userId: 'leo');
    final id = await repo.createSet(name: 'Gig');
    await repo.setLineup(id, ['leo', 'ann', 'ann']);
    await engine.sync();
    expect(server.sets[id]!.lineup, ['leo', 'ann']);
    expect(server.sets[id]!.lineupCustom, isTrue);

    await repo.setLineup(id, null);
    await engine.sync();
    expect(server.sets[id]!.lineup, isEmpty);
    expect(server.sets[id]!.lineupCustom, isFalse);
  });

  test('copying a set into another band gives it to the whole band', () async {
    server.user = _leo;
    await engine.sync();
    final storage = FileAttachmentStorage(dir);
    final repo = SetRepository(db, storage, bandId: 'b1', userId: 'leo');
    final id = await repo.createSet(name: 'Gig');
    await repo.setLineup(id, ['leo']);
    final copy = await BandCopyService(
      db,
      storage,
    ).copySet(id, targetBandId: localBandId, targetLibraryId: localBandId);
    final row = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(copy))).getSingle();
    expect(row.lineup, isEmpty);
    expect(row.lineupCustom, isFalse);
  });

  group('planned for the user', () {
    SetlistEntry entry(String id, {List<String>? lineup, DateTime? gig}) =>
        SetlistEntry(
          id: id,
          bandId: 'b1',
          name: id,
          gigDate: gig,
          revision: 0,
          updatedAt: DateTime(2026, 1, 1),
          deleted: false,
          purged: false,
          lineup: lineup ?? const [],
          lineupCustom: lineup != null,
        );

    test('plannedFor: the lineup, otherwise the band members', () {
      expect(plannedFor(entry('a'), userId: 'ann'), isTrue);
      expect(plannedFor(entry('a'), userId: 'ann', bandMember: false), isFalse);
      expect(plannedFor(entry('a', lineup: ['ann']), userId: 'ann'), isTrue);
      expect(plannedFor(entry('a', lineup: ['leo']), userId: 'ann'), isFalse);
      expect(plannedFor(entry('a', lineup: ['leo']), userId: null), isTrue);
    });

    test('the overview skips the sets the user does not play', () {
      final day = DateTime(2026, 6, 10);
      final sets = [
        SetSummary(entry('first', lineup: ['leo'], gig: day), 0),
        SetSummary(entry('second', gig: day.add(const Duration(days: 1))), 0),
        SetSummary(entry('third', gig: day.add(const Duration(days: 2))), 0),
      ];
      bool planned(SetlistEntry s) => plannedFor(s, userId: 'ann');
      final shown = overviewSet(sets, day, planned: planned)!;
      expect((shown.summary.set.id, shown.upcoming), ('second', true));
      expect(
        [for (final s in moreSets(sets, day, planned: planned)) s.set.id],
        ['first', 'third'],
      );
      expect(overviewSet(sets, day)!.summary.set.id, 'first');
    });

    test('the song list marks only gigs the user plays', () async {
      final storage = FileAttachmentStorage(dir);
      server.user = _leo;
      await engine.sync();
      song('s1');
      song('s2');
      await engine.sync();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      set('mine', lineup: ['ann'], songs: ['s1'], gig: tomorrow);
      set('theirs', lineup: ['leo'], songs: ['s2'], gig: tomorrow);
      await engine.sync();
      final repo = SetRepository(
        db,
        storage,
        bandId: 'b1',
        userId: 'ann',
        bandMember: false,
      );
      final gigs = await repo.watchUpcomingGigs().first;
      expect(gigs.keys, ['s1']);
    });
  });
}
