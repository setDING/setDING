# ADR-0065: URL routing and deep links

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

The app opens its screens with `Navigator.push` (about 50 places in 32 files)
and switches the tabs of the main navigation (`HomeScreen`, `HomeTab`) with
local state. No screen has an address. This leads to three problems:

- **Web client (ADR-0018):** the browser history holds a single entry for
  setDING, so the browser's **back button leaves the app** instead of going
  back to the previous screen (owner report, 2026-11-26). Reloading the page
  goes back to the start screen, and a screen cannot be bookmarked.
- **Sharing:** a band member cannot send a set or a song to the band chat in a
  way that opens it on the others' tablets. Only invitations have links
  (`/invite/<token>`, ADR-0005), and those are handled by a listener that
  pushes the join screen (`app/lib/ui/deep_links.dart`).
- **ADR-0002** already named `go_router` as the routing library, but it was
  never introduced. Code and ADR are out of sync.

The owner's decisions (2026-11-26, #1111):

- Links are meant for the **web and the apps**: a link such as
  `https://app.setding.app/sets/<id>` opens the web client in a browser and the
  installed app on a tablet or phone, as invitations do today.
- Routing is built with **`go_router`** (Flutter team, BSD-3-Clause, compatible
  with MIT).

Forces:

- **Offline-first** (ADR-0001): a link must open from the local database
  without a network. A record that is not on the device yet (sync pending) or
  that the person may not see shows a clear hint, never an error.
