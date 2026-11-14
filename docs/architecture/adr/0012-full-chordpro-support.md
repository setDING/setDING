# ADR-0012: Full ChordPro specification support

- **Status:** Accepted
- **Date:** 2026-11-14
- **Extends:** ADR-0003 (ChordPro as source format)

## Context

ADR-0003 defined a subset of ChordPro 6. Songs from other tools (SongSelect, OnSong,
SongBook Pro, the ChordPro reference implementation) use much more of the
[specification](https://www.chordpro.org/chordpro/chordpro-directives/), e.g. `{transpose}`,
grids, conditional directives, markup, chord diagrams and delegated environments. The
whole specification must be supported.

The specification states that directives are "a friendly request" to the formatter: the
semantics are defined, the appearance is up to the program. BandChords is a screen-based
live app, not a PDF formatter, so page-oriented directives are mapped to the screen
layout (ADR-0007) where this makes sense.

## Decision

All directives of the specification are **parsed**; each one is **rendered or applied**
as listed below. The ChordPro source stays the single source of truth (ADR-0003).

### Coverage

| Area | Directives / features | Support in BandChords |
|---|---|---|
| Syntax | `name: value`, `name value`, attributes `key="v"`/`key='v'`, labels with `\n`, `#` remarks, `x_…` custom directives | Full; `x_` directives are ignored silently |
| Preamble | `new_song` / `ns` | A file with several songs is imported as several songs |
| Meta-data | `title`, `sorttitle`, `subtitle`, `artist`, `sortartist`, `composer`, `lyricist`, `arranger`, `copyright`, `album`, `year`, `key`, `time`, `tempo`, `duration`, `capo`, `tag`, `meta` (any name, multiple values) | Full; `sorttitle`/`sortartist` for sorting, `tag` for search and filter |
| Metadata in texts | `%{name}`, `%{name\|true\|false}`, `%{name=value\|…}`, `%{}`, `.1`/`.-1`, escapes; `key_actual`, `key_from`, `_key`, `instrument`, `user`, `today` | Full in comments, labels and titles |
| Formatting | `comment`/`c`, `highlight`, `comment_italic`/`ci`, `comment_box`/`cb` | Full |
| Markup | Pango subset: `<span …>` (font, size, style, weight, colours, underline, overline, strikethrough, rise), `<b> <i> <u> <s> <sub> <sup> <big> <small> <tt>`, `<strut/>` | Full in lyrics, chords, comments and labels; `href`/bookmarks are ignored |
| Environments | `chorus`, `verse`, `bridge`, `tab`, `grid`, any `start_of_xxx`, `{chorus}` recall | Full; unknown environments are shown as lyrics |
| Grids | `shape`, cells, bar lines (`\|`, `\|\|`, `\|.`, `\|:`, `:\|`, `:\|:`, voltas), `.` `/` `~` `%` `%%`, margins, strums | Full, chords transposed |
| Delegated | `abc`, `ly`, `svg`, `textblock` | SVG and textblock rendered; ABC rendered as notation by BandChords' own engraver (single voice, transposable); Lilypond shown as source with a notice (needs an external program that is not available on tablets) |
| Images | `image` with `src`, `width`, `height`, `scale`, `align`, … | Images are **attachments** of the song (like PDFs, ADR-0009), found by file name |
| Chord diagrams | `define`, `chord`, `diagrams` | Diagrams for the instrument chosen in the settings; built-in chord library plus `define`/`chord` |
| Transposition | `transpose` (`+n`, `-n`, `s`/`f` suffix, cancel, modulation mid-song) | Full; combined with set and personal transposition (ADR-0006) |
| Key and capo | multiple `key` (modulation), `capo` | Nashville numbers follow the current key; a song `capo` means chords are shapes, the sounding key is key + capo |
| Chords | Strict and relaxed parsing, `[*annotation]`, Dutch/German note names (`Bes`, `Fis`, `H`), Roman and Nashville chords in the source | Full; Roman/Nashville chords are not transposed |
| Fonts, sizes, colours | `textfont/size/colour`, `chord…`, `chorus…`, `label…`, `tab…`, `grid…`, `title…`, `footer…`, `toc…` | Applied to the following lines; font families mapped to `serif`/`sans`/`monospace`; sizes relative to the live font size |
| Output | `columns`, `column_break` | `columns` limits the live columns; `column_break` forces a new column |
| Output (page) | `new_page`, `new_physical_page`, `pagetype`, `titles`, `grid`/`no_grid` | Parsed; `new_page`/`new_physical_page` act like `column_break`; the others have no effect on screen |
| Conditional | `directive-selector`, `-selector!` | Selected by **instrument** and **user name** from the settings, then by metadata |

### New settings

- **Instrument** (guitar, ukulele, bass, keyboard, vocals, or free text) and **user name**,
  used for conditional directives and chord diagrams.

### Phases

1. Parser core: generic directives and attributes, conditionals, `new_song`, metadata
   (multiple values, substitution), `transpose`, key changes, capo, chord parsing.
2. Rendering: markup, fonts/sizes/colours, grids, labels, `columns`/`column_break`.
3. Settings (instrument, user name), import of multi-song files, tags and sort fields.
4. Chord diagrams with built-in library (guitar, ukulele).
5. Images as attachments, SVG, textblock, ABC.

Each phase is a separate branch and merge (ADR-0010).

## Consequences

- The `chordpro` package grows considerably; its tests use own example files per area.
- The layout measurement for live mode (ADR-0007) must cover the new elements (grids,
  images, diagrams, markup sizes).
- ADR-0003's "chord diagrams are not displayed" is superseded by this ADR.
- Attachments (ADR-0009) are extended from PDFs to images.

## Decision log

- 2026-11-14: Full ChordPro support required. Chord diagrams with built-in library and
  `define`; SVG and textblock rendered, ABC as notation, Lilypond as source; images as
  attachments; new settings for instrument and user name.
- 2026-11-14: Phase 1 (parser core) done.
- 2026-11-14: Phase 2 (rendering) done: markup in lyrics, chords, comments and labels;
  font/size/colour directives (absolute sizes relative to 12 pt); grids laid out in cells
  (cell width from the widest single chord, several chords per cell may spill into the
  next cell); `{columns}` fixes the live column count when the column setting is
  automatic; `{column_break}`/`{new_page}` start a new column when more than one column
  is shown. Layout measurement covers all of these.
- 2026-11-14: Phase 3 done: settings for instrument (presets guitar, ukulele, bass,
  keyboard, vocals, or free text) and user name drive conditional directives; files with
  `{new_song}` are imported as separate songs; `{sorttitle}` sorts the library and `{tag}`
  values can be filtered (case-insensitive). Database schema 2 stores sort fields and
  tags and a personal capo that can be "as in the song".
- 2026-11-14: Phase 4 done. The open point on the chord library is decided: fingerings
  are **generated** from the chord tones (no external chord data, no licence question).
  The generator searches playable fingerings within 12 frets (all required tones, lowest
  note = root or slash bass on guitar and bass, low positions, open strings, at most four
  fingers incl. barre); the ukulele (re-entrant tuning) allows inversions; keyboard
  diagrams highlight the chord tones. `{define}`/`{chord}` shapes are used when the chord
  is shown as written (also `copy`, `display`, `diagram off`); transposed chords get
  generated fingerings. A new setting shows the diagrams of all chords at the top or the
  bottom (default off); the song's `{diagrams}` wins.
- 2026-11-14: Phase 5a done: images (PNG, JPG, GIF, WebP, SVG) can be attached to a song
  and are found by `{image}` via their file name; images in an imported ZIP are attached
  automatically when a song refers to them. Image sizes are read from the file headers
  (1 font unit = 20 px, 12 pt; `width`/`height` in points or percent, `scale`, `align`)
  and images shrink to the column width. `{start_of_svg}` and `{start_of_textblock}`
  (`flush`, `align`, `textsize`, `padding`) are rendered; Lilypond is shown as source with
  a notice. ABC follows in phase 5b.
- 2026-11-14: Phase 5b done. The open point on ABC is decided: no external library (none
  works offline on all platforms without a web view); BandChords has its own ABC parser
  (`chordpro` package) and engraver: header fields, keys and modes, notes with
  accidentals (shown according to key signature and measure), durations, broken rhythm,
  tuplets, ties, chords, rests, bar lines, repeats, voltas, chord symbols, annotations,
  inline key/meter changes and `w:` lyrics, single voice. Lines break at bar lines to fit
  the column; the tune follows the set and personal transposition. Multiple voices,
  slurs and decorations are not drawn. All phases of this ADR are done.

## Open points

- ABC: multiple voices (`V:`), slurs and decorations are not drawn yet.
- 2026-11-15: BandChords extension `{sequence: C, V1, PC, C x2, B}` (also written
  `{x_sequence}` for portability) holds the song sequence (arrangement). It is metadata
  (`%{sequence}` works) and is shown as small chips below the subtitle in the song view,
  the editor preview and live mode, with the full part name as tooltip. Recognised
  abbreviations (case-insensitive, English and German): I/Intro, V/Vs/S/Str/Verse/Strophe,
  PC/Pre/PR/Pre-chorus, C/Ch/R/Ref/Chorus/Refrain, PoC/Post-chorus, B/Br/Bridge,
  Int/Zw/Interlude, Inst/Instrumental, Solo, T/Tag, O/Out/End/Outro; optional number
  (`V2`) and repeat (`C x2`, `2x C`, `C (2x)`); unknown codes are shown as written. Other
  ChordPro tools treat `{sequence}` as an unknown directive.
