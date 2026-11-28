# ADR-0070: Storage quota for attachments per organization

- **Status:** Proposed
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

*Proposed; the owner decides (see the open points). The recommendation is option
**B**, with the details below.*

### 1. A storage limit per organization, set by the operator

- **`SETDING_ORG_STORAGE_LIMIT_MB`**: the most file storage one organization may
  use on the server, in megabytes.
  - **Default: 2048** (2 GB). That is about 1,000 typical PDFs of 2 MB, more than a
    band's or a music school's library usually needs.
  - **`0` or `off`: no limit.**
  - An invalid value stops the start, like the other `SETDING_*` variables.
- **The same limit for every organization.** A per-organization override (a field
  on `organizations` that only superusers can change) is a possible follow-up, not
  part of this decision (open point 3).
- **Superusers are not limited.** An operator can always move or repair data
  through the admin UI or the API.

### 2. What counts

The limit counts **what is on the disk**:

- every **attachment** of the organization that still has a file (`purged = false`
  and `file != ""`): live attachments, attachments in the trash, and attachments of
  songs in the trash;
- every **report screenshot** of the organization that is not purged.

Counting the trash means that:

- restoring from the trash never fails because of the limit;
- deleting does not free space until the purge. The app points this out (section 5),
  and a follow-up lets a single deleted attachment be purged at once, like songs and
  sets (#866).

### 3. Sizes the server can trust

- **The server sets `size_bytes`** of a new attachment from the uploaded file and
  ignores the value the client sends. Older apps keep working, because they send
  the field and get the correct value back.
- **`song_reports` gets `screenshot_bytes`**, set by the server when a screenshot is
  added.
- **A migration fills in both** for existing records from the stored files.

### 4. Enforced in the create hook, atomically

- **Attachments:** a hook on creating an attachment (and on adding a screenshot to a
  report) works out the new file's size, adds up the organization's usage with one
  SQL query (`SUM(size_bytes)` of section 2 plus `SUM(screenshot_bytes)`), and
  refuses the record if the total would go over the limit.
- **Atomic:** the sum and the insert run in the same write transaction. PocketBase
  sends writes through a single SQLite connection, so two uploads at the same moment
  cannot both pass the check (to be confirmed in the implementation). A server test uploads in parallel at the limit and
  checks that only one succeeds.
- **The request is refused before the file is kept.** PocketBase writes a record's
  files as part of saving it and removes them when the save fails, so a refused
  upload should leave no file behind (to be confirmed in the implementation).
  The server test checks the storage directory.
- **Data over the limit stays.** Organizations that are already over the limit, or
  get over it because the operator lowers it, keep everything. Only new files are
  refused until enough is purged.
- **Everything else still works** at the limit: songs, sets, renaming and deleting
  attachments, reports without a screenshot.

### 5. What the API answers

- **HTTP 400**, like the other validation errors of the hooks, with the field error
  code **`storage_limit_reached`** on `file` (or `screenshot`). Not 413 or 507: those
  mean "request too large" or a server fault, and clients may treat a 5xx as
  temporary and retry the 20 MB upload on every sync.
- **`GET /api/setding/organizations/{id}/storage`**, for the members of the
  organization: `used_bytes`, `limit_bytes` (null without a limit), and the bytes of
  attachments, of the trash and of screenshots. It answers only for members of the
  organization (deny by default, tested through the API).

### 6. What the app shows and does

- **Organization screen**, for organization admins and librarians: "Storage: 1.2 GB
  of 2 GB", including the trash, with a warning from 90 %.
- **Before attaching a PDF online:** if the PDF does not fit any more, the app says
  so at once, with how much is used and that deleted files count until the trash is
  emptied. The server's answer stays the authority; this is only a convenience.
- **When an upload is refused later** (the PDF was attached offline, or the limit was
  reached meanwhile):
  - The attachment **stays on this device** and keeps working there, including live
    mode.
  - It is **marked as not uploaded** (a new device-only status, a client schema
    change): an icon on the attachment, "Only on this device: the organization's
    storage is full", with *Try again*.
  - **A one-time message after the sync** names the PDFs that were not uploaded.
  - **No automatic retry on every sync**, so the app does not re-send 20 MB each
    time. It retries when the user taps *Try again*, or when the storage route shows
    enough room.
- **Report screenshots:** a refused screenshot is dropped, the report is sent
  without it, and the reporter gets a message.
- The existing silent "attachment stays local" for every other refusal gets the same
  marking, with a general text. That fixes the silent loss for the uploader beyond
  this issue.
- All texts in the six ARB files (ADR-0008); the website page on attachments explains
  the limit, with a screenshot of the storage line and of the hint (AGENTS.md).

### 7. Operations

- The self-hosting chapter (ADR-0063) documents `SETDING_ORG_STORAGE_LIMIT_MB` and how
  to size the disk: the limit times the number of organizations, times
  `1 + SETDING_BACKUP_KEEP` in the worst case.
- The configuration check at the start logs the effective limit.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **A. No limit; document the risk, rely on the operator's monitoring** | Nothing to build; nobody is ever blocked | One account can still fill the disk, and backups multiply it; the operator learns about it when the server is full; members' tablets fill up as well; no monitoring exists yet (ADR-0014 open point) |
| **B. One limit per organization from an environment variable** (recommended) | Bounds what one organization can do to the disk and to its members' devices; fits the model (songs and files belong to the organization, ADR-0017); one setting, the ADR-0063 way; can be enforced exactly in one hook | Needs server-set sizes, a migration, a hook, a route and app work (status, messages, texts, website); counting the trash delays freeing space; does not stop many organizations on an `open` server (open point 4) |
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
  - ADR-0009: decision log entry (server-set `size_bytes`, the limit).
  - ADR-0060: decision log entry (screenshots count, refused screenshots).
  - ADR-0043: follow-up to purge a single deleted attachment at once.
  - ADR-0063: the new variable in the configuration list.
  - ADR-0023: the storage route in the matrix (who reads the usage).
- **Compatibility** (ADR-0028): a server migration and a client schema change, both
  minor. Older apps get the 400 and keep the PDF local without a hint, as today.

## Decision log

- 2026-11-28: Proposed (#1198).

## Open points

Questions for the owner:

1. **Limit at all?** Option B (recommended), A, C or D?
2. **Default value:** 2 GB per organization, another value, or no limit by default
   (`off`), so that self-hosters opt in?
3. **Override per organization** (B3) now or later?
4. **`open` registration servers:** anyone can create many organizations, each with
   its own limit. Accept this (invite-only is the default), or add a limit on how
   many organizations one account may found?
5. **What counts:** the trash too (recommended, B) or live attachments only (B1)?
   Screenshots in the same limit (recommended), a separate one, or not at all (B2)?
6. **Freeing space:** let librarians and organization admins purge a single deleted
   attachment at once, as a follow-up of #866?
7. **Who sees the usage:** organization admins and librarians only, or every member?
8. **Per-upload limits (C)** in addition, e.g. a maximum number of attachments per
   song or uploads per day?
