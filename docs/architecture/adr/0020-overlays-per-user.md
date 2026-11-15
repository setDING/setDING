# ADR-0020: Personal adjustments per user, synced with the account

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

ADR-0006 defines personal adjustments (layer 3: transposition, capo, font
size, notes, Nashville, live view) as an overlay that never changes the shared
song, and says they are "synced with the user account so they are available
on a new device (phase 2)". The domain model in the architecture README gives
`PERSONAL_OVERLAY` a `user_id`.

The client does not do this yet. The local table `personal_overlays` has the
song ID as its only key (database schema 7):

- **Shared devices:** a tablet of a music school or church is used by several
  people one after another (sign out, sign in, ADR-0016 keeps the data on the
  device). The next person sees the previous person's key, capo, font size
  and notes.
- **No sync possible:** without an owner, an overlay cannot be pushed to the
  server or pulled on a new device (phase 2, roadmap).
- **Web client:** signing out deletes the browser's database (ADR-0018), so
  the problem does not arise there, but the web client cannot show a
  member's adjustments either.

The code review of 2026-11-15 (finding B7) raised this. Deciding it now keeps
the next schema change (and the phase 2 sync) from having to migrate data
whose owner is unknown.

## Decision

1. **Each overlay belongs to a person.** The local key becomes
   (`owner_id`, `song_id`). `owner_id` is the server user ID of the signed-in
   user for songs of an organization. Songs of the local library ("On this
   device", ADR-0017) always use the fixed value `local`, also while someone
   is signed in: the local library belongs to the device, not to a person,
   and is never synced.
2. **Reads and writes use the current owner.** Signed in: the user's ID;
   signed out: `local`. Other people's overlays stay on the device (like songs
   and sets on sign-out, ADR-0016) but are never shown or changed. Without an
   overlay of the current owner, the defaults apply (as today).
3. **Upgrade of existing overlays (schema 8):** existing rows get the owner
   `local`. The **first user who signs in after the upgrade** takes over the
   `local` overlays of songs in their organizations, once per device (a flag
   in the device settings). Overlays of local-library songs stay `local`.
   Until now each device was used by one person in practice, so this keeps
   their adjustments.
4. **Sync with the account (phase 2):** a server collection `overlays`
   (`user`, `song`, the fields of layer 3, `revision`, `deleted`; unique per
   user and song). Access rules: only the user themself may list, create and
   change their overlays, and only for songs of their organizations
   (ADR-0015). Overlays are private: organization admins do not see other
   people's adjustments or notes. A removed overlay is soft-deleted
   (`deleted`) like other synced records, so the delta pull carries the
   removal to the user's other devices. Overlays use the outbox and delta
   pull like other records
   (ADR-0004), with the user as the pull scope, and **last writer wins**: an
   overlay is personal, so there is no conflict dialog. `local` overlays are
   never synced.
5. **Related behaviour:**
   - Deleting a song deletes its overlays (soft delete on the server).
   - "Copy to band" (ADR-0017) copies the current owner's overlay only.
   - The live view (`live_view`, an attachment ID) stays part of the overlay;
     if the attachment is gone on another device, it falls back to ChordPro
     (as today when an attachment is deleted).
   - Layer 4 (device settings) stays local per device and is not affected.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Per user, synced** (proposed) | Correct on shared devices; available on a new device; matches ADR-0006 and the domain model | Schema change and one-time adoption of existing overlays; new server collection |
| Keep per device | No work | Wrong on shared devices; cannot be synced, contradicts ADR-0006 |
| Per user and device (not synced) | Correct on shared devices | No adjustments on a new device, contradicts ADR-0006 |
| Delete overlays on sign-out | Simple, no owner needed | A member loses their adjustments on every sign-out; on stage no sign-out happens anyway, but before and after it does |
| Sync overlays per device, last device wins | No owner per row | Wrong as soon as two people use one device |

## Consequences

- Local schema 8: `personal_overlays` gets `owner_id` and a composite primary
  key; the repository reads and writes the overlay of the current owner, so
  `SongRepository` needs the owner (from the auth state).
- A flag in the device settings records the one-time adoption of `local`
  overlays.
- Phase 2 adds the `overlays` collection (migration, access rules, hooks for
  revision and `updated_by`, ADR-0015), an outbox collection and a pull scope
  per user in the sync engine, and tests against a real PocketBase.
- The live mode and the song screen are unchanged apart from where the
  overlay comes from.
- Notes anchored to a line or section (ADR-0006) remain a separate change; the
  owner applies to them the same way.

## Decision log

- 2026-11-15: Proposed after the code review (finding B7).
- 2026-11-15: Accepted by the owner as proposed. Resolved open points: the
  first user who signs in after the upgrade takes over the existing overlays
  of organization songs (once per device); overlays are private (no access
  for organization admins); removals are soft deletes, which the delta sync
  needs. Clarified: songs of the local library always use the owner `local`.
- 2026-11-15: Local part implemented (schema 8, #81); sync with the account
  follows in #82.
- 2026-11-15: Sync implemented (#82): server collection `overlays` (ADR-0015
  decision log); local schema 9 adds `revision` to `personal_overlays`; the
  server record ID is a UUID v5 of user and song, so a person's devices never
  create two records; delta pull with the user as scope; changes of another
  person on a shared device stay in the outbox until that person syncs.

## Open points

- None.
