# ADR-0008: Localization (German, English, French, Italian, Spanish, Portuguese)

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

The app is primarily used by German-speaking bands, but should also be usable in
English. Users must be able to choose the language themselves, independent of the
device's system language (e.g. an English-language tablet used by a German-speaking
musician).

## Decision

- The UI is available in **German (`de`), English (`en`), French (`fr`), Italian
  (`it`), Spanish (`es`) and Portuguese (`pt`)** (the last four since #983). All UI texts are
  localized from the start of the MVP; no hard-coded strings in widgets.
- Implementation uses Flutter's standard approach: **`flutter_localizations` + `intl`
  with ARB files** (`app_de.arb`, `app_en.arb`) and generated, type-safe accessors
  (`gen-l10n`), one ARB file per language.
- **Language setting** in the app settings, a drop-down with:
  - *System default* (initial value) – uses the first device language the app
    has, otherwise **English** as fallback
  - one entry per language, each named in its own language (*Deutsch*,
    *English*, *Français*, *Italiano*, *Español*, *Português*)
- The setting is stored **locally per device** (layer 4 in ADR-0006) and applied
  immediately without restarting the app.
- **German is the reference language** for UI texts; new texts are written in German
  and English at the same time, and in the other languages in the same change.
  A missing key in any ARB file fails the build/CI check.
- **Not localized:** song content (ChordPro text, titles, comments written by the
  band). Only generated labels are localized, e.g. default section labels
  ("Verse"/"Strophe", "Chorus"/"Refrain") when the ChordPro file has no explicit label.
- Date and number formats follow the selected language (`intl`).
- **German means Swiss Standard German (`de-CH`):** German UI texts use Swiss
  orthography ("ss" instead of "ß", e.g. "Grösse", "schliessen"), and date/number
  formatting uses the `de_CH` locale. There is only one German variant; users in
  Germany or Austria also get the Swiss spelling.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **`flutter_localizations` + `intl` (ARB, gen-l10n)** (chosen) | Official Flutter approach, type-safe, ARB is supported by translation tools, no extra dependency | Some boilerplate, code generation |
| `easy_localization` / `slang` | Less boilerplate, JSON/YAML files | Additional third-party dependency |
| Follow system language only (no setting) | Simplest | Does not meet the requirement to choose the language in the settings |
| German only | Least effort | Excludes English-speaking musicians/stand-ins |

## Consequences

- From the first screen on, every UI text goes through the localization layer.
- Further languages are added with an ARB file, an entry in `LanguageMode`
  and `supportedUiLocales` (`app/lib/settings/settings.dart`).
- Chord notation (H vs. B) is **not** coupled to the UI language; it is a separate display setting (see open point in ADR-0003).

## Decision log

- 2026-11-14: UI primarily in German and English, selectable in the settings.
- 2026-11-14: German variant is Swiss Standard German (`de-CH`, no "ß"). A separate de-DE variant is not planned; it could be added later as an extra ARB file if needed.
- 2026-11-17: Shared data never stores a localized UI label, because band members may use different languages (#289). A break left with its default name is stored without a note and shows the type label of each member's language; for older data, a note that equals the type label in any supported language counts as no note (`ui/sets/set_item_label.dart`). This applies to the set screen, live mode and the set list exports.
- 2026-11-17: Resolved open point (ADR-0027, accepted, #328): the language is a **personal setting** synced with the account, no longer stored per device. Signed out, the device's own (`local`) value applies. `USER.locale` as a default for new devices is not needed.
- 2026-11-19: Song section names (Verse, Chorus, Pre-chorus, Bridge, Interlude, Ending, Grid, …) are musician terminology and stay **English in every UI language** (#533): in the song view, live mode, the sequence chips and their tooltips in arrangements, the song display settings and the editor. The editor writes them into the shared ChordPro text as labels, so localizing them would also break the rule above. The ARB files keep the keys, the German values equal the English ones (`test/section_names_test.dart`).
- 2026-11-23: French, Italian, Spanish and Portuguese added as UI languages (#983), all in their standard variants (no `fr-CH`/`it-CH`; Portuguese in European spelling). The language setting becomes a drop-down, since seven options no longer fit a segmented button. The system default picks the first device language the app has. Song section names stay English in every language. The user documentation (website) stays German and English.

## Open points

- None.
