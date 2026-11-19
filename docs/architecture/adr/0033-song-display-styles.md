# ADR-0033: Song display styles per section type

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

Live mode (ADR-0007) shows every song in one fixed style: lyrics in the text
colour, chords bold in the stage colour (`StageColors`: deep blue on light,
amber on dark and black), section labels small, upper case and semi-bold in
the secondary colour, and a chorus with a 3 px bar and an indent. Verses,
bridges, intros and solos look the same.

Musicians read a chart differently depending on their role. A singer wants
the lyrics strong and the chords quiet; a guitarist the opposite. Many want
to find the chorus at a glance, or be warned by a colour that the bridge or
a solo is coming. Today none of this can be adjusted.

Constraints:

- The ChordPro text is shared and stays the single source of truth
  (ADR-0003); the style must not change it. Songs may already carry their
  own formatting: directives such as `{chordcolour}`, `{textcolour}`,
  `{chordsize}`, `{textfont}` and inline markup such as `<b>` or
  `<span color="…">` (ADR-0012).
- Live mode has three appearances, *app*, *dark* and *black* (device
  setting, ADR-0027). A colour has to stay readable on all of them.
- Sections are recognised from `{start_of_…}` environments and, since #463,
  from comment headings such as `{c: Solo}` (`section_heading.dart`). The
  parser maps intro, outro, pre-chorus, solo, interlude etc. to
  `SectionKind.custom` today.
- The layout of live mode is measured in advance (`song_layout.dart`,
  `SongSpacing`) for columns, song pages and auto-fit; rendered and measured
  sizes must match.

