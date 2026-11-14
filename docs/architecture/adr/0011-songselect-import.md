# ADR-0011: Song import from CCLI SongSelect

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Many bands, especially those playing in churches, get their chord sheets from
[CCLI SongSelect](https://songselect.ccli.com). An import directly from SongSelect into
BandChords would save the manual download and import of each song.

Findings (researched 2026-11-14):

- **SongSelect Partner API** ([Postman documentation](https://documenter.getpostman.com/view/604633/TzseGkmA)):
  technically a very good fit. It offers song search, details, lyrics and an endpoint that
  returns **ChordPro directly, in a chosen key** (`GET /v2/songs/:id/chordpro?key=D`).
  Authentication is OAuth 2.0 / OpenID Connect with Authorization Code + PKCE (suitable for
  mobile apps), plus a subscription key per partner application (`Ocp-Apim-Subscription-Key`).
  Rate limits: 100 calls / 10 s and 300 calls / 5 min per user. Content access is recorded
  and monetized; partners are asked to implement opt-in usage reporting (Reporting API).
- **The documentation states that CCLI has retired the SongSelect API Partner Program and
  is no longer accepting new API partners.** Without a partner agreement there is no client
  ID or subscription key, so the API cannot be used. No official announcement with a date
  was found; developer reports confirm that CCLI does not accept new partners.
- **"Public API" on [status.ccli.com/public-api](https://status.ccli.com/public-api)** is only
  the API of CCLI's status page (Instatus): it reports whether CCLI services are up
  (`/v3/summary.json`, `/v3/components.json`). It provides no song content.
- **Licensing:** a SongSelect subscription is only available to organizations holding a
  CCLI Church Copyright License; personal use is not permitted. Use for gigs outside church
  is most likely not covered (our inference; not stated explicitly by CCLI).
- **Manual path:** with a SongSelect **Premium** subscription, ChordPro files can be
  downloaded per song on the SongSelect website (Advanced does not include ChordPro). Other
  apps (e.g. OnSong) document the same manual workflow.

## Decision

- BandChords does **not** integrate the SongSelect API.
- The supported way is the **manual import**: users download ChordPro files from
  SongSelect (Premium) and import them with the existing file import (single files or ZIP).
- The decision is revisited if CCLI reopens the partner program.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Manual ChordPro import** (chosen) | Works today, no partner agreement, no extra code, licensing responsibility stays with the user's SongSelect account | One download and import per song |
| SongSelect Partner API integration | Search and import in the app, ChordPro in the desired key | Not available: partner program closed to new partners; also only relevant for church-licensed bands; requires usage reporting |
| Automating the SongSelect website (scraping, browser automation) | No partner agreement needed | Against the terms of use, fragile, rejected |
| Status page "Public API" | Public, no key | Only service status, no songs – irrelevant for import |

## Consequences

- No CCLI-specific code, credentials or reporting duties in the app.
- The ChordPro importer must handle files downloaded from SongSelect well.
- Bands without a church license need other sources for chord sheets (own ChordPro files,
  other services, own transcriptions).

## Decision log

- 2026-11-14: Accepted. No SongSelect API integration; manual import of ChordPro files downloaded from SongSelect.

## Findings from a real SongSelect file (2026-11-14)

A ChordPro file downloaded from SongSelect was tested (not committed to the repository
because of copyright). Its structure:

- Metadata: `title`, `artist`, `subtitle` (translators), `key`, `time`, `tempo`, plus
  CCLI-specific `ccli`, `ccli_license`, `copyright` and `footer`. UTF-8, LF line endings.
- **Sections are marked with comment headings** (`{comment: Vers 1}`, `{comment: Chorus 1}`,
  `{comment: Pre-Chorus}`, `{comment: Intro}`, `{comment: Tag}`) instead of
  `{start_of_verse}` etc.
- **Optional chords in parentheses** (`[(Bb/D)]`), bar and beat marks as chords (`[|]`, `[.]`)
  in the intro line, chords such as `Eb2`, `F(4)`, `Fsus`.
- After the song, a plain-text paragraph with CCLI song number, copyright, terms notice and
  CCLI license number.

Resulting changes in the `chordpro` package and the app:

- Comment headings with known section names (verse/Vers/Strophe, chorus/Refrain, bridge,
  pre-chorus, intro, outro, tag, interlude, solo, …) at the start of a paragraph become
  labelled sections; ordinary comments stay comments.
- Optional chords in parentheses are transposed and formatted (notation, Nashville) and keep
  their parentheses; bar/beat marks stay as written.
- `ccli`, `ccli_license` and `footer` are read as metadata.
- Live-mode fitting lets lines without chords (such as the copyright paragraph) wrap instead
  of shrinking the font, and measures with the same font as the display.

## Open points

- Should the copyright paragraph be rendered smaller (as a footer) in live mode? It is
  currently shown as written, at lyrics size.
- Monitor whether CCLI reopens the partner program.
