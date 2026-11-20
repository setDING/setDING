import 'dart:io';

import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/play_history.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SongRepository songs;
  late SetRepository sets;
  late ArrangementRepository arrangements;
  late PlayHistoryRepository history;
  final today = DateTime(2026, 11, 20, 15);
  DateTime daysAgo(int days) =>
      DateTime(today.year, today.month, today.day - days);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('setding_history');
    final storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
    sets = SetRepository(db, storage);
    arrangements = ArrangementRepository(db);
    history = PlayHistoryRepository(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  /// A set of [bandId] on [date] with [songIds] in this order, as the sync
  /// stores it: without frozen values.
  Future<String> gig(
    String name,
    DateTime? date,
    List<String> songIds, {
    String bandId = localBandId,
  }) async {
    final id = await SetRepository(
      db,
      FileAttachmentStorage(dir),
      bandId: bandId,
    ).createSet(name: name, gigDate: date);
    for (final (position, songId) in songIds.indexed) {
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: '$id-$position',
              setId: id,
              songId: Value(songId),
              position: position,
              type: SetItemType.song,
            ),
          );
    }
    return id;
  }

  Future<SongPlays> plays(String songId) =>
      history.watchSongPlays(localBandId, songId, today: today).first;

  test('resolves key, tempo and sequence from song, band and set item', () {
    final song = SongEntry(
      id: 's',
      libraryId: localBandId,
      chordproSource: '',
      title: 'S',
      songKey: 'D',
      tempo: 90,
      sequence: 'V C',
      chordproProblems: 0,
      revision: 0,
      updatedAt: today,
      deleted: false,
      purged: false,
    );
    const arrangement = BandArrangement(
      bandId: localBandId,
      songId: 's',
      transpose: 2,
      tempo: 100,
      revision: 0,
      deleted: false,
    );
    const item = SetItemEntry(
      id: 'i',
      setId: 'set',
      songId: 's',
      position: 0,
      transpose: -1,
      type: SetItemType.song,
    );
    expect(
      resolvePlayed(song: song, arrangement: arrangement, item: item),
      const PlayedValues(key: 'Eb', tempo: 100, sequence: 'V C'),
    );
    expect(
      resolvePlayed(song: song, arrangement: null, item: item),
      const PlayedValues(key: 'Db', tempo: 90, sequence: 'V C'),
    );
  });

  test(
    'counts each past set once, newest first, derived until frozen',
    () async {
      final song = await songs.createSong(
        source: '{title: S}\n{key: G}\n{tempo: 80}',
      );
      final other = await songs.createSong(source: '{title: Other}');
      await gig('Twice', daysAgo(30), [song, other, song]);
      await gig('Old', daysAgo(400), [song]);
      await gig('Today', daysAgo(0), [song]);
      await gig('Undated', null, [song]);
      final deleted = await gig('Deleted', daysAgo(10), [song]);
      await sets.deleteSet(deleted);
      await gig('Without the song', daysAgo(5), [other]);

      final result = await plays(song);
      expect(result.plays.map((p) => p.setName), ['Twice', 'Old']);
      expect(result.total, 2);
      expect(result.lastYear, 1);
      expect(result.last!.date, daysAgo(30));
      expect(result.first!.setName, 'Old');
      // Nothing frozen: derived from today's song and arrangement.
      expect(result.plays.every((p) => p.approximate), isTrue);
      expect(result.last!.values, const PlayedValues(key: 'G', tempo: 80));
      // 'Without the song' has only the other one.
      expect((await plays(other)).total, 2);
    },
  );

  test('freezes the sets whose gig day has come, within the window', () async {
    final song = await songs.createSong(source: '{title: S}\n{key: D}');
    await arrangements.save(localBandId, song, transpose: 2);
    final todaySet = await gig('Today', daysAgo(0), [song]);
    await gig('Last week', daysAgo(7), [song]);
    await gig('Long ago', daysAgo(30), [song]);
    await gig('Tomorrow', daysAgo(-1), [song]);

    expect(await history.freeze(localBandId, today: today), 2);
    // A second run finds nothing left.
    expect(await history.freeze(localBandId, today: today), 0);

    Future<PlayedValues?> played(String name) async {
      final set = (await sets.watchSets().first).firstWhere(
        (s) => s.set.name == name,
      );
      return (await sets.getItems(set.set.id)).single.item.played;
    }

    expect(await played('Today'), const PlayedValues(key: 'E'));
    expect(await played('Last week'), const PlayedValues(key: 'E'));
    expect(await played('Long ago'), isNull);
    expect(await played('Tomorrow'), isNull);

    // A later change of the band's key changes only what is not frozen.
    await arrangements.save(localBandId, song, transpose: 0);
    final result = await plays(song);
    expect(
      {for (final p in result.plays) p.setName: (p.values.key, p.approximate)},
      {'Last week': ('E', false), 'Long ago': ('D', true)},
    );
    // The gig of today counts from tomorrow on.
    expect(result.plays.any((p) => p.setId == todaySet), isFalse);
  });

  test(
    'changing a song of a past set by hand updates what was played',
    () async {
      final song = await songs.createSong(source: '{title: S}\n{key: A}');
      final past = await gig('Past', daysAgo(60), [song]);
      final upcoming = await gig('Upcoming', daysAgo(-3), [song]);
      final pastItem = (await sets.getItems(past)).single.item;
      final upcomingItem = (await sets.getItems(upcoming)).single.item;

      await sets.setItemTranspose(pastItem.id, 2);
      await sets.setItemSequence(pastItem.id, 'V C V');
      await sets.setItemTranspose(upcomingItem.id, 2);

      final items = await db.select(db.setItems).get();
      final byId = {for (final i in items) i.id: i};
      expect(
        byId[pastItem.id]!.played,
        const PlayedValues(key: 'B', sequence: 'V C V'),
      );
      expect(byId[upcomingItem.id]!.played, isNull);
      expect((await plays(song)).last!.approximate, isFalse);
    },
  );

  test('a band changing its sets marks them for the sync', () async {
    await db
        .into(db.bands)
        .insert(BandsCompanion.insert(id: 'b1', name: 'Rock'));
    final song = await songs.createSong(source: '{title: S}');
    final id = await gig('Gig', daysAgo(1), [song], bandId: 'b1');
    await db.delete(db.syncOutbox).go();

    expect(await history.freeze('b1', today: today), 1);
    final outbox = await db.select(db.syncOutbox).get();
    expect(outbox.map((e) => e.recordId), [id]);
  });

  test(
    'knows when each song was last played and the most played key',
    () async {
      final a = await songs.createSong(source: '{title: A}\n{key: C}');
      final b = await songs.createSong(source: '{title: B}');
      final newest = await gig('Newest', daysAgo(3), [a]);
      await gig('Middle', daysAgo(20), [a, b]);
      await gig('Oldest', daysAgo(50), [a]);
      await gig('Next', daysAgo(-5), [a, b]);
      final newestItem = (await sets.getItems(newest)).single.item;
      await sets.setItemTranspose(newestItem.id, 2);

      expect(await history.watchLastPlayed(localBandId, today: today).first, {
        a: daysAgo(3),
        b: daysAgo(20),
      });
      final most = (await plays(a)).mostPlayedKey!;
      expect(
        (most.key.format(cp.ChordNotation.international), most.count),
        ('C', 2),
      );
    },
  );

  test('a tie of keys goes to the more recent one', () async {
    final a = await songs.createSong(source: '{title: A}\n{key: C}');
    final recent = await gig('Recent', daysAgo(3), [a]);
    await gig('Older', daysAgo(20), [a]);
    await sets.setItemTranspose(
      (await sets.getItems(recent)).single.item.id,
      7,
    );
    final most = (await plays(a)).mostPlayedKey!;
    expect(
      (most.key.format(cp.ChordNotation.international), most.count),
      ('G', 1),
    );
  });

  test('a song added to a past set is frozen as it is now', () async {
    final song = await songs.createSong(source: '{title: S}\n{key: F}');
    final past = await sets.createSet(name: 'Past', gigDate: daysAgo(40));
    final upcoming = await sets.createSet(name: 'Next', gigDate: daysAgo(-1));
    await sets.addSongs(past, [song]);
    await sets.addSongs(upcoming, [song]);
    expect(
      (await sets.getItems(past)).single.item.played,
      const PlayedValues(key: 'F'),
    );
    expect((await sets.getItems(upcoming)).single.item.played, isNull);
  });

  group('repertoire', () {
    Future<Repertoire> repertoire() =>
        history.watchRepertoire(localBandId, localBandId, today: today).first;

    test('counts the plays of every song of the library', () async {
      final hit = await songs.createSong(source: '{title: Hit}');
      final old = await songs.createSong(source: '{title: Oldie}');
      final dusty = await songs.createSong(source: '{title: Dusty}');
      final fresh = await songs.createSong(source: '{title: Fresh}');
      final gone = await songs.createSong(source: '{title: Gone}');
      await songs.deleteSong(gone);
      await gig('A', daysAgo(5), [hit, hit]);
      await gig('B', daysAgo(40), [hit, dusty]);
      await gig('C', daysAgo(400), [old, old]);
      await gig('D', daysAgo(500), [old]);
      await gig('Next', daysAgo(-3), [fresh]);
      final deleted = await gig('Deleted', daysAgo(10), [fresh]);
      await sets.deleteSet(deleted);
      await db
          .into(db.bands)
          .insert(BandsCompanion.insert(id: 'other', name: 'Other'));
      await gig('Other band', daysAgo(2), [fresh], bandId: 'other');

      final r = await repertoire();
      final byTitle = {for (final s in r.songs) s.title: s};
      expect(byTitle.keys, unorderedEquals(['Hit', 'Oldie', 'Dusty', 'Fresh']));
      expect(
        (byTitle['Hit']!.total, byTitle['Hit']!.lastYear, byTitle['Hit']!.last),
        (2, 2, daysAgo(5)),
      );
      expect((byTitle['Oldie']!.total, byTitle['Oldie']!.lastYear), (2, 0));
      expect(byTitle['Fresh']!.last, isNull);

      expect(
        [for (final s in r.mostPlayed(lastYear: true)) s.title],
        ['Hit', 'Dusty'],
      );
      // A tie goes to the song played more recently.
      expect(
        [for (final s in r.mostPlayed(lastYear: false)) s.title],
        ['Hit', 'Oldie', 'Dusty'],
      );
      expect(
        [for (final s in r.mostPlayed(lastYear: false, limit: 1)) s.title],
        ['Hit'],
      );
      expect([for (final s in r.notPlayedFor(6)) s.title], ['Oldie']);
      expect([for (final s in r.notPlayedFor(1)) s.title], ['Oldie', 'Dusty']);
      expect([for (final s in r.neverPlayed) s.title], ['Fresh']);
      expect(staleBefore(DateTime(2026, 3, 31), 1), DateTime(2026, 2, 31));
    });
  });
}
