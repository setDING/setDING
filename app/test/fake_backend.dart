import 'dart:async';
import 'dart:typed_data';

import 'package:setding/data/database.dart' show SetItemType;
import 'package:setding/sync/sync_backend.dart';

/// In-memory [SyncBackend] for widget tests.
class FakeSyncBackend implements SyncBackend {
  FakeSyncBackend({this.user, this.serverUrl = defaultServerUrl});

  AuthUser? user;

  @override
  final String serverUrl;

  /// Accounts that can sign in: email → password.
  final accounts = <String, String>{};

  /// When set, every call fails with this error.
  BackendErrorKind? failWith;

  final resetRequests = <String>[];
  final verificationRequests = <String>[];

  /// Registration settings reported by [fetchServerConfig] (ADR-0024);
  /// an open server unless a test asks otherwise.
  ServerConfig config = const ServerConfig();

  /// Accounts whose address is not confirmed (sign-in fails).
  final unverified = <String>{};

  /// Invitation tokens of the last sign-ups.
  final signUpInvites = <String?>[];
  int refreshCount = 0;
  final _changes = StreamController<AuthUser?>.broadcast();

  void _check() {
    if (failWith != null) throw BackendException(failWith!);
  }

  void _set(AuthUser? u) {
    user = u;
    _changes.add(u);
  }

