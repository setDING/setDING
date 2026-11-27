import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pocketbase/pocketbase.dart';

import '../midi/midi_message.dart';
import '../platform/http_client.dart';
import '../platform/network_error.dart';
import 'session_store.dart';
import 'sync_backend.dart';
import '../util/log.dart';

const _log = Log('backend');

/// [SyncBackend] on PocketBase (ADR-0004, ADR-0015).
class PocketBaseBackend implements SyncBackend {
  PocketBaseBackend({
    required this.serverUrl,
    required SessionStore store,
    http.Client Function()? httpClientFactory,
    this.rateLimitBackoff = defaultRateLimitBackoff,
    this.clientVersion,
  }) : _store = store,
       _httpClientFactory = _versioned(
         httpClientFactory ?? createHttpClient,
         clientVersion,
       ) {
    _pb = PocketBase(
      serverUrl,
      authStore: AsyncAuthStore(
        initial: _sessionFor(store.current, serverUrl),
        save: (data) =>
            _store.write(jsonEncode({'server': serverUrl, 'auth': data})),
        clear: _store.delete,
      ),
      httpClientFactory: _httpClientFactory,
    );
    // The SDK would drop an expired token before every request, also while
    // offline; refreshSession decides instead (offline-first, ADR-0001).
    _pb.autoClearAuthStore(false);
    _subscription = _pb.authStore.onChange.listen(
      (_) => _changes.add(currentUser),
    );
  }

  static const _users = 'users';

  /// Waits before the retries of a request the server rejected with
  /// HTTP 429 (rate limit): about half a minute in total, longer than the
  /// windows of PocketBase's default limits (`*:create` 20 per 5 s,
  /// `/api/` 300 per 10 s), so a large backlog, e.g. after an import, gets
  /// through instead of stopping the sync (issue #303).
  static const defaultRateLimitBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  /// One wait per retry after HTTP 429; empty: no retries.
  final List<Duration> rateLimitBackoff;

  /// The app version sent with every request (ADR-0029), so the server can
  /// refuse outdated clients; null sends none (the server assumes 0.0.0).
  final String? clientVersion;

  /// Header with [clientVersion]; read by the server's `lib/compat.js`.
  static const versionHeader = 'X-Setding-Version';

  static http.Client Function() _versioned(
    http.Client Function() factory,
    String? version,
  ) => version == null ? factory : () => _VersionClient(factory(), version);

  @override
  final String serverUrl;

  final SessionStore _store;
  final http.Client Function() _httpClientFactory;
  late final PocketBase _pb;
  late final StreamSubscription<AuthStoreEvent> _subscription;
  final _changes = StreamController<AuthUser?>.broadcast();

  /// The stored auth data, if it belongs to [serverUrl].
  static String? _sessionFor(String? stored, String serverUrl) {
    if (stored == null || stored.isEmpty) return null;
    try {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      if (data['server'] != serverUrl) return null;
      return data['auth'] as String?;
    } on FormatException {
      return null;
    }
  }

