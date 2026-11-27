import 'package:drift/drift.dart';

import 'database.dart';

/// Server collections of synced records (ADR-0015, ADR-0017).
abstract final class SyncCollection {
  static const songs = 'songs';

  /// A link field of a song (ADR-0053), pushed on its own, last writer wins
  /// per field; the outbox record ID is [songLinkRecordId]. Never a server
  /// collection of its own.
  static const songLinks = 'song_links';

  /// The review status of a song (ADR-0060), pushed on its own, last writer
  /// wins; the outbox record ID is the song ID. Never a server collection
  /// of its own.
  static const songReview = 'song_review';

  /// Mistake reports (ADR-0060); the outbox record ID is the report ID.
  static const songReports = 'song_reports';

  /// Which mistake reports of an organization the last pull could read
  /// (ADR-0060): no outbox, only a cursor per organization holding 1 for
  /// the user's own reports and 2 for all. When it changes with the user's
  /// roles, the reports are pulled again from the start (#1194).
  static const songReportsScope = 'song_reports_scope';

  /// People without an account (ADR-0064); the outbox record ID is the
  /// contact ID.
  static const contacts = 'contacts';
  static const setlists = 'setlists';
  static const attachments = 'attachments';

  /// Personal adjustments (ADR-0020); the outbox record ID is
  /// [overlayRecordId].
  static const overlays = 'overlays';

  /// Band arrangements (ADR-0025); the outbox record ID is
  /// [arrangementRecordId].
  static const arrangements = 'arrangements';

  /// Personal settings (ADR-0027); the outbox record ID is the user ID.
  static const userSettings = 'user_settings';

  /// Freehand annotations (ADR-0032); the outbox record ID is
  /// [annotationRecordId].
  static const annotations = 'annotations';

  /// Plays across the bands of an organization (ADR-0046): no outbox, only
  /// a cursor per organization holding when they were fetched (seconds
  /// since the epoch).
  static const orgPlays = 'org_plays';
}

/// Outbox record ID of the annotations of [ownerId] on [songId]: its
/// ChordPro text ([target] empty) or a PDF attachment.
String annotationRecordId(String ownerId, String songId, String target) =>
    '$ownerId:$songId:$target';

/// Owner, song and target of an [annotationRecordId].
(String, String, String) parseAnnotationRecordId(String id) {
  final parts = id.split(':');
  return (parts[0], parts[1], parts.length > 2 ? parts[2] : '');
}

/// Languages a song can be marked with (ADR-0053): German, Swiss German,
/// English, French, Italian, Spanish, Portuguese, Dutch and other.
const songLanguages = [
  'de',
  'gsw',
  'en',
  'fr',
  'it',
  'es',
  'pt',
  'nl',
  'other',
];

/// A link field of a song (ADR-0053), synced last writer wins per field.
enum SongLinkField {
  workId('work_id'),
  language('language');

  const SongLinkField(this.serverName);

  /// Name of the field on the server.
  final String serverName;
}

/// Outbox record ID of the link field [field] (its server name, e.g.
/// `work_id`) of [songId] (ADR-0053).
String songLinkRecordId(String songId, String field) => '$songId:$field';

/// Song and field of a [songLinkRecordId].
(String, String) parseSongLinkRecordId(String id) {
  final i = id.indexOf(':');
  return (id.substring(0, i), id.substring(i + 1));
}

/// Outbox record ID of the arrangement of [bandId] for [songId].
String arrangementRecordId(String bandId, String songId) => '$bandId:$songId';

/// Band and song of an [arrangementRecordId].
(String, String) parseArrangementRecordId(String id) {
  final i = id.indexOf(':');
  return (id.substring(0, i), id.substring(i + 1));
}

/// Outbox record ID of the personal adjustments of [ownerId] for [songId].
String overlayRecordId(String ownerId, String songId) => '$ownerId:$songId';

/// Owner and song of an [overlayRecordId].
(String, String) parseOverlayRecordId(String id) {
  final i = id.indexOf(':');
  return (id.substring(0, i), id.substring(i + 1));
}

/// Records a local change for the sync (ADR-0004). Changes in the local
/// library ([localBandId]) are never synced.
Future<void> markDirty(
  AppDatabase db,
  String collection,
  String recordId, {
  required String scope,
}) async {
  if (scope == localBandId) return;
  await db.customStatement(
    'INSERT INTO sync_outbox (collection, record_id, version) VALUES (?, ?, 1) '
    'ON CONFLICT (collection, record_id) DO UPDATE SET version = version + 1',
    [collection, recordId],
  );
  db.notifyUpdates({
    TableUpdate.onTable(db.syncOutbox, kind: UpdateKind.insert),
  });
}
