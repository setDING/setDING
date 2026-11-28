# ADR-0070: Storage quota for attachments per organization

- **Status:** Accepted
- **Date:** 2026-11-28

## Context

Issue #1198 (app review of 2026-11-27): nothing limits how much file storage an
organization uses on the server. One account can fill the server's disk.

**What is stored today:**

- **PDF attachments** (ADR-0009, ADR-0017): collection `attachments`, one file per
  record (`file`, `maxSize` 20 MB, `application/pdf` only, protected), plus `pages`
  and `size_bytes`.
  - Who may upload (ADR-0023): organization admins, librarians, and band leaders for
    their own songs.
  - There is no limit on the number of attachments per song or per organization.
  - **`size_bytes` is sent by the client** and stored as it comes. The server does
    not check it against the file, so it cannot be trusted for a quota as it is.
  - Files are immutable (`pb_hooks/attachments.pb.js`). Replacing a PDF creates a
    new attachment and deletes the old one.
- **Report screenshots** (ADR-0060): collection `song_reports`, field `screenshot`
  (1 MB, PNG/JPEG/WebP, added once). **Every member** of the organization may write
  reports, so the group that can upload is much larger than for attachments. There
  is no size field.
- **Image attachments** for `{image}` (ADR-0012) stay on the device. The server
  accepts PDFs only.

**Where the files stay:**