  @override
  AuthUser? get currentUser {
    final record = _pb.authStore.record;
    if (_pb.authStore.token.isEmpty || record == null) return null;
    String? known(String field) =>
        record.data.containsKey(field) ? record.getStringValue(field) : null;
    return AuthUser(
      id: record.id,
      email: record.getStringValue('email'),
      name: record.getStringValue('name'),
      // Older servers have no such fields (ADR-0062).
      firstName: known('first_name'),
      lastName: known('last_name'),
      nickname: record.getStringValue('nickname'),
    );
  }

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _pb.collection(_users).authWithPassword(email.trim(), password);
    } on ClientException catch (e) {
      throw _map(e, credentials: true);
    }
    return currentUser!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required PersonName name,
    String? invite,
  }) async {
    try {
      await _pb
          .collection(_users)
          .create(
            body: {
              'email': email.trim(),
              'password': password,
              'passwordConfirm': password,
              ..._names(name),
              'invite': ?invite,
            },
          );
    } on ClientException catch (e) {
      throw _map(e);
    }
    return signIn(email: email, password: password);
  }

  /// The name fields of the `users` collection (ADR-0062).
  static Map<String, String> _names(PersonName name) => {
    'first_name': name.firstName.trim(),
    'last_name': name.lastName.trim(),
    'nickname': name.nickname.trim(),
  };

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _pb.collection(_users).requestPasswordReset(email.trim());
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> requestVerification(String email) async {
    try {
      await _pb.collection(_users).requestVerification(email.trim());
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<ServerConfig> fetchServerConfig() async {
    final data = await _sendPublic('/api/setding/config');
    return ServerConfig(
      registration: switch (data['registration']) {
        'open' => RegistrationMode.open,
        'invite_only' => RegistrationMode.inviteOnly,
        _ => RegistrationMode.unknown,
      },
      emailVerification: data['emailVerification'] == 'required',
      minClientVersion: data['minClientVersion'] as String?,
      latestClientVersion: data['latestClientVersion'] as String?,
      linkBase: data['linkBase'] as String?,
    );
  }

  @override
  Future<void> refreshSession() async {
    if (currentUser == null) return;
    try {
      if (_pb.authStore.isValid) {
        await _pb.collection(_users).authRefresh();
      } else {
        // An expired token cannot be refreshed. Only sign out once the
        // server is reachable; offline, the session stays.
        await _pb.health.check();
        _pb.authStore.clear();
      }
    } on ClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        // Token invalidated or account gone: the user has to sign in again.
        _pb.authStore.clear();
      } else {
        _log.warning('Session refresh failed: ${e.statusCode} ${e.response}');
      }
    }
  }

  @override
  Future<void> signOut() async => _pb.authStore.clear();

  @override
  Future<AuthUser> changeName(PersonName name) async {
    final user = currentUser;
    if (user == null) throw const BackendException(BackendErrorKind.signedOut);
    // The SDK updates the stored session with the returned record, which
    // emits the new name through [userChanges].
    await _call(
      () => _pb.collection(_users).update(user.id, body: _names(name)),
    );
    return currentUser!;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) throw const BackendException(BackendErrorKind.signedOut);
    try {
      await _pb
          .collection(_users)
          .update(
            user.id,
            body: {
              'oldPassword': oldPassword,
              'password': newPassword,
              'passwordConfirm': newPassword,
            },
          );
      // The new password invalidated the token of this session too, and
      // the server refuses every request that carries it (401), signing in
      // included. Sign in on a client without the old token and take over
      // its session: clearing the session first would sign out on the way
      // (the web client deletes its data then, ADR-0018).
      final fresh = await PocketBase(
        serverUrl,
        httpClientFactory: _httpClientFactory,
      ).collection(_users).authWithPassword(user.email, newPassword);
      _pb.authStore.save(fresh.token, fresh.record);
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    final user = currentUser;
    if (user == null) throw const BackendException(BackendErrorKind.signedOut);
    try {
      // The SDK clears the session after deleting the own record.
      await _pb
          .collection(_users)
          .delete(user.id, body: {'password': password});
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  // Organizations and bands ----------------------------------------------------

  @override
  Future<List<RemoteOrganization>> fetchOrganizations() async {
    final me = currentUser;
    if (me == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      Future<List<RecordModel>> all(String collection, {String? expand}) =>
          _retrying(
            () => _pb
                .collection(collection)
                .getFullList(filter: 'deleted = false', expand: expand),
          );
      // In parallel; Future.wait passes the first ClientException on.
      final [orgs, orgMembers, bands, bandMembers] = await Future.wait([
        all('organizations'),
        all('org_memberships', expand: 'user'),
        all('bands'),
        all('memberships', expand: 'user'),
      ]);
      return [
        for (final o in orgs)
          if (orgMembers.any(
            (m) =>
                m.getStringValue('organization') == o.id &&
                m.getStringValue('user') == me.id,
          ))
            RemoteOrganization(
              id: o.id,
              name: o.getStringValue('name'),
              revision: o.getIntValue('revision'),
              members: [
                for (final m in orgMembers)
                  if (m.getStringValue('organization') == o.id)
                    _member(m, me, OrgRole.values, OrgRole.member),
              ],
              bands: [
                for (final b in bands)
                  if (b.getStringValue('organization') == o.id)
                    RemoteBand(
                      id: b.id,
                      organizationId: o.id,
                      name: b.getStringValue('name'),
                      revision: b.getIntValue('revision'),
                      staleAfterMonths: b.getIntValue('stale_after_months'),
                      members: [
                        for (final m in bandMembers)
                          if (m.getStringValue('band') == b.id)
                            _member(m, me, BandRole.values, BandRole.member),
                      ],
                    ),
              ],
            ),
      ];
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  /// A membership with its role from [roles] ([fallback] for unknown
  /// values, e.g. a role of a newer server).
  static RemoteMember<R> _member<R extends Enum>(
    RecordModel m,
    AuthUser me,
    List<R> roles,
    R fallback,
  ) {
    final userId = m.getStringValue('user');
    final user = m.get<RecordModel?>('expand.user');
    final name = user?.getStringValue('name') ?? '';
    final email = user?.getStringValue('email') ?? '';
    final role = m.getStringValue('role');
    return RemoteMember<R>(
      membershipId: m.id,
      userId: userId,
      name: userId == me.id && name.isEmpty ? me.displayName : name,
      firstName: user?.getStringValue('first_name') ?? '',
      lastName: user?.getStringValue('last_name') ?? '',
      nickname: user?.getStringValue('nickname') ?? '',
      email: userId == me.id ? me.email : (email.isEmpty ? null : email),
      role: roles.where((r) => r.name == role).firstOrNull ?? fallback,
      revision: m.getIntValue('revision'),
    );
  }

  @override
  Future<void> renameOrganization(String organizationId, String name) => _call(
    () => _pb
        .collection('organizations')
        .update(organizationId, body: {'name': name.trim()}),
  );

  @override
  Future<void> setOrgMemberRole(String orgMembershipId, OrgRole role) => _call(
    () => _pb
        .collection('org_memberships')
        .update(orgMembershipId, body: {'role': role.name}),
  );

  @override
  Future<void> removeOrgMember(String orgMembershipId) => _call(
    () => _pb
        .collection('org_memberships')
        .update(orgMembershipId, body: {'deleted': true}),
  );

  @override
  Future<void> createBand({
    required String id,
    required String name,
    String? organizationId,
  }) => _call(
    () => _pb
        .collection('bands')
        .create(
          body: {
            'id': id,
            'name': name.trim(),
            'organization': ?organizationId,
          },
        ),
  );

  @override
  Future<void> updateBand(
    String bandId, {
    String? name,
    int? staleAfterMonths,
  }) => _call(
    () => _pb
        .collection('bands')
        .update(
          bandId,
          body: {
            'name': ?name?.trim(),
            'stale_after_months': ?staleAfterMonths,
          },
        ),
  );

  @override
  Future<void> closeOrganization(String organizationId) =>
      _call(() => _pb.collection('organizations').delete(organizationId));

  @override
  Future<void> restoreOrganization(String organizationId) => _call(
    () => _pb
        .collection('organizations')
        .update(organizationId, body: {'deleted': false}),
  );

  @override
  Future<List<ClosedOrganization>> fetchClosedOrganizations() async {
    final me = currentUser;
    if (me == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      final memberships = await _retrying(
        () => _pb
            .collection('org_memberships')
            .getFullList(
              filter: _pb.filter(
                'user = {:me} && deleted = false && organization.deleted = true'
                ' && organization.purged = false',
                {'me': me.id},
              ),
              expand: 'organization,organization.updated_by',
            ),
      );
      final closed = [
        for (final m in memberships)
          if (m.get<RecordModel?>('expand.organization') case final org?)
            ClosedOrganization(
              id: org.id,
              name: org.getStringValue('name'),
              closedAt:
                  DateTime.tryParse(org.getStringValue('deleted_at'))
                      ?.toUtc() ??
                  DateTime.now().toUtc(),
              isAdmin: m.getStringValue('role') == OrgRole.admin.name,
              closedBy: switch (org
                  .get<RecordModel?>('expand.updated_by')
                  ?.getStringValue('name')) {
                final name? when name.isNotEmpty => name,
                _ => null,
              },
            ),
      ]..sort((a, b) => b.closedAt.compareTo(a.closedAt));
      return closed;
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> deleteBand(String bandId) =>
      _call(() => _pb.collection('bands').delete(bandId));

  @override
  Future<void> restoreBand(String bandId) => _call(
    () => _pb.collection('bands').update(bandId, body: {'deleted': false}),
  );

  @override
  Future<List<RemoteOrgPlay>> fetchOrgPlays(String organizationId) =>
      _signedIn(() async {
        final result = await _pb.send<dynamic>(
          '/api/setding/plays/${Uri.encodeComponent(organizationId)}',
        );
        final plays = (result as Map)['plays'] as List? ?? const [];
        return [
          for (final p in plays.cast<Map<String, dynamic>>())
            if (DateTime.tryParse(p['last'] as String? ?? '') case final last?)
              RemoteOrgPlay(
                songId: p['song'] as String,
                bandId: p['band'] as String,
                bandName: p['bandName'] as String? ?? '',
                count: (p['count'] as num?)?.toInt() ?? 0,
                last: last,
                key: p['key'] as String?,
              ),
        ];
      });

  @override
  Future<List<DeletedBand>> fetchDeletedBands(String organizationId) async {
    try {
      final records = await _retrying(
        () => _pb
            .collection('bands')
            .getFullList(
              filter: _pb.filter(
                'organization = {:org} && deleted = true && purged = false',
                {'org': organizationId},
              ),
              sort: '-deleted_at',
            ),
      );
      return [
        for (final r in records)
          DeletedBand(
            id: r.id,
            name: r.getStringValue('name'),
            deletedAt:
                DateTime.tryParse(r.getStringValue('deleted_at'))?.toUtc() ??
                DateTime.now().toUtc(),
          ),
      ];
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> addBandMember(String bandId, String userId, BandRole role) =>
      _call(() async {
        // A removed member keeps a soft-deleted membership (unique per user
        // and band), which is reactivated instead.
        final previous = await _pb
            .collection('memberships')
            .getList(
              perPage: 1,
              filter: _pb.filter('band = {:band} && user = {:user}', {
                'band': bandId,
                'user': userId,
              }),
            );
        if (previous.items.isNotEmpty) {
          return _pb
              .collection('memberships')
              .update(
                previous.items.first.id,
                body: {'deleted': false, 'role': role.name},
              );
        }
        return _pb
            .collection('memberships')
            .create(body: {'band': bandId, 'user': userId, 'role': role.name});
      });

  @override
  Future<void> setMemberRole(String membershipId, BandRole role) => _call(
    () => _pb
        .collection('memberships')
        .update(membershipId, body: {'role': role.name}),
  );

  @override
  Future<void> removeMember(String membershipId) => _call(
    () => _pb
        .collection('memberships')
        .update(membershipId, body: {'deleted': true}),
  );

  // Invitations -----------------------------------------------------------------

  @override
  Future<CreatedInvite> createInvite(
    String organizationId, {
    String? bandId,
    String? contactId,
  }) async {
    final data = await _send(
      '/api/setding/invites',
      method: 'POST',
      body: {
        'organization': organizationId,
        'band': ?bandId,
        'contact': ?contactId,
      },
    );
    return CreatedInvite(
      id: data['id'] as String,
      url: data['url'] as String,
      expires: DateTime.parse(data['expires'] as String),
    );
  }

  @override
  Future<List<InviteInfo>> fetchInvites(
    String organizationId, {
    String? bandId,
  }) async {
    return _signedIn(() async {
      final filter = _pb.filter('organization = {:org}', {
        'org': organizationId,
      });
      final active =
          // Personal invitations belong to their contact (ADR-0064).
          '$filter && revoked = false && expires > @now && contact = ""'
          '${bandId == null ? '' : ' && ${_pb.filter('band = {:band}', {'band': bandId})}'}';
      final invites = await _pb
          .collection('invites')
          .getFullList(filter: active, sort: '-created', expand: 'band');
      final joined = await _pb
          .collection('org_memberships')
          .getFullList(
            filter: '$filter && invite != "" && deleted = false',
            expand: 'user',
          );
      return [
        for (final i in invites)
          InviteInfo(
            id: i.id,
            created: DateTime.parse(i.getStringValue('created')),
            expires: DateTime.parse(i.getStringValue('expires')),
            revoked: i.getBoolValue('revoked'),
            bandName: i
                .get<RecordModel?>('expand.band')
                ?.getStringValue('name'),
            joined: [
              for (final m in joined)
                if (m.getStringValue('invite') == i.id)
                  m.get<RecordModel?>('expand.user')?.getStringValue('name') ??
                      '',
            ],
          ),
      ];
    });
  }

  @override
  Future<CreatedInvite> fetchInviteLink(String inviteId) async {
    final data = await _send(
      '/api/setding/invites/${Uri.encodeComponent(inviteId)}/link',
    );
    return CreatedInvite(
      id: data['id'] as String,
      url: data['url'] as String,
      expires: DateTime.parse(data['expires'] as String),
    );
  }

  @override
  Future<void> revokeInvite(String inviteId) => _call(
    () => _pb.collection('invites').update(inviteId, body: {'revoked': true}),
  );

  static InviteStatus _status(String value) => switch (value) {
    'expired' => InviteStatus.expired,
    'revoked' => InviteStatus.revoked,
    'used' => InviteStatus.used,
    _ => InviteStatus.valid,
  };

  @override
  Future<InvitePreview> previewInvite(String token) async {
    final data = await _sendPublic('/api/setding/invites/${_token(token)}');
    final org = data['organization'] as Map<String, dynamic>;
    return InvitePreview(
      organizationId: org['id'] as String,
      organizationName: org['name'] as String,
      status: _status(data['status'] as String),
      alreadyMember: data['member'] as bool,
      founder: data['founder'] == true,
      bandName: (data['band'] as Map<String, dynamic>?)?['name'] as String?,
      contact: switch (data['contact']) {
        final Map<String, dynamic> c => (
          name: PersonName(
            firstName: c['first_name'] as String? ?? '',
            lastName: c['last_name'] as String? ?? '',
            nickname: c['nickname'] as String? ?? '',
          ),
          email: _nonEmpty(c['email'] as String? ?? ''),
        ),
        _ => null,
      },
    );
  }

  @override
  Future<String> redeemInvite(String token) async {
    final data = await _send(
      '/api/setding/invites/${_token(token)}/redeem',
      method: 'POST',
    );
    return (data['organization'] as Map<String, dynamic>)['id'] as String;
  }

  // Songs and sets -------------------------------------------------------------

  static RemoteSong _song(RecordModel r) => RemoteSong(
    id: r.id,
    organizationId: r.getStringValue('organization'),
    title: r.getStringValue('title'),
    chordpro: r.getStringValue('chordpro'),
    revision: r.getIntValue('revision'),
    deleted: r.getBoolValue('deleted'),
    deletedAt: _date(r.getStringValue('deleted_at')),
    purged: r.getBoolValue('purged'),
    createdBy: _nonEmpty(r.getStringValue('created_by')),
    updatedBy: _nonEmpty(r.getStringValue('updated_by')),
    workId: _nonEmpty(r.getStringValue('work_id')),
    language: _nonEmpty(r.getStringValue('language')),
    contentRevision: r.getIntValue('content_revision'),
    created: _date(r.getStringValue('created')),
    reviewState: _nonEmpty(r.getStringValue('review_state')),
    reviewReason: _nonEmpty(r.getStringValue('review_reason')),
    reviewedBy: _nonEmpty(r.getStringValue('reviewed_by')),
    reviewedAt: _date(r.getStringValue('reviewed_at')),
  );

  static RemoteSongReport _report(RecordModel r) {
    final location = r.get<dynamic>('location');
    return RemoteSongReport(
      id: r.id,
      songId: r.getStringValue('song'),
      organizationId: r.getStringValue('organization'),
      authorId: _nonEmpty(r.getStringValue('author')),
      category: r.getStringValue('category'),
      comment: r.getStringValue('comment'),
      location: location is Map ? location.cast<String, dynamic>() : null,
      screenshot: _nonEmpty(r.getStringValue('screenshot')),
      status: r.getStringValue('status'),
      resolution: _nonEmpty(r.getStringValue('resolution')),
      resolvedBy: _nonEmpty(r.getStringValue('resolved_by')),
      resolvedAt: _date(r.getStringValue('resolved_at')),
      created: _date(r.getStringValue('created')),
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
      purged: r.getBoolValue('purged'),
    );
  }

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;

  /// A PocketBase date, or null if empty.
  static DateTime? _date(String value) =>
      value.isEmpty ? null : DateTime.tryParse(value);

  /// A date as PocketBase stores it, or '' for none.
  static String _dateValue(DateTime? value) =>
      value?.toUtc().toIso8601String().replaceFirst('T', ' ') ?? '';

  static RemoteSet _set(RecordModel r) {
    final date = r.getStringValue('gig_date');
    final venue = r.getStringValue('venue');
    final items = r.get<dynamic>('items');
    return RemoteSet(
      id: r.id,
      bandId: r.getStringValue('band'),
      name: r.getStringValue('name'),
      gigDate: date.isEmpty ? null : DateTime.parse(date),
      venue: venue.isEmpty ? null : venue,
      origin: _nonEmpty(r.getStringValue('origin')),
      items: items is List
          ? [
              for (final i in items)
                RemoteSetItem.fromJson((i as Map).cast<String, dynamic>()),
            ]
          : const [],
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
      deletedAt: _date(r.getStringValue('deleted_at')),
      purged: r.getBoolValue('purged'),
      updatedBy: _nonEmpty(r.getStringValue('updated_by')),
      lineup: r.getListValue<String>('lineup'),
      lineupContacts: r.getListValue<String>('lineup_contacts'),
      lineupCustom: r.getBoolValue('lineup_custom'),
    );
  }

  static RemoteContact _contact(RecordModel r) => RemoteContact(
    id: r.id,
    organizationId: r.getStringValue('organization'),
    firstName: r.getStringValue('first_name'),
    lastName: r.getStringValue('last_name'),
    nickname: r.getStringValue('nickname'),
    // Absent for people who may not edit sets (ADR-0064).
    email: _nonEmpty(r.getStringValue('email')),
    linkedUserId: _nonEmpty(r.getStringValue('linked_user')),
    createdBy: _nonEmpty(r.getStringValue('created_by')),
    revision: r.getIntValue('revision'),
    deleted: r.getBoolValue('deleted'),
  );

  @override
  Future<List<RemoteContact>> pullContacts(
    String organizationId,
    int since,
  ) async => [
    for (final r in await _since(
      'contacts',
      'organization',
      organizationId,
      since,
    ))
      _contact(r),
  ];

  @override
  Future<RemoteContact> pushContact(
    RemoteContact contact, {
    required bool create,
  }) => _signedIn(() async {
    final body = {
      'first_name': contact.firstName,
      'last_name': contact.lastName,
      'nickname': contact.nickname,
      'email': contact.email ?? '',
      if (contact.deleted) 'deleted': true,
    };
    final r = create
        ? await _pb
              .collection('contacts')
              .create(
                body: {
                  'id': contact.id,
                  'organization': contact.organizationId,
                  ...body,
                },
              )
        : await _pb.collection('contacts').update(contact.id, body: body);
    return _contact(r);
  });

  @override
  Future<RemoteLineup> fetchLineup() => _signedIn(() async {
    final result = await _pb.send<dynamic>('/api/setding/lineup');
    List<Map<String, dynamic>> list(String key) => [
      for (final x in (result as Map)[key] as List? ?? const [])
        (x as Map).cast<String, dynamic>(),
    ];
    return RemoteLineup(
      sets: [for (final s in list('sets')) _set(RecordModel.fromJson(s))],
      bands: [
        for (final b in list('bands'))
          (
            id: b['id'] as String,
            name: b['name'] as String? ?? '',
            organizationId: b['organization'] as String? ?? '',
          ),
      ],
      arrangements: [
        for (final a in list('arrangements'))
          _arrangement(RecordModel.fromJson(a)),
      ],
    );
  });

  @override
  Future<List<({String name, String email})>> fetchLineupEmails(
    String setId,
  ) => _signedIn(() async {
    final result = await _pb.send<dynamic>(
      '/api/setding/lineup/${Uri.encodeComponent(setId)}/emails',
    );
    return [
      for (final p in (result as Map)['people'] as List? ?? const [])
        if ((p as Map)['email'] case final String email when email.isNotEmpty)
          (name: p['name'] as String? ?? '', email: email),
      // People without an account (ADR-0064).
      for (final c in result['contacts'] as List? ?? const [])
        if ((c as Map)['email'] case final String email when email.isNotEmpty)
          (name: _contactName(c), email: email),
    ];
  });

  /// The name of a contact in a server route's answer: nickname, otherwise
  /// first and last name (the server's display name of people, ADR-0062).
  static String _contactName(Map<dynamic, dynamic> c) {
    final nickname = (c['nickname'] as String? ?? '').trim();
    if (nickname.isNotEmpty) return nickname;
    return [
      c['first_name'] as String? ?? '',
      c['last_name'] as String? ?? '',
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
  }

  Future<List<RecordModel>> _since(
    String collection,
    String scopeField,
    String scope,
    int since,
  ) async {
    return _signedIn(() async {
      return await _pb
          .collection(collection)
          .getFullList(
            filter: _pb.filter(
              '$scopeField = {:scope} && revision > {:since}',
              {'scope': scope, 'since': since},
            ),
            sort: 'revision',
          );
    });
  }

  @override
  Future<List<RemoteSong>> pullSongs(String organizationId, int since) async =>
      [
        for (final r in await _since(
          'songs',
          'organization',
          organizationId,
          since,
        ))
          _song(r),
      ];

  @override
  Future<List<RemoteSet>> pullSets(String bandId, int since) async => [
    for (final r in await _since('setlists', 'band', bandId, since)) _set(r),
  ];

  @override
  Future<RemoteSong?> fetchSong(String id) async {
    try {
      return _song(await _retrying(() => _pb.collection('songs').getOne(id)));
    } on ClientException catch (e) {
      if (e.statusCode == 404) return null;
      throw _map(e);
    }
  }

  @override
  Future<RemoteSong> pushSong(RemoteSong song, {required bool create}) {
    final body = {
      'title': song.title,
      'chordpro': song.chordpro,
      'deleted': song.deleted,
      'deleted_at': _dateValue(song.deletedAt),
      // Deleting permanently from the trash (#866); never sent as false,
      // which the server ignores anyway.
      if (song.purged) 'purged': true,
    };
    return _signedIn(
      () async => _song(
        create
            ? await _pb
                  .collection('songs')
                  .create(
                    body: {
                      'id': song.id,
                      'organization': song.organizationId,
                      ...body,
                      // Link fields only on create; later by pushSongLink
                      // (ADR-0053).
                      'work_id': ?song.workId,
                      'language': ?song.language,
                      // Review status only on create; later by
                      // pushSongReview (ADR-0060).
                      'review_state': ?song.reviewState,
                      'review_reason': ?song.reviewReason,
                    },
                  )
            : await _pb
                  .collection('songs')
                  .update(song.id, body: {...body, 'revision': song.revision}),
      ),
      map: (e) => e.statusCode == 409
          ? BackendException(BackendErrorKind.conflict, e.response)
          : _map(e),
    );
  }

  @override
  Future<RemoteSong> pushSongLink(
    String songId,
    SongLinkField field,
    String? value,
  ) => _signedIn(
    () async => _song(
      await _pb
          .collection('songs')
          .update(songId, body: {field.serverName: value ?? ''}),
    ),
  );

  @override
  Future<RemoteSong> pushSongReview(
    String songId,
    String? state,
    String? reason,
  ) => _signedIn(
    () async => _song(
      await _pb
          .collection('songs')
          .update(
            songId,
            body: {'review_state': state ?? '', 'review_reason': reason ?? ''},
          ),
    ),
  );

  @override
  Future<List<RemoteSongReport>> pullSongReports(
    String organizationId,
    int since,
  ) async => [
    for (final r in await _since(
      'song_reports',
      'organization',
      organizationId,
      since,
    ))
      _report(r),
  ];

  @override
  Future<RemoteSongReport> pushSongReport(
    RemoteSongReport report, {
    required bool create,
    bool asAuthor = true,
    bool asApprover = false,
    List<int>? screenshot,
    String? screenshotName,
  }) => _signedIn(() async {
    final files = [
      if (screenshot != null)
        http.MultipartFile.fromBytes(
          'screenshot',
          screenshot,
          filename: screenshotName ?? '${report.id}.webp',
          contentType: _imageType(screenshotName ?? ''),
        ),
    ];
    final RecordModel r;
    if (create) {
      r = await _pb
          .collection('song_reports')
          .create(
            body: {
              'id': report.id,
              'song': report.songId,
              'organization': report.organizationId,
              'category': report.category,
              'comment': report.comment,
              'location': ?report.location,
            },
            files: files,
          );
    } else {
      r = await _pb
          .collection('song_reports')
          .update(
            report.id,
            body: {
              if (asAuthor) ...{
                'category': report.category,
                'comment': report.comment,
                'location': ?report.location,
              },
              if (asApprover) 'resolution': report.resolution ?? '',
              'status': report.status,
            },
            files: files,
          );
    }
    return _report(r);
  });

  static MediaType _imageType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('image', 'webp');
  }

  @override
  Future<Uint8List> fetchReportScreenshot(String reportId, String file) =>
      _signedIn(() async {
        final token = await _pb.files.getToken();
        final uri = Uri.parse(
          '$serverUrl/api/files/song_reports/$reportId/$file',
        ).replace(queryParameters: {'token': token});
        final client = _httpClientFactory();
        try {
          final response = await client.get(uri);
          if (response.statusCode != 200) {
            throw BackendException(
              response.statusCode == 404
                  ? BackendErrorKind.notAllowed
                  : BackendErrorKind.server,
              response.statusCode,
            );
          }
          return response.bodyBytes;
        } on http.ClientException catch (e) {
          throw BackendException(BackendErrorKind.network, e);
        } finally {
          client.close();
        }
      });

  @override
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create}) async {
    return _signedIn(() async {
      final body = {
        'name': set.name,
        'gig_date':
            set.gigDate?.toUtc().toIso8601String().replaceFirst('T', ' ') ?? '',
        'venue': set.venue ?? '',
        // Only sent when set: an update without it keeps the stored one.
        'origin': ?set.origin,
        'items': [for (final i in set.items) i.toJson()],
        'deleted': set.deleted,
        'deleted_at': _dateValue(set.deletedAt),
        if (set.purged) 'purged': true, // deleted permanently (#866)
        'lineup': set.lineup,
        'lineup_contacts': set.lineupContacts,
        'lineup_custom': set.lineupCustom,
      };
      final r = create
          ? await _pb
                .collection('setlists')
                .create(body: {'id': set.id, 'band': set.bandId, ...body})
          : await _pb.collection('setlists').update(set.id, body: body);
      return _set(r);
    });
  }

  static RemoteAttachment _attachment(RecordModel r) {
    final file = r.getStringValue('file');
    final pages = r.getIntValue('pages');
    return RemoteAttachment(
      id: r.id,
      organizationId: r.getStringValue('organization'),
      songId: r.getStringValue('song'),
      name: r.getStringValue('name'),
      file: file.isEmpty ? null : file,
      pages: pages == 0 ? null : pages,
      sizeBytes: r.getIntValue('size_bytes'),
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
      deletedAt: _date(r.getStringValue('deleted_at')),
      purged: r.getBoolValue('purged'),
      updatedBy: _nonEmpty(r.getStringValue('updated_by')),
    );
  }

  @override
  Future<List<RemoteAttachment>> pullAttachments(
    String organizationId,
    int since,
  ) async => [
    for (final r in await _since(
      'attachments',
      'organization',
      organizationId,
      since,
    ))
      _attachment(r),
  ];

  @override
  Future<RemoteAttachment> pushAttachment(
    RemoteAttachment attachment, {
    required bool create,
    List<int>? bytes,
  }) async {
    return _signedIn(() async {
      final RecordModel r;
      if (create) {
        r = await _pb
            .collection('attachments')
            .create(
              body: {
                'id': attachment.id,
                'organization': attachment.organizationId,
                'song': attachment.songId,
                'name': attachment.name,
                'pages': ?attachment.pages,
                'size_bytes': attachment.sizeBytes,
                'deleted': attachment.deleted,
                'deleted_at': _dateValue(attachment.deletedAt),
              },
              files: [
                http.MultipartFile.fromBytes(
                  'file',
                  bytes ?? const [],
                  filename: '${attachment.id}.pdf',
                  contentType: MediaType('application', 'pdf'),
                ),
              ],
            );
      } else {
        r = await _pb
            .collection('attachments')
            .update(
              attachment.id,
              body: {
                'name': attachment.name,
                'deleted': attachment.deleted,
                'deleted_at': _dateValue(attachment.deletedAt),
              },
            );
      }
      return _attachment(r);
    });
  }

  static RemoteOverlay _overlay(RecordModel r) {
    final data = r.get<dynamic>('data');
    return RemoteOverlay(
      id: r.id,
      userId: r.getStringValue('user'),
      songId: r.getStringValue('song'),
      data: data is Map ? data.cast<String, dynamic>() : const {},
      midi: MidiProgram.fromJson(r.get<dynamic>('midi')),
      midiPrograms: MidiPrograms.fromJson(r.get<dynamic>('midi_programs')),
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
    );
  }

  @override
  Future<List<RemoteOverlay>> pullOverlays(int since) async => [
    for (final r in await _since(
      'overlays',
      'user',
      currentUser?.id ?? '',
      since,
    ))
      _overlay(r),
  ];

  @override
  Future<RemoteOverlay> pushOverlay(
    RemoteOverlay overlay, {
    required bool create,
  }) => _signedIn(() async {
    final body = {
      'data': overlay.data,
      'midi': overlay.midi?.toJson(),
      'midi_programs': overlay.midiPrograms?.toJson(),
      'deleted': overlay.deleted,
    };
    return _overlay(
      create
          ? await _pb
                .collection('overlays')
                .create(
                  body: {
                    'id': overlay.id,
                    'user': overlay.userId,
                    'song': overlay.songId,
                    ...body,
                  },
                )
          : await _pb.collection('overlays').update(overlay.id, body: body),
    );
  });

  static RemoteAnnotations _annotations(RecordModel r) {
    final data = r.get<dynamic>('data');
    final attachment = r.getStringValue('attachment');
    return RemoteAnnotations(
      id: r.id,
      userId: r.getStringValue('user'),
      songId: r.getStringValue('song'),
      attachmentId: attachment.isEmpty ? null : attachment,
      data: data is Map ? data.cast<String, dynamic>() : const {},
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
    );
  }

  @override
  Future<List<RemoteAnnotations>> pullAnnotations(int since) async => [
    for (final r in await _since(
      'annotations',
      'user',
      currentUser?.id ?? '',
      since,
    ))
      _annotations(r),
  ];

  @override
  Future<RemoteAnnotations> pushAnnotations(
    RemoteAnnotations annotations, {
    required bool create,
  }) => _signedIn(() async {
    final body = {'data': annotations.data};
    return _annotations(
      create
          ? await _pb
                .collection('annotations')
                .create(
                  body: {
                    'id': annotations.id,
                    'user': annotations.userId,
                    'song': annotations.songId,
                    'attachment': ?annotations.attachmentId,
                    ...body,
                  },
                )
          : await _pb
                .collection('annotations')
                .update(annotations.id, body: body),
    );
  });

  static RemoteUserSettings _userSettings(RecordModel r) {
    final data = r.get<dynamic>('data');
    return RemoteUserSettings(
      id: r.id,
      userId: r.getStringValue('user'),
      data: data is Map ? data.cast<String, dynamic>() : const {},
      revision: r.getIntValue('revision'),
    );
  }

  @override
  Future<RemoteUserSettings?> pullUserSettings(int since) async {
    final records = await _since(
      'user_settings',
      'user',
      currentUser?.id ?? '',
      since,
    );
    return records.isEmpty ? null : _userSettings(records.last);
  }

  @override
  Future<RemoteUserSettings> pushUserSettings(
    RemoteUserSettings settings, {
    required bool create,
  }) => _signedIn(() async {
    return _userSettings(
      create
          ? await _pb
                .collection('user_settings')
                .create(
                  body: {
                    'id': settings.id,
                    'user': settings.userId,
                    'data': settings.data,
                  },
                )
          : await _pb
                .collection('user_settings')
                .update(settings.id, body: {'data': settings.data}),
    );
  });

  static RemoteArrangement _arrangement(RecordModel r) {
    final tempo = r.getIntValue('tempo');
    return RemoteArrangement(
      id: r.id,
      bandId: r.getStringValue('band'),
      songId: r.getStringValue('song'),
      transpose: r.getIntValue('transpose'),
      sequence: _nonEmpty(r.getStringValue('sequence')),
      tempo: tempo > 0 ? tempo : null,
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
      updatedBy: _nonEmpty(r.getStringValue('updated_by')),
    );
  }

  @override
  Future<List<RemoteArrangement>> pullArrangements(
    String bandId,
    int since,
  ) async => [
    for (final r in await _since('arrangements', 'band', bandId, since))
      _arrangement(r),
  ];

  @override
  Future<RemoteArrangement> pushArrangement(
    RemoteArrangement arrangement, {
    required bool create,
  }) => _signedIn(() async {
    final body = {
      'transpose': arrangement.transpose,
      'sequence': arrangement.sequence ?? '',
      'tempo': arrangement.tempo ?? 0,
      'deleted': arrangement.deleted,
    };
    return _arrangement(
      create
          ? await _pb
                .collection('arrangements')
                .create(
                  body: {
                    'id': arrangement.id,
                    'band': arrangement.bandId,
                    'song': arrangement.songId,
                    ...body,
                  },
                )
          : await _pb
                .collection('arrangements')
                .update(arrangement.id, body: body),
    );
  });

  @override
  AttachmentDownloads openDownloads() => _PocketBaseDownloads(this);

  @override
  Stream<String> watchChanges() {
    const collections = [
      'songs',
      'setlists',
      'attachments',
      'overlays',
      'arrangements',
      'user_settings',
      'annotations',
      'song_reports',
      'contacts',
      // Changes of who sees which band (SyncController.bandCollections).
      'organizations',
      'org_memberships',
      'bands',
      'memberships',
    ];
    late StreamController<String> controller;
    final unsubscribers = <Future<void> Function()>[];
    controller = StreamController<String>(
      onListen: () async {
        for (final c in collections) {
          try {
            unsubscribers.add(
              await _pb.collection(c).subscribe('*', (_) => controller.add(c)),
            );
          } catch (e) {
            _log.warning('Realtime subscription for $c failed', e);
          }
        }
      },
      onCancel: () async {
        for (final unsubscribe in unsubscribers) {
          try {
            await unsubscribe();
          } catch (_) {}
        }
        await controller.close();
      },
    );
    return controller.stream;
  }

  Future<Map<String, dynamic>> _send(
    String path, {
    String method = 'GET',
    Map<String, dynamic> body = const {},
  }) => _signedIn(() async {
    final result = await _pb.send<dynamic>(path, method: method, body: body);
    return (result as Map).cast<String, dynamic>();
  }, map: (e) => _map(e, invite: true));

  /// A server route that also answers without an account (ADR-0024); sends
  /// the session if there is one.
  Future<Map<String, dynamic>> _sendPublic(String path) async {
    try {
      final result = await _pb.send<dynamic>(path);
      return (result as Map).cast<String, dynamic>();
    } on ClientException catch (e) {
      throw _map(e, invite: true);
    }
  }

  /// Only well-formed tokens go into a URL path.
  static String _token(String token) {
    if (inviteTokenFrom(token) != token) {
      throw const BackendException(BackendErrorKind.inviteUnknown);
    }
    return token;
  }

  /// Runs [request] for the signed-in user; maps its [ClientException]s
  /// with [map] (default: [_map]).
  Future<T> _signedIn<T>(
    Future<T> Function() request, {
    BackendException Function(ClientException e)? map,
  }) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      return await _retrying(request);
    } on ClientException catch (e) {
      throw (map ?? _map)(e);
    }
  }

  /// Runs [request] and runs it again after the waits of [rateLimitBackoff]
  /// while the server rejects it with HTTP 429. Not used for signing in and
  /// invitations: their limits protect against guessing.
  Future<T> _retrying<T>(Future<T> Function() request) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await request();
      } on ClientException catch (e) {
        if (e.statusCode != 429 || attempt >= rateLimitBackoff.length) {
          rethrow;
        }
        final wait = rateLimitBackoff[attempt];
        _log.info(
          'Rate limited (HTTP 429), retrying in ${wait.inMilliseconds} ms',
        );
        await Future<void>.delayed(wait);
      }
    }
  }

  /// [_signedIn] for requests whose result is not needed.
  Future<void> _call(Future<Object?> Function() request) => _signedIn(request);

  @override
  void dispose() {
    _subscription.cancel();
    _changes.close();
  }

  static BackendException _map(
    ClientException e, {
    bool credentials = false,
    bool invite = false,
  }) {
    if (e.statusCode == 0) {
      return BackendException(BackendErrorKind.network, e.originalError);
    }
    // The server refuses this app version (ADR-0029).
    if (e.statusCode == 426) {
      return BackendException(BackendErrorKind.updateRequired, e.response);
    }
    if (invite && e.statusCode == 410) {
      final data = e.response['data'];
      final code = data is Map && data['token'] is Map
          ? (data['token'] as Map)['code']
          : null;
      return BackendException(switch (code) {
        'revoked' => BackendErrorKind.inviteRevoked,
        'used' => BackendErrorKind.inviteUsed,
        _ => BackendErrorKind.inviteExpired,
      }, e.response);
    }
    if (invite && e.statusCode == 409) {
      return BackendException(BackendErrorKind.inviteNotStored, e.response);
    }
    if (invite && e.statusCode == 404) {
      return BackendException(BackendErrorKind.inviteUnknown, e.response);
    }
    final data = e.response['data'];
    String? codeOf(String field) {
      final error = data is Map ? data[field] : null;
      return error is Map ? error['code'] as String? : null;
    }

    // Registration settings of the server (ADR-0024).
    if (codeOf('invite') == 'invitation_required') {
      return BackendException(BackendErrorKind.invitationRequired, e.response);
    }
    if (codeOf('email') == 'email_not_verified') {
      return BackendException(BackendErrorKind.emailNotVerified, e.response);
    }
    if (codeOf('organization') == 'founder_invitation_required') {
      return BackendException(
        BackendErrorKind.founderInvitationRequired,
        e.response,
      );
    }
    if (credentials && e.statusCode == 400) {
      return BackendException(BackendErrorKind.invalidCredentials, e.response);
    }
    if (e.statusCode == 403 || e.statusCode == 404) {
      return BackendException(BackendErrorKind.notAllowed, e.response);
    }
    if (e.statusCode == 401) {
      return BackendException(BackendErrorKind.signedOut, e.response);
    }
    final fields = e.response['data'];
    if (fields is Map) {
      String? code(String field) {
        final error = fields[field];
        return error is Map ? error['code'] as String? : null;
      }

      final email = code('email');
      if (email == 'validation_not_unique') {
        return BackendException(BackendErrorKind.emailTaken, e.response);
      }
      if (email != null) {
        return BackendException(BackendErrorKind.invalidEmail, e.response);
      }
      // Deleting the account (ADR-0052).
      if (code('organizations') == 'last_admin') {
        return BackendException(BackendErrorKind.soleOrgAdmin, e.response);
      }
      // Changing the password or deleting the account with a wrong
      // current password (issue #779, ADR-0052).
      if (code('oldPassword') != null ||
          code('password') == 'invalid_password') {
        return BackendException(
          BackendErrorKind.invalidCredentials,
          e.response,
        );
      }
      if (code('password') != null || code('passwordConfirm') != null) {
        return BackendException(BackendErrorKind.weakPassword, e.response);
      }
      if (code('role') == 'last_admin') {
        return BackendException(BackendErrorKind.lastAdmin, e.response);
      }
      if (code('user') == 'not_org_member') {
        return BackendException(BackendErrorKind.notOrgMember, e.response);
      }
    }
    return BackendException(BackendErrorKind.server, e.response);
  }
}

