# ADR-0047: Set markers with a chosen icon and text

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

A set holds songs and two kinds of non-song entries (ADR-0015): a **break**
(`type: pause`) and a **text** (`type: text`), each with an optional `note`. They
are added with two commands in the set's menu, *Add break* and *Add text*. Live
mode shows them as a page of their own with a fixed icon (a coffee cup for a
break, a megaphone for a text) and the note as the title (ADR-0007).

The two types differ only in a few details today:

| | Break | Text |
|---|---|---|
| Icon in live mode | coffee cup | megaphone |
| Empty note | allowed: shows "Pause" / "Break" in each member's language (#289) | not allowed |
| Printable set list and text export (ADR-0013) | always printed, in the PDF as a divider line with the text in the middle | a plain muted line; left out without a note of its own |

Everything else is the same: a page of its own in live mode, dashed in the set
progress bar, not numbered, same rights, sync and undo.

Bands use these entries for much more than breaks and announcements: an encore,
a change of instrument, tuning, a guest on stage, the click on or off, light and
effects. With one icon for every text, the stage page does not tell at a glance
what comes next, and the set editor shows a list of identical rows.

Constraints:

- The note is shared with the whole band, whose members may use different UI
  languages (ADR-0008).
- Sets are synced as a whole, last writer wins (ADR-0004, ADR-0015). Older apps
  read `type` and save a set with the items they know; since 0.17.0 they keep
  unknown item fields in `extra` (ADR-0046), older ones drop them.
- Icons must look the same on Android, iOS, Windows, Linux and the web, and the
  web build tree-shakes the icon font (ADR-0018).

## Decision

### One kind of marker, no type

Breaks and texts become one kind of entry, a **marker**, made of an **icon** and
an optional **text**. There is no break or text type any more in the app: the
icon and the default name follow from the chosen icon, and **every marker is a
divider** in the printable set list and the text export. The stored `type` stays
only for older apps (see *Data*).

### One command: *Add marker*

The set's menu gets one command **Add marker** (*Hinweis hinzufügen*) in place of
*Add break* and *Add text*. Its dialog has:

1. an **icon grid**, grouped by topic (see the catalogue below), one icon
   selected (default: *break*);
2. a **text** field, **prefilled with the default name of the selected icon**,
   limited to **24 characters** (see *Text length*);
3. a **preview** of the marker's page in live mode.

Choosing another icon replaces the text with the new icon's default name as long
as the text is still a default name (not edited). Once the person types a text of
their own, choosing another icon keeps it. The text can be overwritten or cleared
at any time.

Editing a marker opens the same dialog. The set editor shows the chosen icon in
the marker's row with its text of its own, otherwise the icon's default name;
never both, as in live mode.

### Default name in each member's language

A text that is **empty or equal to the default name of its icon in any supported
language** counts as no text of its own and is **stored empty**. Every member then
sees the icon's default name in their own UI language: a prefilled "Zugabe" that
was left as it is shows as "Encore" in English. This extends #289 (where a break
named "Pause" or "Break" counts as no note) from the type label to the icon's
name (`markerNote`, `markerTitle`). A text of its own is shown as typed.

### Text length

