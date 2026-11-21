import 'dart:async';

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

  /// Registration settings reported by [fetchServerConfig] (ADR-0024).
  ServerConfig config = ServerConfig.unknown;

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
    required String name,
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
    final u = AuthUser(id: 'u-$email', email: email.trim(), name: name.trim());
    _set(u);
    return u;
  }

  @override
  Future<AuthUser> changeName(String name) async {
    _check();
    final u = user;
    if (u == null) throw const BackendException(BackendErrorKind.signedOut);
    final changed = AuthUser(id: u.id, email: u.email, name: name.trim());
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
      : (i.founder != null && i.usedBy != null)
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
  }) async {
    _requireUser();
    final allowed =
        _isOrgAdmin(organizationId) ||
        (bandId != null && _canManageBand(bandId));
    if (!allowed) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final token = 'Tok${++_ids}'.padRight(32, 'x');
    final invite = FakeInvite(
      'inv$_ids',
      organizationId,
      token,
      now,
      now.add(const Duration(days: 7)),
    )..bandId = bandId;
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
  RemoteSong putSong(RemoteSong song, {String? by}) {
    final editor = by ?? song.updatedBy;
    final stored = RemoteSong(
      id: song.id,
      organizationId: song.organizationId,
      title: song.title,
      chordpro: song.chordpro,
      revision: ++_serverRevision,
      deleted: song.deleted,
      deletedAt: song.deleted ? song.deletedAt ?? DateTime.now() : null,
      purged: song.purged,
      createdBy: songs[song.id]?.createdBy ?? song.createdBy ?? editor,
      updatedBy: editor,
    );
    songs[song.id] = stored;
    return stored;
  }

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
    );
    sets[set.id] = stored;
    return stored;
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
      if (existing.revision != song.revision) {
        throw const BackendException(BackendErrorKind.conflict);
      }
    }
    return putSong(song);
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

  @override
  Future<RemoteAttachment> pushAttachment(
    RemoteAttachment attachment, {
    required bool create,
    List<int>? bytes,
  }) async {
    _requireUser();
    pushCount++;
    if (!songs.containsKey(attachment.songId)) {
      throw const BackendException(BackendErrorKind.server);
    }
    if (create) {
      if (bytes == null || bytes.length > 20 * 1024 * 1024) {
        throw const BackendException(BackendErrorKind.server);
      }
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
      ),
    );
  }

  int downloads = 0;

  /// Download sessions opened and closed.
  int downloadsOpened = 0;
  int downloadsClosed = 0;

  /// Server files whose download fails with a network error.
  final offlineFiles = <String>{};

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
    if (_server.offlineFiles.contains(attachment.file)) {
      // Part of the file arrived before the connection broke.
      target.add([1, 2]);
      throw const BackendException(BackendErrorKind.network);
    }
    final bytes = _server.files[attachment.file];
    if (bytes == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    target.add(bytes);
  }

  @override
  void close() => _server.downloadsClosed++;
}
