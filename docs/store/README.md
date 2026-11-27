# Store listings

Texts and images for the app stores, kept in the layout of fastlane (`supply`
for Google Play, `deliver` for the App Store) so a later upload step can use
them as they are. For now they are entered in the store consoles by hand.

| Folder | Store |
|---|---|
| [`play/`](play/README.md) | Google Play (`app.setding`, ADR-0067): texts, icon, feature graphic, phone and tablet screenshots |
| `app-store/` | App Store: iPhone, iPad and Mac screenshots. iOS is not published yet (ADR-0021) and there is no macOS build; the screenshots are ready for when it is. |
| `captions/<locale>.txt` | Headlines of the screenshots, shared by both stores: one line per screen, `regular part\|bold part` |

## Screenshots

The screenshots are **not checked in** (git-ignored): they are large (about
100 MB for both stores) and change with every render (the overview shows the
gig "in 3 days"). Render them before updating a listing:

```bash
make screenshots ONLY="^store "
```

`app/test_screenshots/store_screenshots_test.dart` renders eight screens – live
mode, set, ChordPro editor, song display editor, overview, song list, drummer
mode and the server setting (self-hosting) – on every device, in both languages
and both themes (`<lang>_<theme>_store_<device>_<n>_<screen>.png` in
`app/build/screenshots/`). `tool/copy-screenshots.sh` then runs
`tool/store-screenshots.sh`, which puts each screen into a drawn device frame on
the brand gradient under its headline, the bold line in the bell's brass. The
listing alternates between the light and the dark theme and splits the first and
the last screen diagonally into both (`themes` in the script). A changed caption
needs only `tool/store-screenshots.sh` after a render.

| Store | Device | Size | Folder |
|---|---|---|---|
| Google Play | Phone | 1080×1920 (9:16) | `play/<locale>/images/phoneScreenshots/` |
| Google Play | Tablet, for 7" and 10" | 2560×1600 (16:10) | `play/<locale>/images/tenInchScreenshots/` |
| App Store | iPhone 6.9" | 1320×2868 | `app-store/<locale>/images/iphone/` |
| App Store | iPad 13", landscape | 2752×2064 | `app-store/<locale>/images/ipad/` |
| App Store | Mac | 2880×1800 | `app-store/<locale>/images/mac/` |

The screens are rendered with the app's Material look and the Roboto font of
the screenshot tests on every device, also for the Apple ones.

Locales: `de-DE` (Swiss spelling without "ß" like the app) and `en-US`. A
further language (ADR-0008) adds its captions, the listing texts and the
language in the test and in `tool/store-screenshots.sh`.
