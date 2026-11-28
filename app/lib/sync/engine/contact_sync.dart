import 'package:drift/drift.dart';

import '../../data/database.dart';
import '../../data/outbox.dart';
import '../../util/log.dart';
import '../sync_backend.dart';
import 'refused_changes.dart';
import 'sync_store.dart';

const _log = Log('sync');

/// Sync of the people without an account of an organization (ADR-0064):
/// delta pull per organization, push of this device's changes, last writer
/// wins. The server sends the mail addresses only to people who may edit
/// sets; for everybody else they stay null.
class ContactSync {
  ContactSync(this.db, this.backend, this.store, {RefusedChanges? undone})
    : undone = undone ?? RefusedChanges(store);

  final AppDatabase db;
  final SyncBackend backend;
  final SyncStore store;

  /// Changes of contacts the server refused for good (#1264).
  final RefusedChanges undone;

  /// Pulls the changed contacts of [orgId]; a server without them (older
  /// than ADR-0064) or another error keeps what the device has.
  Future<int> pull(String orgId) async {
    try {
      return (await _pull(orgId)).length;
    } on BackendException catch (e) {
      if (e.kind == BackendErrorKind.network ||
          e.kind == BackendErrorKind.signedOut) {
        rethrow;
      }
      _log.info('Contacts of $orgId not pulled: ${e.kind.name}');
      return 0;
    }
  }

  /// Pulls the server's version of the contacts whose change the server
  /// refused in this run (#1264), so that they are undone at once; a
  /// contact the server does not send back (never created) is removed
  /// from this device. A failed pull stops the sync, so nothing is removed
  /// for a server that did not answer.
  Future<int> pullUndone() => undone.pullAgain(
    SyncCollection.contacts,
    RefusedRecord.contact,
    pull: (org, _) => _pull(org),
    remove: (ids) => db.transaction(() async {
      await (db.delete(db.contacts)..where((c) => c.id.isIn(ids))).go();
      await (db.delete(db.syncOutbox)..where(
            (o) =>
                o.collection.equals(SyncCollection.contacts) &
                o.recordId.isIn(ids),
          ))
          .go();
      _log.info('Removed ${ids.length} contacts the server does not have');
    }),
  );

  /// [pull]; returns the IDs of the contacts the server sent.
  Future<Set<String>> _pull(String orgId) async {
    final since = await store.cursor(orgId, SyncCollection.contacts);
    final remote = await backend.pullContacts(orgId, since);
    if (remote.isEmpty) return const {};
    await db.transaction(() async {
      final ids = [for (final c in remote) c.id];
      final locals = await SyncStore.byId(
        ids,
        (chunk) =>
            (db.select(db.contacts)..where((c) => c.id.isIn(chunk))).get(),
        (c) => c.id,
      );
      final dirty = await store.dirty(SyncCollection.contacts, ids);
      for (final c in remote) {
        final local = locals[c.id];
        if (local != null && c.revision <= local.revision) continue;
        // A pending local change wins and is pushed.
        if (local != null && dirty.contains(c.id)) continue;
        await db.into(db.contacts).insertOnConflictUpdate(_row(c));
      }
      await store.setCursor(
        orgId,
        SyncCollection.contacts,
        remote.last.revision,
      );
    });
    return {for (final c in remote) c.id};
  }

  static ContactsCompanion _row(RemoteContact c) => ContactsCompanion.insert(
    id: c.id,
    organizationId: c.organizationId,
    firstName: c.firstName,
    lastName: Value(c.lastName),
    nickname: Value(c.nickname),
    email: Value(c.email),
    linkedUserId: Value(c.linkedUserId),
    createdBy: Value(c.createdBy),
    revision: Value(c.revision),
    updatedAt: DateTime.now(),
    deleted: Value(c.deleted),
  );

  Future<PushResult> push(OutboxEntry entry) async {
    final contact = await (db.select(
      db.contacts,
    )..where((c) => c.id.equals(entry.recordId))).getSingleOrNull();
    if (contact == null || contact.organizationId == localBandId) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final create = contact.revision == 0;
    if (create && contact.deleted) {
      await store.done(entry);
      return PushResult.skipped;
    }
    final remote = RemoteContact(
      id: contact.id,
      organizationId: contact.organizationId,
      firstName: contact.firstName,
      lastName: contact.lastName,
      nickname: contact.nickname,
      email: contact.email,
      revision: contact.revision,
      deleted: contact.deleted,
    );
    try {
      final stored = await backend.pushContact(remote, create: create);
      await db.transaction(() async {
        await (db.update(
          db.contacts,
        )..where((c) => c.id.equals(contact.id))).write(
          ContactsCompanion(
            revision: Value(stored.revision),
            createdBy: Value(stored.createdBy),
            linkedUserId: Value(stored.linkedUserId),
            deleted: Value(stored.deleted),
            email: Value(stored.email),
          ),
        );
        await store.done(entry);
      });
      return PushResult.done;
    } on BackendException catch (e) {
      if (!e.refused) rethrow; // sent again in the next sync
      // Not allowed (e.g. deleted or linked meanwhile) or a validation
      // error: sending it again gets the same answer, so the change is
      // undone and the server's version comes back (#1264).
      _log.warning('Contact ${contact.id} refused by the server, undone', e);
      await undone.undo(
        entry,
        (
          kind: RefusedRecord.contact,
          id: contact.id,
          name: [
            contact.firstName,
            contact.lastName,
          ].where((n) => n.isNotEmpty).join(' '),
          songTitle: null,
        ),
        collection: SyncCollection.contacts,
        scope: contact.organizationId,
        revision: contact.revision,
        setRevision: (before) =>
            (db.update(db.contacts)..where((c) => c.id.equals(contact.id)))
                .write(ContactsCompanion(revision: Value(before))),
      );
      return PushResult.skipped;
    }
  }
}
