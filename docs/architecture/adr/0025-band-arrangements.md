# ADR-0025: Band arrangements between song and personal overlay

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

Songs belong to the organization and are shared by all its bands (ADR-0017). Since
ADR-0023, band leaders no longer edit songs of others: the library is maintained by
librarians and organization admins. Bands still need to adapt songs for themselves:

- a choir sings a song in A, the youth band in C;
- one band plays verse–chorus–verse–chorus, another adds a bridge and an outro;
- the youth band plays the song faster than the choir.

Today this is only possible in two places, and neither fits:

- **Set items** (layer 2, ADR-0006) hold a transposition and a sequence, but only for
  one set. The leader repeats them in every set, and a song opened on its own shows
  none of it.
- **Personal overlays** (layer 3, ADR-0006, ADR-0020) are private per person. Every
  band member would have to set the band's key themself.

ADR-0023 decided that band leaders and set planners maintain a **band arrangement**
and left its design to this ADR.

## Decision

### Layers

A new layer between the song and the set item (ADR-0006, applied in this order):

1. **Song** (ChordPro, organization): original key, sequence, everything else.
2. **Band arrangement** *(new)*, per band and song: the band's key, sequence and tempo.
3. **Set item**, per set: "tonight" on top of the band's key, or another sequence.
4. **Personal overlay**, per person and song: transposition/capo, notes, font size, …
5. **Device settings**.

The arrangement **never changes the song**. A correction of the song by the library
(ADR-0023) reaches every band, with their own arrangements still applied.

### Contents of an arrangement

| Field | Meaning | Default |
|---|---|---|
| `transpose` | Semitones relative to the song's key (the band's key) | 0 |
| `sequence` | Song sequence in `{x_sequence}` syntax (ADR-0012) | null = as in the song |
| `tempo` | Tempo in BPM for this band | null = as in the song (`{tempo}`) |

The key is stored as a transposition relative to the song (like set items), so it
stays correct when the library fixes the song but not its key. The app shows it as
the resulting key ("C (+3)").

Capo, font size and Nashville stay **personal** (layer 4): they depend on the
instrument and the person, not the band. There are **no band notes**: they are not
needed for now (owner); personal notes stay as they are.

### How it combines

- **Transposition:** song + arrangement + set item + personal overlay. A set item's
  transposition becomes relative to the band's key: "−2 tonight" means two semitones
  below the band's key. Existing set items keep their value: without arrangements
  the band's key is the song's key, so nothing changes for existing sets.
- **Sequence:** the first that is set wins: set item, arrangement, song.
- **Tempo:** the arrangement's tempo replaces the song's `{tempo}` wherever the app
  shows or uses it (song header, set list, a later metronome or count-in, ADR-0007
  roadmap); the song keeps its own value.
- **Where it applies:**
  - in a set and in live mode started from a set: the arrangement of the set's band;
  - on the songs tab and when a single song is played live: the song is shown
    **as written**. The song screen shows the arrangement of the band chosen on
    the sets tab (if it plays from this library) only in its own card, where it
    is also edited.
- **Printable set list and set export** (ADR-0013): key, sequence and tempo for the
  set include the arrangement.
- **Copy to band** (ADR-0017): copying a set into another band of the same
  organization keeps its items; the target band's arrangements apply. Copying songs
  into another organization does not copy arrangements (they belong to a band).

### Permissions (ADR-0023)

| Action | Who |
|---|---|
| See a band's arrangements | band members and organization admins |
| Create, change and remove arrangements | band leaders, set planners, organization admins |

### Server and sync (ADR-0004, ADR-0015)

- New synced collection `arrangements`: `band`, `song`, `transpose`, `sequence`,
  `tempo`, sync fields; unique per band and song; the song must belong to the band's
  organization.
- Delta pull per band, like sets; **last writer wins** (like sets): an arrangement is
  small and maintained by a few people, a conflict dialog is not worth it.
- Removing an arrangement is a soft delete. Deleting a song soft-deletes its
  arrangements (like its overlays, ADR-0020).
