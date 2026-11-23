import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../sync/sync_backend.dart' show SyncBackend;
import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';

/// Review state of a song that waits for a check (ADR-0060); an approved
/// song has none.
const songToReview = 'to_review';

/// Maximum length of the reason why a song waits for a check (server limit).
const maxReviewReasonLength = 200;

/// Maximum length of the comment and the answer of a report (server limit).
const maxReportTextLength = 1000;

/// Maximum size of a report's screenshot (server limit, ADR-0060).
const maxScreenshotBytes = 1024 * 1024;

/// What a mistake report is about (ADR-0060).
enum SongReportCategory {
  chords('chords'),
  lyrics('lyrics'),
  key('key'),
  sequence('sequence'),
  tempo('tempo'),
  formatting('formatting'),
  sheetMusic('sheet_music'),
  other('other');

  const SongReportCategory(this.serverName);

  /// The value stored locally and on the server.
  final String serverName;

  static SongReportCategory parse(String value) => values.firstWhere(
    (c) => c.serverName == value,
    orElse: () => SongReportCategory.other,
  );
}

/// Where a mistake report stands (ADR-0060).
enum SongReportStatus {
  open,
  resolved,
  withdrawn;

  static SongReportStatus parse(String value) => values.firstWhere(
    (s) => s.name == value,
    orElse: () => SongReportStatus.open,
  );
}

/// Where in a song a mistake was reported (ADR-0060), filled from where the
/// person was: a section (by its label and occurrence), the source line,
/// the live page, or a page of a PDF attachment.
class SongReportLocation {
  const SongReportLocation({
    this.section,
    this.occurrence,
    this.line,
    this.page,
    this.attachmentId,
    this.attachmentPage,
  });

  final String? section;

  /// Which occurrence of [section] (1 = first), if it repeats.
  final int? occurrence;

  /// Line of the ChordPro source (0-based).
  final int? line;

  /// Page in live mode (1-based).
  final int? page;

  /// The PDF attachment shown, and its page (1-based).
  final String? attachmentId;
  final int? attachmentPage;

  bool get isEmpty =>
      section == null &&
      line == null &&
      page == null &&
      attachmentId == null &&
      attachmentPage == null;

  Map<String, dynamic> toJson() => {
    'section': ?section,
    'occurrence': ?occurrence,
    'line': ?line,
    'page': ?page,
    'attachment': ?attachmentId,
    'attachmentPage': ?attachmentPage,
  };

  static SongReportLocation? fromJson(Object? json) {
    if (json is! Map) return null;
    int? number(Object? v) => v is num ? v.toInt() : null;
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    final location = SongReportLocation(
      section: text(json['section']),
      occurrence: number(json['occurrence']),
      line: number(json['line']),
      page: number(json['page']),
      attachmentId: text(json['attachment']),
      attachmentPage: number(json['attachmentPage']),
    );
    return location.isEmpty ? null : location;
  }

