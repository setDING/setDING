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

**Format** (`Backup <library> <yyyy-mm-dd>.setDING.zip`):

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
  overwritten"; replacing is a normal change of the set, synced like an
  edit. The origin is the setlist field `origin` (schema 28, server
  migration `1796500000_set_origin.js`); exporting an imported set keeps
  the original ID, so copies of copies are found too. Replacing is the
  default.
- **Copy names:** an added set keeps its name unless the band has a set
  (not deleted) with the same name (ignoring case) and the same gig date
  (or both without one); then it gets the first free "<name> (copy)",
  "<name> (copy 2)", … in the importer's language. The preview shows the
  name (#719).
- **Missing songs** that the person may not create (set planner, ADR-0023)
  become text items "missing: <title>" in the set and are listed in the
  import report; the set is imported anyway.
- Rights are those of the records created or changed (sets, set items,
  arrangements, songs); the server enforces them as for any other change.

### 1c. Song archive (#792)

The export of a song (only its ChordPro file) gets a second form: a **song
archive** that holds one or several songs with their attachments and can be
imported again **like a set archive** (section 1b), only without a set:

- **Format:** `songs/<title> (<short id>).cho` and the attachments as in
  the backup archive, plus a `manifest.json` with `format: "setding-songs"`,
  `formatVersion: 1`, the app version, the creation time, the source library
  (ID and name), the export options and the songs with their original IDs
  and their attachments' metadata; depending on the options also the band
  arrangements of the songs (ADR-0025, of the band selected when exporting)
  and the **exporting person's own** personal adjustments and annotations.
  Field-by-field reference with an example, for tools that write song
  archives: [`docs/formats/song-archive.md`](../../formats/song-archive.md).
- **Export:** from the song's menu ("Export …", a dialog with the format:
  ChordPro file or setDING archive) and for several songs from the selection
  mode of the song list (archive only). Options: attachments (on), band arrangements (off), own personal
  adjustments and annotations (off, because the archive is often passed on).
  Anyone who sees the songs may export them.
- **Import with a preview,** like the set import: a ZIP with such a manifest
  is recognised by the normal import. Before anything is written, a preview
  shows the target (the current library; a band for the arrangements), the
  songs (already there, new, text differs), the attachments that will be
  added and the options the archive holds.
- **Songs** follow the duplicate rule of section 1 (identical songs reused,
  differing ones optionally added); band arrangements already present in the
  target band are kept unless the preview's option overwrites them.
- **Attachments of existing songs are completed:** when a song of the
  archive is reused, its attachments that the existing song does not have
  (no attachment with the same name, ignoring case) are added, if the person
  may edit the song (ADR-0023). This applies to the set archive as well,
  whose preview shows them too; the backup archive keeps existing songs
  unchanged.
- The import is offered where songs are imported, to people who may create
  songs in the library (ADR-0023); band arrangements go to a band whose sets
  the person may manage, chosen in the preview.

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
  songs) and per band (sets, for people who may manage sets), grouped by
  deletion time (today, this week, older), with the deletion date and the
  days left as a badge (in the warning colour on the last three days);
  restoring is a normal change synced like an edit.
