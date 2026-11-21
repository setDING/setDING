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
| `setlists` | `band`, `name`, `gig_date`, `venue`, `origin` (set an imported set was made from, ADR-0043), `items` (JSON array) | ✓ |
| `invites` | `band`, `token_hash` (hidden), `token_enc` (hidden, encrypted token, ADR-0005), `expires`, `revoked`, `created_by` | – |

Other song metadata (artist, key, tempo, tags, sort fields) is derived from the
ChordPro text in the client (ADR-0003) and not stored on the server.
Personal overlays (ADR-0006, ADR-0020) are stored in `overlays` (see the
decision log).

### Sync fields

Every synced record has a client-generated **UUID `id`** (the server generates a
UUID v4 only if none is sent), **`revision`**, **`updated_by`**, **`deleted`** and
the autodate fields `created`/`updated`.

- **One server-wide revision counter** (table `setding_sync`). A hook increments
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
| `users` | self and current bandmates | sign-up open | self (deleting: with the password, ADR-0052) |

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
- 2026-11-17: Band arrangements (**ADR-0025**, issue #221): collection `arrangements` (`band`, `song`, `transpose`, `sequence`, `tempo`, sync fields; unique per band and song; the song must belong to the band's organization). Band members and organization admins read them; band leaders, set planners and organization admins create and change them; `band` and `song` cannot be changed. Deleting a song soft-deletes its arrangements (`pb_hooks/songs.pb.js`). Migration `1795400000_arrangements.js`.
- 2026-11-17: Restoring a soft-deleted song (`deleted` back to false, undo in the app, issue #267, ADR-0004) restores the personal adjustments and arrangements that deleting it soft-deleted: those of the song deleted with a revision above the song's deletion revision (`pb_hooks/songs.pb.js`). Ones deleted before the song stay deleted.
- 2026-11-17: Personal settings (**ADR-0027**, issue #338): collection `user_settings` (`user` unique, `data` JSON, sync fields; record ID a UUID v5 of the user). Private: only the user may list, view, create and update it; `user` cannot be changed; never hard-deleted. An update merges the sent keys of `data` into the stored ones (`pb_hooks/user_settings.pb.js`), so devices send only the keys they changed. Migration `1795500000_user_settings.js`.
- 2026-11-20: Bands and organizations cannot be deleted through the API (issue #627): their update rules refuse changes of `deleted`. The app never offered it and ADR-0023's permission matrix does not grant it, but band leaders could soft-delete their band and organization admins their organization with a direct API call (found in a permission review). Deleting a band and closing an organization will be features of their own with their rules decided then. Migration `1796100000_lock_band_org_deletion.js`.
- 2026-11-20: Deleting bands (**ADR-0044**, issue #628): `bands.deleted_at` and `bands.purged` (server only); `deleteRule` = active organization admin, and `DELETE` is turned into a soft delete by `pb_hooks/bands.pb.js` (also for superusers); `onRecordUpdateExecute` soft-deletes the band's sets (with its `deleted_at`), arrangements and memberships and revokes its invitations, and restores them on `PATCH {"deleted": false}` (organization admins, not purged; arrangements and memberships by revision, people who left the organization stay out). A deleted band takes no other update; sets, arrangements and memberships require `band.deleted = false` for create and update. Migration `1796200000_delete_bands.js`.
- 2026-11-20: Closing organizations (**ADR-0044**, issue #629): `organizations.deleted_at` and `organizations.purged` (server only); `deleteRule` = active organization admin, and `DELETE` is turned into a soft delete by `pb_hooks/organizations.pb.js` (also for superusers); its `onRecordUpdateExecute` soft-deletes the bands (with their own cascade), songs (with theirs) and attachments with the organization's `deleted_at` and revokes its invitations, and restores them on `PATCH {"deleted": false}` (its admins, not purged); organization memberships stay. While it is closed, the list and view rules of bands, sets, arrangements, band memberships, songs, attachments, invitations and other people's organization memberships admit only its admins, and songs, attachments, bands, organization memberships, personal adjustments, annotations and invitations take no writes. Migration `1796300000_close_organizations.js`.
- 2026-11-20: Song play history (**ADR-0046**, issue #660): set items may carry `played` (key, tempo, sequence frozen on the gig day). An update keeps the stored `played` of an item sent again with the same ID but without the field (`pb_hooks/setlists.pb.js`), so apps before 0.17.0 do not erase it. No schema change.
- 2026-11-21: Set markers (**ADR-0047**, issue #722): marker items carry `icon` (a catalogue key); `type` stays `pause` or `text` for older apps. The hook `pb_hooks/setlists.pb.js` keeps the stored `icon` of an item sent again with the same ID but without the field, as for `played`. No schema change.
- 2026-11-21: Set archive (**ADR-0043** §1b, issue #707): `setlists.origin` (text, optional) holds the ID of the set an imported set was made from, so importing it again can offer to replace it. Written like the other fields; an update without it keeps it.
- 2026-11-20: Band repertoire (**ADR-0046**, issue #661): `bands.stale_after_months` (number, 0–36, 0 = 6 months). The update rule also lets set planners in; `pb_hooks/bands.pb.js` refuses any other field in their request. Migration `1796400000_band_stale_after.js`.
- 2026-11-20: Plays across the bands (**ADR-0046**, issue #662): custom route `GET /api/setding/plays/{organization}` (`pb_hooks/plays.pb.js`, `lib/plays.js`) sums up, per song and band, the past non-deleted sets of the organization's non-deleted bands (count, last date, last frozen key); only for active members of the organization, never set names or contents. No schema change.

## Open points

- Purging soft-deleted records after a retention period (all devices must have synced).
- Version history for songs (ADR-0004 open point) could reuse the revision counter.
- Rate limiting for sign-up and auth endpoints (PocketBase settings).
- Account deletion (ADR-0052): users delete only their own record, with their
  password in the body of the `DELETE`; `pb_hooks/users.pb.js` refuses the only
  admin of an organization that is not closed (also for superusers), soft-deletes
  the memberships and clears every non-cascading reference to the user with a
  direct update (memberships become tombstones without a person; `updated_by`,
  `created_by`, `used_by` without a new revision). Personal adjustments,
  annotations and personal settings cascade.
- 2026-11-21: Users can no longer delete their own account through the API (issue #778): PocketBase's default `deleteRule` let them, which hard-deleted their memberships and could leave an organization without an admin. `users.deleteRule = null`; superusers still can. Migration `1796600000_users_no_self_delete.js`.
- 2026-11-21: Deleting the own account (**ADR-0052**, issue #780): `users.deleteRule = "id = @request.auth.id"` again, `memberships.user` and `org_memberships.user` no longer cascade and are optional (tombstones without a person), rate limit `users:delete` (5 per minute); `pb_hooks/users.pb.js` with `lib/accounts.js` checks the password (`invalid_password`), refuses the only admin of an organization that is not closed (`organizations`/`last_admin`, the names in the message), soft-deletes the memberships, revokes the user's open invitations and clears the references in the delete's transaction. `keepLastAdmin` no longer applies in a closed organization. Migration `1796700000_account_deletion.js`.
