# ADR-0064: People without an account in a set's lineup

- **Status:** Proposed
- **Date:** 2026-11-26

## Context

A set's lineup (ADR-0061) holds the people who play it, and only people of the
band's organization with a setDING account can be in it. Bands also play with
people who do not use the app: a guest drummer, a horn section hired for one
gig, a sound engineer, a choir leader, a substitute who prints the set list on
paper. Today the lineup cannot name them, so a set does not say who really
took part, and the printable set list and *Notify lineup* leave them out.

The owner's idea (2026-11-26): also add people from outside the app to a
set's lineup, so one can see who played a set.

Forces:

- **Offline-first** (ADR-0001): the lineup is chosen in the set editor, also
  without a network.
- **Permissions on the server** (owner rule #632, ADR-0023): anyone can call
  the API directly; who may create such people and who sees their mail
  addresses is enforced by the server.
- **Organizations** (ADR-0017): people belong to an organization; nobody from
  outside it is offered in the lineup. A person without an account is not a
  member and gets no access to anything.
- **Personal data of people who never agreed to anything**: setDING stores
  data about them without an account of their own, so it keeps as little as
  possible.
- **Names** (ADR-0062): first name, last name and nickname, shown as each
  viewer chose (*Show names as*).
- **Older apps** keep working: they save sets without knowing the new field.

## Decision

### 1. Contacts of the organization

A person without an account is a **contact** of the organization (owner
decision): a record in a new server collection `contacts`, reusable in every
set of every band of the organization, not free text in one set and not per
band.

- Fields: `organization`, `first_name` (required), `last_name`, `nickname`,
  `email` (optional, decision 4), `linked_user` (decision 5), `revision`,
  `deleted`, `deleted_at`, `created_by`, `updated_by`, like the other synced
  records (ADR-0015).
- The name follows ADR-0062: shown and sorted as the viewer chose; only the
  first name is required, since an organizer often knows no more of a guest.
- A contact has no login, no device and no rights. It is never a substitute
  (ADR-0061): it sees nothing because it has nothing to sign in with.
- Contacts are synced to every member of the organization like the
  organization's people (delta by revision), so the lineup's names show
  offline.

### 2. Contacts in the lineup

- Collection `setlists` gets `lineup_contacts` (relation to `contacts`,
  several, at most 200), next to `lineup` (users). Both together are the
  lineup when `lineup_custom` is true; with `lineup_custom = false` the lineup
  is the whole band, as before, and `lineup_contacts` is ignored.
- A separate field keeps `lineup` a relation to `users`, so older apps and the
  routes of ADR-0061 keep their meaning; older apps do not send the field and
  PocketBase keeps its stored value.
- The server refuses contacts of another organization or deleted contacts when
  they are added (hook on create and update of `setlists`, like the check of
  ADR-0061 that people belong to the organization); a contact already in a set
  stays when it is deleted later, so old sets keep the name.

### 3. Choosing and creating them

- The lineup dialog's *Add people* picker lists the organization's people and
  its contacts, contacts marked *No account* (*Ohne Konto*). The picker's
  search matches every part of the name (ADR-0062).
- *New person without account* in the picker creates a contact (first name,
  optional last name, nickname, mail address) and adds it to the set at once,
  also offline; the contact is pushed before the set at the next sync.
- The set view, the set card and the printable set list (ADR-0061 decisions
  2 and 7) show contacts like people of the lineup, marked *No account* in
  the app (not on the printed list).
- The organization screen gets a section *People without account* that lists
  the contacts for set editors and organization admins, with *Edit*, *Link to
  account* and, for organization admins, *Delete*.

### 4. Mail address

- The mail address is optional (owner decision). It is visible **only to
  people who may edit sets in some band of the organization** (band leaders,
  set planners, organization admins): the server removes `email` from the
  records it sends to everybody else (enrich hook), like users' addresses are
  hidden through `emailVisibility`.
- *Notify lineup* (ADR-0061 decision 6) fills in the contacts' addresses
  together with the people's: the route `GET /api/setding/lineup/{set}/emails`
  returns both, only to whoever may edit that set.
- A substitute (ADR-0061 decision 4) gets the **names** of the lineup's
  contacts from `GET /api/setding/lineup`, never their addresses.

### 5. Linking a contact to an account

When the person later joins setDING, the contact is **linked to their account
by hand** (owner decision), never matched automatically by mail address:

- *Link to account* chooses a person of the organization. The server route
  `POST /api/setding/contacts/{id}/link` with the user's ID replaces the
  contact with that user in the lineup of every set of the organization (each
  changed set gets a new revision), sets `linked_user` and marks the contact
  deleted, in one transaction.
- Allowed for whoever may create contacts (decision 6). The route changes sets
  of bands the caller cannot edit, but only by swapping the same person for
  their account; it refuses a user who is not a member of the organization.
- From then on the person is a substitute or band member in those sets like
  anybody added by name (ADR-0061), so they see their past gigs as a
  substitute.

### 6. Permissions

| Action | Org admin | Librarian | Band leader | Set planner | Member | Substitute |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| See the names of the organization's contacts | ✓ | ✓ | ✓ | ✓ | ✓ | lineup's only |
| Create and edit contacts, see their mail addresses, link them to an account | ✓ | – | ✓ | ✓ | – | – |
| Add contacts to a set's lineup | ✓ all bands | – | ✓ | ✓ | – | – |
| Delete contacts | ✓ | – | – | – | – | – |

*Band leader* and *Set planner* mean that role in any band of the
organization: contacts belong to the organization, not to one band. The rows
go into ADR-0023's permission matrix and are tested through the API as the
refused roles.

### 7. Deleting a contact

Only organization admins delete contacts (owner decision), since a contact can
be in the lineup of old sets:

- Deleting is a soft delete: the contact leaves the picker and the
  organization screen, its **mail address is cleared at once**, and sets that
  name it keep showing its name.
- Closing the organization (ADR-0044) purges its contacts with everything
  else. A contact has no account of its own, so ADR-0052 (deleting an account)
  does not apply.

### 8. What stays

- Set archives (ADR-0043) carry no lineup, so no contacts either.
- Gig counting (overview *Next set*, *You are planned*) concerns signed-in
  people only; contacts do not change it.
- The lineup stays people only, without roles (ADR-0061 open point).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Contacts of the organization** (chosen) | Reused in every set and band; one spelling per person; a place for a mail address; can be linked to an account later | A new collection, its sync, server rules and a link route |
| Free-text names in the set (JSON next to `lineup`) | Little work, no new collection | No reuse, the same person spelled differently in every set, no mail address, nothing to link when they join |
| Contacts per band | Narrower list | A guest playing with two bands of the organization exists twice; the organization's people pool is organization-wide already (ADR-0017, ADR-0061) |
| Invite them as members without them signing in (placeholder accounts) | One kind of person | Accounts nobody can sign in to, invitations and mail addresses that must be unique; mixes people with rights and people without |
| Contacts created by organization admins only | Tidy list | Too slow when a guest steps in shortly before a gig |
| Contacts created by every member | Open | Duplicates and data about outsiders from people without any planning role |
| Link automatically by mail address on sign-up | Comfortable | Wrong matches with shared or mistyped addresses; the address is optional anyway |
| No mail address | Less personal data | *Notify lineup* cannot reach them |

## Consequences

- A set says who really played it, also people without setDING, in the app and
  on the printed set list.
- Set editors keep a reusable list of guests per organization and reach them
  through *Notify lineup*.
- The server gets the `contacts` collection with rules, an enrich hook hiding
  mail addresses, the check of `lineup_contacts`, the link route and an
  extended lineup mail route; all tested through the API, and the permission
  matrix test covers the new rows.
- The client gets a new synced table (a schema step), the contacts in the
  lineup dialog, the set view, the set card and the PDF, and a section on the
  organization screen.
- setDING stores names and optional mail addresses of people who have no
  account; the privacy notice of the website says so.
- New UI texts in all six languages; the website page *Lineup and substitutes*
  gets a section with screenshots of the picker and the new contact
  (AGENTS.md).

## Decision log

- 2026-11-26: Proposed after a discussion with the owner (#1095). Owner
  decisions: contacts of the organization (not free text, not per band);
  created and edited by whoever may edit sets, deleted by organization admins
  only; an optional mail address visible to set editors and used by *Notify
  lineup*; linking to an account by hand when the person joins, no automatic
  matching.

## Open points

- Purging a deleted contact's name after a while (today the name stays in old
  sets for good).
- Merging two contacts that turn out to be the same person.
- Roles per person in the lineup (ADR-0061), for contacts as well.
