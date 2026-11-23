# ADR-0059: Spelling of Roman numerals

- **Status:** Accepted
- **Date:** 2026-11-23

## Context

ADR-0055 shows chords as Roman numerals in one fixed spelling: the **case** carries
the quality (upper case for major, dominant and augmented, lower case for minor,
diminished and half-diminished) and the minor `m` is not written (`ii7 – V7 – IΔ7`,
`vi`, `viiø7`).

A tester pointed out that this is correct, but that many players expect the other
common spelling and miss the `m`. There is no single official spelling; two
conventions are established, each consistent in itself:

| Convention | Minor chord | ii–V–I in C | Where |
|---|---|---|---|
| **Case** (ADR-0055) | `vi` | `ii7 – V7 – IΔ7` | Classical harmonic analysis (Kostka/Payne, Aldwell/Schachter), MuseScore, much of pop and jazz teaching ("two-five-one") |
| **Upper case with chord symbol** | `VIm` | `IIm7 – V7 – Imaj7` | Berklee harmony, Real Book analyses, German jazz theory (Sikora: `IIm7 – V7 – Ij7`) |

A mix of both (`iim7`, `vim`) marks minor twice and is not used in the literature.

The upper-case spelling has an advantage on stage: the numeral names only the
degree, and the suffix reads exactly like the chord name the musician already
knows. With the case spelling, `vii` is a diminished or half-diminished chord, not a
minor one, and only `°`/`ø` tell them apart.

ADR-0055 rejected "numerals follow the chord style (ADR-0022)" because it would
produce mixed spellings like `viim7b5`. That objection applies to the mix, not to
the upper-case convention, where the chord style fits naturally.

Nashville numbers (ADR-0003) already work this way: the degree replaces the root
and the suffix is spelled in the chosen chord style (`6m7`, `6−7`, ADR-0022
decision 4).

## Decision

1. **Two numeral spellings.** A new device setting *Numeral spelling* with:
   - *Case* (default): today's spelling of ADR-0055 (`ii7 – V7 – IΔ7`, `vi`,
     `viiø7`, `vii°7`).
   - *Chord symbol*: the numeral is always upper case and the full chord suffix
     follows it (`IIm7 – V7 – Imaj7`, `VIm`, `VIIm7♭5`, `VII°7`).

   UI names: *Gross-/Kleinschreibung* and *Akkordsymbol* (de-CH), *Case* and
   *Chord symbol* (en); the setting explains both with the ii–V–I example.
2. **Chord symbol follows the chord style.** In *Chord symbol*, the suffix is
   spelled exactly as the chord name would be in the active chord style
   (ADR-0022), like the Nashville numbers:
   - *As written*: the suffix as in the source (`IImi7` for `Dmi7`).
   - *Standard*: `IIm7`, `Imaj7`, `VIIm7b5`, `VIIdim`.
   - *Jazz*: `II−7`, `IΔ7`, `VIIø7`, `VII°`.

   The superscript switch applies as for chord names. *Case* keeps the fixed
   spelling of ADR-0055 decision 8 and ignores the chord style.
3. **Everything else as in ADR-0055.** Degrees, accidentals before the numeral
   (`♭III`, `♭VII`), minor keys counted from the parallel major (`Im – ♭III – ♭VI –
   ♭VII` in A minor), slash chords with an arabic bass (`IIm7/1`), no secondary
   dominants, no figured bass, unknown suffixes shown as written. The B/H notation
   has no effect.
4. **Device setting, synced with the person.** Like the chord style, the spelling
   is a reading habit, not a property of the song: a device setting synced with the
   person (ADR-0027, scope *personal*), placed next to the chord view and the chord
   style in the display settings. No per-song value in the overlay (ADR-0006) and no
   segment in the live toggle; the toggle keeps `C · 1 · I`.
5. **Documented.** The website page *Chords, Nashville and numerals* (ADR-0055
   decision 10) explains both spellings with the same example side by side, says
   that neither is more correct, and shows the setting in a screenshot (de and en).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Separate setting, chord symbol follows the chord style** (chosen) | Both conventions; suffix reads like the chord name; same rule as Nashville; default unchanged | One more setting |
| Keep only the case spelling (status quo, ADR-0055) | No work | Jazz players miss the `m`; `vii` ambiguous without `°`/`ø` |
| Couple the spelling to the chord style (*Jazz* → upper case) | No new setting | The default style *As written* would never get it; Standard-style players who want upper case cannot have it |
| Switch the default to upper case with chord symbol | Matches the owner's and tester's preference | Changes the view of everyone who already uses numerals; classical readers expect case |
| Lower case and `m` (`iim7`) | Shows minor twice, "can't be misread" | Not used in the literature; redundant |
| Per-song value in the overlay or a live toggle segment | Fine-grained | A reading habit, not a song property; the live toggle is full on phones |

## Consequences

- The `chordpro` package gets a `NumeralSpelling` (`casing`, `chordSymbol`);
  `Chord.toNumeralParts` takes it and the chord style, and `ChordFormatter` passes
  them. Unit tests cover every quality in both spellings and all chord styles,
  minor keys, slash chords and unknown suffixes;
  `chord_views_example_test.dart` keeps checking the case spelling of the website
  examples.
- The app gets the setting (`numeralSpelling`, synced *personal*), its tile in the
  display settings and new UI texts in `app_de.arb` and `app_en.arb` (ADR-0008).
- The website page *Chords, Nashville and numerals* gets a section on the two
  spellings and a screenshot of the chord symbol spelling (`app/test_screenshots/`,
  de and en).
- ADR-0055 decisions 3 and 8 and ADR-0022's decision log point to this ADR.

## Decision log

- 2026-11-23: Proposed (#971) after tester feedback: lower case without `m` is
  correct, but the upper-case spelling with `m` is missing. The owner finds upper
  case better personally.

- 2026-11-23: Default is *Case*, so nothing changes for people who already
  use numerals (owner, #971).
- 2026-11-23: Accepted by the owner (#971). Implementation: `chordpro`
  conversion #975, app setting #976, website page with screenshot #978.

## Open points

- None.
