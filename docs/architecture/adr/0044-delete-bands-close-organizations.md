# ADR-0044: Deleting bands and closing organizations

- **Status:** Proposed
- **Date:** 2026-11-20

## Context

Bands and organizations (ADR-0017) cannot be deleted.

- **No feature:** the app offers neither action, and the permission matrix of ADR-0023 does not grant it.
- **Server gap, now closed:** until #627 the update rules still let band leaders soft-delete their band and organization admins their organization, with a direct API call. Since #627 the server refuses changes of `deleted` on both (ADR-0015). The owner rule of #632 requires every permission to be enforced and tested on the server (AGENTS.md "Permissions on the server").

Two needs remain:

- **A band ends** (it breaks up, or a school year's ensemble is over). Its sets clutter the organization, and its members still see it.
- **An organization ends.** It cannot even be abandoned today: the last admin cannot leave (`keepLastAdmin`, ADR-0017).

Constraints:

- **Offline-first and sync:** devices learn about deletions only through soft deletes and delta sync (ADR-0001, ADR-0004). A hard delete leaves other devices with stale data, so `sync.pb.js` refuses it.
- **Trash:** ADR-0043 (proposed, #622/#623) introduces a 30-day trash with `deleted_at`, `purged`, a daily purge and tombstones for songs, sets and attachments.
- **Private data:** personal adjustments and annotations are private (ADR-0020, ADR-0032).
- **Invite-only servers** create organizations only through founder invitations (ADR-0024).
- **Server backups** are kept for 14 days (ADR-0014, `KEEP_DAYS`).

The owner decided the open questions one by one in #628 (bands) and #629 (organizations); this ADR records them.

## Decision

### 1. Who

| Action | Org admin | Librarian | Band leader | Set planner | Member |
|---|:-:|:-:|:-:|:-:|:-:|
| Delete a band, restore it from the trash | ✓ | – | – | – | – |
| Close an organization, restore it from the trash | ✓ | – | – | – | – |

- **Bands:** deleting a band matches "Create bands" in ADR-0023. A band leader who wants their band removed asks an organization admin. The last band of an organization may be deleted; the organization and its library stay.
- **Organizations:** any organization admin may close the organization alone. Abuse can be undone, because the other admins see the closed organization in the trash and can restore it.

### 2. Interface: the PocketBase standard path

Both actions use the records API of PocketBase, so the REST interface stays the same as for every other record.

- **Delete:**
  - `DELETE /api/collections/bands/records/{id}` and `DELETE /api/collections/organizations/records/{id}` answer **204**.
  - `deleteRule` is "active organization admin" of the band's organization or of the organization.
  - A hook (`onRecordDeleteRequest`) turns the call into a **soft delete plus the cascade** of section 3, in one transaction, instead of a hard delete. The same hook also applies to a superuser deleting the record in the admin UI.
  - Every other synced collection keeps refusing hard deletes (`sync.pb.js`).
- **Restore:**
  - `PATCH` of the same record with `{"deleted": false}` and nothing else, allowed only for active organization admins.
  - A hook restores the cascade.
  - `deleted` stays locked otherwise. In particular, `PATCH {"deleted": true}` is still refused, so deleting always goes through `DELETE` and its cascade (#627).
- **Fields:** like the trash of ADR-0043, bands and organizations get `deleted_at` (set by the server) and `purged`.
- **App:** it calls `collection('bands').delete(id)` and `collection('organizations').delete(id)`.

### 3. What goes with it

Everything the deletion soft-deletes gets the deletion's `deleted_at`. Restoring brings back exactly the records with that time; records deleted earlier stay deleted (the pattern of ADR-0015 and ADR-0043).

**Deleting a band** soft-deletes:

- its **sets**, with their items kept (ADR-0043);
- its **band arrangements** (ADR-0025);
- its **band memberships**.

Its **open invitations** are revoked; they stay revoked after a restore, because invitations are short-lived and new ones can be created.

Songs, attachments, personal adjustments and annotations stay, because they belong to the organization's library (ADR-0017).

**Closing an organization** soft-deletes:

- **every band**, with the band cascade above;
- **every song and attachment** of its library. The existing song hook removes everyone's personal adjustments, arrangements and annotations for those songs (ADR-0015).

Its **invitations** are revoked.

**Organization memberships stay active** during the 30 days, so the admins keep seeing the closed organization in their trash and can restore it. Members' devices hide it at once (section 5).

**Writes into a deleted band or a closed organization are refused.** The create and update rules of sets, arrangements, band memberships, songs, attachments, personal adjustments, annotations and invitations also require that the band, or the band's or song's organization, is not deleted. Reads stay as they are; devices hide the data themselves.

### 4. Trash and purge

- **Bands:**
  - A deleted band appears for organization admins in the organization's trash, with the deletion date and the days left.
  - It can be restored for **30 days**.
  - After that the daily purge of ADR-0043 marks it `purged` together with its sets and arrangements, and keeps a tombstone. Its memberships are hard-deleted.
- **Organizations:**
  - A closed organization appears for its admins in the list of organizations, as "closed, n days left", with "Restore".
  - After **30 days** the purge **deletes everything for good**:
    - all records of the organization: bands, sets, arrangements, songs with everyone's personal adjustments and annotations, attachments, memberships with names and roles, and invitations;
    - the attachment files.
  - Only a **tombstone of the organization without its name** stays (`purged`, name cleared), so devices that were offline for a long time still learn about the closing.
  - User accounts stay; a person may belong to other organizations.
- **Server backups:** the operator documentation states that the data is also gone from the server backups after 30 + 14 days (`KEEP_DAYS`, ADR-0014).

### 5. Devices

- **When the deletion arrives:** devices learn about a deleted band or a closed organization through delta sync. They remove its local data, including downloaded attachment files for an organization.
- **Live mode:** while it is active, applying the deletion waits until live mode ends, like other deferred syncs.
- **Queued offline changes:** the server refuses changes to a deleted band or a closed organization that were made offline and are still waiting. The app drops them and says once "The band was deleted" or "The organization was closed".
- **Closed organizations:** members get a one-time message in the app on their next sync: "Organization X was closed by Y". No email is sent.
- **Restoring:** the restored records come back through delta sync like any change.

### 6. Confirmation in the app

- **Band:**
  - A dialog shows a summary of what goes, e.g. "12 sets, 5 members, 2 open invitations", and that the band stays in the trash for 30 days.
  - Deleting requires **typing the band name**. For the last band, the dialog says so.
  - After deleting, a short "Undo" is offered.
  - No backup export is offered; the dialog points to the normal backup export of ADR-0043.
- **Organization:**
  - The same kind of dialog, with a summary of bands, songs and members, the 30 days, and typing the organization name.
  - In addition, it offers an optional **"Back up first"** that runs the organization's backup export (ADR-0043). The export is not required.

### 7. Invite-only servers

Closing an organization gives no right to found a new one. On an `invite_only` server (ADR-0024) a new organization still needs a founder invitation from the operator. Within the 30 days the closed organization can be restored instead.

### 8. Tests

As required by AGENTS.md "Permissions on the server" (#632), server tests call the API directly:

- **Refused callers:** band leaders, set planners, members, librarians and admins of another organization, for `DELETE`, `PATCH {"deleted": true}` and restore. They get rows in `server/test/permissions_test.dart`.
- **Cascade:** what goes with a band or an organization, and what a restore brings back.
- **Writes into deleted parents:** refused.
- **Purge:** the purge, the tombstones and the removed files.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Delete with a 30-day grace period through `DELETE` on the records API** (chosen) | Same REST path as every record; one pattern for bands and organizations; mistakes and abuse can be undone; data really goes away afterwards | Hooks must turn `DELETE` into a soft delete with a cascade; write rules must check the parent's `deleted` |
| Own routes (`DELETE /api/setding/bands/{id}`, `POST …/restore`) | Clearly separate from the records API | A second path for the same resource; `restore` as an action endpoint (owner: keep REST conventions) |
| `PATCH {"deleted": true}` plus a hook, as for songs | Existing song pattern | Re-opens what #627 locked; easy to send by mistake; the cascade hides behind a field change |
| Band leaders may delete their band | More autonomy for bands | A leader could remove the sets of all members; creating bands is an org admin right (ADR-0023) |
| Closing an organization as a read-only archive | Nothing is lost; can be reopened any time | Data stays on the server forever; every write rule needs an archive state; a second state next to the trash |
| Archive first, then delete | Most flexible | Two states and two flows for a rare action |
| All admins must confirm closing | Protects against one admin acting alone | Needs a request and notification flow; can be blocked; the 30-day restore already undoes abuse |
| Email to all members when an organization is closed | Reaches people who rarely open the app | Needs SMTP and new mail templates; the in-app message reaches everyone who still uses the organization |
| Required backup export before closing | No data can be lost by mistake | Not always possible (web, offline); the trash and the optional export are enough |

## Consequences

- **Easier:** organizations can end, and the last admin is no longer stuck. Bands that are over no longer clutter the organization. Both actions can be undone for 30 days and leave no data behind afterwards.
- **Harder:**
  - Every write rule that refers to a band or an organization must also check `deleted`.
  - The `DELETE` hooks run large cascades in one transaction; closing a big organization touches many records.
  - Devices need the deferral in live mode and must clean up their local data, including files.
- **Changes to other ADRs on acceptance:**
  - ADR-0023: two rows in the permission matrix.
  - ADR-0015: rules, hooks, `deleted_at` and `purged` on bands and organizations, and the write rules.
  - ADR-0043: the trash and purge cover bands and organizations, and the hard purge for organizations.
  - ADR-0017: an organization can end.
  - ADR-0014: operator documentation on data retention.
- **Dependencies:**
  - The trash of ADR-0043 (#623) comes first.
  - Then band deletion (#628), then closing organizations (#629).
  - Server migrations and client schema changes are minor versions (ADR-0028): old clients ignore the new fields, but they show deleted bands until they update. The server refuses their writes into deleted bands.

## Decision log

- 2026-11-20: Proposed (#634). The owner decided the open questions of #628 and #629 one by one: org admins only; the REST standard path `DELETE /api/collections/{bands|organizations}/records/{id}` with restore by `PATCH {"deleted": false}`; the cascade; 30 days in the trash; live-mode deferral and refused offline writes; confirmation by typing the name; the last band may be deleted; closing is deletion with a grace period by any org admin alone; an in-app message; an optional backup before closing; a hard purge after 30 days with a tombstone without a name; no new founding right on invite-only servers.

## Open points

- **Members during the grace period:** members of a closed organization can still read its data through the API, although their devices hide it. Restrict the read rules to organization admins while it is closed?
- **Size limits:** closing very large organizations in one transaction. Measure it, and split the cascade if needed.
- **Admin UI:** whether a superuser deleting a band or an organization should skip the trash (an operator purge) or follow it like everyone else.
