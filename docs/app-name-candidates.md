# App name candidates

> Status: **Open** – no name chosen yet. "BandChords" is the working title.
> Collected: 2026-11-14

The name should be short, memorable, easy to pronounce in German and English, and
available as a domain (the domain is also used for invitation links, ADR-0005).

## Shortlist (favourites)

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
| Tutti | tutti.ch is a well-known Swiss classifieds marketplace → confusion / trademark risk |
| Coda | Well-known software product (coda.io) |
| Chordify, OnSong, BandHelper, SongbookPro, forScore | Existing music apps |

## Domain notes

- `.app` enforces HTTPS (required anyway for deep links of invitation links).
- Additionally register `.ch` for protection and the Swiss market; `.band` is an option.

## Checks before deciding (not done yet)

1. Domain availability at the registrar
2. App stores (Google Play, Apple App Store, Microsoft Store): no app with the same or a very similar name
3. Trademarks: swissreg.ch (Switzerland) and EUIPO (EU)

Once a name is chosen: update the architecture README, AGENTS.md and ADR-0005
(invitation link domain), and remove this file or mark it as decided.
