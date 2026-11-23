# ADR-0040: Stacked verses as a display transformation

- **Status:** Accepted; extension for choruses (#953, decision 8) Proposed
- **Date:** 2026-11-19

## Context

Verses of a song often share their chords. #518 added a personal option to
show the chords in the first verse only. Some musicians prefer the layout of
hymnals instead (#521): each line of chords once, and below it the matching
line of every verse, so they can read any verse under its chords:

```
       [A]    [B]    [C]
1. Erste  Zeile des Verses 1
2. Erste  Zeile des Verses 2
```

The ChordPro text is the single source of truth (ADR-0003) and personal
adjustments never change it (ADR-0006). Freehand annotations are anchored to
source lines (ADR-0032). The song view and live mode share one renderer and
one layout measurement used to fit songs to pages (ADR-0007).

## Decision

1. **One personal choice, three values.** *Chords in verses* is a layer 3
   adjustment (ADR-0006) with the values *all*, *first verse only* (#518) and
   *verses stacked* (#521); it replaces the boolean of #518.
2. **A transformation of the parsed song.** `stackVerses` in the `chordpro`
   package turns a parsed `Song` into another one, like
   `firstVerseChordsOnly`; it is applied after the set or band sequence, so
   only the shown verses are stacked. The ChordPro text is never changed.
3. **Grouping.** Verses are sections with the verse role (ADR-0033).
   Consecutive verses form a group with a first verse that has chords when
   they have the same lyric and empty lines with the same chord sequence
   line by line (chord positions may differ). A verse without any chords
   joins when its lines match the lyric lines of the first one. Verses with
   other content (comments, tabs, images, format directives) are never
   stacked. Other sections between the verses stay where they are. A verse
   with the same lyrics as an earlier one of its group adds no row and is
   left out with the group (#953).
4. **Placement.** A group is shown in place of its first verse as one
   section, labelled `Verse 1–3` when the first and last label end in a
   number, otherwise with the first verse's label. The later verses of the
   group are left out.
5. **New line type `StackedLine`.** The stacked section holds `StackedLine`s:
   the chords of each column and a `StackedRow` per verse with the verse's
   number (from its label, else its position), its own `LyricLine` and the
   text under each chord (none for a verse without chords). Lines of chords
   only and empty lines stay single lines. `StackedLine` is never parsed from
   ChordPro.
6. **Rendering.** A column of verse numbers, the chords once, and the verses
   with chords as rows in columns as wide as their widest cell, so words
   under a chord line up; a hyphen joins the syllables of a word split by a
   chord (#532). The columns wrap together. Verses without chords
   follow with their text in one piece. The layout measurement mirrors this.
7. **Annotations.** Each row is marked as its verse's source line (on its
   verse number), so freehand annotations follow their line into the block;
   the layout fingerprint records the choice, so strokes drawn on another
   layout fall back to their line anchor (ADR-0032).

8. **Stacked choruses (#953).** A second, independent layer 3 setting
   *choruses stacked* (a boolean next to *chords in verses*, a tick in the
   same menu) applies the same transformation to the sections with the
   chorus role (`stackChoruses`; `stackVerses` and `stackChoruses` share
   `stackSections`). It is applied before the verse choice, so verses,
   choruses or both can be stacked. Choruses that only repeat the words of
   an earlier one add no row, so a song whose choruses are all the same is
   not changed and the tick is disabled; `{chorus}` recalls stay where they
   are. It is synced in the overlay data (`stacked_choruses`), kept in
   backups and recorded in the layout fingerprint (`choruses`).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Transformation of the parsed song with a new line type (chosen) | Song view, live mode, sequences and layout reuse the existing pipeline; the source stays unchanged | A new line type every renderer and measurement must handle |
| Layout only in the renderer, from the original verses | No model change | The renderer must regroup sections across the song; sequences, pagination and annotations would need special cases |
| Estimate chord positions for verses without chords (by syllables) | Every verse aligned | Unreliable; wrong positions are worse than none |
| Repeat the block at every verse position | Song order unchanged | Longer than the plain song; the point is to save room |
| Separate boolean next to #518 | Smaller change | Two options that exclude each other |
| Choruses as a fourth value of *chords in verses*, or one multi-select of verses and choruses (#953) | One control | Stacked choruses combine with every verse choice, *first verse only* and *stacked verses* exclude each other |

## Consequences

- Stacked songs are shorter, but the musician reads back up to the block for
  later verses; the song map and sequences still name the shown parts.
- Mid-word chords split the word into two columns, which can leave a gap
  inside the word; a hyphen centred in the gap joins the syllables (#532).
- Wrapped columns of a long line continue without verse numbers.
- Every new renderer or exporter of parsed songs must handle `StackedLine`
  (the sealed `Line` type makes this a compile error).

## Decision log

- 2026-11-19: Proposed with #521 after the owner chose: verses without chords
  join unsplit, the block replaces the first verse, annotations follow their
  line, one choice with three values replacing #518's boolean.
- 2026-11-19: Accepted by the owner (#521, #531).
- 2026-11-19: Owner decision (#532): where a chord splits a word of a verse
  (its cell ends and the next begins without a space), a hyphen joins the
  syllables, centred in the rest of the column as in hymnals (`A - mazing`),
  directly after the syllable when the column is just as wide; its width
  counts towards the column width in the layout measurement.
- 2026-11-23: Proposed with #953 after the owner chose an independent tick
  for choruses next to the verse choice: choruses whose words change are
  stacked like verses (decision 8), and a section with the same lyrics as an
  earlier one of its group adds no row (also for verses, decision 3).

## Open points

- Line width on small tablets: padding and the column of verse numbers make
  lines wider; to be checked on a real device.
