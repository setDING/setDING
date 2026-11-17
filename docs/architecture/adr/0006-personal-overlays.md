# ADR-0006: Personal adjustments as overlays

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Band members need different views of the same song: the guitarist plays with a
capo, the horn player needs a transposed key (e.g. B♭ instrument), the singer wants
lyrics only, the bass player prefers Nashville numbers. There are also personal
notes ("solo here", "come in after 4 bars"). If these changes were made directly in
the shared ChordPro text, conflicts would arise and the text would become unusable
for everyone else.

## Decision

Personal adjustments are stored as an **overlay** and applied at render time.
The shared ChordPro text is **never modified** by them.

Layers (applied in this order):

1. **Song** (ChordPro, shared) – original key
2. **Set item** (shared, set by an admin) – e.g. "tonight −2 semitones", or a
   different song sequence for this set
3. **Personal overlay per song** – transposition/capo, instrument transposition,
   text notes, font size, optionally Nashville display for this song
4. **Personal device settings** – display mode (lyrics + chords, lyrics only),
   chord notation (international/German, ADR-0003), Nashville display, theme
   (light/dark), number of columns, UI language (ADR-0008)

Overlays (layer 3) are synced with the user account so they are available on a new
device (phase 2); layer 4 stays local per device.

Notes are **text notes** anchored to a line or section. **Freehand annotations**
(stylus drawing) are not part of this decision and will be addressed later in a
separate ADR.

Overlays apply to ChordPro songs only. For PDF attachments (ADR-0009) only the font
size/zoom setting is relevant.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Overlay** (chosen) | No conflicts, original stays clean, everyone has their own view | Renderer must combine layers |
| Personal copy of the song | Simple | Changes to the original (corrections) no longer arrive |
| Everything in the shared song | No additional model | Conflicts, unusable for others |

## Consequences

- The renderer receives a `RenderContext` object (total transposition, capo, display mode, notation, Nashville, notes) instead of just the song.
- Notes are anchored to a line/section; if the song changes, a note may become "orphaned" – it is then shown at the end of the song instead of being discarded.
- The overlay model must be extensible so that freehand annotations can be added later without a migration of existing overlays.

## Decision log

- 2026-11-14: Overlay model accepted. Freehand annotations are postponed to a later phase. A dedicated chords-only display mode is not planned.
- 2026-11-14: The key is chosen from a dropdown of the twelve keys (or semitone offsets for songs without a key). In a set – in the set list and in live mode started from a set – the chosen key is stored on the **set item** (layer 2); the song itself is never changed. Outside a set, the dropdown sets the personal transposition (layer 3).
- 2026-11-14: The personal capo distinguishes "as written in the song" (`{capo}`, default) from an explicit fret including "no capo" (ADR-0012).
- 2026-11-15: The song sequence (`{x_sequence}`, ADR-0012) can be overridden per **set item** (layer 2, column `set_items.sequence`, database schema 3, same syntax; null = as in the song). It is edited in the set list and shown in the set list and in live mode started from the set, marked as set-specific; the song itself is never changed. Opening the song on its own shows its original sequence.

- 2026-11-15: Overlays belong to a person and are synced with the account (phase 2): see [ADR-0020](0020-overlays-per-user.md).
- 2026-11-17: **ADR-0025** (accepted): a band arrangement layer between song and set item
  (key as transposition, sequence and tempo per band and song). Set item transposition
  becomes relative to the band's key; personal overlays stay on top.
- 2026-11-17: Band arrangement layer implemented (#221, ADR-0025): set lists, live mode and the songs tab apply song → band arrangement → set item → personal overlay.
- 2026-11-17: The live view (ChordPro text or one of the song's PDF attachments, ADR-0009) can also be chosen in the **set list**, with a dropdown per song that has a choice (#219). Unlike the key and the sequence (set item, band arrangement), it stays a personal adjustment (layer 3, `personal_overlays.live_view`, synced with the account per ADR-0020), not a set item field: it applies to the person and the song in every set. The song screen, the set list and live mode share one fallback rule (`livePdfFor`): a chosen attachment that no longer exists falls back to ChordPro, a song without ChordPro content to its first PDF.
- 2026-11-17: Owner decision (#233): on the song screen the personal adjustments (key, capo, font size, Nashville, notes) and the attachments (with the choice of the live view) are no longer shown above the song but in **side panels** (end drawer) behind their own app bar icons, like the band arrangement (ADR-0025). The personal icon shows a dot while the song is shown differently from how it is written (transposition, capo, font size, Nashville); the attachments icon shows their number. Songs without ChordPro content keep their attachments above the song, as they are its content. "Edit ChordPro" moves into the overflow menu.
- 2026-11-17: Owner decision (#237): in the set list the live view is chosen with a small **icon button** per song instead of the dropdown: a text or PDF icon shows the current choice (named in its tooltip together with the scope) and opens a menu with all choices. It is still shown only when there is a choice. The rows keep only the key and the drag handle next to it; the set sequence and "Remove from set" (and, for pauses and texts, "Edit") move into a ⋮ menu per row. Songs without ChordPro content get no key picker, as transposing a PDF does nothing.
- 2026-11-17: **ADR-0027** (accepted, #328): layer 4 is split into **4a personal settings** (instrument, voice, notation, Nashville, chord style, display mode, chorus repeat, diagrams, set progress, theme, accent colour, language, drummer preferences), which belong to a person and are synced with the account like overlays, and **4b device settings** (font size, columns, auto-fit, page turn, live appearance, server URL, sync mode, click volume, latency compensation), which stay local per device. The statement above that layer 4 stays local per device applies to 4b only.

## Open points

- None.
