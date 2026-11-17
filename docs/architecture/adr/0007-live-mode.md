# ADR-0007: Live mode, no leader sync

- **Status:** Accepted (leader sync rejected)
- **Date:** 2026-11-14

## Context

During a performance the hands are on the instrument. Page turning must be possible
via a minimal gesture (tap, swipe) or a foot pedal. The screen must not turn off and the display
must not change unexpectedly.

A feature found in some apps is a "leader sync": when the band leader picks the next
song, all tablets follow automatically. We evaluated whether this is needed.

## Decision

### Live mode (MVP)

- Full screen, **wakelock** active, status bar hidden.
- **Screen stays on:** a `StageWakeLock` (`app/lib/platform/stage_wake_lock.dart`, on top of `wakelock_plus`) keeps
  the screen on while a live view is open. It counts the open live views and turns the screen's wake lock off only
  when none is left, applying each change in order, so leaving live mode and opening it again right away never lets
  the screen turn off. When the app returns to the foreground the wake lock is set again, since not every platform
  keeps it in the background. If the platform does not keep the screen on (it throws, or reports it off afterwards,
  e.g. Linux without a desktop portal or a browser without the Screen Wake Lock API), the bottom bar says so
  ("The screen may turn off – check the device's power settings") and the log records it. The app cannot stop the
  power button, an empty battery or the user leaving the app; on stage the tablet belongs on the charger, and
  leaving the app by accident is up to the operating system (iOS Guided Access, Android screen pinning).
- **Input:**
  - Tap on the left/right part of the screen, swipe.
  - **Bluetooth page turners** (foot pedals registering as HID keyboards) and keyboards: **right arrow, down arrow,
    Page Down and Space** turn forward, **left arrow, up arrow and Page Up** back, exactly like the right/left tap zones
    (the scroll position, the pages of a song and PDF pages/spreads first, then the next/previous song). Down/up arrow
    cover page turners switched to an up/down mode; in a song that scrolls (it does not fit, or fitting is off) they
    scroll it first by the same step as the tap zones, not line by line. The mapping is fixed (not configurable).
    One press turns once: a held key (key repeat) does not turn again, so it never races through the set. The keys are
    taken before the focused widget (an early key handler of the focus manager), so they work whichever widget of live
    mode has the focus, and Space never presses a focused button; while a dialog, sheet or menu opened from live mode
    is on top, and in text fields, the keys stay theirs. Escape leaves live mode.
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
- **More pages at a glance:** the bottom right corner of the page says whether more of the current song follows, so it
  is seen from the corner of the eye instead of read in the bottom bar. While a tap or key would still turn within the
  song (a further song page, a scrolled song not at its end, a further PDF page or spread), a **folded corner** in the
  accent colour sits in the corner; on the last page a quiet **final barline** (thin and thick line, in the page
  margin) marks the end of the song. Pauses and texts show neither. It is an overlay above ChordPro and PDF alike and
  never takes taps, so the right tap zone works under it. On by default, can be switched off in the live settings
  ("Show more pages at a glance").
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
  (automatic / always in full / always as label), base font size, appearance on stage, more pages at a glance.
- **Appearance on stage:** a per-device setting independent of the app theme: *as app* (default), *dark* (also when
  the app is light) or *black* (true black page, very dark bars, e.g. for OLED screens). The live view, its control
  bar, the bottom bar, the set overview and the PDF background follow it. Chords are drawn in a stronger colour than
  elsewhere in the app, with a contrast of at least 7:1 in every variant: deep brand red on light, amber on dark and black.
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
  page. They are prepared in idle time after a turn, never in the frames of a turn animation, where a long frame
  would be a visible stutter: the fit runs between frames, the song is built a few lines per frame (all its pages,
  so turning a page of the song only shows another one), and the page left behind is kept until the turn is over
  and then taken down the same way. A turn to a page that is not fully
  prepared yet (turning faster than the preparation, a jump from the set overview) builds it at once. Items further
  away are not kept, so memory stays bounded in long sets.
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
- 2026-11-16: Fit-to-page button in the live control bar next to the font size buttons; resets the personal font scale to the fitted size (issue #173).
- 2026-11-16: Fit to page also works with fitting switched off: it measures the font scale that fits the page (issue #175).
- 2026-11-16: Long songs are split into pages instead of shrinking far or scrolling: pages only for a clearly larger font, enlarged text (personal scale above 100 %) is paged too, half-page turning does not apply to song pages (issue #177).
- 2026-11-16: Swiping turns pages exactly like tapping: the scroll position, the pages of a song and PDF spreads/pages first, then the next/previous song (issue #181).
- 2026-11-16: The song screen fits the song to the visible area like live mode; a song that does not fit is split into columns and scrolls (issue #183).
- 2026-11-16: Chords/Nashville toggle in the middle of the live control bar, stored as the personal per-song Nashville overlay (issue #184).
- 2026-11-17: In the live mode of a set, only the parts of the song sequence are shown; the header names the hidden parts (issue #257).
- 2026-11-17: The previous and next item are built and fitted ahead (PDFs opened, landscape spreads rendered), only the direct neighbours are kept (issue #262).
- 2026-11-17: Key, capo, tempo and time signature are shown as large chips in the live header instead of a small info line (issue #264).
- 2026-11-17: Appearance on stage (as app / dark / black) independent of the app theme, with stronger chord colours in live mode (issue #263).
- 2026-11-17: Page turning with Bluetooth page turners and the keyboard is back, reversing the removal of 2026-11-16 (#149/#152): right arrow, Page Down and Space forward, left arrow and Page Up back, like the tap zones; fixed mapping; key repeat is ignored (one press turns once). Resolves the open point "Foot pedal support again later?" (issue #261).
- 2026-11-17: The light stage chord colour follows the brand palette: deep brand red `#852309` instead of indigo (issue #269).
- 2026-11-17: Down arrow also turns forward and up arrow back, for page turners switched to an up/down mode, with the same behaviour as the other keys (scroll position first, key repeat ignored, text fields of dialogs keep them). Answers the key mapping part of the open point on page turners: a fixed mapping covering both modes instead of a configurable one (issue #286).
- 2026-11-17: The stage follows the accent colour chosen in the settings: on light the chords use a deep tone of the accent (brand red `#852309` by default), the dark and black stage use the accent's dark scheme; chords on dark and black stay amber for every accent (issue #300).
- 2026-11-17: The screen stays on reliably: the wake lock counts the open live views and applies changes in order, is set again when the app returns to the foreground, and a wake lock that does not hold is shown in the bottom bar (issue #294).
- 2026-11-17: A folded corner at the bottom right shows that more of the song follows (song pages, scrolling, PDF pages and spreads), a final barline marks its last page; can be switched off in the live settings (issue #305).
- 2026-11-17: The neighbours are prepared in idle time after a turn instead of in the first frames of the turn animation: the fit runs between frames, the song is built a few lines per frame, the page left behind is taken down after the turn in the same way; a turn to a page that is not prepared yet builds it at once. All pages of a song are built, so turning a page of the song only shows another one; rebuilding the live screen (e.g. when the page changes) no longer builds the songs again (issue #296).

## Open points

- Windows: `wakelock_plus` requests only `ES_DISPLAY_REQUIRED`. Check on a real Windows tablet that it does not go to
  sleep during a long song; if it does, additionally request `ES_SYSTEM_REQUIRED` (issue #294).
- Which page turner model (for testing on real hardware)? Configurable key mapping needed for pedals sending other keys?
- Is MIDI control desired (e.g. Program Change from a keyboard/pedalboard)?
