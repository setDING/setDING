# Screenshots

Screenshots of the app shown in the repository [README](../../README.md) and on the
website (`website/`). They are rendered by `make screenshots`
(the tests in `app/test_screenshots/`, one file per area so they run in parallel;
shared setup in `screenshot_support.dart`) and copied here by
[`tool/copy-screenshots.sh`](../../tool/copy-screenshots.sh), which lists which
rendered file becomes which file here.

- `<name>.png` – English, dark theme (README, English website pages)
- `<name>_de.png` – Swiss Standard German, light theme (German website pages)

**In a PR, render only the screenshots the change adds or changes**, by the name
of their test (a regular expression; most tests run once per language):

```bash
make screenshots ONLY="set archive"
make screenshots ONLY="lilypond|sync hint"
```

It renders only the matching tests and copies only their images, so a PR does not
carry unrelated image changes that conflict with other PRs. For a new screenshot,
add a test that renders it and a line to the list in `tool/copy-screenshots.sh`.

Other screenshots that a change affects only in passing (a renamed button, a new
icon in the app bar) are brought up to date by the **release PR**: it runs
`make screenshots` without `ONLY`, which renders all of them, and commits whatever
changed since the last release ([releases.md](../development/releases.md)).

The test gate (`make check`) runs the same tests without writing files: the screens
are built, driven, laid out and painted, but not rasterised and PNG-encoded, so a UI
change that breaks them fails the check at a fraction of the cost.

The phone and tablet screenshots of the Google Play listing are rendered by
`play_store_screenshots_test.dart` and composed into `docs/store/play/` instead
(`make screenshots ONLY="^play "`, see [its README](../store/play/README.md)).
