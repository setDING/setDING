# ADR-0064: People without an account in a set's lineup

- **Status:** Accepted
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
  the contacts for set editors and organization admins, with *Edit*, *Invite
  to setDING* (decision 5) and, for organization admins, *Delete*.

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

### 5. A personal invitation links the contact to an account

When the person should use setDING, the contact gets a **personal invitation**
(owner decision 2026-11-26); redeeming it links the contact to the new
account automatically. There is no linking by hand and no matching by mail
address.

- *Invite to setDING* on a contact creates an invitation bound to it
  (`invites.contact`). It works like the invitations of ADR-0005 (a link with
  a random token, valid for 7 days, revocable, shown again while valid,
  ADR-0024 lets it create an account on closed servers), but it can be used
  **once** and names the person it is for.
- **Sending it**: with a mail address, *Send by mail* opens a prepared mail to
  that address in the sender's mail app (a `mailto:` link, like *Notify
  lineup*; the server sends no mail, ADR-0024). Without one, or in person, the
  link is shared through the share menu or shown as a **QR code**, like every
  invitation.
- **Signing up**: the sign-up form is prefilled with the contact's first name,
  last name, nickname and mail address; the person completes the fields an
  account needs (first and last name, ADR-0062, a password, and a verified
  mail address where the server requires it) and may change the prefilled
  ones. A person who has an account already signs in and redeems it.
