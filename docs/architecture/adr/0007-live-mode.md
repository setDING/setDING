# ADR-0007: Live mode, no leader sync

- **Status:** Accepted (leader sync rejected)
- **Date:** 2026-11-14

## Context

During a performance the hands are on the instrument. Page turning must be possible
via a minimal gesture (tap, swipe) or, later possibly, a foot pedal. The screen must not turn off and the display
must not change unexpectedly.

A feature found in some apps is a "leader sync": when the band leader picks the next
song, all tablets follow automatically. We evaluated whether this is needed.

## Decision

### Live mode (MVP)

- Full screen, **wakelock** active, status bar hidden.
- **Input:**
  - Tap on the left/right part of the screen, swipe.
  - Foot pedals (Bluetooth page turners registering as HID keyboards) are **not supported for now** (removed in #149); they may return later. Escape leaves live mode.
- **Page turn modes:** full page, half page (top half already shows the next page), optional auto-scroll based on tempo/duration.
- **Layout – fit to screen (default, configurable in the settings):** the whole song fits on the screen without scrolling.
  Sections are kept whole and arranged automatically in reading order into 1–4 columns; the arrangement with the largest
  font wins (more columns only when clearly better). A repeated chorus (`{chorus}`) is shown as a short label only when
  needed to fit. A long song is split into **pages** (up to 4) when that gives a clearly larger font than one page;
  pages continue the columns in reading order, each page filled as far as it goes. A font above the base font size is
  no reason for another page, and `{column_break}`/`{new_page}` in the song keep it on one page. Tapping right/left
  (or swiping left/right) turns the pages of the song before turning to the next/previous song; the bottom bar shows the page (e.g. "Page 1/2").
  The *half page* setting does not apply to song pages. Scrolling is used only if the song does not fit even on pages
  (a single section taller than the page at the minimum font size), or when fitting is switched off.
- **Chords or Nashville on stage:** a toggle in the middle of the control bar switches the current song between chord
  names and Nashville numbers (personal per-song Nashville overlay, ADR-0006); it is disabled when the song has no key.
  On narrow screens it gets a row of its own above the other controls.
- **Font size on stage:** the control bar (tap in the middle of the screen) makes the text smaller or larger (personal
  font scale, ADR-0006); larger text is split into as many pages as needed instead of scrolling, with fewer columns
  when chord lines would not fit. A *fit to page* button fits the song again: with fitting on, it resets the scale to 100 %,
  i.e. the fitted size; with fitting off, it sets the scale at which the song fits the page with the configured columns
  and chorus display (between 50 % and 250 %).
- **Song screen (outside live mode):** the song is fitted to the visible area in the same way (fit to screen setting,
  columns and repeated chorus as in live mode, personal font scale on top, no pages). When it does not fit, or with
  fitting switched off, it keeps the base font size and is split into the fewest columns with which it fits; if none
  does, into as many columns as the width allows (each at least 220 px and wide enough for the chord lines) and it
  scrolls.
- **Settings:** fit to screen on/off, maximum number of columns (automatic = up to 4, or 1/2/3), repeated chorus
  (automatic / always in full / always as label), base font size.
- **Only the parts of the sequence:** in the live mode of a set, a song with a sequence (set item, band arrangement or
  the song's own `{x_sequence}`, ADR-0006/ADR-0025) shows only the sections whose part appears in it (`V` matches every
  verse, `V2` only the second). The song stays in document order; order and repetitions of the sequence are not
  applied. Sections that are no part (unlabelled, tab, grid) stay. The header says which parts are hidden
  ("Hidden (not in the sequence): V3, B"). If the sequence matches none of the song's parts, the song is shown whole.
  A single song played outside a set is always shown whole.
- **Key and tempo at a glance:** the live header shows the key as played (band arrangement, set item transposition
  and capo, ADR-0025), the tempo and the time signature as large chips beside the title (below it on narrow
  screens); the song is fitted to the space below the header. The song screen keeps the compact info line.
- PDF attachments (ADR-0009) are shown in live mode with the same page-turn input.
- **Next song prepared ahead:** the direct neighbours of the current item (previous and next) are built and fitted
  before the turn, PDFs opened (landscape spreads also rendered), so turning never shows an empty or half-laid-out
  page. Items further away are not kept, so memory stays bounded in long sets.
- At the end of a song → next item in the set; footer preview "Next: *Title* (key)".
- Quick jump to any song of the set (set overview), e.g. when the set order changes spontaneously on stage.
- **Sync freeze:** Incoming changes are not applied automatically in live mode but shown as a discreet notice.

### No leader sync

**Every member navigates independently.** There is no synchronized navigation
between devices – neither over the local network nor via the backend.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Independent navigation** (chosen) | Simple, no network on stage required, no single point of failure | Spontaneous set changes must be announced verbally |
| Leader sync via LAN/WebSocket | Works without internet, low latency | Same Wi-Fi for all devices required, considerable effort (discovery, permissions, multi-device testing) |
| Leader sync via backend (realtime) | Infrastructure exists | Requires internet → violates ADR-0001 |

## Consequences

- No local network communication between devices → no iOS "Local Network" permission or firewall issues.
- Navigation in live mode still goes through a central `LiveController` (local input only), which keeps the live logic testable and leaves room for a later extension.

## Decision log

- 2026-11-14: Leader sync is not needed and is removed from the roadmap. Each member turns pages on their own device.
- 2026-11-14: In live mode the song is fitted to the screen without scrolling; sections are arranged in columns automatically. Fitting, maximum columns and the display of repeated choruses are configurable in the settings.

- 2026-11-15: Sync is paused while live mode is open; a sync requested meanwhile runs after leaving live mode (issue #17, ADR-0004).
- 2026-11-16: Foot pedal / keyboard page turning removed, not needed for now; may be implemented again later (issue #149). Tap and swipe remain.
- 2026-11-17: In the live mode of a set, only the parts of the song sequence are shown; the header names the hidden parts (issue #257).
- 2026-11-17: The previous and next item are built and fitted ahead (PDFs opened, landscape spreads rendered), only the direct neighbours are kept (issue #262).
- 2026-11-17: Key, capo, tempo and time signature are shown as large chips in the live header instead of a small info line (issue #264).

## Open points

- Foot pedal support again later? Which page turner model (for testing)?
- Is MIDI control desired (e.g. Program Change from a keyboard/pedalboard)?
- 2026-11-16: Fit-to-page button in the live control bar next to the font size buttons; resets the personal font scale to the fitted size (issue #173).
- 2026-11-16: Fit to page also works with fitting switched off: it measures the font scale that fits the page (issue #175).
- 2026-11-16: Long songs are split into pages instead of shrinking far or scrolling: pages only for a clearly larger font, enlarged text (personal scale above 100 %) is paged too, half-page turning does not apply to song pages (issue #177).
- 2026-11-16: Swiping turns pages exactly like tapping: the scroll position, the pages of a song and PDF spreads/pages first, then the next/previous song (issue #181).
- 2026-11-16: The song screen fits the song to the visible area like live mode; a song that does not fit is split into columns and scrolls (issue #183).
- 2026-11-16: Chords/Nashville toggle in the middle of the live control bar, stored as the personal per-song Nashville overlay (issue #184).
