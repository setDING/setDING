# ADR-0046: Song play history per band

- **Status:** Proposed
- **Date:** 2026-11-20

## Context

Bands keep asking how they played a song the last time: in which key, at which
tempo, with which sequence. The answer is spread over past sets today, and it is
not reliable there either:

- A set item's transposition is relative to the band's key (ADR-0025), and the
  band's key is relative to the song's key. When the band arrangement or the
  song's `{key}` changes later, a past set shows the new key, not the one played.
  The same holds for tempo and sequence, which come from the arrangement unless
  the set item overrides the sequence.
- Sets of a band are visible to the band only (ADR-0017, ADR-0023); the song
  library belongs to the organization, so "who else plays this song" cannot be
  answered on the device.
- Everything that is shown on stage must work offline (ADR-0001); ChordPro is
  parsed only in the client, so the server cannot resolve a key (ADR-0003).

Owner decisions for the scope (#659): a song in a past set counts as played; the
number of gigs and venues are not needed.

## Decision

### What counts as a play

A **play** is a song item in a non-deleted set of a band whose `gig_date` is
**before today** (a gig today is still upcoming, as in the sets tab). A song that
appears twice in one set counts once. Sets without a gig date do not count. There
is no marking of skipped songs.

### Frozen values in the set item

Each song item of a set gets the resolved values it was played with, stored in
the item JSON of `setlists.items` (ADR-0015) and in local columns:

```json
{"id": "…", "type": "song", "song": "…", "transpose": -2,
 "played": {"key": "D", "tempo": 96, "sequence": "I V C V C B C C O"}}
```

- `key` is the sounding key after song, arrangement and set item (personal
  overlays and capo are not part of it), written as a ChordPro key; `tempo` and
  `sequence` are the resolved values; each is omitted when unknown.
- **When:** the values are written once, when the set's gig date is reached
  (`gig_date <= today`), by the first client of a person who may edit the band's
  sets (band leader or set planner, ADR-0023) that runs a sync on or after that
  day. Before that day nothing is stored and the history derives nothing from the
  set, because it is not a play yet.
- **Frozen:** once written, clients never rewrite `played` of a set whose gig
  date has passed, also when the arrangement or the song changes later. Editing
  such a set by hand (e.g. fixing the key afterwards) updates `played` of the
  edited item only.
- **Fallback:** a past set without `played` (older sets, or nobody with set
  rights synced in time) is derived from today's song and arrangement and shown
  as approximate ("≈ D").
- **Older clients** drop unknown item fields when they save a set. The release
  that introduces `played` raises `MIN_CLIENT_VERSION` (ADR-0029); from then on
  `RemoteSetItem` keeps unknown fields so later additions do not need this again.
- The server checks nothing new: `played` is part of the set and covered by the
  existing set write rules.

### Steps

1. **v1 – song and set editor** (#660), local only:
   - Card *Played* in the song view with the band choice of the arrangement
     panel: plays in total and in the last 12 months, last and first play, the
     latest plays with date, set name, key, tempo and sequence, *Show all*; a key
     that differs from today's band key is highlighted.
   - Set editor: the key picker shows "Last D on 12.10.2026 · mostly D (12 of
     14)"; the song picker shows when each song was last played ("never").
2. **v2 – band repertoire** (#661), local only: most played songs, songs not
   played for a while and never played songs of the organization's library, for
   12 months or all; the song list gets the sort *Last played* and the filters
   *Never played* and *Not played for a while*.
3. **v3 – organization** (#662): a custom server route returns, per song, the
   bands of the organization that played it with last date, key and count;
   never set names or set contents. The song card shows *Other bands*; organization
   admins and librarians get *Library usage* (songs no band plays, linked to the
   trash of ADR-0043). Permissions are enforced and tested on the server and added
   to the matrix of ADR-0023.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Derive everything from today's arrangement (no stored values) | No data change | Wrong exactly when the key changed, which is when the question comes up |
| Store `played` whenever a set is saved | Simple | Stale when the arrangement changes between planning and gig |
| Store on save and rewrite upcoming sets on every arrangement change | Always current before the gig | Many automatic set writes, conflicts with people editing the set |
| Freeze on the gig day (chosen) | One write per set, values of the evening | Stale if the arrangement changed after the gig but before anyone with set rights synced |
| Snapshot in a separate `plays` collection | Independent of sets, easy to query on the server | New collection, sync and rules for data the set already has |
| Count plays from live mode | Only songs really played | Each member navigates independently (ADR-0007): counts per device, not per band; privacy |
| Server computes the history | Also for v3 | The server cannot resolve keys (ADR-0003), and v1/v2 must work offline |

## Consequences

- The question "how did we play it last time" is answered offline, on the song
  and in the set editor, with the values of the evening.
- `setlists.items` grows by a few bytes per song item; the local schema gets new
  columns and a migration.
- The minimum client version is raised once.
- v3 adds the first aggregated read across bands; it needs its own permission
  tests and possibly a change of ADR-0023's matrix.
- Backups (ADR-0043) carry `played` with the set items.

## Decision log

- 2026-11-20: Proposed (#659); a song in a past set counts as played, no gig
  counts or venues (owner).

## Open points

- v2: where the repertoire view lives (the band under *Organization & bands* or
  the *Sets* tab).
- v2: threshold for "not played for a while": fixed 6 months or configurable per
  band.
- v3: who may see other bands' plays: all organization members, or band leaders
  and organization admins only.
- v3: offline behaviour: cache the aggregate at sync or show it online only.
