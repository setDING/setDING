# ADR-0032: Personal freehand annotations on songs

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

Musicians mark up their sheets by hand: a circle around a tricky chord, an
arrow back to the chorus, "watch the drummer" with a pair of glasses, a
breath mark, a highlighted line. ADR-0006 keeps freehand annotations out of
the overlay decision and asks for a separate ADR; the overlay model "must be
extensible so that freehand annotations can be added later". The roadmap lists
"freehand annotations (stylus)" under *Later*.

Requirements from the owner (2026-11-18):

- Every person can draw **their own** freehand notes on a song.
- The notes are **synced** with the account (like overlays, ADR-0020).
- Notes can be **edited and deleted** afterwards.

Forces specific to setDING:

- **There is no fixed page.** A ChordPro song is laid out on every device
  anew: font size (device setting and personal `font_scale`), number of
  columns, auto-fit in live mode, screen size and orientation, personal
  transposition and capo (chord widths), lyrics-only mode, band arrangement
  and set sequence (repeated or skipped parts). A stroke stored in screen
  coordinates would land in the wrong place on the next device, or on the same
  device after rotating it.
- **PDF attachments** (ADR-0009) do have fixed pages; annotating them is the
  same need.
- **Live mode** (ADR-0007) uses taps and swipes for page turns; drawing must
  not steal them, and nothing may slow down a page turn.
- **Offline-first** (ADR-0001): two devices of the same person may both add
  annotations offline; both must survive the sync.
- The renderer already knows the source line of every element
  (`sourceLineOf`, used for taps into the editor), and layout sizes are
  computed per unit of font size (`song_layout.dart`).

## Decision

### 1. Personal, a new overlay part, never in the ChordPro text

Freehand annotations are part of layer 3 (personal overlay, ADR-0006): private
to their owner (`owner_id` as in ADR-0020, `local` for the local library),
never written into the ChordPro text, never visible to others. They apply to
the song everywhere it is shown (song screen, sets, live mode), like the other
personal adjustments.

They are stored **separately from the overlay row**, because an overlay is
synced as a whole with last writer wins and a song can carry hundreds of
strokes.

### 2. Anchoring: page coordinates, with a line anchor as fallback

Annotations are often **not about a line** but about the free space of a
page: an arrow from the verse to the chorus in the next column, a bracket
around two parts, a note in the margin. On stage a person almost always uses
the **same device** in the same orientation, so the layout they drew on is
the layout they play from. Therefore (owner decision 2026-11-18):

**ChordPro songs** – annotations are drawn on the pages of **live mode**
(ADR-0007), the view used on stage. Each stroke stores:

- **page coordinates**: the page (spread) index within the song and the
  points normalized to the page's content area (0…1 of width and height);
- the **layout fingerprint** of that page: viewport size (rounded), orientation,
  effective font size, number of columns, lyrics-only, the song's content hash
  and the shown sequence (song, band arrangement or set item, ADR-0025);
- a **line anchor** as fallback: the rendered line nearest to the stroke's
  start (source line number, fingerprint of its text without chords, repeat
  index) and the start point's offset from that line's baseline in units of
  the font size.

Rendering:

- **Same layout** (fingerprint equal): the stroke is drawn exactly where it
  was drawn, in page coordinates – free arrows and margin notes included.
  A viewport that differs only slightly (e.g. a system bar) still counts as
  the same layout, as the points are normalized.
- **Different layout** (another device, rotated, other font size, edited
  song, other sequence): the stroke is placed relative to its **anchor line**
  (moved with it, scaled with the font size, shape kept). Text marks stay on
  their text; free arrows stay near where they started but may no longer
  point exactly at their target. A small hint in the toolbar says that
  annotations were drawn for another view (e.g. "landscape").
- **Anchor line not found** (the song text changed so much that neither the
  line nor its fingerprint is found): the stroke is **orphaned**; it is not
  drawn, the annotation toolbar shows the count and offers to show orphaned
  strokes on the last page (to move them) or delete them, following ADR-0006
  for orphaned text notes.

Annotations apply per song (owner decision 2026-11-18): the same strokes in
every set. A set with a different sequence lays the song out differently and
therefore uses the line-anchor fallback.

The scrolling **song screen** shows annotations read-only, placed by their
line anchor (it has no pages); drawing happens in live mode only.

**PDF attachments** – drawn in the PDF view of live mode; each stroke is
anchored to the attachment ID and the **page number**, with coordinates
normalized to the page (0…1). PDF pages never reflow, so these strokes never
move, on any device. Replacing an attachment file keeps its annotations only
if the page count is the same; otherwise they are orphaned like above.
Deleting an attachment deletes its annotations.