  /// [u] with the names of [name], as the server keeps them (ADR-0062).
  static AuthUser _withName(AuthUser u, PersonName name) => AuthUser(
    id: u.id,
    email: u.email,
    name: name.format(NameFormat.nickname),
    firstName: name.firstName.trim(),
    lastName: name.lastName.trim(),
    nickname: name.nickname.trim(),
  );

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _check();
    if (accounts[email.trim()] != password) {
      throw const BackendException(BackendErrorKind.invalidCredentials);
    }
    if (unverified.contains(email.trim())) {
      throw const BackendException(BackendErrorKind.emailNotVerified);
    }
    final u = AuthUser(id: 'u-$email', email: email.trim(), name: '');
    _set(u);
    return u;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required PersonName name,
    String? invite,
  }) async {
    _check();
    if (config.inviteOnly && invite == null) {
      throw const BackendException(BackendErrorKind.invitationRequired);
    }
    if (accounts.containsKey(email.trim())) {
      throw const BackendException(BackendErrorKind.emailTaken);
    }
    accounts[email.trim()] = password;
    signUpInvites.add(invite);
    if (config.emailVerification) {
      unverified.add(email.trim());
      throw const BackendException(BackendErrorKind.emailNotVerified);
    }
    final u = _withName(
      AuthUser(id: 'u-$email', email: email.trim(), name: ''),
      name,
    );
    _set(u);
    return u;
  }

  @override
  Future<AuthUser> changeName(PersonName name) async {
    _check();
    final u = user;
    if (u == null) throw const BackendException(BackendErrorKind.signedOut);
    final changed = _withName(u, name);
    _set(changed);
    return changed;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _check();
    final u = user;
    if (u == null) throw const BackendException(BackendErrorKind.signedOut);
    if (accounts[u.email] != oldPassword) {
      throw const BackendException(BackendErrorKind.invalidCredentials);
    }
    accounts[u.email] = newPassword;
  }

  /// Organizations whose only admin cannot delete the account (ADR-0052).
  final soleAdminOrgs = <String>[];

  @override
  Future<void> deleteAccount(String password) async {
    _check();
    final u = user;
    if (u == null) throw const BackendException(BackendErrorKind.signedOut);
    if (accounts[u.email] != password) {
      throw const BackendException(BackendErrorKind.invalidCredentials);
    }
    if (soleAdminOrgs.isNotEmpty) {
      throw const BackendException(BackendErrorKind.soleOrgAdmin);
    }
    accounts.remove(u.email);
    _set(null);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _check();
    resetRequests.add(email);
  }

  @override
  Future<void> requestVerification(String email) async {
    _check();
    verificationRequests.add(email);
  }

  @override
  Future<ServerConfig> fetchServerConfig() async {
    // The config route answers outdated clients too (ADR-0029).
    if (failWith != BackendErrorKind.updateRequired) _check();
    return config;
  }

  @override
  Future<void> refreshSession() async => refreshCount++;

  @override
  Future<void> signOut() async => _set(null);

  // Organizations and bands ----------------------------------------------------

  /// Organizations on the "server": id → name.
  final organizations = <String, String>{};

  /// Closed organizations (ADR-0044): id → when and by whom.
  final closedOrganizations = <String, ({DateTime at, AuthUser by})>{};

  /// People of organizations on the "server".
  final orgMembers = <FakeMember<OrgRole>>[];

  /// Bands on the "server".
  final bands = <String, FakeBand>{};

  /// Band memberships on the "server".
  final members = <FakeMember<BandRole>>[];
  int _ids = 0;

  /// Adds an organization with [admin], e.g. to start a test inside one.
  void addOrganization(String id, String name, {required AuthUser admin}) {
    organizations[id] = name;
    addOrgMember(id, admin, OrgRole.admin);
  }

  FakeMember<OrgRole> addOrgMember(String orgId, AuthUser user, OrgRole role) {
    final m = FakeMember('om${++_ids}', orgId, user, role);
    orgMembers.add(m);
    return m;
  }

  /// Adds a band to an organization (created if needed) with [admin].
  void addBand(
    String id,
    String name, {
    required AuthUser admin,
    String? organizationId,
  }) {
    final orgId = organizationId ?? 'org-$id';
    if (!organizations.containsKey(orgId)) {
      addOrganization(orgId, name, admin: admin);
    }
    bands[id] = FakeBand(orgId, name);
    addMember(id, admin, BandRole.admin);
  }

  FakeMember<BandRole> addMember(String bandId, AuthUser user, BandRole role) {
    final orgId = bands[bandId]!.organizationId;
    if (!orgMembers.any((m) => m.scopeId == orgId && m.user.id == user.id)) {
      addOrgMember(orgId, user, OrgRole.member);
    }
    final m = FakeMember('m${++_ids}', bandId, user, role);
    members.add(m);
    return m;
  }

  bool _isOrgAdmin(String orgId) => orgMembers.any(
    (m) =>
        m.scopeId == orgId && m.user.id == user?.id && m.role == OrgRole.admin,
  );

  bool _canManageBand(String bandId) =>
      _isOrgAdmin(bands[bandId]!.organizationId) ||
      members.any(
        (m) =>
            m.scopeId == bandId &&
            m.user.id == user?.id &&
            m.role == BandRole.admin,
      );

  void _requireUser() {
    _check();
    if (user == null) throw const BackendException(BackendErrorKind.signedOut);
  }

  RemoteMember<R> _remote<R extends Enum>(FakeMember<R> m) => RemoteMember<R>(
    membershipId: m.id,
    userId: m.user.id,
    name: m.user.displayName,
    firstName: m.user.firstName ?? '',
    lastName: m.user.lastName ?? '',
    nickname: m.user.nickname,
    email: m.user.id == user!.id ? m.user.email : null,
    role: m.role,
  );

  /// Number of [fetchOrganizations] calls.
  int fetchOrganizationsCalls = 0;

  @override
  Future<List<RemoteOrganization>> fetchOrganizations() async {
    fetchOrganizationsCalls++;
    _requireUser();
    return [
      for (final o in organizations.entries)
        if (!closedOrganizations.containsKey(o.key) &&
            orgMembers.any((m) => m.scopeId == o.key && m.user.id == user!.id))
          RemoteOrganization(
            id: o.key,
            name: o.value,
            // Stable like the server's: unchanged records keep it.
            revision: 1,
            members: [
              for (final m in orgMembers)
                if (m.scopeId == o.key) _remote(m),
            ],
            bands: [
              for (final b in bands.entries)
                if (b.value.organizationId == o.key &&
                    b.value.deletedAt == null &&
                    (_isOrgAdmin(o.key) ||
                        members.any(
                          (m) => m.scopeId == b.key && m.user.id == user!.id,
                        )))
                  RemoteBand(
                    id: b.key,
                    organizationId: o.key,
                    name: b.value.name,
                    revision: 1,
                    staleAfterMonths: b.value.staleAfterMonths,
                    members: [
                      for (final m in members)
                        if (m.scopeId == b.key) _remote(m),
                    ],
                  ),
            ],
          ),
    ];
  }

  void _keepAdmin<R extends Enum>(List<FakeMember<R>> list, FakeMember<R> m) {
    final others = list.where(
      (o) => o.scopeId == m.scopeId && o != m && o.role.name == 'admin',
    );
    if (m.role.name == 'admin' && others.isEmpty) {
      throw const BackendException(BackendErrorKind.lastAdmin);
    }
  }

  FakeMember<R> _find<R extends Enum>(List<FakeMember<R>> list, String id) {
    final m = list.where((m) => m.id == id).firstOrNull;
    if (m == null) throw const BackendException(BackendErrorKind.notAllowed);
    return m;
  }

  @override
  Future<void> renameOrganization(String organizationId, String name) async {
    _requireUser();
    if (!_isOrgAdmin(organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    organizations[organizationId] = name.trim();
  }

  @override
  Future<void> setOrgMemberRole(String orgMembershipId, OrgRole role) async {
    _requireUser();
    final m = _find(orgMembers, orgMembershipId);
    if (!_isOrgAdmin(m.scopeId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (role != OrgRole.admin) _keepAdmin(orgMembers, m);
    m.role = role;
  }

  @override
  Future<void> removeOrgMember(String orgMembershipId) async {
    _requireUser();
    final m = _find(orgMembers, orgMembershipId);
    if (!_isOrgAdmin(m.scopeId) && m.user.id != user!.id) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    _keepAdmin(orgMembers, m);
    orgMembers.remove(m);
    members.removeWhere(
      (b) =>
          b.user.id == m.user.id &&
          bands[b.scopeId]?.organizationId == m.scopeId,
    );
  }

  @override
  Future<void> createBand({
    required String id,
    required String name,
    String? organizationId,
  }) async {
    _requireUser();
    if (organizationId != null && !_isOrgAdmin(organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (organizationId == null && config.inviteOnly) {
      throw const BackendException(BackendErrorKind.founderInvitationRequired);
    }
    addBand(id, name.trim(), admin: user!, organizationId: organizationId);
  }

  @override
  Future<void> updateBand(
    String bandId, {
    String? name,
    int? staleAfterMonths,
  }) async {
    _requireUser();
    final band = bands[bandId];
    // Set planners may change the threshold only (ADR-0046).
    final planner = members.any(
      (m) =>
          m.scopeId == bandId &&
          m.user.id == user?.id &&
          m.role == BandRole.planner,
    );
    if (band == null ||
        !(_canManageBand(bandId) || (planner && name == null))) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (name != null) band.name = name.trim();
    if (staleAfterMonths != null) band.staleAfterMonths = staleAfterMonths;
  }

  @override
  Future<void> closeOrganization(String organizationId) async {
    _requireUser();
    if (!organizations.containsKey(organizationId) ||
        closedOrganizations.containsKey(organizationId) ||
        !_isOrgAdmin(organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    closedOrganizations[organizationId] = (
      at: DateTime.now().toUtc(),
      by: user!,
    );
  }

  @override
  Future<void> restoreOrganization(String organizationId) async {
    _requireUser();
    if (!closedOrganizations.containsKey(organizationId) ||
        !_isOrgAdmin(organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    closedOrganizations.remove(organizationId);
  }

  @override
  Future<List<ClosedOrganization>> fetchClosedOrganizations() async {
    _requireUser();
    return [
      for (final c in closedOrganizations.entries)
        if (orgMembers.any((m) => m.scopeId == c.key && m.user.id == user!.id))
          ClosedOrganization(
            id: c.key,
            name: organizations[c.key]!,
            closedAt: c.value.at,
            isAdmin: _isOrgAdmin(c.key),
            closedBy: c.value.by.displayName,
          ),
    ]..sort((a, b) => b.closedAt.compareTo(a.closedAt));
  }

  @override
  Future<void> deleteBand(String bandId) async {
    _requireUser();
    final band = bands[bandId];
    if (band == null ||
        band.deletedAt != null ||
        !_isOrgAdmin(band.organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    band.deletedAt = DateTime.now().toUtc();
  }

  @override
  Future<void> restoreBand(String bandId) async {
    _requireUser();
    final band = bands[bandId];
    if (band == null ||
        band.deletedAt == null ||
        !_isOrgAdmin(band.organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    band.deletedAt = null;
  }

  /// The storage limit per organization (ADR-0070); null for none.
  int? storageLimitBytes = 25 * 1024 * 1024;

  /// Number of [fetchOrgStorage] calls.
  int fetchOrgStorageCalls = 0;

  /// Whether the signed-in user may upload PDFs in [orgId] (ADR-0023).
  bool _mayUpload(String orgId) =>
      orgMembers.any(
        (m) =>
            m.scopeId == orgId &&
            m.user.id == user?.id &&
            (m.role == OrgRole.admin || m.role == OrgRole.librarian),
      ) ||
      members.any(
        (m) =>
            bands[m.scopeId]?.organizationId == orgId &&
            m.user.id == user?.id &&
            m.role == BandRole.admin,
      );

  /// The bytes of [orgId]'s PDFs still on the server: `(used, live)`.
  (int, int) _usage(String orgId) {
    var used = 0;
    var live = 0;
    for (final a in attachments.values) {
      if (a.organizationId != orgId || a.purged) continue;
      used += a.sizeBytes;
      final song = songs[a.songId];
      if (!a.deleted && !(song?.deleted ?? false)) live += a.sizeBytes;
    }
    return (used, live);
  }

  @override
  Future<OrgStorage?> fetchOrgStorage(String organizationId) async {
    _requireUser();
    fetchOrgStorageCalls++;
    if (!_mayUpload(organizationId)) return null;
    final (used, live) = _usage(organizationId);
    return OrgStorage(
      usedBytes: used,
      limitBytes: storageLimitBytes,
      liveBytes: live,
      trashBytes: used - live,
    );
  }

  /// Number of [fetchOrgPlays] calls; set [orgPlaysFail] to answer them
  /// like a server without the route.
  int fetchOrgPlaysCalls = 0;
  bool orgPlaysFail = false;

  @override
  Future<List<RemoteOrgPlay>> fetchOrgPlays(String organizationId) async {
    _requireUser();
    fetchOrgPlaysCalls++;
    if (orgPlaysFail ||
        !orgMembers.any(
          (m) => m.scopeId == organizationId && m.user.id == user!.id,
        )) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final past = [
      for (final s in sets.values)
        if (!s.deleted &&
            bands[s.bandId]?.organizationId == organizationId &&
            bands[s.bandId]?.deletedAt == null &&
            s.gigDate != null &&
            s.gigDate!.isBefore(today))
          s,
    ]..sort((a, b) => b.gigDate!.compareTo(a.gigDate!));
    final plays = <(String, String), RemoteOrgPlay>{};
    for (final set in past) {
      for (final songId in {
        for (final i in set.items)
          if (i.type == SetItemType.song) ?i.songId,
      }) {
        final key = (songId, set.bandId);
        final before = plays[key];
        final played = set.items
            .firstWhere((i) => i.songId == songId)
            .played
            ?.key;
        plays[key] = RemoteOrgPlay(
          songId: songId,
          bandId: set.bandId,
          bandName: bands[set.bandId]!.name,
          count: (before?.count ?? 0) + 1,
          last: before?.last ?? set.gigDate!,
          key: before?.key ?? played,
        );
      }
    }
    return plays.values.toList();
  }

  @override
  Future<List<DeletedBand>> fetchDeletedBands(String organizationId) async {
    _requireUser();
    if (!_isOrgAdmin(organizationId)) return const [];
    return [
      for (final b in bands.entries)
        if (b.value.organizationId == organizationId &&
            b.value.deletedAt != null)
          DeletedBand(
            id: b.key,
            name: b.value.name,
            deletedAt: b.value.deletedAt!,
          ),
    ]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  }

  @override
  Future<void> addBandMember(
    String bandId,
    String userId,
    BandRole role,
  ) async {
    _requireUser();
    if (!_canManageBand(bandId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final person = orgMembers
        .where(
          (m) =>
              m.scopeId == bands[bandId]!.organizationId && m.user.id == userId,
        )
        .firstOrNull;
    if (person == null) {
      throw const BackendException(BackendErrorKind.notOrgMember);
    }
    members.add(FakeMember('m${++_ids}', bandId, person.user, role));
  }

  @override
  Future<void> setMemberRole(String membershipId, BandRole role) async {
    _requireUser();
    final m = _find(members, membershipId);
    if (!_canManageBand(m.scopeId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (role == BandRole.member) _keepAdmin(members, m);
    m.role = role;
  }

  @override
  Future<void> removeMember(String membershipId) async {
    _requireUser();
    final m = _find(members, membershipId);
    if (!_canManageBand(m.scopeId) && m.user.id != user!.id) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    _keepAdmin(members, m);
    members.remove(m);
  }

  // Invitations ------------------------------------------------------------------

  final invites = <FakeInvite>[];

  /// Clock for expiry checks (tests can move it forward).
  DateTime now = DateTime.utc(2026, 11, 15, 12);

  FakeInvite? _invite(String token) =>
      invites.where((i) => i.token == token).firstOrNull;

  InviteStatus _inviteStatus(FakeInvite i) => i.revoked
      ? InviteStatus.revoked
      : ((i.founder != null || i.contactId != null) && i.usedBy != null)
      ? InviteStatus.used
      : (i.expires.isBefore(now) ? InviteStatus.expired : InviteStatus.valid);

  /// A founder invitation for a new organization [name] (ADR-0024), as the
  /// server operator creates it; returns its link.
  String addFounderInvite(String name) {
    final token = 'Fnd${++_ids}'.padRight(32, 'x');
    invites.add(
      FakeInvite('inv$_ids', '', token, now, now.add(const Duration(days: 7)))
        ..founder = name,
    );
    return 'https://api.setding.app/invite/$token';
  }

  @override
  Future<CreatedInvite> createInvite(
    String organizationId, {
    String? bandId,
    String? contactId,
  }) async {
    _requireUser();
    final allowed =
        _isOrgAdmin(organizationId) ||
        (bandId != null && _canManageBand(bandId));
    if (!allowed) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (contactId != null) {
      final c = contacts[contactId];
      if (c == null || c.deleted || c.organizationId != organizationId) {
        throw const BackendException(BackendErrorKind.server);
      }
    }
    final token = 'Tok${++_ids}'.padRight(32, 'x');
    final invite =
        FakeInvite(
            'inv$_ids',
            organizationId,
            token,
            now,
            now.add(const Duration(days: 7)),
          )
          ..bandId = bandId
          ..contactId = contactId;
    invites.add(invite);
    return CreatedInvite(
      id: invite.id,
      url: 'https://api.setding.app/invite/$token',
      expires: invite.expires,
    );
  }

  @override
  Future<List<InviteInfo>> fetchInvites(
    String organizationId, {
    String? bandId,
  }) async {
    _requireUser();
    return [
      for (final i in invites.reversed)
        if (i.organizationId == organizationId &&
            i.contactId == null &&
            (bandId == null || i.bandId == bandId) &&
            _inviteStatus(i) == InviteStatus.valid)
          InviteInfo(
            id: i.id,
            created: i.created,
            expires: i.expires,
            revoked: i.revoked,
            bandName: i.bandId == null ? null : bands[i.bandId]?.name,
            joined: [for (final u in i.joined) u.displayName],
          ),
    ];
  }

  @override
  Future<CreatedInvite> fetchInviteLink(String inviteId) async {
    _requireUser();
    final i = invites.firstWhere((i) => i.id == inviteId);
    switch (_inviteStatus(i)) {
      case InviteStatus.valid:
        break;
      case InviteStatus.revoked:
        throw const BackendException(BackendErrorKind.inviteRevoked);
      case InviteStatus.expired || InviteStatus.used:
        throw const BackendException(BackendErrorKind.inviteExpired);
    }
    if (!i.stored) {
      throw const BackendException(BackendErrorKind.inviteNotStored);
    }
    return CreatedInvite(
      id: i.id,
      url: 'https://api.setding.app/invite/${i.token}',
      expires: i.expires,
    );
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    _requireUser();
    invites.firstWhere((i) => i.id == inviteId).revoked = true;
  }

  @override
  Future<InvitePreview> previewInvite(String token) async {
    _check();
    final invite = _invite(token);
    if (invite == null) {
      throw const BackendException(BackendErrorKind.inviteUnknown);
    }
    return InvitePreview(
      organizationId: invite.organizationId,
      organizationName: invite.founder ?? organizations[invite.organizationId]!,
      founder: invite.founder != null,
      bandName: bands[invite.bandId]?.name,
      status: _inviteStatus(invite),
      alreadyMember: orgMembers.any(
        (m) => m.scopeId == invite.organizationId && m.user.id == user?.id,
      ),
      contact: switch (contacts[invite.contactId]) {
        final c?
            when !c.deleted && _inviteStatus(invite) == InviteStatus.valid =>
          (
            name: PersonName(
              firstName: c.firstName,
              lastName: c.lastName,
              nickname: c.nickname,
            ),
            email: c.email,
          ),
        _ => null,
      },
    );
  }

  @override
  Future<String> redeemInvite(String token) async {
    _requireUser();
    final invite = _invite(token);
    if (invite == null) {
      throw const BackendException(BackendErrorKind.inviteUnknown);
    }
    switch (_inviteStatus(invite)) {
      case InviteStatus.expired:
        throw const BackendException(BackendErrorKind.inviteExpired);
      case InviteStatus.revoked:
        throw const BackendException(BackendErrorKind.inviteRevoked);
      case InviteStatus.used:
        throw const BackendException(BackendErrorKind.inviteUsed);
      case InviteStatus.valid:
    }
    if (invite.founder case final name?) {
      final orgId = 'org${++_ids}';
      organizations[orgId] = name;
      addOrgMember(orgId, user!, OrgRole.admin);
      invite.usedBy = user;
      return orgId;
    }
    final orgId = invite.organizationId;
    if (!orgMembers.any((m) => m.scopeId == orgId && m.user.id == user!.id)) {
      addOrgMember(orgId, user!, OrgRole.member);
      invite.joined.add(user!);
    }
    final bandId = invite.bandId;
    if (bandId != null &&
        !members.any((m) => m.scopeId == bandId && m.user.id == user!.id)) {
      addMember(bandId, user!, BandRole.member);
    }
    // A personal invitation links its contact (ADR-0064): the account takes
    // its place in every lineup, the contact is deleted.
    if (contacts[invite.contactId] case final c?) {
      invite.usedBy = user;
      for (final set in sets.values.toList()) {
        if (!set.lineupContacts.contains(c.id)) continue;
        putSet(
          RemoteSet(
            id: set.id,
            bandId: set.bandId,
            name: set.name,
            gigDate: set.gigDate,
            venue: set.venue,
            items: set.items,
            deleted: set.deleted,
            lineup: {...set.lineup, user!.id}.toList(),
            lineupContacts: [
              for (final id in set.lineupContacts)
                if (id != c.id) id,
            ],
            lineupCustom: set.lineupCustom,
          ),
          by: user!.id,
        );
      }
      putContact(
        RemoteContact(
          id: c.id,
          organizationId: c.organizationId,
          firstName: c.firstName,
          lastName: c.lastName,
          nickname: c.nickname,
          linkedUserId: user!.id,
          deleted: true,
        ),
      );
    }
    return orgId;
  }

  // Songs and sets ----------------------------------------------------------------

  /// Server state: songs and sets by ID.
  final songs = <String, RemoteSong>{};
  final sets = <String, RemoteSet>{};
  int _serverRevision = 1000;
  final changes = StreamController<String>.broadcast();
  int pushCount = 0;

  /// Simulates a change by someone else.
  ///
  /// [by] (or [RemoteSong.updatedBy]) is recorded as the last editor, and as
  /// the creator of a new song, as the server does.
  ///
  /// The link fields (ADR-0053) are taken from [song] for a new song and kept
  /// otherwise, as an update of the content does not send them.
  RemoteSong putSong(RemoteSong song, {String? by}) {
    final editor = by ?? song.updatedBy;
    final existing = songs[song.id];
    final revision = ++_serverRevision;
    final stored = RemoteSong(
      id: song.id,
      organizationId: song.organizationId,
      title: song.title,
      chordpro: song.chordpro,
      revision: revision,
      deleted: song.deleted,
      deletedAt: song.deleted ? song.deletedAt ?? DateTime.now() : null,
      purged: song.purged,
      createdBy: existing?.createdBy ?? song.createdBy ?? editor,
      updatedBy: editor,
      workId: existing == null ? song.workId : existing.workId,
      language: existing == null ? song.language : existing.language,
      contentRevision: revision,
      created: existing?.created ?? song.created ?? DateTime.now(),
      // The review status (ADR-0060) like the link fields.
      reviewState: existing == null ? song.reviewState : existing.reviewState,
      reviewReason: existing == null
          ? song.reviewReason
          : existing.reviewReason,
      reviewedBy: existing == null
          ? (song.reviewState == null ? null : song.reviewedBy ?? editor)
          : existing.reviewedBy,
      reviewedAt: existing == null
          ? (song.reviewState == null ? null : DateTime.now())
          : existing.reviewedAt,
    );
    songs[song.id] = stored;
    return stored;
  }

  /// Sets a link field of a song (ADR-0053), as the server does for
  /// [pushSongLink] or a change by someone else: last writer wins, the
  /// content revision and the last editor stay.
  RemoteSong putSongLink(String songId, SongLinkField field, String? value) {
    final s = songs[songId]!;
    final stored = RemoteSong(
      id: s.id,
      organizationId: s.organizationId,
      title: s.title,
      chordpro: s.chordpro,
      revision: ++_serverRevision,
      deleted: s.deleted,
      deletedAt: s.deletedAt,
      purged: s.purged,
      createdBy: s.createdBy,
      updatedBy: s.updatedBy,
      workId: field == SongLinkField.workId ? value : s.workId,
      language: field == SongLinkField.language ? value : s.language,
      contentRevision: s.effectiveContentRevision,
      created: s.created,
      reviewState: s.reviewState,
      reviewReason: s.reviewReason,
      reviewedBy: s.reviewedBy,
      reviewedAt: s.reviewedAt,
    );
    songs[songId] = stored;
    return stored;
  }

  /// Sets the review status of a song (ADR-0060), as the server does for
  /// [pushSongReview] or a change by [by]: last writer wins, the content
  /// revision and the last editor stay; an approved song has no reason.
  RemoteSong putSongReview(
    String songId,
    String? state,
    String? reason, {
    String? by,
  }) {
    final s = songs[songId]!;
    final stored = RemoteSong(
      id: s.id,
      organizationId: s.organizationId,
      title: s.title,
      chordpro: s.chordpro,
      revision: ++_serverRevision,
      deleted: s.deleted,
      deletedAt: s.deletedAt,
      purged: s.purged,
      createdBy: s.createdBy,
      updatedBy: s.updatedBy,
      workId: s.workId,
      language: s.language,
      contentRevision: s.effectiveContentRevision,
      created: s.created,
      reviewState: state,
      reviewReason: state == null ? null : reason,
      reviewedBy: by ?? user?.id,
      reviewedAt: DateTime.now(),
    );
    songs[songId] = stored;
    return stored;
  }

  /// Review states pushed with [pushSongReview], in order.
  final songReviewPushes = <(String, String?, String?)>[];

  @override
  Future<RemoteSong> pushSongReview(
    String songId,
    String? state,
    String? reason,
  ) async {
    _requireUser();
    pushCount++;
    if (!songs.containsKey(songId) || refuseReview) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    songReviewPushes.add((songId, state, reason));
    return putSongReview(songId, state, reason);
  }

  /// Refuses every review change, as for a person who may not approve.
  bool refuseReview = false;

  /// Server state: mistake reports by ID (ADR-0060) and screenshot files.
  final reports = <String, RemoteSongReport>{};
  final screenshots = <String, List<int>>{};

  /// Refuses every update of a report, as for a person who may not.
  bool refuseReportUpdates = false;

  /// Simulates a change of a report (by someone else, or the server's
  /// answer to a push).
  RemoteSongReport putReport(RemoteSongReport r, {List<int>? screenshot}) {
    final existing = reports[r.id];
    final file =
        existing?.screenshot ??
        r.screenshot ??
        (screenshot == null ? null : '${r.id}_shot.webp');
    if (screenshot != null && file != null) screenshots[file] = screenshot;
    final stored = RemoteSongReport(
      id: r.id,
      songId: r.songId,
      organizationId: r.organizationId,
      authorId: existing?.authorId ?? r.authorId ?? user?.id,
      category: r.category,
      comment: r.comment,
      location: r.location,
      screenshot: file,
      status: r.status,
      resolution: r.resolution,
      resolvedBy: r.status == 'resolved'
          ? (r.resolvedBy ?? existing?.resolvedBy ?? user?.id)
          : null,
      resolvedAt: r.status == 'resolved'
          ? (r.resolvedAt ?? existing?.resolvedAt ?? DateTime.now())
          : null,
      created: existing?.created ?? r.created ?? DateTime.now(),
      revision: ++_serverRevision,
      deleted: r.deleted,
      purged: r.purged,
    );
    reports[r.id] = stored;
    return stored;
  }

  /// Reports pushed with [pushSongReport]: (report, create, asAuthor,
  /// asApprover, screenshot uploaded).
  final reportPushes = <(RemoteSongReport, bool, bool, bool, bool)>[];

  /// The `since` of each [pullSongReports] call.
  final reportPullsSince = <int>[];

  /// Whether the signed-in user reads every report of [orgId], like the
  /// server's list rule (ADR-0060): librarians, organization admins, and
  /// leaders and set planners of one of its bands; others only their own.
  bool _seesAllReports(String orgId) =>
      orgMembers.any(
        (m) =>
            m.scopeId == orgId &&
            m.user.id == user!.id &&
            m.role != OrgRole.member,
      ) ||
      members.any(
        (m) =>
            m.user.id == user!.id &&
            (m.role == BandRole.admin || m.role == BandRole.planner) &&
            bands[m.scopeId]?.organizationId == orgId &&
            bands[m.scopeId]?.deletedAt == null,
      );

  @override
  Future<List<RemoteSongReport>> pullSongReports(
    String organizationId,
    int since,
  ) async {
    _requireUser();
    reportPullsSince.add(since);
    final uid = user!.id;
    if (!orgMembers.any(
      (m) => m.scopeId == organizationId && m.user.id == uid,
    )) {
      return const [];
    }
    final all = _seesAllReports(organizationId);
    return reports.values
        .where(
          (r) =>
              r.organizationId == organizationId &&
              r.revision > since &&
              (all || r.authorId == uid),
        )
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  @override
  Future<RemoteSongReport> pushSongReport(
    RemoteSongReport report, {
    required bool create,
    bool asAuthor = true,
    bool asApprover = false,
    List<int>? screenshot,
    String? screenshotName,
  }) async {
    _requireUser();
    pushCount++;
    reportPushes.add((
      report,
      create,
      asAuthor,
      asApprover,
      screenshot != null,
    ));
    if (!songs.containsKey(report.songId)) {
      throw const BackendException(BackendErrorKind.server);
    }
    final existing = reports[report.id];
    if (create) return putReport(report, screenshot: screenshot);
    if (existing == null || refuseReportUpdates) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putReport(
      RemoteSongReport(
        id: report.id,
        songId: existing.songId,
        organizationId: existing.organizationId,
        authorId: existing.authorId,
        category: asAuthor ? report.category : existing.category,
        comment: asAuthor ? report.comment : existing.comment,
        location: asAuthor ? report.location : existing.location,
        status: report.status,
        resolution: asApprover ? report.resolution : existing.resolution,
        resolvedBy: report.status == 'resolved' ? user?.id : null,
      ),
      screenshot: existing.screenshot == null ? screenshot : null,
    );
  }

  @override
  Future<Uint8List> fetchReportScreenshot(String reportId, String file) async {
    _requireUser();
    final bytes = screenshots[file];
    if (bytes == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return Uint8List.fromList(bytes);
  }

  /// Link fields pushed with [pushSongLink], in order.
  final songLinkPushes = <(String, SongLinkField, String?)>[];

  /// Personal adjustments by record ID (ADR-0020).
  final overlays = <String, RemoteOverlay>{};

  /// Simulates a change on another device of [overlay]'s user.
  RemoteOverlay putOverlay(RemoteOverlay overlay) {
    final stored = RemoteOverlay(
      id: overlay.id,
      userId: overlay.userId,
      songId: overlay.songId,
      data: overlay.data,
      midi: overlay.midi,
      midiPrograms: overlay.midiPrograms,
      revision: ++_serverRevision,
      deleted: overlay.deleted,
    );
    overlays[overlay.id] = stored;
    return stored;
  }

  /// Freehand annotations by record ID (ADR-0032).
  final annotations = <String, RemoteAnnotations>{};

  /// Simulates a change on another device of [a]'s user: the strokes of
  /// [a] are merged into the stored ones by stroke ID, as on the server.
  RemoteAnnotations putAnnotations(RemoteAnnotations a, {bool? deleted}) {
    final existing = annotations[a.id];
    final stored = RemoteAnnotations(
      id: a.id,
      userId: a.userId,
      songId: a.songId,
      attachmentId: a.attachmentId,
      data: {...?existing?.data, ...a.data},
      revision: ++_serverRevision,
      deleted: deleted ?? existing?.deleted ?? a.deleted,
    );
    annotations[a.id] = stored;
    return stored;
  }

  /// Band arrangements by record ID (ADR-0025).
  final arrangements = <String, RemoteArrangement>{};

  /// Simulates a change of an arrangement on another device; [by] (or
  /// [RemoteArrangement.updatedBy]) is recorded as the last editor, as the
  /// server does.
  RemoteArrangement putArrangement(RemoteArrangement a, {String? by}) {
    final stored = RemoteArrangement(
      id: a.id,
      bandId: a.bandId,
      songId: a.songId,
      transpose: a.transpose,
      sequence: a.sequence,
      tempo: a.tempo,
      revision: ++_serverRevision,
      deleted: a.deleted,
      updatedBy: by ?? a.updatedBy,
    );
    arrangements[a.id] = stored;
    return stored;
  }

  @override
  Future<List<RemoteArrangement>> pullArrangements(
    String bandId,
    int since,
  ) async {
    _requireUser();
    return arrangements.values
        .where((a) => a.bandId == bandId && a.revision > since)
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  @override
  Future<RemoteArrangement> pushArrangement(
    RemoteArrangement arrangement, {
    required bool create,
  }) async {
    _requireUser();
    pushCount++;
    final manager =
        _isOrgAdmin(bands[arrangement.bandId]?.organizationId ?? '') ||
        members.any(
          (m) =>
              m.scopeId == arrangement.bandId &&
              m.user.id == user!.id &&
              m.role != BandRole.member,
        );
    if (!manager || songs[arrangement.songId] == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final existing = arrangements[arrangement.id];
    if (create && existing != null) {
      throw const BackendException(BackendErrorKind.server);
    }
    return putArrangement(arrangement, by: user!.id);
  }

  /// Personal settings by user ID (ADR-0027).
  final userSettings = <String, RemoteUserSettings>{};

  /// Simulates a change on another device of the user: merges [data] into
  /// the stored settings, as the server does.
  RemoteUserSettings putUserSettings(String userId, Map<String, dynamic> data) {
    final stored = RemoteUserSettings(
      id: userSettings[userId]?.id ?? 'settings-$userId',
      userId: userId,
      data: {...?userSettings[userId]?.data, ...data},
      revision: ++_serverRevision,
    );
    userSettings[userId] = stored;
    return stored;
  }

  @override
  Future<RemoteUserSettings?> pullUserSettings(int since) async {
    _requireUser();
    final s = userSettings[user!.id];
    return s != null && s.revision > since ? s : null;
  }

  @override
  Future<RemoteUserSettings> pushUserSettings(
    RemoteUserSettings settings, {
    required bool create,
  }) async {
    _requireUser();
    pushCount++;
    if (settings.userId != user!.id) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final existing = userSettings[settings.userId];
    if (create && existing != null) {
      throw const BackendException(BackendErrorKind.server);
    }
    if (!create && existing == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putUserSettings(settings.userId, settings.data);
  }

  @override
  Future<List<RemoteAnnotations>> pullAnnotations(int since) async {
    _requireUser();
    return annotations.values
        .where((a) => a.userId == user!.id && a.revision > since)
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  @override
  Future<RemoteAnnotations> pushAnnotations(
    RemoteAnnotations a, {
    required bool create,
  }) async {
    _requireUser();
    pushCount++;
    final song = songs[a.songId];
    if (a.userId != user!.id ||
        song == null ||
        !orgMembers.any(
          (m) => m.scopeId == song.organizationId && m.user.id == user!.id,
        )) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final existing = annotations[a.id];
    if (create && existing != null) {
      throw const BackendException(BackendErrorKind.server);
    }
    if (!create && existing == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putAnnotations(a);
  }

  @override
  Future<List<RemoteOverlay>> pullOverlays(int since) async {
    _requireUser();
    return overlays.values
        .where((o) => o.userId == user!.id && o.revision > since)
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  @override
  Future<RemoteOverlay> pushOverlay(
    RemoteOverlay overlay, {
    required bool create,
  }) async {
    _requireUser();
    pushCount++;
    final song = songs[overlay.songId];
    if (overlay.userId != user!.id ||
        song == null ||
        !orgMembers.any(
          (m) => m.scopeId == song.organizationId && m.user.id == user!.id,
        )) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final existing = overlays[overlay.id];
    if (create && existing != null) {
      throw const BackendException(BackendErrorKind.server);
    }
    if (!create && existing == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putOverlay(overlay);
  }

  /// Simulates a change of a set; [by] (or [RemoteSet.updatedBy]) is
  /// recorded as the last editor, as the server does.
  RemoteSet putSet(RemoteSet set, {String? by}) {
    final stored = RemoteSet(
      id: set.id,
      bandId: set.bandId,
      name: set.name,
      gigDate: set.gigDate,
      venue: set.venue,
      origin: set.origin ?? sets[set.id]?.origin,
      items: set.items,
      revision: ++_serverRevision,
      deleted: set.deleted,
      deletedAt: set.deleted ? set.deletedAt ?? DateTime.now() : null,
      purged: set.purged,
      updatedBy: by ?? set.updatedBy,
      lineup: set.lineupCustom ? set.lineup : const [],
      lineupContacts: set.lineupCustom ? set.lineupContacts : const [],
      lineupCustom: set.lineupCustom,
    );
    sets[set.id] = stored;
    return stored;
  }

  /// Server state: people without an account by ID (ADR-0064).
  final contacts = <String, RemoteContact>{};

  /// Simulates a change of a contact by someone else; a deleted contact
  /// loses its mail address, as on the server.
  RemoteContact putContact(RemoteContact c, {String? by}) {
    final existing = contacts[c.id];
    final stored = RemoteContact(
      id: c.id,
      organizationId: c.organizationId,
      firstName: c.firstName,
      lastName: c.lastName,
      nickname: c.nickname,
      email: c.deleted ? null : c.email,
      linkedUserId: c.linkedUserId ?? existing?.linkedUserId,
      createdBy: existing?.createdBy ?? by ?? c.createdBy,
      revision: ++_serverRevision,
      deleted: c.deleted,
    );
    contacts[c.id] = stored;
    return stored;
  }

  /// Whether the user may edit sets in some band of [orgId] (ADR-0064).
  bool _editsContacts(String orgId) =>
      _isOrgAdmin(orgId) ||
      members.any(
        (m) =>
            m.user.id == user?.id &&
            (m.role == BandRole.admin || m.role == BandRole.planner) &&
            bands[m.scopeId]?.organizationId == orgId,
      );

  /// Contacts pushed with [pushContact]: (contact, create).
  final contactPushes = <(RemoteContact, bool)>[];

  /// Set to answer [pullContacts] like a server without contacts.
  bool contactsFail = false;

  /// Like the server: the contacts of an organization the user is in, the
  /// mail addresses only for set editors.
  @override
  Future<List<RemoteContact>> pullContacts(
    String organizationId,
    int since,
  ) async {
    _requireUser();
    if (contactsFail) throw const BackendException(BackendErrorKind.notAllowed);
    final inOrg = orgMembers.any(
      (m) => m.scopeId == organizationId && m.user.id == user!.id,
    );
    if (!inOrg) return const [];
    final mail = _editsContacts(organizationId);
    return contacts.values
        .where((c) => c.organizationId == organizationId && c.revision > since)
        .map(
          (c) => RemoteContact(
            id: c.id,
            organizationId: c.organizationId,
            firstName: c.firstName,
            lastName: c.lastName,
            nickname: c.nickname,
            email: mail ? c.email : null,
            linkedUserId: c.linkedUserId,
            createdBy: c.createdBy,
            revision: c.revision,
            deleted: c.deleted,
          ),
        )
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  /// Like the server: set editors create and edit, organization admins
  /// delete; a deleted contact is not changed any more.
  @override
  Future<RemoteContact> pushContact(
    RemoteContact contact, {
    required bool create,
  }) async {
    _requireUser();
    _check();
    contactPushes.add((contact, create));
    final existing = contacts[contact.id];
    if (!_editsContacts(contact.organizationId) ||
        (!create && (existing == null || existing.deleted)) ||
        (contact.deleted && !_isOrgAdmin(contact.organizationId))) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putContact(contact, by: user!.id);
  }

  /// Like the server (ADR-0061): the lineup's addresses for who may edit
  /// the set; [lineupEmailsFail] answers like a server that is not reached.
  bool lineupEmailsFail = false;

  @override
  Future<List<({String name, String email})>> fetchLineupEmails(
    String setId,
  ) async {
    _requireUser();
    if (lineupEmailsFail) {
      throw const BackendException(BackendErrorKind.network);
    }
    final set = sets[setId];
    if (set == null || set.deleted || !_canManageBand(set.bandId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final ids = set.lineupCustom
        ? set.lineup
        : [
            for (final m in members)
              if (m.scopeId == set.bandId) m.user.id,
          ];
    final people = {
      for (final m in orgMembers) m.user.id: m.user,
      for (final m in members) m.user.id: m.user,
    };
    return [
      for (final id in ids)
        if (people[id] case final user?) (name: user.name, email: user.email),
      if (set.lineupCustom)
        for (final id in set.lineupContacts)
          if (contacts[id] case final c? when c.email != null && !c.deleted)
            (name: c.firstName, email: c.email!),
    ];
  }

  /// Number of [fetchLineup] calls; set [lineupFail] to answer them like a
  /// server without the route.
  int fetchLineupCalls = 0;
  bool lineupFail = false;

  /// Like the server (ADR-0061): the sets with a lineup of their own that
  /// contains the user, in bands they are no member of and whose
  /// organization they do not administrate, while they are in it.
  @override
  Future<RemoteLineup> fetchLineup() async {
    _requireUser();
    fetchLineupCalls++;
    if (lineupFail) throw const BackendException(BackendErrorKind.server);
    final me = user!.id;
    final result = <RemoteSet>[];
    final bandIds = <String>{};
    for (final s in sets.values) {
      final band = bands[s.bandId];
      if (s.deleted || band == null || band.deletedAt != null) continue;
      if (closedOrganizations.containsKey(band.organizationId)) continue;
      if (!s.lineupCustom || !s.lineup.contains(me)) continue;
      if (members.any((m) => m.scopeId == s.bandId && m.user.id == me)) {
        continue;
      }
      final inOrg = orgMembers.where(
        (m) => m.scopeId == band.organizationId && m.user.id == me,
      );
      if (inOrg.isEmpty || inOrg.any((m) => m.role == OrgRole.admin)) continue;
      result.add(s);
      bandIds.add(s.bandId);
    }
    final songs = {
      for (final s in result)
        for (final i in s.items) ?i.songId,
    };
    return RemoteLineup(
      sets: result,
      bands: [
        for (final id in bandIds)
          (
            id: id,
            name: bands[id]!.name,
            organizationId: bands[id]!.organizationId,
          ),
      ],
      arrangements: [
        for (final a in arrangements.values)
          if (bandIds.contains(a.bandId) &&
              !a.deleted &&
              songs.contains(a.songId))
            a,
      ],
    );
  }

  @override
  Future<List<RemoteSong>> pullSongs(String organizationId, int since) async {
    _requireUser();
    return songs.values
        .where((s) => s.organizationId == organizationId && s.revision > since)
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  @override
  Future<List<RemoteSet>> pullSets(String bandId, int since) async {
    _requireUser();
    return sets.values
        .where((s) => s.bandId == bandId && s.revision > since)
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  @override
  Future<RemoteSong?> fetchSong(String id) async {
    _requireUser();
    return songs[id];
  }

  @override
  Future<RemoteSong> pushSong(RemoteSong song, {required bool create}) async {
    _requireUser();
    pushCount++;
    final existing = songs[song.id];
    if (create && existing != null) {
      throw const BackendException(BackendErrorKind.server);
    }
    if (!create) {
      if (existing == null) {
        throw const BackendException(BackendErrorKind.notAllowed);
      }
      if (existing.effectiveContentRevision > song.revision) {
        throw const BackendException(BackendErrorKind.conflict);
      }
    }
    return putSong(song);
  }

  @override
  Future<RemoteSong> pushSongLink(
    String songId,
    SongLinkField field,
    String? value,
  ) async {
    _requireUser();
    pushCount++;
    if (!songs.containsKey(songId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    songLinkPushes.add((songId, field, value));
    return putSongLink(songId, field, value);
  }

  @override
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create}) async {
    _requireUser();
    pushCount++;
    if (!bands.containsKey(set.bandId) || !_canManageBand(set.bandId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (create && sets.containsKey(set.id)) {
      throw const BackendException(BackendErrorKind.server);
    }
    if (!create && !sets.containsKey(set.id)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putSet(set, by: user!.id);
  }

  /// Server state: attachments by ID and their files.
  final attachments = <String, RemoteAttachment>{};
  final files = <String, List<int>>{};

  /// Simulates a change of an attachment; [by] (or
  /// [RemoteAttachment.updatedBy]) is recorded as the last editor.
  RemoteAttachment putAttachment(
    RemoteAttachment a, {
    List<int>? bytes,
    String? by,
  }) {
    final stored = RemoteAttachment(
      id: a.id,
      organizationId: a.organizationId,
      songId: a.songId,
      name: a.name,
      file: a.file ?? attachments[a.id]?.file ?? '${a.id}_abc.pdf',
      pages: a.pages,
      sizeBytes: a.sizeBytes,
      revision: ++_serverRevision,
      deleted: a.deleted,
      deletedAt: a.deleted ? a.deletedAt ?? DateTime.now() : null,
      purged: a.purged,
      updatedBy: by ?? a.updatedBy,
    );
    attachments[a.id] = stored;
    if (bytes != null) files[stored.file!] = bytes;
    return stored;
  }

  @override
  Future<List<RemoteAttachment>> pullAttachments(
    String organizationId,
    int since,
  ) async {
    _requireUser();
    return attachments.values
        .where((a) => a.organizationId == organizationId && a.revision > since)
        .toList()
      ..sort((a, b) => a.revision.compareTo(b.revision));
  }

  /// When set, uploads of new attachments fail with it, e.g. a refusal
  /// (#1225) or a server error.
  BackendException? attachmentUploadError;

  /// Uploads of new attachments, also refused ones.
  int attachmentUploads = 0;

  @override
  Future<RemoteAttachment> pushAttachment(
    RemoteAttachment attachment, {
    required bool create,
    List<int>? bytes,
  }) async {
    _requireUser();
    pushCount++;
    if (create) attachmentUploads++;
    if (!songs.containsKey(attachment.songId)) {
      // The song relation fails the validation, as on the server.
      throw const BackendException(BackendErrorKind.server, null, 400);
    }
    if (create) {
      if (attachmentUploadError case final e?) throw e;
      if (bytes == null || bytes.length > 1024 * 1024) {
        throw const BackendException(BackendErrorKind.server, {
          'data': {
            'file': {'code': 'validation_file_size_limit'},
          },
        }, 400);
      }
      // The storage limit of the organization (ADR-0070).
      final limit = storageLimitBytes;
      if (limit != null &&
          _usage(attachment.organizationId).$1 + bytes.length > limit) {
        throw const BackendException(BackendErrorKind.server, {
          'data': {
            'file': {'code': 'storage_limit_reached'},
          },
        }, 400);
      }
      // The server sets the size from the file.
      attachment = RemoteAttachment(
        id: attachment.id,
        organizationId: attachment.organizationId,
        songId: attachment.songId,
        name: attachment.name,
        file: attachment.file,
        pages: attachment.pages,
        sizeBytes: bytes.length,
        revision: attachment.revision,
        deleted: attachment.deleted,
        deletedAt: attachment.deletedAt,
        purged: attachment.purged,
        updatedBy: attachment.updatedBy,
      );
      return putAttachment(attachment, bytes: bytes);
    }
    final existing = attachments[attachment.id];
    if (existing == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    return putAttachment(
      RemoteAttachment(
        id: attachment.id,
        organizationId: existing.organizationId,
        songId: existing.songId,
        name: attachment.name,
        file: existing.file,
        pages: existing.pages,
        sizeBytes: existing.sizeBytes,
        deleted: attachment.deleted,
        deletedAt: attachment.deletedAt,
        // As the server: only a deleted attachment is purged, by those who
        // may delete it (ADR-0070); a purge cannot be undone.
        purged:
            existing.purged ||
            (attachment.purged &&
                attachment.deleted &&
                _mayDeleteSongs(existing.organizationId)),
      ),
    );
  }

  bool _mayDeleteSongs(String orgId) => orgMembers.any(
    (m) =>
        m.scopeId == orgId &&
        m.user.id == user?.id &&
        (m.role == OrgRole.admin || m.role == OrgRole.librarian),
  );

  int downloads = 0;

  /// Download sessions opened and closed.
  int downloadsOpened = 0;
  int downloadsClosed = 0;

  /// Server files whose download fails with a network error.
  final offlineFiles = <String>{};

  /// When set, downloads of the other files wait for it; it completes on
  /// the next turn of the event loop after a download of [offlineFiles]
  /// failed, so the connection breaks while the other downloads are still
  /// running (#935).
  Completer<void>? downloadGate;

  @override
  AttachmentDownloads openDownloads() {
    downloadsOpened++;
    return _FakeDownloads(this);
  }

  @override
  Stream<String> watchChanges() => changes.stream;

  @override
  void dispose() => changes.close();
}

class FakeInvite {
  FakeInvite(
    this.id,
    this.organizationId,
    this.token,
    this.created,
    this.expires,
  );

  final String id;
  final String organizationId;
  final String token;
  final DateTime created;
  DateTime expires;
  bool revoked = false;

  /// Name of the organization a founder invitation creates (ADR-0024).
  String? founder;

  /// The band the link also leads into (ADR-0023).
  String? bandId;

  /// The person without an account of a personal invitation (ADR-0064).
  String? contactId;

  /// Whether the server kept the token, so the link can be shown again
  /// (issue #579).
  bool stored = true;
  AuthUser? usedBy;
  final joined = <AuthUser>[];
}

class FakeBand {
  FakeBand(this.organizationId, this.name);

  final String organizationId;
  String name;

  /// Months after which a song counts as not played for a while (ADR-0046).
  int staleAfterMonths = 0;

  /// When the band was deleted (ADR-0044), or null.
  DateTime? deletedAt;
}

/// A membership in an organization or a band ([scopeId]).
class FakeMember<R extends Enum> {
  FakeMember(this.id, this.scopeId, this.user, this.role);

  final String id;
  final String scopeId;
  final AuthUser user;
  R role;
}

class _FakeDownloads implements AttachmentDownloads {
  _FakeDownloads(this._server);

  final FakeSyncBackend _server;

  @override
  Future<void> download(
    RemoteAttachment attachment,
    StreamSink<List<int>> target,
  ) async {
    _server._requireUser();
    _server.downloads++;
    final gate = _server.downloadGate;
    if (_server.offlineFiles.contains(attachment.file)) {
      // Part of the file arrived before the connection broke.
      target.add([1, 2]);
      if (gate != null && !gate.isCompleted) Timer.run(gate.complete);
      throw const BackendException(BackendErrorKind.network);
    }
    await gate?.future;
    final bytes = _server.files[attachment.file];
    if (bytes == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    target.add(bytes);
  }

  @override
  void close() => _server.downloadsClosed++;
}
