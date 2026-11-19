# ADR-0039: MIDI program change per song in live mode

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

Keyboard players change the sound of their instrument between songs: piano for
one song, organ for the next, a pad for a ballad. Today they look for the right
program on the keyboard by hand while the band waits. Many stage keyboards,
among them the **Nord Stage 3** of the owner's band, switch programs by MIDI:

- a **Bank Select** (CC 0 = MSB, CC 32 = LSB) followed by a **Program Change**;
- on the Nord Stage 3 (checked on a keyboard with OS 2.54, #512): 400 programs in 16 banks
  A–P of 25 (5 pages of 5 buttons, the display shows e.g. `K:33`), counted
  through and sent in blocks of 125: CC 0 = 0, CC 32 = block 0–3, Program Change
  = place in the block 0–124. Songs use CC 0 = 1 and the same blocks with 5
  parts per song. The five live memories are sent by the Nord as CC 0 = 6,
  CC 32 = 0, Program Change 0–4. Received on the keyboard's global channel when "Program
  Change" reception is switched on in its MIDI menu. The bank select must come
  before the program change.

Since OS 2 the Nord Stage 3 also has **Songs** (a set of programs as song
parts). According to users in the Nord User Forum, bank select MSB 0 addresses
programs and MSB 1 songs, and an OS update changed the song numbering; Nord
publishes no MIDI chart for this. A program change without the full bank select
was handled differently depending on the panel mode until a Nord OS fix.

setDING is meant for any band, not only the owner's, so Nord users who work with
programs and those who work with Nord songs both have to be served.

ADR-0007 lists "Is MIDI control desired?" as an open point. ADR-0026 already
added a native dependency for audio, so a native MIDI dependency is not new in
kind.

Constraints:

- The program depends on the **person and their keyboard**, not on the song or
  the band: another band's keyboard player has other programs. The same person
  usually plays the same keyboard in all their bands.
- Live mode must stay calm (ADR-0007): no dialogs, no surprises, nothing that
  blocks turning pages.
- Older clients push the whole `data` JSON of a personal overlay
  (`overlay_sync.dart`, ADR-0020) and drop keys they do not know. A new key in
  `data` would be erased as soon as an older device of the same person changes
  the overlay.
- The owner's keyboard player uses an iPad today; there is no iOS build yet
  (ADR-0021). The band also has Android and Windows devices.
- Browsers offer the Web MIDI API in Chrome and Edge (also on Android), not in
  Safari and not in any browser on iOS.

## Decision

### Scope of the first version

When a song becomes the current song in **live mode**, setDING sends the MIDI
program stored for that song to **one** keyboard connected **by USB**. Nothing
else is sent automatically.

| In the first version | Later (own decision) |
|---|---|
| Program per song, personal and synced | Learning the program from the keyboard |
| Sending in live mode (start, song change), "Send again" | Program changes per section (custom directive, e.g. `{x_midi: …}`) |
| Device profiles: Nord Stage 3 and generic | Page turning by MIDI from the keyboard |
| USB on Android, Windows, Linux; web in Chrome/Edge | Bluetooth MIDI |
| | Several target devices per tablet |
| | iOS (with the iOS app) |

### Program per song: personal overlay, own server field

- The program is part of the **personal overlay** (layer 3, ADR-0006, ADR-0020):
  per person and song, private, synced with the account, the same in all bands.
- It is stored as **raw MIDI values**, independent of the profile:
  `{ "msb": 0, "lsb": 2, "program": 12 }`. `msb` and `lsb` are optional (no bank
  select). The profile only translates between these values and what the
  musician sees, so a stored program stays valid when the profile changes.
- On the server the `overlays` collection gets a **separate JSON field `midi`**,
  not a key in `data`. Older clients send only `data` and `deleted`, so PocketBase
  keeps `midi` untouched when they change other adjustments. Locally,
  `personal_overlays` gets a nullable `midi` column (new schema version).
- Last writer wins, as for the rest of the overlay. Deleting the song deletes it
  with the overlay.

### Device settings: profile, output, channel

The MIDI settings belong to the hardware on the stage, so they are **device
settings** (layer 4b, ADR-0027), never synced:

| Setting | Values | Default |
|---|---|---|
| MIDI program changes | on / off | off |
| Output | a connected USB MIDI device, remembered by name | none |
| Profile | Nord Stage 3, Generic | Nord Stage 3 |
| Nord addresses (Nord profile only) | Programs, Songs | Programs |
| Channel | 1–16 | 1 |

- **Nord Stage 3 profile** with a device setting **"Nord addresses: Programs |
  Songs"**, chosen by the keyboard player (default Programs):
  - *Programs:* bank A–P, page 1–5 and button 1–5 as on the display (sent as
    CC 0 = 0, CC 32 = number ÷ 125, Program Change = number mod 125, where
    number = bank × 25 + (page − 1) × 5 + button − 1), or live memory 1–5
    (CC 0 = 6, CC 32 = 0, Program Change 0–4).
  - *Songs:* song and part 1–5, sent as CC 0 = 1 and the same blocks of 125
    with number = (song − 1) × 5 + part − 1.
  - The full bank select (MSB and LSB) is always sent before the program change,
    so the result does not depend on the Nord's current panel mode.
  - A stored value is shown by its MSB (program or song), so values entered in the
    other mode stay readable after the setting changes.
  - The settings explain that "Program Change" reception must be on in the Nord's
    MIDI menu, that the channel is the Nord's global channel, and that the
    numbering of songs depends on the Nord's OS version.
- **Generic profile:** bank select MSB and LSB (each optional, 0–127) and program
  1–128. It is also the fallback for every case a profile does not cover, e.g. a
  Nord OS version with another numbering.
- Further profiles can be added without a data change.

### Editing

- The song screen's personal adjustments get a **"Keyboard program"** field, shown
  when MIDI program changes are on for this device or when the song already has a
  program. It is edited in the terms of the profile (e.g. "Bank C, program 13")
  and can be removed.
- A **"Test"** button next to it sends the program once, when an output is
  connected. This is an explicit action; outside live mode nothing is sent
  automatically.
- The web client offers the field as on any device (ADR-0018).

### Sending in live mode

- When a song becomes the **current** song (live mode starts, or a page turn,
  tap or set list jump reaches another song), setDING sends, in this order:
  bank select MSB (if set), bank select LSB (if set), program change, on the
  device's channel.
- Preparing the neighbouring songs ahead (ADR-0007) sends nothing.
- A song **without a program sends nothing**: the keyboard keeps its program.
  Breaks and text items of a set send nothing either.
- The live menu has **"Send program again"** (e.g. after the keyboard was
  restarted).
- If no output is connected, nothing is sent and nothing is shown in the way:
  a small MIDI indicator in the live header shows connected / not connected only
  while MIDI program changes are on. Errors are logged, never shown as dialogs.
- When the remembered device is plugged in again, setDING reconnects to it
  without asking.

### Platforms and library

- MIDI is behind a small interface (`MidiOutput`: list devices, connect, send
  bytes, connection state), with a fake for tests.
- Implementation with **`flutter_midi_command`** (BSD-3-Clause, compatible with
  MIT; newest version, licence notice shipped): USB MIDI on Android, Windows and
  Linux, and Web MIDI in the browser. Bank select and program change are sent as
  raw MIDI bytes with `sendData` (or `sendDataAwaitingDelivery`).
- **Prototype first:** the first implementation issue is a prototype that sends
  bank select and program change from Android, Windows, Linux and Chrome to a
  real Nord Stage 3, in both Programs and Songs mode, and records the Nord's OS
  version and the song addressing that works. The feature is built only after
  it; if the library fails on a platform, another one from the table below is
  chosen, and if songs cannot be addressed reliably, the Songs mode is left out
  (the generic profile stays as the way out).
- **Web:** Chrome and Edge, after the browser's permission prompt; other browsers
  show a hint that MIDI is not available there. Live mode on web keeps its notice
  (ADR-0018).
- **iOS:** CoreMIDI support comes with the iOS app (ADR-0021); until then the
  keyboard player uses an Android or Windows device for MIDI.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Personal overlay** (chosen) | The program belongs to the person and their keyboard; same in all bands; synced to all their devices | The same song cannot have different programs in two bands |
| Band arrangement (ADR-0025) | Visible to the band next to key and tempo | Only leaders and set planners may edit it; a keyboard player in several bands maintains it several times; another keyboard player in the band has other programs |
| Personal per band and song | Different sounds per band possible | New table and sync for a rare case (owner) |
| Directive in the ChordPro text (`{x_midi: …}`) | Travels with the song | Changes the shared song for one person's keyboard (contradicts ADR-0006); kept for later as program changes per section |
| Key in the overlay `data` JSON | No server migration | Older clients erase it when they change the overlay |
| Nord programs only | Documented by Nord, no OS-dependent numbering | Keyboard players who organize their sounds as Nord songs are left out; setDING is for every band (owner) |
| Raw values only, no profiles | Simplest | Musicians think in "Bank C, program 13", not in CC 32 = 2, PC = 12 |
| USB and Bluetooth in the first version | Wireless on stage | Pairing and permissions per platform, no Bluetooth on Linux and web; USB is the most reliable (owner) |
| Sending also outside live mode | Practising at home switches sounds too | The keyboard would switch while songs are browsed or edited (owner) |
| A default program for songs without one | Always a defined sound | Unpredictable when songs are played without a change on purpose (owner) |
| `libremidi_flutter` | Stable, Windows MIDI Services | No web |
| `aud_midi` | Newest, MIDI 2.0 | Desktop backends experimental |
| Own platform channels | Full control | Four implementations to write and test |

## Consequences

- New native dependency; its licence notice is shipped. The Android app may need
  the USB host feature declared (optional, so devices without it still install).
- Server migration: `overlays.midi` (JSON, optional). Older clients keep working
  and do not erase it, so this is a **minor** version (ADR-0028); no new minimum
  client version (ADR-0029).
- Local schema: `personal_overlays.midi`; the overlay sync pushes and pulls it.
- New device settings category (or group in *Screen & live mode*) with UI texts in
  `app_de.arb` and `app_en.arb`.
- Tests: profile translation (Nord Stage 3 programs and songs, generic, both
  directions), the
  live mode sends exactly once per song change and never for prepared neighbours,
  nothing for songs without a program or for breaks, overlay sync of `midi`
  (including an older client's push that leaves it untouched, server test).
  Manual test with a Nord Stage 3 on Android, Windows, Linux and in Chrome
  (first in the prototype).
- The user documentation (ADR-0030) gets a page on connecting a keyboard.
- ADR-0007's open point on MIDI control is answered by this ADR.

## Decision log

- 2026-11-18: Proposed after discussing the scope with the owner (#510): the
  program is personal (personal overlay), sent only in live mode, nothing for
  songs without a program, USB only, device profiles with the Nord Stage 3
  first, web in Chrome/Edge; MIDI before iOS, as the band also has Android and
  Windows devices.
- 2026-11-18: Stored in a separate `overlays.midi` field instead of the overlay
  `data` JSON, because older clients rewrite `data` without unknown keys.
- 2026-11-18: Owner answers on the open points: the "Test" button is part of the
  first version; the Nord profile serves both programs and Nord songs, chosen by
  the keyboard player in the device settings, since setDING is for every band;
  the first implementation step is a prototype on all platforms with a real Nord
  Stage 3 (`flutter_midi_command` offers `sendData` for raw bytes); the later
  stages stay listed in this ADR, with issues only once one is taken up.
- 2026-11-18: Accepted by the owner (#510).
- 2026-11-18: Prototype implemented (#512): `flutter_midi_command` 1.4 behind
  `MidiOutput` (`app/lib/midi/`), the message bytes and the Nord Stage 3
  addressing in `midi_message.dart`, and a "MIDI test (prototype)" screen in
  the *Screen & live mode* settings that lists USB MIDI devices, sends Nord
  programs, songs, live memories or raw values on a chosen channel and logs
  what the keyboard sends back (to find the song addressing). The plugin
  requires the Android MIDI feature in its manifest; the app overrides it to
  optional. Linux loads `libasound.so.2` at run time; the web plugin asks for
  MIDI access with SysEx, so Chrome shows the stronger permission prompt.
  Results on the real keyboard are pending.
- 2026-11-19: The MIDI test also sends free control changes (#512): midi.guide
  lists CC 2 "Live mode", CC 3 "Song mode" and CC 5 "Song part" for the Nord
  Stage 3 without their values, a second candidate for selecting Nord songs
  besides bank select MSB 1. The midi.guide data (CC BY-SA 4.0) is a reference
  only and is not copied into the repository.
- 2026-11-19: First test on the owner's Nord Stage 3 with Android (#512, OS
  version not read). `flutter_midi_command` sends and receives over USB.
  Programs: the assumed banks A–H of 50 were wrong; the Nord has 16 banks A–P
  of 25 and counts them through in blocks of 125 (sent LSB 2 / PC 12 showed
  K:33, LSB 7 / PC 49 the last program P:55; the Nord itself never sent a
  program change above 124). Live memories 1–5 = PC 50–54 without bank select
  work as assumed. CC 3 = 127 switches the song mode on, CC 3 = 0 off. Bank
  select MSB 1 changes the song, its numbering is unknown. CC 5 (song part) and
  CC 2 (live mode) showed no effect. When a program, song or live memory is
  chosen on the Nord, it sends bank select and program change (MSB 0 programs,
  MSB 1 songs, MSB 6 with PC 0–4, probably the live memories), never CC 2, 3
  or 5. None of this is on midi.guide. The addressing is corrected, and the
  MIDI test got a guided test that needs only taps (send a step, tap what
  happened) and no setting on the Nord, to find the song numbering.
- 2026-11-19: Second test with the guided test (#512, Android): the program
  numbering holds across the block borders (E:55, F:11). Songs have 5 parts:
  bank select MSB 1 with number = (song − 1) × 5 + part − 1 in blocks of 125
  (PC 1 = next part, PC 5 = next song, LSB 1 / PC 0 = song 26 part 1), so a
  part is chosen directly and CC 5 is not needed (it still had no effect).
  CC 3 switches the song mode, CC 2 the live mode on and off. A program change
  52 without bank select selected program C:13, not live memory 3: the first
  test only worked because the Nord was in live mode. Live memories now use
  what the Nord sends for them, CC 0 = 6 with PC 0–4; a third, shorter guided
  test checks this and songs with parts.
- 2026-11-19: Third guided test (#512, Android): all 10 steps as expected.
  Live memories 1, 3 and 5 with CC 0 = 6, CC 32 = 0, PC 0–4 from program mode,
  a program afterwards leaves them again; song 2 part 3 and song 26 part 5
  with CC 0 = 1; CC 3 switches the song mode. The Nord Stage 3 addressing of
  this ADR is confirmed on Android. The test keyboard runs Nord OS 2.54.

## Open points

- Prototype results still open: Windows, Linux and Chrome; the number of
  songs on the Nord.
- Later stages (issues only when taken up): learning the program from the
  keyboard, program changes per section, page turning by MIDI, Bluetooth, several
  target devices, further device profiles, iOS.
