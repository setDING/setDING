import 'dart:async';
import 'dart:convert';

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
              'name': name.trim(),
              'invite': ?invite,
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
      registration: data['registration'] == 'open'
          ? RegistrationMode.open
          : RegistrationMode.inviteOnly,
      emailVerification: data['emailVerification'] == 'required',
      minClientVersion: data['minClientVersion'] as String?,
      latestClientVersion: data['latestClientVersion'] as String?,
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
  Future<void> updateBand(String bandId, {String? name}) => _call(
    () => _pb.collection('bands').update(bandId, body: {'name': ?name?.trim()}),
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
  Future<CreatedInvite> createInvite(
    String organizationId, {
    String? bandId,
  }) async {
    final data = await _send(
      '/api/setding/invites',
      method: 'POST',
      body: {'organization': organizationId, 'band': ?bandId},
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
          '$filter && revoked = false && expires > @now'
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
  );

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
    );
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
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create}) async {
    return _signedIn(() async {
      final body = {
        'name': set.name,
        'gig_date':
            set.gigDate?.toUtc().toIso8601String().replaceFirst('T', ' ') ?? '',
        'venue': set.venue ?? '',
        'items': [for (final i in set.items) i.toJson()],
        'deleted': set.deleted,
        'deleted_at': _dateValue(set.deletedAt),
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
