import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/attachment_storage.dart';
import '../data/band_view.dart';
import '../data/database.dart';
import '../data/organization_cleanup.dart';
import 'sync_backend.dart';

const _uuid = Uuid();

/// Organizations and bands of the signed-in user (ADR-0005, ADR-0017):
/// cached in the local database so that they, the roles and the names of
/// people are available offline (ADR-0001), and changed through the
/// backend. Songs and sets are synced later (issue #17).
class BandService {
  BandService(this.db, this.backend, {this.storage});

  final AppDatabase db;
  final SyncBackend backend;

  /// Where attachment files are stored, to delete those of a closed
  /// organization (ADR-0044).
  final AttachmentStorage? storage;

  Stream<T> _watch<T>(Future<T> Function() load) {
    final tables = TableUpdateQuery.onAllTables([
      db.organizations,
      db.orgMemberships,
      db.bands,
      db.memberships,
    ]);
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    // One load at a time: changes during a load start one more load, and
    // the result of a load that a change overtook is dropped, so the
    // stream never emits an older state after a newer one.
    var loading = false;
    var changed = false;
    Future<void> emit() async {
      if (loading) {
        changed = true;
        return;
      }
      loading = true;
      try {
        do {
          changed = false;
          try {
            final value = await load();
            if (!changed && !controller.isClosed) controller.add(value);
          } catch (e, st) {
            if (!changed && !controller.isClosed) controller.addError(e, st);
          }
        } while (changed && !controller.isClosed);
      } finally {
        loading = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        sub = db.tableUpdates(tables).listen((_) => emit());
      },
      onCancel: () async {
        await sub?.cancel();
        await controller.close();
      },
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

  /// The local library followed by the libraries of the organizations of
  /// [userId], sorted by name (ADR-0017).
  Stream<List<LibraryView>> watchLibraries(String? userId) {
    if (userId == null) return Stream.value(const [LibraryView.local]);
    return _watch(() => _libraries(userId));
  }

  Future<List<LibraryView>> _libraries(String userId) async {
    final rights = await _rights(userId);
    return [
      LibraryView.local,
      for (final o in rights.orgs.values) rights.library(o.id),
    ];
  }

  /// The organizations of [userId] (sorted by name), their bands, the
  /// user's band roles and the song library of each organization with the
  /// user's song permissions (same as the server rules, ADR-0023).
  Future<
    ({
      Map<String, OrganizationView> orgs,
      List<BandEntry> bands,
      Map<String, BandRole> own,
      LibraryView Function(String orgId) library,
    })
  >
  _rights(String userId) async {
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
    LibraryView library(String orgId) => LibraryView(
      id: orgId,
      name: orgs[orgId]!.name,
      orgRole: orgs[orgId]!.role,
      isLeader: bands.any(
        (b) => b.organizationId == orgId && own[b.id] == BandRole.admin,
      ),
      userId: userId,
    );

    return (orgs: orgs, bands: bands, own: own, library: library);
  }

  /// The local library followed by the bands [userId] can see, sorted by
  /// organization and band name.
  Stream<List<BandView>> watchBands(String? userId) {
    if (userId == null) return Stream.value(const [BandView.local]);
    return _watch(() => _bands(userId));
  }

  Future<List<BandView>> _bands(String userId) async {
    final (:orgs, :bands, :own, :library) = await _rights(userId);
    final views = [
      for (final b in bands)
        if (own.containsKey(b.id) ||
            orgs[b.organizationId]!.isAdmin ||
            b.substitute)
          BandView(
            id: b.id,
            name: b.name,
            organizationId: b.organizationId,
            organizationName: orgs[b.organizationId]!.name,
            role: own[b.id],
            orgRole: orgs[b.organizationId]!.role,
            orgLibrary: library(b.organizationId!),
            staleAfterSetting: b.staleAfterMonths,
            substitute: b.substitute && !own.containsKey(b.id),
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

  Future<BandChanges>? _refreshing;

  /// Loads the organizations and bands of the signed-in user from the
  /// server and stores them. What the user can no longer see is hidden
  /// (songs and sets stay in the database until sync cleans them up); the
  /// data of a closed organization is removed from this device (ADR-0044).
  /// Returns what is gone. Concurrent calls share one request.
  Future<BandChanges> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<BandChanges> _refresh() async {
    final user = backend.currentUser;
    if (user == null) return const BandChanges();
    final (:goneBands, :goneOrgs) = await store(
      user.id,
      await backend.fetchOrganizations(),
    );
    var closed = const <ClosedOrganization>[];
    if (goneOrgs.isNotEmpty) {
      try {
        closed = [
          for (final c in await backend.fetchClosedOrganizations())
            if (goneOrgs.contains(c.id)) c,
        ];
      } on BackendException {
        // Unknown why they are gone: hidden as before, kept on the device.
      }
    }
    for (final c in closed) {
      await removeOrganizationData(db, c.id, storage: storage);
    }
    final closedIds = {for (final c in closed) c.id};
    return BandChanges(
      goneBands: [
        for (final b in goneBands)
          if (!closedIds.contains(b.organizationId)) b.name,
      ],
      closedOrganizations: closed,
    );
  }

  /// Stores [remote] as the complete view of [userId] and returns the bands
  /// and organizations the user could see before but no longer can. Only
  /// rows that changed are written, so an unchanged refresh notifies no
  /// watcher.
  Future<({List<BandEntry> goneBands, Set<String> goneOrgs})> store(
    String userId,
    List<RemoteOrganization> remote,
  ) => db.transaction(() async {
    // What this user could see before, to hide what is gone.
    final previousOrgs = {
      for (final m in await (db.select(
        db.orgMemberships,
      )..where((m) => m.userId.equals(userId))).get())
        m.organizationId,
    };
    final previousBands = {
      // Substitute bands come from the lineups, not from here (ADR-0061).
      for (final b
          in await (db.select(db.bands)..where(
                (b) =>
                    b.organizationId.isIn(previousOrgs) &
                    b.substitute.equals(false),
              ))
              .get())
        b.id,
    };

    final orgIds = {for (final o in remote) o.id};
    final bandIds = {
      for (final o in remote)
        for (final b in o.bands) b.id,
    };
    final orgs = {
      for (final o in await (db.select(
        db.organizations,
      )..where((o) => o.id.isIn(orgIds))).get())
        o.id: o,
    };
    final orgMembers = await (db.select(
      db.orgMemberships,
    )..where((m) => m.organizationId.isIn(orgIds))).get();
    final bands = {
      for (final b in await (db.select(
        db.bands,
      )..where((b) => b.id.isIn(bandIds))).get())
        b.id: b,
    };
    final bandMembers = await (db.select(
      db.memberships,
    )..where((m) => m.bandId.isIn(bandIds))).get();

    for (final o in remote) {
      await _put(
        db.organizations,
        orgs[o.id],
        OrganizationEntry(
          id: o.id,
          name: o.name,
          revision: o.revision,
          deleted: false,
        ),
      );
      await _replace(
        db.orgMemberships,
        [
          for (final m in orgMembers)
            if (m.organizationId == o.id) m,
        ],
        [
          for (final m in o.members)
            OrgMembershipEntry(
              id: m.membershipId,
              organizationId: o.id,
              userId: m.userId,
              userName: m.name,
              userEmail: m.email,
              role: m.role,
              revision: m.revision,
            ),
        ],
        id: (m) => m.id,
        delete: (ids) =>
            (db.delete(db.orgMemberships)..where((m) => m.id.isIn(ids))).go(),
      );
      for (final b in o.bands) {
        await _put(
          db.bands,
          bands[b.id],
          BandEntry(
            id: b.id,
            name: b.name,
            organizationId: o.id,
            revision: b.revision,
            deleted: false,
            staleAfterMonths: b.staleAfterMonths,
            // A band from the organizations is no substitute band (any more).
            substitute: false,
          ),
        );
        await _replace(
          db.memberships,
          [
            for (final m in bandMembers)
              if (m.bandId == b.id) m,
          ],
          [
            for (final m in b.members)
              MembershipEntry(
                id: m.membershipId,
                bandId: b.id,
                userId: m.userId,
                userName: m.name,
                userEmail: m.email,
                role: m.role,
                revision: m.revision,
              ),
          ],
          id: (m) => m.id,
          delete: (ids) =>
              (db.delete(db.memberships)..where((m) => m.id.isIn(ids))).go(),
        );
      }
    }

    // Deletes and updates of no rows notify no watcher.
    final goneBands = previousBands.difference(bandIds);
    final goneEntries =
        await (db.select(db.bands)
              ..where((b) => b.id.isIn(goneBands) & b.deleted.equals(false))
              ..orderBy([
                (b) => OrderingTerm.asc(b.name.collate(Collate.noCase)),
              ]))
            .get();
    await (db.delete(
      db.memberships,
    )..where((m) => m.bandId.isIn(goneBands))).go();
    await (db.update(db.bands)
          ..where((b) => b.id.isIn(goneBands) & b.deleted.equals(false)))
        .write(const BandsCompanion(deleted: Value(true)));
    final goneOrgs = previousOrgs.difference(orgIds);
    final goneOrgsVisible = {
      for (final o in await (db.select(
        db.organizations,
      )..where((o) => o.id.isIn(goneOrgs) & o.deleted.equals(false))).get())
        o.id,
    };
    await (db.delete(
      db.orgMemberships,
    )..where((m) => m.organizationId.isIn(goneOrgs))).go();
    await (db.update(db.organizations)
          ..where((o) => o.id.isIn(goneOrgs) & o.deleted.equals(false)))
        .write(const OrganizationsCompanion(deleted: Value(true)));
    return (goneBands: goneEntries, goneOrgs: goneOrgsVisible);
  });

  /// Writes [row] unless [existing] is equal.
  Future<void> _put<D extends DataClass>(
    TableInfo<Table, D> table,
    D? existing,
    D row,
  ) async {
    if (existing == row) return;
    await db.into(table).insertOnConflictUpdate(row as Insertable<D>);
  }

  /// Makes the rows [existing] equal to [wanted]: deletes rows that are
  /// gone, writes new and changed ones.
  Future<void> _replace<D extends DataClass>(
    TableInfo<Table, D> table,
    List<D> existing,
    List<D> wanted, {
    required String Function(D) id,
    required Future<int> Function(Set<String> ids) delete,
  }) async {
    final byId = {for (final row in existing) id(row): row};
    final gone = byId.keys.toSet().difference(wanted.map(id).toSet());
    if (gone.isNotEmpty) await delete(gone);
    for (final row in wanted) {
      await _put(table, byId[id(row)], row);
    }
  }

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

  /// Sets when songs count as not played for a while in the band
  /// (ADR-0046): 1–36 months, 0 = the default. Online, like renaming.
  Future<void> setStaleAfterMonths(String bandId, int months) =>
      _then(backend.updateBand(bandId, staleAfterMonths: months.clamp(0, 36)));

  /// Deletes a band; it stays 30 days in the trash (organization admins,
  /// ADR-0044).
  Future<void> deleteBand(String bandId) => _then(backend.deleteBand(bandId));

  /// Restores a deleted band (organization admins, ADR-0044).
  Future<void> restoreBand(String bandId) => _then(backend.restoreBand(bandId));

  /// The bands of [organizationId] in its trash (organization admins,
  /// online, ADR-0044).
  Future<List<DeletedBand>> deletedBands(String organizationId) =>
      backend.fetchDeletedBands(organizationId);

  /// Closes an organization; it stays 30 days in the trash (its admins,
  /// ADR-0044). Its data leaves this device with the refresh.
  Future<void> closeOrganization(String organizationId) =>
      _then(backend.closeOrganization(organizationId));

  /// Restores a closed organization (its admins, ADR-0044); its songs and
  /// sets come back with the next sync.
  Future<void> restoreOrganization(String organizationId) =>
      _then(backend.restoreOrganization(organizationId));

  /// The closed organizations of the signed-in user (online, ADR-0044).
  Future<List<ClosedOrganization>> closedOrganizations() =>
      backend.fetchClosedOrganizations();

  Future<void> addBandMember(String bandId, String userId, BandRole role) =>
      _then(backend.addBandMember(bandId, userId, role));

  Future<void> setRole(String membershipId, BandRole role) =>
      _then(backend.setMemberRole(membershipId, role));

  /// Removes a member, or leaves the band when [membershipId] is the own one.
  Future<void> removeMember(String membershipId) =>
      _then(backend.removeMember(membershipId));

  Future<void> renameOrganization(String organizationId, String name) =>
      _then(backend.renameOrganization(organizationId, name));

  Future<void> setOrgRole(String orgMembershipId, OrgRole role) =>
      _then(backend.setOrgMemberRole(orgMembershipId, role));

  /// Removes a person from the organization (and its bands), or leaves it.
  Future<void> removeOrgMember(String orgMembershipId) =>
      _then(backend.removeOrgMember(orgMembershipId));
}

/// What a refresh found gone (ADR-0044).
class BandChanges {
  const BandChanges({
    this.goneBands = const [],
    this.closedOrganizations = const [],
  });

  /// Names of bands the user could see before but no longer can (deleted,
  /// or the user was removed or left), without those of closed
  /// organizations.
  final List<String> goneBands;

  /// Organizations of the user that were closed; their data was removed
  /// from this device.
  final List<ClosedOrganization> closedOrganizations;
}
