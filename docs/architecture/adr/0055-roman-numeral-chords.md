# ADR-0055: Chords as Roman numerals

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

Today a song shows its chords either as chord names or as **Nashville numbers**
(ADR-0003): an on/off display setting per device, optionally overridden per song in
the personal overlay (ADR-0006, ADR-0020), with a toggle in the live control bar
(ADR-0007). Nashville numbers write the scale degree as an arabic number and keep
the chord quality as a suffix (`Am7` in C → `6m7`).

Musicians who think in harmonic analysis (in German *Stufenanalyse*), above all in
jazz, read chords as **Roman numerals**: `vi7 – II7 – V7 – IΔ7`. Planning Center
offers the three views side by side as *Chord chart*, *Number chart* (Nashville) and
*Numeral chart* (Roman). MuseScore supports Roman numeral analysis as text typed by
hand (upper case for major, lower case for minor, `o`/`0`/`+` for diminished,
half-diminished and augmented, accidentals before the numeral); its chord symbol
style (Standard/Jazz) applies to chord symbols and Nashville numbers but **not** to
Roman numerals.

Roman numerals differ from Nashville numbers in more than the digits:

- The **case** carries the quality: upper case is major (and dominant, augmented),
  lower case is minor (and diminished, half-diminished). The minor `m` is not
  written.
- In **minor keys** there are two conventions: degrees counted from the natural minor
  scale (classical: `i – III – VI – VII` in A minor) or from the parallel major
  (jazz/Berklee: `i – ♭III – ♭VI – ♭VII`).
- **Inversions** are written as figured bass (`I⁶`, `V⁶₅`) in classical analysis and
  as slash chords (`I/3`) in pop and jazz charts.
- Analysis often names **secondary functions** (`V/V`), which needs harmonic
  interpretation, not only transcription.

The structured chord suffix of ADR-0022 already provides the parsed quality, so the
conversion needs no new parsing.

## Decision

1. **Three chord views instead of the Nashville switch.** The on/off setting
   `nashville` becomes a choice with three values:
   - *Chords* (default): chord names, as today.
   - *Nashville*: Nashville numbers, as today (ADR-0003).
   - *Numerals*: Roman numerals (this ADR).

   UI names: *Akkorde / Nashville / Stufen* (de-CH) and *Chords / Nashville / Numerals*
   (en). The choice applies in the same three places as the Nashville switch today:
   device setting (synced with the person, ADR-0027), personal per-song adjustment
   (overlay, ADR-0006/ADR-0020) and the toggle in the live control bar, which gets
   three segments (`C · 1 · I`).
2. **Computed, never stored.** Numerals are derived at render time from the chords
   and the song's key after set and personal transposition, like Nashville numbers
   (ADR-0003). The ChordPro source is never changed. Without a `{key}` the chord
   names are shown with the same hint as for Nashville numbers.
3. **Case shows the quality.** Major, dominant and augmented chords are upper case;
   minor, diminished and half-diminished chords are lower case, and the minor marker
   is dropped. Examples in C: `C` → `I`, `Dm7` → `ii7`, `G7` → `V7`, `Am` → `vi`,
   `Cmaj7` → `IΔ7`, `Bm7b5` → `viiø7`, `Bdim` → `vii°`, `Bdim7` → `vii°7`,
   `Caug` → `I+`, `Csus4` → `Isus4`, `Am(maj7)` → `viΔ7`.
4. **Accidentals before the numeral**, from the same degree table as the Nashville
   numbers: `♭II`, `♭III`, `♯IV`/`♭V` as for Nashville, `♭VI`, `♭VII`.
5. **Minor keys in jazz style.** Degrees are counted from the tonic with the major
   scale as reference (jazz/Berklee), so in A minor `Am – C – F – G` is
   `i – ♭III – ♭VI – ♭VII`. This matches the Nashville display, which counts the same
   way in minor (`1m … b3 … b7`).
6. **Slash chords** keep the bass as an arabic scale degree behind a slash:
   `C/E` → `I/3`, `G/B` → `V/7`, `D/C` in C → `II/1`. No figured-bass inversions.
7. **No harmonic analysis.** Each chord is converted on its own; secondary dominants
   are shown by their degree (`D7` in C is `II7`, not `V/V`).
8. **Fixed spelling.** Numerals always use `°`, `ø`, `+`, `Δ`, `♭` and `♯`, independent
   of the chord style setting (ADR-0022), as in MuseScore. The extension and
   alterations follow the jazz spelling (`V7♭9`, `IΔ9`). The superscript switch of
   ADR-0022 still applies, and the B/H notation has no effect (numerals have no note
   names). A suffix the parser does not understand is shown as written behind an
   upper-case numeral, so no chord is displayed wrongly or dropped.
