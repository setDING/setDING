import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/band_role.dart';
import '../data/database.dart' show PlayedValues, SetItemEntry, SetItemType;
import '../data/marker_icons.dart';
import '../data/outbox.dart' show SongLinkField;
import '../midi/midi_message.dart';

export '../data/band_role.dart';
export '../data/outbox.dart' show SongLinkField;

/// Default setDING server (ADR-0014).
const defaultServerUrl = 'https://api.setding.app';

/// The signed-in user.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  /// Name to show in the UI; falls back to the email address.
  String get displayName => name.trim().isEmpty ? email : name.trim();

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, email, name);
}

/// Why a backend call failed; the UI shows a message per kind.
enum BackendErrorKind {
  /// No connection to the server.
  network,

  /// Wrong email or password.
  invalidCredentials,

  /// An account with this email address already exists.
  emailTaken,

  /// The email address is not valid.
  invalidEmail,

  /// The password does not meet the server's requirements.
  weakPassword,

  /// The band must keep at least one admin (ADR-0005).
  lastAdmin,

  /// The account cannot be deleted while the person is the only admin of
  /// an organization (ADR-0052).
  soleOrgAdmin,

  /// The record does not exist or the user may not change it.
  notAllowed,

  /// The person is not a member of the band's organization.
  notOrgMember,

  /// The invitation link is unknown (mistyped or deleted).
  inviteUnknown,

  /// The invitation link has expired (valid for 7 days).
  inviteExpired,

  /// The invitation link was revoked by an admin.
  inviteRevoked,

  /// The link cannot be shown again: it was created before the server kept
  /// tokens, or the server has no key for them (issue #579).
  inviteNotStored,

  /// The founder invitation was used already (ADR-0024).
  inviteUsed,

  /// The server only accepts new accounts with an invitation (ADR-0024).
  invitationRequired,

  /// The email address is not confirmed yet; the server sent a mail
  /// (ADR-0024).
  emailNotVerified,

  /// New organizations need a founder invitation on this server (ADR-0024).
  founderInvitationRequired,

  /// The song was changed on the server since the local change was based on
  /// it (ADR-0004); the user decides.
  conflict,

  /// Not signed in.
  signedOut,

  /// This app version is older than the server accepts (HTTP 426,
  /// ADR-0029); the person has to update setDING.
  updateRequired,

  /// Any other error reported by the server.
  server,
}

class BackendException implements Exception {
  const BackendException(this.kind, [this.detail]);

  final BackendErrorKind kind;

  /// Technical detail for logs; never shown to the user.
  final Object? detail;

  @override
  String toString() => 'BackendException(${kind.name}, $detail)';
}

/// A member of an organization or a band as reported by the server.
/// [R] is [OrgRole] for people of an organization and [BandRole] for band
/// members (ADR-0023).
@immutable
class RemoteMember<R extends Enum> {
  const RemoteMember({
    required this.membershipId,
    required this.userId,
    required this.name,
    this.email,
    required this.role,
    this.revision = 0,
  });

  final String membershipId;
  final String userId;
  final String name;

  /// Only known for the signed-in user (other addresses are not public).
  final String? email;
  final R role;
  final int revision;
}

/// A band visible to the signed-in user, with its active members.
@immutable
class RemoteBand {
  const RemoteBand({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.revision,
    required this.members,
    this.staleAfterMonths = 0,
  });

  final String id;
  final String organizationId;
  final String name;
  final int revision;
  final List<RemoteMember<BandRole>> members;

  /// Months after which a song counts as not played for a while; 0 = the
  /// default (ADR-0046).
  final int staleAfterMonths;
}

/// How often a band of an organization played a song, as the server sums it
/// up (ADR-0046): never the sets themselves.
@immutable
class RemoteOrgPlay {
  const RemoteOrgPlay({
    required this.songId,
    required this.bandId,
    required this.bandName,
    required this.count,
    required this.last,
    this.key,
  });

  final String songId;
  final String bandId;
  final String bandName;
  final int count;
  final DateTime last;