- Offline: changes go to the outbox like sets; set planners and leaders can prepare
  arrangements without a connection.

### App

- Local table `band_arrangements` (band, song, the fields, revision; key band + song).
- Song screen and live mode in a band context: leaders and set planners get a
  "Band arrangement" section (key, sequence, tempo); members see it read-only.
  "Reset to the song" removes the arrangement.
- The key picker in a set shows the band's key as the reference.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Arrangement layer per band and song** (chosen) | Once per band, applies in every set and on the songs tab; library corrections still reach every band | One more layer, collection and table |
| Status quo: set items only | No work | Repeated in every set; not visible outside sets |
| Personal overlays for the band key | No new concept | Every member sets it; private, not shared |
| A copy of the song per band | Full freedom (also lyrics and chords) | Duplicates; corrections must be repeated; ADR-0017 chose one library to avoid this |
| Arrangement as a full ChordPro text per band | Any change possible | Diverges from the song; corrections of the library get lost |
| Arrangement per organization instead of band | Simpler | Different bands of one organization need different keys |
| Set item transposition stays relative to the song | No change in meaning | Every set must repeat the band's key; the arrangement would only help outside sets |
| Conflict dialog like songs | No lost change | Effort out of proportion for three small fields |
| Capo per band | Guitars of a band agree on one capo | Depends on the instrument and person; stays in the personal overlay (owner) |
| Band notes (one per song or anchored) | Shared hints for the band | Not needed for now (owner) |
| Arrangements only in sets and live mode from a set (chosen since #227) | Songs tab shows the song as written; the band's key is shown in its card | The song screen does not show the song in the band's key |
| Arrangement applied on the songs tab (chosen first, replaced by #227) | The band sees its own key when browsing songs | Confusing: the band's key appears everywhere in the song, as if the song were changed |

## Consequences

- ADR-0006 gets a new layer; set item transposition becomes relative to the band's
  key (unchanged for existing data). ADR-0013 and live mode use the band's key.
- New server collection with rules and migration (ADR-0015), new local table and
  sync part (ADR-0004), UI on the song screen and in live mode, texts in both ARB
  files (ADR-0008).
- The library can be kept clean: band-specific keys and sequences no longer tempt
  anyone to change the shared song.

## Decision log

- 2026-11-17: Proposed with issue #216, following ADR-0023 (band leaders and set
  planners maintain band arrangements).
- 2026-11-17: Owner answers: capo stays **personal**; the **songs tab applies** the
  arrangement of the band chosen on the sets tab, with a label; **no band notes**;
  the arrangement holds a **tempo per band**.
- 2026-11-17: Accepted by the owner.
- 2026-11-17: Implemented (#221). Server: collection `arrangements` (migration
  `1795400000_arrangements.js`, transposition −11…11, tempo 0…400 with 0 = as in
  the song; deterministic record ID per band and song), soft-deleted with its song.
  App: table `band_arrangements` (schema 12), `ArrangementRepository` (an arrangement
  without any change is removed), `ArrangementSync` (pull per band after the sets,
  push after the songs), applied in the set list, the printable/text set list, live
  mode (from a set: the set's band; a single song: the band chosen on the sets tab)
  and on the songs tab. The arrangement is edited on the song screen (card "Arrangement
  of <band>": key, sequence, tempo, back to the song); live mode shows it but does not
  edit it. The set list shows no tempo (it never did), so only key and sequence
  include the arrangement there.
- 2026-11-17: Owner decision (#227): the band's key, sequence and tempo are shown
  and valid **only in the band arrangement**. The song screen (songs tab) shows the
  song as written and the arrangement only in its card; a single song played live
  is played as written. Sets, the set list and live mode from a set still apply
  the arrangement of the set's band.
- 2026-11-17: Owner decision (#233): on the song screen the arrangement moves from
  the card above the song into a **side panel** (end drawer) behind a band icon in
  the app bar, with a dot while the band has an arrangement for the song. The
  song stays visible behind the panel, so changes show at once.

## Open points

- None.
