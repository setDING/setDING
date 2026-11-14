import 'package:chordpro/chordpro.dart' as cp;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'attachment_storage.dart';
import 'database.dart';

const _uuid = Uuid();

/// Metadata extracted from a ChordPro source (ADR-0003).
class SongMeta {
  const SongMeta({this.title, this.artist, this.key, this.tempo});

  factory SongMeta.fromSource(String source) {
    final song = cp.parseChordPro(source);
    return SongMeta(
      title: _blankToNull(song.title),
      artist: _blankToNull(song.artist),
      key: _blankToNull(song.keyName),
      tempo: song.tempo,
    );
  }

  final String? title;
  final String? artist;
  final String? key;
  final int? tempo;
}

String? _blankToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Access to songs, attachments and personal overlays.
class SongRepository {
  SongRepository(this.db, this.storage);

  final AppDatabase db;
  final AttachmentStorage storage;

  Stream<List<SongEntry>> watchSongs({String query = ''}) {
    final q = db.select(db.songs)
      ..where((s) => s.deleted.equals(false))
      ..orderBy([(s) => OrderingTerm.asc(s.title.collate(Collate.noCase))]);
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
    await db
        .into(db.songs)
        .insert(
          SongsCompanion.insert(
            id: id,
            bandId: localBandId,
            chordproSource: Value(source),
            title: meta.title ?? _blankToNull(title) ?? '',
            artist: Value(meta.artist ?? _blankToNull(artist)),
            songKey: Value(meta.key),
            tempo: Value(meta.tempo),
            updatedAt: DateTime.now(),
          ),
        );
    return id;
  }

  /// Saves a new ChordPro source and refreshes the extracted metadata.
  Future<void> updateSource(String id, String source) async {
    final existing = await getSong(id);
    if (existing == null) return;
    final meta = SongMeta.fromSource(source);
    await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
      SongsCompanion(
        chordproSource: Value(source),
        title: Value(meta.title ?? existing.title),
        artist: Value(meta.artist ?? existing.artist),
        songKey: Value(meta.key),
        tempo: Value(meta.tempo),
        revision: Value(existing.revision + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Updates title and artist of a song without ChordPro metadata.
  Future<void> updateTitleArtist(
    String id,
    String title,
    String? artist,
  ) async {
    final existing = await getSong(id);
    if (existing == null) return;
    await (db.update(db.songs)..where((s) => s.id.equals(id))).write(
      SongsCompanion(
        title: Value(title.trim()),
        artist: Value(_blankToNull(artist)),
        revision: Value(existing.revision + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-deletes a song, removes it from all sets and deletes its files.
  Future<void> deleteSong(String id) async {
    final files = await (db.select(
      db.attachments,
    )..where((a) => a.songId.equals(id) & a.deleted.equals(false))).get();
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

  /// Adds a PDF attachment. Throws [AttachmentTooLargeException] above 20 MB.
  Future<String> addAttachment(
    String songId, {
    required String name,
    required Uint8List bytes,
    int? pages,
  }) async {
    if (bytes.length > maxAttachmentBytes) {
      throw AttachmentTooLargeException(bytes.length);
    }
    final id = _uuid.v4();
    final fileName = '$id.pdf';
    await storage.write(fileName, bytes);
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
    return id;
  }

  Future<void> renameAttachment(String id, String name) =>
      (db.update(db.attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteAttachment(AttachmentEntry attachment) async {
    await (db.update(db.attachments)..where((a) => a.id.equals(attachment.id)))
        .write(const AttachmentsCompanion(deleted: Value(true)));
    await (db.update(db.personalOverlays)
          ..where((o) => o.liveView.equals(attachment.id)))
        .write(const PersonalOverlaysCompanion(liveView: Value(null)));
    await storage.delete(attachment.fileName);
  }

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
