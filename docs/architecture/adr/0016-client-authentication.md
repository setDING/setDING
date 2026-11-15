# ADR-0016: Client authentication and session storage

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Phase 1 adds accounts (ADR-0005) on the PocketBase server (ADR-0004, ADR-0015).
The app is offline-first (ADR-0001): it must start and work on stage without a
network, also weeks after the last sign-in, and it must keep working without an
account at all. The session (auth token and user record) has to survive app
restarts and is a credential, so it must not be stored in plain text.

## Decision

### Backend access

- The app talks to the server only through the **`SyncBackend` interface**
  (`app/lib/sync/sync_backend.dart`); `PocketBaseBackend` implements it with the
  official **PocketBase Dart SDK**, pinned to an exact version (`pocketbase: 0.26.0`)
  like the server (`PB_VERSION`) and updated deliberately.
- The server URL is a device setting, default **`https://api.realchord.app`**;
  it can be changed for a local test server (`make backend`). Changing it signs out,
  and a stored session is only used for the server it belongs to.

### Accounts

- Email and password: **sign up** (name, email, password, at least 8 characters),
  **sign in**, **sign out**, **password reset** by email. The user is signed in
  directly after signing up; email verification is not required.
- Signing in is optional. Without an account the app keeps working locally as in
  the MVP; band features (#15 onwards) need an account.
- Signing out keeps all songs and sets on the device.

### Session storage

- The session is stored with **`flutter_secure_storage`**: Keychain (iOS),
  Android Keystore-backed encrypted preferences, Windows Credential Manager /
  DPAPI, libsecret on Linux. If no secure storage is available (e.g. a Linux
  desktop without Secret Service), the app starts signed out instead of failing.
- Isolated test instances (`REALCHORD_DATA_DIR`, `make dev`) keep their session in
  a file in their data directory, so they never touch the session of an installed app.

### Offline behaviour

- A stored session counts as **signed in even if its token has expired**; nothing
  in the app blocks on the network.
- When the app starts and the server is reachable, the session is **refreshed**
  (sliding expiry). An expired token or a session the server rejects (401/403/404)
  signs the user out, but only once the server has answered; network errors never
  sign out. The SDK's automatic clearing of expired tokens is disabled for this.
- User tokens are valid for **30 days** (server migration, PocketBase default: 5
  days), so a member who is offline for a few weeks does not have to sign in again.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **`flutter_secure_storage`** (chosen) | Platform key stores on all target platforms, widely used | Native dependency (libsecret on Linux) |
| `shared_preferences` | Already used, no new dependency | Token stored in plain text |
| Storing the session in the local SQLite DB | One place for all data | Plain text unless the DB is encrypted (SQLCipher: heavier) |
| **Keep expired sessions while offline** (chosen) | Works on stage after weeks offline | The UI may show "signed in" with a token the server will reject; sync then asks to sign in again |
| Sign out as soon as the token expires (SDK default) | Simple | Members lose their session while offline, against ADR-0001 |
| Longer tokens (e.g. 1 year) | Hardly any re-login | A stolen token stays valid long; 30 days plus refresh on every online start is enough |
| Magic link / OTP sign-in | No password | Needs SMTP and deep links first; can be added later (PocketBase supports OTP) |

## Consequences

- The UI (settings → account) and later the sync engine depend on `SyncBackend`,
  not on PocketBase; tests use a fake backend.
- Linux builds need the libsecret development files (`libsecret-1`).
- App integration tests start a real PocketBase with the repository's schema
  (`server/lib/pocketbase_harness.dart`), like the server tests.
- Password reset only works once the server can send email (SMTP, open point).

## Decision log

- 2026-11-15: Proposed with the implementation of issue #14.
- 2026-11-15: Accepted by the owner.
- 2026-11-15: Session on web (ADR-0018, accepted): kept for the tab only by default, "Stay signed in" unchecked; signing out deletes the local data of that browser; the server URL defaults to the page's origin.
- 2026-11-15: Signed out, the app offers "Sign in" and "Join with invitation" side by side (issue #31). Joining takes the link first and then offers "Create account" or "Sign in"; afterwards it continues to the invitation.

## Open points

- **SMTP** for the production server (password reset; later email verification and
  invitations by mail): provider and sender address are the owner's decision.
- Changing the name, email and password of the account in the app.
- Deleting the account (see ADR-0015, open points).
- Sign-in with OTP or OAuth (Apple/Google) instead of a password.
