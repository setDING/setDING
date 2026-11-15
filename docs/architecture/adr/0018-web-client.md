# ADR-0018: Web client for management

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

With phase 1 complete (backend, sign-in, organizations, bands, invitations, sync of
songs, sets and PDFs), all management happens in the installed app. Some people
need to manage without installing anything:

- an organization admin who prepares bands, people and the song library at an
  office PC,
- someone who receives an invitation link on a device without the app,
- a band leader who prefers a large screen and keyboard for typing songs, on a
  computer where installing the Windows app is not possible.

ADR-0005 chose one app with roles and rejected a separate web app, because a second
code base or a second renderer would make the editor preview differ from the tablet.
ADR-0002 and ADR-0005 already name a Flutter web build of the same app as the way to
offer management in the browser later.

## Decision

The management UI is offered in the browser as a **Flutter web build of the same
app** (`app/`), not as a separate web application.

### Architecture

- **The browser is another device.** The local database runs on web with drift's
  WASM backend (`sqlite3.wasm` plus the drift worker, stored in OPFS or IndexedDB).
  Repositories, the outbox and the sync engine (ADR-0004) are unchanged; the UI
  still reads and writes only locally and the sync engine talks to the server.
- **No offline guarantee on web** (exception to ADR-0001): browsers may evict
  storage, so the web client is a management tool, not a stage tool. The
  "Offline ready" status is not shown on web.
- **PDF attachments are not preloaded** on web (exception to ADR-0009): they are
  fetched from the server when opened, using PocketBase file tokens, and may be
  cached by the browser. Uploading attachments works as in the app.
- **Platform code** (`dart:io`, file paths, `path_provider`, `app_links`) is moved
  behind conditional imports with a web implementation: file import uses bytes
  instead of paths, exports (ZIP, printable set list, ADR-0013) become browser
  downloads, deep links become URL routes (`/invite/<token>`).
- **Local library hidden:** the local library "On this device" (ADR-0005) is not
  offered on web, because its data would exist only in one browser and could be
  evicted. The web client requires an account and shows only organization
  libraries.
- **Live mode with a notice:** live mode is available on web (useful for rehearsals
  at a laptop) but shows a notice that it is not offline-safe and the app should be
  used on stage. Wakelock and full screen work as far as the browser allows.
- **Same roles and rules** (ADR-0005, ADR-0017): the UI shows only what the user's
  roles allow; the server access rules stay the authority. No new server
  collections or rules are needed.

### Scope

| Feature | Web |
|---|---|
| Sign up, sign in, sign out, password reset | ✓ |
| Organizations, bands, members, roles, invitations with QR code | ✓ |
| Songs: ChordPro editor with preview, file and ZIP import, PDF attachments | ✓ |
| Sets: create, reorder, export as ZIP, text and printable PDF | ✓ |
| Personal overlays (ADR-0006) | ✓ (as on any device) |
| Local library "On this device" | – (hidden; signing in is required on web) |
| Live mode | ✓ with a notice "not offline-safe, use the app on stage" |
| "Offline ready" status | – |

### Session (ADR-0016)

Browsers have no platform key store, and web clients are often used on shared
computers:

- The session is kept for the browser tab only (`sessionStorage`) by default;
  a **"Stay signed in"** checkbox, **unchecked by default**, keeps it in
  persistent browser storage.
- Signing out on web **deletes the local database** of that browser (unlike the
  native apps, which keep songs and sets on sign-out).
- The 30-day token lifetime and the refresh on start stay the same.

### Hosting (ADR-0014)

- The web client is published at **`https://app.realchord.app`**: a second
  hostname of the Cloudflare Tunnel that points to the same PocketBase, which
  serves the web build as static files (`pb_public`). No second server.
- On web the server URL defaults to the **page's own origin**, so the web client
  calls the API on `app.realchord.app` itself: same origin, no CORS configuration.
  The apps keep `https://api.realchord.app`.
- It is deployed with the server targets (`make server-*`), built from the same
  commit as the apps.
- The invitation landing page (`/invite/<token>`) offers **"Open in the browser"**
  (`https://app.realchord.app/invite/<token>`) next to the instructions for
  installing the app.
- Adding the tunnel hostname and the DNS record is done by the owner (Cloudflare
  account, ADR-0014).

### Implementation steps

Tracked in issue #27, each step a separate PR:

1. Add the web platform: drift web setup, conditional imports for the platform
   code, `flutter build web` in `make check` and CI.
2. Web session handling and file import/export via bytes and downloads.
3. PDF attachments fetched on demand, `pdfrx` web assets.
4. Hosting in `pb_public`, deploy target, "Open in the browser" on the landing page.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Flutter web build of the same app** (chosen) | One code base, same ChordPro renderer and editor preview, same role logic, ARB texts already there, sync engine reused | Large first download (several MB), WASM database setup, some platform code needs web variants |
| Separate web app (e.g. SvelteKit) against the PocketBase API | Small and fast to load, conventional web stack | Second code base and second ChordPro parser/renderer (preview differs from the tablet, rejected in ADR-0005), translations and role logic duplicated |
| Web client online-only (no local DB, direct API calls) | No WASM database, no eviction issues | A second data access path next to repositories and sync engine; every screen would need an online variant |
| PocketBase admin UI for owners | No effort | Not for end users, no preview, bypasses the role model |
| PWA with offline support for stage use | No installation for members either | iOS storage eviction and limited wakelock (rejected in ADR-0002) |

## Consequences

- `make check` and CI also build the web target, so platform-only code that breaks
  the web build is caught early.
- `dart:io` must not be imported directly in shared code any more; new platform
  code goes behind a conditional import.
- People can join an organization from an invitation link without installing the
  app; band members still need the app for the stage.
- The server serves one more set of static files; deploying the web build is part
  of each server release.
- The roadmap moves "web client for management" from *Later* to the next phase.

## Decision log

- 2026-11-15: Proposed (owner request: manage organizations, bands and songs
  without an installed app), issue #27.
- 2026-11-15: Owner decisions on the open points: local library hidden on web; live
  mode allowed with a "not offline-safe" notice; public URL `app.realchord.app`
  (same PocketBase, same-origin API); session for the tab only by default, "Stay
  signed in" unchecked.
- 2026-11-15: Accepted by the owner.

## Open points

- Supported browsers (OPFS needs current Chrome, Edge, Firefox or Safari; fallback
  to IndexedDB on older ones).
- Register `app.realchord.app` in the tunnel and DNS (owner).