/// Downloads with one HTTP client and a shared file token, renewed after a
/// minute (file tokens are short-lived).
class _PocketBaseDownloads implements AttachmentDownloads {
  _PocketBaseDownloads(this._backend) : _client = _backend._httpClientFactory();

  static const _tokenAge = Duration(minutes: 1);

  final PocketBaseBackend _backend;
  final http.Client _client;
  Future<String>? _token;
  DateTime _tokenTime = DateTime(0);

  Future<String> _fileToken() {
    final now = DateTime.now();
    if (_token == null || now.difference(_tokenTime) > _tokenAge) {
      _tokenTime = now;
      _token = _backend._pb.files.getToken();
    }
    return _token!;
  }

  @override
  Future<void> download(
    RemoteAttachment attachment,
    StreamSink<List<int>> target,
  ) async {
    if (_backend.currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      final token = await _fileToken();
      final uri = Uri.parse(
        '${_backend.serverUrl}/api/files/attachments/'
        '${attachment.id}/${attachment.file}',
      ).replace(queryParameters: {'token': token});
      var response = await _client.send(http.Request('GET', uri));
      for (final wait in _backend.rateLimitBackoff) {
        if (response.statusCode != 429) break;
        await response.stream.drain<void>();
        _log.info(
          'Rate limited (HTTP 429), retrying in ${wait.inMilliseconds} ms',
        );
        await Future<void>.delayed(wait);
        response = await _client.send(http.Request('GET', uri));
      }
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw BackendException(
          response.statusCode == 404
              ? BackendErrorKind.notAllowed
              : BackendErrorKind.server,
          response.statusCode,
        );
      }
      await target.addStream(response.stream);
    } on ClientException catch (e) {
      _token = null; // e.g. a failed token request: ask again next time
      throw PocketBaseBackend._map(e);
    } on http.ClientException catch (e) {
      throw BackendException(BackendErrorKind.network, e);
    } catch (e) {
      // The connection broke while the file was arriving (native only).
      if (!isSocketException(e)) rethrow;
      throw BackendException(BackendErrorKind.network, e);
    }
  }

  @override
  void close() => _client.close();
}

/// Adds the app version to every request (ADR-0029).
class _VersionClient extends http.BaseClient {
  _VersionClient(this._inner, this._version);

  final http.Client _inner;
  final String _version;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers[PocketBaseBackend.versionHeader] = _version;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
