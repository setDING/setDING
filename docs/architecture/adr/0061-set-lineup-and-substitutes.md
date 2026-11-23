# ADR-0061: Lineup per set and substitutes from the organization

- **Status:** Accepted
- **Date:** 2026-11-23

## Context

A band plays most gigs with its regular members, but not all of them: a singer
is ill, the pianist is on holiday, a guitarist from another band of the
organization helps out. Today the app knows only the band:

- **Every band member sees every set** of the band (ADR-0023), and nothing says
  who actually plays a set.
- **A substitute** is added to the band as a member (ADR-0023, owner decision
  2026-11-17: no guest role). Then they see every set of the band, past and
  future, until somebody remembers to remove them, and the band's member list
  no longer says who belongs to the band.
- **Telling people** that they play a gig happens outside the app.

Planning tools for church bands (e.g. Planning Center) plan people per date and
role and send a request by mail that the person accepts or declines.

The owner's idea (2026-11-23): when a set is put together, choose the people
who play it. The band's members are proposed; people are removed with check
boxes or added from the organization's pool. When the set is ready, a message
can be sent to the chosen people.

Forces:

- **Offline-first** (ADR-0001): the substitute needs the set, its songs, PDF
  attachments and the band's arrangements on their device before the gig,
  like any member.
- **Permissions on the server** (owner rule #632, ADR-0023): the server decides
  who sees a set; anyone can call the API directly. A substitute must see the
  sets they play and nothing else of the band.
- **People stay inside their organization** (ADR-0017): the pool is the
  organization's members; nobody from outside is offered.
- **No SMTP required** (ADR-0024): sending mail from the server needs SMTP,
  which is optional for operators.
- **Older apps** keep working: they save sets without knowing the new field.

## Decision

### 1. A lineup per set: people, no roles

A set gets a **lineup**: the people who play it. Version 1 has **people only**,
no roles or instruments (owner decision); roles per person are a possible later
step (open points).

- Server collection `setlists` gets `lineup` (relation to `users`, several) and
  `lineup_custom` (bool).
- `lineup_custom = false` (every existing set, every set older apps create)
  means **the whole band**: the lineup follows the band's members, also people
  who join later. Nothing is stored in `lineup`.
- When somebody changes the lineup of a set, `lineup_custom` becomes `true` and
  `lineup` holds the chosen people. *Reset to the band* goes back to `false`.
- The lineup is edited by whoever may edit the set: band leaders, set planners
  and organization admins (ADR-0023).
- Every person in `lineup` must be a member of the band's organization; the
  server refuses others (hook on create and update of `setlists`). Band members
  and other people of the organization are both allowed.
- Older apps do not send the fields; PocketBase keeps stored values of fields a
  request does not send, so they do not erase a lineup.

### 2. Choosing the lineup in the set editor

The set editor shows a section *Lineup* with every band member checked by
default (owner decision). A command *Add people* opens a picker of the
organization's other members (search by name). Unchecking a band member takes
them out of this set; a person from outside the band is shown as
*Substitute* (*Aushilfe*). The set card and the set view show the lineup as a
short list of names.

### 3. What a band member taken out of a set sees

A band member not in the lineup of a set **still sees it** (owner decision):
they may rehearse it, step in, or look up what was played. The set is marked
*Not planned for you* in the set list and the set view, and it does **not**
count as their gig: the overview's *Next set* (ADR-0045) and the upcoming-gig
icon of the song list skip it for them.

### 4. What a substitute sees

A **substitute** is a person in the lineup of a set who is not a member of its
band. They see that set **read-only**, as long as they are in its lineup, also
after the gig (owner decision). Removing them from the lineup, setting it back
to the band, or deleting the set ends their access.

They get:

- the set with its items (songs, markers, set-specific keys and sequences);
- the **band arrangements of the songs in that set** only (owner decision), not
  the band's other arrangements (ADR-0025);
- the songs and attachments, which they see already as members of the
  organization (ADR-0017);
- the band's **name**, to show where the set belongs, but not its members,
  settings, other sets or repertoire (ADR-0046);
- the **names of everyone in the lineup** (owner decision), so they know who
  they play with; they know these people as members of the organization
  anyway, and see no mail addresses.

They cannot edit the set, its lineup or the arrangements, and they never freeze
how a song was played (ADR-0046: only clients with set rights do that). Personal
overlays and annotations work as for any song they see (ADR-0020, ADR-0032).

**On the server**, a substitute does not get the band's collections through the
records API:

- The rules of `setlists` stay per band (band members and organization admins)
  and are not widened.
- A new server route `GET /api/setding/lineup` returns, for the signed-in user,
  every non-deleted set whose `lineup_custom` is true and whose `lineup`
  contains them while they are not a member of its band, with the band's ID and
  name and the arrangements of the songs in those sets. Like the plays of
  ADR-0046, the route computes everything from the user's own memberships and
  returns nothing else; it is tested through the API as the refused roles.
- The client calls it at every sync and **replaces** its substitute data with
  the result, so a removal reaches the device at the next sync without a delta
  or tombstone. The data is stored for offline use like synced sets.

### 5. Where the substitute finds the set

On the substitute's device the band of such a set appears in the **band
switcher** marked *Substitute*. It shows only the sets they are in the lineup
of, read-only; band settings, members, invitations and repertoire are not
shown. The overview's *Next set* (ADR-0045) takes the next set they are in the
lineup of, across their bands and these bands, so a substitute sees their gig
on the start screen. The band disappears from the switcher once they are in no
lineup of it any more.

### 6. Telling the lineup (version 1, no server mail)

- **Share from the device**: the set editor gets *Notify lineup*. It opens the
  platform's share sheet (on the web and desktop: copy to the clipboard, and a
  `mailto:` link) with a prepared text in the sender's language: set name, gig
  date, venue, the names of the lineup and a link that opens the set in the app.
  The person sending chooses the channel (mail, messenger, band chat); the app
  does not send anything itself.
