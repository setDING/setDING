import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:archive/archive.dart';
import 'package:chordpro/chordpro.dart' show Subdivision;
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'arrangement_repository.dart';
import 'attachment_storage.dart';
import 'database.dart';
import 'demo_song.dart' show demoSongSource;
import 'marker_icons.dart';
import 'import_export.dart' show archiveExtension, safeFileName, sourceWithMeta;
import 'outbox.dart';
import 'set_repository.dart';
import 'song_repository.dart';
import 'song_review.dart' show SongReviewRepository, songToReview;

const _uuid = Uuid();

/// `format` of a backup archive's manifest (ADR-0043).
const backupFormat = 'setding-backup';

/// Newest `formatVersion` this app reads. A minor addition (an optional
/// field) keeps the version; anything an older app would misread needs a
/// new one.
const backupFormatVersion = 2;

/// `formatVersion` of the archive of one library (ADR-0043).
const backupLibraryFormatVersion = 1;

/// `formatVersion` of a full backup (#639): several libraries in folders,
/// the person's own adjustments of other libraries and their settings.
const backupFullFormatVersion = 2;

/// Name of the manifest inside the archive.
const backupManifestName = 'manifest.json';

/// The archive is not a backup, or one this app cannot read.
class BackupFormatException implements Exception {
  const BackupFormatException({this.newerVersion});

  /// The archive was written by a newer app ([backupFormatVersion] is
  /// lower).
  final int? newerVersion;

  @override
  String toString() => newerVersion == null
      ? 'Not a setDING backup'
      : 'Backup format $newerVersion is newer than $backupFormatVersion';
}

/// An attachment file could not be read for the export (not downloaded,
/// web: not loadable).
class BackupFileMissingException implements Exception {
  const BackupFileMissingException(this.songTitle, this.name);

  final String songTitle;
  final String name;

  @override
  String toString() => 'Attachment "$name" of "$songTitle" is not available';
}

/// Why an organization cannot be exported right now (ADR-0043): the archive
/// would miss something that is not on this device yet.
enum BackupBlocker {
  /// Local changes are waiting to be pushed.
  pendingChanges,

  /// Songs of the library have open sync conflicts.
  conflicts,

  /// Attachment files are not downloaded yet (native apps).
  missingFiles,
}

/// How songs of the archive that exist in the target library with a
/// different ChordPro text are imported.
enum BackupDuplicates {
  /// As additional songs next to the existing ones.
  addAll,

  /// Not at all: the existing song is used.
  keepExisting,
}

/// A backup archive read into memory.
@immutable
class BackupContents {
  const BackupContents(this.manifest, this.files);

  final Map<String, dynamic> manifest;

  /// Files of the archive by their path.
  final Map<String, Uint8List> files;

  List<Map<String, dynamic>> _list(String key) => [
    for (final e in (manifest[key] as List?) ?? const [])
      (e as Map).cast<String, dynamic>(),
  ];

  List<Map<String, dynamic>> get songs => _list('songs');
  List<Map<String, dynamic>> get bands => _list('bands');
  List<Map<String, dynamic>> get sets => _list('sets');
  List<Map<String, dynamic>> get arrangements => _list('arrangements');
  List<Map<String, dynamic>> get overlays => _list('overlays');
  List<Map<String, dynamic>> get annotations => _list('annotations');

  /// Name of the library the archive was made from.
  String get sourceName =>
      ((manifest['source'] as Map?)?['name'] as String?) ?? '';

  /// The device that wrote the archive (automatic backup), or null.
  String? get device => (manifest['source'] as Map?)?['device'] as String?;

  /// When the archive was written, or null.
  DateTime? get createdAt =>
      DateTime.tryParse(manifest['createdAt'] as String? ?? '')?.toLocal();

  /// The ChordPro text of a song of the archive ('' for PDF-only songs).
  String sourceOf(Map<String, dynamic> song) {
    final file = song['file'] as String?;
    final bytes = file == null ? null : files[file];
    return bytes == null ? '' : utf8.decode(bytes, allowMalformed: true);
  }
}

/// The person's own adjustments and annotations of an organization without
/// library rights, from a full backup (#639).
@immutable
class PersonalBackup {
  const PersonalBackup(
    this.libraryId,
    this.name,
    this.overlays,
    this.annotations,
  );

  final String libraryId;
  final String name;
  final List<Map<String, dynamic>> overlays;
  final List<Map<String, dynamic>> annotations;

  int get songs => {
    for (final o in [...overlays, ...annotations]) o['songId'],
  }.length;
}

/// A backup archive: one library (version 1) or a full backup (version 2,
/// #639) with several libraries, personal data and settings.
@immutable
class FullBackup {
  const FullBackup(this.manifest, this.libraries);

  final Map<String, dynamic> manifest;
  final List<BackupContents> libraries;

  /// A full backup (version 2), not the archive of one library.
  bool get isFull => manifest['formatVersion'] != backupLibraryFormatVersion;

  List<PersonalBackup> get personal => [
    for (final e in (manifest['personal'] as List?) ?? const [])
      if (e is Map)
        PersonalBackup(
          e['id'] as String? ?? '',
          e['name'] as String? ?? '',
          [
            for (final o in (e['overlays'] as List?) ?? const [])
              (o as Map).cast<String, dynamic>(),
          ],
          [
            for (final x in (e['annotations'] as List?) ?? const [])
              (x as Map).cast<String, dynamic>(),
          ],
        ),
  ];

  Map<String, Object?> _settings(String scope) =>
      switch ((manifest['settings'] as Map?)?[scope]) {
        final Map<dynamic, dynamic> m => m.cast<String, Object?>(),
        _ => const {},
      };

  /// Personal settings (ADR-0027) at the time of the backup.
  Map<String, Object?> get personalSettings => _settings('personal');

  /// Settings of the device the backup was made on.
  Map<String, Object?> get deviceSettings => _settings('device');

  bool get hasSettings =>
      personalSettings.isNotEmpty || deviceSettings.isNotEmpty;
}

/// What importing an archive into a library would find (ADR-0043).
@immutable
class BackupPreview {
  const BackupPreview({
    required this.songs,
    required this.identical,
    required this.differing,
  });

