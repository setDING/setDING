# ADR-0068: Projecting lyrics to a browser from live mode

- **Status:** Accepted
- **Date:** 2026-11-27

## Context

Small gigs and especially worship sessions often show the lyrics on a projector or
a TV so the audience can sing along. Today the band needs separate presentation
software for this and has to keep a second copy of every song in it in sync with
the set. setDING already has everything the projection needs: the songs as
ChordPro (ADR-0003), the set with its order and markers (ADR-0047), the band's
sequence (ADR-0025) and live mode, which knows which song and which part of it the
band is playing.

What the projection needs is small: **the lyrics without chords**, large, on a dark
background, following the band. What it must not need is installation, an account
or internet on the device that drives the projector: often that is a borrowed
laptop or a smart TV with a browser.

Forces:

- **Offline-first** (ADR-0001): a gig must not depend on internet or the server.
  The band's tablet and the projector are usually in the same room, often in the
  same Wi-Fi or connected to the tablet's hotspot.
- **Permissions are enforced on the server only** (AGENTS.md, ADR-0023): anything
  the app hands out through another channel must not become a second way into the
  library. The projection may show only what the person running live mode shows
  anyway, to everyone in the room.
- **Licences:** projecting lyrics publicly requires showing the copyright of the
  song. The owner decided that the `{copyright}` directive is enough; CCLI song or
  licence numbers are not shown.
- **Platforms:** a native app can open a listening socket on Android, iOS, Windows,
  Linux and macOS; the Flutter web client (ADR-0018) cannot. iOS suspends an app in
  the background, Android may stop network work of a backgrounded app, and Windows
  asks the user once whether the app may accept connections.
- **Venue networks** often isolate clients from each other (guest Wi-Fi), so the
  browser cannot reach the tablet even though both are "in the Wi-Fi".
- **Live mode stays reliable** (quality goal 1): page turns must not wait for the
  projection, and a failing projection must never disturb the musician.

## Decision

1. **Local web server in the native app.** The app hosts a small HTTP server with
   `dart:io` (`HttpServer`, no new dependency) on Android, iOS, Windows, Linux and
   macOS. The web client does not offer it. The server is **off by default** and is
   started from live mode (*Project lyrics*); it stops when live mode is left or the
   projection is switched off. It listens on all interfaces of the device on a fixed
   default port (with a fallback to a free port) and only accepts connections from
   private address ranges (RFC 1918, link-local, IPv6 ULA) and loopback.

2. **Access by token.** Each start creates a random token (128 bits); every request
   without it gets 404. The app shows the URL (`http://<device IP>:<port>/p/<token>`)
   as text and as a QR code (`qr_flutter`), with every local IP address when the
   device has several. A new start creates a new token, so an old link stops
   working. There is no sign-in and no account: whoever has the link sees the
   projection, the same as everyone in the room sees the screen.

3. **Read-only and only the projection.** The server knows no song ids, no library
   and no API. It serves one page (HTML, CSS and JS shipped as an app asset) and
   one stream of the **current projection state**: the slide shown now, the next
   slide for a preview, the song title and its `{copyright}`. Nothing the person in
   live mode cannot see is ever sent; nothing can be changed through the server.

4. **Updates as Server-Sent Events.** The page opens an `EventSource`; the app
   pushes a new state whenever the projection changes and a heartbeat every few
   seconds. The browser reconnects on its own after a drop and gets the current
   state at once. Several browsers may follow at the same time (projector, confidence
   monitor, a laptop for the livestream). Sending runs outside the frames of a page
   turn and never blocks live mode; a failing client is dropped.

5. **Slides per section.** The lyrics are cut into **slides by section** of the
   rendered song (verse, chorus, bridge …), in the order of the song as the band
   plays it: the band arrangement's sequence (ADR-0025) or `{x_sequence}`, so a
   chorus that is recalled appears again. Chords, chord diagrams, comments for the
   band, tabs and grids are left out; personal overlays (ADR-0006) do not change the
   projection, except the language version chosen for the set item (ADR-0053). The
   page fits each slide to the screen (largest font that fits), white text on black
   by default. A section longer than the *lines per slide* setting (default 8) is
   split into several slides of about equal length.

