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

  /// Releases resources.
  void dispose();
}
