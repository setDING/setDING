import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/arrangement_repository.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/backup.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/marker_icons.dart';
import 'package:setding/data/set_archive.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/data/song_repository.dart';

/// Set archive of ADR-0043 §1b (#707).
void main() {
  final pdf = Uint8List.fromList('%PDF-1.4 score'.codeUnits);
  late AppDatabase db;
  late Directory dir;
  late FileAttachmentStorage storage;
  late SongRepository songs;
  late SetRepository sets;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_set_archive');
    storage = FileAttachmentStorage(dir);
    songs = SongRepository(db, storage);
    sets = SetRepository(db, storage);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  SetArchiveService service([AppDatabase? on]) =>
      SetArchiveService(BackupService(on ?? db, storage, appVersion: '1.2.3'));

  String missing(String title) => 'missing: $title';
  String copyOf(String name, int n) =>
      n == 1 ? '$name (copy)' : '$name (copy $n)';

  /// A set "Gig" with "Hello" (transposed, with an attachment, an
  /// adjustment and a band arrangement), a break, "Bye" without a title
  /// directive and a text item.
  Future<({String set, String hello, String bye})> fill() async {
    final hello = await songs.createSong(
      source: '{title: Hello}\n{artist: Band}\n[C]Hello [G]world',
    );
    await songs.addAttachment(hello, name: 'Score', bytes: pdf, pages: 1);
    await songs.updateOverlay(
      hello,
      (o) => o.copyWith(notes: const Value('Slow intro')),
    );
    await ArrangementRepository(db).save(localBandId, hello, transpose: -2);
    final bye = await songs.createSong(source: '[G]Bye', title: 'Bye');
    final set = await sets.createSet(
      name: 'Gig',
      gigDate: DateTime(2027, 6, 21),
      venue: 'Bern',
    );
    await sets.addSongs(set, [hello]);
    await sets.addMarker(set, MarkerIcons.breakIcon, 'Break');
    await sets.addSongs(set, [bye]);
    await sets.addMarker(set, MarkerIcons.announcement, 'Encore');
    final first = (await sets.getItems(set)).first.item;
    await sets.setItemTranspose(first.id, 3);
    return (set: set, hello: hello, bye: bye);
  }

  Map<String, Uint8List> unzip(Uint8List zip) => {
    for (final f in ZipDecoder().decodeBytes(zip).files)
      if (f.isFile) f.name: Uint8List.fromList(f.content),
  };

  test('the archive has a manifest and numbered ChordPro files and no '
      'setlist.txt', () async {
    final ids = await fill();
    final files = unzip(await service().export(ids.set));
    expect(files.keys, {
      'manifest.json',
      '01 - Hello.cho',
      '01 - Hello - Score.pdf',
      '03 - Bye.cho',
    });
    // Title directive added for a file readable without setDING.
    expect(utf8.decode(files['03 - Bye.cho']!), startsWith('{title: Bye}'));
    final manifest = jsonDecode(
      utf8.decode(files['manifest.json']!),
    ) as Map<String, dynamic>;
    expect(manifest['format'], 'setding-set');
    expect(manifest['formatVersion'], 1);
    final set = manifest['set'] as Map<String, dynamic>;
    expect(set['id'], ids.set);
    expect(set['name'], 'Gig');
    expect(set['venue'], 'Bern');
    expect(
      [for (final i in set['items'] as List) (i as Map)['type']],
      ['song', 'pause', 'song', 'text'],
    );
    expect(((set['items'] as List).first as Map)['transpose'], 3);
    expect((manifest['arrangements'] as List), hasLength(1));
    // Personal adjustments are off by default.
    expect(manifest['overlays'], isEmpty);
    expect(manifest['options'], {
      'arrangements': true,
      'setSettings': true,
      'attachments': true,
      'personal': false,
    });
  });

  test('the export leaves out what the options exclude', () async {
    final ids = await fill();
    final files = unzip(
      await service().export(
        ids.set,
        options: const SetArchiveOptions(
          arrangements: false,
          setSettings: false,
          attachments: false,
          personal: true,
        ),
      ),
    );
    expect(files.keys, {'manifest.json', '01 - Hello.cho', '03 - Bye.cho'});
    final manifest = jsonDecode(
      utf8.decode(files['manifest.json']!),
    ) as Map<String, dynamic>;
    expect(manifest['arrangements'], isEmpty);
    expect(
      ((manifest['set'] as Map)['items'] as List).first,
      isNot(contains('transpose')),
    );
    expect((manifest['overlays'] as List), hasLength(1));
  });

  test('only set archives are read as such', () async {
    final ids = await fill();
    expect(
      await SetArchiveService.read(await service().export(ids.set)),
      isNotNull,
    );
    final backup = await BackupService(
      db,
      storage,
    ).export(localBandId, libraryName: 'Mine');
    expect(await SetArchiveService.read(backup), isNull);
    expect(await SetArchiveService.read(Uint8List.fromList([1, 2, 3])), isNull);
    final newer = Archive()
      ..addFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'format': 'setding-set',
            'formatVersion': 99,
            'set': <String, Object?>{},
          }),
        ),
      );
    await expectLater(
      SetArchiveService.read(Uint8List.fromList(ZipEncoder().encode(newer))),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.newerVersion,
          'newerVersion',
          99,
        ),
      ),
    );
  });

  test('a round trip into another library gives the set with new songs, '
      'arrangements and attachments', () async {
    final ids = await fill();
    final zip = await service().export(
      ids.set,
      options: const SetArchiveOptions(personal: true),
    );
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final archive = (await SetArchiveService.read(zip))!;
    final target = service(other);
    final preview = await target.preview(
      archive,
      bandId: localBandId,
      canCreateSongs: true,
      copyName: copyOf,
    );
    expect((preview.songs, preview.added, preview.identical), (2, 2, 0));
    expect(preview.missing, isEmpty);
    expect(preview.existingSet, isNull);

    final result = await target.import(
      archive,
      bandId: localBandId,
      canCreateSongs: true,
      missingNote: missing,
      copyName: copyOf,
    );
    expect(result.replaced, isFalse);
    expect(result.songs.imported, hasLength(2));
    expect(result.songs.files, 1);
    expect(result.arrangements, 1);
    final set = await (other.select(
      other.setlists,
    )..where((s) => s.id.equals(result.setId))).getSingle();
    expect(
      (set.name, set.venue, set.gigDate),
      ('Gig', 'Bern', DateTime(2027, 6, 21)),
    );
    expect(set.origin, ids.set);
    final items = await SetRepository(other, storage).getItems(set.id);
    expect(
      [for (final v in items) (v.item.type, v.item.icon)],
      [
        (SetItemType.song, null),
        (SetItemType.marker, MarkerIcons.breakIcon),
        (SetItemType.song, null),
        (SetItemType.marker, MarkerIcons.announcement),
      ],
    );
    expect(items.first.song!.title, 'Hello');
    expect(items.first.item.transpose, 3);
    expect(items[3].item.note, 'Encore');
    final hello = items.first.song!.id;
    expect(
      (await ArrangementRepository(other).get(localBandId, hello))!.transpose,
      -2,
    );
    final overlay = await SongRepository(other, storage).getOverlay(hello);
    expect(overlay.notes, 'Slow intro');
  });

  test('importing into the same library reuses the songs and finds the '
      'set again: replace or add a copy', () async {
    final ids = await fill();
    final archive = (await SetArchiveService.read(
      await service().export(ids.set),
    ))!;
    // The set changes after the export.
    await sets.updateSet(ids.set, name: 'Changed');
    await sets.addMarker(ids.set, MarkerIcons.announcement, 'Later');

    final preview = await service().preview(
      archive,
      bandId: localBandId,
      canCreateSongs: true,
      copyName: copyOf,
    );
    expect((preview.identical, preview.added), (2, 0));
    expect(preview.existingSet?.id, ids.set);
    expect(preview.arrangementConflicts, 1);

    final replaced = await service().import(
      archive,
      bandId: localBandId,
      canCreateSongs: true,
      missingNote: missing,
      copyName: copyOf,
      replace: true,
    );
    expect((replaced.replaced, replaced.setId), (true, ids.set));
    expect(replaced.songs.imported, isEmpty);
    expect((await sets.getSet(ids.set))!.name, 'Gig');
    expect(await sets.getItems(ids.set), hasLength(4));
    expect(await db.select(db.songs).get(), hasLength(2));

    final copy = await service().import(
      archive,
      bandId: localBandId,
      canCreateSongs: true,
      missingNote: missing,
      copyName: copyOf,
    );
    expect(copy.replaced, isFalse);
    expect(copy.setId, isNot(ids.set));
    expect((await sets.getSet(copy.setId))!.origin, ids.set);

    // An imported copy is found again by its origin, and exporting it keeps
    // the identity of the original set.
    await sets.deleteSet(ids.set);
    final again = await service().preview(
      archive,
      bandId: localBandId,
      canCreateSongs: true,
      copyName: copyOf,
    );
    expect(again.existingSet?.id, copy.setId);
    final reexported = (await SetArchiveService.read(
      await service().export(copy.setId),
    ))!;
    expect(reexported.setId, ids.set);
  });

  test(
    'existing band arrangements are kept unless overwriting is chosen',
    () async {
      final ids = await fill();
      final archive = (await SetArchiveService.read(
        await service().export(ids.set),
      ))!;
      final arrangements = ArrangementRepository(db);
      await arrangements.save(localBandId, ids.hello, transpose: 5);

      await service().import(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        missingNote: missing,
        copyName: copyOf,
      );
      expect((await arrangements.get(localBandId, ids.hello))!.transpose, 5);

      await service().import(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        missingNote: missing,
        copyName: copyOf,
        overwriteArrangements: true,
      );
      expect((await arrangements.get(localBandId, ids.hello))!.transpose, -2);
    },
  );

  test(
    'without the right to create songs, missing songs become text items',
    () async {
      final ids = await fill();
      final zip = await service().export(ids.set);
      // The library has "Hello" with the same text but not "Bye".
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await SongRepository(
        other,
        storage,
      ).createSong(source: '{title: Hello}\n{artist: Band}\n[C]Hello [G]world');
      final archive = (await SetArchiveService.read(zip))!;
      final target = service(other);
      final preview = await target.preview(
        archive,
        bandId: localBandId,
        canCreateSongs: false,
        copyName: copyOf,
      );
      expect((preview.identical, preview.added), (1, 0));
      expect(preview.missing, ['Bye']);

      final result = await target.import(
        archive,
        bandId: localBandId,
        canCreateSongs: false,
        missingNote: missing,
        copyName: copyOf,
      );
      expect(result.missing, ['Bye']);
      expect(await other.select(other.songs).get(), hasLength(1));
      final items = await SetRepository(other, storage).getItems(result.setId);
      expect(items[2].item.type, SetItemType.marker);
      expect(items[2].item.icon, MarkerIcons.warning);
      expect(items[2].item.note, 'missing: Bye');
      expect(items[2].item.songId, isNull);
    },
  );

  test(
    'set-specific settings are left out of the import if not chosen',
    () async {
      final ids = await fill();
      final archive = (await SetArchiveService.read(
        await service().export(ids.set),
      ))!;
      final result = await service().import(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        missingNote: missing,
        copyName: copyOf,
        options: const SetArchiveOptions(setSettings: false),
      );
      final items = await sets.getItems(result.setId);
      expect(items.first.item.transpose, 0);
    },
  );

  test(
    'a copy gets a copy name only if name and date are taken (#719)',
    () async {
      final ids = await fill();
      final archive = (await SetArchiveService.read(
        await service().export(ids.set),
      ))!;
      Future<String> importCopy() async {
        final result = await service().import(
          archive,
          bandId: localBandId,
          canCreateSongs: true,
          missingNote: missing,
          copyName: copyOf,
        );
        return (await sets.getSet(result.setId))!.name;
      }

      final preview = await service().preview(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        copyName: copyOf,
      );
      expect(preview.newName, 'Gig (copy)');
      expect(await importCopy(), 'Gig (copy)');
      expect(await importCopy(), 'Gig (copy 2)');

      // Replacing keeps the archive's name.
      final replaced = await service().import(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        missingNote: missing,
        copyName: copyOf,
        replace: true,
      );
      expect((await sets.getSet(replaced.setId))!.name, 'Gig');

      // The same name on another date is no clash.
      await sets.updateSet(ids.set, name: 'Gig', gigDate: DateTime(2027, 7, 1));
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final elsewhere = SetRepository(other, storage);
      await elsewhere.createSet(name: 'gig', gigDate: DateTime(2027, 6, 22));
      final result = await service(other).import(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        missingNote: missing,
        copyName: copyOf,
      );
      expect((await elsewhere.getSet(result.setId))!.name, 'Gig');
      // Same name (ignoring case) and date: a copy.
      await elsewhere.createSet(
        name: 'GIG',
        gigDate: DateTime(2027, 6, 21, 20),
      );
      final second = await service(other).import(
        archive,
        bandId: localBandId,
        canCreateSongs: true,
        missingNote: missing,
        copyName: copyOf,
      );
      expect((await elsewhere.getSet(second.setId))!.name, 'Gig (copy)');
    },
  );
}