6. **Following live mode, automatic and manual.** By default the projection
   follows the musician: a new song in live mode shows its first slide, and the
   slide follows the section at the top of the visible page (the first slide of a
   split section). A small projection bar in live mode allows *previous slide*,
   *next slide* and *Blank* (black screen) without leaving the song. As soon as the
   bar's *previous* or *next* is used in a song, that song stays **manual** until
   the next song, so the automatic follow never undoes a hand-picked slide; a
   button in the bar returns to *follow*. The bar is hidden when the projection is
   off, so live mode does not change for anyone else. Advancing from another device
   (a control page in the browser) is not part of the first version.

7. **Set markers and blank.** A set marker (ADR-0047) shows a black slide by
   default; a setting per projection can show the marker's text instead (for
   *Prayer*, *Break*). *Blank* always wins until it is switched off.

8. **Copyright.** Every slide of a song shows its `{copyright}` in a small line at
   the bottom (or on the first and last slide only, a projection setting). A song
   without `{copyright}` is projected without one; the app shows a hint in the
   projection bar so the band can add it. CCLI fields are not shown.

9. **Two languages.** A projection setting *Second language* (off by default)
   names a language. When the song of the set item has a linked language version
   in it (`work_id`, ADR-0053), each slide shows both versions: side by side on a
   landscape screen, one above the other on a portrait screen, the second in a
   lighter colour. The sections are paired by their position in the played order
   of each version; a section the second version does not have shows the first
   language alone. A song without a version in the second language is projected
   in one language. The version chosen for the set item always comes first.

10. **Lower third for livestreams.** Besides the full-screen page the server serves
    a **lower-third layout** at its own path (`/p/<token>/lower-third`): the current
    slide in a band at the bottom of the screen (at most a quarter of its height),
    on a **transparent background**, meant as a browser source in OBS or similar
    software. It uses the same state stream and slides; the copyright is shown in
    a small line beside the text. The QR dialog offers both links. A band using it
    sets *lines per slide* to 2–4, so the slides fit the band.

11. **Settings.** Projection settings are **device settings** (ADR-0027):
   font, colours (black/white or white/black), alignment, lines per slide,
   copyright placement, markers as text, second language, next-slide preview on the page (for a confidence monitor, off
   by default). The page has no settings of its own besides full screen.

12. **Limits documented, not hidden.** The website page (both languages, with a
    screenshot of the projection bar, the QR dialog, the projected page in one and
    two languages and the lower third) explains
    the hotspot workaround for client isolation, the Windows firewall prompt and
    that iOS projects only while setDING is in the foreground (which live mode keeps
    with its wakelock). Keeping the server alive on Android while another app is in
    front (a foreground service) is not part of the first version.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Local web server in the app, browser as the display** (chosen) | Works with any projector computer, smart TV or OBS browser source; no installation; offline; several displays at once | Needs a network between tablet and display; client isolation; iOS foreground only; firewall prompt on Windows |
| Second screen of the tablet (HDMI cable, AirPlay, Chromecast, Android Presentation API) | No network; no token | Different on every platform, plugins of varying quality; the tablet needs a cable or a cast device; one display only; the tablet is often on the music stand, far from the projector |
| Relay through PocketBase (the app publishes the state, a web page on `app.setding.app` shows it) | Works across networks, no client isolation problem | Needs internet at the venue (against ADR-0001); a new server route and permission model for anonymous viewers; latency |
| Separate presenter app or the web client as presenter | Clear separation | Second login and second device to operate; does not follow live mode; the web client cannot run offline |
| Export slides (PDF or a presentation file) for existing software | Simple; works with any presentation tool | Not live: no following, no blank, set changes need a new export |

## Consequences

- Bands can project lyrics with nothing but the tablet already on stage and any
  browser; worship teams no longer need a second song database.
- The app gets a network listener for the first time. It is small and read-only,
  but it is new attack surface: the token, the private-address check, the
  off-by-default start and tests for refused requests (wrong token, other paths,
  public address) are mandatory.
- The chordpro package gets a **lyrics-only slide model** (sections in played
  order, chord-free lines, long sections split), tested in the package; the page
  and the app only display it.
- `{copyright}` becomes visible to the audience, so the import and editor hints
  about a missing copyright matter more.
