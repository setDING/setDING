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

- 2026-11-15: Sync of songs and sets implemented (issue #17, owner asked to finish the remaining features without further questions): local tables `sync_outbox` (one row per changed record with a version counter, so a change during a push is not lost), `sync_cursors` (last pulled revision per organization/band and collection) and `song_conflicts` (server version of a song changed on both sides). A run refreshes organizations and bands, pulls songs per organization and sets per band, then pushes the outbox; songs are pushed with their base revision and a 409 or a pull of a locally changed song becomes a conflict the user resolves on the song screen (keep mine, use server version, keep both); sets use last writer wins. Records the user may no longer change stay local. Syncs start after sign-in and at start, 3 s after local changes, on realtime events and every 5 minutes, never while live mode is open (ADR-0007). Local edits no longer change `revision`, which is always the server revision. The local library is never synced.
- 2026-11-15: Sync records that never reached the server (revision 0, e.g. created before the outbox existed) are added to the outbox before each push (issue #29).
- 2026-11-15: When syncs start is a device setting (issue #40, requested by the owner): *at start* (default: once at app start and after signing in), *automatic* (as before: also 3 s after local changes, on realtime events and every 5 minutes) or *manual*. "Sync now" is always available. Automatic mode reacts only to new or changed outbox entries, so the entries a sync removes after pushing no longer start the next sync.
- 2026-11-15: Automatic mode loads the organizations and bands only when they may have changed (owner request after the code review): at start, after signing in, every 5 minutes, on "Sync now" and on realtime events of `organizations`, `org_memberships`, `bands` and `memberships` (now subscribed as well). Realtime events of songs, sets, attachments and personal adjustments and local changes sync with the bands stored on the device.
- 2026-11-17: **Undo of deletions** (issue #267): deleting a song, set, set item or attachment shows a message with "Undo" for a few seconds. Undo restores the record as a normal local change (`deleted` back to false, set items back at their place) that gets an outbox entry and a new server revision like any edit; nothing about the sync protocol changes. If the deletion was pushed already, the device holds the deletion's revision as its base, so the restore is accepted without a conflict (the next pull skips the deletion it pushed itself). Attachment files are no longer deleted together with their record but once the undo is no longer offered, and at app start for deleted attachments left behind, so a restored attachment still has its file offline (and an attachment that never reached the server can still be uploaded). On the server, restoring a song restores the personal adjustments and band arrangements its deletion had soft-deleted (those deleted after the song's deletion revision, `pb_hooks/songs.pb.js`, ADR-0015). Confirmation dialogs stay for songs and sets (shared with the organization or band, and the screen closes) and are dropped for attachments; removing a set item never asked.

## Open points

- Should there be a version history for songs (restore earlier versions)?