The design was worked out with the owner in an interactive mock-up
(issue #471).

## Decision

1. **New settings section "Song display"** (de-CH: *Songdarstellung*) with
   presets, an editor per section type and a live preview with a demo song.
2. **Section types: Standard plus seven fixed types.**
   - *Standard* is the base style. It applies to every type without its own
     style and to every section that is not recognised (post-chorus, tab,
     grid, custom names, unlabelled lyrics).
   - Fixed types: *Intro*, *Verse*, *Pre-Chorus*, *Chorus*, *Bridge*,
     *Interlude*, *Outro*.
   - The type is a **section role** derived from the section name, from
     `{start_of_<name>}` or a comment heading, with fixed synonyms:

     | Type | Recognised names |
     |---|---|
     | Intro | intro |
     | Verse | verse, vers, strophe, `{start_of_verse}` |
     | Pre-Chorus | pre-chorus, pre-refrain |
     | Chorus | chorus, refrain, `{start_of_chorus}` |
     | Bridge | bridge, `{start_of_bridge}` |
     | Interlude | interlude, instrumental, zwischenspiel, solo, turnaround, vamp |
     | Outro | outro, ending, schluss, coda, tag |

     The `chordpro` package exposes the role next to `SectionKind`, which
     stays close to the specification. No free rules ("name starts with …").
   - The label of a repeated chorus (`{chorus}` collapsed to a label) uses the
     chorus style. Comments, notes, chord diagrams and the song header are not
     styled per type.
3. **Inheritance.** Every type except Standard either has its **own style** or
   **inherits from a chosen type**. Chains are allowed (Intro → Interlude →
   Standard); the editor disables every choice that would create a cycle, so
   every chain ends at Standard. Defaults: Intro and Outro inherit from
   Interlude, Pre-Chorus from Verse, all others from Standard. Switching a
   type to its own style starts from what it inherited so far.
4. **Style properties** of a type:
   - Chords: bold, italic, size (S / M / L), colour.
   - Lyrics: bold, italic, colour.
   - Heading (section label): shown or not, bold, italic, size (S / M / L /
     XL), colour.
   - Indent bar: on or off, width (thin / medium / wide), colour; indent
     (none / normal / large); tinted background.

   - Font (since #526): *Standard* (the app font) or *Monospace*, one
     choice for lyrics, chords and headings of all types; independent of
     the preset.

   Bold means weight 700 and not bold 400 for every element. Sizes, bar width
   and indent are relative to the font size, so they scale with the device
   font size.
5. **Curated palette, no free colours.** Automatic plus nine colours (blue,
   amber, red, green, teal, purple, pink, grey, black/white). Every colour has a light and
   a dark tone with a contrast of at least 4.5:1 on its background; the tone
   is chosen from the brightness of the background, so one style works in
   all live appearances and in the app theme. *Automatic* is today's colour
   of the element (stage chord colour, text colour, label colour).
6. **Presets.** *Classic* (today's look), *Colour-coded*, *Chorus focus*,
   *Singer*, *Guitar*, *Minimal*. Any change turns the selection into
   *Custom*; "Reset" returns to the preset. A selected preset is stored by
   its ID, so improvements to a preset in a later app version apply; only a
   custom style is stored with all its values.
7. **Precedence over formatting in the song.**
   - Colour: an explicitly chosen colour beats `{chordcolour}`,
     `{textcolour}` and the like. *Automatic* lets the song's colour through,
     otherwise the app colour applies.
   - Size: the style's size factor multiplies with `{chordsize}`,
     `{textsize}` and the like.
   - Inline markup (`<b>`, `<i>`, `<span …>`, also in chords) always wins: it
     is local and deliberate emphasis.
   - There is no switch to ignore the song's formatting.
8. **Where it applies.** Live mode and the song view. The preview in the
   ChordPro editor stays neutral (Classic), so whoever edits the shared song
   sees how it looks for everybody, including its own directives.
9. **Personal setting** (layer 4a, ADR-0027): synced with the account, the
   same on every device of a person, no per-device override. It is stored as
   one key `songDisplay` (preset ID, or the custom styles of all types and
   their inheritance); last writer wins for the whole key. Unknown types or
   properties from a newer app version are kept and written back unchanged.
   The live appearance and the font size stay device settings.
10. **Layout.** Bar width, indent and heading size become per-type values in
    the renderer and in the layout measurement, so columns, song pages and
    auto-fit stay exact. `SongSpacing.chorusIndent` and
    `chorusBorderPixels` are replaced by the indent *normal* (0.6) and the
    bar width *thin* (0.15 of the font size, 3 px at 20 px) of the
    *Classic* chorus.
11. All texts in both ARB files (ADR-0008); type names are UI texts, the
    recognised synonyms are not.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Standard + fixed types with chosen inheritance** (chosen) | Simple start (only Standard), fine control where wanted, intros and outros can share a solo's style | Role detection and inheritance to implement and explain |
| Only verse, chorus, bridge and "other" | Smallest change | Intro, solo and outro, often the cues a band needs, cannot be told apart |
| Free rules "name starts with …" → style | Covers every naming | Hard to use in a settings screen, easy to misconfigure on stage |
| Fixed parent per type instead of a chosen one | Less UI | Intro and outro cannot follow the interlude, as the owner wants |
| Free colour picker (hex) | Any colour | Unreadable combinations on dark or black backgrounds; a colour per appearance needed |
| Song formatting always wins | Respects the author | One `{chordcolour}` breaks a person's scheme, possibly unreadable on black |
| Personal style always wins (also over markup) | Fully consistent | Deliberate emphasis such as a bold "quiet!" is lost |
| Device setting | Could differ between phone and tablet | Set again on every device; sizes already scale with the device font size |
| Also in the editor preview | Simplest, one look everywhere | Editors no longer see how the shared song looks for others |
| Style in the ChordPro source or the overlay | Per song possible | Changes shared data or multiplies settings; a style is a reading habit (as in ADR-0022) |

## Consequences

- The `chordpro` package gets a section role (`SectionRole`) derived from
  the section name, reusing the synonyms of `section_heading.dart`, with unit
  tests; the feature showcase gets an intro, pre-chorus, solo and outro.
- `SongTextStyles` and the section rendering take a resolved style per
  section; `song_layout.dart` measures with the same per-type values.
  Tests check that measured and rendered heights still match for every
  preset.
- `StageColors` remains the source of the *Automatic* chord colour in live
  mode; the song view uses the theme's primary colour as today.
- The precedence rules need tests against directives and markup.
- *Classic* looks like today except that section labels become bold (700)
  instead of semi-bold (600), a barely visible change.
- `AppSettings` gets the `songDisplay` key in the personal scope; the
  settings category is listed under the personal heading (ADR-0027).
- The user documentation on the website (ADR-0030) gets a page on song
  display.
- Further types (post-chorus, tab, grid) can be added later without changing
  the model; until then they use Standard.

## Decision log

- 2026-11-18: Proposed after a design session with the owner (#471):
  Standard plus seven fixed types, inheritance from a chosen type, curated
  palette, precedence rules, personal scope, live mode and song view only,
  bold = 700 everywhere.
- 2026-11-18: Accepted by the owner.
- 2026-11-18: Implementation details (#471): the thin bar is relative
  like all other widths (0.15 of the font size instead of a fixed 3 px);
  the chord size of a style does not apply to chord grids, whose rows are
  as high as their text.
- 2026-11-18: Implemented in #473–#476 with the user documentation; the
  palette tones are in `song_display_colors.dart`, a test checks a
  contrast of at least 4.5:1 on every app and live background.
- 2026-11-19: Palette extended by *Black/White* (#522): black on light
  backgrounds, white on dark ones, for maximum contrast.
- 2026-11-19: A font choice, *Standard* or *Monospace*, for the whole song
  text (#526). It is not a per-type property and not part of a preset:
  stored as `font` next to `preset` in the `songDisplay` key (only when not
  standard) and kept when another preset is chosen. Older apps keep it as
  an unknown key. A font directive in the song (`{textfont}` etc.) still
  wins, like the other format directives.

## Open points

- Where the preset selection is offered besides the settings (e.g. in the
  live menu) – not planned for the first version.
