import 'dart:io';
import 'dart:async';

import 'package:realchord/sync/sync_backend.dart';

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
    final u = AuthUser(id: 'u-$email', email: email.trim(), name: '');
    _set(u);
    return u;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _check();
    if (accounts.containsKey(email.trim())) {
      throw const BackendException(BackendErrorKind.emailTaken);
    }
    accounts[email.trim()] = password;
    final u = AuthUser(id: 'u-$email', email: email.trim(), name: name.trim());
    _set(u);
    return u;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    _check();
    resetRequests.add(email);
  }

  @override
  Future<void> refreshSession() async => refreshCount++;

  @override
  Future<void> signOut() async => _set(null);

  // Organizations and bands ----------------------------------------------------

  /// Organizations on the "server": id → name.
  final organizations = <String, String>{};

  /// People of organizations on the "server".
  final orgMembers = <FakeMember>[];

  /// Bands on the "server".
  final bands = <String, FakeBand>{};

  /// Band memberships on the "server".
  final members = <FakeMember>[];
  int _ids = 0;

  /// Adds an organization with [admin], e.g. to start a test inside one.
  void addOrganization(String id, String name, {required AuthUser admin}) {
    organizations[id] = name;
    addOrgMember(id, admin, BandRole.admin);
  }

  FakeMember addOrgMember(String orgId, AuthUser user, BandRole role) {
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
    bool membersCanEditSongs = false,
  }) {
    final orgId = organizationId ?? 'org-$id';
    if (!organizations.containsKey(orgId)) {
      addOrganization(orgId, name, admin: admin);
    }
    bands[id] = FakeBand(orgId, name, membersCanEditSongs);
    addMember(id, admin, BandRole.admin);
  }

  FakeMember addMember(String bandId, AuthUser user, BandRole role) {
    final orgId = bands[bandId]!.organizationId;
    if (!orgMembers.any((m) => m.scopeId == orgId && m.user.id == user.id)) {
      addOrgMember(orgId, user, BandRole.member);
    }
    final m = FakeMember('m${++_ids}', bandId, user, role);
    members.add(m);
    return m;
  }

  bool _isOrgAdmin(String orgId) => orgMembers.any(
    (m) =>
        m.scopeId == orgId && m.user.id == user?.id && m.role == BandRole.admin,
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

  RemoteMember _remote(FakeMember m) => RemoteMember(
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
        if (orgMembers.any((m) => m.scopeId == o.key && m.user.id == user!.id))
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
                    (_isOrgAdmin(o.key) ||
                        members.any(
                          (m) => m.scopeId == b.key && m.user.id == user!.id,
                        )))
                  RemoteBand(
                    id: b.key,
                    organizationId: o.key,
                    name: b.value.name,
                    membersCanEditSongs: b.value.membersCanEditSongs,
                    revision: 1,
                    members: [
                      for (final m in members)
                        if (m.scopeId == b.key) _remote(m),
                    ],
                  ),
            ],
          ),
    ];
  }

  void _keepAdmin(List<FakeMember> list, FakeMember m) {
    final others = list.where(
      (o) => o.scopeId == m.scopeId && o != m && o.role == BandRole.admin,
    );
    if (m.role == BandRole.admin && others.isEmpty) {
      throw const BackendException(BackendErrorKind.lastAdmin);
    }
  }

  FakeMember _find(List<FakeMember> list, String id) {
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
  Future<void> setOrgMemberRole(String orgMembershipId, BandRole role) async {
    _requireUser();
    final m = _find(orgMembers, orgMembershipId);
    if (!_isOrgAdmin(m.scopeId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (role == BandRole.member) _keepAdmin(orgMembers, m);
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
    addBand(id, name.trim(), admin: user!, organizationId: organizationId);
  }

  @override
  Future<void> updateBand(
    String bandId, {
    String? name,
    bool? membersCanEditSongs,
  }) async {
    _requireUser();
    final band = bands[bandId];
    if (band == null || !_canManageBand(bandId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    if (name != null) band.name = name.trim();
    if (membersCanEditSongs != null) {
      band.membersCanEditSongs = membersCanEditSongs;
    }
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
      : (i.expires.isBefore(now) ? InviteStatus.expired : InviteStatus.valid);

  @override
  Future<CreatedInvite> createInvite(String organizationId) async {
    _requireUser();
    if (!_isOrgAdmin(organizationId)) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    final token = 'Tok${++_ids}'.padRight(32, 'x');
    final invite = FakeInvite(
      'inv$_ids',
      organizationId,
      token,
      now,
      now.add(const Duration(days: 7)),
    );
    invites.add(invite);
    return CreatedInvite(
      id: invite.id,
      url: 'https://api.realchord.app/invite/$token',
      expires: invite.expires,
    );
  }

  @override
  Future<List<InviteInfo>> fetchInvites(String organizationId) async {
    _requireUser();
    return [
      for (final i in invites.reversed)
        if (i.organizationId == organizationId)
          InviteInfo(
            id: i.id,
            created: i.created,
            expires: i.expires,
            revoked: i.revoked,
            joined: [for (final u in i.joined) u.displayName],
          ),
    ];
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    _requireUser();
    invites.firstWhere((i) => i.id == inviteId).revoked = true;
  }

  @override
  Future<InvitePreview> previewInvite(String token) async {
    _requireUser();
    final invite = _invite(token);
    if (invite == null) {
      throw const BackendException(BackendErrorKind.inviteUnknown);
    }
    return InvitePreview(
      organizationId: invite.organizationId,
      organizationName: organizations[invite.organizationId]!,
      status: _inviteStatus(invite),
      alreadyMember: orgMembers.any(
        (m) => m.scopeId == invite.organizationId && m.user.id == user!.id,
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
      case InviteStatus.valid:
    }
    final orgId = invite.organizationId;
    if (!orgMembers.any((m) => m.scopeId == orgId && m.user.id == user!.id)) {
      addOrgMember(orgId, user!, BandRole.member);
      invite.joined.add(user!);
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
  RemoteSong putSong(RemoteSong song) {
    final stored = RemoteSong(
      id: song.id,
      organizationId: song.organizationId,
      title: song.title,
      chordpro: song.chordpro,
      revision: ++_serverRevision,
      deleted: song.deleted,
    );
    songs[song.id] = stored;
    return stored;
  }

  RemoteSet putSet(RemoteSet set) {
    final stored = RemoteSet(
      id: set.id,
      bandId: set.bandId,
      name: set.name,
      gigDate: set.gigDate,
      venue: set.venue,
      items: set.items,
      revision: ++_serverRevision,
      deleted: set.deleted,
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
    return putSet(set);
  }

  /// Server state: attachments by ID and their files.
  final attachments = <String, RemoteAttachment>{};
  final files = <String, List<int>>{};

  RemoteAttachment putAttachment(RemoteAttachment a, {List<int>? bytes}) {
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
  void dispose() {}
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
  final DateTime expires;
  bool revoked = false;
  final joined = <AuthUser>[];
}

class FakeBand {
  FakeBand(this.organizationId, this.name, this.membersCanEditSongs);

  final String organizationId;
  String name;
  bool membersCanEditSongs;
}

/// A membership in an organization or a band ([scopeId]).
class FakeMember {
  FakeMember(this.id, this.scopeId, this.user, this.role);

  final String id;
  final String scopeId;
  final AuthUser user;
  BandRole role;
}

class _FakeDownloads implements AttachmentDownloads {
  _FakeDownloads(this._server);

  final FakeSyncBackend _server;

  @override
  Future<void> download(RemoteAttachment attachment, File target) async {
    _server._requireUser();
    _server.downloads++;
    if (_server.offlineFiles.contains(attachment.file)) {
      // Part of the file arrived before the connection broke.
      await target.writeAsBytes([1, 2]);
      throw const BackendException(BackendErrorKind.network);
    }
    final bytes = _server.files[attachment.file];
    if (bytes == null) {
      throw const BackendException(BackendErrorKind.notAllowed);
    }
    await target.writeAsBytes(bytes);
  }

  @override
  void close() => _server.downloadsClosed++;
}
