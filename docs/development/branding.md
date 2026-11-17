# Logo and splash screens

The setDING logo is a plectrum with a chord diagram (the *mark*) next to the
wordmark "setDING" ("Real" in ink, "Chord" in the brand gradient).

## Sources

`app/branding/` holds the SVG sources; everything else is generated from them:

| File | Content |
|---|---|
| `mark.svg` | The mark, 512 × 512 |
| `wordmark.svg`, `wordmark-dark.svg` | Wordmark for light and dark backgrounds (Noto Sans Bold, converted to paths) |
| `logo.svg`, `logo-dark.svg` | Mark and wordmark side by side (generated, used in the README) |
| `generated/` | PNGs for the native splash screens (generated) |

Brand colors: red `#E8461C`, mark gradient `#FFB020` → `#E8461C`, wordmark
gradient ("Chord") `#FFA41C` → `#E8461C`, ink `#1B1D22`, splash
background `#FFFFFF` (light) and `#121417` (dark). In the app they are
`BrandColors` in `app/lib/ui/widgets/logo.dart`.

## App colours

By default the app's colour scheme is derived from the logo red (issue #269;
other accent colours below):
`appColorScheme` in `app/lib/ui/theme.dart` calls
`ColorScheme.fromSeed(seedColor: Color(0xFFE8461C))` for light and dark
with Material's default `tonalSpot` variant. It keeps the brand hue but
calm: a muted terracotta instead of the logo's bright vermilion, which would
compete with the lyrics and sit right next to the error red. (`fidelity`,
`content` and `vibrant` give a primary of `#B02700`/`#B42900`, almost the
error red `#BA1A1A`.)

| Role | Light | Dark |
|---|---|---|
| `primary` (chords, key badges, buttons) | `#8F4B3A` | `#FFB4A2` |
| `tertiaryContainer` (search hits, notes) | `#F7E1A6` | `#544519` |
| `error` (errors, sync conflicts) | `#BA1A1A` | `#FF7164` (tone 65) |
| `errorContainer` (conflict banner) | `#FFB4AB` (tone 80) | `#93000A` |

With a red seed, two Material error roles land on the same colour as the
primary roles, so `appColorScheme` moves them to other tones of the
Material error palette: the dark `error` (tone 80 would be the pastel of
the dark `primary`) and the light `errorContainer` (tone 90 would be the
blush of `primaryContainer`). `app/test/theme_test.dart` checks that error
and primary colours stay apart (CIELAB ΔE), the contrast of lyrics, chords
and editor colours (≥ 4.5:1) and that the sync-conflict icon in the song
list differs from the gig icon in both themes.

