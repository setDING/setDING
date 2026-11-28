# ADR-0009: PDF sheet music attachments

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Besides ChordPro lead sheets, bands use PDF sheet music (e.g. horn parts, piano
scores, arrangements). It was decided in ADR-0001 that PDF attachments must be
available offline, like the rest of the data. This ADR defines how PDFs are modelled,
synced and displayed.

## Decision

### Data model

- A song can have **zero or more PDF attachments** (`ATTACHMENT`), each with a name
  (e.g. "Horns", "Piano"), the file, page count, file size, `revision` and `deleted`.
- A song may consist of **only PDF attachments** without ChordPro text
  (`chordpro_source` is then empty; title and artist are entered as fields).
- PDFs belong to the band, like songs. Every member sees all attachments of a song.

### Storage and sync

- **Server:** stored as a PocketBase file field on the attachment record (ADR-0004).
- **Client:** stored as files in the app's private storage, referenced by attachment
  ID and revision; metadata in the local DB.
- **Sync:** metadata is synced like other records; files are downloaded afterwards
  in the background. Every device downloads **all** PDF attachments of its bands;
  there is no selective download. Files are never edited, only replaced (new revision = new file),
  so there are no file conflicts.
- **"Offline ready"** for a set includes all PDF attachments of its songs (ADR-0001).
- **Maximum file size: 20 MB** per PDF (enforced client- and server-side).

### Phasing

- **MVP:** import PDFs locally, attach them to songs, display them in live mode.
- **Phase 1:** file sync via the backend, together with the sync of songs and sets.

### Display

- PDFs are rendered in the app (no external viewer), in the live view as well.
- Page turning with the same input as for ChordPro songs (tap, swipe, page turner or keyboard; ADR-0007).
- Portrait: one page at a time, fit to width. Landscape: two pages side by side (spreads 1–2, 3–4, …; a last odd page alone), fitted to the screen; a page turn moves a whole spread.
- If a song has both ChordPro text and PDFs, the user chooses per song what to show
  in live mode (stored in the personal overlay, ADR-0006); default is ChordPro.
- Personal transposition, notation and Nashville settings do not apply to PDFs.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Attachments per song, synced as files** (chosen) | PDFs available offline, live flow identical for ChordPro and PDF | Larger data volume, separate file sync |
| PDFs as links to external storage (cloud drive) | No file sync | Not offline, violates ADR-0001 |
| No PDF support | Simplest | Does not cover bands with sheet music |

## Consequences

- An additional PDF rendering library is needed in the Flutter client (candidate: `pdfrx`, to be verified during setup).
- Server storage and backups grow with the number of PDFs.
- The settings show local storage usage; files of deleted attachments are removed locally.
- Export of a set as ZIP includes the PDF attachments.

## Decision log

- 2026-11-14: PDF attachments accepted: all attachments are downloaded to every device (no selective download), maximum 20 MB per PDF, songs may consist of PDFs only. Local PDF support is part of the MVP; file sync follows in phase 1.
- 2026-11-14: Attachments are extended to images (PNG, JPG, GIF, SVG) for the ChordPro `{image}` directive (ADR-0012).

- 2026-11-15: Sync of PDF attachments implemented (issue #18, ADR-0004): metadata is pulled per organization with the songs; files are uploaded once (immutable, the song first) and downloaded in the same sync run, so all attachments are on every device; renames and deletions travel both ways, deleted files are removed locally. A file that is not downloaded yet is shown as a hint in live mode and keeps the set from being "offline ready"; the settings show how many files are still missing. Image attachments for `{image}` (ADR-0012) stay on the device (the server accepts PDFs only).
- 2026-11-15: On web (ADR-0018, accepted) attachments are fetched on demand instead of preloaded; the apps keep all attachments offline.
- 2026-11-16: On-demand loading implemented (#27): the web sync skips file downloads; the live view downloads a PDF when it is opened (one shared download per file, kept in memory until signing out) and explains a failed download.
- 2026-11-16: Two pages side by side in landscape implemented (#150): live mode shows spreads fitted to the screen and turns a spread at a time; portrait keeps the scrollable viewer with one page per turn.
- 2026-11-18: Attachments can be opened from the song screen without changing the live view choice (#507): a PDF opens in live mode for that song only, an image in a full-screen, zoomable view.
- 2026-11-23: Attachments can be saved as a file from their menu (#1025), by everyone who sees the song: the platform's save dialog, a download on web (the file is fetched on demand first, ADR-0018).
- 2026-11-28: A refused upload is no longer dropped silently (#1225). When the server gives a lasting answer to a new attachment (no permission, 403/404, or a validation error, 400, e.g. the file is too large), the attachment stays on the device marked "Only on this device" with the reason (local column `attachments.upload_refused`, schema 43), the sync report names it and the person is told once; it is not sent again until the person chooses *Upload again* in its menu, or deletes it. Network errors, server errors (5xx), rate limits (429) and a required update (426) are not refusals: the upload is sent again in the next sync, server errors and rate limits without stopping the other pushes. Further lasting answers (e.g. a storage limit, ADR-0070) fit as another refusal reason.

## Open points

- Syncing image attachments (`{image}`): needs the server to accept image types.
