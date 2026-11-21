# ADR-0053: Language versions of a song

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

Many songs exist in several languages: an English worship song and its German
translation, a German song and a free Swiss German adaptation. In the library they
are separate songs with their own ChordPro text (ADR-0003), and nothing shows that
they belong together. Users want to see that a song has other language versions and
switch between them, for example when the audience of a gig speaks another language.

The relation is not part of the song text: it links songs, like band arrangements
(ADR-0025) or personal overlays (ADR-0006) add data next to the text. It must work
offline (ADR-0001), sync with the library (ADR-0004), and be enforced on the server
like every permission (ADR-0023, owner rule #632).

## Decision

### What a language version is

Songs that are the **same work in another language**: translations and free
adaptations (e.g. a Swiss German version with another number of verses). Other
variants of a song (acoustic, short or live versions) are **not** language versions
and are not linked this way.

All versions of a work are **equal**. There is no "original": it would need a
place to store it, rules for when it is deleted, and conflict handling when two
devices choose different originals offline, for little benefit (owner).

### Data: a group ID on the song

| Field | Meaning | Default |
|---|---|---|
| `songs.work_id` | Shared ID (UUID) of all language versions of a work | null = no other versions |
| `songs.language` | Language set by hand | null = use the detected language |

- **Linking** gives the songs the same `work_id`: a new UUID when neither has one,
  otherwise the ID of the existing group. Linking two groups rewrites the IDs of the
  smaller group. **Unlinking** clears the field of one song.
- A `work_id` that only one song (not in the trash) carries is harmless: the app
  shows no other versions and nothing is cleaned up.
- Groups exist **within one organization** (ADR-0017): the app only groups songs of
  the same library; the server refuses a `work_id` that a song of another
  organization already uses.
- There is **no new collection**: the fields are synced with the song record. A
  collection for the work (`song_works`) can be added later, if a work ever needs
  data of its own (composer, original title), by turning the existing group IDs
  into its IDs without losing anything.
- Changing only `work_id` or `language` never opens the conflict dialog of the
  ChordPro text (ADR-0004): these fields are taken last writer wins per field.

### Language

- **Languages:** German (`de`), Swiss German (`gsw`), English (`en`), French (`fr`),
  Italian (`it`), Spanish (`es`), Portuguese (`pt`), Dutch (`nl`) and *Other*
  (`other`). The list is fixed in the client and easy to extend.
- **Detection** on the device, without a library: for every language except Swiss
  German and *Other* a short list of frequent function words ("und, der, ich, nicht",
  "the, and, you, my", "le, et, je, pas", …) is counted in the lyrics without chords
  (`songs.search_text`). The language with the most hits wins if it is clearly ahead
  of the second; otherwise **no language** is detected rather than a wrong one.
  Swiss German mostly shows as German and is set by hand.
- The detected language is **derived on the device and not synced** (like
  `songs.chordpro_problems`); it is computed again when the text changes.
- **By hand:** whoever may edit the song sets the language (`songs.language`, synced);
  a language set by hand always wins and is never replaced by the detection.
- The language is useful without links too: the song list filters by language.

### In the app

- **Song list:** every version stays its own row, with a small language tag (`DE`,
  `EN`, …) and a hint that other versions exist; a filter chip by language. Versions
  are not merged into one row.
- **Song view:** the language tags of all versions of the work in the header; a tap
  opens that version. The tags have a fixed order (the language of the UI first,
  then the others alphabetically by code).
- **Linking:** *Link language version…* in the song menu opens a song picker of the
  library; songs with the same artist, key, tempo or sequence are listed first.
  *Unlink* removes the song from its group. There is **no suggestion on import**:
  CCLI numbers of translations differ and titles carry no common marker (owner).
- **Search:** unchanged; every version is found by its own text.

### Sets

- A set item still points to **one concrete song**. Set planners can **switch** a set
  item to another language version of its song (in the set editor and in the set
  item's menu).
- After the switch the **band arrangement of the new version** applies (ADR-0025);
  the set item's transposition stays (it is relative to the band's key). If the
  resulting key differs from before, the app says so ("EN version: G instead of A").
- Played songs (ADR-0046) are counted per version, like any song.

### Personal adjustments

Overlays (ADR-0006, ADR-0020), annotations (ADR-0032) and keyboard programs
(ADR-0039, ADR-0042) stay **per version**. When a person opens a version without
adjustments while another version of the work has some, the app **offers to copy**
the musical ones (transposition, capo, keyboard programs, click) from it. Nothing is
copied without that tap.

### Permissions (ADR-0023)

| Action | Who |
|---|---|
| See language versions and the language | everyone who sees the song |
| Link, unlink, set the language | whoever may edit the song (librarians and organization admins; creators of their own songs as ADR-0023 allows) |
| Switch a set item to another version | whoever may edit the set (band leaders, set planners, organization admins) |

The server enforces this with the existing update rule of `songs`, and its tests call
the API directly as the refused roles (permission matrix test).

### Trash and archives (ADR-0043)

- A song in the trash **keeps its `work_id`**; restored, it is linked again. While it
  is in the trash it is not shown as a version. Purging removes the song with it.
- **Song archive** and **backup archive** store the `work_id` per song. Import (always
  as a copy with new IDs) links the songs that belong together **within the archive**
  under a new group ID; it never links them to songs already in the library.
  Exporting a song exports only what was selected, not its other versions.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Group ID on the song** (chosen) | No new collection; sync, rights, trash and archive follow the song; can grow into a work collection later | The group has no data of its own |
| Own collection `song_works` | Room for data per work (original, composer); one place for an original | New collection, rules, tests and sync for an ID without data now that there is no original (owner) |
| Pairwise links (`song_links`) | Also other relations (acoustic, medley) | Several links per group, no clear group; only language versions are wanted |
| A marked original per work | "Translation of …", a default version | Trash and offline conflicts with two originals; too complicated (owner) |
| Language as `{x_language}` in the ChordPro text | Travels with the text; no new field | The owner wants it outside the text; detection would have to write into the text |
| Language only by hand | No detection to build | Every existing song needs a manual edit before the filter is useful |
| Language detection with a statistical library | More languages, more exact on short texts | New dependency with language profiles; Swiss German still not recognised |
| Platform language detection (ML Kit) | Very good | Not on Linux, Windows and web |
| Work in the set item, language chosen by the band or live | One set for every language | Big change of sets, arrangements and transposition (ADR-0025) |
| One row per work in the song list | Shorter list | Versions are harder to find and to sort; the owner prefers a row per version |
| Suggest links on import (same CCLI number, title marker) | Less manual work | CCLI numbers of translations differ, titles have no common marker (owner) |
| Shared personal adjustments for all versions | Set capo or the keyboard program once | Free adaptations may need other values; an offer to copy covers the common case |

## Consequences

- Server: two new fields on `songs` with a migration, validation (UUID, language
  codes, the group stays in one organization) and permission tests (ADR-0015).
- Client: new columns on the local `songs` table (synced `work_id`, `language`;
  derived `detected_language`), the word lists and their tests, the song list tags and
  filter, the song view tags, the link dialog, switching set items, the offer to copy
  adjustments; texts in both ARB files (ADR-0008).
- Song archive and backup archive formats get the group ID
  (`docs/formats/song-archive.md`); older apps ignore it.
- The website documents the feature with screenshots in both languages (ADR-0030).

## Decision log

- 2026-11-21: Proposed with issue #802 after a discussion with the owner: translations
  and free adaptations, no original, a group ID on the song, language detected from
  word lists and set by hand, switching set items with the new version's band
  arrangement, adjustments per version with an offer to copy, linking by hand only,
  the group kept in archives.
- 2026-11-21: Accepted by the owner (#803).

## Open points

- Does a set item's own sequence survive a switch? It names the sections of the old
  version, which a free adaptation may not have. Tendency: keep it when every section
  exists in the new version, otherwise clear it with a hint.
- Switching the language of a whole set at once (e.g. "all songs in English").
- Showing two versions side by side or line by line for songs sung in both languages.
