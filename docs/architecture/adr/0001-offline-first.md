# ADR-0001: Offline-first architecture

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Performances often take place in locations with poor or no Wi-Fi/mobile coverage
(basements, festival tents, halls). The chord display failing during a performance
is the worst possible failure scenario for this application.

## Decision

The app is built **offline-first**:

- Every device holds **all data of the bands the user belongs to** (songs, sets,
  PDF sheet music attachments) locally:
  - structured data (ChordPro text, sets, overlays) in a local **SQLite** database,
  - **PDF attachments** as files in the app's private storage, referenced from the DB
    (see ADR-0009).
- ChordPro text is small (a few KB per song; even 1000 songs are only a few MB).
  PDF attachments make up most of the data volume.
- The UI reads and writes **exclusively locally**. The network is only used by the
  sync engine in the background.
- The login token is stored locally; without a network the app starts directly in
  the library.
- Members can check before the performance that their data is complete and up to
  date. A set is only "offline ready" when all its songs **and their PDF
  attachments** are available locally. Only the problem is shown: a set that is not
  offline ready says how many of its songs are missing (a visible text, not only an
  icon); offline ready sets show nothing. "Up to date" is shown as a warning above
  the sets when the last successful sync (kept across restarts) is more than 24
  hours ago or never happened, or when local changes did not reach the server
  because the last sync failed.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Offline-first with local DB** (chosen) | Always works, fast, no loading behaviour on stage | Sync logic required, conflicts possible |
| Online with cache (e.g. HTTP cache) | Simpler | Unpredictable what is cached; risk of an empty screen |
| Local only, exchange via files (ZIP, AirDrop, email) | No backend | Cumbersome, version chaos within the band |

## Consequences

- Client-generated UUIDs as primary keys (records are also created offline).
- A sync and conflict strategy is required (→ ADR-0004).
- The MVP can be built entirely without a backend; the backend is added later as a
  sync target without restructuring the app architecture.
- Because of the PDFs, storage usage must be visible in the settings, and files of
  deleted songs must be cleaned up locally.

## Decision log

- 2026-11-14: Offline-first accepted. PDF sheet music attachments are also kept offline. Audio files are not part of the offline scope.
- 2026-11-15: Exception for the web client (ADR-0018, accepted): the browser is a management tool without an offline guarantee; "Offline ready" is not shown there. The apps stay offline-first.
- 2026-11-16: Web client implemented and deployed (#27): data in the browser exists only while signed in (deleted on sign-out and on a start without a session), PDFs are loaded when opened, no "Offline ready" status, and live mode shows "not offline-safe, use the app on stage". The apps are unchanged.
- 2026-11-21: Offline status shows only problems (#744): the green "Offline ready" mark on every set was almost always shown and went unnoticed, and it did not cover "up to date". Sets that are not offline ready show the number of missing songs as text; a warning above the sets covers a stale (over 24 hours) or missing sync and changes that did not reach the server. Neither is shown on the web client (ADR-0018).

## Open points

- None.
