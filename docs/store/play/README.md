# Google Play listing

The store listing of `app.setding` (ADR-0067), kept in the layout of
fastlane supply (`<locale>/…`) so a later upload step can use it as it is.
Texts and images are entered in the Play Console by hand for now.

The screenshots are **not checked in** (git-ignored): they are about 35 MB and
change with every render (the overview shows the gig "in 3 days"). Render them
before updating the listing:

```bash
make screenshots ONLY="^play "
```

| File | Content | Made by |
|---|---|---|
| `icon-512.png` | App icon 512×512, opaque and full-bleed (Play masks the corners) | `make branding` |
| `feature-1024x500.png` | Feature graphic, the dark logo without text (fits every language) | `make branding` |
| `<locale>/title.txt`, `short_description.txt` (≤ 80), `full_description.txt` (≤ 4000) | Listing texts, based on the website's home page | by hand |
| `<locale>/captions.txt` | Headlines of the phone screenshots, one line per screen: `regular part\|bold part` | by hand |
| `<locale>/images/phoneScreenshots/<n>.png` | Phone screenshots 1080×1920 (9:16): the screen in a drawn phone frame under the headline | `make screenshots ONLY="^play "` |
| `<locale>/images/tenInchScreenshots/<n>.png` | Tablet screenshots 2560×1600 (16:10) in a tablet frame; upload them for 7" and 10" tablets | `make screenshots ONLY="^play "` |

The eight screens are live mode, set, ChordPro editor, song display editor,
overview, song list, drummer mode and the server setting (self-hosting). Each
is rendered in the light and the dark theme; the listing alternates between
them and splits the first and the last diagonally into both
(`themes` in `tool/store-screenshots.sh`).

Locales: `de-DE` (Swiss spelling without "ß" like the app) and `en-US`.
Further languages
(ADR-0008) add a folder with the texts and captions and a language in
`app/test_screenshots/play_store_screenshots_test.dart` and
`tool/store-screenshots.sh`.

The screens are rendered by `app/test_screenshots/play_store_screenshots_test.dart`
(`<lang>_<theme>_play_<device>_<n>_<screen>.png` in `app/build/screenshots/`);
`tool/copy-screenshots.sh` then runs `tool/store-screenshots.sh`, which composes
them with the captions. A changed caption needs only `tool/store-screenshots.sh`
after a render. The release PR renders them with the other screenshots.

Play's rules for the texts: no superlatives ("best", "#1"), no names of other
apps, no keyword lists, no prices or calls to rate the app.
