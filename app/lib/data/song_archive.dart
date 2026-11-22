import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:path/path.dart' as p;

import 'arrangement_repository.dart';
import 'backup.dart';
import 'database.dart';
import 'import_export.dart' show safeFileName, sourceWithMeta;

/// `format` of a song archive's manifest (ADR-0043 §1c).
const songArchiveFormat = 'setding-songs';

/// Newest `formatVersion` of a song archive this app reads.
const songArchiveFormatVersion = 1;

/// What a song archive holds besides the songs, chosen for the export and
/// again for the import (ADR-0043 §1c).
@immutable
class SongArchiveOptions {
  const SongArchiveOptions({
    this.attachments = true,
    this.arrangements = false,
    this.personal = false,
  });

  /// Attachments (PDFs, images) of the songs.
  final bool attachments;

  /// Key, sequence and tempo of a band for the songs (ADR-0025).
  final bool arrangements;

  /// The exporting person's own adjustments and annotations (ADR-0006).
  /// Off by default: a song archive is often passed on.
  final bool personal;

  /// Everything an import may take over.
  static const all = SongArchiveOptions(arrangements: true, personal: true);

  SongArchiveOptions copyWith({
    bool? attachments,
    bool? arrangements,
    bool? personal,
  }) => SongArchiveOptions(
    attachments: attachments ?? this.attachments,
    arrangements: arrangements ?? this.arrangements,
    personal: personal ?? this.personal,
  );

  /// Only what both allow: what the archive holds and the person chose.
  SongArchiveOptions and(SongArchiveOptions other) => SongArchiveOptions(
    attachments: attachments && other.attachments,
    arrangements: arrangements && other.arrangements,
    personal: personal && other.personal,
  );

  Map<String, bool> toJson() => {
    'attachments': attachments,
    'arrangements': arrangements,
    'personal': personal,
  };