  /// The key of the most recent play with frozen values (international
  /// notation), if any.
  final String? key;
}

/// A closed organization of the signed-in user in the trash (ADR-0044).
@immutable
class ClosedOrganization {
  const ClosedOrganization({
    required this.id,
    required this.name,
    required this.closedAt,
    required this.isAdmin,
    this.closedBy,
  });

  final String id;
  final String name;
  final DateTime closedAt;

  /// The user's role there is admin: they may restore it.
  final bool isAdmin;

  /// Name of the person who closed it, if known.
  final String? closedBy;
}

/// A band in the trash of its organization (ADR-0044).
@immutable
class DeletedBand {
  const DeletedBand({
    required this.id,
    required this.name,
    required this.deletedAt,
  });

  final String id;
  final String name;
  final DateTime deletedAt;
}

/// An organization of the signed-in user (ADR-0017) with its people and the
/// bands the user can see.
@immutable
class RemoteOrganization {
  const RemoteOrganization({
    required this.id,
    required this.name,
    required this.revision,
    required this.members,
    required this.bands,
  });

  final String id;
  final String name;
  final int revision;
  final List<RemoteMember<OrgRole>> members;
  final List<RemoteBand> bands;
}

/// A song as stored on the server (ADR-0017: per organization).
@immutable
class RemoteSong {
  const RemoteSong({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.chordpro,
    this.revision = 0,
    this.deleted = false,
    this.deletedAt,
    this.purged = false,
    this.createdBy,
    this.updatedBy,
    this.workId,
    this.language,
    this.contentRevision = 0,
    this.created,
    this.reviewState,
    this.reviewReason,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String organizationId;
  final String title;
  final String chordpro;

  /// Review status (ADR-0060): `to_review` or null (approved), with its
  /// reason; last writer wins, sent on create and by
  /// [SyncBackend.pushSongReview], never with an update of the content.
  final String? reviewState;
  final String? reviewReason;

  /// Who set the review status and when; set by the server, never sent.
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final int revision;
  final bool deleted;

  /// When it was deleted, for the trash (ADR-0043): sent with a deletion
  /// (it may have happened offline), set by the server otherwise.
  final DateTime? deletedAt;

  /// Content purged by the server 30 days after the deletion (ADR-0043),
  /// or deleted permanently from the trash (#866): sent with a deleted
  /// record, the server then clears its content.
  final bool purged;

  /// Creator and last editor (ADR-0023); set by the server, never sent.
  final String? createdBy;
  final String? updatedBy;

  /// When the song was created on the server (`created`, #868); set by
  /// the server, never sent. Null where unknown.
  final DateTime? created;

  /// Language version group and language set by hand (ADR-0053): last
  /// writer wins per field, sent on create and by [SyncBackend.pushSongLink],
  /// never with an update of the content.
  final String? workId;
  final String? language;

  /// Revision of the last change of everything but [workId] and [language]
  /// (ADR-0053), set by the server; 0 from a server before it, then
  /// [revision] counts.
  final int contentRevision;

  /// The revision the content of the song last changed at.
  int get effectiveContentRevision =>
      contentRevision > 0 ? contentRevision : revision;
}

/// A mistake report of a song as stored on the server (ADR-0060).
@immutable
class RemoteSongReport {
  const RemoteSongReport({
    required this.id,
    required this.songId,
    required this.organizationId,
    required this.category,
    this.authorId,
    this.comment = '',
    this.location,
    this.screenshot,
    this.status = 'open',
    this.resolution,
    this.resolvedBy,
    this.resolvedAt,
    this.created,
    this.revision = 0,
    this.deleted = false,
    this.purged = false,
  });

  final String id;
  final String songId;
  final String organizationId;

  /// Set by the server: the person who reported it; null once they deleted
  /// their account.
  final String? authorId;
  final String category;
  final String comment;

  /// Where in the song (JSON object), or null.
  final Map<String, dynamic>? location;

  /// Name of the screenshot file on the server, or null.
  final String? screenshot;
  final String status;
  final String? resolution;

  /// Set by the server when the report is resolved.
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime? created;
  final int revision;
  final bool deleted;
  final bool purged;
}

/// A band arrangement as stored on the server (ADR-0025).
@immutable
class RemoteArrangement {
  const RemoteArrangement({
    required this.id,
    required this.bandId,
    required this.songId,
    this.transpose = 0,
    this.sequence,
    this.tempo,
    this.revision = 0,
    this.deleted = false,
    this.updatedBy,
  });

  final String id;
  final String bandId;
  final String songId;
  final int transpose;
  final String? sequence;
  final int? tempo;
  final int revision;
  final bool deleted;

  /// Last editor (ADR-0045); set by the server, never sent.
  final String? updatedBy;
}

/// A set as stored on the server: its items as one JSON array
/// (ADR-0015), each `{id, type, song, transpose, sequence, note}`.
@immutable
class RemoteSet {
  const RemoteSet({
    required this.id,
    required this.bandId,
    required this.name,
    this.gigDate,
    this.venue,
    this.origin,
    this.items = const [],
    this.revision = 0,
    this.deleted = false,
    this.deletedAt,
    this.purged = false,
    this.updatedBy,
    this.lineup = const [],
    this.lineupCustom = false,
  });

  final String id;
  final String bandId;
  final String name;
  final DateTime? gigDate;
  final String? venue;

  /// The people who play the set (user IDs) when [lineupCustom] is set;
  /// otherwise the whole band (ADR-0061).
  final List<String> lineup;
  final bool lineupCustom;

  /// The set this one was imported from (ADR-0043 §1b).
  final String? origin;
  final List<RemoteSetItem> items;
  final int revision;
  final bool deleted;

  /// When it was deleted, for the trash (ADR-0043): sent with a deletion
  /// (it may have happened offline), set by the server otherwise.
  final DateTime? deletedAt;

  /// Content purged by the server 30 days after the deletion (ADR-0043),
  /// or deleted permanently from the trash (#866): sent with a deleted
  /// record, the server then clears its content.
  final bool purged;

  /// Last editor (ADR-0045); set by the server, never sent.
  final String? updatedBy;
}

/// The sets the signed-in user plays as a substitute (ADR-0061), from
/// `GET /api/setding/lineup`: always the complete state, which replaces
/// what the device has.
@immutable
class RemoteLineup {
  const RemoteLineup({
    this.sets = const [],
    this.bands = const [],
    this.arrangements = const [],
  });

  final List<RemoteSet> sets;

  /// The bands of [sets]: only their names, never their members.
  final List<({String id, String name, String organizationId})> bands;

  /// The band arrangements of the songs in [sets].
  final List<RemoteArrangement> arrangements;
}

/// An item of a set as stored on the server: one entry of the JSON array
/// `setlists.items` (ADR-0015).
@immutable
class RemoteSetItem {
  const RemoteSetItem({
    required this.id,
    required this.type,
    this.songId,
    this.transpose = 0,
    this.sequence,
    this.note,
    this.icon,
    this.played,
    this.extra = const {},
  });

  /// Reads an entry; every type other than `song` is a marker, which gets
  /// an icon from its type when an older app wrote it (ADR-0047). Fields
  /// this version does not know are kept in [extra] (ADR-0046).
  factory RemoteSetItem.fromJson(Map<String, dynamic> json) {
    final kind = readItemType(json['type'], json['icon']);
    return RemoteSetItem(
      id: json['id'] as String? ?? '',
      type: kind.type,
      icon: kind.icon,
      songId: json['song'] as String?,
      transpose: (json['transpose'] as num?)?.toInt() ?? 0,
      sequence: json['sequence'] as String?,
      note: json['note'] as String?,
      played: switch (json['played']) {
        final Map<String, dynamic> played => PlayedValues.fromJson(played),
        _ => null,
      },
      extra: {
        for (final e in json.entries)
          if (!_knownFields.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// An item of the local database.
  factory RemoteSetItem.fromEntry(SetItemEntry i) => RemoteSetItem(
    id: i.id,
    type: i.type,
    songId: i.songId,
    transpose: i.transpose,
    sequence: i.sequence,
    note: i.note,
    icon: i.type == SetItemType.marker ? i.icon : null,
    played: i.played,
    extra: decodeExtra(i.extra),
  );

  static const _knownFields = {
    'id',
    'type',
    'song',
    'transpose',
    'sequence',
    'note',
    'icon',
    'played',
  };

  /// Empty when the server sent none (older clients); a new ID is used.
  final String id;
  final SetItemType type;
  final String? songId;
  final int transpose;
  final String? sequence;
  final String? note;

  /// Key of a marker's icon (ADR-0047); null for songs.
  final String? icon;

  /// How the song was played, frozen on the gig day (ADR-0046).
  final PlayedValues? played;

  /// Fields of newer clients, sent back unchanged.
  final Map<String, dynamic> extra;

  /// The local form of [extra]: null when there are none.
  String? get extraJson => extra.isEmpty ? null : jsonEncode(extra);

  /// Reads the local form of [extra]; a value that cannot be read is empty.
  static Map<String, dynamic> decodeExtra(String? json) {
    if (json == null) return const {};
    try {
      final value = jsonDecode(json);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }

  /// The JSON form, without default values; the known fields win over
  /// [extra].
  Map<String, dynamic> toJson() => {
    ...extra,
    'id': id,
    'type': writeItemType(type, icon),
    'song': ?songId,
    if (transpose != 0) 'transpose': transpose,
    'sequence': ?sequence,
    'note': ?note,
    'icon': ?icon,
    if (played case final played? when !played.isEmpty)
      'played': played.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is RemoteSetItem &&
      other.id == id &&
      other.type == type &&
      other.songId == songId &&
      other.transpose == transpose &&
      other.sequence == sequence &&
      other.note == note &&
      other.icon == icon &&
      other.played == played &&
      mapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    songId,
    transpose,
    sequence,
    note,
    icon,
    played,
    extra.length,
  );
}

/// Personal adjustments of a user for a song as stored on the server
/// (ADR-0020); [data] holds the fields of layer 3 (ADR-0006), [midi] the
/// keyboard program in its own field (ADR-0039) and [midiPrograms] the
/// programs per device profile (ADR-0042).
@immutable
class RemoteOverlay {
  const RemoteOverlay({
    required this.id,
    required this.userId,
    required this.songId,
    this.data = const {},
    this.midi,
    this.midiPrograms,
    this.revision = 0,
    this.deleted = false,
  });

  final String id;
  final String userId;
  final String songId;
  final Map<String, dynamic> data;

  /// Keyboard program (`overlays.midi`); a separate field, so clients
  /// that only push [data] leave it untouched (ADR-0039).
  final MidiProgram? midi;

  /// Keyboard programs per device profile (`overlays.midi_programs`,
  /// ADR-0042); null = never written. v0.16.0 clients leave it untouched.
  final MidiPrograms? midiPrograms;
  final int revision;
  final bool deleted;
}

/// Freehand annotations of a user on a song as stored on the server
/// (ADR-0032): one record per user, song and target (the ChordPro text, or
/// the PDF attachment [attachmentId]); [data] maps stroke IDs to strokes or
/// tombstones. An update is merged per stroke ID by the server.
@immutable
class RemoteAnnotations {
  const RemoteAnnotations({
    required this.id,
    required this.userId,
    required this.songId,
    this.attachmentId,
    this.data = const {},
    this.revision = 0,
    this.deleted = false,
  });

  final String id;
  final String userId;
  final String songId;

  /// Null for the ChordPro text.
  final String? attachmentId;
  final Map<String, dynamic> data;
  final int revision;
  final bool deleted;
}

/// Personal settings of a user as stored on the server (ADR-0027); [data]
/// holds the personal settings (layer 4a) by key.
@immutable
class RemoteUserSettings {
  const RemoteUserSettings({
    required this.id,
    required this.userId,
    this.data = const {},
    this.revision = 0,
  });

  final String id;
  final String userId;
  final Map<String, dynamic> data;
  final int revision;
}

/// PDF attachment metadata as stored on the server (ADR-0009, ADR-0017).
@immutable
class RemoteAttachment {
  const RemoteAttachment({
    required this.id,
    required this.organizationId,
    required this.songId,
    required this.name,
    this.file,
    this.pages,
    this.sizeBytes = 0,
    this.revision = 0,
    this.deleted = false,
    this.deletedAt,
    this.purged = false,
    this.updatedBy,
  });

  final String id;
  final String organizationId;
  final String songId;
  final String name;

  /// File name on the server (download), null before the upload.
  final String? file;
  final int? pages;
  final int sizeBytes;
  final int revision;
  final bool deleted;

  /// When it was deleted, for the trash (ADR-0043): sent with a deletion
  /// (it may have happened offline), set by the server otherwise.
  final DateTime? deletedAt;

  /// Content purged by the server 30 days after the deletion (ADR-0043);
  /// never sent.
  final bool purged;

  /// Last editor (ADR-0045); set by the server, never sent.
  final String? updatedBy;
}

/// State of an invitation link.
/// `used` only for founder invitations, which can be used once (ADR-0024).
enum InviteStatus { valid, expired, revoked, used }

/// Who may create accounts on the server (ADR-0024). [unknown] when the
/// server could not be asked; the app then offers nothing that needs an
/// open server.
enum RegistrationMode { open, inviteOnly, unknown }

/// Settings of the server the app needs before signing in (ADR-0024).
@immutable
class ServerConfig {
  const ServerConfig({
    this.registration = RegistrationMode.open,
    this.emailVerification = false,
    this.minClientVersion,
    this.latestClientVersion,
  });

  /// Assumed when the server cannot be asked (offline, older server): not
  /// treated as open, so the app offers no sign-up without an invitation and
  /// no new organization (issue #829); the server enforces its own settings.
  static const unknown = ServerConfig(registration: RegistrationMode.unknown);

  final RegistrationMode registration;

  /// New accounts must confirm their email address before signing in.
  final bool emailVerification;

  /// The lowest app version the server accepts (ADR-0029); null if the
  /// server does not say (older server, or not reachable).
  final String? minClientVersion;

  /// The newest app release (ADR-0036); null if the server does not say
  /// (older server, deployed from a working tree, or not reachable).
  final String? latestClientVersion;

  bool get inviteOnly => registration == RegistrationMode.inviteOnly;

  /// Anyone may sign up and found organizations; false while the mode is
  /// [RegistrationMode.unknown].
  bool get openRegistration => registration == RegistrationMode.open;
}

/// An invitation link with its URL: right after creating it, or shown again
/// while it is valid (the server keeps the token encrypted, issue #579).
@immutable
class CreatedInvite {
  const CreatedInvite({
    required this.id,
    required this.url,
    required this.expires,
  });

  final String id;
  final String url;
  final DateTime expires;
}

/// An invitation link of an organization as admins see it.
@immutable
class InviteInfo {
  const InviteInfo({
    required this.id,
    required this.created,
    required this.expires,
    required this.revoked,
    this.joined = const [],
    this.bandName,
  });

  final String id;
  final DateTime created;
  final DateTime expires;
  final bool revoked;

  /// Names of the people who joined with this link.
  final List<String> joined;

  /// The band the link also leads into (ADR-0023); null for links into the
  /// organization only.
  final String? bandName;

  InviteStatus statusAt(DateTime now) => revoked
      ? InviteStatus.revoked
      : (expires.isBefore(now) ? InviteStatus.expired : InviteStatus.valid);
}

/// What a link leads to, shown before joining.
@immutable
class InvitePreview {
  const InvitePreview({
    required this.organizationId,
    required this.organizationName,
    required this.status,
    required this.alreadyMember,
    this.founder = false,
    this.bandName,
  });

  /// Empty for a founder invitation (the organization does not exist yet).
  final String organizationId;
  final String organizationName;
  final InviteStatus status;
  final bool alreadyMember;

  /// Redeeming founds the organization [organizationName] with the user as
  /// its admin (ADR-0024).
  final bool founder;

  /// The band the link also leads into (invitation of a band leader,
  /// ADR-0023).
  final String? bandName;
}

/// Extracts the token from an invitation link (`https://…/invite/<token>`,
/// `setding://invite/<token>`) or a pasted token; null if there is none.
String? inviteTokenFrom(String input) {
  final text = input.trim();
  final inLink = RegExp(r'invite/([A-Za-z0-9]{16,64})').firstMatch(text);
  if (inLink != null) return inLink.group(1);
  return RegExp(r'^[A-Za-z0-9]{16,64}$').hasMatch(text) ? text : null;
}

/// Access to the setDING server (ADR-0004). The app talks to the backend
/// only through this interface, so the backend product can be replaced
/// without touching the rest of the app.
///
/// The session survives app restarts and works offline: a stored session is
/// considered signed in even if its token has expired; it is refreshed when
/// the server is reachable.
abstract class SyncBackend {
  /// Server base URL, e.g. [defaultServerUrl].
  String get serverUrl;

  /// The signed-in user, or null.
  AuthUser? get currentUser;

  /// Emits the user whenever the session changes (sign-in, sign-out,
  /// refresh, session invalidated by the server).
  Stream<AuthUser?> get userChanges;

  /// Signs in with email and password.
  Future<AuthUser> signIn({required String email, required String password});

  /// Creates an account and signs in. On an invite-only server the
  /// [invite] token is required (ADR-0024); it is not redeemed here. If the
  /// server requires email verification, signing in fails with
  /// [BackendErrorKind.emailNotVerified] after the account was created.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String name,
    String? invite,
  });

  /// Asks the server to send a password reset email.
  Future<void> requestPasswordReset(String email);

  /// Asks the server to send the email verification mail again.
  Future<void> requestVerification(String email);

  /// Registration mode and email verification of the server; works without
  /// an account (ADR-0024).
  Future<ServerConfig> fetchServerConfig();

  /// Refreshes the stored session if the server is reachable. Network errors
  /// are ignored (offline); a session rejected by the server is cleared.
  Future<void> refreshSession();

  /// Signs out on this device. Local songs and sets are kept.
  Future<void> signOut();

  /// Changes the display name of the signed-in user (issue #779); bandmates
  /// see it after their next sync.
  Future<AuthUser> changeName(String name);

  /// Changes the password of the signed-in user (issue #779). Fails with
  /// [BackendErrorKind.invalidCredentials] if [oldPassword] is wrong. The
  /// server invalidates every session of the account; this device signs in
  /// again with [newPassword], other devices are signed out.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// Deletes the account of the signed-in user for good (ADR-0052) and
  /// signs out. Fails with [BackendErrorKind.invalidCredentials] if
  /// [password] is wrong and with [BackendErrorKind.soleOrgAdmin] while
  /// the person is the only admin of an organization.
  Future<void> deleteAccount(String password);

  // Organizations and bands (ADR-0005, ADR-0017) ------------------------------

  /// The organizations of the signed-in user with their people and the
  /// bands the user can see (member of the band, or organization admin).
  Future<List<RemoteOrganization>> fetchOrganizations();

  /// Renames an organization (organization admins).
  Future<void> renameOrganization(String organizationId, String name);

  /// Changes the organization role of a person (organization admins).
  Future<void> setOrgMemberRole(String orgMembershipId, OrgRole role);

  /// Removes a person from an organization and its bands (organization
  /// admins), or leaves it (own membership).
  Future<void> removeOrgMember(String orgMembershipId);

  /// Creates a band in [organizationId] (organization admins), or with a new
  /// organization of the same name when null. The signed-in user becomes
  /// the band's first admin.
  Future<void> createBand({
    required String id,
    required String name,
    String? organizationId,
  });

  /// Changes band settings (band and organization admins).
  Future<void> updateBand(String bandId, {String? name, int? staleAfterMonths});

  /// Deletes a band with its sets, arrangements and memberships
  /// (organization admins, ADR-0044); it stays 30 days in the trash.
  Future<void> deleteBand(String bandId);

  /// Restores a deleted band with what was deleted with it (organization
  /// admins, ADR-0044).
  Future<void> restoreBand(String bandId);

  /// Deleted bands of [organizationId] that can still be restored, most
  /// recently deleted first (organization admins, ADR-0044).
  Future<List<DeletedBand>> fetchDeletedBands(String organizationId);

  /// How often each band of [organizationId] played each song of its
  /// library (ADR-0046); members of the organization only.
  Future<List<RemoteOrgPlay>> fetchOrgPlays(String organizationId);

  /// Closes an organization with everything in it (organization admins,
  /// ADR-0044); it stays 30 days in the trash.
  Future<void> closeOrganization(String organizationId);

  /// Restores a closed organization (its admins, ADR-0044).
  Future<void> restoreOrganization(String organizationId);

  /// The closed organizations of the signed-in user that can still be
  /// restored, most recently closed first (ADR-0044).
  Future<List<ClosedOrganization>> fetchClosedOrganizations();

  /// Adds a person of the band's organization to the band.
  Future<void> addBandMember(String bandId, String userId, BandRole role);

  /// Changes the band role of a member (band and organization admins).
  Future<void> setMemberRole(String membershipId, BandRole role);

  /// Removes a member from a band, or leaves it (own membership).
  Future<void> removeMember(String membershipId);

  // Invitations (ADR-0005, ADR-0017) ---------------------------------------------

  /// Creates an invitation link into an organization (organization admins).
  /// With [bandId], the link also adds people to that band; band leaders
  /// may only create such links (ADR-0023).
  Future<CreatedInvite> createInvite(String organizationId, {String? bandId});

  /// The valid links of an organization, newest first: all of them for
  /// organization admins, those of the leader's bands otherwise; with
  /// [bandId] only the links into that band. Revoked and expired links are
  /// left out (issue #579).
  Future<List<InviteInfo>> fetchInvites(
    String organizationId, {
    String? bandId,
  });

  /// The URL of a valid link again, for the people who see it in
  /// [fetchInvites] (issue #579).
  Future<CreatedInvite> fetchInviteLink(String inviteId);

  /// Revokes a link; people who joined stay members.
  Future<void> revokeInvite(String inviteId);

  /// The organization and state of a link; works without an account
  /// (ADR-0024).
  Future<InvitePreview> previewInvite(String token);

  /// Joins the organization of a link as member; returns its ID.
  Future<String> redeemInvite(String token);

  // Songs and sets (ADR-0004) ------------------------------------------------------

  /// Songs of an organization changed after revision [since] (also deleted
  /// ones), in revision order.
  Future<List<RemoteSong>> pullSongs(String organizationId, int since);

  /// Sets of a band changed after revision [since], in revision order.
  Future<List<RemoteSet>> pullSets(String bandId, int since);

  /// Arrangements of a band changed after revision [since], in revision
  /// order (ADR-0025).
  Future<List<RemoteArrangement>> pullArrangements(String bandId, int since);

  /// Creates or updates an arrangement (last writer wins) and returns the
  /// server state.
  Future<RemoteArrangement> pushArrangement(
    RemoteArrangement arrangement, {
    required bool create,
  });

  /// The current server state of a song, or null if it does not exist.
  Future<RemoteSong?> fetchSong(String id);

  /// Creates ([create]) or updates a song and returns the server state. An
  /// update sends [song]`.revision` as base revision; if the server has moved
  /// on, it fails with [BackendErrorKind.conflict].
  Future<RemoteSong> pushSong(RemoteSong song, {required bool create});

  /// Sets one link field of an existing song to [value] (null clears it),
  /// last writer wins without a base revision (ADR-0053), and returns the
  /// server state.
  Future<RemoteSong> pushSongLink(
    String songId,
    SongLinkField field,
    String? value,
  );

  /// Sets the review status of an existing song ([state] `to_review` or
  /// null for approved, with [reason]), last writer wins without a base
  /// revision (ADR-0060), and returns the server state.
  Future<RemoteSong> pushSongReview(
    String songId,
    String? state,
    String? reason,
  );

  /// Mistake reports of an organization changed after revision [since]
  /// that the signed-in user may read (ADR-0060), in revision order.
  Future<List<RemoteSongReport>> pullSongReports(
    String organizationId,
    int since,
  );

  /// Creates ([create]) or updates a mistake report and returns the server
  /// state. An update sends the fields of the author ([asAuthor]: category,
  /// comment, location) and of the person who resolves it ([asApprover]:
  /// resolution); the status always. [screenshot] (with its file name,
  /// e.g. `x.webp`) is uploaded with the create or added to a report
  /// without one; screenshots are never replaced.
  Future<RemoteSongReport> pushSongReport(
    RemoteSongReport report, {
    required bool create,
    bool asAuthor = true,
    bool asApprover = false,
    List<int>? screenshot,
    String? screenshotName,
  });

  /// The screenshot [file] of the report [reportId] (protected, needs read
  /// access). Throws a [BackendException].
  Future<Uint8List> fetchReportScreenshot(String reportId, String file);

  /// Creates or updates a set (last writer wins) and returns the server
  /// state.
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create});

  /// The sets the signed-in user plays as a substitute, with their bands'
  /// names and the arrangements of their songs (ADR-0061). Throws a
  /// [BackendException].
  Future<RemoteLineup> fetchLineup();

  /// PDF attachments of an organization changed after revision [since].
  Future<List<RemoteAttachment>> pullAttachments(
    String organizationId,
    int since,
  );

  /// Uploads a new attachment with its file ([bytes], PDF), or updates the
  /// metadata (name, deleted) of an existing one. Files are immutable.
  Future<RemoteAttachment> pushAttachment(
    RemoteAttachment attachment, {
    required bool create,
    List<int>? bytes,
  });

  /// Personal adjustments of the signed-in user changed after revision
  /// [since], in revision order (ADR-0020).
  Future<List<RemoteOverlay>> pullOverlays(int since);

  /// Creates ([create]) or updates personal adjustments of the signed-in
  /// user and returns the server state (last writer wins).
  Future<RemoteOverlay> pushOverlay(
    RemoteOverlay overlay, {
    required bool create,
  });

  /// Annotation records of the signed-in user changed after revision
  /// [since], in revision order (ADR-0032).
  Future<List<RemoteAnnotations>> pullAnnotations(int since);

  /// Creates ([create]) or updates an annotation record of the signed-in
  /// user with the strokes in [RemoteAnnotations.data] (merged per stroke on
  /// the server) and returns the server state.
  Future<RemoteAnnotations> pushAnnotations(
    RemoteAnnotations annotations, {
    required bool create,
  });

  /// The personal settings of the signed-in user if they changed after
  /// revision [since], else null (ADR-0027).
  Future<RemoteUserSettings?> pullUserSettings(int since);

  /// Creates ([create], with all keys) or updates the personal settings of
  /// the signed-in user; an update merges the keys of [settings] into the
  /// stored ones (last writer wins per key). Returns the server state.
  Future<RemoteUserSettings> pushUserSettings(
    RemoteUserSettings settings, {
    required bool create,
  });

  /// Starts downloading attachment files (protected, need read access).
  /// The downloads share one file token and one HTTP client; close them
  /// when done.
  AttachmentDownloads openDownloads();

  /// Emits the name of a collection whenever the server reports a change
  /// (realtime, while online). Errors are not reported; delta sync catches
  /// up anyway.
  Stream<String> watchChanges();

  /// Releases resources.
  void dispose();
}

/// Downloads of attachment files during one sync run (ADR-0009).
abstract interface class AttachmentDownloads {
  /// Streams the file of [attachment] into [target]. Throws a
  /// [BackendException].
  Future<void> download(
    RemoteAttachment attachment,
    StreamSink<List<int>> target,
  );

  /// Releases the HTTP client.
  void close();
}
