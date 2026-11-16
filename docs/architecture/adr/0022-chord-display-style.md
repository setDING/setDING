# ADR-0022: Selectable chord display style

- **Status:** Proposed
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
   `dim`/`°`, `aug`/`+`, `m7b5`/`ø`. A suffix the parser does not fully understand is
   kept **as written** and shown unchanged in every style (no chord is ever displayed
   wrongly or dropped). `isMinor` and the Nashville conversion use the parsed quality.
2. **Global device setting "chord style"** with the values:
   - *As written* (default): today's behaviour, the suffix exactly as in the source.
   - *Standard*: `Cm7`, `Cmaj7`, `Cdim`, `Caug`, `Cm7b5`, `Csus4`, `Cadd9`.
   - *Jazz*: `C−7`, `CΔ7`, `C°`, `C+`, `Cø`, `Csus4`, `Cadd9`.
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

## Open points

- Exact symbol set for *Jazz* (e.g. `−` vs `-` for minor, `Δ` vs `Δ7` for major
  seventh) and whether ♭/♯ symbols replace `b`/`#` in alterations.
- Whether the printable set list (ADR-0013), which shows keys, follows the style.
