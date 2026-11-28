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
- 2026-11-28: Storage limit implemented on the server (ADR-0070, #1226): a PDF is at most 1 MB (`maxSize` of `file`, was 20 MB; larger files already stored stay), `size_bytes` is set by the server from the uploaded file (the value the client sends is ignored, later changes too; a migration filled it in from the stored files), and a new attachment is refused with HTTP 400 `storage_limit_reached` on `file` when the organization's PDFs on the disk, the trash included, would go over `SETDING_ORG_STORAGE_LIMIT_MB`.
- 2026-11-28: The open point "Syncing image attachments" is decided by the owner: images for `{image}` (ADR-0012) are **synced like PDFs** (#1227). Server part: the `file` field also accepts PNG, JPEG, GIF, WebP and SVG (`image/png`, `image/jpeg`, `image/gif`, `image/webp`, `image/svg+xml`), with the limits of ADR-0070 (at most 1 MB per file, counted toward the organization's storage). PocketBase detects the type from the content, not from the name or the declared type: text or HTML named `.png` or `.svg` is refused (`validation_invalid_mime_type`), as are BMP and other image types. **SVG files** (checked against PocketBase 0.42.3, `server/test/image_attachments_test.dart`): they stay protected (a file token of a member is needed), and PocketBase serves them with `Content-Type: image/svg+xml`, `Content-Disposition: attachment` (also without `?download=1`; only raster images and PDFs are served inline), `Content-Security-Policy: default-src 'none'; …; sandbox` and `X-Content-Type-Options: nosniff`, so a browser that opens the file URL directly neither shows it as a document nor runs its scripts.
- 2026-11-28: App sync part of image attachments implemented (#1227): images are pushed and pulled like PDFs (upload, download to every device, rename, delete, trash and purge). A new file is uploaded under its local name (`<id>.png`, …) and media type instead of always `<id>.pdf`, and a pulled attachment gets the extension of the server's file, so `{image}` finds it by name on every device. Images attached before this change are queued with the next sync in every organization of the person; the server decides who may upload, and a refused one is marked once as with #1225. An image is at most 1 MB like a PDF (ADR-0070, also in the local library) and its content must be its type (magic bytes; SVG: text whose first element is `<svg`), checked when it is attached and when an archive or a ChordPro ZIP is imported (a skipped image is named in the import summary). SVG stays drawn with `flutter_svg` only; on the web client *Open* after saving shows an SVG as an `<img>` on a page whose Content-Security-Policy forbids scripts, never as a document in the app's origin.
- 2026-11-28: A refused change of an attachment already on the server is no longer kept locally in silence (#1229, follow-up of #1225). When the server gives a lasting answer (`BackendException.refused`) to a rename, a deletion, or a restore or purge from the trash of a PDF or image, the change is **undone on the device** instead of being marked like a refused upload: the server decides what the person may do, and a retry would get the same answer. As for refused contact and report changes, the local revision and the attachments cursor of the organization are lowered below the record's revision, so the server's version is pulled again, in the same sync run right after the push; an attachment whose deletion was undone gets its file downloaded again if it was already removed. The sync report lists the undone changes (`SyncReport.undoneChanges`, not recorded as changes of others, ADR-0045) and the person is told once with the shared message widget. Transient errors (network, 5xx, 429, 426) are sent again in the next sync as before.
- 2026-11-28: The web client loads the images of a song when the song is shown (song screen, live mode, full-screen view) instead of preloading them, like PDFs (ADR-0018, #1227); `{image}` draws them once they arrived. Website pages on attachments and import updated, with the screenshots of the size hint and the import summary.
- 2026-11-28: Follow-ups of #1227 and #1229 (#1248). When the server answers a refused attachment change with 404 because the attachment is no longer visible to the person (e.g. its song was moved out of reach), the pull right after the push does not send it back; the device then **removes the attachment and its file at once** (clearing a live view that pointed to it, personal annotations stay, ADR-0006) instead of keeping the local change until the next band refresh, so the device agrees with the "undone" message. The change log says "Attachment changed" ("Text and attachment changed") for a PDF or an image instead of "PDF changed", and the song list's attachment icon is explained as "Has attachments (PDFs, images)", matching what it counts.
- 2026-11-28: Found by the randomized convergence test (#1245, ADR-0004): an upload whose answer got lost is sent again as a change instead of being marked refused (PocketBase answers the second create with `validation_pk_invalid`), and one pulled before it is sent again takes the server's revision, so a later deletion reaches the server; when a song deleted on this device is no longer deleted on the server, its deleted attachments are pulled again, so those deleted only with the song come back.

## Open points

- None.
