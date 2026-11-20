# ADR-0023: Finer-grained roles for organizations and bands

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

ADR-0005 and ADR-0017 define two roles on each level: **admin** and **member** of
an organization, and **admin** and **member** of a band. Since songs belong to the
organization (ADR-0017), this model has gaps:

- **Admins of any band** of an organization may edit every song of the shared
  library. The leader of band A can change the key or structure of a song that
  band B plays tonight.
- The band setting **`members_can_edit_songs`** lets one band grant its members write
  access to the **whole library of the organization**: a band-level switch over
  organization data (also listed as an open point in ADR-0017).
- Planning sets and managing people come only as a package (band admin). A band
  cannot let its musical director plan sets without also letting them manage the
  band's people and settings.
- Who looks after the song library (a librarian) has no role of its own; it is
  either an organization admin or a side effect of a band role or setting.

The owner wants organization admins to keep **all** rights (they manage the
organization and may step in for any band) and finer-grained roles below them.

## Decision

### Principles

1. **Fixed roles, no configurable permission matrix.** Each role stands for a task
   people have in a band or organization. The PocketBase rules stay readable and
   testable, and the app can explain in one word what someone may do.
2. **Two levels.** The **organization** owns people, bands and the song library.
   The **band** owns its sets (and, with a follow-up ADR, its arrangements).
3. **Roles are ordered on each level**; a higher role includes everything of the
   lower ones. So one role per organization membership and one per band membership
   is enough, as today.
4. **Organization admins may do everything** in every band of their organization.
5. **The server enforces, the client only shows** (unchanged from ADR-0005).

### Organization roles

`org_memberships.role`: `admin` > `librarian` > `member`.

| Role | UI (en / de-CH) | Typical person | Responsibilities |
|---|---|---|---|
| `admin` | Admin / Admin | Head of the music school or church, founder of a single band | Everything: people and their roles, bands, invitations, the song library including deletion, sets and settings of all bands |
| `librarian` *(new)* | Librarian / Bibliothek | Keeper of the song library | Create, import, edit and delete (soft delete) songs and attachments of the organization |
| `member` | Member / Mitglied | Everybody else | See the organization's people and song library; personal overlays (ADR-0006, ADR-0020) |

The **`librarian`** role replaces the band setting `members_can_edit_songs`.

### Band roles

`memberships.role`: `admin` > `planner` > `member`.

| Role | UI (en / de-CH) | Typical person | Responsibilities |
|---|---|---|---|
| `admin` | Leader / Leitung | Band leader | Everything of the band: sets, band settings, band members and their band roles, invitations into the band; create and import **new** songs into the organization's library and edit **their own** songs (see below) |
| `planner` *(new)* | Set planner / Setplanung | Musical director, deputy | Create, edit, reorder and delete the band's sets; no people or settings |
| `member` | Member / Mitglied | Musicians | See the band's sets, play live, personal overlays |

The stored value of the band leader stays `admin`, so existing memberships, sync
and older clients keep working; only the UI calls it *Leader* / *Leitung*.

### Songs: creating versus editing

