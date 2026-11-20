# ADR-0045: Overview as the start screen

- **Status:** Accepted
- **Date:** 2026-11-20

## Context

The app has three tabs: *Sets*, *Songs* and *Settings*
(`app/lib/ui/home_screen.dart`), and it always opens on *Sets*. Useful
information is spread over these tabs or not visible at all:

- which set is next, although the song list already knows the next set of the
  current band with a gig date from today on (status icon, ADR-0003, #314);
- songs whose ChordPro probably does not show as intended
  (`songs.chordpro_problems`), open sync conflicts and songs with sheet music
  only: each is marked per song, but there is no list of what needs attention;
- what other people changed since the last time the app was used;
- the version, the update hint (ADR-0036) and *What's new* (ADR-0041), which
  are under *Settings → Storage & info*.

The most frequent path must stay fast: on the way to a gig or a rehearsal a
musician opens the app, picks the set and starts live mode (ADR-0007). A start
screen that only shows statistics would add a tap to this path every time.

## Decision

A new first tab **Overview** (de-CH *Übersicht*) becomes the start screen of
the native apps and of the web client (after the sign-in and band gate of
ADR-0018). The tabs become *Overview · Sets · Songs · Settings*. The overview
shows cards, in this order, and leaves out a card that has nothing to show:

1. **Next set**: the next set of the current band with a gig date from today
   on (the one the song list already uses), with date, number of songs and a
   **Start live** button that opens live mode on its first song, plus *Open
   set*. Without such a set, the most recently edited set of the band. This
   keeps the main path at one tap after the start, one less than today.
2. **To do**, only for people who may edit the songs concerned (the edit
   rights of ADR-0023, the same check as the song list's warning icon): the
   number of songs with ChordPro problems, open sync conflicts and songs with
   sheet music only; each line opens the song list filtered to these songs.
3. **Recent changes**: what other people changed in the current band and its
   organization since this device last showed the overview, newest first, at
   most about ten entries, with *Show all* for the full list. One entry per
   song or set:
   - **New song**, with the name of the person who created it
     (`songs.created_by`, ADR-0023) where known.
   - **Changed song**: its ChordPro text, or a PDF attachment added, replaced
     or removed (an attachment counts as a change of its song), with the name
     of the person who changed it last (`songs.updated_by`) where known.
   - **Changed set**: songs added to or removed from the set, and changed song
     sequences (`{x_sequence}`), both of a set item (ADR-0006) and of the
     band's arrangement of a song in the set (ADR-0025), listed as short
     details ("2 songs added, 1 removed, sequence of *Song* changed"), with
     the name of the person who changed the set or the arrangement last. A
     reordering or a new gig date alone is no entry.

   The entries come from a **local change log** (a new table on the device,
   not synced) that the sync engine fills while it applies records from the
   server, comparing them with the local state it replaces: only incoming
   changes whose `updated_by` is someone else, so a person's own changes,
   also from their other devices, never show up. The very first sync of a library logs
   nothing. Entries older than 30 days are removed. The marker "last shown" is
   a **device setting**, not synced; on a new installation the card starts
   empty.
4. **Footer**: the version (with beta and commit for beta builds, #654), the
   update hint of ADR-0036 and the *What's new* button of ADR-0041. Both stay
   under *Storage & info* as well.

Further rules:

- **Everything comes from the local database** (ADR-0001); the overview works
  offline and never waits for the network. A running sync updates it live.
- **Who changed it**: the server already records `updated_by` on every
  synced record and sets it itself from the request (`handleWriteRequest`,
  clients cannot set it, ADR-0015). The client now also keeps it for **sets
  and band arrangements** (new local columns, as for songs since schema 11),
  so every entry can name the person.
- **Nothing new on the server**: no new fields, rules or permissions. The
  overview only shows what the person can already read; the *To do* card is
  hidden by the same client check as the warning icons, which is presentation
  only (the server still enforces every write, ADR-0023).
- **Layout**: one column on phones; from 720 px (where the navigation rail
  starts) two columns. No charts.
- All texts in `app_de.arb` and `app_en.arb` (ADR-0008).
- Live mode is unaffected; leaving live mode returns to the tab it was started
  from.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Keep *Sets* as the start screen (today) | No work, main path unchanged | Problems, changes and the next set stay hidden |
| Open the last used tab | Little work | Shows none of the new information; start depends on the last session |
| Overview as a page in *Settings* or behind an icon | No change of the tabs | Nobody sees it; the point is to see it at the start |
| **Overview as the first tab with the next set on top** (chosen) | Main path one tap shorter; problems and changes visible at a glance | A fourth tab; more to keep up to date on every sync |
| Statistics dashboard (counts, charts) | Looks informative | Adds a tap to the main path; numbers without an action are of little use on stage |

## Consequences

- The navigation has four destinations; the bottom bar on phones still fits.
- Deep links (`deep_links.dart`) and tests that assume *Sets* as tab 0 must be
  adapted.
- The set items are one JSON array in the set record (ADR-0015), so the
  details of a changed set come from comparing the incoming array with the
  local one; the sync engine (sets and arrangements parts) gets this
  comparison and a new local table with a schema migration.
- A "last shown" marker per device means a person sees the same change again on
  each of their devices; acceptable, simpler than a synced marker.
- Implementation in separate issues once the ADR is accepted: the tab with the
  *Next set* card first, then *To do*, then *Recent changes* and the footer.

## Decision log

- 2026-11-20: Proposed (#656).
- 2026-11-20: Owner feedback: the start tab is **not** a setting, the
  overview is always the start screen. *Recent changes* shows **new songs**;
  a new, replaced or removed **PDF counts as a change of its song**; a
  **changed set** means songs added or removed and changed song sequences.
  Hence the local change log filled by the sync engine.

- 2026-11-20: Owner: also show **who changed a set**. The server already
  records `updated_by` on sets and arrangements; the client keeps it now, and
  a person's own changes from other devices are left out. **Accepted** by the
  owner (#656).

## Open points

- Further cards later, e.g. pending invitations or the reminder for a full
  backup (ADR-0043).
