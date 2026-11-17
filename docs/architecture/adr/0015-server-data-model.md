# ADR-0015: Server data model and access rules

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Phase 1 needs the PocketBase data model behind login, bands, invitations and sync.
ADR-0004 fixes the sync strategy (client UUIDs, server revisions, soft delete,
conflict handling for songs, last writer wins for sets) and ADR-0005 the
permissions. The details are not covered by those ADRs: how revisions are
assigned so that delta sync never misses a change, how set items are stored, how
permissions are enforced, and which (small) server logic is needed besides the
invitation hook.

## Decision

The schema is defined as versioned migrations in
[`server/pb_migrations`](../../../server/pb_migrations), the server logic in
[`server/pb_hooks`](../../../server/pb_hooks); both are deployed with
`make server-install` and tested against a real PocketBase in
[`server/test`](../../../server/test) as part of `make check`.

### Collections

| Collection | Fields (besides sync fields) | Synced |
|---|---|---|
| `users` | PocketBase auth collection (`email`, `name`, `avatar`) | – |
| `bands` | `name`, `members_can_edit_songs` | ✓ |
| `memberships` | `user`, `band`, `role` (`admin`/`member`); unique per user and band | ✓ |
| `songs` | `band`, `chordpro`, `title` (redundant copy for the admin UI and conflict dialogs) | ✓ |
| `attachments` | `band`, `song`, `name`, `file` (PDF, max. 20 MB, protected), `pages`, `size_bytes` | ✓ |
| `setlists` | `band`, `name`, `gig_date`, `venue`, `items` (JSON array) | ✓ |
| `invites` | `band`, `token_hash` (hidden), `expires`, `revoked`, `created_by` | – |

Other song metadata (artist, key, tempo, tags, sort fields) is derived from the
ChordPro text in the client (ADR-0003) and not stored on the server.
Personal overlays (ADR-0006, ADR-0020) are stored in `overlays` (see the
decision log).

### Sync fields

Every synced record has a client-generated **UUID `id`** (the server generates a
UUID v4 only if none is sent), **`revision`**, **`updated_by`**, **`deleted`** and
the autodate fields `created`/`updated`.

- **One server-wide revision counter** (table `realchord_sync`). A hook increments
  it in the **same transaction** that saves the record; SQLite serializes writes, so
  revisions become visible in increasing order and "all changes since revision X"
  never misses a change. Because the counter is shared, a client can keep a single
  cursor per band.
- `revision` and `updated_by` are always set by the server; values sent by clients
  are ignored.
- Synced records are **never hard-deleted** through the API, not even by superusers;
  clients set `deleted`. Removing a member is `memberships.deleted = true`, so the
  affected device learns about it through sync.
- `attachments.band` is redundant to `song.band` so that delta sync filters every
  collection by band.

### Set items as JSON

The ordered items of a set (song reference, set-specific transposition and
sequence, pauses and text entries, each with its own UUID) are stored as **one JSON
array** in `setlists.items`, not as separate records. A set is always saved and
synced as a whole, which makes *last writer wins* (ADR-0004) consistent: concurrent
edits can never produce a mixed or duplicated ordering.

### Conflict detection for songs

When updating a song, the client sends the revision its change is based on in
`revision`. If it differs from the server's revision, the server refuses the update
with **HTTP 409** and the client resolves the conflict (ADR-0004). A missing base
revision is refused with 400 for users (superusers in the admin UI are exempt).
Sets and other collections use last writer wins.

### Access rules (ADR-0005)

Enforced with PocketBase API rules; the client only mirrors them in the UI.