  factory SongArchiveOptions.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    bool flag(String key) => m[key] == true;
    return SongArchiveOptions(
      attachments: flag('attachments'),
      arrangements: flag('arrangements'),
      personal: flag('personal'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SongArchiveOptions &&
      other.attachments == attachments &&
      other.arrangements == arrangements &&
      other.personal == personal;

  @override
  int get hashCode => Object.hash(attachments, arrangements, personal);
}

/// A song archive read into memory, in the shape of a backup archive
/// ([BackupContents]) so the song import is shared.
@immutable
class SongArchive {
  const SongArchive(this.contents);

  final BackupContents contents;

  /// Name of the library the songs were exported from.
  String get libraryName => contents.sourceName;

  /// Name of the band whose arrangements the archive holds, if any.
  String get bandName =>
      ((contents.manifest['band'] as Map?)?['name'] as String?) ?? '';

  /// What the archive holds.
  SongArchiveOptions get holds =>
      SongArchiveOptions.fromJson(contents.manifest['options']);

  /// Titles of the songs, in archive order.
  List<String> get titles => [
    for (final s in contents.songs) s['title'] as String? ?? '',
  ];
}

/// What importing a song archive into a library would find.
@immutable
class SongArchivePreview {
  const SongArchivePreview({
    required this.songs,
    required this.identical,
    required this.differing,
    required this.added,
    required this.attachmentsAdded,
    required this.arrangementConflicts,
  });

  final int songs;

  /// Songs that exist with the same text: the existing ones are used.
  final int identical;

  /// Songs that exist with a different text.
  final int differing;

  /// Songs imported as new songs.
  final int added;

  /// Attachments added to existing songs that lack them.
  final int attachmentsAdded;

  /// Songs whose arrangement in the target band would be overwritten.
  final int arrangementConflicts;
}

/// Result of a song archive import.
@immutable
class SongArchiveResult {
  const SongArchiveResult({required this.songs, required this.arrangements});

  final SongImport songs;

  /// Band arrangements saved.
  final int arrangements;
}

/// Song archive (ADR-0043 §1c): one or several songs exported as ZIP with
/// their ChordPro files, attachments and a manifest, imported again with a
/// preview like a set archive.
class SongArchiveService {
  SongArchiveService(this.backup);

  final BackupService backup;

  AppDatabase get db => backup.db;

  // Export --------------------------------------------------------------------

  /// A file name for the archive of [songs]: the title of a single song,
  /// else `setDING-Songs yyyy-mm-dd`.
  static String fileName(List<SongEntry> songs, {DateTime? now}) {
    if (songs.length == 1) return '${safeFileName(songs.single.title)}.zip';
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'setDING-Songs ${d.year}-${two(d.month)}-${two(d.day)}.zip';
  }

  /// Exports [songIds] (in this order) with what [options] include. The
  /// band arrangements are those of [bandId] (none without it). [readFile]
  /// reads an attachment file (default: from the storage); a missing file
  /// aborts the export with [BackupFileMissingException].
  Future<Uint8List> export(
    List<String> songIds, {
    SongArchiveOptions options = const SongArchiveOptions(),
    String? bandId,
    Future<Uint8List?> Function(AttachmentEntry attachment)? readFile,
    DateTime? now,
  }) async {
    final byId = {
      for (final s in await (db.select(
        db.songs,
      )..where((s) => s.id.isIn(songIds) & s.deleted.equals(false))).get())
        s.id: s,
    };
    final songs = [for (final id in songIds.toSet()) ?byId[id]];
    final libraryId = songs.isEmpty ? localBandId : songs.first.libraryId;
    final library = libraryId == localBandId
        ? null
        : await (db.select(
            db.organizations,
          )..where((o) => o.id.equals(libraryId))).getSingleOrNull();

    final files = <String, Uint8List>{};
    final used = <String>{};
    String unique(String path) {
      final ext = p.extension(path);
      final stem = path.substring(0, path.length - ext.length);
      var candidate = path;
      for (var n = 2; !used.add(candidate.toLowerCase()); n++) {
        candidate = '$stem ($n)$ext';
      }
      return candidate;
    }

    final songJson = <Map<String, dynamic>>[];
    for (final song in songs) {
      final base = safeFileName(song.title);
      final short = song.id.length > 8 ? song.id.substring(0, 8) : song.id;
      String? file;
      if (song.chordproSource.trim().isNotEmpty) {
        file = unique('songs/$base ($short).cho');
        // Readable without setDING: title and artist directives added.
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
          final path = unique(
            'attachments/$base ($short) - '
            '${safeFileName(p.basenameWithoutExtension(a.name))}'
            '${p.extension(a.fileName)}',
          );
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

    final ids = {for (final s in songs) s.id};
    final band = options.arrangements && bandId != null
        ? await (db.select(
            db.bands,
          )..where((b) => b.id.equals(bandId))).getSingleOrNull()
        : null;
    final arrangements = band == null
        ? const <BandArrangement>[]
        : await (db.select(db.bandArrangements)..where(
                (a) =>
                    a.bandId.equals(band.id) &
                    a.songId.isIn(ids) &
                    a.deleted.equals(false),
              ))
              .get();
    final (overlays, strokes) = options.personal
        ? await backup.personalData(libraryId, ids)
        : (const <SongOverlay>[], const <AnnotationRow>[]);

    files[backupManifestName] = BackupService.json({
      'format': songArchiveFormat,
      'formatVersion': songArchiveFormatVersion,
      'app': backup.appVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'source': {'id': libraryId, 'name': library?.name ?? ''},
      'band': ?(band == null ? null : {'id': band.id, 'name': band.name}),
      'options': options.copyWith(arrangements: band != null).toJson(),
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

  /// Reads a song archive; null if [zip] is none. Throws
  /// [BackupFormatException] with `newerVersion` if a newer app wrote it.
  static Future<SongArchive?> read(Uint8List zip) async {
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
        songArchiveFormat,
        songArchiveFormatVersion,
      );
    } on BackupFormatException catch (e) {
      if (e.newerVersion != null) rethrow;
      return null;
    }
    if (manifest['songs'] is! List) return null;
    return SongArchive(BackupContents(manifest, files));
  }

  /// What importing [archive] into [libraryId] would find. [canEditSong]:
  /// whether the person may add attachments to an existing song; [bandId]:
  /// the band that gets the archive's arrangements (ADR-0023).
  Future<SongArchivePreview> preview(
    SongArchive archive, {
    required String libraryId,
    bool Function(SongEntry song)? canEditSong,
    String? bandId,
  }) async {
    final existing = await backup.existingSongs(libraryId);
    var identical = 0, differing = 0, added = 0, files = 0, conflicts = 0;
    final matched = <String, String>{};
    for (final song in archive.contents.songs) {
      final (match, same) = existing.match(
        song,
        archive.contents.sourceOf(song),
      );
      if (match == null) {
        added++;
        continue;
      }
      matched[song['id'] as String] = match.id;
      same ? identical++ : differing++;
      if (canEditSong?.call(match) ?? false) {
        files += (await backup.missingAttachments(
          archive.contents,
          song,
          match.id,
        )).length;
      }
    }
    if (bandId != null) {
      final arrangements = ArrangementRepository(db);
      for (final a in archive.contents.arrangements) {
        final songId = matched[a['songId']];
        if (songId != null && await arrangements.get(bandId, songId) != null) {
          conflicts++;
        }
      }
    }
    return SongArchivePreview(
      songs: archive.contents.songs.length,
      identical: identical,
      differing: differing,
      added: added,
      attachmentsAdded: files,
      arrangementConflicts: conflicts,
    );
  }

  /// Imports [archive] into [libraryId] with what [options] choose (and the
  /// archive holds). Existing songs the person may edit ([canEditSong]) get
  /// the attachments they lack. The arrangements go to [bandId] (none
  /// without it); existing ones are kept unless [overwriteArrangements].
  Future<SongArchiveResult> import(
    SongArchive archive, {
    required String libraryId,
    SongArchiveOptions options = SongArchiveOptions.all,
    BackupDuplicates duplicates = BackupDuplicates.keepExisting,
    bool Function(SongEntry song)? canEditSong,
    String? bandId,
    bool overwriteArrangements = false,
  }) async {
    final chosen = options.and(archive.holds);
    final songs = await backup.importSongs(
      archive.contents,
      libraryId: libraryId,
      duplicates: duplicates,
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
    var count = 0;
    if (chosen.arrangements && bandId != null) {
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
        count++;
      }
    }
    return SongArchiveResult(songs: songs, arrangements: count);
  }
}
