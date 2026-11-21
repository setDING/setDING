# ADR-0049: Keyboard shortcuts

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

setDING runs on tablets, but also on Linux, Windows and macOS and in the browser
(ADR-0002, ADR-0018), where people use a keyboard. Until now only the ChordPro
editor (Ctrl+S, Ctrl+F, line commands, #361) and live mode (page turning, foot
pedals, ADR-0007) took keys. Moving between screens and the frequent actions of the
song and set views needed the mouse.

Single keys without a modifier (E, L) are the fastest, but must never get in the way
of typing: an "e" in a search field is a letter. Flutter also uses some keys
itself: Esc closes dialogs and menus (`DismissIntent`), the arrow keys move the
focus (`DirectionalFocusIntent`).

## Decision

1. **Esc goes back** on every screen like the app bar's back button (#726): a late
   key event handler (`EscapeGoesBack`) pops the current page route with `maybePop`
   (so `PopScope` still asks) when nothing else handled Esc. Dialogs, menus and
   widgets with their own Esc (editor search, autocomplete, live mode) keep it; a
   dialog that is not dismissible stays open; the start screen does nothing.
2. **Screen shortcuts** (#729) are declared per screen with `PageShortcuts`
   (`app/lib/ui/widgets/app_shortcuts.dart`), a map from key to action. They apply
   only while the screen's route is current (no dialog or menu above it), the
   screen is visible (not a hidden tab) and **no text field has the focus**. The
   widget is a focus node that takes the focus when the screen opens, so it sees
   the keys after the focused widget (a slider keeps its arrows) and before
   Flutter's focus traversal; a late key event handler catches the keys when the
   focus is elsewhere.
3. **The shortcuts:**

   | Key | Where | Action |
   |---|---|---|
   | Esc | everywhere | back |
   | ? | everywhere | dialog listing all shortcuts |
   | E | song, set | edit (only with the permission; the same check as the edit button) |
   | L | song, set | start live mode |
   | + / − (also numpad) | song | personal transposition up/down (overlay, ADR-0006) |
   | ← / → | song opened from a set | previous/next song of the set; breaks and texts are skipped, the song replaces the current one, so back returns to the set |
   | / or Ctrl+F (Cmd+F) | song list | focus the search |

   Live mode keeps its own keys (ADR-0007), the editor its Ctrl shortcuts.
4. **Discoverability:** the **?** dialog lists all shortcuts, grouped by screen, with
   the live mode keys; the website's *First steps* page shows it. Every new shortcut
   is added to that dialog.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| Flutter `Shortcuts`/`Actions` per screen | Idiomatic | Needs the focus inside the screen; a route's disabled `DismissIntent` action hides an outer one, so Esc on pages cannot be handled this way |
| Only late key event handlers | Simple, independent of the focus | The arrow keys never arrive: focus traversal handles them first |
| Shortcuts with a modifier (Ctrl+E) | No conflict with typing | Slower; Ctrl+L, Ctrl+E are taken in browsers |
| A visible shortcut hint on each button | Discoverable | Clutters the tablet UI, where no keyboard is used |

## Consequences

- Desktop and web are faster to use; nothing changes on a tablet without keyboard.
- Each screen declares its keys next to its buttons, with the same permission
  checks; the **?** dialog must be kept in sync by hand.
- Single letters are reserved per screen; a new one needs a look at the dialog to
  avoid conflicts.

## Decision log

- 2026-11-21: Esc goes back (#726, implemented).
- 2026-11-21: Proposed E, L, + / −, ← / →, / and Ctrl+F, and the ? dialog (#729).
- 2026-11-21: Accepted by the owner; implemented in #729.

## Open points

- Further shortcuts (e.g. new song, sync, settings) once they are asked for.
- Show the keys in the tooltips of the buttons on desktop.
