# ADR-0042: Keyboard programs per device profile

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

ADR-0039 stores **one** keyboard program per person and song, as raw MIDI
values `{msb?, lsb?, program}` in the personal overlay (`overlays.midi`). The
device profile (Nord Stage 3, Generic) is a device setting and only translates
these raw values for display and editing.

The owner plans a second profile, the **Yamaha Motif XF** (XF8). A keyboard
player who changes keyboards, e.g. a Nord Stage 3 in one band and a Motif XF
in another, or a new keyboard after some years, would have to enter all
programs again, and in between the same raw values would select unrelated
sounds on the other keyboard: "K:33" on the Nord (MSB 0, LSB 2, PC 12) means
nothing sensible on the Motif. Goal (owner): **a keyboard player can change
keyboards without adapting the songs.**

Constraints:

- v0.16.0 clients already read and write `overlays.midi` in the single-program
  shape and push it with every change of the overlay. They must not be able to
  destroy programs stored in a new shape, and their stored programs must stay
  usable.
- The program stays personal and private (ADR-0006, ADR-0020, ADR-0039).
- More profiles will follow; the profile is chosen in a drop-down (#586).
- Live mode stays calm (ADR-0007).

The Motif XF (from Yamaha's Data List, to be checked on a real keyboard):
voices in banks of 128 (shown as group A–H × number 1–16 and as 001–128),
selected with bank select MSB/LSB and program change 0–127, e.g. PRE 1 =
MSB 63, LSB 0; further preset, user, GM and drum banks, performances and
mixings have their own MSB/LSB.

## Decision

### One program per profile and song

- A song can have **one keyboard program per device profile** for each person:
  e.g. a Nord program *and* a Motif program. Each stored program carries its
  profile: `{ "profile": "nordStage3", "msb": 0, "lsb": 2, "program": 12 }`.
- The device's profile (device setting, ADR-0039) decides which one is
  **shown first, sent in live mode and tested**. A song without a program for
  that profile sends nothing, as a song without a program today.
- Changing the profile in the settings therefore switches all songs at once;
  the programs of the other profiles are kept.
- The Generic profile is a profile like the others: its programs belong to
  "generic", not to every keyboard.

### Editing

- The *Keyboard program* field of the song's personal adjustments shows the
  program of the device's profile in that profile's terms (Nord: "Program
  K:33"; Motif XF: e.g. "PRE1 A01") and edits it with that profile's picker.
- Below it, the programs of **other profiles** stored for the song are listed
  with the profile's name; each can be edited with its own profile's picker
  (without sending, as "Test" only reaches the connected keyboard of the
  device's profile) or removed.
- An action "Program for another keyboard" lets the keyboard player prepare
  a program for a profile that is not the device's (e.g. before the new
  keyboard arrives).

### Storage and compatibility

- New server field **`overlays.midi_programs`** (JSON, optional): a map from
  profile id to the raw values, e.g.
  `{ "nordStage3": {"msb": 0, "lsb": 2, "program": 12}, "motifXf": {…} }`.
  Locally a new nullable column `personal_overlays.midi_programs` (new schema
  version). Last writer wins for the whole map, as for the rest of the
  overlay.
- **`overlays.midi` stays as it is** and is never written by new clients.
  v0.16.0 clients keep reading and writing only `midi`, so they cannot destroy
  `midi_programs`.
- A value in `midi` **without a profile** (written by v0.16.0) counts as the
  program of the device's profile while that profile has none in
  `midi_programs`. The first change of the song's programs on a new client
  moves it into `midi_programs` under the device's profile; `midi` is left
  untouched.
- Profile ids are stable strings (`generic`, `nordStage3`, `motifXf`), never
  the position in the drop-down.
- This is a **minor** version (ADR-0028); no new minimum client version
  (ADR-0029). A keyboard player who keeps a v0.16.0 device next to a new one
  sees only the program in `midi` there.

### Yamaha Motif XF profile

- A new device profile **Yamaha Motif XF** in the drop-down after Generic and
  next to the Nord Stage 3.
- Its picker works without typing, like the Nord's: the kind (voice, and
  possibly performance and mixing, see open points), the bank (PRE1–PRE8,
  USR1–USR4, GM, drums …), group A–H and number 1–16, with a preview as on the
  display.
- The MSB/LSB of each bank are taken from Yamaha's *Motif XF Data List* and
  checked on the owner's Motif XF8 before the profile is built, as the Nord
  was (#512); the MIDI test screen (developer mode) serves for this.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **One program per profile** (chosen) | Changing keyboards needs no change of the songs; programs for a new keyboard can be prepared | A map instead of one value; the editor lists several programs |
| One program that knows its profile | Simple; the display never misreads raw values | After changing keyboards nothing is sent until each song is edited again (owner: not wanted) |
| Programs per keyboard *device* (by MIDI name) instead of per profile | Two keyboards of the same model could differ | Several Nords of one person are rare; the device name changes between platforms and USB ports |
| Write the new shape into `overlays.midi` | No server migration | v0.16.0 clients overwrite it with the single-program shape on every overlay change |
| Mirror the device's program into `midi` for old clients | v0.16.0 devices keep sending the current program | Two devices with different profiles overwrite each other's mirror; the old clients are few and short-lived |
| A profile chooser in the song editor instead of the device setting | Free choice per song | The device's keyboard is a fact of the stage, not of the song; the setting already exists |

## Consequences

- Server migration `overlays.midi_programs`; local schema +1 with
  `personal_overlays.midi_programs`; the overlay sync pushes and pulls it; a
  server test shows that a v0.16.0-shaped push (`data`, `deleted`, `midi`)
  keeps `midi_programs`.
- `MidiProfile` gets a stable `id`; `MidiProfileKind` gets `motifXf`; the
  repository offers the programs of a song per profile and the one of the
  device's profile, with the fallback to `midi`.
- `LiveMidiSender` and "Test" read the program of the device's profile.
- The *Keyboard program* field lists the programs of other profiles and can
  add one for another profile; new UI texts in `app_de.arb` and `app_en.arb`.
- Tests: the map round trip, the fallback to `midi` and its move on the first
  change, live mode sending only the device profile's program and nothing for
  a song with programs of other profiles only, the Motif XF translation both
  ways, the editor with several profiles.
- The website page *Connecting a keyboard* explains changing keyboards and
  the Motif XF; the Nord test set may get a Motif counterpart.
- ADR-0039 stays accepted; its storage decision (one program in
  `overlays.midi`) is extended by this ADR.

## Decision log

- 2026-11-19: Proposed after the owner's request (#590): a keyboard player
  can change keyboards without adapting the songs, so a song keeps one
  program per device profile; first new profile the Yamaha Motif XF (XF8).
- 2026-11-19: Accepted by the owner (#590, PR #592). The open points below
  are settled when the implementation issues are taken up.
- 2026-11-19: Yamaha Motif XF profile implemented first (owner, #591), the
  storage per profile follows in #594. Open points settled for the Motif:
  **voices and performances** (preset 1–8, user 1–4, GM, preset and user
  drums, GM drum; performances user 1–4), no mixings and masters yet; bank
  select values from the *MOTIF XF Data List* (see ADR-0039's decision log).
  Added to this ADR: a program change only works in the Motif's current
  mode, so the profile sends the **SysEx mode change** to voice or
  performance mode before bank select and program change (device number 1,
  the Motif set to "all" or 1). The owner allowed merging the profile before
  the check on the XF8, which stays an open point. Until #594 lands, a
  profile change shows the one stored program in the new profile's terms.
- 2026-11-19: Programs per profile implemented (#593, also opened as
  #594). Server migration
  `1795900000_overlay_midi_programs.js` adds `overlays.midi_programs`; local
  schema 20 adds `personal_overlays.midi_programs` (`MidiPrograms`, a map
  from `MidiProfile.id` = the name of `MidiProfileKind` to `MidiProgram`).
  The v0.16.0 program in `midi` counts for the device's profile only while
  `midi_programs` was **never written** (null): the first change writes the
  map, and removing the last program leaves an **empty map**, so the old
  value does not come back (more precise than "while that profile has
  none", which would have sent a Nord program to a newly chosen Motif). The
  overlay sync pushes and pulls the map; `midi` is pulled and pushed
  unchanged. *Program for another keyboard* is part of the field (a menu
  of the profiles without a program), which settles that open point. A
  profile id this client does not know (written by a newer client) is
  listed as "Unknown keyboard (id)" with its raw values and can only be
  removed.

## Open points

- Motif XF mixings and masters (a master needs SysEx and a key of its own,
  ADR-0039); voices and performances are settled (#591).
- Several keyboards at one tablet at the same time stay out of scope
  (later stage of ADR-0039).
- The MSB/LSB table and the SysEx mode change of the Motif XF, checked on
  the owner's XF8 with the MIDI test (#591).
