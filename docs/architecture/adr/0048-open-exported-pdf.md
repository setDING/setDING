# ADR-0048: Opening an exported PDF in the default app

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

After exporting a PDF (today the printable set list, ADR-0013), the user wants to
look at it, print it or share it right away. Until now the app only showed
"Exported", and the user had to find the file in a file manager (#721).

The file is saved with `file_picker`'s save dialog. Where it ends up cannot be
opened reliably:

- On Android the dialog uses the Storage Access Framework; `file_picker` returns
  only the path part of the `content://` URI, not a URI another app can read.
- Passing a file to another app on Android needs a `FileProvider` and a read
  grant on the intent; `url_launcher` does neither. iOS needs a document
  interaction controller.
- On Linux, Windows and macOS the saved path is a real file, but the save dialog
  is not the only place exports will come from.

## Decision

1. The message after a PDF export offers an **Open** (*Öffnen*) action. It stays
   for eight seconds, then disappears on its own.
2. **Open** writes the same bytes to a copy in the app's cache
   (`<temporary directory>/opened/<file name>`) and opens that copy with
   **`open_filex`** (BSD-3-Clause, MIT-compatible) in the system's default app for
   the MIME type: an intent through the plugin's `FileProvider` on Android, a
   document interaction controller on iOS, `xdg-open`, `start` and `open` on the
   desktop. The copy is opened, not the saved file, so it works the same on every
   platform. If no app can open it, a message says so.
3. The media and storage permissions `open_filex` declares on Android
   (`READ_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES/VIDEO/AUDIO`) are removed in the
   app's manifest (`tools:node="remove"`): files in the app's own cache need none,
   and setDING never asks for access to photos, videos or music.
4. The web client has no PDF export (ADR-0018); its implementation opens the bytes
   as a blob URL in a new tab, so the shared code compiles and works if an export
   is added there.
5. Only PDF exports get the action, by the owner's choice; the helper
   (`app/lib/platform/open_file.dart`, `openFileProvider`) is reused by future PDF
   exports.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| `open_filex` with a cache copy (chosen) | Works on every platform; little code; no permissions needed for the cache | One more dependency; declares permissions that must be removed in the manifest |
| Own platform code (Kotlin `FileProvider` + intent, Swift document controller, `url_launcher` on desktop) | No new dependency | More native code to write and maintain on three platforms |
| Open the saved file with `url_launcher` on the desktop only | No new dependency | No action on Android and iOS, the main platforms on stage |
| Share sheet (`share_plus`) | Print and send in one place | Not "open"; no share sheet on Linux |

## Consequences

- One more plugin, kept at its newest version like every dependency.
- The cache copy is overwritten by the next open of the same name and removed
  with the app's cache by the system.
- New exports that produce PDFs show the action by calling the same helper.

## Decision log

- 2026-11-21: Proposed (#721). The owner chose `open_filex` over own native code
  and limited the action to PDF exports.
- 2026-11-21: Accepted by the owner; implemented in #721.
- 2026-11-28: On the web client an SVG attachment is opened as an image on a page without scripts (`lib/platform/svg_viewer_page.dart`), not as an SVG document: a `blob:` URL has the app's origin, and synced SVGs come from other people (#1227, ADR-0009).

## Open points

- Whether other exports (song `.cho`, set archive, backup) should offer **Open**
  too.
