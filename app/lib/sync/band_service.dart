import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/band_view.dart';
import '../data/database.dart';
import 'sync_backend.dart';

const _uuid = Uuid();

/// Organizations and bands of the signed-in user (ADR-0005, ADR-0017):
/// cached in the local database so that they, the roles and the names of
/// people are available offline (ADR-0001), and changed through the
/// backend. Songs and sets are synced later (issue #17).
class BandService {
  BandService(this.db, this.backend);

  final AppDatabase db;
  final SyncBackend backend;

  Stream<T> _watch<T>(Future<T> Function() load) {
    final tables = TableUpdateQuery.onAllTables([
      db.organizations,
      db.orgMemberships,
      db.bands,
      db.memberships,
    ]);
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    Future<void> emit() async {
      try {
        controller.add(await load());
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        sub = db.tableUpdates(tables).listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// The organizations of [userId], sorted by name.
  Stream<List<OrganizationView>> watchOrganizations(String? userId) {
    if (userId == null) return Stream.value(const []);
    return _watch(() => _organizations(userId));
  }

  Future<List<OrganizationView>> _organizations(String userId) async {
    final rows =
        await (db.select(db.organizations).join([
                innerJoin(
                  db.orgMemberships,
                  db.orgMemberships.organizationId.equalsExp(
                        db.organizations.id,
                      ) &
                      db.orgMemberships.userId.equals(userId),
                ),
              ])
              ..where(db.organizations.deleted.equals(false))
              ..orderBy([
                OrderingTerm.asc(db.organizations.name.collate(Collate.noCase)),
              ]))
            .get();
    return [
      for (final r in rows)
        OrganizationView(
          id: r.readTable(db.organizations).id,
          name: r.readTable(db.organizations).name,
          role: r.readTable(db.orgMemberships).role,
        ),
    ];
  }

  /// The local library followed by the bands [userId] can see, sorted by
  /// organization and band name.
  Stream<List<BandView>> watchBands(String? userId) {
    if (userId == null) return Stream.value(const [BandView.local]);
    return _watch(() => _bands(userId));
  }

  Future<List<BandView>> _bands(String userId) async {
    final orgs = {for (final o in await _organizations(userId)) o.id: o};
    final bands =
        await (db.select(db.bands)..where(
              (b) => b.deleted.equals(false) & b.organizationId.isIn(orgs.keys),
            ))
            .get();
    final own = {
      for (final m in await (db.select(
        db.memberships,
      )..where((m) => m.userId.equals(userId))).get())
        m.bandId: m.role,
    };
    // Organization-wide permission to edit songs (same as the server rule).
    bool mayEditSongs(String orgId) {
      if (orgs[orgId]!.isAdmin) return true;
      return bands.any(
        (b) =>
            b.organizationId == orgId &&
            own.containsKey(b.id) &&
            (own[b.id] == BandRole.admin || b.membersCanEditSongs),
      );
    }

    final views = [
      for (final b in bands)
        if (own.containsKey(b.id) || orgs[b.organizationId]!.isAdmin)
          BandView(
            id: b.id,
            name: b.name,
            organizationId: b.organizationId,
            organizationName: orgs[b.organizationId]!.name,
            role: own[b.id],
            isOrgAdmin: orgs[b.organizationId]!.isAdmin,
            membersCanEditSongs: b.membersCanEditSongs,
            mayEditOrgSongs: mayEditSongs(b.organizationId!),
          ),
    ];
    int byName(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    views.sort((a, b) {
      final org = byName(a.organizationName, b.organizationName);
      return org != 0 ? org : byName(a.name, b.name);
    });
    return [BandView.local, ...views];
  }

  /// People of an organization: admins first, then by name.
  Stream<List<OrgMembershipEntry>> watchOrgMembers(String organizationId) =>
      (db.select(db.orgMemberships)
            ..where((m) => m.organizationId.equals(organizationId))
            ..orderBy([
              (m) => OrderingTerm.asc(m.role),
              (m) => OrderingTerm.asc(m.userName.collate(Collate.noCase)),
            ]))
          .watch();

  /// Members of a band: admins first, then by name.
  Stream<List<MembershipEntry>> watchMembers(String bandId) =>
      (db.select(db.memberships)
            ..where((m) => m.bandId.equals(bandId))
            ..orderBy([
              (m) => OrderingTerm.asc(m.role),
              (m) => OrderingTerm.asc(m.userName.collate(Collate.noCase)),
            ]))
          .watch();

  /// Loads the organizations and bands of the signed-in user from the
  /// server and stores them. What the user can no longer see is hidden
  /// (songs and sets stay in the database until sync cleans them up).
  Future<void> refresh() async {
    final user = backend.currentUser;
    if (user == null) return;
    await store(user.id, await backend.fetchOrganizations());
  }

  /// Stores [remote] as the complete view of [userId].
  Future<void> store(String userId, List<RemoteOrganization> remote) =>
      db.transaction(() async {
        // What this user could see before, to hide what is gone.
        final previousOrgs = {
          for (final m in await (db.select(
            db.orgMemberships,
          )..where((m) => m.userId.equals(userId))).get())
            m.organizationId,
        };
        final previousBands = {
          for (final b in await (db.select(
            db.bands,
          )..where((b) => b.organizationId.isIn(previousOrgs))).get())
            b.id,
        };

        final orgIds = <String>{};
        final bandIds = <String>{};
        for (final o in remote) {
          orgIds.add(o.id);
          await db
              .into(db.organizations)
              .insertOnConflictUpdate(
                OrganizationsCompanion.insert(
                  id: o.id,
                  name: o.name,
                  revision: Value(o.revision),
                  deleted: const Value(false),
                ),
              );
          await (db.delete(
            db.orgMemberships,
          )..where((m) => m.organizationId.equals(o.id))).go();
          for (final m in o.members) {
            await db
                .into(db.orgMemberships)
                .insert(
                  OrgMembershipsCompanion.insert(
                    id: m.membershipId,
                    organizationId: o.id,
                    userId: m.userId,
                    userName: Value(m.name),
                    userEmail: Value(m.email),
                    role: m.role,
                    revision: Value(m.revision),
                  ),
                );
          }
          for (final b in o.bands) {
            bandIds.add(b.id);
            await db
                .into(db.bands)
                .insertOnConflictUpdate(
                  BandsCompanion.insert(
                    id: b.id,
                    name: b.name,
                    organizationId: Value(o.id),
                    membersCanEditSongs: Value(b.membersCanEditSongs),
                    revision: Value(b.revision),
                    deleted: const Value(false),
                  ),
                );
            await (db.delete(
              db.memberships,
            )..where((m) => m.bandId.equals(b.id))).go();
            for (final m in b.members) {
              await db
                  .into(db.memberships)
                  .insert(
                    MembershipsCompanion.insert(
                      id: m.membershipId,
                      bandId: b.id,
                      userId: m.userId,
                      userName: Value(m.name),
                      userEmail: Value(m.email),
                      role: m.role,
                      revision: Value(m.revision),
                    ),
                  );
            }
          }
        }

        for (final id in previousBands.difference(bandIds)) {
          await (db.delete(
            db.memberships,
          )..where((m) => m.bandId.equals(id))).go();
          await (db.update(db.bands)..where((b) => b.id.equals(id))).write(
            const BandsCompanion(deleted: Value(true)),
          );
        }
        for (final id in previousOrgs.difference(orgIds)) {
          await (db.delete(
            db.orgMemberships,
          )..where((m) => m.organizationId.equals(id))).go();
          await (db.update(db.organizations)..where((o) => o.id.equals(id)))
              .write(const OrganizationsCompanion(deleted: Value(true)));
        }
      });

  Future<T> _then<T>(Future<T> action) async {
    final result = await action;
    await refresh();
    return result;
  }

  /// Creates a band in [organizationId], or in a new organization of the
  /// same name when null; returns the band ID.
  Future<String> createBand(String name, {String? organizationId}) async {
    final id = _uuid.v4();
    await _then(
      backend.createBand(id: id, name: name, organizationId: organizationId),
    );
    return id;
  }

  Future<void> renameBand(String bandId, String name) =>
      _then(backend.updateBand(bandId, name: name));

  Future<void> setMembersCanEditSongs(String bandId, bool value) =>
      _then(backend.updateBand(bandId, membersCanEditSongs: value));

  Future<void> addBandMember(String bandId, String userId, BandRole role) =>
      _then(backend.addBandMember(bandId, userId, role));

  Future<void> setRole(String membershipId, BandRole role) =>
      _then(backend.setMemberRole(membershipId, role));

  /// Removes a member, or leaves the band when [membershipId] is the own one.
  Future<void> removeMember(String membershipId) =>
      _then(backend.removeMember(membershipId));

  Future<void> renameOrganization(String organizationId, String name) =>
      _then(backend.renameOrganization(organizationId, name));

  Future<void> setOrgRole(String orgMembershipId, BandRole role) =>
      _then(backend.setOrgMemberRole(orgMembershipId, role));

  /// Removes a person from the organization (and its bands), or leaves it.
  Future<void> removeOrgMember(String orgMembershipId) =>
      _then(backend.removeOrgMember(orgMembershipId));
}
