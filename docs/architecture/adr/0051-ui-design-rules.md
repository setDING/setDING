# ADR-0051: UI design rules

- **Status:** Proposed
- **Date:** 2026-11-21

## Context

The management screens of the app (overview, sets, songs, people, settings) grew
screen by screen, mostly written by agents. A review (issue #743) found that the
same thing was built in several ways:

- **Section headers** were implemented eight times (settings groups, song list, set
  list, set archive dialogs, song display settings, band and organization screens,
  invitations), with top paddings of 16, 20 and 24, regular or bold, and only some
  marked as headings for screen readers; the invitations header was not even in the
  primary colour.
- **Destructive confirmations:** `confirm()` showed a neutral filled button, while
  deleting a band and closing an organization showed an error-coloured one. The same
  helper also asked non-destructive questions (installing an update, signing out).
- **Messages:** about twenty places built their own `SnackBar`; some replaced the
  message shown, others queued behind it; some messages with an action stayed until
  tapped, others went away by themselves.
- **Status colours** were hard-coded Material colours (`Colors.green.shade600` for
  "available offline", `Colors.amber` for ChordPro problems) outside the colour
  scheme, so they ignored the theme.

Without written rules every new screen picks again, and review cannot point to
anything.

ADR-0050 (accepted, #766) already settled the layout of the **settings screen**:
titled sections with dividers, a leading icon on every option, the scope note as a
banner, enforced by `settings_layout_test.dart`. It covers one screen; the problems
above span all of them.

## Decision

1. The **UI design rules** in [`docs/development/ui-design.md`](../../development/ui-design.md)
   are binding for every management screen, dialog and panel: principles, colours,
   layout and spacing, section headers, actions, dialogs, messages, states, panels,
   texts and accessibility, and a checklist for a new screen. Live mode and the song
   renderer keep their own theme and palettes (ADR-0007, ADR-0033).
2. **Shared widgets** carry the rules, and screens use them instead of own versions:
   - `SectionHeader` (`widgets/section_header.dart`) for every section heading;
   - `confirm(destructive: …)` and `destructiveButtonStyle()` for confirmations;
     destructive is the default and fills the confirming button in the error colours;
   - `showMessage()` / `showMessageOn()` / `showMessageWithAction()` / `showUndo()`
     for every message: a new message replaces the one shown unless queued, and a
     message with an action goes away by itself;
   - `StatusColors` (a `ThemeExtension` in `theme.dart`) for success and warning,
     tuned for light and dark.
3. `app/test/ui_rules_test.dart` enforces the rules that can be found in the source
   (no own `SnackBar`, no named Material colours outside the renderer and stage theme,
   no own section header style, no own destructive button style). It runs in
   `make check`.
4. **Relation to ADR-0050:** this ADR is the app-wide base, ADR-0050 the stricter
   rules of the settings screen on top of it. `SettingsSection` builds its heading
   with `SectionHeader`, so settings sections look like every other section; the
   rest of ADR-0050 stays as decided.
5. AGENTS.md points to the rules; a change of a rule changes the document, this ADR's
   decision log and, where possible, the test.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Extend ADR-0050 to the whole app | One ADR for UI layout | Changes the scope and title of an accepted, settings-specific ADR; its settings-only rules (icon on every option, scope banner) do not fit other screens |
| Only a document, no shared widgets | Nothing to refactor | Every screen re-implements, rules drift again |
| Only shared widgets, no document | Code is the truth | Principles (undo vs. ask, when a panel, when a sheet) are not in any widget |
| Component themes in `ThemeData` (e.g. a destructive `FilledButtonTheme`) | Central | A theme cannot know which button is destructive; headers are not a Material component |
| A custom lint package | Errors in the IDE | A whole analyzer plugin for four patterns; the source test is enough for now |
| **Document + shared widgets + source test** (chosen) | Rules readable, applied by default, the checkable ones enforced | Some rules are checked in review only |

## Consequences

- New screens are faster to build and look like the others; review can point to a
  rule.
- Section headers are now bold everywhere (also the settings sections of ADR-0050), the invitations header turned primary,
  repertoire section titles use the header style, destructive confirmations are red,
  the "after live" hint goes away by itself after 8 s like the other hints.
- A deliberate exception needs a change of the document (and the test's allow list),
  not a local override.

## Decision log

- 2026-11-21: Proposed with the first set of rules and shared widgets (#743); numbered 0051 after ADR-0050 (settings screen layout) was accepted meanwhile, and related to it as the app-wide base.

## Open points

- Pages of tiles that do not yet limit their width to 720 on large screens: band,
  organization, trash and deleted bands, the MIDI test screen.
- Further rules worth enforcing in the source: tooltips on every `IconButton`,
  spacing in steps of 4.
