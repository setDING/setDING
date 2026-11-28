# ADR-0004: Backend and synchronization

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Sets and songs are maintained by the band leader and must reach the members'
devices. Requirements: user accounts, band membership with roles, data storage,
change notification. The data volume is small, as is the number of users per band
(typically 3–10). Concurrent editing of the same song is rare.

## Decision

### Backend

A **lean, self-hosted backend**: **PocketBase**
(single Go binary with SQLite, auth, access rules, realtime subscriptions,
admin UI, official Dart SDK), running on the band's existing server.

The backend stays **"dumb"**: it stores records and enforces access rights,
but contains no ChordPro logic.

### Sync strategy

- Every record has `id` (UUID), `revision` (assigned by the server, monotonically
  increasing), `updated_at`, `updated_by`, `deleted` (soft delete).
- **Pull:** The client requests "all changes since revision X" (delta sync). In
  addition, a realtime subscription while online.
- **Push:** Local changes go into an **outbox table** and are sent as soon as a
  network is available.
- **Conflicts:** The client sends the base revision. If the server has moved on,
  songs are **never silently overwritten**: the app shows both versions and lets the
  user choose (or saves the local one as a copy). For sets (ordering) *last writer
  wins* applies, since usually only one person edits them.
- **Files (PDF attachments, ADR-0009):** stored in PocketBase file fields. Metadata is
  synced like other records; files are downloaded in the background afterwards.
  Files are immutable – a change creates a new revision, so there are no file conflicts.
- Sets are edited by admins only; songs by admins and, if enabled for the band, by
  members (ADR-0005). Conflicts are therefore rare but possible, and the conflict
  handling above is required from phase 1 on.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **PocketBase** (chosen) | Minimal operations (1 binary + SQLite file), auth & realtime included, runs on a small VPS/NAS/Raspberry Pi | Still pre-1.0 (API changes possible), scales only vertically |
| Supabase (Postgres) | Mature, hosted or self-hosted, row-level security | Self-hosting considerably more complex (many containers); hosted → data stored abroad |
| Firebase / Firestore | Built-in offline sync, very fast start | Vendor lock-in, Google Cloud, costs hard to predict, no self-hosting |
| Own backend (e.g. Dart Shelf / ASP.NET / Node + Postgres) | Full control | Auth, realtime, admin UI must be built → much more effort |
| No backend: sync via shared folder (Nextcloud/Dropbox/Git) | No server development, ChordPro files directly in the folder | No roles/permissions, file-level conflicts, different APIs per platform |

## Consequences

- The client encapsulates backend access behind a `SyncBackend` interface, so a later switch (e.g. to Supabase or an own backend) only affects the sync layer.
- Operations: set up backups of the server's SQLite file; HTTPS via a reverse proxy (e.g. Caddy).
  Hosting, publication (Cloudflare Tunnel instead of Caddy) and backups: ADR-0014.
- Server access rules ensure that users only see data of their own bands.
- Exception to the "dumb backend": **redeeming invitation links** (ADR-0005) needs a
  small server-side hook (PocketBase `pb_hooks`) that validates the token and creates
  the membership, because access rules alone cannot do this securely. The server also
  serves the invite landing page and the deep-link verification files.

## Decision log

- 2026-11-14: The backend is **self-hosted** on an **existing server**. Managed cloud services (Supabase Cloud, Firebase) and syncing via a shared folder are therefore rejected.
- 2026-11-14: **PocketBase** confirmed as the backend product. Because PocketBase is still pre-1.0, a specific version is pinned and updates are applied deliberately. Client access remains encapsulated behind the `SyncBackend` interface.
- 2026-11-15: Server details and backup concept decided in **ADR-0014** (accepted): Debian LXC on the owner's Proxmox server, PocketBase as a systemd service, published via a Cloudflare Tunnel (replaces the Caddy reverse proxy), daily SQLite online backups, provisioning with `make server-install`.
- 2026-11-15: Details of the data model decided in **ADR-0015** (accepted): one server-wide revision counter incremented in the save transaction, set items stored as JSON in the set, conflict detection for songs with HTTP 409 when the base revision is outdated.

