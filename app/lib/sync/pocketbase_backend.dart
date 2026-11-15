import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'session_store.dart';
import 'sync_backend.dart';

/// [SyncBackend] on PocketBase (ADR-0004, ADR-0015).
class PocketBaseBackend implements SyncBackend {
  PocketBaseBackend({
    required this.serverUrl,
    required SessionStore store,
    http.Client Function()? httpClientFactory,
  }) : _store = store {
    _pb = PocketBase(
      serverUrl,
      authStore: AsyncAuthStore(
        initial: _sessionFor(store.current, serverUrl),
        save: (data) =>
            _store.write(jsonEncode({'server': serverUrl, 'auth': data})),
        clear: _store.delete,
      ),
      httpClientFactory: httpClientFactory,
    );
    // The SDK would drop an expired token before every request, also while
    // offline; refreshSession decides instead (offline-first, ADR-0001).
    _pb.autoClearAuthStore(false);
    _subscription = _pb.authStore.onChange.listen(
      (_) => _changes.add(currentUser),
    );
  }

  static const _users = 'users';

  @override
  final String serverUrl;

  final SessionStore _store;
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
    return AuthUser(
      id: record.id,
      email: record.getStringValue('email'),
      name: record.getStringValue('name'),
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
    required String name,
  }) async {
    try {
      await _pb
          .collection(_users)
          .create(
            body: {
              'email': email.trim(),
              'password': password,
              'passwordConfirm': password,
              'name': name.trim(),
            },
          );
    } on ClientException catch (e) {
      throw _map(e);
    }
    return signIn(email: email, password: password);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _pb.collection(_users).requestPasswordReset(email.trim());
    } on ClientException catch (e) {
      throw _map(e);
    }
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
        debugPrint('Session refresh failed: ${e.statusCode} ${e.response}');
      }
    }
  }

  @override
  Future<void> signOut() async => _pb.authStore.clear();

  // Organizations and bands ----------------------------------------------------

  @override
  Future<List<RemoteOrganization>> fetchOrganizations() async {
    final me = currentUser;
    if (me == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      Future<List<RecordModel>> all(String collection, {String? expand}) => _pb
          .collection(collection)
          .getFullList(filter: 'deleted = false', expand: expand);
      final orgs = await all('organizations');
      final orgMembers = await all('org_memberships', expand: 'user');
      final bands = await all('bands');
      final bandMembers = await all('memberships', expand: 'user');
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
                  if (m.getStringValue('organization') == o.id) _member(m, me),
              ],
              bands: [
                for (final b in bands)
                  if (b.getStringValue('organization') == o.id)
                    RemoteBand(
                      id: b.id,
                      organizationId: o.id,
                      name: b.getStringValue('name'),
                      membersCanEditSongs: b.getBoolValue(
                        'members_can_edit_songs',
                      ),
                      revision: b.getIntValue('revision'),
                      members: [
                        for (final m in bandMembers)
                          if (m.getStringValue('band') == b.id) _member(m, me),
                      ],
                    ),
              ],
            ),
      ];
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  static RemoteMember _member(RecordModel m, AuthUser me) {
    final userId = m.getStringValue('user');
    final user = m.get<RecordModel?>('expand.user');
    final name = user?.getStringValue('name') ?? '';
    final email = user?.getStringValue('email') ?? '';
    return RemoteMember(
      membershipId: m.id,
      userId: userId,
      name: userId == me.id && name.isEmpty ? me.displayName : name,
      email: userId == me.id ? me.email : (email.isEmpty ? null : email),
      role: m.getStringValue('role') == 'admin'
          ? BandRole.admin
          : BandRole.member,
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
  Future<void> setOrgMemberRole(String orgMembershipId, BandRole role) => _call(
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
    bool? membersCanEditSongs,
  }) => _call(
    () => _pb
        .collection('bands')
        .update(
          bandId,
          body: {
            'name': ?name?.trim(),
            'members_can_edit_songs': ?membersCanEditSongs,
          },
        ),
  );

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
  Future<CreatedInvite> createInvite(String organizationId) async {
    final data = await _send(
      '/api/realchord/invites',
      method: 'POST',
      body: {'organization': organizationId},
    );
    return CreatedInvite(
      id: data['id'] as String,
      url: data['url'] as String,
      expires: DateTime.parse(data['expires'] as String),
    );
  }

  @override
  Future<List<InviteInfo>> fetchInvites(String organizationId) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      final filter = _pb.filter('organization = {:org}', {
        'org': organizationId,
      });
      final invites = await _pb
          .collection('invites')
          .getFullList(filter: filter, sort: '-created');
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
            joined: [
              for (final m in joined)
                if (m.getStringValue('invite') == i.id)
                  m.get<RecordModel?>('expand.user')?.getStringValue('name') ??
                      '',
            ],
          ),
      ];
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> revokeInvite(String inviteId) => _call(
    () => _pb.collection('invites').update(inviteId, body: {'revoked': true}),
  );

  static InviteStatus _status(String value) => switch (value) {
    'expired' => InviteStatus.expired,
    'revoked' => InviteStatus.revoked,
    _ => InviteStatus.valid,
  };

  @override
  Future<InvitePreview> previewInvite(String token) async {
    final data = await _send('/api/realchord/invites/${_token(token)}');
    final org = data['organization'] as Map<String, dynamic>;
    return InvitePreview(
      organizationId: org['id'] as String,
      organizationName: org['name'] as String,
      status: _status(data['status'] as String),
      alreadyMember: data['member'] as bool,
    );
  }

  @override
  Future<String> redeemInvite(String token) async {
    final data = await _send(
      '/api/realchord/invites/${_token(token)}/redeem',
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
  );

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
      items: items is List
          ? [for (final i in items) (i as Map).cast<String, dynamic>()]
          : const [],
      revision: r.getIntValue('revision'),
      deleted: r.getBoolValue('deleted'),
    );
  }

  Future<List<RecordModel>> _since(
    String collection,
    String scopeField,
    String scope,
    int since,
  ) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      return await _pb
          .collection(collection)
          .getFullList(
            filter: _pb.filter(
              '$scopeField = {:scope} && revision > {:since}',
              {'scope': scope, 'since': since},
            ),
            sort: 'revision',
          );
    } on ClientException catch (e) {
      throw _map(e);
    }
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
      return _song(await _pb.collection('songs').getOne(id));
    } on ClientException catch (e) {
      if (e.statusCode == 404) return null;
      throw _map(e);
    }
  }

  @override
  Future<RemoteSong> pushSong(RemoteSong song, {required bool create}) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    final body = {
      'title': song.title,
      'chordpro': song.chordpro,
      'deleted': song.deleted,
    };
    try {
      final r = create
          ? await _pb
                .collection('songs')
                .create(
                  body: {
                    'id': song.id,
                    'organization': song.organizationId,
                    ...body,
                  },
                )
          : await _pb
                .collection('songs')
                .update(song.id, body: {...body, 'revision': song.revision});
      return _song(r);
    } on ClientException catch (e) {
      if (e.statusCode == 409) {
        throw BackendException(BackendErrorKind.conflict, e.response);
      }
      throw _map(e);
    }
  }

  @override
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create}) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    final body = {
      'name': set.name,
      'gig_date':
          set.gigDate?.toUtc().toIso8601String().replaceFirst('T', ' ') ?? '',
      'venue': set.venue ?? '',
      'items': set.items,
      'deleted': set.deleted,
    };
    try {
      final r = create
          ? await _pb
                .collection('setlists')
                .create(body: {'id': set.id, 'band': set.bandId, ...body})
          : await _pb.collection('setlists').update(set.id, body: body);
      return _set(r);
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

  @override
  Stream<String> watchChanges() {
    const collections = ['songs', 'setlists', 'attachments', 'bands'];
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
            debugPrint('Realtime subscription for $c failed: $e');
          }
        }
      },
      onCancel: () async {
        for (final unsubscribe in unsubscribers) {
          try {
            await unsubscribe();
          } catch (_) {}
        }
      },
    );
    return controller.stream;
  }

  Future<Map<String, dynamic>> _send(
    String path, {
    String method = 'GET',
    Map<String, dynamic> body = const {},
  }) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      final result = await _pb.send<dynamic>(path, method: method, body: body);
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

  Future<void> _call(Future<Object?> Function() request) async {
    if (currentUser == null) {
      throw const BackendException(BackendErrorKind.signedOut);
    }
    try {
      await request();
    } on ClientException catch (e) {
      throw _map(e);
    }
  }

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
    if (invite && e.statusCode == 410) {
      final data = e.response['data'];
      final code = data is Map && data['token'] is Map
          ? (data['token'] as Map)['code']
          : null;
      return BackendException(
        code == 'revoked'
            ? BackendErrorKind.inviteRevoked
            : BackendErrorKind.inviteExpired,
        e.response,
      );
    }
    if (invite && e.statusCode == 404) {
      return BackendException(BackendErrorKind.inviteUnknown, e.response);
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
