import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'arrangement_repository.dart';
import 'backup.dart';
import 'database.dart';
import 'marker_icons.dart';
import 'import_export.dart' show safeFileName, sourceWithMeta;
import 'outbox.dart';
import 'set_repository.dart';

const _uuid = Uuid();

/// `format` of a set archive's manifest (ADR-0043 §1b).
const setArchiveFormat = 'setding-set';

/// Newest `formatVersion` of a set archive this app reads.
const setArchiveFormatVersion = 1;

/// What a set archive holds besides the set and its songs, chosen for the
/// export and again for the import (ADR-0043 §1b).
@immutable
class SetArchiveOptions {
  const SetArchiveOptions({
    this.arrangements = true,
    this.setSettings = true,
    this.attachments = true,
    this.personal = false,
  });

  /// Key, sequence and tempo of the band for the songs (ADR-0025).
  final bool arrangements;

  /// Key, sequence and played values of the songs in this set.
  final bool setSettings;

  /// Attachments (PDFs, images) of the songs.
  final bool attachments;

  /// The exporting person's own adjustments and annotations (ADR-0006).
  /// Off by default: a set archive is often passed on.
  final bool personal;

  SetArchiveOptions copyWith({
    bool? arrangements,
    bool? setSettings,
    bool? attachments,
    bool? personal,
  }) => SetArchiveOptions(
    arrangements: arrangements ?? this.arrangements,
    setSettings: setSettings ?? this.setSettings,
    attachments: attachments ?? this.attachments,
    personal: personal ?? this.personal,
  );

  /// Only what both allow: what the archive holds and the person chose.
  SetArchiveOptions and(SetArchiveOptions other) => SetArchiveOptions(
    arrangements: arrangements && other.arrangements,
    setSettings: setSettings && other.setSettings,
    attachments: attachments && other.attachments,
    personal: personal && other.personal,
  );

  Map<String, bool> toJson() => {
    'arrangements': arrangements,
    'setSettings': setSettings,
    'attachments': attachments,
    'personal': personal,
  };

