# ADR-0007: Live mode, no leader sync

- **Status:** Accepted (leader sync rejected)
- **Date:** 2026-11-14

## Context

During a performance the hands are on the instrument. Page turning must be possible
via foot pedal or a minimal gesture. The screen must not turn off and the display
must not change unexpectedly.

A feature found in some apps is a "leader sync": when the band leader picks the next
song, all tablets follow automatically. We evaluated whether this is needed.

## Decision

### Live mode (MVP)

- Full screen, **wakelock** active, status bar hidden.
- **Input:**
  - Bluetooth page turners (e.g. AirTurn, PageFlip, Donner) register as HID keyboards → keys **arrow left/right, Page Up/Down, space** can be mapped.
  - Tap on the left/right half of the screen, swipe.
- **Page turn modes:** full page, half page (top half already shows the next page), optional auto-scroll based on tempo/duration.
- **Layout – fit to screen (default, configurable in the settings):** the whole song fits on the screen without scrolling.
  Sections are kept whole and arranged automatically in reading order into 1–4 columns; the arrangement with the largest
  font wins (more columns only when clearly better). A repeated chorus (`{chorus}`) is shown as a short label only when
  needed to fit. Scrolling is used only if the song cannot fit at the minimum font size, or when fitting is switched off.
- **Settings:** fit to screen on/off, maximum number of columns (automatic = up to 4, or 1/2/3), repeated chorus
  (automatic / always in full / always as label), base font size.
- PDF attachments (ADR-0009) are shown in live mode with the same page-turn input.
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

## Open points

- Is a page turner already in use? Which model (for testing)?
- Is MIDI control desired (e.g. Program Change from a keyboard/pedalboard)?
