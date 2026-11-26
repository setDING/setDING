import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/data/attachment_storage_io.dart';
import 'package:setding/data/band_copy.dart';
import 'package:setding/data/contact_repository.dart';
import 'package:setding/data/database.dart';
import 'package:setding/data/lineup.dart';
import 'package:setding/data/organization_cleanup.dart';
import 'package:setding/data/set_repository.dart';
import 'package:setding/sync/band_service.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/sync_engine.dart';

import 'fake_backend.dart';

/// People without an account on the device (ADR-0064, #1098).
const _leo = AuthUser(id: 'leo', email: 'leo@example.test', name: 'Leo');
const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeSyncBackend server;
  late SyncEngine engine;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('setding_contacts');
    // Leo leads the band and is organization admin; Ann is a member.
    server = FakeSyncBackend(user: _leo);
    server.addBand('b1', 'Rock', admin: _leo, organizationId: 'o1');
    server.addMember('b1', _ann, BandRole.member);
    engine = SyncEngine(
      db,
      server,
      BandService(db, server),
      copies: BandCopyService(db, FileAttachmentStorage(dir)),
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  ContactRepository contacts() => ContactRepository(db);
  SetRepository sets() => SetRepository(
    db,
    FileAttachmentStorage(dir),
    bandId: 'b1',
    userId: server.user?.id,
  );

  Future<SetlistEntry> localSet(String id) =>
      (db.select(db.setlists)..where((s) => s.id.equals(id))).getSingle();

  Future<ContactEntry?> localContact(String id) =>
      (db.select(db.contacts)..where((c) => c.id.equals(id))).getSingleOrNull();

  test('a contact created offline reaches the server before the set that '
      'names it', () async {
    await engine.sync();
    final id = await contacts().createContact(
      'o1',
      firstName: ' Guest ',
      lastName: 'Drummer',
      email: 'guest@example.test',
    );
    final set = await sets().createSet(name: 'Gig');
    await sets().setLineup(set, ['leo'], contacts: [id, id]);
    expect((await localSet(set)).lineupContacts, [id]);

    await engine.sync();
    final stored = server.contacts[id]!;
    expect(stored.firstName, 'Guest');
    expect(stored.email, 'guest@example.test');
    expect(stored.createdBy, 'leo');
    expect(server.sets[set]!.lineupContacts, [id]);
    expect(server.sets[set]!.lineupCustom, isTrue);
    // The contact was pushed first.
    expect(server.contactPushes.single.$2, isTrue);
    expect((await localContact(id))!.revision, stored.revision);
  });

  test('members get the names, set editors the mail addresses too', () async {
    server.putContact(
      const RemoteContact(
        id: 'c1',
        organizationId: 'o1',
        firstName: 'Guest',
        email: 'guest@example.test',
      ),
    );
    await engine.sync();
    expect((await localContact('c1'))!.email, 'guest@example.test');

    final annDb = AppDatabase(NativeDatabase.memory());
    addTearDown(annDb.close);
    server.user = _ann;
    final annEngine = SyncEngine(annDb, server, BandService(annDb, server));
    await annEngine.sync();
    final ann = await (annDb.select(
      annDb.contacts,
    )..where((c) => c.id.equals('c1'))).getSingle();
    expect(ann.firstName, 'Guest');
    expect(ann.email, isNull);
  });

  test('the lineup shows its contacts by name, also deleted ones, and the '
      'whole band none', () async {
    server.putContact(
      const RemoteContact(
        id: 'c1',
        organizationId: 'o1',
        firstName: 'Guest',
        lastName: 'Drummer',
      ),
    );
    server.putContact(
      const RemoteContact(
        id: 'c2',
        organizationId: 'o1',
        firstName: 'Zoe',
        deleted: true,
      ),
    );
    server.putSet(
      const RemoteSet(
        id: 's1',
        bandId: 'b1',
        name: 'Gig',
        lineup: ['leo'],
        lineupContacts: ['c2', 'c1', 'unknown'],
        lineupCustom: true,
      ),
    );
    await engine.sync();
    final set = await localSet('s1');
    expect(set.lineupContacts, ['c2', 'c1', 'unknown']);
    final all = await db.select(db.contacts).get();
    final lineup = resolveLineup(
      set,
      members: const [],
      orgMembers: const [],
      userId: 'leo',
      contacts: all,
    );
    expect(lineup.contacts, const [
      LineupContact(contactId: 'c1', name: 'Guest Drummer'),
      LineupContact(contactId: 'c2', name: 'Zoe'),
    ]);
    expect(lineup.contactIds, ['c1', 'c2']);
    // Only contacts that are not deleted are offered.
    expect(
      [for (final c in await contacts().watchContacts('o1').first) c.id],
      ['c1'],
    );

    await sets().setLineup('s1', null, contacts: ['c1']);
    final whole = await localSet('s1');
    expect(whole.lineupContacts, isEmpty);
    expect(
      resolveLineup(
        whole,
        members: const [],
        orgMembers: const [],
        userId: 'leo',
        contacts: all,
      ).contacts,
      isEmpty,
    );
  });

  test('editing and deleting a contact are pushed; a deleted contact loses '
      'its mail address', () async {
    await engine.sync();
    final id = await contacts().createContact(
      'o1',
      firstName: 'Guest',
      email: 'guest@example.test',
    );
    await engine.sync();
    await contacts().updateContact(id, firstName: 'Gast', nickname: 'G');
    await engine.sync();
    expect(server.contacts[id]!.nickname, 'G');
    expect(server.contacts[id]!.email, isNull);

    await contacts().updateContact(id, firstName: 'Gast', email: 'g@x.test');
    await contacts().deleteContact(id);
    expect((await localContact(id))!.email, isNull);
    await engine.sync();
    expect(server.contacts[id]!.deleted, isTrue);
    expect(server.contacts[id]!.email, isNull);
    // A deleted contact is not changed any more.
    await contacts().updateContact(id, firstName: 'Again');
    expect((await localContact(id))!.firstName, 'Gast');
  });

  test('a refused change is replaced by the server state at the next '
      'pull', () async {
    // Leo leads the band but is no organization admin.
    server.orgMembers.removeWhere((m) => m.user.id == 'leo');
    server.addOrgMember('o1', _leo, OrgRole.member);
    server.putContact(
      const RemoteContact(id: 'c1', organizationId: 'o1', firstName: 'Guest'),
    );
    await engine.sync();
    await contacts().deleteContact('c1');
    expect((await localContact('c1'))!.deleted, isTrue);
    await engine.sync(); // refused: only organization admins delete
    expect(server.contacts['c1']!.deleted, isFalse);
    await engine.sync();
    expect((await localContact('c1'))!.deleted, isFalse);
  });

  test('a server without contacts keeps the sync going', () async {
    server.contactsFail = true;
    server.putSet(const RemoteSet(id: 's1', bandId: 'b1', name: 'Gig'));
    final report = await engine.sync();
    expect(report.error, isNull);
    expect((await localSet('s1')).name, 'Gig');
  });

  test('a linked contact comes back deleted with its account', () async {
    server.putContact(
      const RemoteContact(id: 'c1', organizationId: 'o1', firstName: 'Guest'),
    );
    await engine.sync();
    server.putContact(
      const RemoteContact(
        id: 'c1',
        organizationId: 'o1',
        firstName: 'Guest',
        linkedUserId: 'ann',
        deleted: true,
      ),
    );
    await engine.sync();
    final c = (await localContact('c1'))!;
    expect(c.deleted, isTrue);
    expect(c.linkedUserId, 'ann');
  });

  test('a closed organization takes its contacts and their pending '
      'changes', () async {
    await engine.sync();
    final id = await contacts().createContact('o1', firstName: 'Guest');
    await removeOrganizationData(db, 'o1');
    expect(await localContact(id), isNull);
    final outbox = await db.select(db.syncOutbox).get();
    expect(outbox.where((e) => e.recordId == id), isEmpty);
  });

  test('copying a set into another band leaves its contacts out', () async {
    await engine.sync();
    final storage = FileAttachmentStorage(dir);
    final id = await contacts().createContact('o1', firstName: 'Guest');
    final set = await sets().createSet(name: 'Gig');
    await sets().setLineup(set, ['leo'], contacts: [id]);
    final copy = await BandCopyService(
      db,
      storage,
    ).copySet(set, targetBandId: localBandId, targetLibraryId: localBandId);
    expect((await localSet(copy)).lineupContacts, isEmpty);
  });
}