  factory SetArchiveOptions.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    bool flag(String key) => m[key] == true;
    return SetArchiveOptions(
      arrangements: flag('arrangements'),
      setSettings: flag('setSettings'),
      attachments: flag('attachments'),
      personal: flag('personal'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SetArchiveOptions &&
      other.arrangements == arrangements &&
      other.setSettings == setSettings &&
      other.attachments == attachments &&
      other.personal == personal;

  @override
  int get hashCode =>
      Object.hash(arrangements, setSettings, attachments, personal);
}

/// A set archive read into memory: one set with its songs, in the shape of
/// a backup archive ([BackupContents]) so the song import is shared.
@immutable
class SetArchive {
  const SetArchive(this.contents);

  final BackupContents contents;

  Map<String, dynamic> get set => contents.sets.single;

  /// The original ID of the exported set (or its own origin): an existing
  /// set with this ID or origin is the same set (ADR-0043 §1b).
  String get setId => set['id'] as String? ?? '';

  String get name => set['name'] as String? ?? '';

  /// Name of the band the set was exported from.
  String get bandName =>
      ((contents.manifest['band'] as Map?)?['name'] as String?) ?? '';

  /// What the archive holds.
  SetArchiveOptions get holds =>
      SetArchiveOptions.fromJson(contents.manifest['options']);

  /// Title of a song of the archive by its original ID.
  String? titleOf(String? songId) {
    for (final s in contents.songs) {
      if (s['id'] == songId) return s['title'] as String?;
    }
    return null;
  }
}

/// The name of a copy of the set [name]: [number] 1 is the first copy
/// ("Gig (copy)"), then 2, 3, … ("Gig (copy 2)"), in the importer's
/// language.
typedef CopyName = String Function(String name, int number);

/// What importing a set archive into a band would find.
@immutable
class SetArchivePreview {
  const SetArchivePreview({
    required this.songs,
    required this.identical,
    required this.differing,
    required this.added,
    required this.missing,
    required this.arrangementConflicts,
    required this.newName,
    this.attachmentsAdded = 0,
    this.existingSet,
  });

  final int songs;

  /// Songs that exist with the same text: the existing ones are used.
  final int identical;

  /// Songs that exist with a different text.
  final int differing;

  /// Songs imported as new songs.
  final int added;

  /// Titles of songs that are not in the library and that the person may
  /// not create (set planner, ADR-0023): they become text items.
  final List<String> missing;

  /// Songs whose band arrangement in the target band would be overwritten.
  final int arrangementConflicts;

  /// Attachments added to existing songs that lack them (ADR-0043 §1c).
  final int attachmentsAdded;

  /// The same set in the target band, from an earlier import or the export
  /// itself: the person may replace it.
  final SetlistEntry? existingSet;

  /// Name of the set when it is added (not replaced): the archive's name,
  /// or a copy name if the band has a set with the same name and date.
  final String newName;
}

/// Result of a set import.
@immutable
class SetArchiveResult {
  const SetArchiveResult({
    required this.setId,
    required this.replaced,
    required this.songs,
    required this.missing,
    required this.arrangements,
  });

  final String setId;

  /// The existing set was replaced instead of a new one being added.
  final bool replaced;

  final SongImport songs;

  /// Titles of songs that became text items.
  final List<String> missing;

  /// Band arrangements saved.
  final int arrangements;
}

/// Set archive (ADR-0043 §1b): a set exported as ZIP with its ChordPro
/// files, attachments and a manifest, imported again as a set.
class SetArchiveService {
  SetArchiveService(this.backup);

  final BackupService backup;

  AppDatabase get db => backup.db;

  // Export --------------------------------------------------------------------

  /// A file name for the archive of [set].
  static String fileName(SetlistEntry set) => '${safeFileName(set.name)}.zip';

  /// Exports [setId] with what [options] include. [readFile] reads an
  /// attachment file (default: from the storage); a missing file aborts the
  /// export with [BackupFileMissingException].
  Future<Uint8List> export(
    String setId, {
    SetArchiveOptions options = const SetArchiveOptions(),
    Future<Uint8List?> Function(AttachmentEntry attachment)? readFile,
    DateTime? now,
  }) async {
    final set = await (db.select(
      db.setlists,
    )..where((s) => s.id.equals(setId))).getSingle();
    final band = await (db.select(
      db.bands,
    )..where((b) => b.id.equals(set.bandId))).getSingleOrNull();
    final libraryId = band?.organizationId ?? localBandId;
    final items =
        await (db.select(db.setItems)
              ..where((i) => i.setId.equals(set.id))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final songs = {
      for (final s
          in await (db.select(db.songs)..where(
                (s) =>
                    s.id.isIn([
                      for (final i in items)
                        if (i.songId != null) i.songId!,
                    ]) &
                    s.deleted.equals(false),
              ))
              .get())
        s.id: s,
    };

    final files = <String, Uint8List>{};
    final songJson = <Map<String, dynamic>>[];
    final done = <String>{};
    for (final (index, item) in items.indexed) {
      final song = songs[item.songId];
      // A song played twice in the set is exported once.
      if (song == null || !done.add(song.id)) continue;
      final base =
          '${(index + 1).toString().padLeft(2, '0')} - '
          '${safeFileName(song.title)}';
      String? file;
      if (song.chordproSource.trim().isNotEmpty) {
        file = '$base.cho';
        files[file] = Uint8List.fromList(
          utf8.encode(
            sourceWithMeta(song.chordproSource, song.title, song.artist),
          ),
        );
      }
      final attachments = <Map<String, dynamic>>[];
      if (options.attachments) {
        final stored =
            await (db.select(db.attachments)
                  ..where(
                    (a) => a.songId.equals(song.id) & a.deleted.equals(false),
                  )
                  ..orderBy([(a) => OrderingTerm.asc(a.name)]))
                .get();
        for (final a in stored) {
          Uint8List? bytes;
          try {
            bytes = await (readFile?.call(a) ?? backup.readStored(a));
          } catch (_) {
            bytes = null;
          }
          if (bytes == null) {
            throw BackupFileMissingException(song.title, a.name);
          }
          final ext = p.extension(a.fileName);
          var path =
              '$base - ${safeFileName(p.basenameWithoutExtension(a.name))}$ext';
          for (var n = 2; files.containsKey(path); n++) {
            path =
                '$base - ${safeFileName(p.basenameWithoutExtension(a.name))}'
                ' ($n)$ext';
          }
          files[path] = bytes;
          attachments.add({
            'id': a.id,
            'name': a.name,
            'file': path,
            'pages': ?a.pages,
          });
        }
      }
      songJson.add({
        'id': song.id,
        'title': song.title,
        'artist': ?song.artist,
        'file': ?file,
        'attachments': attachments,
        ...BackupService.languageJson(song),
      });
    }

    final arrangements = options.arrangements
        ? await (db.select(db.bandArrangements)..where(
                (a) =>
                    a.bandId.equals(set.bandId) &
                    a.songId.isIn(done) &
                    a.deleted.equals(false),
              ))
              .get()
        : const <BandArrangement>[];
    final (overlays, strokes) = options.personal
        ? await backup.personalData(libraryId, done)
        : (const <SongOverlay>[], const <AnnotationRow>[]);

    files[backupManifestName] = BackupService.json({
      'format': setArchiveFormat,
      'formatVersion': setArchiveFormatVersion,
      'app': backup.appVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'band': {'id': set.bandId, 'name': band?.name ?? ''},
      'options': options.toJson(),
      'set': {
        'id': set.origin ?? set.id,
        'name': set.name,
        'gigDate': ?set.gigDate?.toIso8601String(),
        'venue': ?set.venue,
        'items': [
          for (final i in items)
            {
              'type': writeItemType(i.type, i.icon),
              if (songs.containsKey(i.songId)) 'songId': i.songId,
              if (options.setSettings) ...{
                if (i.transpose != 0) 'transpose': i.transpose,
                'sequence': ?i.sequence,
                if (i.played case final played? when !played.isEmpty)
                  'played': played.toJson(),
              },
              'note': ?i.note,
              if (i.type == SetItemType.marker) 'icon': ?i.icon,
            },
        ],
      },
      'songs': songJson,
      'arrangements': [
        for (final a in arrangements)
          {
            'songId': a.songId,
            'transpose': a.transpose,
            'sequence': ?a.sequence,
            'tempo': ?a.tempo,
          },
      ],
      'overlays': [for (final o in overlays) BackupService.overlayJson(o)],
      'annotations': [for (final x in strokes) BackupService.strokeJson(x)],
    });
    return zipArchive(files);
  }

  // Import --------------------------------------------------------------------

  /// Reads a set archive; null if [zip] is none. Throws
  /// [BackupFormatException] with `newerVersion` if a newer app wrote it.
  static Future<SetArchive?> read(Uint8List zip) async {
    final Map<String, Uint8List> files;
    try {
      files = await unzipArchive(zip);
    } catch (_) {
      return null;
    }
    final Map<String, dynamic> manifest;
    try {
      manifest = BackupService.decodeManifest(
        files[backupManifestName],
        setArchiveFormat,
        setArchiveFormatVersion,
      );
    } on BackupFormatException catch (e) {
      if (e.newerVersion != null) rethrow;
      return null;
    }
    final set = manifest['set'];
    if (set is! Map) return null;
    return SetArchive(
      BackupContents({
        ...manifest,
        'sets': [set],
      }, files),
    );
  }

  /// The set of [bandId] that [archive] holds again: same ID or origin.
  Future<SetlistEntry?> existingSet(SetArchive archive, String bandId) async {
    if (archive.setId.isEmpty) return null;
    return (db.select(db.setlists)
          ..where(
            (s) =>
                s.bandId.equals(bandId) &
                s.deleted.equals(false) &
                (s.id.equals(archive.setId) | s.origin.equals(archive.setId)),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// The library of [bandId]: its organization, or the local library.
  Future<String> _libraryOf(String bandId) async =>
      (await (db.select(
            db.bands,
          )..where((b) => b.id.equals(bandId))).getSingleOrNull())
          ?.organizationId ??
      localBandId;

  /// The name of [archive]'s set when it is added to [bandId]: unchanged,
  /// unless the band has a set (not deleted, other than [except]) with the
  /// same name and gig date; then the first free [copyName] (#719).
  Future<String> newSetName(
    SetArchive archive,
    String bandId, {
    required CopyName copyName,
    String? except,
  }) async {
    String? day(DateTime? date) =>
        date == null ? null : '${date.year}-${date.month}-${date.day}';
    final date = day(
      DateTime.tryParse(archive.set['gigDate'] as String? ?? ''),
    );
    final taken = {
      for (final s in await (db.select(
        db.setlists,
      )..where((s) => s.bandId.equals(bandId) & s.deleted.equals(false))).get())
        if (s.id != except && day(s.gigDate) == date)
          s.name.trim().toLowerCase(),
    };
    final name = archive.name.trim();
    if (!taken.contains(name.toLowerCase())) return name;
    for (var n = 1; ; n++) {
      final candidate = copyName(name, n);
      if (!taken.contains(candidate.toLowerCase())) return candidate;
    }
  }

  /// What importing [archive] into [bandId] would find. [canCreateSongs]:
  /// whether the person may create songs in the band's library;
  /// [canEditSong]: whether they may add attachments to an existing song
  /// (ADR-0023).
  Future<SetArchivePreview> preview(
    SetArchive archive, {
    required String bandId,
    required bool canCreateSongs,
    required CopyName copyName,
    bool Function(SongEntry song)? canEditSong,
  }) async {
    final existing = await backup.existingSongs(await _libraryOf(bandId));
    final arrangements = ArrangementRepository(db);
    var identical = 0, differing = 0, added = 0, conflicts = 0, files = 0;
    final missing = <String>[];
    final matched = <String, String>{};
    for (final song in archive.contents.songs) {
      final (match, same) = existing.match(
        song,
        archive.contents.sourceOf(song),
      );
      if (match != null) {
        matched[song['id'] as String] = match.id;
        same ? identical++ : differing++;
        if (canEditSong?.call(match) ?? false) {
          files += (await backup.missingAttachments(
            archive.contents,
            song,
            match.id,
          )).length;
        }
      } else if (canCreateSongs) {
        added++;
      } else {
        missing.add(song['title'] as String? ?? '');
      }
    }
    for (final a in archive.contents.arrangements) {
      final songId = matched[a['songId']];
      if (songId != null && await arrangements.get(bandId, songId) != null) {
        conflicts++;
      }
    }
    return SetArchivePreview(
      songs: archive.contents.songs.length,
      identical: identical,
      differing: differing,
      added: added,
      missing: missing,
      arrangementConflicts: conflicts,
      attachmentsAdded: files,
      existingSet: await existingSet(archive, bandId),
      newName: await newSetName(archive, bandId, copyName: copyName),
    );
  }

  /// Imports [archive] into [bandId] with what [options] choose (and the
  /// archive holds). [replace]: replace the same set of the band
  /// ([existingSet]) instead of adding one. [overwriteArrangements]:
  /// arrangements of the band are replaced by the archive's. Songs that are
  /// missing and may not be created ([canCreateSongs] false) become text
  /// items with [missingNote]. An added set gets a [copyName] if the band
  /// has a set with the same name and date ([newSetName]). Existing songs
  /// the person may edit ([canEditSong]) get the attachments they lack.
  Future<SetArchiveResult> import(
    SetArchive archive, {
    required String bandId,
    required bool canCreateSongs,
    required String Function(String title) missingNote,
    required CopyName copyName,
    SetArchiveOptions options = const SetArchiveOptions(personal: true),
    BackupDuplicates duplicates = BackupDuplicates.keepExisting,
    bool replace = false,
    bool overwriteArrangements = false,
    bool Function(SongEntry song)? canEditSong,
  }) async {
    final chosen = options.and(archive.holds);
    final libraryId = await _libraryOf(bandId);
    final songs = await backup.importSongs(
      archive.contents,
      libraryId: libraryId,
      duplicates: duplicates,
      create: canCreateSongs,
      attachments: chosen.attachments,
      completeAttachments: canEditSong,
    );
    if (chosen.personal) {
      await backup.importPersonal(
        archive.contents,
        libraryId: libraryId,
        songs: songs,
      );
    }

    var arrangementCount = 0;
    if (chosen.arrangements) {
      final arrangements = ArrangementRepository(db, userId: backup.userId);
      for (final a in archive.contents.arrangements) {
        final songId = songs.songIds[a['songId']];
        if (songId == null) continue;
        if (!overwriteArrangements &&
            await arrangements.get(bandId, songId) != null) {
          continue;
        }
        await arrangements.save(
          bandId,
          songId,
          transpose: (a['transpose'] as int?) ?? 0,
          sequence: a['sequence'] as String?,
          tempo: a['tempo'] as int?,
        );
        arrangementCount++;
      }
    }

    final repo = SetRepository(
      db,
      backup.storage,
      bandId: bandId,
      userId: backup.userId,
    );
    final set = archive.set;
    final gigDate = DateTime.tryParse(set['gigDate'] as String? ?? '');
    final venue = set['venue'] as String?;
    final existing = replace ? await existingSet(archive, bandId) : null;
    final String setId;
    if (existing != null) {
      setId = existing.id;
      await repo.updateSet(
        setId,
        name: archive.name,
        gigDate: gigDate,
        venue: venue,
      );
    } else {
      setId = await repo.createSet(
        name: await newSetName(archive, bandId, copyName: copyName),
        gigDate: gigDate,
        venue: venue,
        origin: archive.setId.isEmpty ? null : archive.setId,
      );
    }

    final missing = <String>[];
    await db.transaction(() async {
      await (db.delete(db.setItems)..where((i) => i.setId.equals(setId))).go();
      var position = 0;
      for (final i in [
        for (final e in (set['items'] as List?) ?? const [])
          (e as Map).cast<String, dynamic>(),
      ]) {
        var (:type, :icon) = readItemType(i['type'], i['icon']);
        var note = i['note'] as String?;
        final songId = songs.songIds[i['songId']];
        if (type == SetItemType.song && songId == null) {
          // Not in the library and not created: a text item keeps its
          // place (ADR-0043 §1b); a song not in the archive is left out.
          final title = archive.titleOf(i['songId'] as String?);
          if (title == null) continue;
          missing.add(title);
          type = SetItemType.marker;
          icon = MarkerIcons.warning;
          note = missingNote(title);
        }
        final song = type == SetItemType.song;
        await db
            .into(db.setItems)
            .insert(
              SetItemsCompanion.insert(
                id: _uuid.v4(),
                setId: setId,
                songId: Value(songId),
                position: position++,
                transpose: Value(
                  song && chosen.setSettings
                      ? (i['transpose'] as int?) ?? 0
                      : 0,
                ),
                sequence: Value(
                  song && chosen.setSettings ? i['sequence'] as String? : null,
                ),
                note: Value(note),
                type: type,
                icon: Value(icon),
                played: Value(switch (i['played']) {
                  final Map<String, dynamic> played
                      when song && chosen.setSettings =>
                    PlayedValues.fromJson(played),
                  _ => null,
                }),
              ),
            );
      }
      await markDirty(db, SyncCollection.setlists, setId, scope: bandId);
    });

    return SetArchiveResult(
      setId: setId,
      replaced: existing != null,
      songs: songs,
      missing: missing,
      arrangements: arrangementCount,
    );
  }
}
