# ADR-0005: One app with roles instead of a separate management app

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

We need management features (creating sets, adding songs) and a display for the
band members. This can be built as two separate applications or as one app with
different permissions.

## Decision

**A single app** whose features depend on the user's role in the band.

### Roles

There are two roles per band membership: **admin** and **member**.

- A band can have **several admins** (e.g. band leader and deputy).
- A user account can be a **member of several bands** and switch between them
  (band switcher). The role is defined per band.
- There is **no guest role**.

### Permissions

| Feature | Admin | Member |
|---|---|---|
| View sets & play live | ✓ | ✓ |
| Personal adjustments (overlay, ADR-0006) | ✓ | ✓ |
| Create / edit / import songs | ✓ | only if enabled for the band |
| Delete songs | ✓ | – |
| Create / edit / reorder / delete sets | ✓ | – |
| Invite members, assign roles, band settings | ✓ | – |

**Song editing by members** is a band setting (`members_can_edit_songs`), off by
default. An admin can enable it in the band settings.

Permissions are **enforced server-side** (PocketBase access rules) and evaluated in
the client only for the UI (showing/hiding buttons). Every band must always keep at
least one admin.

### Invitations

New members join a band via an **invitation link**:

- An admin creates a link for the band in the app and shares it (e.g. in the band's
  group chat). The app can also show it as a **QR code** for joining in person at a
  rehearsal.
- Format: `https://<server-domain>/invite/<token>` with a long random token. The
  server only stores a **hash** of the token.
- A link can be used **several times**, is valid for **7 days** and can be **revoked**
  by any admin at any time. Admins can see who joined via which link.
- A link always grants the **member** role. Admin rights are assigned afterwards by an
  existing admin.
- Opening the link:
  - App installed → the app opens via deep link (Android App Links, iOS Universal
    Links, Windows protocol handler) and shows "Join band *X*?".
  - App not installed → a small web page on the server explains how to install the app;
    afterwards the link can be opened again or pasted in the app ("Join band").
  - The user signs in or creates an account first, if needed.
- Joining requires a network connection once (the server validates the token and
  creates the membership). After that the band's data is synced (ADR-0001).

The management UI is optimized for larger screens (tablet in landscape, Windows PC);
it is usable on a phone, but that is not a primary target.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **One app with roles** (chosen) | One code base, the band leader uses the same app live, the editor preview automatically matches the live view | Role logic in the UI |
| Separate web app for management | Convenient on the PC, no installation | Second code base or second renderer → preview may differ from the tablet |
| Management only via the backend admin UI | No effort | Not user-friendly, no preview |

Alternatives for song editing:

| Option | Pros | Cons |
|---|---|---|
| **Configurable per band** (chosen) | Fits strict and relaxed bands alike | One additional setting and access rule |
| Admins only | Simplest, hardly any conflicts | Members cannot fix typos themselves |
| All members | Everyone can correct | More conflicts |
| Members suggest, admin approves | Controlled | Considerably more effort (review workflow) |

Alternatives for invitations:

| Option | Pros | Cons |
|---|---|---|
| **Invitation link (+ QR code)** (chosen) | One tap for the invitee, easy to share in a group chat, works in person via QR | Deep links need a public domain and platform setup |
| Invitation code | No deep-link setup | Code must be typed manually |
| Email invitation | Personal, bound to one person | Requires mail sending from the server, more effort |

## Consequences

- The Windows version also serves as the "management workstation" on the PC.
- A Flutter web build of the same app can be added later if management in the browser is desired.
- If members may edit songs, concurrent edits become more likely; the conflict handling from ADR-0004 (no silent overwrite) is therefore required from phase 1 on.
- The local DB holds the data of **all bands** the user belongs to (ADR-0001); every query is scoped by `band_id`.
- Songs belong to one band. Sharing a song with another band is done via export/import (copy), not via a shared reference.

## Decision log

- 2026-11-14: One app with roles accepted.
- 2026-11-14: Song editing by members is configurable per band (default: admins only). Sets are managed by admins only.
- 2026-11-14: Several admins per band and membership in several bands are supported. No guest role.
- 2026-11-14: Members join via invitation link (reusable, 7 days valid, revocable, member role only), also shown as a QR code. Invite codes and email invitations are not planned.
- 2026-11-15: App name RealChord chosen; `realchord.app` (and `realchord.ch`) are the intended public domains for invitation links and the deep-link verification files, once registered and pointed at the server (see `docs/app-name-candidates.md`).
- 2026-11-15: **Organizations** above bands decided in **ADR-0017** (accepted) (owner request): songs belong to the organization and are shared by all its bands (replaces "songs belong to one band; sharing between bands only by copy"); organization admins manage people and bands; invitations add people to the organization, band admins then add organization members to their bands. Band roles and `members_can_edit_songs` stay.
- 2026-11-15: Owner decisions for the app (issue #15): the MVP data stays as a **local library** ("On this device") – its own entry in the band switcher, never synced, usable without an account; songs (multi-select) and whole sets can be **copied** from the local library or another band into a band (songs into its organization's library). The UI shows only the actions the user's roles allow; the server rules stay the authority.
- 2026-11-15: Invitations implemented (issue #16), into the **organization** (ADR-0017): links `https://api.realchord.app/invite/<token>` with a 32-character random token (only its SHA-256 hash is stored), created, previewed and redeemed through server routes (`pb_hooks/invites.pb.js`), revoked by organization admins, `org_memberships.invite` records who joined with which link. A landing page explains how to open the link in the app. Deep links: Android App Links for `api.realchord.app/invite/*` (verification file served once the signing fingerprint is configured) and the `realchord://invite/<token>` scheme on Android and iOS; the app also accepts pasted links (Bands → Join). The public domain question is resolved with `api.realchord.app` (ADR-0014).
- 2026-11-15: Management in the browser (ADR-0018, accepted) is the **same app** as a Flutter web build, not a separate web app; roles and gates are unchanged. The local library is hidden on web. The invitation landing page offers "Open in the browser".
- 2026-11-16: The band switcher is only on the sets tab; the songs tab chooses a song library (organization or local library) independently (#167, ADR-0017).
- 2026-11-16: Web client implemented (#27): signing in is required; the local library is neither shown nor selectable on web (also not while the bands load or with an old stored choice); without a band the web client offers to manage bands or join with an invitation; the landing page links to `https://app.realchord.app/invite/<token>`, which opens the join screen.
- 2026-11-17: **ADR-0024** (accepted): the server operator decides whether people may sign up without an invitation (`REALCHORD_REGISTRATION`, default `invite_only`); on closed servers an invitation is also the ticket to create an account, and new organizations come only from operator **founder invitations**.
- 2026-11-17: **ADR-0023** (accepted): band roles leader (`admin`) > set planner > member; the band setting `members_can_edit_songs` is replaced by the organization role librarian; band leaders invite into their band; still no guest role.

## Open points

- Activate verified deep links: Android needs the signing certificate fingerprint, iOS Universal Links need the Apple Team ID and the Associated Domains capability (`docs/operations/server.md`, "Deep links"). Until then links open the landing page, the `realchord://` scheme, or are pasted / scanned.
- Protocol handler for `realchord://` on Windows (MSIX/installer) and Linux (`.desktop` file); until then links are pasted there.
