# App name candidates

> Status: **Decided (2026-11-17): setDING.** Called RealChord from 2026-11-15 to
> 2026-11-17; "BandChords" was the working title.
> Collected: 2026-11-14

## Decision (2026-11-17): setDING

The app is renamed to **setDING** (#318).

- **Why:** the app is extended with features for drummers, so a name about chords
  no longer fits.
- **Idea:** a play on words. Spoken, it sounds like "setting". "Set" is the set
  of a gig (what the app is about) and a drum set; "DING" is the bright ding of a
  cymbal bell. In German, "das Set-Ding" is also casually "the thing for our sets".
- **Spelling:** always **setDING**, also in prose and UI texts. Code and build
  identifiers are case-insensitive or lower case: `setding` (packages, binary,
  paths), `Setding` (Dart classes), `SETDING_` (environment variables),
  application ID `app.setding`.
- **Domain:** `setding.app` (registered by the owner): `api.setding.app` for the
  server, `app.setding.app` for the web client. `realchord.app` expires.
- **Logo:** a new mark and the wordmark "set" + "DING" (#319).
- **Not migrated:** the app was not live yet, so no data, settings or installs
  are carried over (database `setding.sqlite`; the BandChords database migration
  was removed).

### Still to do

1. Trademark search at swissreg.ch and EUIPO/TMview, classes 9 and 42 (to be done by
   a human).
2. Check the Google Play, Apple App Store and Microsoft Store for "setDING".

## Earlier decision (2026-11-15): RealChord

The app is called **RealChord**.

- **Idea:** a nod to the *Real Book* (the jazz musicians' lead sheet collection) and
  "the real chords" – the reliable source on stage. Fits both strengths of the app:
  managing and writing ChordPro, and playing live gigs.
- **Pronunciation:** easy in German and English.
- **Conflicts found (2026-11-15, web and app store search):** only "RealChord" by
  LutherSoft, an old iPhone guitar chord reference from the iTunes era, apparently no
  longer maintained. No registered trademark found. Similar but distinct names exist
  ("Real Guitar – Tabs & Chords", a practice app).
- **Weakness:** in English, "real chord" may suggest chord detection; a tagline such
  as "RealChord – ChordPro for the stage" helps.
- **Domains:** `realchord.app`, `realchord.ch` and `realchord.com` had no DNS
  records on 2026-11-15 (a hint only, not proof that they are free).

### Still to do

1. Register `realchord.app` and `realchord.ch` (optionally `.com`) at a registrar.
2. Trademark search at swissreg.ch and EUIPO/TMview, classes 9 and 42 (to be done by
   a human; a web search does not replace it).
3. Check the Google Play, Apple App Store and Microsoft Store for "RealChord".
4. ~~Rename the code and build identifiers~~ – done 2026-11-15: Dart package
   `realchord`, application ID / bundle ID `ch.realchord.realchord`, binary
   `realchord`, database `realchord.sqlite`, `REALCHORD_DATA_DIR`. A database
   `bandchords.sqlite` from before the rename is renamed on the first start.
5. ~~Application ID matching the domain~~ – done 2026-11-17 (#298): application ID /
   bundle ID **`app.realchord`** (reverse of `realchord.app`, the domain in use)
   instead of `ch.realchord.realchord`; also the Linux app ID and desktop entry and
   the Windows company name. The app was not live yet, so nothing is migrated: data
   in the old app directory stays there, and Android installs of earlier test
   releases are a separate app that has to be uninstalled by hand. Once the app is
   in an app store, the ID can never change again.

## Criteria

The name should be short, memorable, easy to pronounce in German and English, and
available as a domain (the domain is also used for invitation links, ADR-0005).

## Earlier shortlist (2026-11-14)

| Name | Idea | Possible domains |
|---|---|---|
| **Chordset** | Chords + set – describes exactly what the app does | chordset.app, chordset.ch |
| **Pult** | From *Notenpult* (music stand) – the tablet is the new music stand; very catchy in German-speaking regions | pult.app, pult.ch |
| **Stagepad** | Stage + pad (tablet) – works best internationally | stagepad.app, stagepad.ch |

## Further candidates

| Name | Idea |
|---|---|
| Stagesheet | The sheet in front of you on stage |
| Gigsheet | Like Stagesheet, more casual |
| Gigpad | Like Stagepad, more casual |
| Chordeck | Chord + deck |
| Setwise | "Guided through the set", more abstract |
| Setbook | The book for the set |
| Setflow | Flowing through the set |
| Nextsong | The moment on stage: press the pedal, next song |
| Leadleaf | Lead sheet + leaf, alliteration; harder to pronounce |
| Riffsheet | Riff + lead sheet, rock-oriented |
| Standly | From "music stand", English |
| Segue | Seamless transition between songs; pronunciation not obvious to everyone |
| Vamp | Repeat a passage until moving on; short and cheeky |
| Mäppli | Swiss German for the band's sheet music folder; unsuitable for English speakers |
| Bühni | Swiss German for "small stage"; unsuitable for English speakers |

## Excluded

| Name | Reason |
|---|---|
| MuseChord | "Muse" is heavily used in music software by Muse Group (MuseScore, MuseHub, Muse Sounds, MU/MUSE marks) → trademark risk; `musechord.com` taken |
| StageChord | Already used by an offline ChordPro viewer with setlists (github.com/mikesprad/StageChord) and by a MIDI chord-detection plugin for live keyboarders (LiveKeyTools) |
| ChordStage, ChordPilot, ChordCraft, ChordWise, ChordSmith, ChordLight, ChordCue, ChordPad, ChordFlow, Stagepad | `.app` domain already taken (DNS check 2026-11-15) |
| Tutti | tutti.ch is a well-known Swiss classifieds marketplace → confusion / trademark risk |
| Coda | Well-known software product (coda.io) |
| Chordify, OnSong, BandHelper, SongbookPro, forScore | Existing music apps |

## Domain notes

- `.app` enforces HTTPS (required anyway for deep links of invitation links).
- Additionally register `.ch` for protection and the Swiss market; `.band` is an option.

## Further candidates considered (2026-11-15)

CueChord, ChordLine, EncoreChord and SetChord had no app of the same name and mostly
free-looking domains; RealChord was preferred.
