import 'dart:io';
import 'dart:typed_data';

import 'dart:convert';

import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/attachment_storage.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/import_export.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SongRepository songs;
  late SetRepository sets;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('setding_test');
    final storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
    sets = SetRepository(db, storage);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  group('SongRepository', () {
    test('creates a song and extracts metadata', () async {
      final id = await songs.createSong(
        source: '{title: Hello}\n{artist: Band}\n{key: G}\n{tempo: 100}\n[G]Hi',
      );
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Hello');
      expect(song.artist, 'Band');
      expect(song.songKey, 'G');
      expect(song.tempo, 100);
      expect(song.libraryId, localBandId);
    });

    test('PDF-only song uses given title and artist', () async {
      final id = await songs.createSong(title: 'Horns', artist: 'Brass');
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Horns');
      expect(song.chordproSource, '');
    });

    test('updateSource keeps the title if the source has none', () async {
      final id = await songs.createSong(title: 'Keep me');
      await songs.updateSource(id, '[C]No title here');
      final song = (await songs.getSong(id))!;
      expect(song.title, 'Keep me');
      // The revision is the server's (ADR-0004); local edits don't change it.
      expect(song.revision, 0);
    });

    test('search matches title, artist and lyrics', () async {
      await songs.createSong(source: '{title: Alpha}\nsunshine');
      await songs.createSong(source: '{title: Beta}\n{artist: Gamma}');
      expect(
        (await songs.watchSongs(query: 'sun').first).single.title,
        'Alpha',
      );
      expect((await songs.watchSongs(query: 'gam').first).single.title, 'Beta');
      expect(await songs.watchSongs().first, hasLength(2));
    });

    test('full-text search ignores chords, accents and word order', () async {
      await songs.createSong(
        source:
            '{title: Über den Wolken}\n{artist: Reinhard Mey}\n'
            '[C]Hel[G]lo sun[Am]shine\n{c: Capo 2 – slowly}',
      );
      await songs.createSong(source: '{title: Other}\n[D]rain');
      Future<List<String>> find(String q) async => [
        for (final s in await songs.watchSongs(query: q).first) s.title,
      ];
      expect(await find('hello'), ['Über den Wolken']);
      expect(await find('uber'), ['Über den Wolken']);
      expect(await find('mey wolk'), ['Über den Wolken']);
      expect(await find('slowly'), ['Über den Wolken']);
      expect(await find('wolken rain'), isEmpty);
      // Quotes and operators are search text, not FTS syntax.
      expect(await find('"rain" OR'), isEmpty);
      expect(await find('NEAR('), isEmpty);
      expect(await find('!!'), isEmpty);
      // The list query searches the same way.
      expect(
        (await songs.watchSongList(query: 'hello').first).single.title,
        'Über den Wolken',
      );
      // Editing updates the index.
      final id = (await songs.watchSongs(query: 'rain').first).single.id;
      await songs.updateSource(id, '{title: Other}\n[D]snow');
      expect(await find('rain'), isEmpty);
      expect(await find('snow'), ['Other']);
    });

    test('attachments are stored and size-limited', () async {
      final id = await songs.createSong(title: 'X');
      final attId = await songs.addAttachment(
        id,
        name: 'Piano',
        bytes: Uint8List.fromList([1, 2, 3]),
        pages: 2,
      );
      final list = await songs.getAttachments(id);
      expect(list.single.id, attId);
      expect(
        await File('${dir.path}/${list.single.fileName}').exists(),
        isTrue,
      );
      expect((await songs.watchAttachmentCounts().first)[id], 1);

      expect(
        () => songs.addAttachment(
          id,
          name: 'Big',
          bytes: Uint8List(maxAttachmentBytes + 1),
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );

      await songs.deleteAttachment(list.single);
      expect(await songs.getAttachments(id), isEmpty);
      // The file is deleted once the deletion can no longer be undone.
      await songs.purgeFiles(list);
      expect(
        await File('${dir.path}/${list.single.fileName}').exists(),
        isFalse,
      );
    });

    test('overlay defaults and saving', () async {
      final id = await songs.createSong(title: 'X');
      expect((await songs.getOverlay(id)).transpose, 0);
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(transpose: 2, capo: 1),
      );
      final overlay = await songs.getOverlay(id);
      expect(overlay.transpose, 2);
      expect(overlay.capo, 1);
    });

    test('overlay fields can be reset to null', () async {
      final id = await songs.createSong(title: 'X');
      final attId = await songs.addAttachment(
        id,
        name: 'P',
        bytes: Uint8List.fromList([1]),
      );
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(
          nashville: const Value(true),
          notes: const Value('note'),
          liveView: Value(attId),
        ),
      );
      expect((await songs.getOverlay(id)).nashville, isTrue);

      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(
          nashville: const Value(null),
          notes: const Value(null),
          liveView: const Value(null),
        ),
      );
      final overlay = await songs.getOverlay(id);
      expect(overlay.nashville, isNull);
      expect(overlay.notes, isNull);
      expect(overlay.liveView, isNull);
    });

    test(
      'a song has a keyboard program that can be removed (ADR-0039)',
      () async {
        final id = await songs.createSong(title: 'X');
        expect(await songs.midiProgram(id, 'nordStage3'), isNull);
        final seen = <MidiProgram?>[];
        final sub = songs
            .watchMidiPrograms(id, 'nordStage3')
            .map((p) => p['nordStage3'])
            .listen(seen.add);
        await pumpEventQueue();

        const program = MidiProgram(msb: 0, lsb: 2, program: 12);
        await songs.updateOverlay(id, (o) => o.copyWith(transpose: 2));
        await songs.setMidiProgram(
          id,
          'nordStage3',
          program,
          deviceProfile: 'nordStage3',
        );
        await pumpEventQueue();
        expect(await songs.midiProgram(id, 'nordStage3'), program);
        expect((await songs.getOverlay(id)).transpose, 2);

        // Other adjustments keep it.
        await songs.updateOverlay(id, (o) => o.copyWith(transpose: 3));
        expect(await songs.midiProgram(id, 'nordStage3'), program);

        await songs.removeMidiProgram(
          id,
          'nordStage3',
          deviceProfile: 'nordStage3',
        );
        await pumpEventQueue();
        expect(await songs.midiProgram(id, 'nordStage3'), isNull);
        expect((await songs.getOverlay(id)).transpose, 3);
        await sub.cancel();
        // Only changes of the program itself.
        expect(seen, [null, program, null]);
      },
    );

    test('a song keeps one keyboard program per profile (ADR-0042)', () async {
      final id = await songs.createSong(title: 'X');
      const nord = MidiProgram(msb: 0, lsb: 2, program: 12);
      const generic = MidiProgram(program: 4);
      await songs.setMidiProgram(
        id,
        'nordStage3',
        nord,
        deviceProfile: 'nordStage3',
      );
      await songs.setMidiProgram(
        id,
        'generic',
        generic,
        deviceProfile: 'nordStage3',
      );
      expect(await songs.midiProgram(id, 'nordStage3'), nord);
      expect(await songs.midiProgram(id, 'generic'), generic);
      expect(await songs.midiProgram(id, 'motifXf'), isNull);
      await songs.removeMidiProgram(id, 'generic', deviceProfile: 'generic');
      expect(await songs.midiProgram(id, 'generic'), isNull);
      expect(await songs.midiProgram(id, 'nordStage3'), nord);

      // Removing the last one keeps a v0.16.0 program from counting again.
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(midi: const Value(generic)),
      );
      await songs.removeMidiProgram(
        id,
        'nordStage3',
        deviceProfile: 'nordStage3',
      );
      final overlay = await songs.getOverlay(id);
      expect(overlay.midiPrograms, const MidiPrograms());
      expect(await songs.midiProgram(id, 'nordStage3'), isNull);
    });

    test('restoring the programs undoes a change, also to "never written" '
        '(#607)', () async {
      final id = await songs.createSong(title: 'X');
      const legacy = MidiProgram(msb: 0, lsb: 2, program: 12);
      const organ = MidiProgram(program: 4);
      // Only a v0.16.0 program: the map was never written.
      await songs.saveOverlay(
        (await songs.getOverlay(id)).copyWith(midi: const Value(legacy)),
      );
      final before = (await songs.getOverlay(id)).midiPrograms;
      expect(before, isNull);
      await songs.setMidiProgram(
        id,
        'nordStage3',
        organ,
        deviceProfile: 'nordStage3',
      );
      expect(await songs.midiProgram(id, 'nordStage3'), organ);

      await songs.restoreMidiPrograms(id, before);
      expect((await songs.getOverlay(id)).midiPrograms, isNull);
      expect(await songs.midiProgram(id, 'nordStage3'), legacy);
    });

    test('stored programs per profile that cannot be read are none', () async {
      final id = await songs.createSong(title: 'X');
      await songs.updateOverlay(id, (o) => o.copyWith(transpose: 1));
      for (final stored in [
        'not json',
        '[]',
        '{"nordStage3": {"program": 300}}',
      ]) {
        await db.customStatement(
          'UPDATE personal_overlays SET midi_programs = ?',
          [stored],
        );
        expect(
          await songs.midiProgram(id, 'nordStage3'),
          isNull,
          reason: stored,
        );
      }
    });

    test('a stored keyboard program that cannot be read is none', () async {
      final id = await songs.createSong(title: 'X');
      await songs.updateOverlay(id, (o) => o.copyWith(transpose: 1));
      for (final stored in ['not json', '{"program": 300}', '[]']) {
        await db.customStatement('UPDATE personal_overlays SET midi = ?', [
          stored,
        ]);
        expect(
          await songs.midiProgram(id, 'nordStage3'),
          isNull,
          reason: stored,
        );
      }
    });
  });

  group('Tags, sorting and import', () {
    test('sorts by sorttitle and filters by tag', () async {
      await songs.createSong(
        source: '{title: The Zebra}\n{sorttitle: Zebra}\n{tag: Rock}',
      );
      await songs.createSong(
        source: '{title: Apple}\n{tag: Ballad}\n{tag: rock}',
      );
      await songs.createSong(source: '{title: Mango}');
      expect((await songs.watchSongs().first).map((s) => s.title), [
        'Apple',
        'Mango',
        'The Zebra',
      ]);
      expect((await songs.watchSongs(tag: 'Rock').first).map((s) => s.title), [
        'Apple',
        'The Zebra',
      ]);
      expect(await songs.watchTags().first, ['Ballad', 'Rock']);
    });

    test('the import reports songs with ChordPro problems (#314)', () async {
      final service = ImportExportService(songs, sets);
      ImportFile file(String name, String text) =>
          ImportFile(name, Uint8List.fromList(utf8.encode(text)));
      final result = await service.importFiles([
        file('ok.cho', '{title: Fine}\n[C]a\n'),
        file('note.cho', '{title: Washed}\n{c: Chorus} (a cappella)\n[G]b\n'),
        file('open.cho', '{title: Open}\n[G]b [Am\n{c: x} y\n'),
        file('broken.cho', '{title: Broken\n[C]a\n'),
      ]);
      expect(result.imported, 4);
      expect(
        [for (final p in result.problems) (p.title, p.count, p.fixable)],
        // An unclosed {title} gives no title: the file name stands in.
        [('Washed', 1, true), ('Open', 2, true), ('broken', 1, false)],
      );
      final listed = {
        for (final s in await songs.watchSongList().first) s.title: s.problems,
      };
      expect(listed['Fine'], 0);
      expect(listed['Washed'], 1);

      // Fixing changes only what can be fixed; the counts follow.
      expect(
        await service.fixProblems([for (final p in result.problems) p.songId]),
        2,
      );
      final washed = await songs.getSong(result.problems.first.songId);
      expect(
        washed!.chordproSource,
        '{title: Washed}\n{comment_italic: (a cappella)}\n{c: Chorus}\n'
        '[G]b\n',
      );
      expect(washed.chordproProblems, 0);
      final open = await songs.getSong(result.problems[1].songId);
      expect(open!.chordproProblems, 1);
    });

    test('the import reports short-form section labels (#672)', () async {
      final service = ImportExportService(songs, sets);
      ImportFile file(String name, String text) =>
          ImportFile(name, Uint8List.fromList(utf8.encode(text)));
      final result = await service.importFiles([
        file('short.cho', '{title: Short}\n{sov: Verse 1}\n[C]a\n{eov}\n'),
        file('new.cho', '{title: New}\n{sov: label="V"}\n[C]a\n{eov}\n'),
      ]);
      expect(result.problems, isEmpty);
      expect(result.legacyLabels, hasLength(1));
      expect(result.needsReview, isTrue);
      // A short-form label is no problem: no warning in the song list.
      final short = await songs.getSong(result.legacyLabels.single);
      expect(short!.chordproProblems, 0);

      expect(await service.convertLegacyLabels(result.legacyLabels), 1);
      expect(
        (await songs.getSong(short.id))!.chordproSource,
        '{title: Short}\n{sov: label="Verse 1"}\n[C]a\n{eov}\n',
      );
      // Converting again changes nothing.
      expect(await service.convertLegacyLabels(result.legacyLabels), 0);
    });

    test('a file with several songs is imported as several songs', () async {
      final service = ImportExportService(songs, sets);
      final result = await service.importFiles([
        ImportFile(
          'medley.cho',
          Uint8List.fromList(
            utf8.encode('{title: One}\n[C]a\n{new_song}\n{title: Two}\n[G]b\n'),
          ),
        ),
      ]);
      expect(result.imported, 2);
      final all = await songs.watchSongs().first;
      expect(all.map((s) => s.title), ['One', 'Two']);
      expect(all.last.chordproSource, '{title: Two}\n[G]b\n');
    });

    test('SongSelect directives are made standard-conforming (#777)', () async {
      final service = ImportExportService(songs, sets);
      await service.importFiles([
        ImportFile(
          'songselect.cho',
          Uint8List.fromList(
            utf8.encode(
              '{title: S}\n{ccli_license: 1234567}\n{ccli: 7654321}\n[C]a\n',
            ),
          ),
        ),
      ]);
      final song = (await songs.watchSongs().first).single;
      expect(song.chordproSource, '{title: S}\n{x_ccli: 7654321}\n[C]a\n');
    });
  });

  test('the song list sorts by title, artist, key or last edit', () async {
    final c = await songs.createSong(source: '{title: Charlie}\n{key: Em}');
    await songs.createSong(source: '{title: Alpha}\n{artist: Zoe}\n{key: G}');
    await songs.createSong(source: '{title: Bravo}\n{artist: Ann}\n{key: E}');
    await songs.createSong(source: '{title: Delta}\n{artist: ann}');
    Future<List<String>> titles(SongSort sort) async =>
        (await songs.watchSongList(sort: sort).first)
            .map((s) => s.title)
            .toList();

    expect(await titles(SongSort.title), [
      'Alpha',
      'Bravo',
      'Charlie',
      'Delta',
    ]);
    // Accents do not move a title to the end.
    final umlaut = await songs.createSong(source: '{title: Ärger}');
    expect((await titles(SongSort.title))[1], 'Ärger');
    await songs.deleteSong(umlaut);
    // Without artist last; case-insensitive; then by title.
    expect(await titles(SongSort.artist), [
      'Bravo',
      'Delta',
      'Alpha',
      'Charlie',
    ]);
    // C to B, major before minor, without key last.
    expect(await titles(SongSort.key), ['Bravo', 'Charlie', 'Alpha', 'Delta']);
    // Times are stored in seconds: the others were edited long ago.
    await db
        .update(db.songs)
        .write(SongsCompanion(updatedAt: Value(DateTime(2020))));
    await songs.updateSource(c, '{title: Charlie}\n{key: Em}\nedited');
    expect((await titles(SongSort.recent)).first, 'Charlie');
  });

  test('search hits are marked where the search matched', () async {
    String show(String? s) =>
        (s ?? '').replaceAll(hitStart, '[').replaceAll(hitEnd, ']');
    final a = await songs.createSong(
      source: '{title: Ärger im Hof}\n{artist: Ann}\n[G]Sun is shining',
    );
    final b = await songs.createSong(
      source: '{title: Rain}\n{artist: Arge Band}\n[C]Big argument\nnext line',
    );
    await songs.createSong(source: '{title: Other}\n[C]nothing');
    final hits = await songs.watchSearchHits('arg').first;
    expect(hits.keys, unorderedEquals([a, b]));
    // Accents ignored, as in the search; only word starts.
    expect(show(hits[a]!.title), '[Ärger] im Hof');
    expect(show(hits[a]!.artist), 'Ann');
    expect(hits[a]!.lyrics, isNull);
    expect(show(hits[b]!.artist), '[Arge] Band');
    expect(show(hits[b]!.lyrics), 'Big [argument] / next line');
    expect(await songs.watchSearchHits('  ').first, isEmpty);
  });

  test('the song list knows songs without chords (PDF only)', () async {
    await songs.createSong(title: 'Sheet');
    await songs.createSong(source: '{title: Chords}\n[G]x');
    final list = await songs.watchSongList().first;
    expect(
      {for (final s in list) s.title: s.hasChords},
      {'Chords': true, 'Sheet': false},
    );
  });

  test('upcoming gigs: the first set from today on per song', () async {
    final a = await songs.createSong(source: '{title: A}');
    final b = await songs.createSong(source: '{title: B}');
    final c = await songs.createSong(source: '{title: C}');
    final today = DateTime(2027, 6, 10, 15);
    Future<void> set(String name, DateTime? date, List<String> ids) async {
      final id = await sets.createSet(name: name, gigDate: date);
      await sets.addSongs(id, ids);
    }

    await set('Past', DateTime(2027, 6, 9), [a, b, c]);
    await set('Later', DateTime(2027, 7, 1), [a, b]);
    await set('Tonight', DateTime(2027, 6, 10), [a]);
    await set('Undated', null, [c]);
    final gigs = await sets.watchUpcomingGigs(today: today).first;
    expect(gigs.keys, unorderedEquals([a, b]));
    expect(gigs[a]!.setName, 'Tonight');
    expect(gigs[b], (setName: 'Later', date: DateTime(2027, 7, 1)));
  });

  test('groups sets into upcoming, undated and past sets', () async {
    final today = DateTime(2027, 6, 10, 15);
    for (final (name, date) in [
      ('Old', DateTime(2027, 1, 5)),
      ('Later', DateTime(2027, 7, 1)),
      ('Yesterday', DateTime(2027, 6, 9)),
      ('Tonight', DateTime(2027, 6, 10)),
      ('b undated', null),
      ('A undated', null),
      ('Also later', DateTime(2027, 7, 1)),
    ]) {
      await sets.createSet(name: name, gigDate: date);
    }
    final groups = groupSets(await sets.watchSets().first, today);
    List<String> names(List<SetSummary> list) => [
      for (final s in list) s.set.name,
    ];
    // Today counts as upcoming, as for the song list (above).
    expect(names(groups.upcoming), ['Tonight', 'Also later', 'Later']);
    expect(names(groups.undated), ['A undated', 'b undated']);
    expect(names(groups.past), ['Yesterday', 'Old']);
  });

  test('the song list has what lists show, filtered like the songs', () async {
    final a = await songs.createSong(
      source:
          '{title: Alpha}\n{artist: Ann}\n{key: G}\n{tempo: 96}\n{tag: Rock}\n'
          '{x_sequence: V, C x2}\n[G]sun',
    );
    await songs.createSong(source: '{title: Beta}\n[C]rain');
    final list = await songs.watchSongList().first;
    expect(list.map((s) => s.title), ['Alpha', 'Beta']);
    expect(
      list.first,
      SongListEntry(
        id: a,
        title: 'Alpha',
        artist: 'Ann',
        songKey: 'G',
        tempo: 96,
        sequence: 'V, C x2',
        tags: '\nRock\n',
      ),
    );
    expect(list.last.sequence, isNull);
    expect(list.first.tagList, ['Rock']);
    expect(
      (await songs.watchSongList(query: 'rain').first).map((s) => s.title),
      ['Beta'],
    );
    expect((await songs.watchSongList(tag: 'rock').first).map((s) => s.id), [
      a,
    ]);
  });

  group('personal adjustments per person (ADR-0020)', () {
    SongRepository org(String? user) =>
        SongRepository(db, songs.storage, libraryId: 'o1', userId: user);

    test('each person sees their own adjustments on a shared device', () async {
      final id = await org('ann').createSong(source: '{title: Shared}');
      final ann = org('ann');
      await ann.saveOverlay((await ann.getOverlay(id)).copyWith(transpose: 2));
      final bob = org('bob');
      expect((await bob.getOverlay(id)).transpose, 0);
      await bob.saveOverlay(
        (await bob.getOverlay(id)).copyWith(notes: const Value('Solo')),
      );
      expect((await ann.getOverlay(id)).transpose, 2);
      expect((await ann.getOverlay(id)).notes, isNull);
      expect((await bob.getOverlay(id)).ownerId, 'bob');
    });

    test('the local library keeps the local owner when signed in', () async {
      final id = await songs.createSong(source: '{title: Mine}');
      await songs.saveOverlay((await songs.getOverlay(id)).copyWith(capo: 1));
      final signedIn = SongRepository(db, songs.storage, userId: 'ann');
      expect(signedIn.overlayOwner, localOwnerId);
      expect((await signedIn.getOverlay(id)).capo, 1);
    });

    test('adjustments follow the library of the song, not of the '
        'repository', () async {
      final orgSong = await org('ann').createSong(source: '{title: Org}');
      final localSong = await songs.createSong(source: '{title: Mine}');
      // A repository of the local library used for an organization song,
      // e.g. Live mode of a set while the songs tab shows another library.
      final local = SongRepository(db, songs.storage, userId: 'ann');
      await local.saveOverlay(
        (await local.getOverlay(orgSong)).copyWith(transpose: 3),
      );
      expect((await local.getOverlay(orgSong)).ownerId, 'ann');
      expect((await org('ann').getOverlay(orgSong)).transpose, 3);
      expect(await local.watchOverlay(orgSong).first, isA<SongOverlay>());
      expect((await local.watchOverlay(orgSong).first).transpose, 3);
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox.where((o) => o.recordId.contains(orgSong)), isNotEmpty);

      // And the other way round: the local song stays with the local owner.
      final ann = org('ann');
      await ann.saveOverlay(
        (await ann.getOverlay(localSong)).copyWith(capo: 2),
      );
      expect((await songs.getOverlay(localSong)).capo, 2);
      expect((await ann.getOverlay(localSong)).ownerId, localOwnerId);
    });

    test(
      'the first user takes over local adjustments of organization songs',
      () async {
        final orgSong = await org(null).createSong(source: '{title: Org}');
        final localSong = await songs.createSong(source: '{title: Mine}');
        // As after the upgrade: everything belongs to the local owner.
        for (final id in [orgSong, localSong]) {
          await db
              .into(db.personalOverlays)
              .insert(
                PersonalOverlaysCompanion.insert(
                  songId: id,
                  transpose: const Value(5),
                ),
              );
        }
        expect(await adoptLocalOverlays(db, 'ann'), 1);
        expect((await org('ann').getOverlay(orgSong)).transpose, 5);
        expect((await org('bob').getOverlay(orgSong)).transpose, 0);
        expect((await songs.getOverlay(localSong)).transpose, 5);
      },
    );
  });

  group('undo of deletions (#267)', () {
    Future<List<String?>> names(String setId) async => [
      for (final v in await sets.getItems(setId)) v.song?.title ?? v.item.note,
    ];
    bool exists(String fileName) => File('${dir.path}/$fileName').existsSync();

    test('a song comes back with its attachments and set items', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      await songs.addAttachment(a, name: 'Score', bytes: Uint8List(1));
      await songs.addAttachment(a, name: 'Old', bytes: Uint8List(1));
      final old = (await songs.getAttachments(a))
          .firstWhere((x) => x.name == 'Old');
      await songs.deleteAttachment(old);
      final first = await sets.createSet(name: 'First');
      await sets.addSongs(first, [a, b, a]);
      final second = await sets.createSet(name: 'Second');
      await sets.addSongs(second, [b, a]);
      await sets.addMarker(second, MarkerIcons.breakIcon, 'Break');

      final deleted = await songs.deleteSong(a);
      expect(await songs.getSong(a), isNull);
      expect(await names(first), ['B']);
      expect(await names(second), ['B', 'Break']);
      final score = deleted.attachments.single;
      expect(score.name, 'Score');
      expect(exists(score.fileName), isTrue); // kept for the undo

      await songs.restoreSong(deleted);
      expect((await songs.getSong(a))!.title, 'A');
      expect(await names(first), ['A', 'B', 'A']);
      expect(await names(second), ['B', 'A', 'Break']);
      // Only the attachment deleted with the song comes back.
      expect((await songs.getAttachments(a)).map((x) => x.name), ['Score']);
      await songs.purgeFiles(deleted.attachments);
      expect(exists(score.fileName), isTrue);
    });

    test('the files of a deleted song go once the undo is gone', () async {
      // An organization's song: its files are downloaded again if it is
      // restored from the trash; the local library keeps them (ADR-0043,
      // trash_test.dart).
      final org = SongRepository(
        db,
        FileAttachmentStorage(dir),
        libraryId: 'o1',
      );
      final a = await org.createSong(title: 'A');
      await org.addAttachment(a, name: 'Score', bytes: Uint8List(1));
      final deleted = await org.deleteSong(a);
      final file = deleted.attachments.single.fileName;
      expect(exists(file), isTrue);
      await org.purgeFiles(deleted.attachments);
      expect(exists(file), isFalse);
    });

    test('files left behind are purged at start', () async {
      final org = SongRepository(
        db,
        FileAttachmentStorage(dir),
        libraryId: 'o1',
      );
      final a = await songs.createSong(title: 'A');
      final b = await org.createSong(title: 'B');
      final c = await songs.createSong(title: 'C');
      await songs.addAttachment(a, name: 'Deleted', bytes: Uint8List(1));
      await org.addAttachment(b, name: 'Song deleted', bytes: Uint8List(1));
      await songs.addAttachment(a, name: 'Kept', bytes: Uint8List(1));
      await songs.addAttachment(c, name: 'In the trash', bytes: Uint8List(1));
      final all = [
        ...await songs.getAttachments(a),
        ...await org.getAttachments(b),
        ...await songs.getAttachments(c),
      ];
      String file(String name) =>
          all.firstWhere((x) => x.name == name).fileName;
      await songs.deleteAttachment(all.firstWhere((x) => x.name == 'Deleted'));
      await org.deleteSong(b);
      await songs.deleteSong(c);

      await songs.purgeDeletedFiles();
      expect(exists(file('Deleted')), isFalse);
      expect(exists(file('Song deleted')), isFalse);
      expect(exists(file('Kept')), isTrue);
      // A deleted song of the local library keeps its files for the trash
      // (ADR-0043).
      expect(exists(file('In the trash')), isTrue);
    });

    test('an attachment comes back with its live view', () async {
      final a = await songs.createSong(title: 'A');
      final id = await songs.addAttachment(
        a,
        name: 'Score',
        bytes: Uint8List(1),
      );
      await songs.updateOverlay(a, (o) => o.copyWith(liveView: Value(id)));
      final attachment = (await songs.getAttachments(a)).single;

      final deleted = await songs.deleteAttachment(attachment);
      expect(await songs.getAttachments(a), isEmpty);
      expect((await songs.getOverlay(a)).liveView, isNull);
      expect(exists(attachment.fileName), isTrue);

      await songs.restoreAttachment(deleted);
      expect((await songs.getAttachments(a)).single.id, id);
      expect((await songs.getOverlay(a)).liveView, id);
      await songs.purgeFiles([attachment]);
      expect(exists(attachment.fileName), isTrue);
    });

    test('a set comes back with its items', () async {
      final a = await songs.createSong(source: '{title: A}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a]);
      await sets.addMarker(setId, MarkerIcons.announcement, 'Encore');

      final deleted = await sets.deleteSet(setId);
      expect(await sets.watchSets().first, isEmpty);

      await sets.restoreSet(deleted);
      expect((await sets.watchSets().first).single.set.name, 'Gig');
      expect(await names(setId), ['A', 'Encore']);
    });

    test('a removed item comes back at its position', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final c = await songs.createSong(source: '{title: C}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a, b, c]);
      final items = await sets.getItems(setId);

      final removed = await sets.removeItem(setId, items[1].item.id);
      expect(await names(setId), ['A', 'C']);
      await sets.restoreItem(removed!);
      expect(await names(setId), ['A', 'B', 'C']);
      expect(
        [for (final v in await sets.getItems(setId)) v.item.position],
        [0, 1, 2],
      );
      // Back already: a second undo changes nothing.
      await sets.restoreItem(removed);
      expect(await names(setId), ['A', 'B', 'C']);
    });
  });

  group('SetRepository', () {
    test('adds, reorders and removes items', () async {
      final a = await songs.createSong(source: '{title: A}');
      final b = await songs.createSong(source: '{title: B}');
      final setId = await sets.createSet(name: 'Gig', venue: 'Club');
      await sets.addSongs(setId, [a, b]);
      await sets.addMarker(setId, MarkerIcons.breakIcon, 'Break');

      var items = await sets.getItems(setId);
      expect(items.map((v) => v.song?.title ?? v.item.note), [
        'A',
        'B',
        'Break',
      ]);

      await sets.reorder(setId, [
        items[2].item.id,
        items[0].item.id,
        items[1].item.id,
      ]);
      items = await sets.getItems(setId);
      expect(items.map((v) => v.song?.title ?? v.item.note), [
        'Break',
        'A',
        'B',
      ]);

      await sets.removeItem(setId, items[0].item.id);
      items = await sets.getItems(setId);
      expect(items.map((v) => v.item.position), [0, 1]);

      final summary = (await sets.watchSets().first).single;
      expect(summary.itemCount, 2);
    });

    test('deleting a song removes it from sets', () async {
      final a = await songs.createSong(source: '{title: A}');
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a]);
      await songs.deleteSong(a);
      expect(await sets.getItems(setId), isEmpty);
    });

    test('offline ready requires attachment files', () async {
      final a = await songs.createSong(title: 'A');
      await songs.addAttachment(a, name: 'P', bytes: Uint8List.fromList([1]));
      final setId = await sets.createSet(name: 'Gig');
      await sets.addSongs(setId, [a]);
      expect(await sets.offlineMissing(setId), 0);

      final file = (await songs.getAttachments(a)).single.fileName;
      await File('${dir.path}/$file').delete();
      expect(await sets.offlineMissing(setId), 1);
    });

    test('offline status of all sets comes from one stream', () async {
      final a = await songs.createSong(title: 'A');
      await songs.addAttachment(a, name: 'P', bytes: Uint8List.fromList([1]));
      final b = await songs.createSong(title: 'B');
      final ready = await sets.createSet(name: 'Ready');
      await sets.addSongs(ready, [a]);
      await sets.addMarker(ready, MarkerIcons.breakIcon, 'Break');
      final empty = await sets.createSet(name: 'Empty');
      final missingFile = await sets.createSet(name: 'Missing file');
      await sets.addSongs(missingFile, [b]);
      await songs.addAttachment(b, name: 'Q', bytes: Uint8List.fromList([2]));
      final missingSong = await sets.createSet(name: 'Missing song');
      // A set item whose song is not on this device (e.g. not synced yet).
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: 'item-x',
              setId: missingSong,
              position: 0,
              type: SetItemType.song,
            ),
          );

      final fileB = (await songs.getAttachments(b)).single.fileName;
      await File('${dir.path}/$fileB').delete();
      // Another band's set is not part of this band's status.
      final other = SetRepository(db, sets.storage, bandId: 'other');
      await db
          .into(db.bands)
          .insert(BandsCompanion.insert(id: 'other', name: 'Other'));
      final otherSet = await other.createSet(name: 'Other');
      await other.addSongs(otherSet, [b]);

      // A song with two missing files counts once.
      await songs.addAttachment(b, name: 'R', bytes: Uint8List.fromList([3]));
      final fileR = (await songs.getAttachments(b))
          .firstWhere((x) => x.name == 'R')
          .fileName;
      await File('${dir.path}/$fileR').delete();
      // Two items with missing songs and files count as two.
      await sets.addSongs(missingSong, [b]);

      final stream = sets.watchOfflineMissing();
      expect(await stream.first, {missingFile: 1, missingSong: 2});
      expect(await sets.offlineMissing(ready), 0);
      expect(await sets.offlineMissing(empty), 0);
      expect(await sets.offlineMissing(missingFile), 1);
      expect(await sets.offlineMissing(missingSong), 2);
      expect(await other.offlineMissing(otherSet), 1);

      // Removing the song with the missing files makes the set ready.
      await songs.deleteSong(b);
      expect(await sets.watchOfflineMissing().first, {missingSong: 1});
    });

    test('songs with ChordPro problems per set (#314)', () async {
      final ok = await songs.createSong(source: '{title: A}\n[C]a');
      final bad = await songs.createSong(source: '{title: B}\n[C a');
      final worse = await songs.createSong(source: '{c: x} y\n[C a');
      final clean = await sets.createSet(name: 'Clean');
      await sets.addSongs(clean, [ok]);
      final mixed = await sets.createSet(name: 'Mixed');
      // The same song twice counts once.
      await sets.addSongs(mixed, [ok, bad, worse, bad]);
      await sets.addMarker(mixed, MarkerIcons.breakIcon, 'Break');
      expect(await sets.watchProblemSongCounts().first, {mixed: 2});

      // Fixing a song or deleting it updates the counts.
      await songs.updateSource(bad, '{title: B}\n[C]a');
      expect(await sets.watchProblemSongCounts().first, {mixed: 1});
      await songs.deleteSong(worse);
      expect(await sets.watchProblemSongCounts().first, isEmpty);
    });
  });
}