A marker's text is limited to **24 characters**. It is a short label, not a
paragraph: it has to fit in the middle of a divider line of the printable set
list next to the song titles, and to stay readable at a glance in large type on
the stage page. 24 characters hold the longer default names ("Change of
instrument", "Instrumentwechsel") and short notes like "Ansage: Begrüssung" or
"Zugabe: Last Call"; anything longer belongs in a song's notes. The dialog shows
a counter and accepts no more. Notes of older apps may be longer: they are kept
as they are and shortened with an ellipsis where space is tight (set list
divider, set editor row); live mode wraps them. The server does not enforce the
limit, so older apps keep working.

### Icon catalogue

The app has a **curated catalogue** of marker icons. Each entry has a **stable
key** stored in the data (never a Material code point or an icon name of a font),
a Material icon and a localized **default name** (ARB, de-CH and en) of at most
24 characters:

| Group | Key | Default name (en / de-CH) |
|---|---|---|
| Break | `break` | Break / Pause |
| Break | `drinks` | Drinks / Getränke |
| Announcement | `announcement` | Announcement / Ansage |
| Announcement | `microphone` | Speech / Rede |
| Announcement | `guest` | Guest / Gast |
| Flow | `encore` | Encore / Zugabe |
| Flow | `transition` | Transition / Übergang |
| Flow | `solo` | Solo / Solo |
| Flow | `applause` | Applause / Applaus |
| Stage | `instrument` | Change of instrument / Instrumentwechsel |
| Stage | `tuning` | Tuning / Stimmen |
| Stage | `click` | Click / Click |
| Show | `light` | Light / Licht |
| Show | `effects` | Effects / Effekte |
| Show | `celebration` | Celebration / Feier |
| General | `info` | Note / Hinweis |
| General | `warning` | Attention / Achtung |

The exact icons and names are settled in the implementation; new entries can be
added later without a schema change. An unknown key (from a newer app) shows a
neutral marker icon.

### Data

- **Server:** a new optional field **`icon`** (catalogue key) in the item JSON of
  `setlists.items` (ADR-0015). No schema change.
- **`type` for older apps only:** apps with this ADR still write `type`, derived
  from the icon: `pause` for the icons of the *Break* group, `text` for the
  others, so older apps keep showing breaks as breaks. They never read it for a marker that has an
  `icon`.
- **Markers without an icon** (written by older apps) get one from their type:
  `pause` → `break`, `text` → `announcement`. A text item without a note of its
  own then shows "Announcement" instead of being left out of the set list.
- **Client:** the local `set_items.type` becomes `song` or `marker` and a nullable
  column `set_items.icon` is added (one schema migration that maps the existing
  breaks and texts as above). The sync layer, the backup archive and the set
  archive (ADR-0043) read and write `icon` and the derived `type`.
- **Older apps:** apps from 0.17.0 keep `icon` in `extra` when they save a set.
  For older apps, the server hook `pb_hooks/setlists.pb.js` keeps the stored
  `icon` of an item that is sent again with the same ID **without** the field, as
  it does for `played` (ADR-0046). Apps with this ADR always send the field.
- No new permission: markers are set items, edited by whoever may edit the set
  (ADR-0023).

### Where markers show

- **Set editor:** the icon in the leading slot and the title (text of its own or
  default name).
- **Live mode:** the marker's page shows its icon and title (ADR-0007).
- **Printable set list (ADR-0013)** and **text export:** every marker as a
  divider line with its title in the middle (no icon, see the decision log).
  The set list is thus split into blocks at every marker.

### Not in this decision

A duration with a countdown for breaks, markers shown only to certain instruments
or roles, colours and a "set 1 / set 2" split are possible follow-ups. They need
their own fields and are decided separately.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **One kind of marker, icon from a curated catalogue, every marker a divider, text prefilled and limited** (chosen) | One place to add any marker; no type to understand; one rule for the set list; same look on every platform; default names translated | Many small markers split the set list into many blocks; a curated list may lack an icon a band wants (new entries need an app update) |
| A divider per icon (e.g. only break and encore) | The set list shows only the big parts as blocks | One more property per icon to explain; unclear which markers divide |
| No limit on the text | Any note fits | Long notes break the divider line and the stage page |
| Keep the types, the icon decides the type | No local schema change of `type` | Two concepts for one thing; the divider is tied to "break" |
| Keep two commands, add an icon picker to *Add text* only | Smallest change | Two commands for the same thing; breaks still cannot get another icon |
| Free choice of any Material icon, stored as a code point | Unlimited choice | Code points are not stable across Flutter versions; the web build tree-shakes unused icons; no translated default names |
| Emoji as the icon (stored in the note) | No catalogue, works in every text field | Looks different on every platform and font; hard to read on stage; no default names |
| Store the prefilled text as typed | Simple | The creator's language is shown to every member |

## Consequences

- Adding a marker is one command; the stage page tells at a glance what comes.
- The text field is never empty when the dialog opens, and the default name
  still shows in each member's language.
- New UI texts: the command, the dialog and one default name per catalogue entry,
  in `app_de.arb` and `app_en.arb` (ADR-0008).
- One client schema migration (`set_items.type` and `set_items.icon`); the sync,
  backup and set archive formats gain the optional field; the server hook gains
  the keep rule.
- Text markers without a note of their own now appear in the set list, and
  every former text item becomes a divider there.
- The website pages for sets and live mode and their screenshots are updated
  (ADR-0030).
- An app update is needed for each new catalogue entry.

## Decision log

- 2026-11-21: Proposed (#717).
- 2026-11-21: No break or text type any more: the icon decides the divider in
  the set list, the text is prefilled with the icon's default name and can be
  overwritten; `type` is written only for older apps (owner, #717).
- 2026-11-21: Every marker is a divider in the set list (no divider per icon);
  the text is limited to 24 characters (owner, #717).
- 2026-11-21: Accepted by the owner (#718).
- 2026-11-21: Data layer implemented (#722): catalogue `MarkerIcons`
  (`app/lib/data/marker_icons.dart`), local schema 29 (`set_items.type`
  `song`/`marker`, `set_items.icon`), sync, backup and set archive with
  `icon` and the derived `type`; the server hook `pb_hooks/setlists.pb.js`
  keeps `played` and `icon` alike. A song missing from an imported set
  archive (ADR-0043 §1b) becomes a marker with the *warning* icon.
- 2026-11-21: Dialog implemented (#723): *Add marker* replaces *Add break* and
  *Add text*; icon groups side by side, text prefilled and limited to 24
  characters, preview; the set editor shows the marker's icon, live mode its
  icon and title.
- 2026-11-21: Set list dividers implemented (#724): every marker is a divider
  line with its title in the printable set list; a text marker without a note
  of its own shows its icon's name instead of being left out. The PDF shows
  **no icon**: the PDF renderer cannot use the app's Material icon font, and
  the title alone names the marker (resolves the open point). A longer note of
  an older app is shortened to 24 characters with an ellipsis. The plain-text
  export of the set list no longer exists (only the PDF).
- 2026-11-21: The set editor no longer shows the icon's name below a marker's
  text of its own: the icon already names the kind, and live mode shows only
  the text too.

## Open points

- The final catalogue (icons, keys, names, groups).
- Follow-ups: break duration with a countdown, markers per instrument or role,
  colours, a set split.
