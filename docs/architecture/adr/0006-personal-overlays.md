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

## Open points

- None.
