# ADR-0011: Song import from CCLI SongSelect

- **Status:** Proposed
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

## Open points

- Test the import with a real ChordPro file downloaded from SongSelect (directives, section
  headings, encoding).
- Should CCLI metadata in such files (e.g. copyright, CCLI song number) be shown in the song
  header or footer? A visible copyright notice may be required by the license terms.
- Monitor whether CCLI reopens the partner program.