- Follow-up issues once accepted: slide model in `packages/chordpro`, server and
  state stream in the app, projection bar and QR dialog in live mode, projection
  settings, the web page asset (full screen and lower third), pairing two language
  versions, website page with screenshots, Android and iOS manual tests.

## Decision log

- 2026-11-27: Proposed (#1164). The owner decided that showing `{copyright}` is
  enough for the licence; CCLI fields are not projected.
- 2026-11-27: Owner decisions on the open points: the projection follows live mode
  automatically and a song becomes manual once its slides are advanced by hand
  (§6); a control page in the browser comes later; two languages side by side
  (§9) and the lower third for livestreams (§10) are part of the first version;
  following on the audience's phones and the Android foreground service stay open.
- 2026-11-27: Accepted by the owner (#1164).
- 2026-11-27: Slide model in `packages/chordpro` (#1166): `lyricSections` takes
  the played order from the same rule as the drummer's song map (ADR-0026,
  `playedParts`/`sequenceParts`): a part without a number takes the next section
  of its kind, repetitions (`C x2`) are kept on the section and not expanded into
  more slides, and without a matching sequence every section with lyrics is used
  in document order, including sections without a label. `lyricSlides` splits a
  section into the fewest slides of at most *lines per slide* text lines, of about
  equal length, and gives a language pair the slide count of the longer one.
- 2026-11-27: Server and state stream (#1167): `app/lib/projection/`, default port
  8231 (a free port when taken), bound to all IPv6 and IPv4 interfaces; routes
  `/p/<token>` and `/p/<token>/lower-third` (the page) and `/p/<token>/events`
  (SSE, `event: state` with the JSON of `ProjectionState`, format version `v: 1`,
  a comment as heartbeat every 5 s); only `GET`, token compared in constant time,
  at most 32 streams (503 beyond), `Cache-Control: no-store`, `nosniff`, a
  Content Security Policy without external sources. The page asset follows in
  #1168.
- 2026-11-27: Projected page (#1168): one self-contained asset
  `app/assets/projection/index.html` for both layouts (the path decides), texts
  filled in from the app's language (`projectionPage`, ARB `projectionFullScreen`).
  The font is the largest that fits, at most an eighth of the screen height;
  whole lyric lines are kept unless that makes the font smaller than 60 % of
  the wrapped size. The look (dark/light, sans/serif, centred/left) comes with
  the state (`style`); the copyright is shown as written in `{copyright}`; a
  red dot shows a lost connection while the last slide stays. The browser's
  Screen Wake Lock needs HTTPS and is not available over the local `http://`
  link, so the projector computer must not go to sleep by itself.
- 2026-11-27: Live mode (#1169): a *Project lyrics* button in the controls
  (native apps only) starts the server and opens a bottom sheet with the QR
  code, both links per address (copyable) and *Stop projection*; the
  projection bar sits at the top right of the stage while projecting. Following
  live mode uses the **first section on the shown page** of a paged song
  (`SongPageController.section`); a song that fits one page, scrolls or is a
  PDF is followed per song only (its first slide), so within such a song the
  slides are advanced with the bar. A repeated section is found after the
  current slide first. `ProjectionController` holds the follow/manual logic;
  the projection settings (#1170) are `ProjectionOptions`, with the defaults
  until then (8 lines, markers blank, no preview, no second language).
- 2026-11-27: Projection settings (#1170): a *Projection* section in the live
  mode settings (native apps only) with colours (white on black / black on
  white), font (sans / serif), alignment, lines per slide (2–12, default 8),
  copyright on every slide or on the first and last one, a second language
  (a song language of ADR-0053, none by default), markers as text and the
  next-slide preview; all device settings (`projection*` keys). A change
  reaches a running projection at once. The version in the second language is
  the first linked version of the song with that language, paired with its
  own `{x_sequence}`; it is looked up after the song is shown and added
  without moving the slide.

## Open points

- A control page in the browser (e.g. at the mixing desk) that advances the slides
  instead of the tablet: needs a second, writing token. Later, its own decision.
- Pairing the sections of two language versions by position fails when the
  versions are structured differently; a later option could pair them by section
  type and number.
- Audience members following the lyrics on their own phone through the same link
  (load: many clients on one tablet).
- A confidence monitor for the band with chords (would show more than the lyrics;
  check against the licence and the permission rule first).
- Keeping the projection running on Android while another app is in the foreground
  (foreground service).
