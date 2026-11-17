# Screenshots

Screenshots of the app shown in the repository [README](../../README.md) and on the
website (`website/`). They are
rendered by `make screenshots` (`app/test_screenshots/screenshots_test.dart`, English,
dark theme) and copied from `app/build/screenshots/`:

| File | Source |
|---|---|
| `live.png` | `en_7_diagrams.png` |
| `set.png` | `en_2_set.png` |
| `song.png` | `en_3_song.png` |
| `sequence.png` | `en_10_set_sequence.png` |
| `editor.png` | `en_9_editor.png` |
| `drums.png` | `en_11_live_drums.png` |
| `drums_de.png` | `de_11_live_drums.png` (German, light theme) |

After a visible UI change, run `make screenshots` and copy the files again.
The test gate (`make check`) runs the same tests without writing files, so a UI
change that breaks them fails the check.