  final int songs;

  /// Songs that exist with the same ChordPro text: the existing ones are
  /// used.
  final int identical;

  /// Songs that exist (same ID, or same title and artist) with a different
  /// text: the person chooses [BackupDuplicates].
  final int differing;
}

/// Result of an import.
@immutable
class BackupImportResult {
  const BackupImportResult({
    required this.imported,
    required this.identical,
    required this.additional,
    required this.keptExisting,
    required this.sets,
    required this.files,
  });

  /// Songs imported as new songs (including [additional]).
  final int imported;

  /// Songs not imported because they exist with the same text.
  final int identical;

  /// Songs imported next to an existing song with a different text, as
  /// (new ID, title), to compare and delete.
  final List<({String id, String title})> additional;

  /// Songs with a different text not imported ([BackupDuplicates.keepExisting]).
  final int keptExisting;

  final int sets;
  final int files;
}

/// Backup archive of a whole library (ADR-0043): export and import, always
/// as a copy with new IDs.
class BackupService {
  BackupService(this.db, this.storage, {this.userId, this.appVersion = ''});

  final AppDatabase db;
  final AttachmentStorage storage;

  /// The signed-in user: their own personal adjustments and annotations go
  /// into the archive and are imported for them (ADR-0020).
  final String? userId;

  /// Written into the manifest.
  final String appVersion;

  // Export --------------------------------------------------------------------

  /// What keeps [libraryId] from being exported after a sync, or null.
  /// [checkFiles] is false on the web client, which loads the files for the
  /// export instead.
  Future<BackupBlocker?> blocker(
    String libraryId, {
    bool checkFiles = true,
  }) async {
    if (libraryId == localBandId) return null;
    if ((await db.select(db.syncOutbox).get()).isNotEmpty) {
      return BackupBlocker.pendingChanges;
    }
    final conflicts = await (db.select(db.songConflicts).join([
      innerJoin(db.songs, db.songs.id.equalsExp(db.songConflicts.songId)),
    ])..where(db.songs.libraryId.equals(libraryId))).get();
    if (conflicts.isNotEmpty) return BackupBlocker.conflicts;
    if (checkFiles) {
      for (final (a, _) in await _attachments(libraryId)) {
        if (!await storage.exists(a.fileName)) {
          return BackupBlocker.missingFiles;
        }
      }
    }
    return null;
  }

  /// The attachments of the library's songs that are not deleted, with
  /// their song.
  Future<List<(AttachmentEntry, SongEntry)>> _attachments(
    String libraryId,
  ) async =>
      (await (db.select(db.attachments).join([
                  innerJoin(
                    db.songs,
                    db.songs.id.equalsExp(db.attachments.songId),
                  ),
                ])
                ..where(
                  db.songs.libraryId.equals(libraryId) &
                      db.songs.deleted.equals(false) &
                      db.attachments.deleted.equals(false),
                )
                ..orderBy([OrderingTerm.asc(db.attachments.name)]))
              .get())
          .map((r) => (r.readTable(db.attachments), r.readTable(db.songs)))
          .toList();

  /// Exports [libraryId] (the local library or an organization, named
  /// [libraryName]) with the sets and arrangements of its bands on this
  /// device. [readFile] reads an attachment file (default: from the
  /// storage); null or an error means it is missing, which aborts the
  /// export with [BackupFileMissingException].
  Future<Uint8List> export(
    String libraryId, {
    required String libraryName,
    Future<Uint8List?> Function(AttachmentEntry attachment)? readFile,
    DateTime? now,
    String? device,
  }) async => compute(
    _zip,
    await _collect(
      libraryId,
      libraryName: libraryName,
      readFile: readFile,
      now: now,
      device: device,
    ),
  );

  /// A fingerprint of what [export] would write for [libraryId], without
  /// reading the attachment files (their ID, file and last change stand in
  /// for them) and without zipping: it changes when the library changes, so
  /// the automatic backup (ADR-0054) runs only after changes.
  Future<String> fingerprint(String libraryId) async {
    final files = await _collect(
      libraryId,
      libraryName: '',
      readFile: (a) async => Uint8List.fromList(
        utf8.encode('${a.id} ${a.fileName} ${a.updatedAt.toIso8601String()}'),
      ),
      now: DateTime.utc(2000),
    );
    final all = BytesBuilder(copy: false);
    for (final name in files.keys.toList()..sort()) {
      all
        ..add(utf8.encode('$name\n'))
        ..add(files[name]!);
    }
    return sha256.convert(all.takeBytes()).toString();
  }

