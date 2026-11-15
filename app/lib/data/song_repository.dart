import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';

const _uuid = Uuid();

/// Metadata extracted from a ChordPro source (ADR-0003).
class SongMeta {
  const SongMeta({
    this.title,
    this.artist,
    this.key,
    this.tempo,
    this.sortTitle,
    this.sortArtist,
    this.tags = const [],
  });

  factory SongMeta.fromSource(String source) {
    final song = cp.parseChordPro(source);
    return SongMeta(
      title: _blankToNull(song.title),
      artist: _blankToNull(song.artist),
      key: _blankToNull(song.keyName),
      tempo: song.tempo,
      sortTitle: _blankToNull(song.sortTitle),
      sortArtist: _blankToNull(song.sortArtist),
      tags: [
        for (final t in song.tags)
          if (t.trim().isNotEmpty) t.trim(),
      ],
    );
  }

  final String? title;
  final String? artist;
  final String? key;
  final int? tempo;
  final String? sortTitle;
  final String? sortArtist;
  final List<String> tags;

  /// Tags as stored in the database (see `Songs.tags`).
  String? get tagsColumn => tags.isEmpty ? null : '\n${tags.join('\n')}\n';
}

/// Metadata of ChordPro [sources]; larger batches (e.g. the first sync of a
/// library) are parsed outside the UI isolate.
Future<List<SongMeta>> songMetas(List<String> sources) => sources.length < 20
    ? Future.value(_metas(sources))
    : compute(_metas, sources);

List<SongMeta> _metas(List<String> sources) => [
  for (final s in sources) SongMeta.fromSource(s),
];

/// Tags of a song as stored in the database.
List<String> songTags(SongEntry song) => [
  for (final t in (song.tags ?? '').split('\n'))
    if (t.isNotEmpty) t,
];

String? _blankToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Access to songs, attachments and personal overlays of one song library:
/// the organization of the current band (ADR-0017), or the local library
/// by default.
class SongRepository {
  SongRepository(this.db, this.storage, {this.libraryId = localBandId});

  final AppDatabase db;
  final AttachmentStorage storage;

  /// Library whose songs are listed and to which new songs belong.
  final String libraryId;

