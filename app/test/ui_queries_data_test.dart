import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/account_cleanup.dart';
import 'package:setding/data/attachment_storage_memory.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/demo_song.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';

/// The queries that the screens ran themselves until issue #1204 and that
/// now live in lib/data.
void main() {
  late AppDatabase db;
  late MemoryAttachmentStorage storage;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = MemoryAttachmentStorage();
  });

  tearDown(() => db.close());

  Future<void> org(String id, String name, {bool deleted = false}) => db
      .into(db.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: id,
          name: name,
          deleted: Value(deleted),
        ),
      );

  Future<void> member(String org, String user, OrgRole role) => db
      .into(db.orgMemberships)
      .insert(
        OrgMembershipsCompanion.insert(
          id: '$org-$user',
          organizationId: org,
          userId: user,
          role: role,
        ),
      );

  test('soleAdminOrganizations names only those with the user as the only '
      'admin, not closed ones', () async {
    await org('o1', 'Alone');
    await member('o1', 'ann', OrgRole.admin);
    await member('o1', 'bob', OrgRole.member);
    await org('o2', 'Shared');
    await member('o2', 'ann', OrgRole.admin);
    await member('o2', 'bob', OrgRole.admin);
    await org('o3', 'Other');
    await member('o3', 'bob', OrgRole.admin);
    await org('o4', 'Closed', deleted: true);
    await member('o4', 'ann', OrgRole.admin);

    expect(await soleAdminOrganizations(db, 'ann'), ['Alone']);
    expect(await soleAdminOrganizations(db, 'bob'), ['Other']);
    expect(await soleAdminOrganizations(db, 'eve'), isEmpty);
  });

  test('countBandSets counts the band\'s sets outside the trash', () async {
    final sets = SetRepository(db, storage);
    await sets.createSet(name: 'A');
    final b = await sets.createSet(name: 'B');
    await sets.createSet(name: 'C');
    await sets.deleteSet(b);
    await db.into(db.bands).insert(BandsCompanion.insert(id: 'b1', name: 'X'));
    await SetRepository(db, storage, bandId: 'b1').createSet(name: 'D');

    expect(await countBandSets(db, localBandId), 2);
    expect(await countBandSets(db, 'b1'), 1);
    expect(await countBandSets(db, 'none'), 0);
  });

  test('countSongs counts the library\'s songs outside the trash', () async {
    final songs = SongRepository(db, storage);
    await songs.createSong(source: '{title: A}');
    final b = await songs.createSong(source: '{title: B}');
    await songs.deleteSong(b);
    await org('o1', 'School');
    final orgSongs = SongRepository(db, storage, libraryId: 'o1');
    await orgSongs.createSong(source: '{title: C}');
    await orgSongs.createSong(source: '{title: D}');

    expect(await songs.countSongs(), 1);
    expect(await orgSongs.countSongs(), 2);
  });

  test('songsByIds keeps the order, leaves out unknown ids and finds songs '
      'of other libraries and in the trash', () async {
    final songs = SongRepository(db, storage);
    final a = await songs.createSong(source: '{title: A}');
    final b = await songs.createSong(source: '{title: B}');
    await songs.deleteSong(b);
    await org('o1', 'School');
    final c = await SongRepository(
      db,
      storage,
      libraryId: 'o1',
    ).createSong(source: '{title: C}');

    final found = await songs.songsByIds([c, 'missing', b, a]);
    expect([for (final s in found) s.title], ['C', 'B', 'A']);
    expect(await songs.songsByIds(const []), isEmpty);
  });

  test('watchAnySet and watchAnySong find records of any band and library, '
      'deleted ones too', () async {
    await db.into(db.bands).insert(BandsCompanion.insert(id: 'b1', name: 'X'));
    final set = await SetRepository(
      db,
      storage,
      bandId: 'b1',
    ).createSet(name: 'Gig');
    await SetRepository(db, storage, bandId: 'b1').deleteSet(set);
    await org('o1', 'School');
    final orgSongs = SongRepository(db, storage, libraryId: 'o1');
    final song = await orgSongs.createSong(source: '{title: S}');
    await orgSongs.deleteSong(song);

    final s = await watchAnySet(db, set).first;
    expect(s?.name, 'Gig');
    expect(s?.deleted, isTrue);
    final g = await watchAnySong(db, song).first;
    expect(g?.title, 'S');
    expect(g?.deleted, isTrue);
    expect(await watchAnySet(db, 'missing').first, isNull);
    expect(await watchAnySong(db, 'missing').first, isNull);
  });

  group('oldestLocalChange', () {
    test('is the oldest change of the local library after since, without '
        'the demo song, the trash and other libraries', () async {
      final backup = BackupService(db, storage);
      final songs = SongRepository(db, storage);
      expect(await backup.oldestLocalChange(), isNull);

      await songs.createSong(source: demoSongSource);
      await org('o1', 'School');
      await SongRepository(
        db,
        storage,
        libraryId: 'o1',
      ).createSong(source: '{title: Org}');
      final trashed = await songs.createSong(source: '{title: Gone}');
      await songs.deleteSong(trashed);
      expect(await backup.oldestLocalChange(), isNull);

      final a = await songs.createSong(source: '{title: A}');
      final set = await SetRepository(db, storage).createSet(name: 'Gig');
      final old = DateTime(2020, 1, 1);
      final newer = DateTime(2021, 6, 1);
      await (db.update(db.songs)..where((s) => s.id.equals(a))).write(
        SongsCompanion(updatedAt: Value(newer)),
      );
      await (db.update(db.setlists)..where((s) => s.id.equals(set))).write(
        SetlistsCompanion(updatedAt: Value(old)),
      );

      expect(await backup.oldestLocalChange(), old);
      expect(await backup.oldestLocalChange(since: DateTime(2021)), newer);
      expect(await backup.oldestLocalChange(since: DateTime(2022)), isNull);
    });
  });
}
