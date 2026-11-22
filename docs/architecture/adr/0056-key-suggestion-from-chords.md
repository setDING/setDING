# ADR-0056: Key suggested from the chords

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

Many imported songs have no `{key}`. Without it a song cannot show Nashville numbers
or Roman numerals (ADR-0055), and the sounding key with a capo is unknown. The
chords usually make the key clear to a musician, so the app can guess it (#919).

But the guess is a heuristic, and it can be wrong:

- **Relative keys** share their chords (C major and A minor). Only the first and last
  chord, and how often the tonic occurs, tell them apart.
- **Modal songs** fit a neighbouring major key (G Mixolydian with G–F–C looks like
  C major).
- **Key changes** (`{key}` in the middle of the song, a modulation at the end).
- **Few chords**: two chords fit several keys.

The editor already offers *conversions* (#798): places in the source that it can
rewrite, also for all songs at once (*Convert all*). These are unambiguous and do not
change how a song looks. A wrong key changes the chord views and the capo labels for
everyone who uses the song.

## Decision

1. **A suggestion, confirmed per song.** The song details form shows a key guessed
   from the chords below the key field while the song has no `{key}`, as chips. A tap
   puts it in the key field; it is written to the source only with *OK*. The guess is
   **never** written by itself, and it is **not** a conversion: no *Convert all*.
2. **Never an implicit key.** The chord views and the capo labels keep using only
   `{key}`; a song without it still shows the chord names with the hint of ADR-0055.
   The ChordPro text stays the single source of truth (ADR-0003).
3. **The runner-up is shown** when it scores at least 75 % of the best key, typically
   the relative major or minor, so the person sees the ambiguity.
4. **The heuristic** lives in the `chordpro` package (`guessKey`), a pure function:
   - Only chords before the first `{key}` count; chords as written (`{capo}` and
     `{transpose}` do not change them, as `{key}` names the key of the written
     chords). Annotations and chords that do not parse (`N.C.`, Nashville numbers)
     are skipped; slash chords count by their root.
   - Each of the 24 keys scores every chord by its quality (major, minor,
     diminished) and its degree in that key: tonic, dominant and subdominant most,
     the other diatonic chords less, common borrowed chords (`♭VII` and `iv` in major,
     the major `V`, `IV` in minor) a little.
   - The tonic chord as first and as last chord adds a bonus (30 % of the number of
     chords each), which decides relative keys and Mixolydian songs.
   - Fewer than three different chords give no guess.
   - The key is spelled conventionally (`F#`, `Bb`), as in the key field.
5. **A *To do* line *No key*** (ADR-0045): songs with chords and without `{key}`, for
   people who may edit them, as a line of the overview's *To do* card and a filter of
   the song list, so the songs can be worked through one by one.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| A conversion with *Convert all* | Fixes every song at once | Writes wrong keys unnoticed; conversions are meant to be safe and unambiguous |
| Use the guess as an implicit key for the chord views | No work for anyone | Wrong numbers on stage without a hint; the source is no longer the truth |
| Key profiles of the chord tones (Krumhansl–Schmuckler) | Established for audio and notes | Weighs single notes, not chord functions; no better on chord charts, harder to explain |
| Suggestion confirmed per song (chosen) | A person decides; ambiguity shown | One song at a time |

## Consequences

- Songs without a key are easy to find (*To do*, filter) and quick to fix.
- The heuristic is tested in the package with the known pitfalls; it can be tuned
  without touching the app.
- Songs with chords but no key that should stay without one (e.g. very free chord
  progressions) remain on the *To do* card.

## Decision log

- 2026-11-22: Proposed with the implementation (#919).
- 2026-11-22: Accepted by the owner (#924).
- 2026-11-22: Owner request (#925), resolving the open point: **the import
  report suggests keys** too. It lists the imported songs without `{key}` that
  have a guess (title and chips with the best key and the runner-up); a tap
  writes that song's key, so each song is still confirmed on its own. No
  *apply all*. The report opens for key suggestions alone; at most eight songs
  are listed, the rest is pointed to *To do* → *No key*. setDING archives are
  not checked.

## Open points

- None.
