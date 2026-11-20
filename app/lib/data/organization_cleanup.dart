import 'package:drift/drift.dart';

import 'attachment_storage.dart';
import 'database.dart';
import 'outbox.dart';

/// Removes everything of the organization [orgId] from this device after it
/// was closed (ADR-0044): its songs with their attachments, personal
/// adjustments, annotations and conflicts, its bands with their sets,
/// arrangements and memberships, its people, pending changes and sync
/// cursors, and the downloaded attachment files. Restoring the organization
/// brings everything back from the server with the next sync.
Future<void> removeOrganizationData(
  AppDatabase db,
  String orgId, {
  AttachmentStorage? storage,
}) async {
  final files = await db.transaction(() async {
    Future<List<String>> ids(String sql, List<Object> args) async => [
      for (final row
          in await db
              .customSelect(sql, variables: [for (final a in args) Variable(a)])
              .get())
        row.read<String>('id'),
    ];

    final songs = await ids('SELECT id FROM songs WHERE library_id = ?', [
      orgId,
    ]);
    final bands = await ids('SELECT id FROM bands WHERE organization_id = ?', [
      orgId,
    ]);
    final sets = await ids(
      'SELECT id FROM setlists WHERE band_id IN '
      '(SELECT id FROM bands WHERE organization_id = ?)',
      [orgId],
    );
    final attachments = await db
        .customSelect(
          'SELECT id, file_name FROM attachments WHERE song_id IN '
          '(SELECT id FROM songs WHERE library_id = ?)',
          variables: [Variable(orgId)],
        )
        .get();
    final annotations = await ids(
      'SELECT id FROM annotations WHERE song_id IN '
      '(SELECT id FROM songs WHERE library_id = ?)',
      [orgId],
    );

    // Pending changes of all of it: they cannot reach the server anymore.
    final records = {
      ...songs,
      ...sets,
      ...annotations,
      for (final a in attachments) a.read<String>('id'),
    };
    final outbox = await db.select(db.syncOutbox).get();
    final gone = [
      for (final e in outbox)
        if (records.contains(e.recordId) ||
            (e.collection == SyncCollection.overlays &&
                songs.contains(parseOverlayRecordId(e.recordId).$2)) ||
            (e.collection == SyncCollection.arrangements &&
                (bands.any((b) => e.recordId.startsWith('$b:')) ||
                    songs.any((s) => e.recordId.endsWith(':$s')))))
          e,
    ];
    for (final e in gone) {
      await (db.delete(db.syncOutbox)..where(
            (o) =>
                o.collection.equals(e.collection) &
                o.recordId.equals(e.recordId),
          ))
          .go();
    }

    Future<void> run(String sql) => db.customStatement(sql, [orgId]);
    const songsOf = 'SELECT id FROM songs WHERE library_id = ?';
    const bandsOf = 'SELECT id FROM bands WHERE organization_id = ?';
    await run(
      'DELETE FROM set_items WHERE set_id IN '
      '(SELECT id FROM setlists WHERE band_id IN ($bandsOf))',
    );
    await run('DELETE FROM set_items WHERE song_id IN ($songsOf)');
    await run('DELETE FROM setlists WHERE band_id IN ($bandsOf)');
    await run('DELETE FROM band_arrangements WHERE band_id IN ($bandsOf)');
    await run('DELETE FROM band_arrangements WHERE song_id IN ($songsOf)');
    await run('DELETE FROM personal_overlays WHERE song_id IN ($songsOf)');
    await run('DELETE FROM annotations WHERE song_id IN ($songsOf)');
    await run('DELETE FROM attachments WHERE song_id IN ($songsOf)');
    await run('DELETE FROM song_conflicts WHERE song_id IN ($songsOf)');
    await run('DELETE FROM org_plays WHERE organization_id = ?');
    await run('DELETE FROM songs WHERE library_id = ?');
    await run('DELETE FROM memberships WHERE band_id IN ($bandsOf)');
    for (final scope in [orgId, ...bands]) {
      await (db.delete(
        db.syncCursors,
      )..where((c) => c.scope.equals(scope))).go();
    }
    await run('DELETE FROM bands WHERE organization_id = ?');
    await run('DELETE FROM org_memberships WHERE organization_id = ?');
    await run('DELETE FROM organizations WHERE id = ?');
    return [for (final a in attachments) a.read<String>('file_name')];
  });
  if (storage == null) return;
  for (final file in files) {
    if (file.isEmpty) continue;
    try {
      await storage.delete(file);
    } catch (_) {
      // Already gone; nothing to keep.
    }
  }
}