- **Trash** (ADR-0043): a deleted attachment keeps its file for 30 days. The daily
  purge (`pb_hooks/lib/trash.js`) clears `file` and keeps the record as a tombstone
  (`purged`).
  - Deleting a song does not delete its attachments on the server. They are purged
    together with the song.
  - A user can purge a deleted **song** or **set** at once (#866, `PURGEABLE`), but
    not a single deleted attachment of a song that is still in the library. Its file
    stays on the disk until the daily purge.
- **Closing an organization** (ADR-0044) removes all its files after 30 days.

**Why the size matters beyond the server's disk:**

- **Server backups** (ADR-0063, `SETDING_BACKUP_CRON`, `SETDING_BACKUP_KEEP`, default
  14) are PocketBase backups of `pb_data` including `storage/`. In the worst case
  the disk holds the files once plus once per kept backup. The owner's servers are
  small (ADR-0014: 16 GB disk on the test server; a VPS Lite in production).
- **Every device** of every member downloads **all** attachments of its
  organization (ADR-0009, no selective download). A large library also fills the
  members' tablets and makes the first sync slow.

**How the app uploads** (`app/lib/sync/engine/attachment_sync.dart`):

- A PDF is attached **locally first** (offline-first, ADR-0001) and uploaded with
  the next sync as a multipart create of the attachment record.
- If the server refuses the create for any reason other than the network or a lost
  session, the app **logs a warning, marks the outbox entry as done, and keeps the
  attachment on this device only**. The user is not told, and bandmates never get
  the file.

**Constraints:**

- **The server enforces everything** (owner rule #632, `server/AGENTS.md`). A quota
  that only the app checks is no quota.
- **Configuration is through environment variables** (ADR-0063, `SETDING_*`). The
  admin UI may not be the only place a setting lives, and invalid values stop the
  start (`pb_hooks/lib/operations.js`).
- **Registration:** a server is `invite_only` by default (ADR-0024); with
  `SETDING_REGISTRATION=open` anyone can create organizations.

## Decision

*Option **B**, with the details below. The owner answered every open point on
2026-11-28 (see the decision log).*

**Sizing basis (owner, 2026-11-28):** the production server has 20 GB of disk. The
owner's library of about 100 songs holds 45 PDFs with 5.9 MB in total: 133 KB on
average, 131 KB median, 243 KB at most.

### 1. A storage limit per organization, set by the operator

- **`SETDING_ORG_STORAGE_LIMIT_MB`**: the most file storage one organization may
  use on the server, in megabytes.
  - **Default: 25** (25 MB). That is about 190 PDFs of today's average size, four
    times the owner's library, and keeps many organizations and their backups
    within a small disk.
  - **`0` or `off`: no limit.**
  - An invalid value stops the start, like the other `SETDING_*` variables.
- **The same limit for every organization.** A per-organization override (a field
  on `organizations` that only superusers can change) is a later follow-up, not
  part of this decision.
- **Superusers are not limited.** An operator can always move or repair data
  through the admin UI or the API.
- **Servers with `open` registration:** anyone can found several organizations,
  each with its own limit. This is accepted and documented: servers are
  `invite_only` by default (ADR-0024), where only founder invitations create
  organizations.

### 2. Maximum file sizes

- **PDF attachments: at most 1 MB** per file (today 20 MB), the `maxSize` of the
  `file` field, changed by a migration. That is four times the owner's largest PDF.
  Existing larger files stay; only new uploads are checked.
- **Report screenshots: at most 300 KB** (today 1 MB). The app scales a screenshot
  down before it is sent, so reporting never fails on the size.
- **The maximum size is shown before the upload:** wherever a PDF is attached, the
  app states "PDF, at most 1 MB" (and the storage still free, section 7) before the
  user picks a file, and refuses a larger file at once with the same text, also
  offline. The server's limit stays the authority.
- **No further upload limits** (per song, per day): 1 MB per file and the limit per
  organization are enough; the existing create rate limit stays.

### 3. What counts

The limit counts **the PDF attachments on the disk**: every attachment of the
organization that still has a file (`purged = false` and `file != ""`), that is
live attachments, attachments in the trash, and attachments of songs in the trash.

**Report screenshots do not count.** Their own maximum size (section 2) bounds
them.

Counting the trash means that restoring from the trash never fails because of the
limit, and that deleting does not free space until the purge. Therefore:

- **A single deleted attachment can be purged at once** by organization admins and
  librarians, like songs and sets (#866, ADR-0043). It is part of this decision,
  not a follow-up.
- The app says that deleted PDFs count until they are purged (section 7).

### 4. Sizes the server can trust

- **The server sets `size_bytes`** of a new attachment from the uploaded file and
  ignores the value the client sends. Older apps keep working, because they send
  the field and get the correct value back.
- **A migration fills in `size_bytes`** for existing records from the stored files.

### 5. Enforced in the create hook, atomically

- **Attachments:** a hook on creating an attachment works out the new file's size,
  adds up the organization's usage with one SQL query (`SUM(size_bytes)` of
  section 3), and refuses the record if the total would go over the limit.
- **Atomic:** the sum and the insert run in the same write transaction, which the
  hook opens before the sum. PocketBase sends writes through a single SQLite
  connection, so two uploads at the same moment cannot both pass the check. A
  server test uploads in parallel at the limit and checks that only one succeeds.
- **The request is refused before the file is kept.** PocketBase writes a record's
  files as part of saving it and removes them when the save fails, so a refused
  upload leaves no file behind. The server test checks the storage directory.
- **Data over the limit stays.** Organizations that are already over the limit, or
  get over it because the operator lowers it, keep everything. Only new files are
  refused until enough is purged.
- **Everything else still works** at the limit: songs, sets, renaming and deleting
  attachments, reports and their screenshots.

### 6. What the API answers

- **HTTP 400**, like the other validation errors of the hooks, with the field error
  code **`storage_limit_reached`** on `file`. Not 413 or 507: those mean "request
  too large" or a server fault, and clients may treat a 5xx as temporary and retry
  the upload on every sync. A file over 1 MB gets PocketBase's own size validation
  error on `file`.
- **`GET /api/setding/organizations/{id}/storage`**: `used_bytes`, `limit_bytes`
  (null without a limit), and the bytes of live attachments and of the trash. It
  answers only for **the people who may upload PDFs** in the organization (ADR-0023:
  organization admins, librarians, band leaders of one of its bands); deny by
  default, tested through the API as every other role.

### 7. What the app shows and does

- **Storage usage** for everyone who may upload PDFs (organization admins,
  librarians, band leaders): "Storage: 12 MB of 25 MB", including the trash, on the
  organization screen and where PDFs are attached, with a warning from 90 %.
- **Before attaching a PDF:** the maximum size and the free storage are shown
  (section 2). If the PDF is too large or does not fit any more (online), the app
  says so at once, with how much is used and that deleted files count until they
  are purged, and offers to open the trash. The server's answer stays the
  authority; this is only a convenience.
- **When an upload is refused later** (the PDF was attached offline, or the limit was
  reached meanwhile):
  - The attachment **stays on this device** and keeps working there, including live
    mode.
  - It is **marked as not uploaded** (a new device-only status, a client schema
    change): an icon on the attachment, "Only on this device: the organization's
    storage is full", with *Try again*.
  - **A one-time message after the sync** names the PDFs that were not uploaded.
  - **No automatic retry on every sync**, so the app does not re-send the file each
    time. It retries when the user taps *Try again*, or when the storage route shows
    enough room.
  - The marking for any refused upload comes with #1225; this decision adds the
    storage text.
- **Report screenshots** are scaled to at most 300 KB before sending (section 2).
- All texts in the six ARB files (ADR-0008); the website page on attachments explains
  the limits, with screenshots of the size hint, the storage line and the refusal
  (AGENTS.md).

### 8. Operations

- The self-hosting chapter (ADR-0063) documents `SETDING_ORG_STORAGE_LIMIT_MB` and how
  to size the disk: the limit times the number of organizations, times
  `1 + SETDING_BACKUP_KEEP` in the worst case.
- The configuration check at the start logs the effective limit.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **A. No limit; document the risk, rely on the operator's monitoring** | Nothing to build; nobody is ever blocked | One account can still fill the disk, and backups multiply it; the operator learns about it when the server is full; members' tablets fill up as well; no monitoring exists yet (ADR-0014 open point) |
| **B. One limit per organization from an environment variable** (chosen) | Bounds what one organization can do to the disk and to its members' devices; fits the model (songs and files belong to the organization, ADR-0017); one setting, the ADR-0063 way; can be enforced exactly in one hook | Needs server-set sizes, a migration, a hook, a route and app work (status, messages, texts, website); counting the trash delays freeing space; does not stop many organizations on an `open` server (accepted) |
| B1. As B, but counting live attachments only | Deleting frees space at once | The trash and the backups are still on the disk; a restore can fail on the limit; delete, re-upload, delete fills the disk within the 30 days |
| B2. As B, without report screenshots | Screenshots stay unlimited for members; simpler | Every member can upload any number of 1 MB screenshots, so the gap of #1198 stays open for the largest group |
| B3. As B, with an override per organization | The operator can give a large school more | A superuser-only field, more tests; not needed while one limit fits (follow-up) |
| **C. Per-upload limits only** (lower than 20 MB, a maximum number of attachments per song, uploads per user per day) | Simple; no totals to keep | Bounds the speed, not the total: the disk still fills, only more slowly; a lower file size blocks real scores; can be added to B later |
| **D. A quota per user** (the uploader) | Each person is accountable for their uploads | Files belong to the organization, not to the uploader (ADR-0017); unclear when the uploader leaves or deletes their account (ADR-0052); every librarian adds a full quota, so neither the organization nor the devices are bounded |
| E. A server-wide limit only (all organizations together, or free disk space) | Protects the disk whatever the number of organizations | One organization can still take everything and block all others; free disk space is not readable from the PocketBase hooks |

## Consequences

- **Easier:**
  - The disk use of the server has an upper bound the operator can plan with:
    organizations × limit × (1 + kept backups).
  - The size of a library on the members' tablets is bounded as well.
  - Upload refusals are no longer silent for the uploader.
- **Harder:**
  - A full organization cannot add PDFs until it purges. Deleting alone does not
    help for up to 30 days, until single attachments can be purged at once.
  - A PDF attached offline may later turn out to exist on one device only.
  - More to build and test: server-set sizes, the migration, the hook, the route,
    the device status, messages in six languages, the website page and screenshots.
- **Changes to other ADRs (on acceptance):**
  - ADR-0009: decision log entry (server-set `size_bytes`, 1 MB per PDF, the limit).
  - ADR-0060: decision log entry (screenshots at most 300 KB, scaled by the app; not counted).
  - ADR-0043: a single deleted attachment can be purged at once (organization admins, librarians).
  - ADR-0063: the new variable in the configuration list.
  - ADR-0023: the storage route in the matrix (who reads the usage).
- **Compatibility** (ADR-0028): a server migration and a client schema change, both
  minor. Older apps get the 400 and keep the PDF local without a hint, as today.

## Decision log

- 2026-11-28: Proposed (#1198).
- 2026-11-28: The owner answered the open points:
  1. Option **B**, a limit per organization from `SETDING_ORG_STORAGE_LIMIT_MB`.
  2. **Default 25 MB** (production disk 20 GB; the owner's 45 PDFs use 5.9 MB, at
     most 243 KB each), and **at most 1 MB per PDF**. The maximum size is shown
     before a file is uploaded.
  3. **No per-organization override** for now; a later follow-up.
  4. **Many organizations on `open` servers are accepted** and documented.
  5. **PDFs including the trash count; screenshots do not**, but get their own
     maximum of 300 KB.
  6. **Organization admins and librarians may purge a single deleted attachment
     at once**, as part of this decision.
  7. **The usage is shown to everyone who may upload PDFs** (organization admins,
     librarians, band leaders).
  8. **No further upload limits.**
- 2026-11-28: Accepted by the owner.
- 2026-11-28: The marking of any refused upload is implemented (#1225, ADR-0009): local column `attachments.upload_refused` (schema 43) with the reasons *no permission*, *too large* and *refused*, the one-time message after the sync and *Upload again* in the attachment's menu. The quota adds a reason of its own for `storage_limit_reached` (today it shows as *refused by the server*) and the retry when the usage route shows enough room.
- 2026-11-28: Server part implemented (#1226); the two points to be confirmed
  (section 5) are settled by server tests (`server/test/storage_test.dart`):
  - **Serialised:** PocketBase does *not* run a create request in a transaction of
    its own; only a transaction serialises (all writes go through one SQLite
    connection). The check therefore opens the write transaction itself, before
    the sum, and the save joins it (`pb_hooks/storage.pb.js`). Without it, two of
    six parallel uploads at the limit passed; with it, exactly one does.
  - **No file left behind:** the check runs before the save, and PocketBase writes
    the file only with the insert, so a refused upload leaves no file in the
    storage directory, also for the parallel ones.
  - The route answers `used_bytes`, `limit_bytes` (null without a limit),
    `live_bytes` (attachments of songs in the library) and `trash_bytes`
    (deleted attachments and those of deleted songs), and 404 to everyone who
    may not upload PDFs and for a closed organization.

## Open points

- None.
