# ADR-0050: Settings screen layout

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

The settings screen (ADR-0027) lists its categories on the left on wide screens
and opens each one as its own page on narrow ones. Inside a category, the options
grew one at a time, and each category ended up looking different (#766):

- Only some options had a leading icon (the click volume, the page turning hint,
  the storage tiles), so their texts started at two different columns.
- Sections looked different in every category: small coloured headings in *Song
  display*, a list tile with an icon for *Beat and click* in *Musician*, nothing in
  *General* and *Display*, although they mix unrelated options (language and theme
  next to the editor and developer mode).
- The note on whether a category is synced looked like a setting.

Settings keep being added, so the layout needs a rule that new options follow
without thinking about it.

## Decision

1. **Every settings category is a list of titled sections** (`SettingsSections`
   with `SettingsSection`, `app/lib/ui/settings/settings_layout.dart`). A section
   heading is a small text in the primary colour, like the groups of the category
   list; an optional hint below it explains the whole section. **A divider
   separates two sections.** A widget with its own heading in the same style may
   stand in for a section (the song display preview).
2. **Every option has a leading icon**, so all titles and hints start at one
   column. The shared widgets require it: `SettingsSwitch` (on/off) and
   `SettingsChoice` (a few values as a segmented button) take a mandatory `icon`;
   other options are a `ListTile` with `leading`. Controls below an option (colour
   swatches, a button) are indented to the text column. Information tiles (hints,
   a connection status) have an icon too.
3. **Icons are Material icons, outlined where an outlined variant exists**, and
   say what the option does; one icon is not used for two options of the same
   category.
4. **The scope note is a tonal banner** at the top of a category (personal and
   synced, or only this device, ADR-0027), not a list tile, so it is not taken
   for a setting.
5. **Options that depend on another one** (the click's details while the click is
   on) stay in their section right after it; a group of options that only exists
   in some cases is its own section (the click on this device, the keyboard
   settings of MIDI).
6. **The sections of the categories** (as implemented in #766):

   | Category | Sections |
   |---|---|
   | General | Language & theme · Editor · Advanced |
   | Display | Chords · Content · Set & notes |
   | Song display | Style · Preview |
   | Musician | Instrument & voice · Beat and click |
   | Screen & live mode | Screen · Controls · Click on this device |
   | Keyboard (MIDI) | Connection · Keyboard |
   | Storage & info | Backup · This device · Automatic backup · Help & info |
   | Test features | Prototypes |

7. **A test enforces the rules:** `app/test/settings_layout_test.dart` opens every
   settings category on a phone-sized screen, with every option shown (drums with
   the click and developer mode; a keyboard with MIDI on), and fails when an option
   has no icon, is outside a section, or overflows.
8. **Account & sync and Organization & bands are exempt** from the section rule:
   they show the account and lists of organizations and bands rather than options.
   Their options still have icons.
9. **The content uses the width of its pane** (#774). Beside the category list, a
   category fills the pane instead of a 720 column (ADR-0051). From a pane width of
   **1040** (`settingsTwoColumnWidth`), `SettingsSections` flows the sections into
   **two columns** of equal width: in order, the first sections on the left, split
   where the two columns are closest in height, a divider between two sections of a
   column. The keyboard moves through the left column first, then the right one.
   Narrower, the sections fill the width in one column. *Song display* stays in one
   column (`twoColumns: false`): its preview needs the width to show the song as on
   the screen.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Sections with dividers and an icon on every option (chosen) | Sections easy to tell apart; one text column; close to the platform's own settings | More icons to choose; a segmented button has 56 px less width on a phone |
| Each section on a tinted card | The clearest separation | Takes more room; does not match the other screens of the app |
| Sections and dividers, icons only on the headings | Calmer, fewer icons to pick | Loses the icons next to the options, which make them easier to find |
| A written guideline only, no test | No test to maintain | New options drift from it, as the existing ones did |

## Consequences

- A new option is added with `SettingsSwitch`, `SettingsChoice` or a `ListTile`
  with `leading`, inside a `SettingsSection`; the test fails otherwise.
- A section is built as one widget, so its options are built together; tests that
  scroll to an option call `ensureVisible` after `scrollUntilVisible`.
- Visible changes to the settings update their screenshots and website pages
  (ADR-0030).

## Decision log

- 2026-11-21: Proposed (#766), together with the implementation.
- 2026-11-21: Accepted by the owner (#768).
- 2026-11-21: The section heading is the app-wide `SectionHeader` of ADR-0051 (#743): bold like the other sections of the app; the layout rules here are unchanged.
- 2026-11-21: The owner decided that the settings use the width of their pane (#774): two columns of sections from 1040, full width below; the song display stays in one column for its preview (point 9).
- 2026-11-22: The owner chose to split *Storage & backup* (#891): *Backup* (back up everything, restore), *This device* (storage used, show the local library) and below it *Automatic backup* as its own section (point 5): it exists only where a folder can be chosen and, as it backs up only the local library, only while the local library is shown or the automatic backup is still on; *Back up to the folder now* gets its own icon (point 3).

## Open points

- Whether the song display editor (#478) follows the same layout.