- **Permissions on the server** (#632, ADR-0023): a link grants nothing. It
  only names a record; what the person can see is decided as before.
- **Unsaved changes:** screens with a `PopScope` (song editor, set editor)
  must still ask before the browser's back button leaves them.
- **Esc goes back** (ADR-0049, #726) and the app bar's back button keep working
  the same way.
- **Live mode** stays full screen; leaving it with the browser's back button
  must behave like leaving it in the app.
- **Self-hosting** (ADR-0063): links use the server's own web URL, not a fixed
  domain.

## Decision

### 1. go_router for all page navigation

- The app uses `MaterialApp.router` with one `GoRouter`. Every **screen**
  (page) is a route; **dialogs, bottom sheets, menus and side panels stay
  imperative** (`showDialog`, `SidePanel`) and get no URL.
- The main navigation (Overview · Sets · Songs · Settings) is a
  `StatefulShellRoute`: each tab is a branch with its own path and keeps its
  state (scroll position, filters) when switching, as today.
- Screens are opened with `context.go` / `context.push` and named routes
  defined in one place (`app/lib/ui/routes.dart`); `Navigator.push` of a page
  is not used any more. `app/test/ui_rules_test.dart` enforces this
  (ADR-0051).
- Guards are `redirect`s of the router: not signed in → sign-in; no band →
  the no-band screen; incomplete name → the name prompt (ADR-0062). After the
  redirect the person lands on the link they opened.

### 2. Paths

Paths use **record ids** (UUIDs created on the device, the same on every
device and on the server), never names, so a link stays valid when a set or
song is renamed and reveals nothing about its content.

| Path | Screen |
|---|---|
| `/` | Overview |
| `/sets` | Sets of the current band |
| `/sets/<id>` | Set |
| `/sets/<id>/live` | Live mode of a set (optional `?song=<n>`) |
| `/songs` | Song list (search and filters stay local state) |
| `/songs/<id>` | Song |
| `/songs/<id>/edit` | Song editor |
| `/settings`, `/settings/<category>` | Settings (replaces `settingsJumpProvider`) |
| `/organizations/<id>`, `/bands/<id>` | Organization, band |
| `/repertoire`, `/recent-changes`, `/trash` | the other full screens |
| `/invite/<token>` | Join (ADR-0005, unchanged format) |

The exact list is set during implementation; screens that only make sense from
another screen (e.g. the MIDI test) may stay without their own path.

### 3. Band and organization context

A set belongs to a band, a song to an organization (ADR-0017). Opening
`/sets/<id>` or `/songs/<id>` **switches the current band** to the record's
band (or to a band of the song's organization) if the person is a member
there, with a short hint (*Switched to band X*). If the record is not on the
device, a placeholder screen says *Not available on this device* and offers to
sync now; if the person has no access, it says so without revealing the
title.

### 4. Web client

- **Path URLs** (`usePathUrlStrategy`), no `#` in the address, so the same URL
  works in the browser and as an App Link.
- The browser's back and forward buttons follow the router's history;
  `PopScope` screens still ask before discarding changes.
- The server serves the web client's `index.html` for every app path on the
  web hostname (`isWebHost`, `SETDING_WEB_URL`), as it does for `/invite/`
  today; API (`/api/`), admin UI (`/_/`) and files keep their routes.

### 5. Links that open the apps

- **Share link** in the set and the song screen: `<SETDING_WEB_URL>/sets/<id>`
  (or `/songs/<id>`), shared through the system share sheet; without a web URL
  the server's API URL is used, like invitation links.
- **Android App Links** and **iOS Universal Links** cover the app paths on the
  web hostname (`app.setding.app`) next to `/invite/` on `api.setding.app`;
  `assetlinks.json` and `apple-app-site-association` are served on both
  hostnames. Windows and Linux open `setding://sets/<id>` (protocol handler);
  a browser opening a web link there shows the web client.
- `DeepLinkListener` hands every incoming link to the router
  (`router.go(path)`) instead of pushing the join screen itself.

### 6. Tests

- Router tests for every path, the redirects and the context switch
  (`app/test/`), widget tests that the back button and `PopScope` behave as
  before.
- Web integration test (`make web-test`): browser back and forward move
  between screens and a reload keeps the screen.
- Server test: app paths on the web hostname serve `index.html`; the
  verification files list the new paths.
- Android integration test: an App Link opens the set.

### 7. Rollout

1. Router and paths with the same screens, browser back on web (fixes the
   reported problem).
2. Context switch and the *Not available* screen.
3. Share links, App Links / Universal Links, server fallback and verification
   files.
4. Website page (de and en, ADR-0030) with a screenshot of the share action.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **go_router, every screen a route** (chosen) | Browser back, reload, bookmarks and shareable links from one mechanism; Flutter's standard; redirects for sign-in and guards | Large migration of all page navigation; one more dependency |
| History entries only on web (keep `Navigator.push`, push a browser history entry per route) | Small change, fixes the back button | No addresses, no reload, no bookmarks, no sharing |
| Own `Router` (Navigator 2.0) | No dependency | Much more own code for parsing, history and tabs to maintain and test |
| Hash URLs (`/#/sets/<id>`) | No server fallback needed | Cannot be App Links (the fragment is not part of the path); ugly in the chat |

## Consequences

- The reported problem is fixed: on the web, back goes to the previous screen.
- Sets and songs can be shared in the band chat and open on every device that
  has them.
- All page navigation moves to the router; new screens get a path. Tests that
  push screens directly keep working through a test router helper.
- ADR-0002's routing entry is finally implemented (decision log there).
- The server serves `index.html` for more paths and lists more paths in the
  verification files (ADR-0018, ADR-0005).
- Older apps ignore the new links; they open the web page instead.

## Decision log

- 2026-11-26: Proposed (#1111). Owner decisions: links for web and apps,
  `go_router`.
- 2026-11-26: Accepted by the owner (#1111). Implementation: router and
  browser back #1113, band context and *Not available* #1114, share links and
  App Links #1115, website page #1116.
- 2026-11-27: Router implemented (#1113): `app/lib/ui/routes.dart` with
  `AppPaths`; the screens that belong to no tab (bands, organizations,
  libraries, recent changes, join, sign-in) are children of the overview, so
  a link to them also gets a back button. Details settled during
  implementation:
  - **Screen arguments** besides the path are a JSON `extra` (`songExtra`:
    the set a song was opened from; `editorExtra`; `signInExtra`), which the
    browser history keeps; every screen also works without it (the editor
    loads the song's source itself, live mode loads its set or song).
  - **Full-screen dialogs** that return a value (song picker, language
    version picker, marking a screenshot, image attachment) stay
    `MaterialPageRoute(fullscreenDialog: true)` without a path, like the
    other dialogs; `ui_rules_test.dart` allows no other page route.
  - **Settings categories**: `/settings/<category>` is the category's own page
    on narrow screens; on wide screens a category is still selected next to
    the list without changing the URL, and `settingsJumpProvider` stays for
    jumps from the overview (it opens the path on narrow screens).
  - **Web sign-in gate**: not a redirect to its own page; the gate stays the
    start screen at `/` (ADR-0018). A redirect sends a signed-out visitor of
    any other path except `/invite/…`, `/join` and `/sign-in` there with
    `?next=<path>`, and the app goes on to `next` after signing in. The
    router is not refreshed on sign-in (that brought back a sign-in screen
    that was closing). The name prompt and the invitation listener wrap the
    main navigation.
  - **Unsaved changes**: the editor's routes have an `onExit` that asks like
    its `PopScope`, since the browser's back button does not ask the
    `PopScope`.
  - The tabs' screens have their own navigators: code that must know whether
    a screen is on top uses `routeOnTop()` (`widgets/app_shortcuts.dart`), and
    dialogs are closed on the root navigator.
  - The server needed no change: PocketBase's index fallback already serves
    `index.html` for app paths (server test in `web_test.dart`).

## Open points

- On the web, the browser's back button while a dialog is open closes the
  dialog together with the screen below it (dialogs add no history entry).
- iOS Universal Links need the Apple Developer Team ID (open since ADR-0005).
- Should the song list's search and filters be part of the URL
  (`/songs?q=…`)?
- Links to a song *in* a set (`/sets/<id>/songs/<n>`) with the set's
  arrangement?