| Collection | Read | Create | Update |
|---|---|---|---|
| `bands` | members | any signed-in user (becomes admin) | admins |
| `memberships` | own membership, members of the band | hooks only (band creation, invitations) | admins (role, remove); a member may only leave |
| `songs`, `attachments` | members | admins; members if `members_can_edit_songs` | same as create; `deleted` admins only |
| `setlists` | members | admins | admins |
| `invites` | admins | – (invitation hooks, issue #16) | – |
| `users` | self and current bandmates | sign-up open | self |

- Records cannot be moved to another band (`band`, `song`, `user` are fixed after
  creation); an attachment's song must belong to its band.
- Attachment **files are immutable**; a new file is a new attachment record.
- A band must always keep **at least one admin**: demoting or removing the last
  active admin is refused (hook, applies to superusers too).
- PDF files are **protected**: downloading needs a short-lived file token and read
  access to the attachment.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Server-wide revision counter in the save transaction** (chosen) | Gap-free, ordered delta sync; one cursor per band | One extra write per save; requires wrapping write requests in a transaction |
| Revision per collection or per record (`revision + 1`) | Simple | A per-record counter cannot answer "changes since X"; per-collection needs several cursors |
| `updated` timestamp as sync cursor | No hook needed | Clock resolution and transaction order can skip changes |
| **Set items as JSON in the set** (chosen) | Atomic, consistent last writer wins, one record per set | Items cannot be queried individually on the server (not needed) |
| Set items as separate records | Mirrors the local table | Concurrent reordering can mix two orderings; many records per change |
| Hard delete plus a tombstone table | Smaller tables | Extra mechanism; soft delete is already decided in ADR-0004 |

## Consequences

- Deviations from the local `drift` schema are handled in the sync layer: set items
  are (de)serialized to `setlists.items`; song metadata is re-derived from ChordPro.
- Every schema change is a new migration file and goes through PRs and tests like code.
- The server tests download the pinned PocketBase (`PB_VERSION`) once per machine
  (`tool/server/fetch-pocketbase.sh`); CI needs access to GitHub releases.
- `make backend` starts a local PocketBase with the same schema and hooks for app
  development.
- Hard-deleting records in the admin UI is not possible; cleaning up old soft-deleted
  records (purge) is a later decision.

## Decision log

- 2026-11-15: Proposed with the implementation of issue #13.
- 2026-11-15: Accepted by the owner.
- 2026-11-15: Extended by **ADR-0017** (accepted): `organizations` and `org_memberships`, `bands.organization`; `songs`, `attachments` and `invites` reference the organization instead of a band; users see the people of their organizations. Migration `1794900000_organizations.js`.
- 2026-11-15: Invitations (issue #16): `org_memberships.invite` (link a person joined with); organization admins may revoke links (`invites.revoked` only); links are created and redeemed through routes in `pb_hooks/invites.pb.js`. Migration `1795000000_invitations.js`.
- 2026-11-15: Personal adjustments (**ADR-0020**, issue #82): collection `overlays` (`user`, `song`, `data` JSON with the fields of layer 3, sync fields; unique per user and song; record ID derived from user and song, so all devices of a person use the same record). Private: only the user may list, create and change their overlays, and only for songs of their organizations; `user` and `song` cannot be changed. Deleting a song soft-deletes its overlays (`pb_hooks/songs.pb.js`). Migration `1795100000_overlays.js`.
- 2026-11-17: Registration mode (**ADR-0024**, issue #213): `invites.founder_name` and `invites.used_by` for founder invitations (no organization), rate limits enabled. Migration `1795200000_registration.js`.
- 2026-11-17: Finer-grained roles (**ADR-0023**, issue #215): `org_memberships.role` gains `librarian`, `memberships.role` gains `planner`; `songs.created_by` (set by `pb_hooks/songs.pb.js`); `invites.band`; `bands.members_can_edit_songs` removed after its members became librarians. Rules: sets for band leaders, set planners and organization admins; songs and attachments created by librarians, organization admins and band leaders, edited by librarians and organization admins or by the leader who created the song while they are its last editor, deleted by librarians and organization admins; invitations listed and revoked by organization admins and the leaders of their band. Migration `1795300000_roles.js`.

## Open points

- Purging soft-deleted records after a retention period (all devices must have synced).
- Version history for songs (ADR-0004 open point) could reuse the revision counter.
- Rate limiting for sign-up and auth endpoints (PocketBase settings).
- Account deletion: deleting a user cascades to their memberships as a hard delete
  (other devices do not learn about it through sync, and a band could lose its last
  admin). Decide on a deletion flow before the app offers it.
