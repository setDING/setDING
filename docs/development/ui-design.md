# UI design rules

> Binding for every screen, dialog and panel of the app.
> Decision record: [ADR-0051](../architecture/adr/0051-ui-design-rules.md).
> Settings screen: [ADR-0050](../architecture/adr/0050-settings-screen-layout.md) adds stricter rules on top (sections with dividers, an icon on every option).
> Colours and the logo: [branding.md](branding.md). Keyboard: [ADR-0049](../architecture/adr/0049-keyboard-shortcuts.md).

setDING has two faces: **management** (overview, sets, songs, people, settings),
built from plain Material 3 components, and **the stage** (live mode, the song
view), which has its own theme and renderer (ADR-0007, ADR-0033). These rules are
about the management screens; the stage keeps its own rules where it says so below.

The rules exist so that a person who learned one screen knows all of them: the same
thing looks the same and behaves the same everywhere. **Use the shared widgets** in
`app/lib/ui/widgets/`; do not build a second version of them. If a shared widget
does not fit, extend it (and this document) instead of copying it.

`app/test/ui_rules_test.dart` checks the rules that can be found in the source;
the others are checked in review.

## 1. Principles

1. **Stage first.** Nothing a management screen does may get in the way of live
   mode: no dialogs, hints or updates while playing (ADR-0007, ADR-0036, ADR-0041).
2. **Material 3, unstyled.** Standard components with the app theme
   (`appTheme`, `app/lib/ui/theme.dart`). No own button shapes, fonts or
   elevations on management screens.
3. **One way per thing.** One widget for a section header, one for a message, one
   for a confirmation. Consistency beats a local improvement.
4. **Quiet by default.** Hints go away by themselves, colour carries meaning
   (primary = interactive or current, error = destructive or failed), not decoration.
5. **Undo rather than ask** for one's own data; ask before something that affects
   others or cannot be undone.

## 2. Colours

- Colours come from `Theme.of(context).colorScheme` – they follow the accent colour
  and light/dark (branding.md, "Accent colours").
- States the scheme has no role for use **`StatusColors.of(context)`**:
  `success` (e.g. "available offline") and `warning` (e.g. ChordPro problems, a
  warning that is not an error).
- **No named Material colours** (`Colors.green`, `Colors.amber.shade900`, …).
  `Colors.black`, `Colors.white` and `Colors.transparent` are fine.
- Exceptions: the song renderer (`ui/render/`, ChordPro colours and the curated song
  display palette, ADR-0033) and the stage theme (`live/live_theme.dart`).

## 3. Layout and spacing

- **Spacing** in steps of 4: 4, 8, 12, 16, 24, 32. The horizontal inset of content in
  a list is **16**, aligned with the text of a `ListTile`; the gap between an icon and
  its text is **8**. The only smaller value is **2**, the inner padding of small badges
  and key caps. This covers literal paddings, gaps (`SizedBox` with one dimension) and
  `spacing`; the song renderer and the set list PDF scale with their font size and
  paper and are exempt.
- **Lists of tiles** (`ListView` of `ListTile`s) are the default for management
  screens. A `Card` is for a self-contained item among others (a set, a to-do on the
  overview), not for wrapping a whole page.
- **Width on large screens:** pages of tiles and forms limit their content to
  **720** with **`PageWidth`** (`widgets/page_width.dart`, top and centred),
  single-purpose forms such as signing in to **480** (`PageWidth(maxWidth:
  formMaxWidth)`). Controls inside the column wrap rather than scroll sideways
  (e.g. chips in a `Wrap` instead of a long segmented button). Lists that use the width (songs in two columns, the set
  grid) choose their columns with `BreakpointBuilder`. The settings are the
  exception: their content uses the full width of its pane and, from 1040, flows its
  sections into two columns (ADR-0050).
