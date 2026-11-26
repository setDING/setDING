import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'outbox.dart';
import 'person_name.dart';

const _uuid = Uuid();

/// The name of a contact (ADR-0064), shown like the names of people
/// (ADR-0062).
extension ContactName on ContactEntry {
  PersonName get person =>
      PersonName(firstName: firstName, lastName: lastName, nickname: nickname);
}

/// People of an organization without an account (ADR-0064): created and
/// edited by whoever may edit sets in one of its bands, deleted by its
/// admins, also offline; synced per organization (outbox collection
/// [SyncCollection.contacts]). Permissions are checked by the server; the
/// callers only offer what the person may do.
class ContactRepository {
  ContactRepository(this.db);

  final AppDatabase db;

  /// The contacts of [organizationId] that are not deleted, by first name.
  Stream<List<ContactEntry>> watchContacts(String organizationId) =>
      (db.select(db.contacts)
            ..where(
              (c) =>
                  c.organizationId.equals(organizationId) &
                  c.deleted.equals(false),
            )
            ..orderBy([(c) => OrderingTerm.asc(c.firstName)]))
          .watch();

  /// Every contact of [organizationId], deleted ones too: sets keep showing
  /// the names of contacts deleted after they were put in their lineup.
  Stream<List<ContactEntry>> watchAllContacts(String organizationId) =>
      (db.select(
        db.contacts,
      )..where((c) => c.organizationId.equals(organizationId))).watch();

  /// Creates a contact in [organizationId] and returns its ID. Only the
  /// first name is required.
  Future<String> createContact(
    String organizationId, {
    required String firstName,
    String lastName = '',
    String nickname = '',
    String? email,
  }) => db.transaction(() async {
    final id = _uuid.v4();
    await db
        .into(db.contacts)
        .insert(
          ContactsCompanion.insert(
            id: id,
            organizationId: organizationId,
            firstName: firstName.trim(),
            lastName: Value(lastName.trim()),
            nickname: Value(nickname.trim()),
            email: Value(_email(email)),
            updatedAt: DateTime.now(),
          ),
        );
    await markDirty(db, SyncCollection.contacts, id, scope: organizationId);
    return id;
  });

  /// Changes the name and mail address of a contact.
  Future<void> updateContact(
    String id, {
    required String firstName,
    String lastName = '',
    String nickname = '',
    String? email,
  }) => _write(
    id,
    ContactsCompanion(
      firstName: Value(firstName.trim()),
      lastName: Value(lastName.trim()),
      nickname: Value(nickname.trim()),
      email: Value(_email(email)),
    ),
  );

  /// Deletes a contact (organization admins): its mail address goes at once,
  /// its name stays for the sets that name it.
  Future<void> deleteContact(String id) => _write(
    id,
    const ContactsCompanion(deleted: Value(true), email: Value(null)),
  );

  Future<void> _write(String id, ContactsCompanion changes) =>
      db.transaction(() async {
        final contact = await (db.select(
          db.contacts,
        )..where((c) => c.id.equals(id))).getSingleOrNull();
        if (contact == null || contact.deleted) return;
        await (db.update(db.contacts)..where((c) => c.id.equals(id))).write(
          changes.copyWith(updatedAt: Value(DateTime.now())),
        );
        await markDirty(
          db,
          SyncCollection.contacts,
          id,
          scope: contact.organizationId,
        );
      });

  static String? _email(String? email) {
    final trimmed = email?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
