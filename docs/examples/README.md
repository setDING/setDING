# Examples

| File | Content |
|---|---|
| [`feature-showcase.cho`](feature-showcase.cho) | One ChordPro file that uses **every ChordPro feature supported by setDING** (ADR-0012), plus a second song after `{new_song}`. All lyrics and music are original and free to use. |
| [`stage-plan.svg`](stage-plan.svg) | Image used by `{image: src="stage-plan.svg"}` in the showcase. |
| [`feature-showcase.zip`](feature-showcase.zip) | Both files in one archive: importing it creates the two songs and attaches the image automatically. Rebuild it with `make examples` after changing the files. |

## Trying it out

1. Start the app (`make dev`), open **Songs → Import files** and choose `feature-showcase.zip`.
2. Open "Feature Showcase" and use the settings to see the conditional and optional parts:
   - **My instrument** (guitar, ukulele, keyboard, …) and **My name or voice** (e.g. `alto`, `soprano`) change which conditional comments and sections appear.
   - **Chord diagrams** shows the fingerings for the chosen instrument (the song also asks for them with `{diagrams: bottom}`).
   - **Chord notation** (B/H) and **Nashville numbers** change how chords are displayed.
3. Add the song to a set and start live mode; choose a key in the set list to see chords, grids and the ABC melody transposed.

## What it covers

Meta-data and metadata substitution (`%{…}`), comment styles, markup in lyrics, chords
and comments, chord annotations, optional chords, German/Dutch note names, escaped
brackets, all section types and labels, chorus recall, SongSelect-style headings,
`{transpose}` (sharps, flats, `f` suffix, cancel), key changes with Nashville numbers,
tab, grids (shape, marks, voltas, strums), font/size/colour directives, conditional
directives (instrument, user, metadata, negation), chord definitions and diagrams,
images, SVG, textblock, ABC, Lilypond, `{columns}`, `{column_break}`, `{new_page}`,
custom `x_` directives (including setDING' `{x_sequence}` and `{x_time_grouping}` for the odd meter of the second song) and `{new_song}`.

The file is also a regression test: `packages/chordpro/test/showcase_test.dart` and
`app/test/showcase_test.dart` parse, import and render it.
