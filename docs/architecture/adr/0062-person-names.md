# ADR-0062: First name, last name and nickname of people

- **Status:** Proposed
- **Date:** 2026-11-23

## Context

An account had one free-text `name` (PocketBase's default field of `users`),
required at sign-up but not checked: people signed up as "Andi" or "Drums".
In organizations with many people (a music school, ADR-0017) this makes it hard
to find somebody in the member lists or when adding a substitute to a set's
lineup (ADR-0061), and the same person shows up under different names in
different bands' minds. The owner asked for a required full name and an
optional nickname (issue #1039).

The decisions (owner, 2026-11-23):

- first and last name stored separately, both required; the nickname optional;
- how names of other people are shown is a setting of the viewer, with four
  variants;
- existing accounts are migrated and asked for the missing parts after sign-in.

## Decision

### Server (`users`)

- Three text fields on `users`: **`first_name`**, **`last_name`** and
  **`nickname`** (at most 100 characters each). They are not `required` in the
  schema, so accounts from before keep working until they are completed.
- A hook (`pb_hooks/names.pb.js`, `lib/names.js`) on create and update requests:
  - **sign-up** needs a non-empty first and last name, also for superusers;
  - an update that sends `first_name` or `last_name` cannot clear it;
  - whitespace is trimmed and collapsed;
  - **`name` is maintained by the server** as the display name: the nickname,
    otherwise "First Last". A client never sets it directly. Older app versions,
    server routes (`/api/setding/lineup…`, invitation lists) and mail texts keep
    working with it.
  - **Older apps** that only send `name`: on sign-up it is split (two or more
    words → first name(s) and last name; a single word fails with a `name`
    error the old app can show); on update a name with two or more words
    replaces first and last name, a single word becomes the nickname.
- **Migration** (`1797200000_user_names.js`): an existing `name` with two or
  more words becomes first name(s) and last name, a single word becomes the
  nickname. Accounts without a full name stay valid.
- Visibility does not change: the existing `users` rules (ADR-0015) apply to
  the new fields as to `name`; no new rule, no new route.
  The lineup routes return the three fields next to `name`.

### Client

- `AuthUser` carries `firstName`, `lastName` (null when the server does not
  know the fields, i.e. an older server) and `nickname`; **`needsFullName`** is
  true when the server knows the fields and one of them is empty.
- The device caches the three fields per membership (`org_memberships`,
  `memberships`, **schema 40**); `userName` stays the fallback of older servers.
  `PersonName` formats, sorts and searches them.
- **Sign-up** and **Change name** have three fields: *First name*, *Last name*
  (required) and *Display name (optional)*.
- **Prompt:** when the signed-in account `needsFullName`, the app shows the
  *Add your full name* dialog over every screen; it cannot be dismissed until
  first and last name are saved.
- **Setting *Show names as*** (personal, synced with the account, ADR-0027),
  in *Settings → Organization & bands*:
  - *Display name (otherwise full name)*, the default: "Andi", without a
    nickname "Andreas Boss";
  - *First Last*: "Andreas Boss";
  - *Last First*: "Boss Andreas", lists sorted by last name;
  - *First Last (display name)*: "Andreas Boss (Andi)".
  Every variant falls back to what is known (full name, nickname, the old
  single name, finally the email address).
- Applied to the member lists of organizations and bands (with the full name
  under a shown nickname), the lineup of a set and its people picker, and the
  names of the recent changes. Lists are sorted by role, then by the shown
  name (*Last First*: by last name).
- **Search** for people (the lineup's people picker) matches first name, last
  name and nickname, every word of the query.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| One "full name" field with at least two words, plus nickname | Less schema change | First and last name not separable ("van der Berg"), no sorting by last name |
| **Separate first and last name, optional nickname** (chosen) | Sorting and formatting per viewer, clear required fields | More fields; older apps need a translation of `name` |
| One fixed display format for everybody | Simpler | The owner wanted the viewer to choose |
| Require the fields in the schema (`required`) | Enforced by PocketBase | Every update of an old account without a full name would fail, also password changes |
| Only new accounts need the full name | No prompt | Old accounts stay hard to find |

## Consequences

- Finding people by last name works everywhere a list of people is searched or
  sorted; member lists can be sorted by last name.
- `name` is no longer written by clients; a script that set it now changes
  first and last name or the nickname through the split rule.
- An older app can no longer sign up with a single word as its name (the server
  answers with a `name` error); updating the app shows the three fields.
- People with accounts from before see one non-dismissable dialog after their
  next sign-in or start with the new app.

## Decision log

- 2026-11-23: Proposed (#1039): separate first and last name (required) and an
  optional nickname; display format as a personal setting with four variants;
  migration of existing names and a prompt for missing parts.

## Open points

- Searching the member lists of organizations and bands themselves (today only
  the lineup's people picker has a search field).
