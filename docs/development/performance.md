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
  `chrome://tracing`); so do the preparation of live pages
  (`LivePreparation.step` between frames, `LivePreparation.complete` when a
  page has to be built at once).
- The VM keeps the timeline in a ring buffer of about 32,000 events. The test
  records only the streams the summaries need (`Dart`, `Embedder`, `GC`) and
  long scenarios in parts (e.g. ten page turns), which the driver joins again;
  it warns when a part comes close to the buffer size. Before #296 the live
  scenarios filled the buffer, so only their last seconds were measured.

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
  always at a song change (these runs measured only the last seconds of the
  live scenarios, see the timeline buffer above and the next section):
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
change on the same base. Three runs each, times in ms. "Gaps" counts the
frames dropped on screen: pauses of 25–60 ms between two presented frames.

| song_search | frames | build avg | build p99 | build worst | build >16ms | build >8ms | raster avg | raster p99 | raster worst | raster >16ms | gaps |
|---|---|---|---|---|---|---|---|---|---|---|---|
| before, run 1 | 245 | 1.5 | 14.9 | 34.9 | 1 | 9 | 7.9 | 12.5 | 13.2 | 0 | 11 |
| before, run 2 | 262 | 1.5 | 12.4 | 41.2 | 2 | 10 | 7.9 | 11.9 | 14.1 | 0 | 10 |
| before, run 3 | 260 | 1.5 | 14.2 | 30.4 | 3 | 9 | 8.0 | 11.2 | 13.2 | 0 | 13 |
| after, run 1 | 233 | 1.1 | 4.2 | 4.6 | 0 | 0 | 8.9 | 19.7 | 25.5 | 16 | 7 |
| after, run 2 | 249 | 1.3 | 4.9 | 35.5 | 1 | 2 | 8.9 | 17.0 | 25.0 | 29 | 5 |
| after, run 3 | 241 | 1.1 | 4.5 | 5.8 | 0 | 0 | 8.9 | 17.2 | 24.6 | 27 | 3 |

In the second run after, the slow frame is a 33 ms garbage collection in
`PAINT`, the other one over 8 ms (9.5 ms) the first frame of the
scenario. Two earlier runs before the change, without the fixed
orientation and on the old application ID, had 8–9 frames over budget
(worst 40–45 ms), like the first results above.

**Findings**

- **The slow frames were the keyboard opening, not the results.** All
  frames over 8 ms fell into the about 0.4 s in which the keyboard opens at
  the first letter. Once it was open, every frame of the search (results
  arriving, highlighting, snippets, clearing) took less than 6 ms already
  before the change.
- In each frame of the keyboard animation the height of the screen
  changed, and every screen that picks its layout in a `LayoutBuilder`
  built its whole content again: the song list (the section headers of all
  400 songs and every visible song), and the sets and settings kept behind
  the other tabs of the home screen (the settings' category list alone
  took about 4 ms per frame with build profiling on). `BreakpointBuilder`
  (`app/lib/ui/widgets/breakpoint_builder.dart`) builds again only when the
  value it picks from the constraints (wide or not, the number of columns)
  changes, so the keyboard animation now takes 1–6 ms per frame on the UI
  thread. The song list also computes its section headers only when the
  songs, their order, the notation or the language change.
- A changed search keeps the songs shown until the new songs and their
  hits are both there, and then replaces them in one frame, instead of a
  progress indicator, the songs and then their highlighting in separate
  frames.
- **Fewer dropped frames, more raster frames over 16 ms.** Before, the
  keyboard animation ran at about 30 frames per second (every second frame
  dropped on the UI thread); now 3–7 gaps per run remain instead of
  10–13. The raster thread, however, has 16–29 frames over 16 ms per run
  after the change, none before:
  - in the first run, frames of the keyboard animation, now at up to 60
    frames per second, take 15–21 ms in the Impeller OpenGL ES flush
    (`ReactorGLES`, as in live mode);
  - in the other two, a stretch of about 0.5 s in which the UI thread only
    composites (under 1 ms per frame, the same frames as before the change)
    takes 16–17 ms per frame on the raster thread, exactly one frame
    interval, where it took 8 ms before. The frames are still presented
    every 16.7 ms there. The cause is not known; the GPU clocking down
    while the UI thread is idle would fit the pattern, but was not
    checked.

