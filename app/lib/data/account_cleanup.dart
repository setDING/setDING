import 'attachment_storage.dart';
import 'database.dart';
import 'organization_cleanup.dart';

/// Removes what belonged to the deleted account [userId] from this device
/// (ADR-0052): the data of every organization it could see (as after
/// closing an organization), and its personal adjustments, annotations and
/// personal settings. The local library and the signed-out settings stay.
Future<void> removeAccountData(
  AppDatabase db,
  String userId, {
  AttachmentStorage? storage,
}) async {
  for (final org in await db.select(db.organizations).get()) {
    await removeOrganizationData(db, org.id, storage: storage);
  }
  await db.transaction(() async {
    await (db.delete(
      db.personalOverlays,
    )..where((o) => o.ownerId.equals(userId))).go();
    await (db.delete(
      db.annotations,
    )..where((a) => a.ownerId.equals(userId))).go();
    await (db.delete(
      db.userSettings,
    )..where((s) => s.ownerId.equals(userId))).go();
  });
}
