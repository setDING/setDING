import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/band_role.dart';

export '../data/band_role.dart';

/// Default RealChord server (ADR-0014).
const defaultServerUrl = 'https://api.realchord.app';

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

  /// The song was changed on the server since the local change was based on
  /// it (ADR-0004); the user decides.
  conflict,

  /// Not signed in.
  signedOut,

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
@immutable
class RemoteMember {
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
  final BandRole role;
  final int revision;
}

/// A band visible to the signed-in user, with its active members.
@immutable
class RemoteBand {
  const RemoteBand({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.membersCanEditSongs,
    required this.revision,
    required this.members,
  });

  final String id;
  final String organizationId;
  final String name;
  final bool membersCanEditSongs;
  final int revision;
  final List<RemoteMember> members;
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
  final List<RemoteMember> members;
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
  });

  final String id;
  final String organizationId;
  final String title;
  final String chordpro;
  final int revision;
  final bool deleted;
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
    this.items = const [],
    this.revision = 0,
    this.deleted = false,
  });

  final String id;
  final String bandId;
  final String name;
  final DateTime? gigDate;
  final String? venue;
  final List<Map<String, dynamic>> items;
  final int revision;
  final bool deleted;
}

/// Personal adjustments of a user for a song as stored on the server
/// (ADR-0020); [data] holds the fields of layer 3 (ADR-0006).
@immutable
class RemoteOverlay {
  const RemoteOverlay({
    required this.id,
    required this.userId,
    required this.songId,
    this.data = const {},
    this.revision = 0,
    this.deleted = false,
  });

  final String id;
  final String userId;
  final String songId;
  final Map<String, dynamic> data;
  final int revision;
  final bool deleted;
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
}

/// State of an invitation link.
enum InviteStatus { valid, expired, revoked }

/// A new invitation link; the URL is only available right after creating it
/// (the server stores a hash of the token).
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
  });

  final String id;
  final DateTime created;
  final DateTime expires;
  final bool revoked;

  /// Names of the people who joined with this link.
  final List<String> joined;

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
  });

  final String organizationId;
  final String organizationName;
  final InviteStatus status;
  final bool alreadyMember;
}

/// Extracts the token from an invitation link (`https://…/invite/<token>`,
/// `realchord://invite/<token>`) or a pasted token; null if there is none.
String? inviteTokenFrom(String input) {
  final text = input.trim();
  final inLink = RegExp(r'invite/([A-Za-z0-9]{16,64})').firstMatch(text);
  if (inLink != null) return inLink.group(1);
  return RegExp(r'^[A-Za-z0-9]{16,64}$').hasMatch(text) ? text : null;
}

/// Access to the RealChord server (ADR-0004). The app talks to the backend
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

  /// Creates an account and signs in.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String name,
  });

  /// Asks the server to send a password reset email.
  Future<void> requestPasswordReset(String email);

  /// Refreshes the stored session if the server is reachable. Network errors
  /// are ignored (offline); a session rejected by the server is cleared.
  Future<void> refreshSession();

  /// Signs out on this device. Local songs and sets are kept.
  Future<void> signOut();

  // Organizations and bands (ADR-0005, ADR-0017) ------------------------------

  /// The organizations of the signed-in user with their people and the
  /// bands the user can see (member of the band, or organization admin).
  Future<List<RemoteOrganization>> fetchOrganizations();

  /// Renames an organization (organization admins).
  Future<void> renameOrganization(String organizationId, String name);

  /// Changes the organization role of a person (organization admins).
  Future<void> setOrgMemberRole(String orgMembershipId, BandRole role);

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
  Future<void> updateBand(
    String bandId, {
    String? name,
    bool? membersCanEditSongs,
  });

  /// Adds a person of the band's organization to the band.
  Future<void> addBandMember(String bandId, String userId, BandRole role);

  /// Changes the band role of a member (band and organization admins).
  Future<void> setMemberRole(String membershipId, BandRole role);

  /// Removes a member from a band, or leaves it (own membership).
  Future<void> removeMember(String membershipId);

  // Invitations (ADR-0005, ADR-0017) ---------------------------------------------

  /// Creates an invitation link into an organization (organization admins).
  Future<CreatedInvite> createInvite(String organizationId);

  /// The links of an organization, newest first (organization admins).
  Future<List<InviteInfo>> fetchInvites(String organizationId);

  /// Revokes a link; people who joined stay members.
  Future<void> revokeInvite(String inviteId);

  /// The organization and state of a link.
  Future<InvitePreview> previewInvite(String token);

  /// Joins the organization of a link as member; returns its ID.
  Future<String> redeemInvite(String token);

  // Songs and sets (ADR-0004) ------------------------------------------------------

  /// Songs of an organization changed after revision [since] (also deleted
  /// ones), in revision order.
  Future<List<RemoteSong>> pullSongs(String organizationId, int since);

  /// Sets of a band changed after revision [since], in revision order.
  Future<List<RemoteSet>> pullSets(String bandId, int since);

  /// The current server state of a song, or null if it does not exist.
  Future<RemoteSong?> fetchSong(String id);

  /// Creates ([create]) or updates a song and returns the server state. An
  /// update sends [song]`.revision` as base revision; if the server has moved
  /// on, it fails with [BackendErrorKind.conflict].
  Future<RemoteSong> pushSong(RemoteSong song, {required bool create});

  /// Creates or updates a set (last writer wins) and returns the server
  /// state.
  Future<RemoteSet> pushSet(RemoteSet set, {required bool create});

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
  Future<void> download(RemoteAttachment attachment, File target);

  /// Releases the HTTP client.
  void close();
}
