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
- 2026-11-21: Implementation split into #804 (data and sync), #805 (language),
  #806 (linking), #807 (switching set items), #808 (copying adjustments) and #809
  (archives).
- 2026-11-21: Data and sync implemented (#804): on the server `songs.work_id`,
  `songs.language` and the server-maintained `songs.content_revision` (the
  revision of the last change of anything else), which the conflict check uses;
  a change of only the link fields needs no base revision and keeps the last
  editor, so linking a band leader's own song leaves it theirs (ADR-0023). In
  the client the columns `songs.work_id` and `songs.language` (schema 31), each
  link field pushed on its own from the outbox (`song_links`), and
  `SongRepository.linkLanguageVersions`, `unlinkLanguageVersion`, `setLanguage`
  and `languageVersions`. A copy of a song (another band's library, keeping both
  versions of a conflict) is no version of the original's work.
- 2026-11-21: Language implemented (#805): `detectLanguage` (`app/lib/data/language_detection.dart`)
  counts function words of de, en, fr, it, es, pt and nl and returns a language only
  with at least 5 hits, 12 % of the words and 1.5 times the hits of the second; the
  result is `songs.detected_language` (schema 32, derived, not synced). The song menu
  has *Language …* (automatic or a language by hand) for whoever may edit the song.
  Refinement: the song list shows the language tags and the language filter only
  when the library has songs in more than one language, so a library in one
  language stays as quiet as before. *Other* has no tag.
- 2026-11-21: Linking implemented (#806): *Link language version …* and *Remove from
  the language versions* (with Undo) in the song menu for whoever may edit the
  song; the picker offers the songs of the library the person may edit, outside
  the group, the most alike first (same artist, key, tempo, sequence). Linking only
  moves songs the person may edit: if the smaller group holds another's song, the
  other group moves instead, and when neither can move nothing is linked and the
  app says so. The song view shows the versions as chips below its header (UI
  language first, then by language code; named by language, by title while the
  language is unknown or shared); the song list marks songs with other versions
  with a translate icon.
- 2026-11-21: Switching set items implemented (#807), resolving the open point on
  the set item's own sequence: it stays when every part it names exists in the new
  version (`sequenceFits`), otherwise it is removed and the app says so. *Switch
  language version …* in the set item's menu lists the other versions with the key
  they would have in the set; after the switch the new version's band arrangement
  applies, the set item's transposition stays, and a different resulting key is
  named in the message.
- 2026-11-22: Offer to copy adjustments implemented (#808): a card below the
  version chips when the person's adjustments of the song are not musical while
  another version's are (transposition, capo, keyboard programs, click grouping and
  subdivisions); *Use them* copies only those (with Undo; a choice of the version
  when several have some), notes, font size, display and annotations stay. *No
  thanks* hides the offer for that song on this device (device setting
  `adjustmentOfferDismissed`, never synced).
- 2026-11-22: Archives implemented (#809): song, set and backup archives write
  `workId` and `language` per song (`BackupService.languageJson`); the import sets
  the language on new songs and links the new songs that shared a `workId` under a
  new group, never with songs already in the library (a reused identical song keeps
  its own group). Older archives import as before. The format reference
  (`docs/formats/song-archive.md`) and its example describe the fields. With this,
  ADR-0053 is implemented.
- 2026-11-22: The language filter offers *No language* (#834) below *All
  languages* and above a divider and the languages: the songs whose language is
  neither set by hand nor detected, to find the ones to set by hand.
- 2026-11-22: The dialog that sets a song's language shows a small flag in front of
  every language (#845), so the wanted one is found faster: de Germany, gsw
  Switzerland, en the Union Jack, fr, it, es, pt and nl their countries; *Other* a
  neutral language icon, *Automatic* the flag of the detected language. The flags
  are simplified SVGs drawn for the project and bundled in the app (Windows has no
  flag emoji). They appear only in this dialog: the tags in the song list and the
  song view stay text codes, because a language is not a country.
- 2026-11-22: Like the languages, *No language* is offered only when the library
  has songs without a language, or while it is selected (#843).

## Open points

- Switching the language of a whole set at once (e.g. "all songs in English").
- Showing two versions side by side or line by line for songs sung in both languages.