  /// Parses the JSON stored in [SongReportRow.location].
  static SongReportLocation? decode(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    try {
      return fromJson(jsonDecode(stored));
    } on FormatException {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Accessors of a stored report.
extension SongReportRowX on SongReportRow {
  SongReportCategory get categoryValue => SongReportCategory.parse(category);
  SongReportStatus get statusValue => SongReportStatus.parse(status);
  SongReportLocation? get locationValue => SongReportLocation.decode(location);
  bool get isOpen => statusValue == SongReportStatus.open;
}

/// Counts for the *To do* of people who may approve (ADR-0060).
typedef ReviewCounts = ({int toReview, int reported});

/// Review status of songs and their mistake reports (ADR-0060).
///
/// The review status is stored on the song and synced on its own (outbox
/// collection [SyncCollection.songReview], last writer wins); reports are
/// rows of [SongReports] synced per organization. Changes in the local
/// library stay on the device. Permissions are checked by the server; the
/// callers only offer what the person may do.
class SongReviewRepository {
  SongReviewRepository(this.db, this.storage, {this.userId, this.backend});

  final AppDatabase db;

  /// Where screenshots are stored (with the attachment files).
  final AttachmentStorage storage;

  /// The signed-in user, or null.
  final String? userId;

  /// Downloads screenshots that are not on this device yet; without it,
  /// only local screenshots are shown.
  final SyncBackend? backend;

  /// The person acting in [libraryId]: the signed-in user, or the local
  /// owner in the local library and without an account.
  String _actor(String libraryId) =>
      libraryId == localBandId || userId == null ? localOwnerId : userId!;

  Future<SongEntry?> _song(String songId) => (db.select(
    db.songs,
  )..where((s) => s.id.equals(songId))).getSingleOrNull();

  // Review status ----------------------------------------------------------------

  /// Sets [songId] to wait for a check, with [reason].
  Future<void> setToReview(String songId, {String? reason}) =>
      _setReview(songId, songToReview, _reason(reason));

  /// Approves [songId]; with [resolveReports], its open reports are
  /// resolved in the same step, with [resolution] as the answer.
  Future<void> approve(
    String songId, {
    bool resolveReports = false,
    String? resolution,
  }) => db.transaction(() async {
    await _setReview(songId, null, null);
    if (!resolveReports) return;
    for (final r in await openReports(songId)) {
      await resolve(r.id, resolution: resolution);
    }
  });

  /// Approves all of [songIds]; returns their review state before, for an
  /// undo with [restoreReview].
  Future<Map<String, (String?, String?)>> approveAll(List<String> songIds) =>
      db.transaction(() async {
        final before = <String, (String?, String?)>{};
        for (final id in songIds) {
          final song = await _song(id);
          if (song == null || song.reviewState == null) continue;
          before[id] = (song.reviewState, song.reviewReason);
          await _setReview(id, null, null);
        }
        return before;
      });

  /// Sets the review states of [before] again (undo of [approveAll]).
  Future<void> restoreReview(Map<String, (String?, String?)> before) =>
      db.transaction(() async {
        for (final MapEntry(key: id, value: (state, reason))
            in before.entries) {
          await _setReview(id, state, reason);
        }
      });

  String? _reason(String? reason) {
    final text = reason?.trim() ?? '';
    if (text.isEmpty) return null;
    return text.length > maxReviewReasonLength
        ? text.substring(0, maxReviewReasonLength)
        : text;
  }

  Future<void> _setReview(String songId, String? state, String? reason) async {
    final song = await _song(songId);
    if (song == null) return;
    await (db.update(db.songs)..where((s) => s.id.equals(songId))).write(
      SongsCompanion(
        reviewState: Value(state),
        reviewReason: Value(state == null ? null : reason),
        reviewedBy: Value(_actor(song.libraryId)),
        reviewedAt: Value(DateTime.now()),
      ),
    );
    await markDirty(
      db,
      SyncCollection.songReview,
      songId,
      scope: song.libraryId,
    );
  }

  /// Number of songs of [libraryId] that wait for a check, and of songs
  /// with open reports (not deleted).
  Stream<ReviewCounts> watchCounts(String libraryId) {
    final query = db.customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM songs WHERE library_id = ?1 AND deleted = 0 '
      "AND review_state IS NOT NULL) AS to_review, "
      '(SELECT COUNT(DISTINCT r.song_id) FROM song_reports r '
      'JOIN songs s ON s.id = r.song_id WHERE s.library_id = ?1 '
      "AND s.deleted = 0 AND r.deleted = 0 AND r.status = 'open') "
      'AS reported',
      variables: [Variable.withString(libraryId)],
      readsFrom: {db.songs, db.songReports},
    );
    return query.watchSingle().map(
      (r) => (
        toReview: r.read<int>('to_review'),
        reported: r.read<int>('reported'),
      ),
    );
  }

  /// IDs of the songs of [libraryId] with open reports.
  Stream<Set<String>> watchReportedSongs(String libraryId) {
    final query = db.customSelect(
      'SELECT DISTINCT r.song_id AS id FROM song_reports r '
      'JOIN songs s ON s.id = r.song_id WHERE s.library_id = ? '
      "AND s.deleted = 0 AND r.deleted = 0 AND r.status = 'open'",
      variables: [Variable.withString(libraryId)],
      readsFrom: {db.songs, db.songReports},
    );
    return query.watch().map((rows) => {for (final r in rows) r.read('id')});
  }

  // Reports ----------------------------------------------------------------------

  /// Reports a mistake in [songId]; returns the new report's ID.
  /// [screenshot] is stored with the extension [screenshotExtension]
  /// (`webp`, `jpg` or `png`).
  Future<String> report(
    String songId, {
    required SongReportCategory category,
    String comment = '',
    SongReportLocation? location,
    Uint8List? screenshot,
    String screenshotExtension = 'webp',
  }) async {
    final song = await _song(songId);
    if (song == null) throw StateError('Unknown song $songId');
    if (screenshot != null && screenshot.length > maxScreenshotBytes) {
      throw ArgumentError.value(screenshot.length, 'screenshot', 'too large');
    }
    final id = const Uuid().v4();
    String? file;
    if (screenshot != null) {
      file = 'report-$id.$screenshotExtension';
      await storage.write(file, screenshot);
    }
    await db.transaction(() async {
      await db
          .into(db.songReports)
          .insert(
            SongReportsCompanion.insert(
              id: id,
              songId: songId,
              libraryId: song.libraryId,
              authorId: Value(_actor(song.libraryId)),
              category: category.serverName,
              comment: Value(_text(comment) ?? ''),
              location: Value(
                location == null || location.isEmpty ? null : location.encode(),
              ),
              screenshotFile: Value(file),
              createdAt: DateTime.now(),
            ),
          );
      await markDirty(
        db,
        SyncCollection.songReports,
        id,
        scope: song.libraryId,
      );
    });
    return id;
  }

  String? _text(String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.length > maxReportTextLength
        ? t.substring(0, maxReportTextLength)
        : t;
  }

  Future<SongReportRow?> reportById(String id) => (db.select(
    db.songReports,
  )..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<void> _update(String id, SongReportsCompanion change) =>
      db.transaction(() async {
        final report = await reportById(id);
        if (report == null) return;
        await (db.update(
          db.songReports,
        )..where((r) => r.id.equals(id))).write(change);
        await markDirty(
          db,
          SyncCollection.songReports,
          id,
          scope: report.libraryId,
        );
      });

  /// Changes the author's part of an open report.
  Future<void> updateReport(
    String id, {
    SongReportCategory? category,
    String? comment,
  }) => _update(
    id,
    SongReportsCompanion(
      category: category == null
          ? const Value.absent()
          : Value(category.serverName),
      comment: comment == null
          ? const Value.absent()
          : Value(_text(comment) ?? ''),
    ),
  );

  /// The author withdraws an open report.
  Future<void> withdraw(String id) => _update(
    id,
    SongReportsCompanion(status: Value(SongReportStatus.withdrawn.name)),
  );

  /// Resolves a report with [resolution] as the answer to the reporter.
  Future<void> resolve(String id, {String? resolution}) async {
    final report = await reportById(id);
    if (report == null) return;
    await _update(
      id,
      SongReportsCompanion(
        status: Value(SongReportStatus.resolved.name),
        resolution: Value(_text(resolution)),
        resolvedBy: Value(_actor(report.libraryId)),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Opens a resolved report again.
  Future<void> reopen(String id) => _update(
    id,
    SongReportsCompanion(
      status: Value(SongReportStatus.open.name),
      resolvedBy: const Value(null),
      resolvedAt: const Value(null),
    ),
  );

  /// Reports of [songId] that are not deleted, newest first.
  Stream<List<SongReportRow>> watchReports(String songId) =>
      (db.select(db.songReports)
            ..where((r) => r.songId.equals(songId) & r.deleted.equals(false))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .watch();

  /// Open reports of [songId].
  Future<List<SongReportRow>> openReports(String songId) =>
      (db.select(db.songReports)..where(
            (r) =>
                r.songId.equals(songId) &
                r.deleted.equals(false) &
                r.status.equals(SongReportStatus.open.name),
          ))
          .get();

  /// The screenshot of [report], downloaded once if it is not on this
  /// device yet; null without one, or when it cannot be loaded (offline).
  Future<Uint8List?> screenshot(SongReportRow report) async {
    final local = report.screenshotFile;
    if (local != null && await storage.exists(local)) {
      return storage.file(local).readAsBytes();
    }
    final remote = report.remoteScreenshot;
    final backend = this.backend;
    if (remote == null || backend == null) return null;
    try {
      final bytes = await backend.fetchReportScreenshot(report.id, remote);
      final ext = remote.contains('.') ? remote.split('.').last : 'webp';
      final file = 'report-${report.id}.$ext';
      await storage.write(file, bytes);
      await (db.update(db.songReports)..where((r) => r.id.equals(report.id)))
          .write(SongReportsCompanion(screenshotFile: Value(file)));
      return bytes;
    } on Exception {
      return null;
    }
  }
}

/// Whether [fileName] in the attachment storage is the screenshot of a
/// report.
bool isReportScreenshot(String fileName) => fileName.startsWith('report-');

/// Removes the reports of [songIds] for good (songs removed from this
/// device); returns their screenshot files to delete after the transaction.
Future<List<String>> removeReportsOf(
  AppDatabase db,
  List<String> songIds,
) async {
  if (songIds.isEmpty) return const [];
  final rows = await (db.select(
    db.songReports,
  )..where((r) => r.songId.isIn(songIds))).get();
  await (db.delete(db.songReports)..where((r) => r.songId.isIn(songIds))).go();
  return [for (final r in rows) ?r.screenshotFile];
}
