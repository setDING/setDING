import 'package:flutter/foundation.dart';

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

  /// Releases resources.
  void dispose();
}
