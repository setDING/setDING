# ADR-0025: Band arrangements between song and personal overlay

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

Songs belong to the organization and are shared by all its bands (ADR-0017). Since
ADR-0023, band leaders no longer edit songs of others: the library is maintained by
librarians and organization admins. Bands still need to adapt songs for themselves:

- a choir sings a song in A, the youth band in C;
- one band plays verse–chorus–verse–chorus, another adds a bridge and an outro;
- band notes such as "intro: piano alone" or "last chorus twice, slower".

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
2. **Band arrangement** *(new)*, per band and song: the band's key, sequence and notes.
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
| `notes` | Text for all band members, shown above the song | null |

The key is stored as a transposition relative to the song (like set items), so it
stays correct when the library fixes the song but not its key. The app shows it as
the resulting key ("C (+3)").

Capo, font size and Nashville stay **personal** (layer 4): they depend on the
instrument and the person, not the band.

### How it combines

- **Transposition:** song + arrangement + set item + personal overlay. A set item's
  transposition becomes relative to the band's key: "−2 tonight" means two semitones
  below the band's key. Existing set items keep their value: without arrangements
  the band's key is the song's key, so nothing changes for existing sets.
- **Sequence:** the first that is set wins: set item, arrangement, song.
- **Notes:** the band's notes and the personal notes are shown separately (band
  notes first, labelled with the band).
- **Where it applies:**
  - in a set and in live mode started from a set: the arrangement of the set's band;
  - on the songs tab: the arrangement of the band chosen on the sets tab, if it
    plays from this library. Without one (local library, an organization without
    that band), the song is shown as written. A label shows which band's arrangement
    is applied.
- **Printable set list and set export** (ADR-0013): the key and sequence for the
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
  `notes`, sync fields; unique per band and song; the song must belong to the band's
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
  "Band arrangement" section (key, sequence, notes); members see it read-only.
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

## Open points

- Should the arrangement also hold a capo for the band (e.g. "guitars capo 2"), or
  does capo stay personal?
- Should the songs tab apply the arrangement of the band chosen on the sets tab, or
  always show the song as written (arrangements only in sets and live mode)?
- Should band notes be anchored to a line or section (like personal notes, ADR-0006),
  or is one note per song enough for now?
- Tempo per band (e.g. the youth band plays faster): part of the arrangement, or not
  needed?