- **Redeeming**: the server makes the person a member of the organization
  (and of the inviter's band when a band leader invited, as in ADR-0023),
  replaces the contact with the account in the lineup of every set of the
  organization (each changed set gets a new revision), sets `linked_user`
  and marks the contact deleted, in one transaction. Revoking or letting the
  invitation expire leaves the contact as it was.
- From then on the person is a band member or a substitute in those sets
  like anybody added by name (ADR-0061), so a substitute sees their past gigs
  too.
- **Who invites**: whoever may invite into the organization today (ADR-0023):
  organization admins, and band leaders into their band. Set planners create
  contacts but do not invite, since they cannot invite anybody else either.
  The redemption changes sets of other bands too, but only by swapping the
  same person for their account; the inviter chose that person.

### 6. Permissions

| Action | Org admin | Librarian | Band leader | Set planner | Member | Substitute |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| See the names of the organization's contacts | ✓ | ✓ | ✓ | ✓ | ✓ | lineup's only |
| Create and edit contacts, see their mail addresses | ✓ | – | ✓ | ✓ | – | – |
| Invite a contact to setDING with a personal invitation that links it | ✓ | – | ✓ (into own band) | – | – | – |
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
| **Contacts of the organization** (chosen) | Reused in every set and band; one spelling per person; a place for a mail address; becomes an account through a personal invitation | A new collection, its sync, server rules and personal invitations |
| Free-text names in the set (JSON next to `lineup`) | Little work, no new collection | No reuse, the same person spelled differently in every set, no mail address, nothing to link when they join |
| Contacts per band | Narrower list | A guest playing with two bands of the organization exists twice; the organization's people pool is organization-wide already (ADR-0017, ADR-0061) |
| Invite them as members without them signing in (placeholder accounts) | One kind of person | Accounts nobody can sign in to, invitations and mail addresses that must be unique; mixes people with rights and people without |
| Contacts created by organization admins only | Tidy list | Too slow when a guest steps in shortly before a gig |
| Contacts created by every member | Open | Duplicates and data about outsiders from people without any planning role |
| Link by hand (*Link to account* on a contact, first proposal) | No new invitation kind | One more step after the person joined; easily forgotten, then the person shows twice in the picker |
| Link automatically by mail address on sign-up | Comfortable | Wrong matches with shared or mistyped addresses; the address is optional anyway |
| **Personal invitation for the contact** (chosen) | The person gets in with one link or QR code, prefilled; linking happens by itself | A single-use invitation kind bound to a contact |
| No mail address | Less personal data | *Notify lineup* cannot reach them |

## Consequences

- A set says who really played it, also people without setDING, in the app and
  on the printed set list.
- Set editors keep a reusable list of guests per organization and reach them
  through *Notify lineup*.
- The server gets the `contacts` collection with rules, an enrich hook hiding
  mail addresses, the check of `lineup_contacts`, personal single-use
  invitations that link a contact when redeemed, and an
  extended lineup mail route; all tested through the API, and the permission
  matrix test covers the new rows.
- The client gets a new synced table (a schema step), the contacts in the
  lineup dialog, the set view, the set card and the PDF, and a section on the
  organization screen.
- setDING stores names and optional mail addresses of people who have no
  account; the website page on lineups says what is stored and who sees it.
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
- 2026-11-26: Owner decision (#1096): no linking by hand. A contact gets a
  **personal invitation** (sent to its mail address from the device, or as a
  link or QR code); redeeming it links the contact to the new account by
  itself, and the sign-up form is prefilled from the contact, the person
  completing the required fields (decision 5 changed). Inviting follows who
  may invite today: organization admins, band leaders into their band.
- 2026-11-26: Accepted by the owner (#1096); the rows are in ADR-0023's
  permission matrix. Implementation: server #1097, data and sync #1098,
  lineup dialog and set list #1099, organization screen and personal
  invitations #1100, website page #1101.
- 2026-11-26: Server implemented (#1097): collection `contacts` with the
  rules of decision 6 (an enrich hook hides `email` from everybody but set
  editors); `setlists.lineup_contacts`, cleared like `lineup` when a set goes
  back to the whole band or is purged; the lineup route returns the
  contacts' names as `contacts`, the mail route their addresses as
  `contacts` next to `people`; personal invitations with `invites.contact`
  (used once, the preview returns the contact's names and mail address for
  the sign-up, redeeming links the contact in one transaction); deleting a
  contact clears its mail address and revokes its open invitations; closing
  and purging an organization purges its contacts.
- 2026-11-26: Data and sync implemented (#1098): schema 42 stores the
  contacts per organization (`contacts`, delta pull, pushed before the sets
  that name them, last writer wins; a refused change is replaced by the
  server state at the next pull) and `lineup_contacts` with the set. Every
  member, substitutes too, pulls the contacts of their organizations, so the
  names of a lineup come from the device as for people (ADR-0061); the
  lineup route's `contacts` is not needed. Deleted contacts keep their name
  in lineups, only the others are offered. Until the lineup dialog shows
  contacts (#1099), saving it keeps them and *Whole band* drops them. A set
  copied into another band and a closed organization drop them as well.
- 2026-11-26: Lineup dialog, set view and set list implemented (#1099):
  the dialog has a section *People without an account* with check boxes;
  *Add people* offers the organization's people and its contacts (marked
  *No account*, deleted ones left out) with one search, and *New person
  without an account* (first name required; last name, nickname and an
  optional mail address checked on the device) creates one offline and puts
  it in the lineup. The set view, the set card and the message of *Notify
  lineup* mark contacts *No account*, the printed set list does not;
  contacts of a lineup this device does not know yet are kept when saving.
- 2026-11-26: Organization screen and personal invitations implemented
  (#1100): the section *People without an account* lists the contacts with
  their mail address for set editors, with *New person without an account*,
  *Edit*, *Invite to setDING* (organization admins into the organization,
  band leaders into their band, chosen when they lead several) and *Delete*
  (organization admins, with a confirmation). The invitation dialog shows
  the QR code and the link to copy or share, and *By mail* with a prepared
  message to the contact's address. Personal invitations are not listed
  with the other links. The join screen names the person the invitation is
  for and prefills the sign-up from it; a member of the organization accepts
  it too (*Accept invitation*), which links the contact to their account.
- 2026-11-26: Website page *Besetzung und Aushilfen* / *Lineup and
  substitutes* extended with a section on people without an account and four
  screenshots (#1101). The website has no privacy notice yet, so the section
  itself says what setDING stores about them and who sees it (consequences
  changed accordingly).

## Open points

- Purging a deleted contact's name after a while (today the name stays in old
  sets for good).
- Merging two contacts that turn out to be the same person.
- Roles per person in the lineup (ADR-0061), for contacts as well.
