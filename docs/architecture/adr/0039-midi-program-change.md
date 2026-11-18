# ADR-0039: MIDI program change per song in live mode

- **Status:** Proposed
- **Date:** 2026-11-18

## Context

Keyboard players change the sound of their instrument between songs: piano for
one song, organ for the next, a pad for a ballad. Today they look for the right
program on the keyboard by hand while the band waits. Many stage keyboards,
among them the **Nord Stage 3** of the owner's band, switch programs by MIDI:

- a **Bank Select** (CC 0 = MSB, CC 32 = LSB) followed by a **Program Change**;
- on the Nord Stage 3: CC 0 = 0, CC 32 = 0–7 for banks A–H, Program Change 0–49
  for the programs of the bank and 50–54 for the five live memories, received on
  the keyboard's global channel when "Program Change" reception is switched on in
  its MIDI menu. The bank select must come before the program change.

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
| Channel | 1–16 | 1 |

- **Nord Stage 3 profile:** bank A–H and program 1–50 (sent as CC 0 = 0,
  CC 32 = bank, Program Change = program − 1), or live memory 1–5 (Program Change
  50–54, no bank select). The settings explain that "Program Change" reception
  must be on in the Nord's MIDI menu and that the channel is the Nord's global
  channel.
- **Generic profile:** bank select MSB and LSB (each optional, 0–127) and program
  1–128.
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
  raw MIDI bytes; the implementation checks first that this works on every
  platform and falls back to another library from the table below if it does not.
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
- Tests: profile translation (Nord Stage 3 and generic, both directions), the
  live mode sends exactly once per song change and never for prepared neighbours,
  nothing for songs without a program or for breaks, overlay sync of `midi`
  (including an older client's push that leaves it untouched, server test).
  Manual test with a Nord Stage 3 on Android, Windows and in Chrome.
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

## Open points

- Does `flutter_midi_command` send raw bank select and program change on every
  platform (Android USB host, Windows, Linux ALSA, Web MIDI)?
- A Nord User Forum report says bank select was not always applied in the Nord
  Stage 3's song mode; check with the real keyboard.
- Is the "Test" button wanted in the first version?
- Later: learning the program from the keyboard, program changes per section,
  page turning by MIDI, Bluetooth, several target devices, iOS.