### 3. Data model

Local table `annotations` (schema 16):

| Column | Meaning |
|---|---|
| `id` | UUID of the stroke, generated by the client |
| `owner_id` | Owner, as in `personal_overlays` (ADR-0020) |
| `song_id` | Song |
| `attachment_id` | null = ChordPro text, otherwise the PDF attachment |
| `anchor` | JSON: for ChordPro `{page, layout, line, hash, repeat, dx, dy}` (page index, layout fingerprint, line anchor and offset); for PDF `{page}` |
| `tool` | `pen`, `highlighter`, `stamp` |
| `color` | ARGB integer from a small fixed palette |
| `width` | Stroke width as a share of the page width |
| `points` | Points normalized to the page, as a compact base64 list of quantized `(x, y, pressure)` triples (16 bit each), simplified (Ramer–Douglas–Peucker) when the stroke ends; for a stamp its symbol, position and size |
| `updated_at`, `revision`, `deleted` | Sync, as for other personal records |

A stroke is the unit of editing: moving or recolouring changes its row;
erasing part of a stroke deletes it and creates the remaining pieces as new
strokes. There are no partial updates of `points`.

### 4. Sync: one server record per person, song and target, merged per stroke

Server collection `annotations` (new migration, ADR-0015):
`user`, `song`, `attachment` (optional relation), `data` (JSON map
stroke ID → stroke, or a tombstone `{deleted: true}` for an erased stroke),
`revision`, `updated_by`, `deleted`. The record ID is a UUID v5 of user, song
and target, so a person's devices never create two records (as for overlays,
ADR-0020). Access rules as for `overlays`: only the user, only for songs of
their organizations.

A push sends only the strokes changed since the last sync; a server hook
**merges them per stroke ID** into the stored map (last writer wins per
stroke), the same pattern as `user_settings` (ADR-0027). Two devices that
annotated the same song offline therefore keep all strokes; an erase on one
device and a move of the same stroke on another resolve by the later push.
Tombstones older than 90 days are pruned by the hook on the next write.

One record per song and target (instead of one per stroke) keeps the number
of requests and records small: a song with 200 strokes is one request, which
matters for the server's rate limits (ADR-0004). The `data` field is limited
to 1 MB per record; the client refuses new strokes beyond that and says so.

