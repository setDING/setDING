# Changelog

All notable changes to setDING are documented in this file. The section of a
version is also the text of its [GitHub Release](https://github.com/setDING/setDING/releases).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the setDING-specific bump rules of
[ADR-0028](docs/architecture/adr/0028-versioning-scheme.md).

## [0.24.0-beta.1] - 2026-11-27

Pre-release to try the lyrics projection on devices before the final 0.24.0 (installed with Obtainium with *Include prereleases*; not on Google Play).

### Added

- **Project the lyrics** from live mode (ADR-0068): *Project lyrics* in the live controls serves the lyrics without chords to any browser in the same network – a projector laptop, a TV or OBS – with a QR code to open it. The slides follow the set and the page of the song; a projection bar moves to the previous or next slide, blanks the screen and shows a hint when a song has no `{copyright}`. Native apps only, not the web client ([#1173](https://github.com/setDING/setDING/pull/1173), [#1174](https://github.com/setDING/setDING/pull/1174), [#1175](https://github.com/setDING/setDING/pull/1175), [#1176](https://github.com/setDING/setDING/pull/1176))
- Projection settings: colours, font, alignment, lines per slide, copyright on every or on the first and last slide, a second language from the song's language versions, set markers as text, a preview of the next slide, and the section (*Verse 1*, *Chorus*) small above the lyrics ([#1177](https://github.com/setDING/setDING/pull/1177), [#1186](https://github.com/setDING/setDING/pull/1186))
- A lower-third page with a transparent background for livestreams in OBS ([#1175](https://github.com/setDING/setDING/pull/1175))
- *Turning pages moves the slides*: the page turner first moves through the slides of a song, then to the next song ([#1182](https://github.com/setDING/setDING/pull/1182))
- The projection address stays the same on a device; *New address* locks out old links ([#1184](https://github.com/setDING/setDING/pull/1184))
- Installs from Google Play are pointed to Google Play for updates ([#1151](https://github.com/setDING/setDING/pull/1151))
- Pre-releases through Obtainium and the test server ([#1179](https://github.com/setDING/setDING/pull/1179))

## [0.23.1] - 2026-11-27

The release build of 0.23.0 failed, so 0.23.0 was never published: **this is the first release with the changes listed under [0.23.0](https://github.com/setDING/setDING/blob/main/CHANGELOG.md#0230---2026-11-27)** (people without an account in the lineup, share links for sets and songs, QR code scan to join, and more).

### Changed

- Updated libraries ([#1136](https://github.com/setDING/setDING/pull/1136))

### Fixed

- The Linux release builds again with the QR code scanner's native code; nothing changes for Linux users ([#1134](https://github.com/setDING/setDING/pull/1134))

## [0.23.0] - 2026-11-27

### Added

- **People without an account** in a set's lineup (ADR-0064): admins add contacts such as stand-ins to the organization, put them in a set's lineup next to the members, see them in the set view and the set list, and can send them a personal invitation that turns the contact into an account ([#1105](https://github.com/setDING/setDING/pull/1105), [#1108](https://github.com/setDING/setDING/pull/1108), [#1109](https://github.com/setDING/setDING/pull/1109), [#1110](https://github.com/setDING/setDING/pull/1110))
- **Share links** for sets and songs (ADR-0065): *Share link* in the set and song menu; the link opens the set or song in the app, in the right band, or says that it is not available on this device. In the web client every screen has its own address, and the browser's back and forward buttons and a reload work ([#1120](https://github.com/setDING/setDING/pull/1120), [#1121](https://github.com/setDING/setDING/pull/1121), [#1124](https://github.com/setDING/setDING/pull/1124))
- On Android and iOS, join a band by scanning the invitation's QR code ([#1104](https://github.com/setDING/setDING/pull/1104))
- Held beats (`.`) in chord grids show as dots, so the beats of a bar can be counted ([#1092](https://github.com/setDING/setDING/pull/1092))
- Converting a song (magic wand, *Convert all*, import) translates German section labels into English, and a German comment heading becomes the matching section ([#1088](https://github.com/setDING/setDING/pull/1088))
- The website has a privacy policy and a legal notice ([#1119](https://github.com/setDING/setDING/pull/1119))
- For server operators: every server bundle and the server image come with a CycloneDX SBOM; the server keeps request logs for 7 days (`SETDING_LOG_DAYS`) ([#1086](https://github.com/setDING/setDING/pull/1086), [#1119](https://github.com/setDING/setDING/pull/1119))

### Changed

- **Breaking for self-hosters:** the project moved to the GitHub organization [setDING](https://github.com/setDING/setDING); the server image is now `ghcr.io/setding/setding-server` (ADR-0066) ([#1128](https://github.com/setDING/setDING/pull/1128))
- Updated libraries ([#1083](https://github.com/setDING/setDING/pull/1083))

### Fixed

- Intro, Interlude, Solo, Outro and Pre-Chorus sections get their own style instead of the verse style ([#1094](https://github.com/setDING/setDING/pull/1094))
- Sets can be exported in the web client ([#1087](https://github.com/setDING/setDING/pull/1087))
- The automatic backup works into folders that reject temporary file names, such as a Nextcloud folder on Android ([#1107](https://github.com/setDING/setDING/pull/1107))
- The SongSelect `{footer}` directive is now `{x_ccli_footer}`, the song info menu no longer offers the CCLI number, and the editor suggests only the *colour* spelling of colour directives ([#1083](https://github.com/setDING/setDING/pull/1083), [#1089](https://github.com/setDING/setDING/pull/1089), [#1091](https://github.com/setDING/setDING/pull/1091))

## [0.22.1] - 2026-11-26

### Changed

- Updated libraries ([#1075](https://github.com/setDING/setDING/pull/1075))

### Fixed

- The server image `ghcr.io/tafli/setding-server` is published, and the release carries only the server bundles of its own version; 0.22.0 had no image and two misplaced bundles ([#1076](https://github.com/setDING/setDING/pull/1076))

## [0.22.0] - 2026-11-26

### Added

- Run the setDING server yourself (ADR-0063): every release now comes with a **server bundle** for Linux (amd64 and arm64) that runs as it is or as a systemd service, and a **Docker image** `ghcr.io/tafli/setding-server`; both contain the web app and are tested before they are published, including the update from the previous release ([#1060](https://github.com/setDING/setDING/pull/1060), [#1061](https://github.com/setDING/setDING/pull/1061), [#1063](https://github.com/setDING/setDING/pull/1063))
- A new website chapter *Self-hosting* explains the installation with Docker or without, the reverse proxy in front, the settings, backups and updates ([#1069](https://github.com/setDING/setDING/pull/1069))
- For server operators: `pocketbase healthcheck`, automatic backups set with `SETDING_BACKUP_CRON` and `SETDING_BACKUP_KEEP` ([#1057](https://github.com/setDING/setDING/pull/1057))

### Changed

- **For server operators:** the server no longer starts without `SETDING_INVITE_KEY`, and says so in its log ([#1057](https://github.com/setDING/setDING/pull/1057))
- Updated libraries ([#1059](https://github.com/setDING/setDING/pull/1059), [#1067](https://github.com/setDING/setDING/pull/1067))

## [0.21.0] - 2026-11-23

### Added

- First and last name for every account, plus an optional nickname (ADR-0062): sign-up and *Change name* ask for them, accounts without a full name are asked once after sign-in, and the setting *Show names as* chooses how other people's names appear in member lists, lineups and recent changes; existing names are split automatically ([#1043](https://github.com/setDING/setDING/pull/1043))
- The editor can translate German section labels such as *Strophe* or *Refrain* into English, for the selected lines or the whole song ([#1038](https://github.com/setDING/setDING/pull/1038))
- In the song display settings, tapping a section in the preview selects its type, and the preview uses the whole page ([#1041](https://github.com/setDING/setDING/pull/1041))
- The CCLI number in the sources panel links to the song on SongSelect ([#1037](https://github.com/setDING/setDING/pull/1037))
- An attachment can be saved as a file ([#1029](https://github.com/setDING/setDING/pull/1029))
- Importing a single song opens it right after the import ([#1030](https://github.com/setDING/setDING/pull/1030))

### Changed

- Sequence chips start dragging after 250 ms instead of 500 ms ([#1028](https://github.com/setDING/setDING/pull/1028))
- Destructive menu actions such as *Delete* come last in every menu, after a divider ([#1032](https://github.com/setDING/setDING/pull/1032))

### Fixed

- Swiss German lyrics are detected as Swiss German instead of German ([#1034](https://github.com/setDING/setDING/pull/1034))

## [0.20.0] - 2026-11-23

### Added

- Lineup per set and substitutes (ADR-0061): choose who plays a set in the set editor, notify the lineup by share menu, copy or mail, and see the lineup on the printable set list; substitutes see only the sets they are planned for, read-only, and the overview shows upcoming substitute gigs and the sets you are planned for ([#1016](https://github.com/setDING/setDING/pull/1016), [#1019](https://github.com/setDING/setDING/pull/1019), [#1020](https://github.com/setDING/setDING/pull/1020), [#1021](https://github.com/setDING/setDING/pull/1021), [#1022](https://github.com/setDING/setDING/pull/1022)); a new website page explains it ([#1023](https://github.com/setDING/setDING/pull/1023))
- Song review and mistake reports (ADR-0060): imported songs are marked *To review* and can be approved one by one or all at once; everyone can report a mistake in a song, also on stage from the live control bar, with a category, a comment and a screenshot with markings; whoever may edit the song resolves the report with an answer, which the reporter is told after the next sync ([#994](https://github.com/setDING/setDING/pull/994), [#999](https://github.com/setDING/setDING/pull/999), [#1000](https://github.com/setDING/setDING/pull/1000), [#1005](https://github.com/setDING/setDING/pull/1005), [#1014](https://github.com/setDING/setDING/pull/1014)); a new website page explains it ([#1017](https://github.com/setDING/setDING/pull/1017))
- The app in Italian, French, Spanish and Portuguese ([#996](https://github.com/setDING/setDING/pull/996))
- In-app help links to the matching page of the documentation ([#998](https://github.com/setDING/setDING/pull/998))
- Roman numerals can be spelled like a chord symbol (`IIm7`) instead of by case (`ii7`), as a setting ([#980](https://github.com/setDING/setDING/pull/980), [#982](https://github.com/setDING/setDING/pull/982)); the website explains both spellings ([#984](https://github.com/setDING/setDING/pull/984))
- Drummer mode on phones and narrow tablets: switch the drum panel between the set and the song map of the current song, with the beat in one third of the screen ([#958](https://github.com/setDING/setDING/pull/958), [#964](https://github.com/setDING/setDING/pull/964), [#967](https://github.com/setDING/setDING/pull/967), [#970](https://github.com/setDING/setDING/pull/970), [#977](https://github.com/setDING/setDING/pull/977))
- In live mode, the Space key starts and stops the beat ([#973](https://github.com/setDING/setDING/pull/973)), and holding and dragging on the set progress bar jumps to a song ([#981](https://github.com/setDING/setDING/pull/981))
- *Show a written-out chorus only once*: a display setting that leaves out a chorus repeated word for word, e.g. in songs from SongSelect ([#962](https://github.com/setDING/setDING/pull/962))
- The editor offers to convert comment headings such as `{comment: Chorus}` into ChordPro sections ([#966](https://github.com/setDING/setDING/pull/966))
- Linux: the AppImage can add itself to the application menu, and `setding://` invitation links open the Linux app ([#1013](https://github.com/setDING/setDING/pull/1013), [#1018](https://github.com/setDING/setDING/pull/1018))

### Changed

- Choruses whose words change are stacked like verses ([#960](https://github.com/setDING/setDING/pull/960))
- Choosing the instrument *Vocals* turns on *Lyrics only*; switching to another instrument brings the chords back ([#1002](https://github.com/setDING/setDING/pull/1002))

## [0.19.0] - 2026-11-22

### Added

- Chord views (ADR-0055): chords can be shown as chord names, Nashville numbers or Roman numerals, as a setting and as a personal adjustment per song, and switched in the live control bar ([#910](https://github.com/setDING/setDING/pull/910), [#912](https://github.com/setDING/setDING/pull/912), [#914](https://github.com/setDING/setDING/pull/914)); a new website page explains the views ([#918](https://github.com/setDING/setDING/pull/918), [#922](https://github.com/setDING/setDING/pull/922))
- Key suggestions (ADR-0056): setDING suggests a key from the chords for songs without `{key}`, also in the import report, and reports an empty or invalid `{key}` as a ChordPro problem ([#924](https://github.com/setDING/setDING/pull/924), [#929](https://github.com/setDING/setDING/pull/929), [#936](https://github.com/setDING/setDING/pull/936))
- Page turner (ADR-0057): pair it in the settings and see whether it is connected; the app asks whether you use one and offers to pair a detected one ([#921](https://github.com/setDING/setDING/pull/921), [#945](https://github.com/setDING/setDING/pull/945))
- Automatic backup of the local library (ADR-0054) into a chosen folder, which the settings show with its full path, and restoring a backup by replacing the local library ([#852](https://github.com/setDING/setDING/pull/852), [#894](https://github.com/setDING/setDING/pull/894), [#858](https://github.com/setDING/setDING/pull/858))
- Overview: a readiness tile with setup hints that jump to the settings, the newest songs, more sets and songs not played for a while ([#917](https://github.com/setDING/setDING/pull/917), [#873](https://github.com/setDING/setDING/pull/873))
- Language versions: choose several at once in a two-pane dialog that names the song and lists only songs not yet chosen; flags in the language dialog and *No language* in the language filter ([#855](https://github.com/setDING/setDING/pull/855), [#859](https://github.com/setDING/setDING/pull/859), [#863](https://github.com/setDING/setDING/pull/863), [#848](https://github.com/setDING/setDING/pull/848), [#836](https://github.com/setDING/setDING/pull/836))
- Trash: delete permanently, a more readable list, and in the sets only shown as a small link when there are deleted sets ([#871](https://github.com/setDING/setDING/pull/871), [#905](https://github.com/setDING/setDING/pull/905))
- Export: one export entry with a format choice for songs and sets; archives are named `*.setDING.zip` ([#872](https://github.com/setDING/setDING/pull/872), [#875](https://github.com/setDING/setDING/pull/875))
- Chord diagrams for 4- or 5-string bass ([#944](https://github.com/setDING/setDING/pull/944))
- A setting to hide the local library ([#869](https://github.com/setDING/setDING/pull/869)); the voice or role setting is optional and can be cleared ([#941](https://github.com/setDING/setDING/pull/941))
- The band switcher groups bands by organization, and the band and song library selection stay in sync ([#867](https://github.com/setDING/setDING/pull/867), [#862](https://github.com/setDING/setDING/pull/862))

### Changed

- The song picker of a set looks and works like the song list ([#885](https://github.com/setDING/setDING/pull/885), [#887](https://github.com/setDING/setDING/pull/887))
- Menus: an icon in front of every action, destructive actions in the error colour, app bar actions in the overflow menu on narrow screens, and *Repertoire* in the set list's overflow menu ([#837](https://github.com/setDING/setDING/pull/837), [#844](https://github.com/setDING/setDING/pull/844), [#850](https://github.com/setDING/setDING/pull/850), [#854](https://github.com/setDING/setDING/pull/854))
- Settings are pinned to the bottom of the navigation rail; storage and backup settings are tidied up; danger zones are a red-tinted tile set apart with a divider ([#943](https://github.com/setDING/setDING/pull/943), [#897](https://github.com/setDING/setDING/pull/897), [#830](https://github.com/setDING/setDING/pull/830), [#892](https://github.com/setDING/setDING/pull/892))
- Personal adjustments use a single-person icon; checkboxes stand in front of their label everywhere ([#849](https://github.com/setDING/setDING/pull/849), [#880](https://github.com/setDING/setDING/pull/880), [#881](https://github.com/setDING/setDING/pull/881))

### Fixed

- Flat and sharp signs in chords are drawn correctly ([#916](https://github.com/setDING/setDING/pull/916))
- New attachment downloads stop as soon as the connection breaks ([#942](https://github.com/setDING/setDING/pull/942))
- Replacing the local library keeps the creation date of songs; copying songs to another library keeps their language version links ([#877](https://github.com/setDING/setDING/pull/877), [#879](https://github.com/setDING/setDING/pull/879))
- Invitations say which role a band invite gives, and that an organization invite joins as member without a band yet ([#904](https://github.com/setDING/setDING/pull/904), [#895](https://github.com/setDING/setDING/pull/895))
- An unknown registration mode is no longer treated as an open server ([#831](https://github.com/setDING/setDING/pull/831))
- *No language* is offered only when songs without a language exist ([#846](https://github.com/setDING/setDING/pull/846))
- The sets page keeps a single ⋮ menu ([#883](https://github.com/setDING/setDING/pull/883)); the overview keeps the version line at the bottom and shows the page turner line without a pairing on Android and Windows ([#898](https://github.com/setDING/setDING/pull/898), [#931](https://github.com/setDING/setDING/pull/931))

## [0.18.0] - 2026-11-22

### Added

- Language versions of a song (ADR-0053): setDING detects the language of a song, lets you set it and filter the song list by it ([#811](https://github.com/setDING/setDING/pull/811), [#812](https://github.com/setDING/setDING/pull/812)); songs in different languages can be linked as versions of one song and are shown in the song view ([#815](https://github.com/setDING/setDING/pull/815)); a set item can switch to another language version ([#820](https://github.com/setDING/setDING/pull/820)), personal adjustments can be copied from another version ([#821](https://github.com/setDING/setDING/pull/821)), and song and backup archives keep the links ([#822](https://github.com/setDING/setDING/pull/822))
- Account: change your display name and password, and delete your own account (ADR-0052) ([#786](https://github.com/setDING/setDING/pull/786), [#790](https://github.com/setDING/setDING/pull/790), [#791](https://github.com/setDING/setDING/pull/791))
- Set markers with an icon and text (ADR-0047): a dialog with an icon picker adds them, and every marker is a divider in the set list ([#735](https://github.com/setDING/setDING/pull/735), [#737](https://github.com/setDING/setDING/pull/737), [#740](https://github.com/setDING/setDING/pull/740))
- Set archive (ADR-0043): an exported set can be imported again as a set, with a clearer import dialog and names for copies; exported PDFs open in the default app ([#712](https://github.com/setDING/setDING/pull/712), [#720](https://github.com/setDING/setDING/pull/720), [#728](https://github.com/setDING/setDING/pull/728))
- Songs can be exported and imported with their attachments ([#793](https://github.com/setDING/setDING/pull/793))
- The SongSelect import removes the CCLI footer and keeps song number and copyright as directives ([#788](https://github.com/setDING/setDING/pull/788)); songs with places the editor offers to convert get a magic wand icon in the song list and the overview and can be converted from it ([#799](https://github.com/setDING/setDING/pull/799), [#801](https://github.com/setDING/setDING/pull/801))
- Song list: the overview's to-do filters as filter chips, a *Played* chip and tag filters in menus, and deleting several selected songs ([#801](https://github.com/setDING/setDING/pull/801), [#818](https://github.com/setDING/setDING/pull/818), [#741](https://github.com/setDING/setDING/pull/741))
- Song editor typing aids: brackets, quotes and section blocks close themselves, section start and end are renamed together, snippets wrap the selected lines, chorus labels are suggested after `{chorus:`; a switch in the settings turns the aids off ([#751](https://github.com/setDING/setDING/pull/751), [#760](https://github.com/setDING/setDING/pull/760), [#761](https://github.com/setDING/setDING/pull/761), [#762](https://github.com/setDING/setDING/pull/762), [#765](https://github.com/setDING/setDING/pull/765), [#764](https://github.com/setDING/setDING/pull/764))
- LilyPond blocks are drawn as notation (a lead-sheet subset) instead of only their source ([#736](https://github.com/setDING/setDING/pull/736))
- The drummer sets the grouping of an odd meter and the subdivisions of the click per song ([#702](https://github.com/setDING/setDING/pull/702))
- A hint says who changed the open song or set when a sync brings changes ([#705](https://github.com/setDING/setDING/pull/705))
- Keyboard shortcuts: Esc goes back on every screen and closes the song selection and editor; E, L, +/-, the arrow keys and search, with a help overview ([#727](https://github.com/setDING/setDING/pull/727), [#734](https://github.com/setDING/setDING/pull/734), [#742](https://github.com/setDING/setDING/pull/742), [#752](https://github.com/setDING/setDING/pull/752))

### Changed

- The offline status of a set shows only problems and warns when the last sync is too old, instead of a green mark on every set ([#769](https://github.com/setDING/setDING/pull/769))
- *Edit set* is a pencil button in the set's app bar; the set list as text was removed ([#715](https://github.com/setDING/setDING/pull/715)); a tap on the set card of the overview opens the set ([#694](https://github.com/setDING/setDING/pull/694))
- Settings in sections with dividers and an icon on every option, in two columns on wide screens; the song display is customised from a row of its own ([#768](https://github.com/setDING/setDING/pull/768), [#781](https://github.com/setDING/setDING/pull/781), [#789](https://github.com/setDING/setDING/pull/789))
- A more consistent UI across screens: shared page widths, dialogs, messages and export flows (ADR-0051); the song editor's save button is easier to see ([#746](https://github.com/setDING/setDING/pull/746), [#750](https://github.com/setDING/setDING/pull/750), [#771](https://github.com/setDING/setDING/pull/771), [#775](https://github.com/setDING/setDING/pull/775), [#753](https://github.com/setDING/setDING/pull/753))

### Fixed

- Chord suffixes of the ChordPro reference list are recognised ([#814](https://github.com/setDING/setDING/pull/814))
- Directives of CCLI SongSelect files are made standard-conforming on import ([#782](https://github.com/setDING/setDING/pull/782))
- *What's new* shows only the current version ([#776](https://github.com/setDING/setDING/pull/776))
- A set marker shows its own text without the icon's name ([#767](https://github.com/setDING/setDING/pull/767))
- Leaving live mode while a song's personal adjustments were loading could raise an error ([#826](https://github.com/setDING/setDING/pull/826))
- *Recent changes* hides songs and sets deleted afterwards ([#706](https://github.com/setDING/setDING/pull/706))
- The Motif XF menu path in the MIDI help is Utility → Control → MIDI ([#697](https://github.com/setDING/setDING/pull/697))

### Security

- The server refuses deleting a user account directly through the API; accounts are deleted only through the account deletion flow ([#783](https://github.com/setDING/setDING/pull/783))

## [0.17.0] - 2026-11-20

### Added

- Overview tab as the new start screen: the next set with *Start live*, songs that need attention (ChordPro problems, sync conflicts, sheet music only), the version, update hint and *What's new* ([#670](https://github.com/setDING/setDING/pull/670)); *Recent changes* lists new and changed songs and sets of other members ([#673](https://github.com/setDING/setDING/pull/673), [#675](https://github.com/setDING/setDING/pull/675), [#668](https://github.com/setDING/setDING/pull/668))
- Song play history (ADR-0046): a song in a past set counts as played, with key, tempo and sequence of that day. The *Played* panel in the song view shows the plays of the band and of the organization's other bands, the set's key picker hints at the last and most played key, and the song picker shows the last play ([#671](https://github.com/setDING/setDING/pull/671), [#682](https://github.com/setDING/setDING/pull/682))
- Band repertoire behind the Sets tab: most played songs, songs not played for a while (threshold per band) and never played songs; the song list sorts by *Last played* and filters by *Never played* / *Not played for a while*; organization admins and librarians see which songs of the library no band played ([#678](https://github.com/setDING/setDING/pull/678), [#682](https://github.com/setDING/setDING/pull/682))
- Trash: deleted songs and sets can be restored for 30 days ([#631](https://github.com/setDING/setDING/pull/631)); organization admins can delete a band and close an organization, both restorable from the trash (ADR-0044) ([#642](https://github.com/setDING/setDING/pull/642), [#646](https://github.com/setDING/setDING/pull/646))
- Backups (ADR-0043): back up a library as a ZIP archive from the song list and import it again ([#636](https://github.com/setDING/setDING/pull/636)); *Back up everything* in the settings saves every library you may back up, your personal adjustments and settings, with a reminder when the local library was not backed up for 30 days ([#641](https://github.com/setDING/setDING/pull/641))
- Keyboard programs per device profile (ADR-0042): a song keeps one program per keyboard, so a keyboard player can switch keyboards without adapting the songs; new profile *Yamaha Motif XF*, all Nord program kinds in the program dialog ([#589](https://github.com/setDING/setDING/pull/589), [#595](https://github.com/setDING/setDING/pull/595), [#596](https://github.com/setDING/setDING/pull/596), [#598](https://github.com/setDING/setDING/pull/598), [#604](https://github.com/setDING/setDING/pull/604))
- Live mode shows the song's keyboard program, lets you edit it and take it over from the keyboard ([#606](https://github.com/setDING/setDING/pull/606), [#610](https://github.com/setDING/setDING/pull/610), [#611](https://github.com/setDING/setDING/pull/611), [#612](https://github.com/setDING/setDING/pull/612)); guided send and receive tests per keyboard in the MIDI test ([#614](https://github.com/setDING/setDING/pull/614), [#616](https://github.com/setDING/setDING/pull/616))
- The editor offers to convert section labels to the form the ChordPro specification recommends (`{start_of_verse: label="Verse 1"}`), which setDING now writes; the import report offers the same ([#676](https://github.com/setDING/setDING/pull/676))
- Tap a stroke to select it with the lasso tool in the annotation editor ([#588](https://github.com/setDING/setDING/pull/588))
- Invitation links show when they were created ([#638](https://github.com/setDING/setDING/pull/638))

### Changed

- *Edit ChordPro* is a pencil button in the song screen's app bar, with the number of ChordPro problems as a badge ([#603](https://github.com/setDING/setDING/pull/603))
- Beta builds show `beta` and the commit instead of the build number in their version ([#654](https://github.com/setDING/setDING/pull/654), [#658](https://github.com/setDING/setDING/pull/658))

### Fixed

- The first press of a page turner in live mode turns the page ([#669](https://github.com/setDING/setDING/pull/669))
- Switching the page turner on or off no longer restarts the app on Android ([#685](https://github.com/setDING/setDING/pull/685))

### Security

- Every permission is enforced and tested on the server; bands and organizations can no longer be deleted directly through the API, and client filters cannot reveal other organizations' data ([#624](https://github.com/setDING/setDING/pull/624), [#630](https://github.com/setDING/setDING/pull/630), [#633](https://github.com/setDING/setDING/pull/633))
- Invitation links are built from the configured app URL, never from the request's Host header ([#621](https://github.com/setDING/setDING/pull/621))

## [0.16.0] - 2026-11-19

### Added

- Keyboard program changes over MIDI (ADR-0039): musicians whose instrument is keyboard connect a keyboard in the new *Keyboard (MIDI)* settings (Nord Stage 3 or generic profile), store a personal keyboard program per song with a test button, and live mode sends it when a song becomes current, with "Send program again" and a connection indicator ([#566](https://github.com/setDING/setDING/pull/566), [#567](https://github.com/setDING/setDING/pull/567), [#569](https://github.com/setDING/setDING/pull/569), [#571](https://github.com/setDING/setDING/pull/571), [#580](https://github.com/setDING/setDING/pull/580))
- Text tool in the annotation editor: type notes onto ChordPro and PDF pages and move, resize, recolour and erase them like stamps ([#577](https://github.com/setDING/setDING/pull/577))
- Invitation links in the organization settings show their band and can be shown again (link and QR code); revoked and expired links are no longer listed ([#581](https://github.com/setDING/setDING/pull/581))
- News page on the website with the notes of every version, and the current version in its header ([#572](https://github.com/setDING/setDING/pull/572), [#574](https://github.com/setDING/setDING/pull/574))

### Changed

- The on-screen keyboard no longer shrinks the page in live mode ([#577](https://github.com/setDING/setDING/pull/577))
- Server operators: `make server-release` adds a random `SETDING_INVITE_KEY` to `pocketbase.env`; links created before this release cannot be shown again, but keep working ([#581](https://github.com/setDING/setDING/pull/581))

## [0.15.0] - 2026-11-19

### Added

- In live mode, parts outside the sequence are shown dimmed at their place in the song; a personal setting hides them as before ([#551](https://github.com/setDING/setDING/pull/551))
- The live mode of a single song applies the sequence of the current band, otherwise the song's own `{x_sequence}` ([#553](https://github.com/setDING/setDING/pull/553)); members of several bands choose the band in the song's arrangement panel ([#557](https://github.com/setDING/setDING/pull/557))
- "What's new" notes are shown once after an app update (ADR-0041) ([#546](https://github.com/setDING/setDING/pull/546))
- Developer mode in the general settings with a category for test features, starting with a MIDI test screen as prototype of program changes (ADR-0039) ([#513](https://github.com/setDING/setDING/pull/513), [#560](https://github.com/setDING/setDING/pull/560))

### Changed

- Settings order: General first among the personal categories, account and organization categories at the bottom ([#549](https://github.com/setDING/setDING/pull/549), [#555](https://github.com/setDING/setDING/pull/555))

### Fixed

- The click no longer runs ahead when the audio engine stands still ([#547](https://github.com/setDING/setDING/pull/547))

## [0.14.0] - 2026-11-19

### Added

- Linux AppImage that updates itself (ADR-0038) ([#504](https://github.com/setDING/setDING/pull/504))
- Open song attachments without starting the live view ([#508](https://github.com/setDING/setDING/pull/508))
- CycloneDX SBOM for every release asset (ADR-0037) ([#509](https://github.com/setDING/setDING/pull/509))
- Personal option to show the chords in the first verse only ([#519](https://github.com/setDING/setDING/pull/519))
- Black/white colour in the song display palette ([#528](https://github.com/setDING/setDING/pull/528))
- Sort chord suggestions in the editor and show them after "Insert chord" ([#529](https://github.com/setDING/setDING/pull/529))
- Stack verses with the same chords line by line ([#531](https://github.com/setDING/setDING/pull/531))
- Monospace font option in the song display settings ([#530](https://github.com/setDING/setDING/pull/530))
- Hyphen between syllables split by a chord in stacked verses ([#534](https://github.com/setDING/setDING/pull/534))
- Black/white song display preset ([#537](https://github.com/setDING/setDING/pull/537)), with bold, larger headings ([#539](https://github.com/setDING/setDING/pull/539))

### Changed

- Upgrade dbus, jni and jni_flutter ([#515](https://github.com/setDING/setDING/pull/515)) and pdfrx to 3.0.3 ([#525](https://github.com/setDING/setDING/pull/525))

### Fixed

- The Android app starts again: jni pinned to 1.1.2 ([#517](https://github.com/setDING/setDING/pull/517))
- Song section names stay in English in every language ([#535](https://github.com/setDING/setDING/pull/535))

## [0.13.0] - 2026-11-18

### Added

- Unobtrusive update check on start (ADR-0036) ([#499](https://github.com/setDING/setDING/pull/499))
- Windows installer with in-app updates (ADR-0035) ([#495](https://github.com/setDING/setDING/pull/495))

## [0.12.0] - 2026-11-18

### Added

- Song sources via `{x_link}` ([#470](https://github.com/setDING/setDING/pull/470)), editable and removable in the sources panel ([#486](https://github.com/setDING/setDING/pull/486))
- Song display styles per section type (ADR-0033): the section role is derived from
  the section name ([#473](https://github.com/setDING/setDING/pull/473)), songs are rendered in the styles ([#475](https://github.com/setDING/setDING/pull/475)), and the settings
  have a song display section with presets, an editor and a preview next to the
  controls ([#474](https://github.com/setDING/setDING/pull/474), [#476](https://github.com/setDING/setDING/pull/476), [#479](https://github.com/setDING/setDING/pull/479)), described in the user guide ([#477](https://github.com/setDING/setDING/pull/477))
- Own settings category for organizations and bands ([#482](https://github.com/setDING/setDING/pull/482))
- Convert CCLI bar lines to chord grids in the editor ([#483](https://github.com/setDING/setDING/pull/483))
- Eye button to show the password on sign-in ([#491](https://github.com/setDING/setDING/pull/491))

### Fixed

- Chord grids are laid out like a table, wide ones scaled to fit ([#487](https://github.com/setDING/setDING/pull/487))
- The server hint in the settings no longer says "only change for testing" ([#492](https://github.com/setDING/setDING/pull/492))
- Sync on Windows trusts the bundled ISRG root certificates ([#493](https://github.com/setDING/setDING/pull/493))

## [0.11.0] - 2026-11-18

### Added

- Section backgrounds for comment headings in the editor ([#466](https://github.com/setDING/setDING/pull/466))
- ChordPro syntax page and drummer mode on the website ([#460](https://github.com/setDING/setDING/pull/460))

### Fixed

- Both erasers show an eraser icon in drawing mode ([#462](https://github.com/setDING/setDING/pull/462))
- Section headings after leading comments are recognised ([#465](https://github.com/setDING/setDING/pull/465))

## [0.10.2] - 2026-11-18

### Fixed

- Restore the readable live play button on narrow screens ([#456](https://github.com/setDING/setDING/pull/456))

## [0.10.1] - 2026-11-18

### Fixed

- Readable live play button on narrow screens ([#451](https://github.com/setDING/setDING/pull/451))

## [0.10.0] - 2026-11-18

### Added

- Personal freehand annotations (ADR-0032) ([#431](https://github.com/setDING/setDING/pull/431)), with larger drawing toolbar
  buttons in live mode ([#448](https://github.com/setDING/setDING/pull/448))
- Beat and set list instead of the song map on phones ([#425](https://github.com/setDING/setDING/pull/425))
- Setting to stop or keep the click in the background ([#426](https://github.com/setDING/setDING/pull/426))
- More screenshots in the user documentation ([#416](https://github.com/setDING/setDING/pull/416), [#418](https://github.com/setDING/setDING/pull/418))

### Changed

- The Android APK is built for arm64 devices only ([#414](https://github.com/setDING/setDING/pull/414))
- The live play button stands out ([#446](https://github.com/setDING/setDING/pull/446))
- New slogan and informal address ("du") on the German website ([#409](https://github.com/setDING/setDING/pull/409))
- Upgrade pdfrx to 3.0.2 and pdfrx_engine to 0.9.5 ([#415](https://github.com/setDING/setDING/pull/415), [#430](https://github.com/setDING/setDING/pull/430), [#436](https://github.com/setDING/setDING/pull/436), [#440](https://github.com/setDING/setDING/pull/440))

### Fixed

- The drummer click plays in the web client ([#413](https://github.com/setDING/setDING/pull/413))
- The beat starts when the audio output does not answer ([#423](https://github.com/setDING/setDING/pull/423))

## [0.9.0] - 2026-11-17

### Added

- Website and user documentation at <https://setding.app> ([#390](https://github.com/setDING/setDING/pull/390)): sets ([#398](https://github.com/setDING/setDING/pull/398)),
  live mode ([#401](https://github.com/setDING/setDING/pull/401)), songs ([#402](https://github.com/setDING/setDING/pull/402)), bands and roles ([#403](https://github.com/setDING/setDING/pull/403)) and settings ([#404](https://github.com/setDING/setDING/pull/404)), and a
  landing page without sidebar ([#405](https://github.com/setDING/setDING/pull/405))

### Changed

- The server runs PocketBase 0.42.3 from its new host ([#391](https://github.com/setDING/setDING/pull/391))

### Fixed

- A failing website step no longer interrupts the server upgrade ([#399](https://github.com/setDING/setDING/pull/399))

## [0.8.0] - 2026-11-17

### Added

- Drummer mode: drums instrument preset and drummer settings ([#344](https://github.com/setDING/setDING/pull/344)), a click engine
  with the audio as the clock ([#347](https://github.com/setDING/setDING/pull/347)), beat display, count-in and tempo on stage
  ([#349](https://github.com/setDING/setDING/pull/349)), start and stop of the beat with the pedal or Enter ([#350](https://github.com/setDING/setDING/pull/350)), and a song map
  layout ([#351](https://github.com/setDING/setDING/pull/351)), also wide with a large beat and the set ([#360](https://github.com/setDING/setDING/pull/360))
- Editor: more section types in the Sections menu ([#359](https://github.com/setDING/setDING/pull/359)); move lines and chords,
  line tools and undo/redo buttons ([#366](https://github.com/setDING/setDING/pull/366)); search with highlighted matches ([#369](https://github.com/setDING/setDING/pull/369)),
  replace ([#376](https://github.com/setDING/setDING/pull/376)) and case-sensitive search and replace ([#380](https://github.com/setDING/setDING/pull/380)); convert
  chords-over-lyrics text to ChordPro ([#370](https://github.com/setDING/setDING/pull/370)); section backgrounds in the ChordPro
  source ([#373](https://github.com/setDING/setDING/pull/373)); a tap in the preview puts the cursor at the tapped character
  ([#374](https://github.com/setDING/setDING/pull/374), [#382](https://github.com/setDING/setDING/pull/382)); drag and drop selected text with the mouse ([#378](https://github.com/setDING/setDING/pull/378)); tap a line
  number to select the line ([#385](https://github.com/setDING/setDING/pull/385))
- Organization admins create bands on the organization screen ([#367](https://github.com/setDING/setDING/pull/367))
- Pull to refresh on the sets and songs lists starts a sync ([#386](https://github.com/setDING/setDING/pull/386))
- The server is deployed after a green release build; builds carry CI build
  numbers ([#346](https://github.com/setDING/setDING/pull/346))

### Fixed

- The server is deployed from a checkout of the release tag outside the
  repository ([#352](https://github.com/setDING/setDING/pull/352))
- People are reloaded when opening an organization or band ([#356](https://github.com/setDING/setDING/pull/356))
- Tap zones cover the whole screen in the wide song map ([#365](https://github.com/setDING/setDING/pull/365))

## [0.7.0] - 2026-11-17

### Added

- Personal settings are synced with the account (ADR-0027) ([#340](https://github.com/setDING/setDING/pull/340))
- Outdated clients are asked to update (minimum client version, ADR-0029) ([#341](https://github.com/setDING/setDING/pull/341))
- Meter model and the `{x_time_grouping}` directive ([#342](https://github.com/setDING/setDING/pull/342))

## [0.6.0] - 2026-11-17

### Changed

- **Breaking:** the app is renamed from RealChord to setDING ([#321](https://github.com/setDING/setDING/pull/321))
- setDING logo and night-blue brand colour ([#323](https://github.com/setDING/setDING/pull/323))

### Fixed

- The server installation restarts sshd through the socket-safe systemctl call ([#322](https://github.com/setDING/setDING/pull/322))

## [0.5.0] - 2026-11-17

### Added

- Registration mode and email verification set by the server operator (ADR-0024) ([#214](https://github.com/setDING/setDING/pull/214))
- Finer-grained roles for organizations and bands (ADR-0023) ([#217](https://github.com/setDING/setDING/pull/217))
- Band arrangements between song and set item (ADR-0025) ([#224](https://github.com/setDING/setDING/pull/224))
- Reorder sequence parts by drag and drop ([#223](https://github.com/setDING/setDING/pull/223)) and edit the song sequence in the
  song details form ([#242](https://github.com/setDING/setDING/pull/242))
- Choose the live view per song in the set list ([#220](https://github.com/setDING/setDING/pull/220))
- Song list: sequence and key badge ([#244](https://github.com/setDING/setDING/pull/244)), tempo and band arrangement hint ([#246](https://github.com/setDING/setDING/pull/246)),
  sorting by title, artist, key or last edit ([#248](https://github.com/setDING/setDING/pull/248), [#260](https://github.com/setDING/setDING/pull/260)), filter by key ([#250](https://github.com/setDING/setDING/pull/250)), two
  columns on wide screens ([#252](https://github.com/setDING/setDING/pull/252)), status icons for conflicts, PDF-only songs and
  upcoming gigs ([#254](https://github.com/setDING/setDING/pull/254)), and highlighted search hits that show where the lyrics
  matched ([#256](https://github.com/setDING/setDING/pull/256))
- Sets: grouped into upcoming, without date and past ([#274](https://github.com/setDING/setDING/pull/274)), past sets collapsed by
  default ([#283](https://github.com/setDING/setDING/pull/283)), and the selected set next to the list on wide screens ([#278](https://github.com/setDING/setDING/pull/278))
- Live mode: only the parts of the sequence in a set ([#259](https://github.com/setDING/setDING/pull/259)), the next song prepared
  before the page turn ([#276](https://github.com/setDING/setDING/pull/276)), larger key, tempo and time signature in the header
  ([#279](https://github.com/setDING/setDING/pull/279)), stage appearance (dark/black) independent of the app theme ([#281](https://github.com/setDING/setDING/pull/281)), page
  turns with Bluetooth page turners and the keyboard ([#284](https://github.com/setDING/setDING/pull/284)) including Arrow Down and
  Arrow Up ([#292](https://github.com/setDING/setDING/pull/292)), a hint that more pages of the song follow ([#306](https://github.com/setDING/setDING/pull/306)), and a progress
  bar of the set ([#313](https://github.com/setDING/setDING/pull/313))
- Undo deletions from a snackbar ([#280](https://github.com/setDING/setDING/pull/280))
- Choose the accent colour ([#301](https://github.com/setDING/setDING/pull/301))
- Warn about text after a directive in the editor and offer a quick fix ([#310](https://github.com/setDING/setDING/pull/310))
- Show songs with ChordPro problems after import, in lists and sets ([#315](https://github.com/setDING/setDING/pull/315))

### Changed

- **Breaking:** the Android application ID is `app.realchord` ([#299](https://github.com/setDING/setDING/pull/299))
- Colour scheme derived from the brand red ([#285](https://github.com/setDING/setDING/pull/285))
- Song settings in side panels; the scope of a setting (personal, set, band, song)
  is shown behind a (?) icon ([#230](https://github.com/setDING/setDING/pull/230), [#232](https://github.com/setDING/setDING/pull/232), [#234](https://github.com/setDING/setDING/pull/234))
- Upgrade pdfrx to 2.13.0 ([#212](https://github.com/setDING/setDING/pull/212))

### Fixed

- The band key is shown only in the band arrangement card ([#228](https://github.com/setDING/setDING/pull/228))
- Band panel buttons aligned with the key picker ([#236](https://github.com/setDING/setDING/pull/236))
- Tidier set list rows and live view choice ([#238](https://github.com/setDING/setDING/pull/238))
- The offline status of a set is an icon, aligned right ([#240](https://github.com/setDING/setDING/pull/240))
- Song title and break label shown only once ([#273](https://github.com/setDING/setDING/pull/273))
- Break labels in the current UI language ([#293](https://github.com/setDING/setDING/pull/293))
- Sequence chips of chorus and pre-chorus can be told apart ([#291](https://github.com/setDING/setDING/pull/291))
- The screen stays on reliably in live mode ([#302](https://github.com/setDING/setDING/pull/302))
- Requests rejected by the server rate limits are retried ([#304](https://github.com/setDING/setDING/pull/304))
- Layouts are kept while the keyboard opens for the song search ([#308](https://github.com/setDING/setDING/pull/308))
- No dropped frames at song changes in live mode ([#307](https://github.com/setDING/setDING/pull/307))

## [0.4.0] - 2026-11-16

### Added

- Edit the main song metadata in a form in the editor ([#192](https://github.com/setDING/setDING/pull/192)), with key and capo
  dropdowns ([#194](https://github.com/setDING/setDING/pull/194))
- Shape key with the sounding key next to the capo ([#198](https://github.com/setDING/setDING/pull/198)), also in the personal capo
  menu ([#200](https://github.com/setDING/setDING/pull/200))
- Selectable chord display style with raised extensions ([#197](https://github.com/setDING/setDING/pull/197))

### Changed

- Upgrade material_ui, cupertino_ui and file_picker ([#191](https://github.com/setDING/setDING/pull/191))

### Fixed

- The sounding key stays the key with a personal capo ([#202](https://github.com/setDING/setDING/pull/202))
- The key is shown next to the capo on the capo button ([#204](https://github.com/setDING/setDING/pull/204))

## [0.3.0] - 2026-11-16

### Added

- Fit-to-page button next to the font size buttons in live mode ([#174](https://github.com/setDING/setDING/pull/174)), also
  without automatic fitting ([#176](https://github.com/setDING/setDING/pull/176))
- Long songs are split into pages instead of scrolling ([#179](https://github.com/setDING/setDING/pull/179)), turned by swiping
  ([#182](https://github.com/setDING/setDING/pull/182))
- Attach-PDF button directly on the song screen ([#180](https://github.com/setDING/setDING/pull/180))
- Fit the song to the screen on the song screen ([#185](https://github.com/setDING/setDING/pull/185))
- Toggle between chords and Nashville numbers in the live control bar ([#186](https://github.com/setDING/setDING/pull/186))

## [0.2.0] - 2026-11-16

### Added

- App version in the settings; failed sign-ins are logged ([#146](https://github.com/setDING/setDING/pull/146))
- Two PDF pages side by side in landscape in live mode ([#153](https://github.com/setDING/setDING/pull/153))
- Logo, shown while the app starts ([#154](https://github.com/setDING/setDING/pull/154), [#160](https://github.com/setDING/setDING/pull/160)) and as the app icon on all
  platforms ([#156](https://github.com/setDING/setDING/pull/156)) and at the top of the navigation rail ([#166](https://github.com/setDING/setDING/pull/166))
- Settings grouped into categories ([#164](https://github.com/setDING/setDING/pull/164))
- Import ChordPro files in the web client ([#165](https://github.com/setDING/setDING/pull/165))
- Choose the song library per organization on the songs tab ([#168](https://github.com/setDING/setDING/pull/168))

### Removed

- Foot pedal and keyboard page turning in live mode ([#152](https://github.com/setDING/setDING/pull/152))

### Fixed

- The app icon is shown under Wayland ([#158](https://github.com/setDING/setDING/pull/158))

## [0.1.1] - 2026-11-16

### Fixed

- The Android app declares the INTERNET permission in its main manifest ([#142](https://github.com/setDING/setDING/pull/142))

## [0.1.0] - 2026-11-16

### Added

- First release, built on GitHub Actions for Linux, Android and Windows ([#138](https://github.com/setDING/setDING/pull/138))

[0.24.0-beta.1]: https://github.com/setDING/setDING/compare/v0.23.1...v0.24.0-beta.1
[0.23.1]: https://github.com/setDING/setDING/compare/v0.22.1...v0.23.1
[0.23.0]: https://github.com/setDING/setDING/compare/v0.22.1...v0.23.0
[0.22.1]: https://github.com/setDING/setDING/compare/v0.22.0...v0.22.1
[0.22.0]: https://github.com/setDING/setDING/compare/v0.21.0...v0.22.0
[0.21.0]: https://github.com/setDING/setDING/compare/v0.20.0...v0.21.0
[0.20.0]: https://github.com/setDING/setDING/compare/v0.19.0...v0.20.0
[0.19.0]: https://github.com/setDING/setDING/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/setDING/setDING/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/setDING/setDING/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/setDING/setDING/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/setDING/setDING/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/setDING/setDING/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/setDING/setDING/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/setDING/setDING/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/setDING/setDING/compare/v0.10.2...v0.11.0
[0.10.2]: https://github.com/setDING/setDING/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/setDING/setDING/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/setDING/setDING/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/setDING/setDING/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/setDING/setDING/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/setDING/setDING/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/setDING/setDING/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/setDING/setDING/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/setDING/setDING/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/setDING/setDING/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/setDING/setDING/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/setDING/setDING/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/setDING/setDING/releases/tag/v0.1.0