  /// Songs sorted by `{sorttitle}` (or title); optionally filtered by a
  /// search [query] and a [tag].
  Stream<List<SongEntry>> watchSongs({String query = '', String? tag}) {
    final q = db.select(db.songs)
      ..where((s) => s.deleted.equals(false) & s.libraryId.equals(libraryId))
      ..orderBy([
        (s) => OrderingTerm.asc(
          coalesce([s.sortTitle, s.title]).collate(Collate.noCase),
        ),
      ]);
    if (tag != null) {
      q.where((s) => s.tags.lower().like('%\n${tag.toLowerCase()}\n%'));
    }
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final pattern = '%${trimmed.toLowerCase()}%';
      q.where(
        (s) =>
            s.title.lower().like(pattern) |
            s.artist.lower().like(pattern) |
            s.chordproSource.lower().like(pattern),
      );
    }
    return q.watch();
  }

  Stream<SongEntry?> watchSong(String id) =>
      (db.select(db.songs)
            ..where((s) => s.id.equals(id) & s.deleted.equals(false)))
          .watchSingleOrNull();

  Future<SongEntry?> getSong(String id) => (db.select(
    db.songs,
  )..where((s) => s.id.equals(id) & s.deleted.equals(false))).getSingleOrNull();

  /// Creates a song. Title and artist from the source take precedence;
  /// [title]/[artist] are used for songs without ChordPro text (PDF only).
  Future<String> createSong({
    String source = '',
    String? title,
    String? artist,
  }) async {
    final meta = SongMeta.fromSource(source);
    final id = _uuid.v4();
    await _write(() async {
      await db
          .into(db.songs)
          .insert(
            SongsCompanion.insert(
              id: id,
              libraryId: libraryId,
              chordproSource: Value(source),
              title: meta.title ?? _blankToNull(title) ?? '',
              artist: Value(meta.artist ?? _blankToNull(artist)),
              songKey: Value(meta.key),
              tempo: Value(meta.tempo),
              sortTitle: Value(meta.sortTitle),
              sortArtist: Value(meta.sortArtist),
              tags: Value(meta.tagsColumn),
              updatedAt: DateTime.now(),
            ),
          );
      await markDirty(db, SyncCollection.songs, id, scope: libraryId);
    });
    return id;
  }

  /// Saves a new ChordPro source and refreshes the extracted metadata.
  Future<void> updateSource(String id, String source) async {
    final meta = SongMeta.fromSource(source);
    await _write(() async {
      final existing = await getSong(id);
      if (existing == null) return;
      await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(
          chordproSource: Value(source),
          title: Value(meta.title ?? existing.title),
          artist: Value(meta.artist ?? existing.artist),
          songKey: Value(meta.key),
          tempo: Value(meta.tempo),
          sortTitle: Value(meta.sortTitle),
          sortArtist: Value(meta.sortArtist),
          tags: Value(meta.tagsColumn),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await markDirty(db, SyncCollection.songs, id, scope: existing.libraryId);
    });
  }

  /// All tags used in the library, sorted.
  Stream<List<String>> watchTags() =>
      (db.selectOnly(db.songs)
            ..addColumns([db.songs.tags])
            ..where(
              db.songs.deleted.equals(false) &
                  db.songs.libraryId.equals(libraryId) &
                  db.songs.tags.isNotNull(),
            ))
          .watch()
          .map((rows) {
            // Tags are matched case-insensitively; show one spelling per
            // tag (the first in sort order, e.g. "Rock" before "rock").
            final byKey = <String, String>{};
            for (final r in rows) {
              for (final t in (r.read(db.songs.tags) ?? '').split('\n')) {
                if (t.isEmpty) continue;
                final key = t.toLowerCase();
                final known = byKey[key];
                if (known == null || t.compareTo(known) < 0) byKey[key] = t;
              }
            }
            return byKey.values.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          });

  /// Recomputes the stored metadata of all songs from their ChordPro
  /// source (used after a database upgrade).
  Future<void> refreshAllMetadata() async {
    final all = [
      for (final song in await db.select(db.songs).get())
        if (song.chordproSource.trim().isNotEmpty) song,
    ];
    final metas = await songMetas([for (final s in all) s.chordproSource]);
    await db.transaction(() async {
      for (final (i, song) in all.indexed) {
        final meta = metas[i];
        await (db.update(db.songs)..where((s) => s.id.equals(song.id))).write(
          SongsCompanion(
            sortTitle: Value(meta.sortTitle),
            sortArtist: Value(meta.sortArtist),
            tags: Value(meta.tagsColumn),
          ),
        );
      }
    });
  }

  /// Updates title and artist of a song without ChordPro metadata.
  Future<void> updateTitleArtist(String id, String title, String? artist) =>
      _write(() async {
        final existing = await getSong(id);
        if (existing == null) return;
        await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
          SongsCompanion(
            title: Value(title.trim()),
            artist: Value(_blankToNull(artist)),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await markDirty(
          db,
          SyncCollection.songs,
          id,
          scope: existing.libraryId,
        );
      });

  /// Soft-deletes a song, removes it from all sets and deletes its files.
  Future<void> deleteSong(String id) async {
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    final files = await (db.select(
      db.attachments,
    )..where((a) => a.songId.equals(id) & a.deleted.equals(false))).get();
    // Sets that lose the song are changed, too.
    final sets =
        await (db.select(db.setlists).join([
              innerJoin(
                db.setItems,
                db.setItems.setId.equalsExp(db.setlists.id),
              ),
            ])..where(db.setItems.songId.equals(id)))
            .map((r) => r.readTable(db.setlists))
            .get();
    await db.transaction(() async {
      await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
        SongsCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (db.update(db.attachments)..where((a) => a.songId.equals(id)))
          .write(const AttachmentsCompanion(deleted: Value(true)));
      await (db.delete(db.setItems)..where((i) => i.songId.equals(id))).go();
      if (song != null) {
        await markDirty(db, SyncCollection.songs, id, scope: song.libraryId);
      }
      for (final set in sets) {
        await markDirty(db, SyncCollection.setlists, set.id, scope: set.bandId);
      }
    });
    for (final f in files) {
      await storage.delete(f.fileName);
    }
  }

  // Attachments -------------------------------------------------------------

  Stream<List<AttachmentEntry>> watchAttachments(String songId) =>
      (db.select(db.attachments)
            ..where((a) => a.songId.equals(songId) & a.deleted.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Future<List<AttachmentEntry>> getAttachments(String songId) =>
      (db.select(db.attachments)
            ..where((a) => a.songId.equals(songId) & a.deleted.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  /// Number of attachments per song ID.
  Stream<Map<String, int>> watchAttachmentCounts() {
    final count = db.attachments.id.count();
    final q = db.selectOnly(db.attachments)
      ..addColumns([db.attachments.songId, count])
      ..where(db.attachments.deleted.equals(false))
      ..groupBy([db.attachments.songId]);
    return q.watch().map(
      (rows) => {
        for (final r in rows) r.read(db.attachments.songId)!: r.read(count)!,
      },
    );
  }

  /// Adds a PDF or image attachment ([extension] without dot). Throws
  /// [AttachmentTooLargeException] above 20 MB.
  Future<String> addAttachment(
    String songId, {
    required String name,
    required Uint8List bytes,
    int? pages,
    String extension = 'pdf',
  }) async {
    if (bytes.length > maxAttachmentBytes) {
      throw AttachmentTooLargeException(bytes.length);
    }
    final id = _uuid.v4();
    final ext = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final fileName = '$id.${ext.isEmpty ? 'bin' : ext}';
    await storage.write(fileName, bytes);
    try {
      await _write(() async {
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: id,
                songId: songId,
                name: name,
                fileName: fileName,
                pages: Value(pages),
                sizeBytes: bytes.length,
                updatedAt: DateTime.now(),
              ),
            );
        await _markAttachment(id, songId, fileName);
      });
    } catch (_) {
      // Not stored: the file would be an orphan.
      await storage.delete(fileName);
      rethrow;
    }
    return id;
  }

  /// Only PDF attachments are synced (ADR-0009); images stay on the device.
  Future<void> _markAttachment(
    String id,
    String songId,
    String fileName,
  ) async {
    if (!isPdfFile(fileName)) return;
    final song = await (db.select(
      db.songs,
    )..where((s) => s.id.equals(songId))).getSingleOrNull();
    if (song == null) return;
    await markDirty(db, SyncCollection.attachments, id, scope: song.libraryId);
  }

  Future<void> renameAttachment(String id, String name) => _write(() async {
    await (db.update(db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
    final a = await (db.select(
      db.attachments,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (a != null) await _markAttachment(a.id, a.songId, a.fileName);
  });

  Future<void> deleteAttachment(AttachmentEntry attachment) async {
    await _write(() async {
      await (db.update(db.attachments)
            ..where((a) => a.id.equals(attachment.id)))
          .write(const AttachmentsCompanion(deleted: Value(true)));
      await _markAttachment(
        attachment.id,
        attachment.songId,
        attachment.fileName,
      );
      await (db.update(db.personalOverlays)
            ..where((o) => o.liveView.equals(attachment.id)))
          .write(const PersonalOverlaysCompanion(liveView: Value(null)));
    });
    await storage.delete(attachment.fileName);
  }

  /// Runs a change together with its outbox entries ([markDirty]) in one
  /// transaction, so that no change is stored without being synced.
  Future<T> _write<T>(Future<T> Function() change) => db.transaction(change);

  // Personal overlays --------------------------------------------------------

  Stream<SongOverlay> watchOverlay(String songId) =>
      (db.select(db.personalOverlays)..where((o) => o.songId.equals(songId)))
          .watchSingleOrNull()
          .map((o) => o ?? defaultOverlay(songId));

  Future<SongOverlay> getOverlay(String songId) async =>
      await (db.select(
        db.personalOverlays,
      )..where((o) => o.songId.equals(songId))).getSingleOrNull() ??
      defaultOverlay(songId);

  static SongOverlay defaultOverlay(String songId) =>
      SongOverlay(songId: songId, transpose: 0, capo: 0, fontScale: 1.0);

  /// Saves all fields, including null values (e.g. resetting Nashville to
  /// the device setting or removing a note).
  Future<void> saveOverlay(SongOverlay overlay) => db
      .into(db.personalOverlays)
      .insertOnConflictUpdate(overlay.toCompanion(false));
}