  /// The files of the archive of one library (see [export]).
  Future<Map<String, Uint8List>> _collect(
    String libraryId, {
    required String libraryName,
    Future<Uint8List?> Function(AttachmentEntry attachment)? readFile,
    DateTime? now,
    String? device,
  }) async {
    final files = <String, Uint8List>{};
    final used = <String>{};
    String unique(String path) {
      var candidate = path;
      var n = 2;
      final ext = p.extension(path);
      final stem = path.substring(0, path.length - ext.length);
      while (!used.add(candidate.toLowerCase())) {
        candidate = '$stem ($n)$ext';
        n++;
      }
      return candidate;
    }

    final songs =
        await (db.select(db.songs)
              ..where(
                (s) => s.libraryId.equals(libraryId) & s.deleted.equals(false),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.title)]))
            .get();
    final attachmentsBySong = <String, List<AttachmentEntry>>{};
    for (final (a, song) in await _attachments(libraryId)) {
      attachmentsBySong.putIfAbsent(song.id, () => []).add(a);
    }
    final songJson = <Map<String, dynamic>>[];
    for (final song in songs) {
      final base = safeFileName(song.title);
      final short = song.id.length > 8 ? song.id.substring(0, 8) : song.id;
      String? file;
      if (song.chordproSource.isNotEmpty) {
        file = unique('songs/$base ($short).cho');
        files[file] = Uint8List.fromList(utf8.encode(song.chordproSource));
      }
      final attachments = <Map<String, dynamic>>[];
      for (final a in attachmentsBySong[song.id] ?? const <AttachmentEntry>[]) {
        Uint8List? bytes;
        try {
          bytes = await (readFile?.call(a) ?? readStored(a));
        } catch (_) {
          bytes = null;
        }
        if (bytes == null) throw BackupFileMissingException(song.title, a.name);
        final ext = p.extension(a.fileName);
        final stem = p.basenameWithoutExtension(a.name);
        final path = unique(
          'attachments/$base ($short) - ${safeFileName(stem)}$ext',
        );
        files[path] = bytes;
        attachments.add({
          'id': a.id,
          'name': a.name,
          'file': path,
          'pages': ?a.pages,
        });
      }
      songJson.add({
        'id': song.id,
        'title': song.title,
        'artist': ?song.artist,
        'file': ?file,
        'attachments': attachments,
        ...songFieldsJson(song),
        // Kept when the local library is replaced (ADR-0054, #876).
        'createdAt': ?song.createdAt?.toUtc().toIso8601String(),
      });
    }

    final bands =
        await (db.select(db.bands)..where(
              (b) =>
                  b.deleted.equals(false) &
                  (libraryId == localBandId
                      ? b.id.equals(localBandId)
                      : b.organizationId.equals(libraryId)),
            ))
            .get();
    final bandIds = [for (final b in bands) b.id];
    final songIds = {for (final s in songs) s.id};
    final sets =
        await (db.select(db.setlists)
              ..where((s) => s.bandId.isIn(bandIds) & s.deleted.equals(false))
              ..orderBy([(s) => OrderingTerm.asc(s.name)]))
            .get();
    final setJson = <Map<String, dynamic>>[];
    for (final set in sets) {
      final items =
          await (db.select(db.setItems)
                ..where((i) => i.setId.equals(set.id))
                ..orderBy([(i) => OrderingTerm.asc(i.position)]))
              .get();
      setJson.add({
        'id': set.id,
        'bandId': set.bandId,
        'name': set.name,
        'gigDate': ?set.gigDate?.toIso8601String(),
        'venue': ?set.venue,
        'items': [
          for (final i in items)
            {
              'type': writeItemType(i.type, i.icon),
              if (i.songId != null && songIds.contains(i.songId))
                'songId': i.songId,
              if (i.transpose != 0) 'transpose': i.transpose,
              'sequence': ?i.sequence,
              'note': ?i.note,
              if (i.type == SetItemType.marker) 'icon': ?i.icon,
              if (i.played case final played? when !played.isEmpty)
                'played': played.toJson(),
            },
        ],
      });
    }
    final arrangements =
        await (db.select(db.bandArrangements)..where(
              (a) =>
                  a.bandId.isIn(bandIds) &
                  a.songId.isIn(songIds) &
                  a.deleted.equals(false),
            ))
            .get();
    final (overlays, strokes) = await personalData(libraryId, songIds);

    final manifest = {
      'format': backupFormat,
      'formatVersion': backupLibraryFormatVersion,
      'app': appVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'source': {
        'kind': libraryId == localBandId ? 'local' : 'organization',
        'id': libraryId,
        'name': libraryName,
        // The device that wrote it (automatic backup, ADR-0054).
        'device': ?device,
      },
      'songs': songJson,
      'bands': [
        for (final b in bands) {'id': b.id, 'name': b.name},
      ],
      'sets': setJson,
      'arrangements': [
        for (final a in arrangements)
          {
            'bandId': a.bandId,
            'songId': a.songId,
            'transpose': a.transpose,
            'sequence': ?a.sequence,
            'tempo': ?a.tempo,
          },
      ],
      'overlays': [for (final o in overlays) overlayJson(o)],
      'annotations': [for (final x in strokes) strokeJson(x)],
    };
    files[backupManifestName] = json(manifest);
    return files;
  }

  /// [value] as indented JSON.
  static Uint8List json(Object value) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(value)),
  );

  /// A full backup (#639): the archives of [libraries] (which the person may
  /// export) in folders, the person's own adjustments and annotations of
  /// [personalOnly] (organizations without library rights), and the
  /// [personalSettings] and [deviceSettings].
  Future<Uint8List> exportAll({
    required List<({String id, String name})> libraries,
    List<({String id, String name})> personalOnly = const [],
    Map<String, Object?> personalSettings = const {},
    Map<String, Object?> deviceSettings = const {},
    Future<Uint8List?> Function(AttachmentEntry attachment)? readFile,
    DateTime? now,
  }) async {
    final files = <String, Uint8List>{};
    final entries = <Map<String, dynamic>>[];
    for (final (index, library) in libraries.indexed) {
      final folder = 'libraries/${index + 1}/';
      final library_ = await _collect(
        library.id,
        libraryName: library.name,
        readFile: readFile,
        now: now,
      );
      for (final MapEntry(:key, :value) in library_.entries) {
        files['$folder$key'] = value;
      }
      entries.add({
        'kind': library.id == localBandId ? 'local' : 'organization',
        'id': library.id,
        'name': library.name,
        'path': folder,
      });
    }
    final personal = <Map<String, dynamic>>[];
    for (final library in personalOnly) {
      final (overlays, strokes) = await personalData(library.id, null);
      personal.add({
        'id': library.id,
        'name': library.name,
        'overlays': [for (final o in overlays) overlayJson(o)],
        'annotations': [for (final x in strokes) strokeJson(x)],
      });
    }
    files[backupManifestName] = json({
      'format': backupFormat,
      'formatVersion': backupFullFormatVersion,
      'app': appVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'libraries': entries,
      'personal': personal,
      'settings': {'personal': personalSettings, 'device': deviceSettings},
    });
    return compute(_zip, files);
  }

  /// The person's adjustments and annotations of the songs of [libraryId]
  /// ([songIds] if given, else all songs that are not deleted).
  Future<(List<SongOverlay>, List<AnnotationRow>)> personalData(
    String libraryId,
    Set<String>? songIds,
  ) async {
    final ids =
        songIds ??
        {
          for (final s
              in await (db.select(db.songs)..where(
                    (s) =>
                        s.libraryId.equals(libraryId) & s.deleted.equals(false),
                  ))
                  .get())
            s.id,
        };
    final owner = overlayOwnerFor(libraryId, userId);
    final overlays = await (db.select(
      db.personalOverlays,
    )..where((o) => o.ownerId.equals(owner) & o.songId.isIn(ids))).get();
    final strokes =
        await (db.select(db.annotations)..where(
              (x) =>
                  x.ownerId.equals(owner) &
                  x.songId.isIn(ids) &
                  x.stroke.isNotNull(),
            ))
            .get();
    return (overlays, strokes);
  }

  static Map<String, dynamic> strokeJson(AnnotationRow x) => {
    'id': x.id,
    'songId': x.songId,
    'target': x.target,
    'stroke': x.stroke,
    'updatedAt': x.updatedAt,
  };

  /// An attachment file from the storage, or null if it is not there.
  Future<Uint8List?> readStored(AttachmentEntry a) async {
    final file = storage.file(a.fileName);
    return await file.exists() ? file.readAsBytes() : null;
  }

  /// The language version group and the language set by hand of [song]
  /// in a manifest (ADR-0053): `workId` (the group in the exporting
  /// library) and `language`; and its review status (ADR-0060):
  /// `reviewState` and `reviewReason`; each only when set.
  static Map<String, dynamic> songFieldsJson(SongEntry song) => {
    'workId': ?song.workId,
    'language': ?song.language,
    'reviewState': ?song.reviewState,
    'reviewReason': ?song.reviewReason,
  };

  /// Sets the review status a song had in an archive (ADR-0060): an
  /// archive import carries it, it never sets a song to review itself.
  static Future<void> restoreReview(
    SongRepository songs,
    String id,
    Map<String, dynamic> song,
  ) async {
    if (song['reviewState'] != songToReview) return;
    await SongReviewRepository(
      songs.db,
      songs.storage,
      userId: songs.userId,
    ).setToReview(id, reason: song['reviewReason'] as String?);
  }

  static Map<String, dynamic> overlayJson(SongOverlay o) => {
    'songId': o.songId,
    'transpose': o.transpose,
    'capoFret': ?o.capoFret,
    'fontScale': o.fontScale,
    'notes': ?o.notes,
    'chordView': ?o.chordView?.name,
    // For older app versions, which only know Nashville numbers.
    'nashville': ?o.chordView?.isDegrees,
    'liveView': ?o.liveView,
    'hideAnnotations': o.hideAnnotations,
    'verseChords': o.verseChords.name,
    'stackedChoruses': o.stackedChoruses,
    'midi': ?o.midi?.toJson(),
    'midiPrograms': ?o.midiPrograms?.toJson(),
    'clickGrouping': ?o.clickGrouping,
    'clickSubdivision': ?o.clickSubdivision?.name,
  };

  /// A file name for the archive of [libraryName] on [date].
  static String fileName(String libraryName, DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${date.year}-${two(date.month)}-${two(date.day)}';
    return '${safeFileName('Backup $libraryName $day')}$archiveExtension';
  }

  // Import --------------------------------------------------------------------

  /// Whether [zip] is a backup archive (a ZIP with a backup manifest).
  static Future<bool> isBackup(Uint8List zip) async {
    try {
      await readFull(zip);
      return true;
    } on BackupFormatException catch (e) {
      // A newer backup is still a backup: the import reports it.
      return e.newerVersion != null;
    } catch (_) {
      return false;
    }
  }

  /// Reads the archive of one library; throws [BackupFormatException] if it
  /// is none, a newer one or a full backup ([readFull]).
  static Future<BackupContents> read(Uint8List zip) async {
    final full = await readFull(zip);
    if (full.isFull) throw const BackupFormatException();
    return full.libraries.single;
  }

  /// Reads a backup archive, of one library (version 1) or a full backup
  /// (version 2); throws [BackupFormatException] if it is none or a newer
  /// one.
  static Future<FullBackup> readFull(Uint8List zip) async {
    final files = await compute(_unzipPaths, zip);
    final manifest = _manifest(files[backupManifestName]);
    final version = manifest['formatVersion'] as int;
    if (version == backupLibraryFormatVersion) {
      return FullBackup(manifest, [BackupContents(manifest, files)]);
    }
    final libraries = <BackupContents>[];
    for (final entry in (manifest['libraries'] as List?) ?? const []) {
      final folder = ((entry as Map)['path'] as String?) ?? '';
      if (folder.isEmpty) continue;
      final inner = {
        for (final MapEntry(:key, :value) in files.entries)
          if (key.startsWith(folder)) key.substring(folder.length): value,
      };
      libraries.add(
        BackupContents(_manifest(inner[backupManifestName]), inner),
      );
    }
    return FullBackup(manifest, libraries);
  }

  static Map<String, dynamic> _manifest(Uint8List? raw) =>
      decodeManifest(raw, backupFormat, backupFormatVersion);

  /// The manifest [raw] of an archive of [format]; throws
  /// [BackupFormatException] if it is none or newer than [maxVersion].
  static Map<String, dynamic> decodeManifest(
    Uint8List? raw,
    String format,
    int maxVersion,
  ) {
    if (raw == null) throw const BackupFormatException();
    final Object? manifest;
    try {
      manifest = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw const BackupFormatException();
    }
    if (manifest is! Map || manifest['format'] != format) {
      throw const BackupFormatException();
    }
    final version = manifest['formatVersion'];
    if (version is! int) throw const BackupFormatException();
    if (version > maxVersion) {
      throw BackupFormatException(newerVersion: version);
    }
    return manifest.cast<String, dynamic>();
  }

  /// Restores the person's adjustments and annotations of [personal] on
  /// the songs that are on this device with the same ID (the organization's
  /// songs). Adjustments replace the current ones; annotations are added by
  /// stroke ID. Returns the number of songs.
  Future<int> restorePersonal(PersonalBackup personal) async {
    final songs = SongRepository(
      db,
      storage,
      libraryId: personal.libraryId,
      userId: userId,
    );
    final owner = overlayOwnerFor(personal.libraryId, userId);
    final present = {
      for (final s
          in await (db.select(db.songs)..where(
                (s) =>
                    s.libraryId.equals(personal.libraryId) &
                    s.deleted.equals(false),
              ))
              .get())
        s.id,
    };
    final attachments = {
      for (final a in await (db.select(
        db.attachments,
      )..where((a) => a.deleted.equals(false))).get())
        a.id,
    };
    final restored = <String>{};
    for (final o in personal.overlays) {
      final songId = o['songId'] as String?;
      if (songId == null || !present.contains(songId)) continue;
      final liveView = o['liveView'] as String?;
      await songs.saveOverlay(
        _overlayFrom(
          await songs.getOverlay(songId),
          o,
          liveView != null && attachments.contains(liveView) ? liveView : null,
        ),
      );
      restored.add(songId);
    }
    await db.transaction(() async {
      for (final x in personal.annotations) {
        final songId = x['songId'] as String?;
        final target = x['target'] as String? ?? '';
        if (songId == null || !present.contains(songId)) continue;
        if (target.isNotEmpty && !attachments.contains(target)) continue;
        await db
            .into(db.annotations)
            .insert(
              AnnotationsCompanion.insert(
                id: x['id'] as String? ?? _uuid.v4(),
                ownerId: owner,
                songId: songId,
                target: Value(target),
                stroke: Value(x['stroke'] as String?),
                updatedAt:
                    (x['updatedAt'] as int?) ??
                    DateTime.now().millisecondsSinceEpoch,
                pending: const Value(1),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        restored.add(songId);
      }
    });
    return restored.length;
  }

  /// [current] with the adjustments of an archive entry [o].
  static SongOverlay _overlayFrom(
    SongOverlay current,
    Map<String, dynamic> o,
    String? liveView,
  ) => current.copyWith(
    transpose: (o['transpose'] as int?) ?? 0,
    capoFret: Value(o['capoFret'] as int?),
    fontScale: (o['fontScale'] as num?)?.toDouble() ?? 1.0,
    notes: Value(o['notes'] as String?),
    chordView: Value(chordViewOf(o['chordView'], o['nashville'])),
    liveView: Value(liveView),
    hideAnnotations: (o['hideAnnotations'] as bool?) ?? false,
    verseChords:
        VerseChords.values.asNameMap()[o['verseChords']] ?? VerseChords.all,
    stackedChoruses: o['stackedChoruses'] == true,
    midi: Value(MidiProgram.fromJson(o['midi'])),
    midiPrograms: Value(MidiPrograms.fromJson(o['midiPrograms'])),
    clickGrouping: Value(o['clickGrouping'] as String?),
    clickSubdivision: Value(
      Subdivision.values.asNameMap()[o['clickSubdivision']],
    ),
  );

  /// Existing songs of [libraryId] by ID and by title and artist.
  Future<ExistingSongs> existingSongs(String libraryId) async {
    final songs =
        await (db.select(db.songs)..where(
              (s) => s.libraryId.equals(libraryId) & s.deleted.equals(false),
            ))
            .get();
    return ExistingSongs(songs);
  }

  /// What importing [contents] into [libraryId] would find.
  Future<BackupPreview> preview(
    BackupContents contents,
    String libraryId,
  ) async {
    final existing = await existingSongs(libraryId);
    var identical = 0, differing = 0;
    for (final song in contents.songs) {
      switch (existing.match(song, contents.sourceOf(song))) {
        case (_, true):
          identical++;
        case (_?, false):
          differing++;
        case (null, _):
          break;
      }
    }
    return BackupPreview(
      songs: contents.songs.length,
      identical: identical,
      differing: differing,
    );
  }

  /// Imports [contents] into the library [libraryId] as copies with new
  /// IDs. [bands] maps each band of the archive to a band of the target
  /// library, or null to skip its sets and arrangements.
  Future<BackupImportResult> import(
    BackupContents contents, {
    required String libraryId,
    required Map<String, String?> bands,
    BackupDuplicates duplicates = BackupDuplicates.addAll,
  }) async {
    final songs = await importSongs(
      contents,
      libraryId: libraryId,
      duplicates: duplicates,
    );
    await importPersonal(contents, libraryId: libraryId, songs: songs);
    final songMap = songs.songIds;
    final arrangements = ArrangementRepository(db);
    for (final a in contents.arrangements) {
      final band = bands[a['bandId']];
      final songId = songMap[a['songId']];
      if (band == null || songId == null) continue;
      // An existing song keeps the band's current arrangement.
      if (await arrangements.get(band, songId) != null) continue;
      await arrangements.save(
        band,
        songId,
        transpose: (a['transpose'] as int?) ?? 0,
        sequence: a['sequence'] as String?,
        tempo: a['tempo'] as int?,
      );
    }

    var setCount = 0;
    for (final s in contents.sets) {
      final band = bands[s['bandId']];
      if (band == null) continue;
      final repo = SetRepository(db, storage, bandId: band);
      final gigDate = DateTime.tryParse(s['gigDate'] as String? ?? '');
      final setId = await repo.createSet(
        name: s['name'] as String? ?? '',
        gigDate: gigDate,
        venue: s['venue'] as String?,
      );
      await _insertItems(s, setId: setId, band: band, songMap: songMap);
      setCount++;
    }

    return BackupImportResult(
      imported: songs.imported.length,
      identical: songs.identical,
      additional: songs.additional,
      keptExisting: songs.keptExisting,
      sets: setCount,
      files: songs.files,
    );
  }

  /// Inserts the items of the archive set [s] into the set [setId] of
  /// [band]; song items whose song is not in [songMap] are left out.
  Future<void> _insertItems(
    Map<String, dynamic> s, {
    required String setId,
    required String band,
    required Map<String, String> songMap,
  }) => db.transaction(() async {
    var position = 0;
    for (final i in [
      for (final e in (s['items'] as List?) ?? const [])
        (e as Map).cast<String, dynamic>(),
    ]) {
      final (:type, :icon) = readItemType(i['type'], i['icon']);
      final songId = songMap[i['songId']];
      // A song item whose song is not in the archive is left out.
      if (type == SetItemType.song && songId == null) continue;
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              id: _uuid.v4(),
              setId: setId,
              songId: Value(songId),
              position: position++,
              transpose: Value((i['transpose'] as int?) ?? 0),
              sequence: Value(i['sequence'] as String?),
              note: Value(i['note'] as String?),
              type: type,
              icon: Value(icon),
              played: Value(switch (i['played']) {
                final Map<String, dynamic> played => PlayedValues.fromJson(
                  played,
                ),
                _ => null,
              }),
            ),
          );
    }
    await markDirty(db, SyncCollection.setlists, setId, scope: band);
  });

  // Replacing the local library (ADR-0054 section 2) -------------------------

  /// The oldest change to the local library after [since] (all changes
  /// when null) that is not in the trash, or null when there is none. The
  /// demo song alone does not count.
  Future<DateTime?> oldestLocalChange({DateTime? since}) async {
    final after = Variable<DateTime>(since ?? DateTime(1970));
    final row = await db
        .customSelect(
          'SELECT MIN(t) AS oldest FROM ('
          'SELECT updated_at AS t FROM songs WHERE library_id = ? AND '
          'deleted = 0 AND updated_at > ? AND chordpro_source <> ? '
          'UNION ALL SELECT updated_at AS t FROM setlists WHERE band_id = ? '
          'AND deleted = 0 AND updated_at > ?)',
          variables: [
            Variable.withString(localBandId),
            after,
            Variable.withString(demoSongSource),
            Variable.withString(localBandId),
            after,
          ],
          readsFrom: {db.songs, db.setlists},
        )
        .getSingle();
    return row.readNullable<DateTime>('oldest');
  }

  /// Whether [contents] is the archive of a local library: only those can
  /// replace the local library.
  static bool isLocalArchive(BackupContents contents) =>
      (contents.manifest['source'] as Map?)?['kind'] == 'local';

  /// The songs and sets of the local library now (not in the trash).
  Future<({int songs, int sets})> localCounts() async {
    final songs =
        await (db.select(db.songs)..where(
              (s) => s.libraryId.equals(localBandId) & s.deleted.equals(false),
            ))
            .get();
    final sets =
        await (db.select(db.setlists)..where(
              (s) => s.bandId.equals(localBandId) & s.deleted.equals(false),
            ))
            .get();
    return (songs: songs.length, sets: sets.length);
  }

  /// Replaces the whole local library by [contents] (ADR-0054 section 2):
  /// its songs, attachments, sets, arrangements, personal adjustments and
  /// annotations and its trash are removed on the device, then the
  /// archive's records are written with their original IDs. An ID that is
  /// already used outside the local library gets a new one. The play
  /// history of the local band comes from its sets and is restored with
  /// them; settings and organizations are not touched.
  Future<BackupImportResult> replaceLocal(BackupContents contents) async {
    final songs = SongRepository(db, storage, libraryId: localBandId);
    final oldFiles = <String>{};
    final newFiles = <String>{};
    var songCount = 0, setCount = 0, fileCount = 0;
    await db.transaction(() async {
      // Remove -----------------------------------------------------------
      final songIds = [
        for (final s in await (db.select(
          db.songs,
        )..where((s) => s.libraryId.equals(localBandId))).get())
          s.id,
      ];
      final setIds = [
        for (final s in await (db.select(
          db.setlists,
        )..where((s) => s.bandId.equals(localBandId))).get())
          s.id,
      ];
      oldFiles.addAll([
        for (final a in await (db.select(
          db.attachments,
        )..where((a) => a.songId.isIn(songIds))).get())
          a.fileName,
      ]);
      await (db.delete(
        db.annotations,
      )..where((a) => a.songId.isIn(songIds))).go();
      await (db.delete(
        db.personalOverlays,
      )..where((o) => o.songId.isIn(songIds))).go();
      await (db.delete(db.bandArrangements)..where(
            (a) => a.bandId.equals(localBandId) | a.songId.isIn(songIds),
          ))
          .go();
      await (db.delete(
        db.setItems,
      )..where((i) => i.setId.isIn(setIds) | i.songId.isIn(songIds))).go();
      await (db.delete(
        db.setlists,
      )..where((s) => s.bandId.equals(localBandId))).go();
      await (db.delete(
        db.attachments,
      )..where((a) => a.songId.isIn(songIds))).go();
      await (db.delete(
        db.songConflicts,
      )..where((c) => c.songId.isIn(songIds))).go();
      await (db.delete(
        db.songs,
      )..where((s) => s.libraryId.equals(localBandId))).go();

      // Write ------------------------------------------------------------
      Future<String> keep(
        String? id,
        Future<bool> Function(String id) used,
      ) async => id == null || id.isEmpty || await used(id) ? _uuid.v4() : id;
      final songMap = <String, String>{};
      final attachmentMap = <String, String>{};
      for (final song in contents.songs) {
        final original = song['id'] as String;
        final id = await keep(
          original,
          (id) async =>
              await (db.select(
                db.songs,
              )..where((s) => s.id.equals(id))).getSingleOrNull() !=
              null,
        );
        await songs.createSong(
          source: contents.sourceOf(song),
          title: song['title'] as String?,
          artist: song['artist'] as String?,
          id: id,
        );
        // The song keeps when it was created, so the restored songs do not
        // show as *Newest songs*; unknown in archives without it (#876).
        await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
          SongsCompanion(
            createdAt: Value(
              DateTime.tryParse(song['createdAt'] as String? ?? '')?.toLocal(),
            ),
          ),
        );
        songMap[original] = id;
        songCount++;
        if (song['language'] case final String language
            when songLanguages.contains(language)) {
          await songs.setLanguage(id, language);
        }
        // The IDs are kept, so the language version groups too (ADR-0053).
        if (song['workId'] case final String work when work.isNotEmpty) {
          await songs.setWorkId(id, work);
        }
        await restoreReview(songs, id, song);
        for (final a in attachmentsOf(song)) {
          final bytes = contents.files[a['file'] as String? ?? ''];
          if (bytes == null || bytes.length > maxAttachmentBytes) continue;
          final attachmentId = await keep(
            a['id'] as String?,
            (id) async =>
                await (db.select(
                  db.attachments,
                )..where((x) => x.id.equals(id))).getSingleOrNull() !=
                null,
          );
          final ext = p
              .extension(a['file'] as String)
              .replaceFirst('.', '')
              .toLowerCase();
          await songs.addAttachment(
            id,
            name: a['name'] as String? ?? '',
            bytes: bytes,
            pages: a['pages'] as int?,
            extension: ext.isEmpty ? 'pdf' : ext,
            id: attachmentId,
          );
          final stored = await (db.select(
            db.attachments,
          )..where((x) => x.id.equals(attachmentId))).getSingle();
          newFiles.add(stored.fileName);
          if (a['id'] case final String original) {
            attachmentMap[original] = attachmentId;
          }
          fileCount++;
        }
      }
      for (final o in contents.overlays) {
        final songId = songMap[o['songId']];
        if (songId == null) continue;
        final liveView = o['liveView'] as String?;
        await songs.saveOverlay(
          _overlayFrom(
            await songs.getOverlay(songId),
            o,
            liveView == null ? null : attachmentMap[liveView],
          ),
        );
      }
      for (final x in contents.annotations) {
        final songId = songMap[x['songId']];
        final target = x['target'] as String? ?? '';
        final newTarget = target.isEmpty ? '' : attachmentMap[target];
        if (songId == null || newTarget == null) continue;
        await db
            .into(db.annotations)
            .insert(
              AnnotationsCompanion.insert(
                id: await keep(
                  x['id'] as String?,
                  (id) async =>
                      await (db.select(
                        db.annotations,
                      )..where((a) => a.id.equals(id))).getSingleOrNull() !=
                      null,
                ),
                ownerId: localOwnerId,
                songId: songId,
                target: Value(newTarget),
                stroke: Value(x['stroke'] as String?),
                updatedAt:
                    (x['updatedAt'] as int?) ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
            );
      }
      final arrangements = ArrangementRepository(db);
      for (final a in contents.arrangements) {
        final songId = songMap[a['songId']];
        if (songId == null) continue;
        await arrangements.save(
          localBandId,
          songId,
          transpose: (a['transpose'] as int?) ?? 0,
          sequence: a['sequence'] as String?,
          tempo: a['tempo'] as int?,
        );
      }
      final sets = SetRepository(db, storage, bandId: localBandId);
      for (final s in contents.sets) {
        final setId = await sets.createSet(
          id: await keep(
            s['id'] as String?,
            (id) async =>
                await (db.select(
                  db.setlists,
                )..where((x) => x.id.equals(id))).getSingleOrNull() !=
                null,
          ),
          name: s['name'] as String? ?? '',
          gigDate: DateTime.tryParse(s['gigDate'] as String? ?? ''),
          venue: s['venue'] as String?,
        );
        await _insertItems(
          s,
          setId: setId,
          band: localBandId,
          songMap: songMap,
        );
        setCount++;
      }
    });
    // Files of removed attachments that no restored one uses.
    for (final f in oldFiles.difference(newFiles)) {
      try {
        await storage.delete(f);
      } catch (_) {}
    }
    return BackupImportResult(
      imported: songCount,
      identical: 0,
      additional: const [],
      keptExisting: 0,
      sets: setCount,
      files: fileCount,
    );
  }

  /// Imports the songs of [contents] into [libraryId]: a song that exists
  /// with the same text (or, with [BackupDuplicates.keepExisting], with a
  /// different one) is not imported; the existing one is used. Without
  /// [create] (the person may not create songs, ADR-0023) only existing
  /// songs are used and the others are left out. [attachments]: whether
  /// the attachments of new songs are imported. [completeAttachments]:
  /// whether an existing song that is used gets the archive's attachments
  /// it does not have ([missingAttachments], ADR-0043 §1c); null keeps
  /// existing songs unchanged.
  Future<SongImport> importSongs(
    BackupContents contents, {
    required String libraryId,
    BackupDuplicates duplicates = BackupDuplicates.addAll,
    bool create = true,
    bool attachments = true,
    bool Function(SongEntry song)? completeAttachments,
  }) async {
    final songs = SongRepository(
      db,
      storage,
      libraryId: libraryId,
      userId: userId,
    );
    final existing = await existingSongs(libraryId);
    final result = SongImport();
    // New songs by the language version group they had in the archive
    // (ADR-0053).
    final newByWork = <String, List<String>>{};
    for (final song in contents.songs) {
      final originalId = song['id'] as String;
      final source = contents.sourceOf(song);
      final (match, same) = existing.match(song, source);
      if (match != null &&
          (same || duplicates == BackupDuplicates.keepExisting || !create)) {
        result.songIds[originalId] = match.id;
        same ? result.identical++ : result.keptExisting++;
        if (attachments && (completeAttachments?.call(match) ?? false)) {
          for (final a in await missingAttachments(contents, song, match.id)) {
            final id = await _addAttachment(songs, match.id, contents, a);
            if (id == null) continue;
            result.attachmentIds[a['id'] as String] = id;
            result.files++;
            result.completed++;
          }
        }
        continue;
      }
      if (!create) continue;
      final id = await songs.createSong(
        source: source,
        title: song['title'] as String?,
        artist: song['artist'] as String?,
      );
      result.songIds[originalId] = id;
      result.imported.add(originalId);
      if (song['language'] case final String language
          when songLanguages.contains(language)) {
        await songs.setLanguage(id, language);
      }
      if (song['workId'] case final String work when work.isNotEmpty) {
        (newByWork[work] ??= []).add(id);
      }
      await BackupService.restoreReview(songs, id, song);
      if (match != null) {
        result.additional.add((
          id: id,
          title: (song['title'] as String?) ?? '',
        ));
      }
      if (!attachments) continue;
      for (final a in attachmentsOf(song)) {
        final added = await _addAttachment(songs, id, contents, a);
        if (added == null) continue;
        result.attachmentIds[a['id'] as String] = added;
        result.files++;
      }
    }
    // The new songs that were language versions of each other in the
    // archive are linked again under a new group; never with songs that were
    // already in the library, also not with an identical one that was reused
    // (ADR-0053).
    for (final ids in newByWork.values) {
      if (ids.length < 2) continue;
      final work = _uuid.v4();
      for (final id in ids) {
        await songs.setWorkId(id, work);
      }
    }
    return result;
  }

  /// The attachments of a song of an archive.
  static List<Map<String, dynamic>> attachmentsOf(Map<String, dynamic> song) =>
      [
        for (final e in (song['attachments'] as List?) ?? const [])
          (e as Map).cast<String, dynamic>(),
      ];

  /// The attachments of the archive's [song] that the existing song
  /// [songId] does not have: none of its attachments has the same name
  /// (ignoring case and surrounding spaces) (ADR-0043 §1c).
  Future<List<Map<String, dynamic>>> missingAttachments(
    BackupContents contents,
    Map<String, dynamic> song,
    String songId,
  ) async {
    final archived = attachmentsOf(song);
    if (archived.isEmpty) return const [];
    String key(String? name) => (name ?? '').trim().toLowerCase();
    final present = {
      for (final a in await (db.select(
        db.attachments,
      )..where((a) => a.songId.equals(songId) & a.deleted.equals(false))).get())
        key(a.name),
    };
    return [
      for (final a in archived)
        if (contents.files.containsKey(a['file']) &&
            present.add(key(a['name'] as String?)))
          a,
    ];
  }

  /// Adds the attachment [a] of [contents] to [songId]; null if its file is
  /// missing or too large.
  Future<String?> _addAttachment(
    SongRepository songs,
    String songId,
    BackupContents contents,
    Map<String, dynamic> a,
  ) async {
    final bytes = contents.files[a['file'] as String? ?? ''];
    if (bytes == null || bytes.length > maxAttachmentBytes) return null;
    final ext = p
        .extension(a['file'] as String)
        .replaceFirst('.', '')
        .toLowerCase();
    return songs.addAttachment(
      songId,
      name: a['name'] as String? ?? '',
      bytes: bytes,
      pages: a['pages'] as int?,
      extension: ext.isEmpty ? 'pdf' : ext,
    );
  }

  /// Imports the person's adjustments and annotations of [contents] for the
  /// songs [songs] imported as new songs: existing songs keep the person's
  /// current ones.
  Future<void> importPersonal(
    BackupContents contents, {
    required String libraryId,
    required SongImport songs,
  }) async {
    final repo = SongRepository(
      db,
      storage,
      libraryId: libraryId,
      userId: userId,
    );
    for (final o in contents.overlays) {
      final original = o['songId'] as String?;
      if (!songs.imported.contains(original)) continue;
      final songId = songs.songIds[original]!;
      final current = await repo.getOverlay(songId);
      final liveView = o['liveView'] as String?;
      await repo.saveOverlay(
        _overlayFrom(
          current,
          o,
          liveView == null ? null : songs.attachmentIds[liveView],
        ),
      );
    }
    final owner = overlayOwnerFor(libraryId, userId);
    await db.transaction(() async {
      for (final x in contents.annotations) {
        final original = x['songId'] as String?;
        if (!songs.imported.contains(original)) continue;
        final target = x['target'] as String? ?? '';
        final newTarget = target.isEmpty ? '' : songs.attachmentIds[target];
        if (newTarget == null) continue;
        await db
            .into(db.annotations)
            .insert(
              AnnotationsCompanion.insert(
                id: _uuid.v4(),
                ownerId: owner,
                songId: songs.songIds[original]!,
                target: Value(newTarget),
                stroke: Value(x['stroke'] as String?),
                updatedAt:
                    (x['updatedAt'] as int?) ??
                    DateTime.now().millisecondsSinceEpoch,
                // Synced as strokes that never reached the server.
                pending: const Value(1),
              ),
            );
      }
    });
  }
}