Pull uses the delta cursor per user, like overlays; the outbox and the
live-mode pause of the sync apply unchanged (annotations from another device
appear after leaving live mode). Deleting a song soft-deletes its annotation
records, and restoring the song restores them (as for overlays, #267). Local
annotations (`local` owner) are never synced. "Copy to band" (ADR-0017)
copies the current owner's annotations with the song.

### 5. User interface

- **Drawing mode** in live mode only (ChordPro pages and PDF pages), switched
  on through the live menu (pen icon). Putting the stylus on the screen does
  **not** start drawing on its own, so nothing is drawn by accident on stage
  (owner decision 2026-11-18). A toolbar shows pen, highlighter, eraser,
  lasso, stamps, colour, width, undo/redo and "done". While drawing, page
  turns by pedal and keyboard keep working; taps and swipes draw instead of
  turning.
- **Stylus first**: in drawing mode with a stylus, only the stylus draws and
  fingers keep turning pages (palm rejection by pointer kind). A setting
  "draw with finger" exists for devices without a stylus; the web client
  draws with the mouse.
- **Tools**: pen (pressure-sensitive width with a stylus), highlighter
  (translucent, drawn behind the text), **stroke eraser** (removes the whole
  stroke it touches) and **partial eraser** (splits strokes), **lasso** to
  select strokes and move, resize, recolour or delete them.
- **Stamps** placed with a tap, then movable and resizable like strokes:
  - *music marks*: fermata, breath mark, crescendo, decrescendo,
    ritardando, accent;
  - *repeats*: ×2, ×3, ×4, repeat brackets, coda, segno;
  - *cues*: glasses ("watch"), stop hand, eye, exclamation mark, star.
  Stamps are vector symbols bundled with the app (MIT-compatible font or own
  paths), so they scale and follow the stage appearance.
- **Editing and deleting**: every change can be undone in the drawing session
  (undo/redo); "Delete all annotations of this song" in the personal side
  panel and in the live toolbar, with the usual "Undo" message (#267).
- **Visibility**: the personal side panel (ADR-0006, #233) gets a switch
  "show annotations" per song; a personal setting (ADR-0027) hides them
  everywhere; live mode has a quick toggle. The personal icon's dot also
  covers annotations.
- **Rendering**: annotations are painted in a `CustomPainter` layer above the
  page (highlighter: below the text). For the fallback the layout exposes the
  positions of rendered lines (source line, repeat index, baseline). Paths are
  built once per page and cached with the render cache; live preparation
  (ADR-0007) prepares them for the next song, so a page turn paints prepared
  paths only.
- Colours come from a palette that stays readable on the light theme and on
  the black stage appearance (ADR-0007); a stroke stores the palette index,
  so it is mapped to a matching shade per appearance.

### 6. Versioning

The new collection is ignored by older clients, so this is a **minor**
release (ADR-0028); no minimum client version change (ADR-0029).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Page coordinates with a line anchor as fallback** (chosen) | Exact on the stage device, free arrows and margin notes possible; still usable on another layout | Two placements to implement; free arrows can point beside their target on another layout |
| Page coordinates only | Simplest, exactly what was drawn | Wrong or hidden on any other device, orientation, font size or after an edit |
| Strokes anchored to source lines only | Survives every layout change | No free-space annotations (arrows between parts, margin notes); small shifts on the stage device too |
| Freeze the layout while annotated (fixed page) | Exact | Breaks auto-fit, personal font size and transposition, which are core features |
| Anchor to sections (blocks) instead of lines | Fewer anchors | Large drift inside long sections when lines wrap differently |
| Annotations as ChordPro text (`{x_annotation}`) | Exported with the song | Shared text, against ADR-0006; not personal; binary-ish data in the source |
| Inside the `overlays` record | No new collection | Last writer wins for the whole overlay loses strokes from a second device; large records synced on every key change |
| One server record per stroke | Natural last writer wins per stroke | Hundreds of records and requests per song, rate limits (ADR-0004), slow first sync |
| Raster image per page | Simple to draw | Not editable per stroke, large, tied to one layout |

## Consequences

- New local table (schema 16), server migration and merge hook, sync part in
  `app/lib/sync/engine/annotation_sync.dart`, server tests against PocketBase.
- The live pages expose their layout fingerprint and the positions of their
  rendered lines (source line, repeat index, baseline) to an annotation
  layer; the live page view, the PDF views and the song screen get an optional
  overlay painter. Live preparation includes the annotation paths of the next
  song.
- A gesture layer distinguishes drawing from page-turn gestures by pointer
  kind and drawing mode; the live-mode tests cover that pedal and keyboard
  turns keep working while drawing.
- The domain model gets `ANNOTATION` (per user, song and optionally attachment).
- Text notes anchored to a line (ADR-0006, still a single note in the MVP) can
  later reuse the line anchor (`{line, hash, repeat}`).
- The data model leaves room for a band layer (an owner kind besides a user),
  so band annotations can follow without a migration of personal ones.
- Possible follow-ups (separate decisions): **band annotations** visible to
  the whole band (set by band leaders, a band layer like ADR-0025; own ADR,
  owner decision 2026-11-18);
  annotations in the exported set ZIP and in a printed song; sharing one's
  annotations with a band colleague as a copy.

## Decision log

- 2026-11-18: Proposed.

## Open points

- Scope: per song (proposed) or optionally per set item, so that a mark for
  one gig does not appear in other sets?
- Band annotations (shared layer for the whole band) now or as a follow-up?
- Stamps: which symbols in the first version?
- Stylus: should pressing the stylus enter drawing mode automatically in live
  mode, or only via the menu (risk of accidental strokes on stage)?
- Limit per song (1 MB of stroke data) – sufficient?
## Decision log

- 2026-11-18: Proposed.
- 2026-11-18: Owner review of the first draft:
  - Annotations are often on free space (arrows between parts), and on stage
    the same device is used: strokes are stored in **page coordinates** with
    the layout fingerprint; on a different layout they fall back to their
    nearest **line anchor** (hybrid), instead of anchoring to lines only.
  - Scope **per song**, not per set item.
  - **Band annotations** later, in their own ADR; the data model leaves room
    for them.
  - Drawing mode in live mode only **via the menu**, the stylus does not
    start it on its own.
  - Drawing in **live mode and PDF view**; the song screen shows annotations
    read-only (line anchor).
  - Stamps in the first version: music marks, repeats and cues.
- 2026-11-18: Numbered 0032, as ADR-0031 is taken by the self-hosting proposal (#420).
- 2026-11-18: Accepted by the owner (#429); implementation in #428.

## Open points

- Size limit of 1 MB of stroke data per song and target: confirm after a
  test with real annotations.
