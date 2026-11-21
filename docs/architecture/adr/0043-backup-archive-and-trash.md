# ADR-0043: Backup archive and trash

- **Status:** Accepted
- **Date:** 2026-11-20

## Context

setDING keeps data in two places: the local library "On this device"
(ADR-0005), which is never synced, and the libraries of organizations
(ADR-0017), which are synced with the server (ADR-0004). The only backup is
the server's daily backup (ADR-0014). It protects the operator, but only as a
whole: bringing back one organization or one deleted song would reset all
others too. Users have no backup at all:

- **Local library:** the data exists only on one device. A lost device or a
  new installation loses everything. The ZIP export of a set (ADR-0009) is not
  a backup: it holds neither the set structure nor arrangements, personal
  adjustments or the whole library.
- **Organizations:** an organization cannot save its own data, move it to
  another server (self-hosting, #419) or keep a copy outside setDING.
- **Deletions:** "Undo" after a deletion is offered for a few seconds (#267).
  After that a deleted song or set is gone for the users, although the server
  still has it as a soft-deleted record (ADR-0004).

Constraints: offline-first (ADR-0001), the data is already on the device;
ChordPro is the single source of truth and an open format (ADR-0003, quality
goal 5 "no lock-in"); personal adjustments and annotations are private
(ADR-0020, ADR-0032); roles of ADR-0023; deletion is a soft delete and devices
learn about it through delta sync (ADR-0004).

## Decision

### 1. Backup archive

A whole **library** can be exported as one ZIP file and imported again.

**Format** (`setDING-Backup <library> <yyyy-mm-dd>.zip`):

- `manifest.json` with `format: "setding-backup"`, `formatVersion: 1`, the app
  version, the creation time, the source (local library or organization, ID
  and name) and the records with their original IDs: songs with their
  attachments' metadata, bands, sets with their items, band arrangements
  (ADR-0025), and the **exporting person's own** personal adjustments and
  annotations. No users, roles, memberships, invitations or other people's
  private data.
- `songs/<title> (<short id>).cho`: the ChordPro text (with title and artist
  directives added if missing, as the existing export does), readable without
  setDING.
- `attachments/…`: the attachment files (PDFs, images).

A newer `formatVersion` than the app knows is refused with a message; a minor
addition (new optional field) does not change the version.

**Export:**

- The local library: anyone, on the device.
- An organization: **organization admins and librarians** (ADR-0023). It
  contains the library and the sets and arrangements of the bands the
  exporting person's device has (the bands they may see).
- On native apps **and on the web client** (ADR-0018 is changed accordingly).
- **A sync is mandatory before an organization is exported**, so the archive
  contains everything: the export first runs a sync and stops with a message
  if the sync fails (offline, sign-in, update required) or is deferred (live
  mode), if local changes are still waiting to be pushed, if the library has
  open conflicts, or if an attachment file is not available (native: not
  downloaded; web: loaded on demand for the export).

**Import, always as a copy:**

- A ZIP with a `manifest.json` of format `setding-backup` is recognized by the
  normal import and imported as a backup instead of as ChordPro files.
- The target is the local library or an organization where the person may
  create songs; each band of the archive is mapped to a band of the target or
  skipped.
- Every record gets a **new ID**; references (set items, arrangements,
  personal adjustments, annotations) are mapped to the new IDs. Nothing
  existing is overwritten.
- **Duplicates:** a song of the archive whose original ID or title + artist
  matches a song of the target library is not imported when the ChordPro text
  is the same; the existing song is used instead (sets and arrangements point
  to it). When the text differs, the person chooses once for the whole import:
  import as an additional song, or keep the existing one. Additional songs keep
  their title (the ChordPro text is not changed) and are listed after the
  import with links, like the ChordPro problems (#314), so they can be
  compared and deleted.
- Sets are always added.

### 1a. Full backup in the settings (#639)

*Settings → Storage & info* offers **Back up everything** and **Restore
backup**:

- A full backup is one archive with `formatVersion: 2`: the archive of each
  library the person may back up (the local library, organizations as
  librarian or admin) in its own folder `libraries/<n>/` (each a version 1
  archive with its own `manifest.json`), the person's **own personal
  adjustments and annotations of the other organizations** (no library rights
  needed; `personal` in the manifest, by song ID), and their **personal and
  device settings** (without the server address).
- Signed in, the same mandatory sync runs first.
- Restoring imports each library as a copy into a chosen library (or skips
  it), restores the personal adjustments on the songs with the same ID that
  are on this device (they replace the current ones; annotations are added
  by stroke ID) and, only if the person ticks it, the settings.
- Archives of one library (version 1) stay importable everywhere.
- The settings show the last backup of the local library on this device. If
  the local library changed and was not backed up for 30 days, a hint offers
  a backup at start, at most every 7 days and never in live mode.
- No automatic backups.

### 1b. Set archive (#707)

The ZIP export of a set (ADR-0009) becomes an archive that can be imported
again **as a set**:

- **Format:** the numbered ChordPro files (`NN - <title>.cho`) and the
  attachments as before, plus a `manifest.json` with
  `format: "setding-set"`, `formatVersion: 1`, the app version, the creation
  time and the records of the set with their original IDs: the set (name,
  date, venue, items with pauses and text items, set transposition and
  sequence), its songs and, depending on the export options, the band
  arrangements of the songs (ADR-0025), the attachments and the **exporting
  person's own** personal adjustments and annotations. The plain-text
  `setlist.txt` is dropped; the text and PDF set list export (ADR-0013)
  covers it.
- **Export options:** band arrangements, set-specific settings, attachments,
  own personal adjustments and annotations. Personal adjustments and
  annotations are off by default, because a set ZIP is often passed on.
- **Import with a preview:** a ZIP with such a manifest is recognised by the
  normal import. Before anything is written, a preview shows the target
  library and band, the songs (already there, new, text differs, missing)
  and the same options as the export.
- **Songs** follow the duplicate rule of section 1 (identical songs reused,
  differing ones optionally added).
- **Band arrangements** already present in the target band are **kept**; an
  option in the preview overwrites them.
- **Importing the same set again** (a set with the set's original ID exists
  in the target band, as an earlier import remembers the original ID): the
  preview offers to **replace** the existing set (its fields and items) or to
  add a copy. This is the one exception to "nothing existing is
  overwritten"; replacing is a normal change, so it can be undone and the
  previous items stay in the change history.
- **Missing songs** that the person may not create (set planner, ADR-0023)
  become text items "missing: <title>" in the set and are listed in the
  import report; the set is imported anyway.
- Rights are those of the records created or changed (sets, set items,
  arrangements, songs); the server enforces them as for any other change.

### 2. Trash

Deleted songs and sets can be **restored for 30 days**.

- Songs, sets and attachments store when they were deleted (`deleted_at`),
  sent by the client (a deletion may happen offline; the server takes now if
  it is missing or in the future). Restoring a song also restores the
  attachments deleted together with it (same deletion time); the server
  restores the personal adjustments, arrangements and annotations the song's
  deletion removed, as for the undo (ADR-0015).
- **Deleting a set keeps its items**, so a restored set is complete. Deleting
  a song still removes its set items; restoring it from the trash does not put
  them back (the undo of #267 still does).
- A daily job on the server **purges** records deleted more than 30 days ago:
  the song text, set items and attachment files are removed (with a song also
  its attachments) and the record is marked `purged`. Superusers can start the
  purge at once (`POST /api/setding/trash/purge`). The record itself stays as a **tombstone**, so devices that were
  offline for a long time still learn about the deletion. Purged records
  cannot be restored.
- The client shows a **trash** per library (songs, for people who may delete
  songs) and per band (sets, for people who may manage sets) with the deletion
  date and the days left; restoring is a normal change synced like an edit.
- The local library has the same trash; its deleted records and files are
  removed on the device after 30 days.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Archive exported by the client** (chosen) | Works offline and on every platform; no server code; same format for the local library and organizations; open format | Only what the device has; large libraries are zipped in memory |
| Export on the server (download of an organization) | Always complete | Server code and rights per route; not possible for the local library; a second format path |
| Per-organization restore from the server backup by the operator | Exact state, IDs kept | Needs the operator; slow; risky merges into the live database |
| Import with restore by ID (overwrite) | Brings back the exact records | Conflicts with revisions, rights and records changed in between; the trash covers accidental deletions |
| Trash without purge | Simplest | Storage of PDFs grows forever |
| Purge by hard delete | Frees everything | Devices offline for more than 30 days would never learn about the deletion |
| Mark imported duplicates in the title | Visible in every list | Changes the ChordPro text, the single source of truth |

## Consequences

- People can keep a copy of their library, move it to another device, another
  organization or another server, and get back accidentally deleted songs and
  sets without the operator.
- New server fields `deleted_at` and `purged` (songs, setlists, attachments), a
  migration and a cron job; client schema 21.
- Code that reads set items must ignore the items of deleted sets.
- Exports of organizations depend on a working connection (mandatory sync);
  the local library can always be exported.
- The archive format is a public interface: changes need a new
  `formatVersion` and an import path for the old ones.

## Decision log

- 2026-11-20: Proposed (#622). Owner decisions: import always as a copy;
  organization export by organization admins and librarians; trash 30 days;
  export allowed on the web client; a sync is mandatory before an
  organization export. Implementation: trash #623, backup archive #625.
- 2026-11-20: Accepted by the owner. Implemented: trash in #631, backup
  archive in #636 (export from the song list menu, local and organization
  alike, also on web).
- 2026-11-20: **ADR-0044** (accepted): the trash will also hold deleted bands and closed organizations for 30 days; the purge removes a closed organization for good and gets an "immediately" option for single records (implemented with #628 and #629).
- 2026-11-20: Implemented for bands (#628, ADR-0044): the daily purge also purges bands deleted more than 30 days ago (memberships and arrangements hard-deleted, sets purged); `POST /api/setding/trash/purge` with `{"collection": "bands", "id": …}` purges one deleted band at once (superusers).

- 2026-11-20: Owner decisions for #639: a full backup in the settings
  (format version 2) with the person's own adjustments of organizations
  without library rights and their settings; restoring the settings is
  optional; a reminder for the local library after 30 days; no automatic
  backups.
- 2026-11-20: Implemented for organizations (#629, ADR-0044): the daily purge first deletes organizations closed more than 30 days ago for good (all their records and attachment files, a tombstone without a name stays); `POST /api/setding/trash/purge` also takes `{"collection": "organizations", "id": …}`.

- 2026-11-21: Proposed: **set archive** (section 1b, #707). Owner
  decisions: `setlist.txt` dropped (no older exports in use); export and
  import with options, personal adjustments off by default; a preview before
  the import; existing band arrangements kept unless overwriting is chosen;
  re-importing a set offers to replace it or add a copy (exception to
  "always as a copy"); missing songs a set planner may not create become text
  items. Rejected: importing a plain-text set list, sending a set to another
  band in the app. Foreign set formats: #708.
- 2026-11-21: Set archive (section 1b) accepted by the owner (#709);
  implementation in #707.

## Open points

- Size limit for archives zipped in memory (large PDF libraries, web).
- Exporting songs and sets (ZIP, text, PDF set list) on the web client too.
