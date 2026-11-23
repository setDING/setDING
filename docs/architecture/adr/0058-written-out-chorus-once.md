# ADR-0058: Showing a written-out repeated chorus only once

- **Status:** Proposed
- **Date:** 2026-11-23

## Context

Songs from SongSelect and many other sources write the chorus out every time
it is sung, marked with a comment heading (`{comment: Chorus}`, #463) instead
of a `{chorus}` recall. "10.000 Gründ", for example, has the same chorus at the
start and again after verse 2. Musicians who know the song lose room on the
screen to a block they have already read; the owner asked for an option to
hide the second copy in live mode (#955).

The ChordPro text is the single source of truth (ADR-0003), personal
adjustments never change it (ADR-0006), and the song view and live mode share
one renderer and layout measurement (ADR-0007). Stacked verses (ADR-0040)
already transform the parsed song for a person's display. A `{chorus}` recall
is shown in full or as a label by the device setting *Repeated chorus*.

## Decision

1. **A personal setting, off by default.** *Show a written-out chorus only
   once* is a switch in *Settings › Display › Content*, a layer 4 setting
   synced with the person's account (`repeatedChorusOnce`, scope personal),
   not a per-song overlay: it is a reading habit, like showing the parts
   outside the sequence.
2. **A transformation of the parsed song.** `withoutRepeatedChoruses` in the
   `chordpro` package leaves out every chorus section whose lines are the
   same as those of an earlier chorus. It is applied after the sequence and
   before stacking choruses (#953) and the verse transformations of
   ADR-0040, in the song view and in live mode; the ChordPro text is never changed.
3. **What counts as the same.** Choruses are the sections with the chorus
   role (ADR-0033): `{start_of_chorus}` or a heading such as
   `{comment: Refrain}`. Two choruses are the same when their lines are equal
   (lyrics with markup, chords as written, comments and other lines;
   trailing spaces and leading or trailing empty lines aside); the label does
   not matter. They need not follow each other. A chorus that differs, even
   by one chord, stays. Grids, chord diagrams and stacked lines never match.
4. **Left out entirely.** The later copy disappears without a label; the
   musician knows to sing the chorus again. `{chorus}` recalls are not
   sections and keep following *Repeated chorus*.
5. **Annotations.** The layout fingerprint records the choice (`chorus1`), so
   strokes drawn on the other layout fall back to their line anchor
   (ADR-0032); strokes on a left-out chorus are not shown.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Transformation of the parsed song, left out entirely (chosen) | Reuses the pipeline of ADR-0040; the owner's choice | No hint where the chorus is sung again |
| Replace the copy with a label like a `{chorus}` recall | Shows where the chorus comes again | Not what the owner chose; would mix with *Repeated chorus* |
| Only directly repeated choruses | Never hides a chorus far from the first | Misses the common SongSelect case ("10.000 Gründ") |
| A per-song adjustment (overlay) | Can differ per song | One more switch per song; the habit is the same for every song |
| A conversion that rewrites the source into `{chorus}` | Shared with the band | Changes the song for everybody (ADR-0003, ADR-0006) |

## Consequences

- Songs that write the chorus out again get shorter for those who switch it
  on; the song map and the sequence still name every part.
- A chorus that varies slightly (another last line, one chord) stays, which
  is safe but may surprise.
- Every new view of the parsed song for a person applies `songForDisplay`.

## Decision log

- 2026-11-23: Proposed with #955 after the owner chose: written-out
  duplicates anywhere in the song, left out entirely, a personal switch off by
  default, in the song view and live mode.

## Open points

- Whether the song map in drummer mode should leave the repeated chorus out
  as well (it lists the parts as played, so it keeps it for now).