### 2026-11-17: Song changes without work in the turn frames (#296)

Same device. Before: main at `c58d11d`; after: the branch of #296 (main at
`e696aec` plus the change). Both recorded in parts (above), so the whole live
scenarios are measured for the first time: about 30 song changes and the
pages of the long songs and PDFs per orientation, then presses at the end of
the set. Two runs each; build = UI thread, times in ms.

| Run | Scenario | frames | build avg | build p99 | build worst | build >16ms | raster >16ms |
|---|---|---|---|---|---|---|---|
| before 1 | live_portrait | 841 | 5.1 | 78.6 | 165.5 | 69 | 200 |
| before 1 | live_landscape | 812 | 5.3 | 89.1 | 132.4 | 67 | 233 |
| before 2 | live_portrait | 843 | 5.1 | 73.6 | 186.9 | 68 | 229 |
| before 2 | live_landscape | 816 | 5.2 | 79.7 | 136.3 | 65 | 280 |
| after 1 | live_portrait | 1304 | 2.6 | 15.2 | 33.2 | 10 | 253 |
| after 1 | live_landscape | 1285 | 2.8 | 17.9 | 31.9 | 20 | 339 |
| after 2 | live_portrait | 1304 | 2.7 | 17.6 | 38.1 | 17 | 339 |
| after 2 | live_landscape | 1272 | 2.7 | 16.6 | 31.2 | 16 | 278 |

The other scenarios did not change (song list, search and editor within the
spread of earlier runs). Memory (RSS) grows more during live mode than
before: from the search step to the end of landscape +134/+142 MB before,
+193/+200 MB after. The recorded timelines stay in the app until the test
ends (they are reported at the end), and the preparation steps add about
40,000 timeline events per orientation (119,000 instead of 77,000, 31 instead
of 20 MB as JSON), which accounts for most of it. Pages are taken down after
each turn (tests check that only the neighbours stay built). Memory numbers
of `make perf` include the recorded timelines, so they are an upper bound.

**Before: every song change dropped frames in the turn animation.** Per
song change and orientation about 2–3 UI frames over budget, all in the
300 ms turn animation (26 + 30 + 13 of 69 in portrait):

- the first frame of the turn built the song after next, which the page view
  builds when it comes into its cache: `fitSong` 35–93 ms (two
  `measureBlocks` passes) plus building and laying out the song, 67–187 ms;
- the frame in the middle of the turn rebuilt all pages, because the page
  change rebuilt the live screen and with it every song (21–35 ms);
- the last frame disposed the song left behind (`FINALIZE TREE` 12–20 ms).

A long song split into pages also built its next page when it was turned to
(about 60 ms).

**After:** the neighbours are prepared in idle time after the turn
(ADR-0007): the fit runs between frames (`LivePreparation.step`), the song is
built four lines per frame (whole blocks), all its pages included, and the
song left behind is kept until the turn is over and then taken down in the
same steps; page widgets are kept, so a rebuild of the live screen does not
build the songs again. No frame of a turn fits, builds or disposes a song any
more (no `fitSong` in any frame), and the worst UI frame went from 132–187 ms to 31–38 ms. What is
left over budget:

- most frames are preparation steps in idle time (12–19 per run): laying out
  a block of the song that is not shown yet takes up to 30 ms on this device
  (a verse with chords is a few dozen paragraphs). Nothing moves on the
  screen then, so they are not visible as a stutter;
- 3–5 frames per run in a turn: the first paint of the page coming in
  (`PAINT` 13–23 ms) and young-generation garbage collections (`Scavenge`
  up to 37 ms).

The raster thread is unchanged: 250–340 frames over budget in the Impeller
OpenGL ES flush during turn animations (the earlier section counted only the
end of the scenarios).

