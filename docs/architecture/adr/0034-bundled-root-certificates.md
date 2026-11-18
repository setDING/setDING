# ADR-0034: Bundled root certificates for the Windows client

- **Status:** Proposed
- **Date:** 2026-11-18

## Context

The released Windows app (v0.11.0) could not sign in on a Windows machine:
"No connection to the server", although the server was reachable (#489).

Dart's TLS stack (BoringSSL) on Windows trusts only the root certificates that
are already in the Windows certificate store. Windows does not ship all trusted
roots; it adds a missing root on demand when its own crypto stack (CryptoAPI,
Schannel) needs it. Chrome and Edge bring their own root stores, so browsing
does not fill the Windows store either. The certificate of `api.setding.app`
is issued by Let's Encrypt (`YE1` → `Root YE` → `ISRG Root X2` → `ISRG Root X1`);
without `ISRG Root X1`/`X2` in the store the handshake fails and the app
reports it as a network error. Running `Invoke-WebRequest` against the server
once (Schannel fetches the root) fixed it, which users cannot be expected to know.

## Decision

On Windows, the app's HTTP client (`app/lib/platform/http_client_io.dart`)
uses a `SecurityContext` with the system roots **plus the bundled ISRG roots
X1 and X2** (Let's Encrypt). They are compiled into the app as PEM constants.
All server requests (PocketBase SDK and attachment downloads) use this client
through the default `httpClientFactory` of `PocketBaseBackend`.

Other platforms keep the plain system trust: Android, iOS and Linux ship the
ISRG roots in their stores, and browsers (web client) check certificates
themselves. No extra error message for certificate failures: users cannot fix
them; the app must avoid them.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Bundle ISRG roots on Windows (chosen) | Works on any Windows machine, no user action, system roots still used | Bundled roots must be updated if the server's CA changes |
| Explain the workaround to users / own error message | No code | Users cannot fix certificate problems; first impression is a broken app |
| Native HTTP stack on Windows (WinHTTP via a plugin) | Uses Windows' own root fetching | New dependency, no maintained package for Windows |
| Certificate of a CA whose root is always in the Windows store | No code | Ties hosting to a CA choice; Cloudflare/Caddy issue Let's Encrypt certificates |
| Bundle a full root list (e.g. Mozilla's) | Covers self-hosted servers with any CA | Large, must be kept current |

## Consequences

- Windows sign-in and sync work regardless of the state of the Windows root store,
  for `api.setding.app` and for self-hosted servers with Let's Encrypt certificates.
- If the server moves to a CA outside the ISRG hierarchy, the bundled list has to be
  extended. ISRG Root X1 is valid until 2035, X2 until 2040.
- If Let's Encrypt stops serving the chain cross-signed by ISRG Root X2, `Root YE`
  (and `Root YR`) must be bundled too.

## Decision log

- 2026-11-18: Proposed after #489 (Windows sign-in failed with missing ISRG roots).

## Open points

- Bundle the new Let's Encrypt roots (`Root YE`, `Root YR`) once chains without the X2 cross-sign are served.