- **Creating and importing new songs** (including "copy to band", issue #15):
  organization admins, librarians and band leaders. A leader needs new songs to
  build sets.
- **Editing existing songs and attachments:** organization admins and librarians.
  A leader who should also maintain songs gets the `librarian` role in the
  organization.
- **Own songs:** a band leader may edit a song (and its attachments) that they
  created or imported, as long as nobody else has changed it since
  (`created_by` and `updated_by` are the leader). This covers fixing an import
  right away; once a librarian or someone else edits the song, it is maintained
  by the library. A leader who is no longer a leader of a band of the
  organization loses this right.
- **Deleting songs and attachments** (soft delete): organization admins and
  librarians.

Band-specific changes (key, capo, sequence, notes for one band) will not need
song edits: a follow-up ADR proposes a **band arrangement**, a layer between the
shared song and the personal overlay (song → band arrangement → personal overlay),
editable by band leaders and set planners.

### Invitations

Invitations (ADR-0005) keep adding people to the **organization** with the role
`member`. In addition, a **band leader** may create invitations that add the person
to the organization **and to the leader's band** (band role `member`), so a leader
can bring a new musician in without an organization admin. Organization admins can
still invite without a band. A leader may only see and revoke their own band's
invitations. On an invite-only server (ADR-0024) these links are also the ticket
for creating an account, like every invitation.

### Permission matrix

| Action | Org admin | Librarian | Band leader | Set planner | Member |
|---|:-:|:-:|:-:|:-:|:-:|
| See the organization's people and library | ✓ | ✓ | ✓ | ✓ | ✓ |
| See a band's sets, live mode, personal overlays | ✓ all bands | own bands | ✓ | ✓ | ✓ |
| Create, edit, reorder, delete sets | ✓ all bands | – | ✓ | ✓ | – |
| Band arrangement (follow-up ADR) | ✓ all bands | – | ✓ | ✓ | – |
| Create and import new songs | ✓ | ✓ | ✓ | – | – |
| Edit existing songs and attachments | ✓ | ✓ | own songs² | – | – |
| Delete songs and attachments | ✓ | ✓ | – | – | – |
| Band settings, band members, band roles | ✓ all bands | – | ✓ | – | – |
| When songs count as not played for a while (ADR-0046) | ✓ all bands | – | ✓ | ✓ | – |
| See how the other bands of the organization played a song (ADR-0046) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Library usage: songs no band played (ADR-0046) | ✓ | ✓ | – | – | – |
| Invite into the organization | ✓ | – | ✓ (into own band) | – | – |
| Create bands, organization roles | ✓ | – | – | – | – |
| Delete a band, restore it from the trash (ADR-0044) | ✓ | – | – | – | – |
| Close the organization, restore it from the trash (ADR-0044) | ✓ | – | – | – | – |
| Leave a band or organization | the person themselves | | | | |

² Songs the leader created or imported and nobody else has changed since.

A person who is a librarian of the organization and a member of a band sees the
sets of that band like any member; librarian rights concern the library only.

### Migration of existing data

- Band `admin` memberships stay `admin` (now shown as *Leader*).
- Members of a band with `members_can_edit_songs = true` become **`librarian`** of
  that band's organization (unless they are admins already), so nobody loses a
  right they were given explicitly.
- Band leaders lose the right to edit **existing** songs of others; they keep
  creating new ones and editing their own. Organization admins give them the
  `librarian` role where wanted.
- Songs get a `created_by` field; existing songs keep it empty (nobody counts as
  their creator), so only librarians and organization admins edit them.
- The field `bands.members_can_edit_songs` is removed after the migration.

### Server and client (ADR-0015)

- `org_memberships.role` gains `librarian`, `memberships.role` gains `planner`;
  only organization admins change organization roles, band leaders and
  organization admins change band roles (as today).
- Rules: `setlists` create/update for band `admin` or `planner` or organization
  admin; `songs` and `attachments` create for organization `admin`/`librarian` or
  an `admin` of any band of the organization, update for organization
  `admin`/`librarian` or for the creator while they are its last editor and an
  `admin` of a band of the organization (`created_by`, set by a hook); `invites` gain an optional `band`, created by its band
  leaders or the organization's admins.
- Client: `BandView` / `LibraryView` derive `canManageSets`, `canCreateSongs`,
  `canEditSongs`, `canDeleteSongs`, `canManageBand` from the new roles; role pickers
  on the organization and band screens; new UI texts in both ARB files (ADR-0008).
- Older clients still show the old buttons; the server rejects what they no longer
  may do, and the sync reports the rejection instead of dropping the change
  silently (ADR-0004).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Fixed, ordered roles per level** (chosen) | Easy to explain, one role per membership, readable rules | Less flexible than free permissions |
| Status quo (admin/member, `members_can_edit_songs`) | No work | Leaders edit songs of other bands; band setting governs organization data; no planner role |
| Configurable permission matrix per organization | Fits every band | Complex UI and rules, hard to test, hard to explain on stage |
| Librarian as a flag combinable with any role | Independent of the other roles | Not needed: admin includes librarian, so an ordered role is enough |
| Organization-wide switch "all members may edit songs" (ADR-0017 open point) | Simple | All-or-nothing; no named responsibility for the library |
| Band leaders keep editing existing songs | No lost rights | The cross-band problem stays |
| Organization admins manage sets only through a band role | Clear separation | Rejected by the owner: organization admins may do everything |
| Guest role for substitutes (one set only) | Covers substitutes from outside | Not needed: substitutes usually play in another band of the organization already and are added to the band as members (owner); the library is visible to the whole organization anyway; ADR-0005 excludes guests |

## Consequences

- Updates ADR-0005 (roles, `members_can_edit_songs`, invitations) and ADR-0017
  (permissions table, open point "organization-wide setting"); both get decision log
  entries when this ADR is accepted.
- A server migration and a client schema change are needed; the migration is
  one-way (restore a backup to go back), like ADR-0017.
- Fewer people can edit existing songs; the library gets a named responsibility.
- The band arrangement needs its own ADR before band leaders can adapt songs for
  their band without editing them.
- Set planners make a common band setup possible (leader organizes, musical
  director plans).

## Decision log

- 2026-11-17: Proposed with issue #207 after discussing permissions with the owner.
  Owner direction: organization admins keep all rights; finer-grained roles below
  them.
- 2026-11-17: Owner answers to the open points: band leaders may edit **their own
  songs** as long as nobody else changed them; **set planners** edit the band
  arrangement like leaders; **band leaders invite** into their own band; members
  who can edit songs today through `members_can_edit_songs` become **librarians**.
- 2026-11-17: Owner decision: **no guest role**. Substitutes are usually members of
  another band of the organization already; a band leader adds them to the band
  as members (and removes them afterwards if wanted).
- 2026-11-17: Accepted by the owner.
- 2026-11-17: Implemented (#215). Server: migration `1795300000_roles.js` (roles
  `librarian` and `planner`, `songs.created_by` set by a hook, `invites.band`, new
  rules, members of bands with `members_can_edit_songs` become librarians, the field
  is removed); band invitations in `lib/invites.js`. App: `OrgRole` next to
  `BandRole`, local schema 11 (`songs.created_by` / `updated_by`, written when the
  user creates or edits an organization song so the own-song rule also works
  offline; `bands.members_can_edit_songs` dropped), permissions in `BandView` /
  `LibraryView` (`canManageSets`, `canCreateSongs`, `canEditSong`, `canDeleteSongs`),
  role menus on the band and organization screens, invitations on the band screen.
  The band arrangement follows with its own ADR (#216).
- 2026-11-20: **ADR-0043** (accepted, #622): exporting an organization's backup archive: organization admins and librarians; restoring from the trash: whoever may delete the record (songs and attachments: organization admins and librarians; sets: band leaders and set planners, organization admins in all bands).
- 2026-11-20: **ADR-0044** (accepted): organization admins delete bands and close the organization (two new rows in the permission matrix); nobody else may, also not through the API (#627, #632).
- 2026-11-20: Matrix row for the band's threshold for songs not played for a
  while (ADR-0046, #661): set planners may change this field of the band and
  nothing else (update rule plus a hook on the request body).
- 2026-11-20: Matrix rows for the plays across the bands (ADR-0046, #662): every
  member of the organization sees, per song, which bands played it, when last,
  in which key and how often (never their sets); the library usage is for those
  who maintain the library.

## Open points

- Suggestion workflow (members propose song corrections, librarians accept); a
  separate decision.