- Leave room under the last item for a floating action button (`bottom: 88`).
- **Song lists are one list.** The song list (Songs tab) and the song picker of a
  set (`ui/sets/song_picker.dart`) are built from the same parts in
  `ui/songs/song_list.dart`: `SongSearchBar`, `SongListFilter` with
  `SongFilters`, `SongListView` (sections and columns) and `SongTile`. A change to
  the search, an order, a filter, the sections, the columns or the tile is made
  there, so both get it; a new filter is a field of `SongListFilter`, a chip in
  `SongFilters` and a step in `filterSongList`. Only the overview's To do filters
  are left out of the picker (`attentionFilters: false`), and only the song list
  has selection mode and the management actions. `app/test/song_list_parity_test.dart`
  shows both with the same songs and fails when they offer different filters or
  show different songs; a new order or filter adds a case there (#886).

## 4. Section headers

- Every section of a list, panel or dialog starts with **`SectionHeader`**
  (`widgets/section_header.dart`): `titleSmall`, primary colour, bold, marked as a
  heading for screen readers.
- Padding: `SectionHeader.listPadding` (default, full-width lists) or
  `SectionHeader.insetPadding` (inside a dialog or another indented container).
- Optional `icon` before the label (e.g. the scope of a settings group) and
  `trailing` widget after it (a small action such as *Refresh*).
- Settings categories use `SettingsSection` (ADR-0050), which is built on
  `SectionHeader`.
- A header that needs its own layout (e.g. collapsible) uses
  `SectionHeader.style(context)` and `Semantics(header: true)`.

## 5. Actions

- **Create** on a main list screen (sets, songs, bands, a set's items): an extended
  `FloatingActionButton` with icon and label.
- **App bar actions:** icon buttons for the two or three most frequent actions, the
  rest in the overflow menu (`PopupMenuButton`). Every action in a menu is a
  **`MenuAction`** (`widgets/menu_action.dart`, #835): an icon in front of its
  label. Menus that choose a value (key, click, MIDI profile) mark the chosen one
  with a check instead; a disabled item without an icon is a group header.
  Where every choice has its own icon (the band and song library switchers,
  #864), the icon stays and the chosen entry is `ListTile(selected: true)` with
  the check at its end; a group header there may carry the icon of what it
  groups (the organization), with the entries indented below it.
  An action that deletes or removes something (delete, remove from set, remove a
  member, delete all annotations) is `MenuAction(destructive: true)`: icon and
  label in the error colour, like the danger zone (#839). It is the **last entry**
  of its menu, set apart from the actions above by a **`PopupMenuDivider`**
  (#1031), so it is not hit by mistake: e.g. *Rename*, *Save*, divider, *Delete*.
  **On narrow screens** the icon buttons that do not fit move to the top of the
  overflow menu, above a divider: **`AppBarActions`** (`widgets/app_bar_actions.dart`,
  #838) takes them in order of importance, shows as many as the screen width leaves
  room for next to the title and the others as `MenuAction`s with their badge; a
  dot on ⋮ shows that a hidden one has a badge. A key function (the song's *Edit*,
  #600) and the live button stay in the bar.
  **One ⋮ per view:** where a list and the open item sit side by side (sets),
  only the item has an overflow menu; a second ⋮ a few pixels away is taken
  for the item's (#882). The list's own actions are icon buttons, the trash is
  an entry at the end of the list (under the empty state when the list is
  empty), and importing is a secondary action of the *New …* dialog.
  Every `IconButton` has a
  **tooltip** (it is also its accessible name). A deliberate exception (the stage's
  MIDI button, whose long press a tooltip would take) has a `Semantics` label and a
  `// No tooltip:` comment just above it that says why.
- **Primary action of a dialog or form:** `FilledButton`; *Cancel* and secondary
  actions: `TextButton`, before the primary action.
- **Danger zone** (deleting the account, deleting a band, closing an organization):
  at the end of the screen, in the **`DangerZone`** tile (`widgets/danger_zone.dart`,
  #828), set apart from the content above by a full-width divider (#890): tinted with `errorContainer`, outlined in the error colour, with a
  *Danger zone* header in the error colour. Its actions are `OutlinedButton`s with
  the error colour as foreground. In the settings, `SettingsSection(danger: true)`
  draws the same tile.
- **Checkboxes lead their row**, in lists and in dialogs alike: the checkbox
  stands in front of its label, where the eye starts reading and every box lines
  up in one column, however long the labels (#881). A `CheckboxListTile` sets
  `controlAffinity: ListTileControlAffinity.leading` (Flutter puts it at the end
  by default). **Switches stay at the end**, like in the settings (ADR-0050).
- **Multi-select in a list** (songs, the trash, the song picker): a long press
  starts it, a tap then toggles an entry. The checkbox takes the place of the
  row's leading icon; the row's own menu is hidden while selecting, and the app
  bar shows *N selected* with the actions for the selection.
- Keyboard: Esc goes back, single-key shortcuts per screen with `PageShortcuts`
  (ADR-0049). A new frequent action gets a shortcut and a line in the *?* dialog.

## 6. Dialogs and confirmations

- `AlertDialog` with a title that names the action ("Delete song?") and a message that
  names the object and the consequence.
- **Confirm with `confirm()`** (`widgets/dialogs.dart`). It is destructive by default:
  the confirming button is filled in the error colours. For a question that destroys
  nothing (installing an update, signing out) pass `destructive: false`.
- An own dialog that confirms a destructive action uses
  **`destructiveButtonStyle(context)`** for its confirming button.
- **Text input** with `askText()`. Dialogs are at most about 420 wide for a form.
- **Deleting:**
  - one's own or the library's songs, sets, annotations and keyboard programs go to
    the trash or can be restored: confirm (if more than one tap away from undoing),
    then **`showUndo()`**;
  - removing people, revoking invitations, leaving a band: `confirm()`;
  - deleting a band or closing an organization: a dialog with the summary of what
    goes, `destructiveButtonStyle`, then `showUndo()`.

## 7. Messages

- Short feedback at the bottom of the screen with **`showMessage(context, …)`**, or
  **`showMessageOn(messenger, …)`** with a messenger taken before an `await` or before
  the screen closes. Never build a `SnackBar` yourself.
- A new message **replaces** the one shown. Only hints at app start that must not
  hide each other (what's new, backup reminder) pass `queue: true`.
- A message with an action (*Open*, *Show*, *Install*) **goes away by itself**
  (`messageActionDuration`): it is a hint, not a question. A question is a dialog.
- *Undo* after deleting: `showUndo()` (`undoDuration`).
- Errors from the server: `backendErrorText(l10n, kind)` as a message; problems that
  stay (sync conflict, update required) are a banner, not a message.

## 8. Loading, empty and error states

- Data from a provider: **`AsyncBody`** (spinner while loading, the error text).
- Nothing to show: **`EmptyState`** with an outlined icon, a sentence what is
  missing and, if there is one, the button that adds the first item.

## 9. Panels and sheets

- Settings that change what the current screen shows (song display, arrangement,
  links, history) open in a **`SidePanel`** (end drawer), so the change shows at
  once behind it.
- Bottom sheets are for live mode (choices that must be reachable with one hand on
  stage); management screens use dialogs and panels.

### Navigation between screens

- Every screen has a **path** in `app/lib/ui/routes.dart` (`AppPaths`) and is
  opened with `context.push(AppPaths.…)` (ADR-0065), so the browser's back and
  forward buttons follow the app, a reload keeps the screen and a link can open
  it. Records are named by their id. What a screen needs besides the path is a
  JSON `extra` (`songExtra`, `editorExtra`, `signInExtra`); the screen also works
  without it.
- Only **full-screen dialogs** that return a value (the song picker, the
  language version picker, marking a screenshot, an image attachment) keep a
  `MaterialPageRoute(fullscreenDialog: true)`. `ui_rules_test.dart` fails on any
  other page route.
- A screen that can lose unsaved changes asks through its `PopScope` and the
  route's `onExit` (the browser's back button does not ask the `PopScope`).

## 10. Texts, icons and accessibility

- Every text is in all ARB files (de-CH without "ß", en, fr, it, es, pt, ADR-0008); sentence case
  for titles, buttons and menu items.
- Prefer the **outlined** variant of a Material icon; filled for a selected state.
- Interactive elements are at least 48×48 (the Material defaults); custom tappable
  widgets carry a `Semantics` label.
- Hints that explain a whole screen sit at its top as `bodyMedium`, inset like the
  tiles (`EdgeInsets.fromLTRB(16, 16, 16, 8)`).
- **Help from the documentation** (#993): where a concept needs more than a hint
  (every settings category, the roles at the members of a band and the people of
  an organization, the ChordPro editor, a band's arrangement), a
  **`DocsHelpButton`** (`widgets/docs_link.dart`, the book icon, tooltip
  *Help: <topic>*) opens the page of the user documentation: next to the title of
  the screen or panel (`SidePanel(docs: …)`), or as `trailing` of its
  `SectionHeader`. Not on every option: a hint below the option explains it
  in place, a `DocsLink` under it leads on where a hint is not enough (the chord
  view). The small (?) of `ScopeInfo` stays reserved for whom a setting applies
  to. Every linked page is a `DocsPage`; the app links to **pages, never to
  headings**, whose anchors differ per language, and UI languages without their
  own documentation get the English pages. `website/src/app-docs-links.test.ts`
  fails when a `DocsPage` has no page in a language of the site.

## 11. Adding a screen – checklist

- [ ] Uses `SectionHeader`, `confirm()`/`destructiveButtonStyle`, `showMessage…`,
      `AsyncBody`, `EmptyState` where they apply.
- [ ] Colours only from the scheme or `StatusColors`.
- [ ] Width limited with `PageWidth` on large screens, spacing in steps of 4.
- [ ] Tooltips on icon buttons, texts in all ARB files.
- [ ] A concept that needs more than a hint has a `DocsHelpButton` (section 10).
- [ ] Shortcuts and Esc behave (ADR-0049).
- [ ] Has a path in `routes.dart` and opens with `context.push` (section 9).
- [ ] A screenshot on the website page (AGENTS.md, "User documentation and screenshots").
- [ ] A list of songs uses the parts of `ui/songs/song_list.dart`, and a change to
      the song list also reaches the song picker of a set (section 3).
- [ ] Reads and writes data through `app/lib/data/`, never with database
      queries of its own (section 12).

## 12. Data access

- Screens, dialogs and their providers read and write the local database only
  through the repositories, services and functions in `app/lib/data/`
  (ADR-0001, issue #1204). A file in `app/lib/ui/` never calls `db.select`,
  `db.selectOnly`, `db.update`, `db.into`, `db.delete`, `db.custom…` or
  `db.transaction` (nor `batch`): a query that a screen needs becomes a method
  of the repository it belongs to, where its tests reach it.
- Passing the database on to a function of `app/lib/data/` (e.g.
  `watchAnySet(ref.watch(databaseProvider), id)`) is fine.
  `ui_rules_test.dart` fails on a query in `app/lib/ui/`.