- 2026-11-15: Sync of songs and sets implemented (issue #17, owner asked to finish the remaining features without further questions): local tables `sync_outbox` (one row per changed record with a version counter, so a change during a push is not lost), `sync_cursors` (last pulled revision per organization/band and collection) and `song_conflicts` (server version of a song changed on both sides). A run refreshes organizations and bands, pulls songs per organization and sets per band, then pushes the outbox; songs are pushed with their base revision and a 409 or a pull of a locally changed song becomes a conflict the user resolves on the song screen (keep mine, use server version, keep both); sets use last writer wins. Records the user may no longer change stay local (replaced on 2026-11-28, #1260: they are undone and the person is told). Syncs start after sign-in and at start, 3 s after local changes, on realtime events and every 5 minutes, never while live mode is open (ADR-0007). Local edits no longer change `revision`, which is always the server revision. The local library is never synced.
- 2026-11-15: Sync records that never reached the server (revision 0, e.g. created before the outbox existed) are added to the outbox before each push (issue #29).
- 2026-11-15: When syncs start is a device setting (issue #40, requested by the owner): *at start* (default: once at app start and after signing in), *automatic* (as before: also 3 s after local changes, on realtime events and every 5 minutes) or *manual*. "Sync now" is always available. Automatic mode reacts only to new or changed outbox entries, so the entries a sync removes after pushing no longer start the next sync.
- 2026-11-15: Automatic mode loads the organizations and bands only when they may have changed (owner request after the code review): at start, after signing in, every 5 minutes, on "Sync now" and on realtime events of `organizations`, `org_memberships`, `bands` and `memberships` (now subscribed as well). Realtime events of songs, sets, attachments and personal adjustments and local changes sync with the bands stored on the device.
- 2026-11-17: Pulling down and releasing the list of sets or songs starts a sync like "Sync now" (issue #384, requested by the owner), in every sync mode and only while signed in. A failed sync is shown in a snack bar; an outdated app is left to the update banner (ADR-0029).
- 2026-11-17: **Undo of deletions** (issue #267): deleting a song, set, set item or attachment shows a message with "Undo" for a few seconds. Undo restores the record as a normal local change (`deleted` back to false, set items back at their place) that gets an outbox entry and a new server revision like any edit; nothing about the sync protocol changes. If the deletion was pushed already, the device holds the deletion's revision as its base, so the restore is accepted without a conflict (the next pull skips the deletion it pushed itself). Attachment files are no longer deleted together with their record but once the undo is no longer offered, and at app start for deleted attachments left behind, so a restored attachment still has its file offline (and an attachment that never reached the server can still be uploaded). On the server, restoring a song restores the personal adjustments and band arrangements its deletion had soft-deleted (those deleted after the song's deletion revision, `pb_hooks/songs.pb.js`, ADR-0015). Confirmation dialogs stay for songs and sets (shared with the organization or band, and the screen closes) and are dropped for attachments; removing a set item never asked.
- 2026-11-17: **Rate limits** (issue #303): the server keeps PocketBase's default limits besides its own (ADR-0024), among them `*:create` 20 requests per 5 s per IP address, so pushing a large backlog (e.g. after importing many songs) stopped the sync with HTTP 429. The PocketBase backend now runs a request rejected with 429 again after 1, 2, 4, 8 and 16 s (longer than the windows of the default limits) before it fails; this covers pulls, pushes, band management and attachment downloads. Signing in, signing up and invitations are not retried: their limits protect against guessing. The server limits stay unchanged.
- 2026-11-17: **PocketBase 0.42.3 from its new host** (issue #389): PocketBase moved off GitHub on 2026-10-26; the GitHub repository is archived at v0.40.6 and new releases are published only at `https://ganigeorgiev.com/pocketbase/pocketbase`. The binary is now downloaded from the documented release URL `https://ganigeorgiev.com/meta/pocketbase/pocketbase/download/v<version>/<file>` and still verified against the release's `checksums.txt`; the pin moves from 0.40.6 to 0.42.3. Since 0.42.0 PocketBase refuses unknown or invalidated `Authorization` tokens with 401 on every route (before, they were ignored and the request ran as a guest). The app is not affected: the Dart SDK never sends an expired token, and a 401 already signs the user out (ADR-0016); the version check still answers outdated clients with 426 before that (ADR-0029). Server tests cover both.
- 2026-11-21: **ADR-0053** (#804): the language version group and the language of a song are last writer wins per field. The client pushes each changed field on its own (outbox collection `song_links`, record ID `<song>:<field>`, after the songs) without a base revision; the server compares a song's base revision with its `content_revision`, so a link change is never a conflict, and a pulled song whose content is unchanged since the local base only moves the base on. A pulled link value never replaces one still in the outbox.
- 2026-11-20: **ADR-0043** (accepted, #622): songs, setlists and attachments get `deleted_at` and `purged`; deleting a set keeps its items (pushed with the deleted set) so it can be restored from the trash within 30 days; a daily server job then purges content and files but keeps the record as a tombstone, so delta sync still delivers the deletion.
- 2026-11-28: **Randomized convergence test** (#1245): several simulated devices of different people make random changes to songs, sets, attachments and personal adjustments, go offline, sync in random order and get transient errors, lost answers and refused attachment changes from the fake server; after a final round every device must agree with the server (`app/test/sync_convergence_test.dart`, docs/development/fuzz-tests.md). Divergences it found and fixed: (1) a create whose answer got lost and that is pulled before it is sent again now takes the server's revision, so a later change of the same record (e.g. its deletion) is pushed as a change instead of being dropped as "deleted before it reached the server" (sets and attachments; songs already became a conflict the person resolves); (2) an attachment upload sent again after its answer got lost is no longer marked as refused: PocketBase answers the second create of the same ID with 400 `validation_pk_invalid` (pinned in `server/test/attachments_test.dart`), which is now sent again as a change; (3) when the server's song is no longer deleted (restored, or kept in a conflict on another device), a device that deleted it pulls its deleted attachments again, so those deleted only together with the song come back (a song deletion never pushes its attachments); (4) a personal adjustment of a song deleted on this device waits while the deletion is still to push, so it is not lost when the deletion becomes a conflict resolved with the server's version.
- 2026-11-28: **Refused song, set and adjustment changes are undone and told once** (owner decision, #1260; resolves the open point from #1245 and replaces "records the user may no longer change stay local" of 2026-11-15). A change of a song (also its link fields and review status), a set or a personal adjustment that the server refuses for good (`BackendException.refused`: 403/404 and 400 validation errors) is undone in the same sync run, as attachment changes are since #1229: the record on this device counts as one revision older than the server's, the pull cursor of its organization, band or user goes below it, the outbox entry is removed, and after the push the scope is pulled again; a record the server does not send back (not visible to the person any more, or a new record the server never took) is removed from this device with what belongs to it (a song with its attachments, adjustments, annotations, reports and set items), as #1248 does for attachments. The changes are listed in `SyncReport.undoneChanges` and shown once after the sync; undone records are not recorded as changes of others (ADR-0045). A 400 no longer stops the sync at the same outbox entry; transient errors (network, 5xx, 408, 429) keep the entry and are sent again. The mechanism is shared by songs, sets, attachments and adjustments (`app/lib/sync/engine/refused_changes.dart`). The convergence test injects these refusals as well.

## Open points

- Should there be a version history for songs (restore earlier versions)?
- **A new song the server refuses** (#1260): it is removed from the device like any undone record, so its text is gone (the client only offers creating songs to people who may). Should it be kept in the local library ("On this device") instead?
- **Refusals of the other collections** (#1260): mistake reports, people without an account, annotations, band arrangements and settings still drop a 403/404 in silence, and a 400 there still stops the sync at the same entry.
- **A song deleted while another device adds it to a set** (#1245): the server keeps the set item (last writer wins), the deleting device and those that pulled the deletion remove it locally without pushing the set (`SongSync.writeSong`), others keep it as "song missing"; after the song is restored, it is in the set on the server and some devices but not on others. Should pulled deletions keep the server's items, or should the server remove a deleted song from its sets?