9. **Compatible storage.** The device setting and the overlay field store the view by
   name (`chords`, `nashville`, `numerals`); a stored `nashville = true` reads as
   *Nashville*. For app versions that only know the switch, the overlay and the synced
   settings keep writing the old `nashville` flag (true for *Nashville* and
   *Numerals*), so an older device shows Nashville numbers instead of numerals.
10. **Explained in the user documentation.** Many musicians know chord names but
    neither number system, so the website gets its own page *Chords, Nashville and
    numerals* in both languages (ADR-0030), linked from the display settings, the
    personal adjustments and live mode. It explains:
    - what the three views are for and that they never change the song;
    - the scale degrees of a key with one worked example (a progression in C as
      chords, Nashville numbers and numerals side by side, with a screenshot of each view);
    - for numerals: upper and lower case for the quality, the symbols `°`, `ø`, `+`
      and `Δ`, accidentals before the numeral, extensions and alterations, slash
      chords with the bass as a number, all as a reference table from chord to
      numeral;
    - minor keys in jazz style (`i – ♭III – ♭VI – ♭VII`) and why it differs from the
      classical way of counting;
    - what the display does not do (no secondary dominants such as `V/V`, no
      figured-bass inversions), what happens without a key, and how unknown chords
      are shown.

    The in-app hint for the setting links to this page.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Three-way chord view** (chosen) | One place to choose how chords read; same scopes as Nashville today; no new concept | Migration of a setting and an overlay field; live toggle needs a third segment |
| Separate switch "Roman numerals" next to the Nashville switch | No migration | Two switches that exclude each other; four combinations for three states |
| Roman numerals as a variant of the chord style (ADR-0022) | Reuses an existing setting | Style is about spelling of names, not about degrees; would not work per song or in live mode |
| Minor keys counted from the natural minor (classical) | Standard in classical analysis | Differs from our Nashville numbers; jazz charts and Berklee use the parallel major |
| Figured-bass inversions (`I⁶`, `V⁶₄`) | Correct classical analysis | Hard to read on stage; slash chords with non-chord bass notes need slash notation anyway |
| Secondary dominants (`V/V`) | Richer analysis | Needs interpretation of context; may be wrong; can be an option later |
| Numerals follow the chord style (Standard/Jazz) | Consistent with chord names | Mixed spellings like `viim7b5` are unusual; MuseScore keeps numerals fixed too |

## Consequences

- The `chordpro` package gets a Roman numeral conversion next to the Nashville one,
  built on the parsed quality (ADR-0022), with unit tests for every quality, minor
  keys, accidentals, slash chords and unknown suffixes. `ChordFormatter` gets the
  chord view instead of the `nashville` flag.
- The app migrates the device setting and the overlay column from a flag to the
  view (database schema step, backup format, overlay sync, settings sync with the
  compatible `nashville` flag of decision 9).
- The live toggle grows from two to three segments; on narrow screens it may need to
  move out of the control row like the Nashville toggle already does below its
  minimum width.
- New UI texts in `app_de.arb` and `app_en.arb` (ADR-0008).
- A new website page *Chords, Nashville and numerals* (decision 10) in both
  languages with screenshots of the three views (`app/test_screenshots/`, de and
  en); the pages about the display settings, personal adjustments and live mode
  replace their Nashville paragraphs with the three views and link to it.
- ADR-0003 (Nashville numbers) and ADR-0022 (chord style) get a decision log entry
  pointing to this ADR.

## Decision log

- 2026-11-22: Proposed (#899). Owner preferences from the discussion: names after
  Planning Center (chord, number and numeral chart), minor keys in jazz style
  (counted from the parallel major), and the numeral spelling well explained
  in the user documentation.
- 2026-11-22: The Nashville view keeps its name *Nashville* in both languages
  instead of *Numbers* / *Zahlen*, because musicians know the term (owner).
- 2026-11-22: Accepted by the owner (#899). Implementation: `chordpro`
  conversion #906, chord view setting and adjustment #907, live toggle #908,
  website page with screenshots #909.
- 2026-11-22: Implemented in the `chordpro` package (#906): `ChordView`,
  `Chord.toNumeralParts`, `ChordFormatter.view`.
- 2026-11-22: Chord view in the app (#907): device setting `chordView` and
  overlay column `chord_view` (schema 34, the flag converted), both still
  writing the `nashville` flag; `chordViewOf` reconciles the two (a flag
  switched by an older version wins). The song's personal panel has a chord
  view chip with a menu; the live toggle offers chords and Nashville until
  #908.
- 2026-11-22: The live toggle has three segments `C` / `1` / `I` with the
  full names as tooltips (#908); words did not fit the control bar on phones.

## Open points

- Later option: secondary dominants (`V/V`) and figured-bass inversions for
  analysis-minded users.
