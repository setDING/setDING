import 'package:drift/drift.dart';

import 'database.dart';

/// Server collections of synced records (ADR-0015, ADR-0017).
abstract final class SyncCollection {
  static const songs = 'songs';
  static const setlists = 'setlists';
  static const attachments = 'attachments';

  /// Personal adjustments (ADR-0020); the outbox record ID is
  /// [overlayRecordId].
  static const overlays = 'overlays';

  /// Band arrangements (ADR-0025); the outbox record ID is
  /// [arrangementRecordId].
  static const arrangements = 'arrangements';
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