- **Deleting permanently** (#866): each entry's menu has *Delete
  permanently…*, a long press selects several entries (restore or delete
  them permanently), and *Empty trash* deletes all; each after a destructive
  confirmation. The right is the right to delete the record (songs:
  organization admins and librarians; sets: set managers, ADR-0023). It is a
  normal synced change, so it works offline: the client sends `purged: true`
  with a deleted song or set (deleted before or in the same request); the
  server clears its content like the daily purge (song text and, with a
  song, its attachments and their files; set items) and keeps the tombstone.
  The update rule of songs refuses a change of `purged` to band leaders as
  it refuses `deleted`; `purged` on a record that is not deleted, or on an
  attachment, is ignored. A purge of a song is a content change, so a song
  restored and changed elsewhere in the meantime gives a conflict instead of
  being purged; sets are last writer wins. In the local library the records
  and their files are removed at once.
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
- 2026-11-21: Implemented (#707): `SetArchiveService` (format `setding-set`,
  version 1) shares the song and personal import with the backup; export
  dialog in the set's menu, import from the import dialog of the song list
  and from the set list's menu (also for set planners); setlist field
  `origin`.
- 2026-11-21: Owner decisions (#719): the import dialog gets sections with
  headings (destination, set already here, songs, include), segmented
  buttons and song status rows; an added set is renamed as a copy when the
  band has a set with the same name and date.
- 2026-11-21: Proposed: **song archive** (section 1c, #792). Owner
  decisions: one or several songs; export options for band arrangements and
  own personal adjustments as for the set archive; attachments missing on an
  existing song are added (also for the set import); a preview
  before the import like the set import.
- 2026-11-21: Song archive (section 1c) accepted by the owner and
  implemented (#792): `SongArchiveService` (format `setding-songs`,
  version 1) shares the song import with the set and backup archives;
  export from the song's menu and the song list's selection mode, import
  with a preview from the import dialog; `importSongs` completes the
  attachments of reused songs for set and song archives.
- 2026-11-22: **ADR-0054** (accepted, #832): for the local library only,
  an optional automatic backup into a folder the person chooses replaces
  "No automatic backups" (section 1a), and a backup of a local library can
  also be restored by replacing the whole local library with the original
  IDs, an exception to "import always as a copy" (section 1). Organizations
  are unchanged.
- 2026-11-22: One export entry per object (#870): the song's menu, the
  song list's selection and the set's menu have one entry "Export …" that
  opens a dialog with the format at the top (song: ChordPro file or setDING
  archive; set: set list as PDF or setDING archive). The archive options
  show only for the archive, the hint follows the format, and the dialog
  preselects the format exported last while the app runs. The menu labels
  named a format or one option ("Export with attachments" was wrong once
  attachments were unticked). The archives keep the `.zip` extension.
- 2026-11-22: The manifest's `source` may carry an optional `device`, the
  device that wrote the archive (the automatic backup of ADR-0054, #841);
  readers ignore it, the format version stays 1.
- 2026-11-22: Archive file names end in **`.setDING.zip`** (#874): song,
  set and backup archives stay plain ZIP files for pickers, mail and unzip
  tools but show that they belong to setDING. The redundant prefix goes:
  `Songs <date>.setDING.zip`, `Backup <library> <date>.setDING.zip`. Imports
  still recognise archives by the manifest, so older `.zip` files import as
  before. A real own extension (`.setding`) with file associations was
  considered and left out: it needs a registered type on every platform, and
  without one the file pickers may hide the files.

- 2026-11-22: Owner decisions (#866): the trash can **delete permanently**
  (single entries, a selection, or the whole trash, each confirmed), allowed
  to whoever may delete the record; the trash screen is grouped by deletion
  time with the days left as a badge and a menu per entry, and a selection
  mode like the song list. Implemented in #866: the client sends `purged`
  with a deleted song or set; server migration
  `1796900000_trash_purge_rights.js`.
- 2026-11-22: The songs of the manifest may carry an optional `createdAt`
  (the creation date of ADR-0045's *Newest songs*, #876); readers that do
  not know it ignore it, the format version stays 1.
- 2026-11-28: A single deleted attachment can be deleted permanently at once (ADR-0070, #1226): `attachments` joins `PURGEABLE` (#866), for organization admins and librarians (the right to delete it); its file is removed and the record stays as a tombstone, so its size no longer counts against the storage limit.
- 2026-11-28: The songs trash of an organization's library lists the PDFs deleted
  on their own as well, to restore or delete permanently (ADR-0070, #1226).
- 2026-11-28: Archives and backups skip attachments over the maximum size of their
  type (1 MB for a PDF, ADR-0070, #1226); the import summary names them.

## Open points

- Size limit for archives zipped in memory (large PDF libraries, web).
- Exporting songs and sets (ZIP, text, PDF set list) on the web client too.
