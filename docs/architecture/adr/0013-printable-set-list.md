# ADR-0013: Printable set list as PDF

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Bands tape a printed set list to the stage floor or to their amps. setDING can
already export the set list as text (clipboard or `.txt`): a header with set name,
date and venue, then one line per song with title, key for this set (set
transposition, ADR-0006) and sequence (`{x_sequence}`, set-specific or from the song,
ADR-0012). Text is fine for chat messages, but it cannot be printed with a large,
stage-readable layout.

Constraints:

- Offline-first (ADR-0001): the PDF must be created on the device, without a server.
- Flutter client on Android, iOS and Windows (ADR-0002); Linux is used for testing.
- The app already uses `pdfrx` (with PDFium) to display PDF attachments (ADR-0009).
- Characters beyond Latin-1 must print correctly: German umlauts, en dash, ♭ and ♯ in
  keys and sequences, song titles in other languages.
- Open-source licences compatible with the project; no commercial licences.

## Decision

1. **PDF generation in the client with the `pdf` package** (pub.dev, Apache-2.0,
   verified publisher nfet.net, pure Dart PDF producer, all target platforms). No print
   plugin for now.
2. **Embedded font:** a TrueType font is shipped as an app asset and embedded in the
   PDF (candidate: Noto Sans regular and bold, SIL Open Font License), because the
   standard PDF fonts only cover Latin-1/WinAnsi.
3. **Content:** the same data as the text export, using the same code path for key and
   sequence:
   - Header: set name, date · venue.
   - One row per song: number, title (bold), key for this set, sequence. Long sequences
     wrap inside their column.
   - Pauses and text items appear as separator rows.
   - Footer: page number when there is more than one page.
4. **Layout:**
   - A4 portrait, black on white, large type for the stage: titles about 18 pt.
   - The font shrinks, down to a minimum of about 12 pt, so that a typical set fits
     on one page.
   - Longer sets continue on further pages.
5. **Output:** "Export set list (PDF)" in the set menu saves the file with the existing
   save dialog (`file_picker`). Printing and sharing then happen with the platform's
   PDF viewer; the file is a normal PDF.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **`pdf` package only** (chosen) | Pure Dart, offline, all platforms, small; vector text (sharp, small files); unit-testable output | No native print dialog; fonts must be embedded |
| `printing` package (on top of `pdf`) | Native print dialog, share sheet, `PdfPreview` widget | Native setup per platform (iOS `use_frameworks!`, macOS entitlement); bundles PDFium on Windows/Linux next to the PDFium of `pdfrx` (risk of duplicate/conflicting native libraries) |
| Render a Flutter widget to an image and wrap it in a PDF | Reuses the app's widgets and fonts | Raster output: blurry when printed, large files, page breaks by hand |
| HTML page printed via a browser | Familiar layout tools | Needs a browser/web view, not offline-friendly on tablets, no control over the result |
| Commercial PDF libraries (e.g. Syncfusion) | Rich features | Commercial licence, vendor lock-in |

## Consequences

- One new dependency (`pdf`) and font assets of roughly 1 MB in the app.
- The PDF layout is code (no templates). It can be tested by generating the document
  and checking its text, and by screenshots of the rendered pages via `pdfrx`.
- Printing needs one extra step: open the saved PDF and print it from the platform
  viewer. A native print dialog can be added later with `printing`, if the PDFium
  question is solved.
- The same generator can later be reused for other printouts, e.g. song sheets
  (chords and lyrics) as PDF.

## Decision log

- 2026-11-15: Proposed after the text export of the set list was implemented.
- 2026-11-15: Accepted by the user. Font: Noto Sans regular and bold (SIL OFL 1.1),
  shipped under `app/assets/fonts/` with its licence. Paper size A4 for now; no export
  options yet.
- 2026-11-15: Implemented: "Export set list (PDF for printing)" in the set menu. The
  font size is found by laying out the document from 18 pt down to 12 pt until it fits
  on one page; text and PDF export share one set list model.
- 2026-11-17: The key and sequence for the set include the band arrangement (ADR-0025): song key + band transposition + set transposition; sequence from the set item, the band or the song.

## Open points

- Paper size: always A4, or Letter for an English locale (`en-US`)?
- Options in the export: font size (normal/large), with or without sequence and key,
  one page forced?
- Native print dialog via `printing`: check whether it can share the PDFium of
  `pdfrx` on Windows/Linux.
- Font choice: Noto Sans (wide coverage) or the app's UI font for a consistent look.
