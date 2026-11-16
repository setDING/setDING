# ADR-0003: ChordPro as source format, parsing in the client

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Songs are to be stored as ChordPro. The question is whether ChordPro is only an
import/export format (with a separate structured model internally) or the actual
source of truth. In addition, the chord display must suit German-speaking musicians
(H/B notation) and support the Nashville number system.

## Decision

### Source format

- **The ChordPro text is the single source of truth** for a song. It is stored and
  synced unchanged.
- Metadata (`{title}`, `{artist}`, `{key}`, `{tempo}`, `{capo}`, …) is extracted on
  save and stored in the DB **redundantly only** for search and sorting.
- **Parsing, transposition and rendering happen in the client** (own Dart package
  `chordpro`). The backend knows nothing about ChordPro and only stores text.
- Initially a **defined subset of ChordPro 6** is supported:
  - Meta directives: `title`, `subtitle`, `artist`, `key`, `tempo`, `time`, `capo`, `duration`
  - Environments: `start_of_verse`/`sov`, `start_of_chorus`/`soc`, `start_of_bridge`, `start_of_tab`/`sot`, `start_of_grid`
  - `chorus` (chorus recall), `comment`/`c`, `comment_italic`, `comment_box`
  - Inline chords `[Am]`, section labels
  - Unknown directives are **ignored but preserved** (no data loss).

### Chord notation

- ChordPro files are **always stored in international notation** (`B`, `Bb`).
- The **display notation is a device setting** (layer 4 in ADR-0006):
  - *International* (default): `B`, `Bb`
  - *German*: `H` for B, `B` for B♭
- This setting is **independent of the UI language** (ADR-0008).
- **Import:** When importing files written in German notation, the user can choose
  "file uses German notation (H/B)"; the importer converts the chords to international
  notation before saving. Without that option, `H` is accepted and interpreted as B.

### Nashville number system

- The renderer can display chords as **Nashville numbers** (scale degrees relative to
  the song's key, e.g. `1`, `4`, `5`, `6m`, `1/3`).
- It is a **display setting** (per device, optionally per song in the personal overlay).
- The key is taken from `{key}` (after set and personal transposition). If a song has
  no `{key}`, the setting has no effect and normal chord names are shown, with a hint.

### Not in scope

- **Chord diagrams** (guitar/ukulele fingerings, `{define}`) are not displayed.
  `{define}` directives are preserved in the source.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **ChordPro as source** (chosen) | Open, compatible with SongBook Pro, OnSong, ChordPro CLI; lossless import/export; easy to diff and version | Parser must handle malformed files robustly |
| Own JSON model, ChordPro only for import/export | Structured editing is easier | Round-trip losses, own lock-in |
| Parsing in the backend, client receives pre-rendered data | Less client logic | Contradicts offline-first, transposition would need the server |

Notation alternatives:

| Option | Pros | Cons |
|---|---|---|
| **Display setting B/H, storage international** (chosen) | Everyone sees their familiar notation, files stay compatible with other apps | Conversion on import of German-notation files |
| International only | Simplest | Unfamiliar for some German-speaking musicians |
| German only | Familiar for German speakers | Confusing for English-speaking users, incompatible files |

## Consequences

- High testing effort for the parser (unit tests with real ChordPro files as fixtures).
- Transposition and Nashville conversion share a chord model (root, quality, extensions, bass note) in the `chordpro` package; notation (international/German) is applied only at render time.
- Section labels without an explicit label (e.g. a plain `{start_of_chorus}`) are rendered with a localized default label ("Chorus" / "Refrain", see ADR-0008).
- The editor in the app is a text editor with live preview; a WYSIWYG editor is not needed. The editor shows chords in international notation, as stored.
- The `chordpro` package also provides **source positions** (`highlightChordPro`) for syntax highlighting in the editor. The tokenizer follows the parser's rules (directive names, selectors, sections), so editor and parser agree; it is tolerant of incomplete input while typing. Bracket matching (`matchBracket`) and autocompletion (`completeChordPro`) in the editor build on these tokens; the directive suggestions come from the parser's own name tables (`chordProDirectives`).
- The parser stays lenient and never rejects a song. Before saving, the editor warns about places where it probably does not do what the author meant (`validateChordPro`: unclosed `{` or `[`, a delegated environment that is never ended); the author can save anyway.

## Decision log

- 2026-11-14: ChordPro as single source of truth accepted.
- 2026-11-14: Display notation selectable (international B / German H), storage always international.
- 2026-11-14: Nashville number display is supported. Chord diagrams are not planned.
- 2026-11-14: Extended by ADR-0012: the whole ChordPro specification is supported, including chord diagrams (supersedes "chord diagrams are not displayed" and the subset listed above).
- 2026-11-16: The package also provides source positions for syntax highlighting in the editor (`highlightChordPro`, #35); the directive names are shared by parser and highlighter.
- 2026-11-16: The editor warns on save about unclosed brackets and environments (`validateChordPro`, #109); saving stays possible.
- 2026-11-16: The spelling of the chord suffix (standard, jazz, raised extensions) is a further display setting, see ADR-0022.

## Open points

- Should the ChordPro editor also offer input in German notation (converted on save)?
