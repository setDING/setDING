# Performance on devices

RealChord's first quality goal is reliability on stage (architecture README,
section 2). Unit and widget tests cannot show whether page turns stay smooth
on a real tablet, so `make perf` measures the stage-relevant paths on a
USB-connected Android device (issue #270).

## Running the measurement

```bash
make perf                 # one device connected
make perf DEVICE=<id>     # several devices: id from `adb devices`
```

- Turn on USB debugging on the device and accept the computer's key.
- [`tool/perf.sh`](../../tool/perf.sh) builds the app in **profile mode** and
  runs [`app/integration_test/performance_test.dart`](../../app/integration_test/performance_test.dart)
  with `flutter drive`; [`app/test_driver/perf_driver.dart`](../../app/test_driver/perf_driver.dart)
  writes the timelines and summaries to `app/build/perf/`, and
  [`tool/perf-summary.py`](../../tool/perf-summary.py) prints a table.
- The test runs in the app's **own data directory** on the device. The first
  run seeds 400 songs, two PDF-only songs (a 6-page scan-like PDF close to the
  20 MB limit and a small one) and a set of 30 songs; later runs reuse them.
  The script refuses to run when a RealChord **release** build (not
  debuggable, e.g. installed with Obtainium) is on the device, because the test
  build would replace it together with its data.
- Semantics are switched off in the test (the `testWidgets` default would add
  their cost to every frame); they only run when an accessibility service such
  as TalkBack is active.
- `fitSong` and `measureBlocks` emit timeline events, so slow frames can be
  attributed in the timelines (`*.timeline.json`, e.g. in Perfetto or
  `chrome://tracing`).

### Scenarios

| Key | What happens |
|---|---|
| `song_list_scroll` | Six flings down and up through the library of 400 songs, in portrait |
| `song_search` | Four queries typed letter by letter (120 ms apart), each cleared, in portrait; the keyboard opens at the first letter |
| `live_portrait` | Live mode of the set in portrait, 90 page turns with the arrow key |
| `live_landscape` | The same in landscape (PDF spreads, more columns) |
| `editor_typing` | Typing a line into a long song with the live preview |

The budget per frame is 16.7 ms at 60 Hz, for the UI thread (build) and the
raster thread each.

## Results

### 2026-11-17: Samsung Galaxy Tab S5e (SM-T720)

Snapdragon 670 (Adreno 615), 3.7 GB RAM, Android 15, 1600 × 2560 px at
60 Hz; Impeller with the **OpenGL ES** backend. Profile build of main at
`f65a6e6` plus timeline markers. Times in ms.

| Scenario | frames | build avg | build p99 | build worst | build >16ms | raster avg | raster p99 | raster worst | raster >16ms |
|---|---|---|---|---|---|---|---|---|---|
| song_list_scroll | 322 | 0.5 | 0.8 | 1.3 | 0 | 8.3 | 10.8 | 12.7 | 0 |
| song_search | 257 | 1.7 | 23.9 | 29.5 | 9 | 6.5 | 9.3 | 32.8 | 1 |
| live_portrait | 173 | 2.1 | 34.4 | 77.1 | 6 | 10.7 | 20.7 | 27.5 | 9 |
| live_landscape | 173 | 2.2 | 33.9 | 97.1 | 6 | 11.7 | 26.7 | 31.1 | 18 |
| editor_typing | 44 | 1.0 | 2.3 | 2.3 | 0 | 5.8 | 8.9 | 8.9 | 0 |

A second run with `make perf` gave the same picture with some spread on the
raster thread: live mode 5–6 build frames over budget (worst 72–90 ms),
4 (landscape) and 20 (portrait) raster frames over budget (worst 32–56 ms),
search 5 frames over budget (worst 78 ms). Compare runs by their order of
magnitude, not single frames.

Memory (RSS): 238 MB after start, 296 MB after the song list, 335 MB after
live mode in portrait, 389 MB after landscape (incl. the large PDF), peak
416 MB; no further growth in the editor.

Start-up: cold start to the first Android frame 1.2–1.4 s (`am start -W`,
three runs); Flutter's first frame (the splash) 0.29 s after the engine starts
(`--trace-startup`).

**Findings**

- **Song list and editor are smooth:** no frame over budget, also with 400
  songs and the live preview.
- **Search:** about two frames per query over budget (18–30 ms) when the
  results arrive; the time is in layout and build of the result list
  (highlighted titles and lyrics snippets). Not stage-relevant, slightly
  visible as a stutter while typing. (A closer look in #297 found these
  frames while the keyboard opens, not when the results arrive; see below.)
- **Live mode, UI thread:** 6 of 173 frames over budget per orientation,
  i.e. a few dropped frames per run of 90 turns, always at a song change:
  - one frame of 77–97 ms when a song is fitted for the first time
    (`fitSong` 42 ms, of which `measureBlocks` 27–30 ms); the fit cache
    makes later visits cheap;
  - frames of 29–38 ms in which the next song, built ahead since #262, is
    built and laid out, or the previous one is disposed (`FINALIZE TREE`
    13–25 ms). These happen at the start of the turn animation, where a
    dropped frame is most visible.
- **Live mode, raster thread:** 9 (portrait) and 18 (landscape) frames over
  budget, worst 27–31 ms, all in the Impeller OpenGL ES flush
  (`ReactorGLES`) during turn animations; the average (11–12 ms) leaves little
  headroom on this GPU.
- No blank pages were seen at turns; the large PDF renders without visible
  delay in the timelines.
- **Accessibility:** with semantics on (accessibility services active), song
  changes cost another 30–55 ms per frame (`SEMANTICS`) for the text of the
  song pages.

### 2026-11-17: song search (#297)

Same tablet, profile builds. The song list and search scenarios now run in
portrait whatever position the tablet was left in (in landscape the
keyboard did not resize the app, so its frames were missing from the
measurement). Before: main at `826edfb` with that change; after: this
change on the same base. Two runs each, times in ms.

| song_search | frames | build avg | build p99 | build worst | build >16ms | raster avg | raster p99 | raster worst | raster >16ms |
|---|---|---|---|---|---|---|---|---|---|
| before, run 1 | 245 | 1.5 | 14.9 | 34.9 | 1 | 7.9 | 12.5 | 13.2 | 0 |
| before, run 2 | 262 | 1.5 | 12.4 | 41.2 | 2 | 7.9 | 11.9 | 14.1 | 0 |
| after, run 1 | 233 | 1.1 | 4.2 | 4.6 | 0 | 8.9 | 19.7 | 25.5 | 16 |
| after, run 2 | 249 | 1.3 | 4.9 | 35.5 | 1 | 8.9 | 17.0 | 25.0 | 29 |

Frames with more than 8 ms of build time: 9–10 per run before, none after
(the one frame over budget in the second run after is a 33 ms garbage
collection in `PAINT`). Two earlier runs before the change, without the
fixed orientation, had 8–9 frames over budget (worst 40–45 ms), like the
first results above.

**Findings**

- **The slow frames were the keyboard opening, not the results.** All
  frames over 8 ms fell into the about 0.4 s in which the keyboard opens at
  the first letter. Once it was open, every frame of the search (results
  arriving, highlighting, snippets, clearing) took less than 6 ms.
- In each frame of the keyboard animation the height of the screen
  changed, and every screen that picks its layout in a `LayoutBuilder`
  built its whole content again: the song list (the section headers of all
  400 songs and every visible song), and the sets and settings kept behind
  the other tabs of the home screen (the settings' category list alone
  took about 4 ms per frame). `BreakpointBuilder`
  (`app/lib/ui/widgets/breakpoint_builder.dart`) builds again only when the
  value it picks from the constraints (wide or not, the number of columns)
  changes, so the keyboard animation now takes 1–5 ms per frame on the UI
  thread. The song list also computes its section headers only when the
  songs, their order, the notation or the language change.
- A changed search keeps the songs shown until the new songs and their
  hits are both there, and then replaces them in one frame, instead of a
  progress indicator, the songs and then their highlighting in separate
  frames.
- **Raster thread:** the keyboard animation now runs at up to 60 frames per
  second instead of about 30, and with the OpenGL ES backend of Impeller
  its frames take 15–21 ms on the raster thread (`ReactorGLES` flush, as
  in live mode), so they count as raster frames over budget (16 and 29 per
  run after, none before). The animation is still smoother than before,
  where every second frame was dropped on the UI thread.
