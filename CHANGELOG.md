# Changelog

All notable changes to setDING are documented in this file. The section of a
version is also the text of its [GitHub Release](https://github.com/tafli/setDING/releases).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the setDING-specific bump rules of
[ADR-0028](docs/architecture/adr/0028-versioning-scheme.md).

## [0.14.0] - 2026-11-19

### Added

- Linux AppImage that updates itself (ADR-0038) ([#504](https://github.com/tafli/setDING/pull/504))
- Open song attachments without starting the live view ([#508](https://github.com/tafli/setDING/pull/508))
- CycloneDX SBOM for every release asset (ADR-0037) ([#509](https://github.com/tafli/setDING/pull/509))
- Personal option to show the chords in the first verse only ([#519](https://github.com/tafli/setDING/pull/519))
- Black/white colour in the song display palette ([#528](https://github.com/tafli/setDING/pull/528))
- Sort chord suggestions in the editor and show them after "Insert chord" ([#529](https://github.com/tafli/setDING/pull/529))
- Stack verses with the same chords line by line ([#531](https://github.com/tafli/setDING/pull/531))
- Monospace font option in the song display settings ([#530](https://github.com/tafli/setDING/pull/530))
- Hyphen between syllables split by a chord in stacked verses ([#534](https://github.com/tafli/setDING/pull/534))
- Black/white song display preset ([#537](https://github.com/tafli/setDING/pull/537)), with bold, larger headings ([#539](https://github.com/tafli/setDING/pull/539))

### Changed

- Upgrade dbus, jni and jni_flutter ([#515](https://github.com/tafli/setDING/pull/515)) and pdfrx to 3.0.3 ([#525](https://github.com/tafli/setDING/pull/525))

### Fixed

- The Android app starts again: jni pinned to 1.1.2 ([#517](https://github.com/tafli/setDING/pull/517))
- Song section names stay in English in every language ([#535](https://github.com/tafli/setDING/pull/535))

## [0.13.0] - 2026-11-18

### Added

- Unobtrusive update check on start (ADR-0036) ([#499](https://github.com/tafli/setDING/pull/499))
- Windows installer with in-app updates (ADR-0035) ([#495](https://github.com/tafli/setDING/pull/495))

## [0.12.0] - 2026-11-18

### Added

- Song sources via `{x_link}` ([#470](https://github.com/tafli/setDING/pull/470)), editable and removable in the sources panel ([#486](https://github.com/tafli/setDING/pull/486))
- Song display styles per section type (ADR-0033): the section role is derived from
  the section name ([#473](https://github.com/tafli/setDING/pull/473)), songs are rendered in the styles ([#475](https://github.com/tafli/setDING/pull/475)), and the settings
  have a song display section with presets, an editor and a preview next to the
  controls ([#474](https://github.com/tafli/setDING/pull/474), [#476](https://github.com/tafli/setDING/pull/476), [#479](https://github.com/tafli/setDING/pull/479)), described in the user guide ([#477](https://github.com/tafli/setDING/pull/477))
- Own settings category for organizations and bands ([#482](https://github.com/tafli/setDING/pull/482))
- Convert CCLI bar lines to chord grids in the editor ([#483](https://github.com/tafli/setDING/pull/483))
- Eye button to show the password on sign-in ([#491](https://github.com/tafli/setDING/pull/491))

### Fixed

- Chord grids are laid out like a table, wide ones scaled to fit ([#487](https://github.com/tafli/setDING/pull/487))
- The server hint in the settings no longer says "only change for testing" ([#492](https://github.com/tafli/setDING/pull/492))
- Sync on Windows trusts the bundled ISRG root certificates ([#493](https://github.com/tafli/setDING/pull/493))

## [0.11.0] - 2026-11-18

### Added

- Section backgrounds for comment headings in the editor ([#466](https://github.com/tafli/setDING/pull/466))
- ChordPro syntax page and drummer mode on the website ([#460](https://github.com/tafli/setDING/pull/460))

### Fixed

- Both erasers show an eraser icon in drawing mode ([#462](https://github.com/tafli/setDING/pull/462))
- Section headings after leading comments are recognised ([#465](https://github.com/tafli/setDING/pull/465))

## [0.10.2] - 2026-11-18

### Fixed

- Restore the readable live play button on narrow screens ([#456](https://github.com/tafli/setDING/pull/456))

## [0.10.1] - 2026-11-18

### Fixed

- Readable live play button on narrow screens ([#451](https://github.com/tafli/setDING/pull/451))

## [0.10.0] - 2026-11-18

### Added

- Personal freehand annotations (ADR-0032) ([#431](https://github.com/tafli/setDING/pull/431)), with larger drawing toolbar
  buttons in live mode ([#448](https://github.com/tafli/setDING/pull/448))
- Beat and set list instead of the song map on phones ([#425](https://github.com/tafli/setDING/pull/425))
- Setting to stop or keep the click in the background ([#426](https://github.com/tafli/setDING/pull/426))
- More screenshots in the user documentation ([#416](https://github.com/tafli/setDING/pull/416), [#418](https://github.com/tafli/setDING/pull/418))

### Changed

- The Android APK is built for arm64 devices only ([#414](https://github.com/tafli/setDING/pull/414))
- The live play button stands out ([#446](https://github.com/tafli/setDING/pull/446))
- New slogan and informal address ("du") on the German website ([#409](https://github.com/tafli/setDING/pull/409))
- Upgrade pdfrx to 3.0.2 and pdfrx_engine to 0.9.5 ([#415](https://github.com/tafli/setDING/pull/415), [#430](https://github.com/tafli/setDING/pull/430), [#436](https://github.com/tafli/setDING/pull/436), [#440](https://github.com/tafli/setDING/pull/440))

### Fixed

- The drummer click plays in the web client ([#413](https://github.com/tafli/setDING/pull/413))
- The beat starts when the audio output does not answer ([#423](https://github.com/tafli/setDING/pull/423))

## [0.9.0] - 2026-11-17

### Added

- Website and user documentation at <https://setding.app> ([#390](https://github.com/tafli/setDING/pull/390)): sets ([#398](https://github.com/tafli/setDING/pull/398)),
  live mode ([#401](https://github.com/tafli/setDING/pull/401)), songs ([#402](https://github.com/tafli/setDING/pull/402)), bands and roles ([#403](https://github.com/tafli/setDING/pull/403)) and settings ([#404](https://github.com/tafli/setDING/pull/404)), and a
  landing page without sidebar ([#405](https://github.com/tafli/setDING/pull/405))

### Changed

- The server runs PocketBase 0.42.3 from its new host ([#391](https://github.com/tafli/setDING/pull/391))

### Fixed

- A failing website step no longer interrupts the server upgrade ([#399](https://github.com/tafli/setDING/pull/399))

## [0.8.0] - 2026-11-17

### Added

- Drummer mode: drums instrument preset and drummer settings ([#344](https://github.com/tafli/setDING/pull/344)), a click engine
  with the audio as the clock ([#347](https://github.com/tafli/setDING/pull/347)), beat display, count-in and tempo on stage
  ([#349](https://github.com/tafli/setDING/pull/349)), start and stop of the beat with the pedal or Enter ([#350](https://github.com/tafli/setDING/pull/350)), and a song map
  layout ([#351](https://github.com/tafli/setDING/pull/351)), also wide with a large beat and the set ([#360](https://github.com/tafli/setDING/pull/360))
- Editor: more section types in the Sections menu ([#359](https://github.com/tafli/setDING/pull/359)); move lines and chords,
  line tools and undo/redo buttons ([#366](https://github.com/tafli/setDING/pull/366)); search with highlighted matches ([#369](https://github.com/tafli/setDING/pull/369)),
  replace ([#376](https://github.com/tafli/setDING/pull/376)) and case-sensitive search and replace ([#380](https://github.com/tafli/setDING/pull/380)); convert
  chords-over-lyrics text to ChordPro ([#370](https://github.com/tafli/setDING/pull/370)); section backgrounds in the ChordPro
  source ([#373](https://github.com/tafli/setDING/pull/373)); a tap in the preview puts the cursor at the tapped character
  ([#374](https://github.com/tafli/setDING/pull/374), [#382](https://github.com/tafli/setDING/pull/382)); drag and drop selected text with the mouse ([#378](https://github.com/tafli/setDING/pull/378)); tap a line
  number to select the line ([#385](https://github.com/tafli/setDING/pull/385))
- Organization admins create bands on the organization screen ([#367](https://github.com/tafli/setDING/pull/367))
- Pull to refresh on the sets and songs lists starts a sync ([#386](https://github.com/tafli/setDING/pull/386))
- The server is deployed after a green release build; builds carry CI build
  numbers ([#346](https://github.com/tafli/setDING/pull/346))

### Fixed

- The server is deployed from a checkout of the release tag outside the
  repository ([#352](https://github.com/tafli/setDING/pull/352))
- People are reloaded when opening an organization or band ([#356](https://github.com/tafli/setDING/pull/356))
- Tap zones cover the whole screen in the wide song map ([#365](https://github.com/tafli/setDING/pull/365))

## [0.7.0] - 2026-11-17

### Added

- Personal settings are synced with the account (ADR-0027) ([#340](https://github.com/tafli/setDING/pull/340))
- Outdated clients are asked to update (minimum client version, ADR-0029) ([#341](https://github.com/tafli/setDING/pull/341))
- Meter model and the `{x_time_grouping}` directive ([#342](https://github.com/tafli/setDING/pull/342))

## [0.6.0] - 2026-11-17

### Changed

- **Breaking:** the app is renamed from RealChord to setDING ([#321](https://github.com/tafli/setDING/pull/321))
- setDING logo and night-blue brand colour ([#323](https://github.com/tafli/setDING/pull/323))

### Fixed

- The server installation restarts sshd through the socket-safe systemctl call ([#322](https://github.com/tafli/setDING/pull/322))

## [0.5.0] - 2026-11-17

### Added

- Registration mode and email verification set by the server operator (ADR-0024) ([#214](https://github.com/tafli/setDING/pull/214))
- Finer-grained roles for organizations and bands (ADR-0023) ([#217](https://github.com/tafli/setDING/pull/217))
- Band arrangements between song and set item (ADR-0025) ([#224](https://github.com/tafli/setDING/pull/224))
- Reorder sequence parts by drag and drop ([#223](https://github.com/tafli/setDING/pull/223)) and edit the song sequence in the
  song details form ([#242](https://github.com/tafli/setDING/pull/242))
- Choose the live view per song in the set list ([#220](https://github.com/tafli/setDING/pull/220))
- Song list: sequence and key badge ([#244](https://github.com/tafli/setDING/pull/244)), tempo and band arrangement hint ([#246](https://github.com/tafli/setDING/pull/246)),
  sorting by title, artist, key or last edit ([#248](https://github.com/tafli/setDING/pull/248), [#260](https://github.com/tafli/setDING/pull/260)), filter by key ([#250](https://github.com/tafli/setDING/pull/250)), two
  columns on wide screens ([#252](https://github.com/tafli/setDING/pull/252)), status icons for conflicts, PDF-only songs and
  upcoming gigs ([#254](https://github.com/tafli/setDING/pull/254)), and highlighted search hits that show where the lyrics
  matched ([#256](https://github.com/tafli/setDING/pull/256))
- Sets: grouped into upcoming, without date and past ([#274](https://github.com/tafli/setDING/pull/274)), past sets collapsed by
  default ([#283](https://github.com/tafli/setDING/pull/283)), and the selected set next to the list on wide screens ([#278](https://github.com/tafli/setDING/pull/278))
- Live mode: only the parts of the sequence in a set ([#259](https://github.com/tafli/setDING/pull/259)), the next song prepared
  before the page turn ([#276](https://github.com/tafli/setDING/pull/276)), larger key, tempo and time signature in the header
  ([#279](https://github.com/tafli/setDING/pull/279)), stage appearance (dark/black) independent of the app theme ([#281](https://github.com/tafli/setDING/pull/281)), page
  turns with Bluetooth page turners and the keyboard ([#284](https://github.com/tafli/setDING/pull/284)) including Arrow Down and
  Arrow Up ([#292](https://github.com/tafli/setDING/pull/292)), a hint that more pages of the song follow ([#306](https://github.com/tafli/setDING/pull/306)), and a progress
  bar of the set ([#313](https://github.com/tafli/setDING/pull/313))
- Undo deletions from a snackbar ([#280](https://github.com/tafli/setDING/pull/280))
- Choose the accent colour ([#301](https://github.com/tafli/setDING/pull/301))
- Warn about text after a directive in the editor and offer a quick fix ([#310](https://github.com/tafli/setDING/pull/310))
- Show songs with ChordPro problems after import, in lists and sets ([#315](https://github.com/tafli/setDING/pull/315))

### Changed

- **Breaking:** the Android application ID is `app.realchord` ([#299](https://github.com/tafli/setDING/pull/299))
- Colour scheme derived from the brand red ([#285](https://github.com/tafli/setDING/pull/285))
- Song settings in side panels; the scope of a setting (personal, set, band, song)
  is shown behind a (?) icon ([#230](https://github.com/tafli/setDING/pull/230), [#232](https://github.com/tafli/setDING/pull/232), [#234](https://github.com/tafli/setDING/pull/234))
- Upgrade pdfrx to 2.13.0 ([#212](https://github.com/tafli/setDING/pull/212))

### Fixed

- The band key is shown only in the band arrangement card ([#228](https://github.com/tafli/setDING/pull/228))
- Band panel buttons aligned with the key picker ([#236](https://github.com/tafli/setDING/pull/236))
- Tidier set list rows and live view choice ([#238](https://github.com/tafli/setDING/pull/238))
- The offline status of a set is an icon, aligned right ([#240](https://github.com/tafli/setDING/pull/240))
- Song title and break label shown only once ([#273](https://github.com/tafli/setDING/pull/273))
- Break labels in the current UI language ([#293](https://github.com/tafli/setDING/pull/293))
- Sequence chips of chorus and pre-chorus can be told apart ([#291](https://github.com/tafli/setDING/pull/291))
- The screen stays on reliably in live mode ([#302](https://github.com/tafli/setDING/pull/302))
- Requests rejected by the server rate limits are retried ([#304](https://github.com/tafli/setDING/pull/304))
- Layouts are kept while the keyboard opens for the song search ([#308](https://github.com/tafli/setDING/pull/308))
- No dropped frames at song changes in live mode ([#307](https://github.com/tafli/setDING/pull/307))

## [0.4.0] - 2026-11-16

### Added

- Edit the main song metadata in a form in the editor ([#192](https://github.com/tafli/setDING/pull/192)), with key and capo
  dropdowns ([#194](https://github.com/tafli/setDING/pull/194))
- Shape key with the sounding key next to the capo ([#198](https://github.com/tafli/setDING/pull/198)), also in the personal capo
  menu ([#200](https://github.com/tafli/setDING/pull/200))
- Selectable chord display style with raised extensions ([#197](https://github.com/tafli/setDING/pull/197))

### Changed

- Upgrade material_ui, cupertino_ui and file_picker ([#191](https://github.com/tafli/setDING/pull/191))

### Fixed

- The sounding key stays the key with a personal capo ([#202](https://github.com/tafli/setDING/pull/202))
- The key is shown next to the capo on the capo button ([#204](https://github.com/tafli/setDING/pull/204))

## [0.3.0] - 2026-11-16

### Added

- Fit-to-page button next to the font size buttons in live mode ([#174](https://github.com/tafli/setDING/pull/174)), also
  without automatic fitting ([#176](https://github.com/tafli/setDING/pull/176))
- Long songs are split into pages instead of scrolling ([#179](https://github.com/tafli/setDING/pull/179)), turned by swiping
  ([#182](https://github.com/tafli/setDING/pull/182))
- Attach-PDF button directly on the song screen ([#180](https://github.com/tafli/setDING/pull/180))
- Fit the song to the screen on the song screen ([#185](https://github.com/tafli/setDING/pull/185))
- Toggle between chords and Nashville numbers in the live control bar ([#186](https://github.com/tafli/setDING/pull/186))

## [0.2.0] - 2026-11-16

### Added

- App version in the settings; failed sign-ins are logged ([#146](https://github.com/tafli/setDING/pull/146))
- Two PDF pages side by side in landscape in live mode ([#153](https://github.com/tafli/setDING/pull/153))
- Logo, shown while the app starts ([#154](https://github.com/tafli/setDING/pull/154), [#160](https://github.com/tafli/setDING/pull/160)) and as the app icon on all
  platforms ([#156](https://github.com/tafli/setDING/pull/156)) and at the top of the navigation rail ([#166](https://github.com/tafli/setDING/pull/166))
- Settings grouped into categories ([#164](https://github.com/tafli/setDING/pull/164))
- Import ChordPro files in the web client ([#165](https://github.com/tafli/setDING/pull/165))
- Choose the song library per organization on the songs tab ([#168](https://github.com/tafli/setDING/pull/168))

### Removed

- Foot pedal and keyboard page turning in live mode ([#152](https://github.com/tafli/setDING/pull/152))

### Fixed

- The app icon is shown under Wayland ([#158](https://github.com/tafli/setDING/pull/158))

## [0.1.1] - 2026-11-16

### Fixed

- The Android app declares the INTERNET permission in its main manifest ([#142](https://github.com/tafli/setDING/pull/142))

## [0.1.0] - 2026-11-16

### Added

- First release, built on GitHub Actions for Linux, Android and Windows ([#138](https://github.com/tafli/setDING/pull/138))

[0.14.0]: https://github.com/tafli/setDING/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/tafli/setDING/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/tafli/setDING/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/tafli/setDING/compare/v0.10.2...v0.11.0
[0.10.2]: https://github.com/tafli/setDING/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/tafli/setDING/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/tafli/setDING/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/tafli/setDING/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/tafli/setDING/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/tafli/setDING/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/tafli/setDING/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/tafli/setDING/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/tafli/setDING/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/tafli/setDING/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/tafli/setDING/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/tafli/setDING/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/tafli/setDING/releases/tag/v0.1.0
