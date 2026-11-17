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
  behind conditional imports with a web implementation; deep links become URL
  routes (`/invite/<token>`).
- **Sign-in required, file import but no export:** the web client works only
  with an account, and all data reaches the browser through sync. Importing
  ChordPro files or ZIPs is offered on web as in the app: the imported songs
  go into the current band's library and are pushed by the next sync.
  Exporting songs or sets (ZIP, text, printable set list, ADR-0013) is not
  offered on web; the native apps keep it.
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
| Songs: ChordPro editor with preview, PDF attachments | ✓ |
| Sets: create, reorder | ✓ |
| File import (ChordPro, ZIP) | ✓ (imported songs are synced like new songs) |
| File export (songs, sets as ZIP, text, printable PDF) | – (not needed; data is synced with the server) |
| Personal overlays (ADR-0006) | ✓ (as on any device) |
| Local library "On this device" | – (hidden; signing in is required on web) |
| Live mode | ✓ with a notice "not offline-safe, use the app on stage" |
| "Offline ready" status | – |

### Session (ADR-0016)

Browsers have no platform key store, and web clients are often used on shared
computers:

- By default the session lasts **as long as a tab of the web client is
  open**: it is kept in `sessionStorage`, and a new tab takes it over from an
  open tab (`BroadcastChannel`). A **"Stay signed in"** checkbox, **unchecked
  by default**, keeps it in `localStorage` instead.
- Signing out in one tab signs out all tabs (they reload), because all tabs
  share one local database.
- Signing out on web **deletes the local database** of that browser (unlike the
  native apps, which keep songs and sets on sign-out). A start without a
  session deletes leftover data too, e.g. after the last tab was closed:
  local data exists only while signed in.
- Signing in is required: signed out, the web client shows only the sign-in
  screen (with "Join with invitation"); signed in without a band, it offers
  to manage bands or join with an invitation.
- The 30-day token lifetime and the refresh on start stay the same.

### Hosting (ADR-0014)

- The web client is published at **`https://app.setding.app`**: a second
  hostname of the Cloudflare Tunnel that points to the same PocketBase, which
  serves the web build as static files (`pb_public`). No second server.
- On web the server URL defaults to the **page's own origin**, so the web client
  calls the API on `app.setding.app` itself: same origin, no CORS configuration.
  The apps keep `https://api.setding.app`.
- It is deployed with the server targets (`make server-*`), built from the same
  commit as the apps.
- The invitation landing page (`/invite/<token>`) offers **"Open in the browser"**
  (`https://app.setding.app/invite/<token>`) next to the instructions for
  installing the app.
- Adding the tunnel hostname and the DNS record is done by the owner (Cloudflare
  account, ADR-0014).

### Implementation steps

Tracked in issue #27, each step a separate PR:

1. Add the web platform: drift web setup, conditional imports for the platform
   code, `flutter build web` in `make check` and CI.
2. Web session handling (sign-in required, tab-only session, local data cleared on
   sign-out).
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
- 2026-11-16: Owner decision: the web client works only with sign-in; file import
  and export are not offered on web, because songs and sets are synced with the
  server. Scope table and implementation step 2 updated.
- 2026-11-16: Step "web platform" implemented (#27): drift's WASM database with
  `web/sqlite3.wasm` (checked in, pinned) and a worker compiled from the locked
  packages; `package:sqlite3` raised to 3.9.1 because older versions made the
  IndexedDB fallback hang. Attachments are kept in memory on web until the
  on-demand step; the session lasts as long as the page until the session
  step. The web build is part of `make check` (docs/development/web.md).
- 2026-11-16: Owner decision: the default web session lasts as long as any
  tab of the web client is open (new tabs take it over, signing out signs out
  all tabs) instead of strictly one tab, because all tabs share the local
  database. Step "web session" implemented (#27): sign-in gate, "Stay signed
  in", local library and file import/export hidden, local data deleted on
  sign-out and on a start without a session.
- 2026-11-16: Step "PDF attachments on demand" implemented (#27): the web sync
  does not download attachment files; the live view loads a PDF when it is
  opened (file token, one download per file, kept in memory until signing
  out) and explains a failed download. "Offline ready" and the count of
  missing files are not shown on web. pdfrx runs from its bundled web assets
  (`pdfium.wasm`). Image attachments are not synced (ADR-0012) and need
  nothing extra. Hardened: the web client never falls back to the local
  library, not even while the bands load or with an old stored choice.
- 2026-11-16: Step "hosting" implemented (#27): `make server-install` builds the
  web client and installs it to `pb_public`; PocketBase serves it with
  `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy:
  credentialless` (credentialless instead of require-corp, so cross-origin
  resources without CORP headers keep working; browsers without it use the
  IndexedDB fallback). The build loads CanvasKit from the server, not from
  Google's CDN. `REALCHORD_WEB_URL` enables "Open in the browser" on the
  landing page and the `/invite/<token>` route on the web hostname; the server
  URL of the web client defaults to the page's origin
  (`--dart-define=REALCHORD_SERVER_URL` for development).
- 2026-11-16: Open points resolved: supported browsers are current Chrome,
  Edge and Firefox (OPFS with cross-origin isolation) and Safari (IndexedDB
  fallback); embedded Electron browsers may fail to start drift's worker under
  isolation. `app.realchord.app` is registered in the tunnel by the owner,
  `REALCHORD_WEB_URL` is set on the server, and the web client is deployed
  (2026-11-16).
- 2026-11-16: Live mode on web shows "not offline-safe, use the app on stage" in
  its status bar (the notice decided on 2026-11-15; step "docs").
- 2026-11-16: The web client's files are served with `Cache-Control: no-cache`
  (#121): Flutter web files keep their names between builds, and without a
  header Cloudflare cached them for 4 hours, so a deploy reached browsers late.
- 2026-11-16: Owner decision (#162): importing ChordPro files and ZIPs is
  offered on web as well, so songs can be uploaded as files in the browser;
  the imported songs are synced like new songs. Export stays native-only.
- 2026-11-17: App renamed to **setDING** (#318): the web client is published at `https://app.setding.app` (`SETDING_WEB_URL`), the apps use `https://api.setding.app`.

## Open points

- None. Possible later: a service worker for faster repeated loads (not an
  offline guarantee).
