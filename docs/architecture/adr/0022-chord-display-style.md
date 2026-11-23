# ADR-0022: Selectable chord display style

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

A chord name consists of several parts:

| Part | Examples |
|---|---|
| **Root** | `C`, `F#`, `Bb` |
| **Quality** | major, minor, diminished, augmented, half-diminished, suspended |
| **Extension** | `6`, `7`, `maj7`, `9`, `11`, `13` |
| **Alterations / additions** (modifiers) | `b5`, `#9`, `add9`, `(#11)` |
| **Bass** | `/E` |

Musicians are used to different ways of writing the same chord. Pop and worship charts
write `Cm7`, `Cmaj7`, `Cdim`, `Cm7b5`; jazz charts and Real Books write `C−7`, `CΔ7`,
`C°`, `Cø` and often set the extension and alterations smaller and raised
(superscript). Songs from different sources (SongSelect, own transcriptions, other
apps) mix these spellings, so a set can show `Am7`, `Ami7` and `A-7` for the same chord.

Today the `chordpro` package parses a chord only into root, suffix and bass
(`Chord` in `packages/chordpro/lib/src/chord.dart`). The suffix is an opaque string and
is shown as written. `ChordFormatter.format` returns a plain `String`, so a raised
extension cannot be expressed. `Chord.isMinor` only looks at the first characters of
the suffix.

ADR-0003 already makes the B/H notation and Nashville numbers **display settings**
while the ChordPro source stays unchanged. The chord style fits the same pattern.

## Decision

1. **Structured chord suffix.** The `chordpro` package parses the suffix into
   *quality*, *extension*, *alterations/additions* (in their written order) and keeps
   the *bass* note. Input variants are normalised, e.g. `m7`, `min7`, `mi7`, `-7` and
   `−7` are all a minor seventh; `maj7`, `Maj7`, `M7`, `Δ7`, `^7` are a major seventh;
   `dim`/`°`/`0`, `aug`/`+`, `m7b5`/`ø`/`h7`; `m9maj7` is `m(maj9)`. The parser
   understands every suffix of the list in the ChordPro reference implementation
   ([chordpro-chords](https://www.chordpro.org/chordpro/chordpro-chords/)) except a
   bare `3` and `h` (so lyrics like `Ah` stay words). A suffix the parser does not fully understand is
   kept **as written** and shown unchanged in every style (no chord is ever displayed
   wrongly or dropped). `isMinor` and the Nashville conversion use the parsed quality.
2. **Global device setting "chord style"** with the values:
   - *As written* (default): today's behaviour, the suffix exactly as in the source.
   - *Standard*: `Cm7`, `Cmaj7`, `Cdim`, `Caug`, `Cm7b5`, `Csus4`, `Cadd9`.
   - *Jazz*: `C−7`, `CΔ7`, `C°`, `C+`, `Cø7`, `Csus4`, `Cadd9`; minor is
     the minus sign `−` (U+2212), a major seventh is always written with its
     number (`Δ7`, `Δ9`), half-diminished as `ø7`, and alterations use `♭`/`♯`
     (`C7♭9♯11`).
3. **Separate global switch "superscript"**: extension and alterations are rendered
   smaller and raised. It applies to *Standard* and *Jazz*; *As written* ignores it.
4. **Orthogonal to the other display settings.** Style and superscript combine with
   the B/H notation, Nashville numbers (e.g. `6−7`, `2ø`), transposition and capo.
   Notation and style are applied only at render time.
5. **Device setting only.** The style is a reading habit of the musician, not a
   property of the song: there is no per-song value in the ChordPro source or in the
   personal overlay (ADR-0006), and no quick toggle in the live control bar. It lives
   in the settings next to the notation and Nashville settings.
6. **Structured formatter output.** `ChordFormatter` returns the chord as a list of
   parts, each with a role (normal or raised). The renderer builds text spans from it
   and measures the width of chords from the spans, so chords above the lyrics, chord
   grids and chord diagram names stay aligned. A plain-text variant remains for places
   that only need text.
7. **The ChordPro source is never changed** (ADR-0003). The editor keeps showing the
   chords as stored.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Device setting with structured suffix** (chosen) | Every musician reads their familiar spelling; mixed sources look consistent; source stays untouched | Suffix parser needed; formatter API and renderer change |
| Show the suffix as written only (status quo) | No work, no risk of misreading | Inconsistent spellings within a set; no jazz notation |
| Normalise the ChordPro source on import/save | Simple rendering | Changes the shared song, against ADR-0003; one spelling forced on the whole band |
| Per-song or per-overlay style | Fine-grained | The style is a reading habit, not a song property; more settings to sync |
| Style via ChordPro `{define}` / config `display` formats | Standard-adjacent | Per song and author-controlled, not per musician; complex |
| Quick toggle in the live control bar | Fast switching | Rarely changed; clutters the control bar |

## Consequences

- The `chordpro` package gets a suffix parser with extensive unit tests (spelling
  variants, unknown suffixes, parentheses, slash chords, Nashville).
- `ChordFormatter.format` changes from `String` to structured parts; call sites in
  `app/lib/ui/render/` (`song_style.dart`, `song_grid.dart`, `chord_diagram.dart`)
  are adapted, and width measurement uses the spans.
- Superscript makes chords narrower but harder to read from a distance; it is
  therefore optional and off by default.
- Two new settings with UI texts in `app_de.arb` and `app_en.arb` (ADR-0008).
- `docs/examples/feature-showcase.cho` and its tests get chord spelling variants.
- Nashville numbers become more robust because minor is read from the parsed quality.

## Decision log

- 2026-11-16: Proposed (#196). Owner preferences from the discussion: styles
  *As written* (default), *Standard* and *Jazz*, superscript as a separate switch,
  global device setting only, not set per song.

- 2026-11-16: Accepted by the owner (#196).
- 2026-11-16: Jazz symbols decided: `−` for minor, `Δ7` (always with the
  number), `ø7`, `°`, `+`, `♭`/`♯` in alterations. Raised parts are 70 % of
  the chord size, lifted by 35 %. Jazz spellings in the source (`CΔ7`, `C−7`,
  `CØ7`) are recognised as chords.
- 2026-11-16: The printable set list (ADR-0013) and other key displays show
  only keys (root and minor), so the style does not apply to them.
- 2026-11-16: Implemented (#196): `ChordSuffix`, `ChordStyle` and
  `ChordPart` in the `chordpro` package, `ChordText` in the renderer, settings
  in the display category.

- 2026-11-21: The suffix parser covers the extension list of the ChordPro
  reference implementation: a major seventh after the extension (`m9maj7`,
  `m9^7`), a second number as an added tone (`711` is `7add11`), `+` after a
  number (`7+` is `7#5`), `m#7`, `sus9`, `add3`/`no3`, `0` (diminished) and
  `h7`/`h9` (half-diminished). The chord tones for diagrams follow.

- 2026-11-22: Roman numerals (ADR-0055) use a fixed jazz spelling and do not
  follow the chord style; the superscript switch applies to them, the B/H
  notation does not.

- 2026-11-23: ADR-0059 (proposed, #971): in the numeral spelling *Chord
  symbol* the suffix behind the numeral follows the chord style, as for
  Nashville numbers.

## Open points

- None.