/// What [BackupService.importSongs] did.
class SongImport {
  /// Original song ID -> song in the target library.
  final songIds = <String, String>{};

  /// Original attachment ID -> new attachment ID.
  final attachmentIds = <String, String>{};

  /// Original song IDs imported as new songs.
  final imported = <String>{};

  /// New songs next to an existing song with a different text.
  final additional = <({String id, String title})>[];

  int identical = 0;
  int keptExisting = 0;

  /// Attachment files added, to new and to existing songs.
  int files = 0;

  /// Of [files]: attachments added to existing songs (ADR-0043 §1c).
  int completed = 0;
}

/// Songs of the target library, to find an archive's songs in it.
class ExistingSongs {
  ExistingSongs(List<SongEntry> songs)
    : _byId = {for (final s in songs) s.id: s},
      _byName = {for (final s in songs) _key(s.title, s.artist): s};

  final Map<String, SongEntry> _byId;
  final Map<String, SongEntry> _byName;

  static String _key(String? title, String? artist) =>
      '${(title ?? '').trim().toLowerCase()}\n'
      '${(artist ?? '').trim().toLowerCase()}';

  /// The existing song for an archive song (same ID, else same title and
  /// artist) and whether its ChordPro text is the same.
  (SongEntry?, bool) match(Map<String, dynamic> song, String source) {
    final found =
        _byId[song['id']] ??
        _byName[_key(song['title'] as String?, song['artist'] as String?)];
    if (found == null) return (null, false);
    // A set archive adds title and artist directives that are missing.
    return (
      found,
      found.chordproSource == source ||
          sourceWithMeta(found.chordproSource, found.title, found.artist) ==
              source,
    );
  }
}

Uint8List _zip(Map<String, Uint8List> files) {
  final archive = Archive();
  for (final MapEntry(key: name, value: bytes) in files.entries) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Zips [files] (path -> bytes) outside the UI isolate.
Future<Uint8List> zipArchive(Map<String, Uint8List> files) =>
    compute(_zip, files);

/// The files of a ZIP archive by their path, outside the UI isolate.
Future<Map<String, Uint8List>> unzipArchive(Uint8List zip) =>
    compute(_unzipPaths, zip);

/// The files of a ZIP archive by their path (with folders), without macOS
/// metadata.
Map<String, Uint8List> _unzipPaths(Uint8List zip) => {
  for (final entry in ZipDecoder().decodeBytes(zip).files)
    if (entry.isFile && !entry.name.contains('__MACOSX'))
      entry.name.replaceAll(r'\', '/'): Uint8List.fromList(entry.content),
};
