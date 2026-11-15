import 'package:drift/drift.dart';

import 'database.dart';

/// Server collections of synced records (ADR-0015, ADR-0017).
abstract final class SyncCollection {
  static const songs = 'songs';
  static const setlists = 'setlists';
  static const attachments = 'attachments';
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
  db.notifyUpdates({TableUpdate.onTable(db.syncOutbox)});
}