- **Mail addresses of the lineup** (owner decision): for the mail link, the
  app fills in the recipients. Users' addresses stay hidden from other users
  (PocketBase `emailVisibility`); a server route
  `GET /api/setding/lineup/{set}/emails` returns the addresses of the people in
  that set's lineup, only to whoever may edit the set (band leaders, set
  planners, organization admins), and is tested through the API as the refused
  roles. It needs a network; offline the text is shared without recipients.
- **Hint in the app**: when a sync brings a set the person has newly been put
  in the lineup of (as band member taken back in or as a substitute), the
  overview shows a hint *You are planned for <set> on <date>* like the other
  hints after a sync (ADR-0045); it is shown once per set and device.

Requests by server mail with *accept* / *decline* (as in Planning Center) are
not part of this decision (open points).

### 7. The lineup on the printable set list

The printable set list and the text export (ADR-0013) get a line
*Lineup: Anna, Beat, Carla …* in their header below name, date and venue
(owner decision), also when the lineup is the whole band (then with the names
of the band's members).

### 8. Permissions

The permission matrix of ADR-0023 has these rows
(*Substitute* = a person in a set's lineup who is not a member of its band):

| Action | Org admin | Librarian | Band leader | Set planner | Member | Substitute |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Choose a set's lineup, add people of the organization | ✓ all bands | – | ✓ | ✓ | – | – |
| See a set they are in the lineup of, with its songs' band arrangements, read-only | ✓ | – | ✓ | ✓ | ✓ | ✓ |
| See the names of a set's lineup | ✓ | – | ✓ | ✓ | ✓ | ✓ |
| Notify the lineup from the device, with the lineup's mail addresses | ✓ all bands | – | ✓ | ✓ | – | – |

ADR-0005 and ADR-0023 keep *no guest role*: a substitute is not a role of the
band but a person in a set's lineup.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keep adding substitutes as band members (ADR-0023, today) | No work | They see every set of the band until removed; the member list no longer says who belongs to the band; nothing says who plays a set |
| A guest role in the band, limited in time | Fits the band screens | A second kind of membership with its own rules everywhere; still per band, not per gig; ADR-0005 and ADR-0023 exclude guest roles |
| **Lineup per set** (chosen) | Says who plays a gig; gives a substitute exactly one set; useful without substitutes too | A new field and a server route; a band appears on a substitute's device without them being a member |
| Lineup with roles (vocals, piano, drums) | Shows who plays what, like Planning Center | Needs an instrument per membership and a role model; more than the owner needs now (owner decision: people only) |
| Store the whole band in `lineup` when a set is created | One meaning, no flag | New band members are missing from sets made before they joined; older apps create sets without a lineup anyway |
| Widen the `setlists` and `arrangements` rules for the lineup | Ordinary sync | The arrangement rule would have to look into the JSON items of every set; a removal from the lineup needs tombstones the delta pull does not have |
| Server mail with accept / decline | Like Planning Center; status visible in the set | Needs SMTP (optional, ADR-0024), mail templates in six languages, reminders and a status model; a feature of its own |
| Only the hint in the app | No sharing UI | People who do not open the app before the gig never learn about it |

## Consequences

- A set says who plays it; a band can plan gigs with substitutes without
  changing its members.
- A substitute gets exactly the sets they play, offline, with the band's keys
  and sequences for those songs, and keeps them read-only for looking back.
- The server gets two new routes and a hook that checks the lineup against the
  organization's members; both are tested through the API, and the permission
  matrix test covers the new rows.
- The client stores substitute sets and arrangements next to the synced ones and
  replaces them at every sync; the band switcher, the overview and the set
  list learn the *Substitute* and *Not planned for you* states.
- New UI texts in all six languages; a website page section and screenshots of
  the lineup in the set editor, the share text and the substitute's band
  (AGENTS.md).
- Set archives (ADR-0043) do not carry the lineup: people belong to an
  organization, and an imported set is a copy for another band.
- The printable set list and the text export show the lineup (ADR-0013).
- Follow-up decisions: roles per person, requests with accept / decline.

## Decision log

- 2026-11-23: Proposed after a discussion with the owner (#1003). Owner
  decisions: people only, no roles; every band member preselected; a band
  member taken out still sees the set, marked as not planned for them; a
  substitute keeps read-only access as long as they are in the lineup, also
  after the gig; a substitute sees only the band arrangements of the songs in
  the set; notification by sharing from the device and a hint in the app, no
  server mail in version 1.
- 2026-11-23: Open points decided by the owner: a substitute sees the names of
  everyone in the lineup; the lineup is a line in the header of the printable
  set list and the text export; *Notify lineup* fills in the lineup's mail
  addresses, which a server route gives only to people who may edit the set.
- 2026-11-23: Accepted by the owner (#1003); the rows are in ADR-0023's
  permission matrix. Implementation: server #1007, data and sync #1008, set
  editor #1009, substitute view #1010, notify and set list #1011, website
  page #1012.

## Open points

- Roles per person in the lineup (vocals, piano, …), with an instrument per
  band membership as the default.
- Requests by server mail with *accept* / *decline* and a status per person,
  when the server has SMTP.