On stage (live mode, ADR-0007) chords use `StageColors` in
`app/lib/ui/render/song_style.dart`: on light a deep tone of the accent
(for the brand red `#852309`, the logo's hue, about 9:1), amber `#FFC54D`
on dark and black for every accent, both ≥ 7:1.
Colours that are not derived from the scheme: setDING's own `x_`
directives in the editor (teal, apart from the warm palette), the
offline-ready icon (green) and the named ChordPro colours of the songs.

### Accent colours

Users choose the accent colour in the settings (*General → Accent colour*,
issue #300), stored per device like the other settings (ADR-0006). Instead
of a free colour picker there is a curated set of seeds
(`AccentColorPalette` in `app/lib/ui/theme.dart`): each one goes through
the same `ColorScheme.fromSeed` `tonalSpot` variant as the brand red, so
light and dark get the same calm tones and contrasts in another hue, and
the neutral surfaces only take a faint tint of it. The error colours stay
the same for every accent.

| Accent | Seed | `primary` light | `primary` dark | Light stage chords |
|---|---|---|---|---|
| setDING red (default) | `#E8461C` | `#8F4B3A` | `#FFB4A2` | `#852309` |
| Amber | `#FFB300` | `#7D570D` | `#F0BE6D` | `#604100` |
| Green | `#43A047` | `#3B6939` | `#A1D39A` | `#005313` |
| Teal | `#00897B` | `#006B5F` | `#82D5C7` | `#005048` |
| Blue | `#1E88E5` | `#39608F` | `#A3C9FE` | `#004881` |
| Purple | `#8E24AA` | `#794F81` | `#E8B5EF` | `#790096` |
| Pink | `#D81B60` | `#8E4958` | `#FFB2BF` | `#90003B` |

The light stage chord colour is the seed's hue at HCT tone 30 with its full
chroma (about 9:1). `app/test/theme_test.dart` runs every colour check of
this page for every accent and checks that the accents can be told apart
(primary colours at least ΔE 15 apart in light and in dark; an indigo was
dropped because its dark primary was too close to the blue one). A new
accent needs a seed and a stage chord colour and must pass these tests.

### Sequence chips

The song sequence (`{x_sequence}`) is shown as small chips in the song
header, the set screen, live mode and the sequence dialog. Their colours
come from `SongSequenceView.background`/`foreground` in
`app/lib/ui/render/song_header.dart`, all from the scheme (issue #288):

| Part | Role | Light | Dark (also dark/black stage) |
|---|---|---|---|
| Chorus | `primary` / `onPrimary` | `#8F4B3A` / `#FFFFFF` | `#FFB4A2` / `#561F11` |
| Pre-/post-chorus | light `primaryFixedDim` / `onPrimaryFixed`, dark `primaryContainer` / `onPrimaryContainer` | `#FFB4A2` / `#3A0A02` | `#723425` / `#FFDAD2` |
| Bridge | `tertiary` / `onTertiary` | `#6D5D2E` / `#FFFFFF` | `#DAC58D` / `#3C2F04` |
| Other parts | `surfaceContainerHighest` / `onSurfaceVariant` | `#F1DFDA` / `#534340` | `#3D3230` / `#D8C2BD` (black stage `#242424`) |

(Colours for the brand red.) The chorus, the part that comes back most
often, is filled with the primary colour; pre- and post-chorus use a softer
tone of the same hue (tone 80 on light, tone 30 on dark), so they read as
belonging to it without looking the same. The bridge is filled with the
tertiary colour: the pastel `tertiaryContainer` used before was too close
to the neutral chips of the other parts with several accent colours
(issue #300). The container roles alone cannot tell the parts
apart: with the red seed, the light `primaryContainer` and
`secondaryContainer` are both `#FFDAD2`, and `surfaceContainerHighest` is
almost the same blush. `app/test/theme_test.dart` checks for every accent, in
light, dark and on the dark and black stage, that the four groups are at
least ΔE 20 apart (closest: chorus and bridge of the blue accent on light,
ΔE 21) and that every chip has a text contrast of at least 4.5:1.

## Where the logo is shown

The splash looks the same everywhere: the mark centered (128 dp), the
wordmark at the bottom (200 dp wide, 48 dp from the bottom edge), and the
background following the system's light/dark mode.

1. **Native splash** (Android, iOS): shown by the OS until Flutter draws its
   first frame. Generated by `flutter_native_splash` from
   `app/flutter_native_splash.yaml` (a dev dependency; it only writes files).
2. **Web splash** (`app/web/index.html`): plain HTML with the SVGs from
   `app/web/splash/`, removed on the engine's `flutter-first-frame` event.
3. **In-app splash** (`SplashScreen` in `logo.dart`, all platforms): the first
   frame, shown while `main()` opens the database and loads the session, and
   for at least one second from the start (`SplashScreen.minimumDuration`;
   starting runs meanwhile, only the rest is waited for). On
   Windows and Linux, which have no native splash, it is the first thing the
   window shows. The web client also shows it (with a progress indicator)
   while the first sync after signing in loads the bands. The mark is drawn
   in code, so it appears without loading an asset.

The web sign-in screen shows `SetdingLogo` above the form.
On wide screens (≥ 720 dp) the navigation rail of the home screen shows
the mark (`SetdingMark`, 40 dp) permanently at its top left. Phones use
the bottom navigation bar, which has no room for it.

## App icons

`make branding` also writes the app icons, all with the mark on the white
splash background:

| Platform | Files |
|---|---|
| Android | Adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`): foreground layer, white background and a monochrome layer for themed icons (Android 13+); legacy `ic_launcher.png` per density |
| iOS | Every size in `AppIcon.appiconset` (opaque) |
| Windows | `windows/runner/resources/app_icon.ico` (16–256 px) |
| Linux | `linux/runner/resources/app_icon.png` and `.svg`, installed into the bundle's `data/`. The window icon is set in `my_application.cc`, which only works under X11. Under Wayland the icon comes from the desktop entry that `install-desktop-entry.sh` (in `linux/packaging/`, shipped in the bundle) installs. `make start` and `make dev` install a hidden entry if there is none yet. |
| Web | `favicon.png`, `icons/Icon-*.png` (incl. maskable) |

ImageMagick writes no date chunks, so running `make branding` without
changing the sources leaves every file unchanged.

## Changing the logo

Edit the SVGs in `app/branding/` (keep `_MarkPainter` in `logo.dart` in sync
with `mark.svg`), then regenerate all images:

```bash
make branding
```

It needs `rsvg-convert` (librsvg), ImageMagick (`magick`) and Python 3. Commit
the generated files. To recreate the wordmark from text, use Inkscape's
*Object to Path* with Noto Sans Bold, size 170, letter spacing −4.

`make screenshots` renders the in-app splash to
`app/build/screenshots/0_splash_*.png`.
