# ADR-0047: Set markers with a chosen icon and text

- **Status:** Proposed
- **Date:** 2026-11-21

## Context

A set holds songs and two kinds of non-song entries (ADR-0015): a **break**
(`type: pause`) and a **text** (`type: text`), each with an optional `note`. They
are added with two commands in the set's menu, *Add break* and *Add text*. Live
mode shows them as a page of their own with a fixed icon (a coffee cup for a
break, a megaphone for a text) and the note as the title (ADR-0007).

Bands use these entries for much more than breaks and announcements: an encore,
a change of instrument, tuning, a guest on stage, the click on or off, light and
effects. With one icon for every text, the stage page does not tell at a glance
what comes next, and the set editor shows a list of identical rows.

Constraints:

- The note is shared with the whole band, whose members may use different UI
  languages (ADR-0008). A break without a note of its own shows "Pause" or
  "Break" in each member's language (#289).
- A break has a meaning of its own beyond its look: the printable set list and
  the text export print it even without a note (ADR-0013), the set progress bar
  draws it dashed, and a break is the natural place for a later "set 1 / set 2"
  split.
- Sets are synced as a whole, last writer wins (ADR-0004, ADR-0015). Older apps
  save a set with the items they know; since 0.17.0 they keep unknown item fields
  in `extra` (ADR-0046), older ones drop them.
- Icons must look the same on Android, iOS, Windows, Linux and the web, and the
  web build tree-shakes the icon font (ADR-0018).

## Decision

### One command: *Add marker*

The set's menu gets one command **Add marker** (*Hinweis hinzufügen*) in place of
*Add break* and *Add text*. Its dialog has:

1. an **icon grid**, grouped by topic (see the catalogue below), one icon
   selected (default: *break*);
2. an optional **text** field; its hint is the default name of the selected icon;
3. a **preview** of the marker's page in live mode.

Editing a marker opens the same dialog. The set editor shows the chosen icon in
the marker's row.

### Icon catalogue

The app has a **curated catalogue** of marker icons. Each entry has a **stable
key** stored in the data (never a Material code point or an icon name of a font),
a Material icon, a localized **default name** (ARB, de-CH and en) and the **type**
it gives the item:

| Group | Key | Default name (en / de-CH) | Type |
|---|---|---|---|
| Break | `break` | Break / Pause | `pause` |
| Break | `drinks` | Drinks / Getränke | `pause` |
| Announcement | `announcement` | Announcement / Ansage | `text` |
| Announcement | `microphone` | Speech / Rede | `text` |
| Announcement | `guest` | Guest / Gast | `text` |
| Flow | `encore` | Encore / Zugabe | `text` |
| Flow | `transition` | Transition / Übergang | `text` |
| Flow | `solo` | Solo / Solo | `text` |
| Flow | `applause` | Applause / Applaus | `text` |
| Stage | `instrument` | Change of instrument / Instrumentwechsel | `text` |
| Stage | `tuning` | Tuning / Stimmen | `text` |
| Stage | `click` | Click / Click | `text` |
| Show | `light` | Light / Licht | `text` |
| Show | `effects` | Effects / Effekte | `text` |
| Show | `celebration` | Celebration / Feier | `text` |
| General | `info` | Note / Hinweis | `text` |
| General | `warning` | Attention / Achtung | `text` |

The exact icons and names are settled in the implementation; new entries can be
added later without a schema change. An unknown key (from a newer app) shows the
icon of the item's type.

### The icon decides the type

The type of a marker follows from its icon: icons of the *Break* group give
`pause`, all others `text`. There is no separate "counts as a break" switch. The
set list, the text export, the progress bar and any later set split keep using
`type` and need no change.

### Default name in each member's language

Without a text of its own, a marker shows the **default name of its icon** in the
member's UI language, extending #289: the set editor, live mode and the set lists
use the icon's name where they use the type label today (`markerTitle`). A marker
without an icon (older data) keeps today's behaviour. The text is therefore
optional for every marker, and the text export and the printable set list print
a text marker without a note of its own by its icon's name (today such a text
item is left out).

### Data

- **Server:** a new optional field **`icon`** (catalogue key) in the item JSON of
  `setlists.items` (ADR-0015). No schema change.
- **Client:** a nullable column `set_items.icon` (one schema migration), read and
  written by the sync layer, the backup archive and the set archive (ADR-0043).
- **Older apps:** apps from 0.17.0 keep `icon` in `extra` when they save a set
  and show the icon of the type. For older apps, the server hook
  `pb_hooks/setlists.pb.js` keeps the stored `icon` of an item that is sent again
  with the same ID **without** the field, as it does for `played` (ADR-0046).
  Apps with this ADR always send the field (`null` to clear it).
- No new permission: markers are set items, edited by whoever may edit the set
  (ADR-0023).

### Where markers show

- **Set editor:** the icon in the leading slot, the title (own text or default
  name), the type label below a text of its own as today.
- **Live mode:** the marker's page shows its icon instead of the coffee cup or
  megaphone (ADR-0007).
- **Printable set list (ADR-0013)** and **text export:** the title; the PDF shows
  the icon too if the PDF font can render it, otherwise a neutral symbol.

### Not in this decision

A duration with a countdown for breaks, markers shown only to certain instruments
or roles, and colours are possible follow-ups. They need their own fields and are
decided separately.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **One command, icon from a curated catalogue, icon decides the type** (chosen) | One place to add any marker; same look on every platform; type semantics kept without a switch; default names translated | A curated list may lack an icon a band wants (new entries need an app update) |
| Keep two commands, add an icon picker to *Add text* only | Smallest change | Two commands for the same thing; breaks still cannot get another icon |
| Free choice of any Material icon, stored as a code point | Unlimited choice | Code points are not stable across Flutter versions; the web build tree-shakes unused icons; no translated default names |
| Emoji as the icon (stored in the note) | No catalogue, works in every text field | Looks different on every platform and font; hard to read on stage; no default names |
| A separate "counts as a break" switch | Any icon can be a break | One more control for a rare case; easy to get wrong |

## Consequences

- Adding a marker is one command; the stage page tells at a glance what comes.
- New UI texts: the command, the dialog and one default name per catalogue entry,
  in `app_de.arb` and `app_en.arb` (ADR-0008).
- One client schema migration (`set_items.icon`), the sync, backup and set
  archive formats gain the optional field; the server hook gains the keep rule.
- The website pages for sets and live mode and their screenshots are updated
  (ADR-0030).
- An app update is needed for each new catalogue entry.

## Decision log

- 2026-11-21: Proposed (#717).

## Open points

- The final catalogue (icons, keys, names, groups).
- Whether the printable set list embeds the Material icon font or uses neutral
  symbols.
- Follow-ups: break duration with a countdown, markers per instrument or role,
  colours.
