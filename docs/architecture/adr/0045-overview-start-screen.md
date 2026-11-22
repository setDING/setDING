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
   - **New set**, with the name of the person who created it (the editor
     of its first save, as sets have no `created_by`).
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
  and band arrangements** (new local columns `setlists.updated_by` and
  `band_arrangements.updated_by`, schema 22, as for songs since schema 11),
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
- 2026-11-20: Implemented the tab with *Next set*, *To do* and the footer
  (#666). *Start live* skips pauses and texts before the first song. The
  *To do* lines set a filter of the song list (`SongAttention`), shown as a
  removable chip, and switch to the songs tab; they count the songs of the
  library the song list shows. *Recent changes* follows in #667.
- 2026-11-20: Implemented *Recent changes* (#667): the device-only table
  `change_log` (schema 24) and `ChangeRecorder` in the sync engine. Notable
  details:
  - **"Last shown"** is the device setting `overviewLastShown`, set when
    the overview is **left** (another tab, or the app hidden while it is on
    the overview), not when it is built: the entries stay while the person
    reads them and opens one of them. An entry counts by the time it
    arrived on this device, so a change synced late still shows up.
  - **First sync**: nothing is logged for a library before any song or
    attachment of it was pulled, nor for a band before any set or
    arrangement of it was pulled. Changes without a known `updated_by`
    (e.g. records from before the server kept it) are not logged.
  - **Set changes** are counted per song (the multiset of song IDs of the
    old and new items), so a reordering is no change; the sequence of a
    set item is compared item by item (by item ID, otherwise the next item
    of the same song); songs not on the device do not count. A new set of
    someone else showed up as its songs added (replaced by *New set*,
    see the next entry). A sequence change of the
    band's arrangement is logged for every set of the band with the song.
    Deleted songs and sets and a new name of a PDF are not logged.
  - The log keeps one row per applied change; the overview merges the rows
    of one song or set into one entry (a new song stays new) and names the
    person from the members stored on the device. *Show all* lists the
    entries of the last 30 days.
- 2026-11-20: Owner: a set created by someone else shows up as **New set**,
  not as its songs added (#674). New kind `setAdded`; like a new song, a
  new set that was changed afterwards stays one *New set* entry.
- 2026-11-20: Owner: a tap anywhere on the set card (next set or most
  recently edited set) opens the set, like *Open set* (#693); *Start live*
  and *Open set* keep their own action.
- 2026-11-20: Owner request (#691): **hints after a sync.** The changes the
  sync engine detects for the change log also tell the open screens what
  someone else did:
  - **What counts:** each run reports the songs and sets others changed or
    deleted (`SyncReport.changes`, filled by `ChangeRecorder`, with the same
    rules: not on the first sync of a library or band, not the signed-in
    user's own changes from any device, not without a known `updated_by`).
    Unlike the change log, deletions count. A reordering or a new name, date
    or venue of a set counts too, but played marks do not. A song deleted by
    someone else also counts as a change of the sets that lose it.
  - **Open song or set:** a SnackBar such as "“Title” was changed by Anna."
    names the person from the members stored on the device. A deleted song
    or set closes its page and says who deleted it. A set shown next to the
    list on wide screens stays, as after deleting it there.
  - **Live mode:** nothing is shown while live mode is open; the sync is
    paused (ADR-0007). The run that catches up afterwards shows one summary
    instead of the screens' own hints ("While you were playing live: 1 song
    deleted, 2 songs changed"), with *Show* opening *Recent changes*.
  - **Unchanged:** the change log still does not log deletions; nothing new
    is stored on the device or the server.
- 2026-11-20: Owner (#701): **entries of deleted songs and sets are
  hidden.** *Recent changes* and *Show all* list only songs and sets that
  are on the device and not deleted; a song or set deleted (or purged)
  after its change was logged drops out, so no entry opens a deleted
  record. The rows stay in the change log: a song or set restored from
  the trash (ADR-0043) shows its earlier entries again while they are
  within the 30 days. Deletions themselves are still not logged.
- 2026-11-21: Owner request (#798): ***To do* also counts songs with
  possible conversions**, the places the editor offers to convert
  (`{ccli}`/`{ccli_license}`, the CCLI footer, CCLI bar lines, short-form
  section labels; `countChordProConversions`). They show as intended, so
  they are a line of their own after the problems, with a quiet icon
  instead of the warning colour; the count is derived on the device like
  the problems (`songs.chordpro_conversions`, schema 30, not synced). The
  song list marks these songs for people who may edit them and, filtered
  to them, offers **Convert all** (`applyChordProConversions`) after a
  confirmation, as the songs are shared.
- 2026-11-21: Owner request (#800): **the *To do* filters are chips of
  the song list** too, one per kind with songs the person may edit (or
  the one chosen), so they can be chosen without the overview; a second
  tap removes the filter. The overview lines still set the same filter.
  A tap on the **magic wand** of a song converts that song at once, with
  *Undo* in the message (undo rather than ask, ADR-0051).

- 2026-11-22: Owner request (#868): the overview looked empty without
  anything to do and without changes, so **three more cards** that always
  have something to show, each entry opening a song or set (no statistics,
  see the alternatives above). In this order after the existing ones, each
  left out when it has nothing to show:
  - **More sets**, right after *Next set*: the upcoming sets of the band
    after the next one, at most three, with date, days until the gig and
    venue.
  - **Newest songs**, after *Recent changes*: the five songs of the band's
    library created last, not in the trash, with artist, key and the day
    they were added. Unlike *Recent changes* it shows the person's own
    songs too and never empties. The creation date is a new local column
    `songs.created_at` (schema 33): the server's `created` for synced
    songs (sent with every pull, nothing new on the server), the time of
    creation on the device for the local library, a copy and a song not
    pushed yet. On the upgrade the songs of every library are pulled once
    more from the start; a pull fills the date of a song it already has
    without changing anything else (no conflict, no change log entry).
    Songs of the local library take their last change as the best guess.
  - **Not played for a while** (the title of the repertoire's section,
    ADR-0046), last: the songs the band has not played for longer than its
    threshold, longest ago first, at most five, with *Show all* opening
    the repertoire.

## Open points

- Further cards later, e.g. pending invitations or the reminder for a full
  backup (ADR-0043).
