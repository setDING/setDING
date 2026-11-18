# ADR-0026: Drummer mode with beat display, count-in and click

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

The app was renamed to setDING because it is extended for drummers (#318). A drummer
needs other things on stage than the rest of the band:

- the **tempo and the time signature** of the song at a glance (shown as chips in the
  live header since #264, ADR-0007);
- a **beat** to check the tempo before counting the band in, and a **count-in**;
- a **click** on the in-ear monitor: the drummers play with in-ears, wired or over
  USB into the mixer, but also with Bluetooth in-ears;
- the **structure** of the song (parts, cues, drum notes) rather than the chords.

What exists today:

- `{tempo}` and `{time}` are read from the song (`Song.tempo`, `Song.time`); the time
  signature is only a string. A band arrangement can override the tempo (ADR-0025).
- The instrument setting (guitar, ukulele, bass, keyboard, vocals, other) drives the
  conditional ChordPro selectors and the chord diagrams. There is no drums preset.
- Page turners have a fixed mapping (ADR-0007); a held key does not turn again.
- No audio library is used. The roadmap lists "metronome/count-in" under *Later*.

Timing is the hard part: a click that wavers by a few milliseconds is heard on the
in-ear and is worse than no click. Dart timers jitter with garbage collection and
with the idle-time preparation of the next song (#296).

## Decision

### Drums as an instrument

- New instrument preset **Drums** (selector `drums`). Conditional ChordPro sections
  for drums (`{start_of_verse-drums}`, `{comment-drums: …}`) work through the existing
  selector context (ADR-0012).
- The drummer settings (below) are a group of the musician settings (personal,
  ADR-0027; click volume and audio delay stay on the device). They are **on by
  default** when the instrument is drums and off for other instruments; beat display,
  count-in and click can be switched on by anyone. The **song map** layout is offered
  only for drums.

### Meter model

- The `chordpro` package parses `{time}` into a meter: beats per bar, note value and
  the pulse the tempo refers to.
- **Simple meters** (2/4, 3/4, 4/4, …): one beat per quarter (or the note value), BPM
  per beat.
- **Compound meters** (6/8, 9/8, 12/8): BPM per **dotted quarter**, i.e. the felt pulse;
  6/8 has two beats per bar, each subdivided in three.
- **Odd meters** (5/8, 7/8, …): counted in eighths, BPM per eighth; accent on 1 only,
  unless the song sets a grouping with the new custom directive
  **`{x_time_grouping: 2+2+3}`** (ADR-0012), which accents the first eighth of each group.
- A missing or unreadable `{time}` means 4/4; a missing tempo means no beat (the
  controls are disabled, with a hint).
- The **time signature belongs to the song**; the band arrangement keeps overriding
  only the tempo (ADR-0025). **No tempo or meter changes within a song**: the first
  `{tempo}` and `{time}` apply.

### Click engine: the audio is the clock

- Library: **`flutter_soloud`** (MIT, SoLoud engine zlib; Android, iOS, Windows, Linux,
  web). The click sounds are synthesised, so no sound assets with licence questions.
- The engine renders **one bar** (accent on 1, the other beats, optional eighth
  subdivision) into an audio buffer at the exact sample positions for the tempo and
  meter, and **loops it**. The audio hardware keeps the time; no Dart timer triggers
  single clicks. A tempo change on stage renders a new bar and switches at the next
  bar line.
- The **visual display follows the audio**: each frame reads the playback position of
  the loop and derives the beat and its phase, shifted by the latency compensation.
  Without audio (click off or muted), the same phase is computed from a monotonic
  clock and a fixed start time, never accumulated, so a long frame delays only the
  drawing, never the beat.
- Settings: click on/off, volume, accent on 1, sound (click / woodblock / beep),
  eighth subdivision.
- **Latency compensation** as a normal drummer setting with a **calibration aid**: the
  drummer taps along with the click, the app measures the mean offset and stores it per
  device. Wired/USB output needs little, Bluetooth in-ears 100–300 ms.
- The click plays through the device's audio output; routing to the in-ear (cable,
  USB interface, Bluetooth) is up to the device and the mixer.

### Start, stop and duration

- **Start:** a drummer setting, *automatic* (a count-in starts when a song is shown in
  live mode) or *manual* (default for other instruments). Manually it is started by a
  tap on the tempo chip, by a **long press of the forward pedal** or by **Enter**.
- **Duration:** a setting *whole song* (default) or *count-in only*. The count-in is one
  or two bars (setting, default two).
- **Stop:** turning to the next or previous **set item** stops the click (turning the
  pages of the same song does not); with automatic start, the next song starts its own
  count-in. A long press of the forward pedal, Enter or a tap on the tempo chip stop it
  as well. Leaving live mode stops it.
- **Pedal:** a press of the forward key held for **at least 0.6 s** starts or stops the
  click **and does not turn**; a shorter press turns as before. The rule "one press
  turns once" (ADR-0007) stays. Enter is added to the fixed mapping as start/stop.

### Tempo on stage

- The drummer can change the tempo by **±1 BPM** and by **tap tempo** in the live control
  bar. The change applies **only until live mode is left**; it is not stored in the
  personal overlay, the band arrangement or the song. The tempo chip marks a changed
  tempo.

### Live view

- **Beat display in the header (all instruments):** next to the tempo and time
  signature chips a row of dots, one per beat (grouped for odd meters), the current one
  lit, the 1 in another colour. Chords and lyrics stay unchanged.
- **Count-in overlay:** large numbers 1–2–3–4 over the page for the count-in bars,
  with the bar ("Bar 1 of 2"); it fades out afterwards and takes no taps.
- **Edge flash (drums, optional):** the edge of the screen flashes on each beat, the 1
  in another colour, for the corner of the eye while the drummer looks at the kit.
- **Song map (drums only):** a layout instead of the chord sheet. The parts of the
  sequence (set item, band arrangement or `{x_sequence}`) as blocks with the first lyric
  line as a cue and the drum notes from `-drums` sections and comments; the current
  tempo and meter large at the top; the footer shows the next song with tempo and time
  signature. No bar counts for now. On wide screens a panel left of the map
  shows the beat large and the set (tempo and time signature per song; a tap
  turns to it). On phones (shortest side below 600 px) this panel is the
  whole stage, without the song map: beat above the set in portrait, beside it
  in landscape.
- All colours follow the stage appearance (ADR-0007) with the contrast required there.
- The beat display and the count-in never block page turns; the preparation of the
  neighbours (#296) runs as before.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Looped bar buffer, audio as the clock** (chosen) | Sample-accurate click, display always in sync with what is heard | Needs an audio library with native code; a new bar is rendered on tempo changes |
| Dart timer triggers single click samples | Simple | Jitter of several ms (GC, busy frames); audible on in-ears |
| Visual display only, no click | No audio dependency, no latency issues | The drummers play with in-ears and want the click (owner) |
| Platform channels per OS for audio | Full control | Four implementations to write and test; `flutter_soloud` covers them |
| BPM per quarter also in 6/8 | One rule | Contradicts how bands state 6/8 tempos (felt pulse) |
| Time signature per band arrangement | Bands could play a song in another meter | Rarely needed; keeps ADR-0025 small (owner) |
| Tempo changes within a song | Songs with a tempo change get the right click | The app does not know where the band is in the song (no auto-scroll); later per part with the song map |
| Live tempo stored as a personal adjustment | Kept for the next gig | A tempo adjusted on stage is a one-off; the band tempo belongs in the arrangement (owner) |
| Separate pedal key only | No change to the turning rules | Most page turners have two keys only |
| Song map for every instrument | Also useful for vocals | Owner: drums only |

## Consequences

- New dependency `flutter_soloud` (newest version, licence notice shipped); native audio
  on every platform, to be checked on a real Android tablet with wired and Bluetooth
  in-ears (latency, behaviour with the screen kept on).
- The `chordpro` package gets a meter model and `{x_time_grouping}`; the feature showcase
  and its tests are extended (ADR-0012).
- ADR-0007 gains the long press of the forward key and Enter, the beat display, the
  count-in overlay and the song map; settings and texts in both ARB files (ADR-0008).
- ADR-0025: the arrangement's tempo is what the click uses.
- The roadmap item "metronome/count-in" moves from *Later* into this ADR.

## Decision log

- 2026-11-17: Proposed with issue #325 after a discussion with the owner: visual display
  and click in the same phase (drummers play with in-ears), automatic or manual start as
  a drummer setting, click for the whole song by default and stopped by the next set
  item, start/stop by a long press of the forward pedal and by a key (Enter), tempo on
  stage only until live mode is left, latency compensation with calibration (wired and
  Bluetooth in-ears both occur), song map for drums only.
- 2026-11-17: Accepted by the owner.
- 2026-11-17: Meter model and `{x_time_grouping}` implemented in the `chordpro` package (`Meter`, `Song.meter`, #331); the showcase's second song is in 7/8 grouped 2+2+3.
- 2026-11-17: Drums instrument preset and the drummer settings implemented (#334). Following ADR-0027 they are split: a group "Beat and click" in the personal musician settings (beat display, edge flash, click, start, count-in 0–2 bars, duration, sound, accent, subdivisions, song map), synced with the account; click volume and audio delay (0–500 ms) in the device category *Screen & live mode*. Beat display, click, start, edge flash and song map follow the instrument until set (on and automatic for drums, off and manual otherwise) and are left out of the stored JSON while unset; edge flash and song map are offered for drums only.
- 2026-11-17: Click engine implemented (#332, `app/lib/audio/`): `flutter_soloud` 5.3 with its engine clock: one bar is rendered as a mono 16-bit WAV (44.1 kHz) and played in a loop with `playScheduled` from an engine time 120 ms ahead; a tempo change renders a new bar, scheduled at the next bar line, and stops the old one there (`stopScheduled`), so the switch is sample-accurate. `BeatTimeline` computes the beat from the start (bar length in whole samples, the same as the rendered bar); the display reads the playhead time, smoothed between audio buffers by the wall clock and shifted by the audio delay. Without a click or without audio (web, no device) a monotonic clock takes its place. Count-in only: the click is scheduled to stop after the count-in. Latency calibration in the device settings: the click plays at 100 BPM, the drummer taps along, the median offset of the taps (after two taps to find the beat, at least eight) is the delay.
- 2026-11-17: Live view implemented (#333, `app/lib/ui/live/live_beat.dart`): `LiveBeat` holds which item's beat runs and the tempo on stage per item (forgotten when live mode is left); the tempo chip of the header shows the tempo as played tonight ("121 BPM *" when changed) and starts or stops the beat with a tap; dots per beat beside the time signature (grouped like the meter, the 1 in the stage's chord colour), a count-in overlay with large numbers and "Bar 1 of 2", the edge flash for drums; the control bar gets a row with slower, faster, tap tempo (mean of the last five taps, a pause of two seconds starts again), back to the song's tempo and start/stop. The animated widgets read the metronome in a ticker and redraw only when the lit beat changes. Turning to another item stops the beat; with the automatic start the new song counts in (also the first song when live mode opens). The bottom bar says when the click has no audio.
- 2026-11-17: Pedal and Enter implemented (#335): only while the current song can have a beat, a forward key turns on key up, and held for 0.6 s it starts or stops the beat without turning; without a beat the forward keys turn on key down as before. Enter and Enter of the number pad start and stop the beat. The open point on page turners that send Enter for turning stays open (to check with real hardware).
- 2026-11-17: Song map implemented (#336): `songMap()` in the `chordpro` package builds the parts of the sequence (set item, band arrangement or `{x_sequence}`; for a single song its own) in its order with repetitions; a part without a number takes the next section of its kind; without a sequence (or one that matches nothing) the parts in document order, a chorus recall repeating the chorus. Each block shows the part name ("Chorus ×2"), the first lyric line as a cue and the section's comments (with the instrument drums, `{comment-drums: …}` included) in the stage's chord colour; the header keeps key, tempo, time and the beat. The bottom bar adds the next song's tempo and time signature for drums. The personal font scale applies; the song map is not fitted (it scrolls).
- 2026-11-17: Owner request (#357): on wide screens (from 900 px, the app's two-column breakpoint) the song map is on the right and a panel on the left is split in two: above, the beat of the current song large (tempo, time signature and grouping, large dots, start/stop) instead of the dots beside the title; below, the set with title, tempo and time signature per item, the current one highlighted; a tap on an item turns to it. The pages keep their state when the panel comes or goes (turning the tablet).
- 2026-11-17: Owner decision (#363): in the wide song map the tap zones (back, control bar, forward; ADR-0007) are thirds of the whole screen, not of the song area, so the middle tap is in the middle of the screen. Empty areas of the panel take part (the left third lies in the panel and turns back); the set list and the start button keep their taps.
- 2026-11-17: Click on the web client: the click engine had been switched off on web (no audio, the beat display only). SoLoud runs in the browser too, so the web client now loads `init_soloud.js` in `web/index.html` and plays the click like the apps; the browser starts the audio on the tap that starts the beat. With the server's cross-origin isolation headers SoLoud uses its AudioWorklet build, else the single-threaded one. On web the playhead time equals the engine time (no render-ahead ring), so the latency calibration covers the browser's output delay.
- 2026-11-18: Owner decision (#421): on small screens (phones, shortest side of the stage below 600 px; it takes precedence over the 900 px breakpoint, so phones in landscape count too) the song map is not shown; the drum panel fills the stage: in portrait the large beat above the set list, in landscape the beat on the left and the set on the right. There is no swipe in this view: the drummer picks the song in the set list; the page turner and the keyboard turn from song to song (no song map to scroll), and taps on empty areas of the panel keep the tap zones. In landscape the line below the page ("Next: …") is hidden while it has no notice to show, as the set list shows what comes next. The control bar leaves out key, font size, fit and Nashville (they change the song, which is not shown) and scales the tempo row down to the width of the phone. Tablets in portrait keep the song map.
- 2026-11-18: Click on devices whose audio does not answer (#422): on an Android phone the start showed Stop, but neither the beat nor the click ran, without a message. The start waited without a limit for the audio engine. It now waits at most 3 s (`Metronome.readyTimeout`); without an answer the beat runs on the monotonic clock and the bottom bar says that there is no audio for the click; a later start uses the click once the engine is ready. `SoLoudClickOutput.ensureReady()` also starts the audio device (`startAudioDevice`) on every start, because SoLoud stops an idle device and restarts it for a voice off the UI thread, where a failure only leaves silence.
- 2026-11-18: Owner request (#424): the click kept playing when the app was minimised or another app was opened. New personal setting **In the background** (`clickInBackground`): **Stop** (default) or **Keep playing**. Live mode stops the beat and the click when the app is hidden (`AppLifecycleListener.onHide`: minimised, another app, screen locked; not a split screen, where the app stays visible); it is not started again on return, also not with the automatic start. This resolves the open point on the behaviour in the background.

## Open points

- Exact long press duration (proposed 0.6 s) and whether Enter collides with page
  turners that send Enter for turning.
- Bar counts per part for the song map (`{x_bars}`), possibly later.
