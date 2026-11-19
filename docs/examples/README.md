# Examples

| File | Content |
|---|---|
| [`feature-showcase.cho`](feature-showcase.cho) | One ChordPro file that uses **every ChordPro feature supported by setDING** (ADR-0012), plus a second song after `{new_song}`. All lyrics and music are original and free to use. |
| [`stage-plan.svg`](stage-plan.svg) | Image used by `{image: src="stage-plan.svg"}` in the showcase. |
| [`feature-showcase.zip`](feature-showcase.zip) | Both files in one archive: importing it creates the two songs and attaches the image automatically. Rebuild it with `make examples` after changing the files. |
| [`nord-test/`](nord-test/) | Nine short songs for testing MIDI program changes on a **Nord Stage 3** in live mode (ADR-0039). Each song shows the program the Nord should switch to and the MIDI values sent. Original lyrics and music, free to use. |
| [`nord-test.zip`](nord-test.zip) | The nine songs in one archive, rebuilt with `make examples`. |

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

## Nord Stage 3 test set

The songs carry no keyboard program: programs are personal adjustments
(ADR-0039), so they are set by hand after the import.

1. Settings → *Musician* → instrument **Keyboard**; then *Keyboard (MIDI)*:
   MIDI program changes on, output = the Nord (USB), profile **Nord Stage 3**,
   channel = the Nord's global channel. On the
   Nord: MIDI menu → "Program Change" reception on.
2. Import `nord-test.zip` and set the keyboard program of each song as shown in
   its subtitle (Program, Live memory or Song at the top of the dialog).
3. Create a set with the songs in order 01–09, a break between 04 and 05, and
   start live mode.

| Song | Keyboard program | Sent (CC 0 / CC 32 / PC) | Tests |
|---|---|---|---|
| 01 First Light | Program A:11 | 0 / 0 / 0 | sent when live mode starts |
| 02 Edge of the Block | Program E:55 | 0 / 0 / 124 | last program of the first block |
| 03 Next Block | Program F:11 | 0 / 1 / 0 | first program of the second block |
| 04 Once Again | Program F:11 | 0 / 1 / 0 | same program again (change it by hand first) |
| *break* | – | nothing | breaks send nothing |
| 05 Quiet Keys | none | nothing | the Nord keeps its sound |
| 06 Memory Lane | Live memory 3 | 6 / 0 / 2 | live memory |
| 07 Back to the Programs | Program K:33 | 0 / 2 / 12 | leaving live mode |
| 08 Song Mode | Song 2, part 3 | 1 / 0 / 7 | Nord songs |
| 09 Last Place | Program P:55 | 0 / 3 / 24 | the last program |

Also try: swiping quickly from 01 to 09 sends only 09 (300 ms), "Send program
again" in the live control bar, and unplugging and plugging in the Nord (the
indicator below the page turns red and back).
