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

The projected page of the lyrics projection (ADR-0068) runs in a browser, not
in the app, so the Flutter tests cannot render it. `tool/projection-screenshots.sh`
serves the real page with the real server and shoots it with a headless Chromium
(`projection_page`, `projection_two_languages`, `projection_lower_third`, each
with `_de`); run it when the page asset changes (`CHROMIUM=<path>` picks the
browser).

The screenshots of the store listings (Google Play, App Store) are rendered by
`store_screenshots_test.dart` and composed into `docs/store/` instead
(`make screenshots ONLY="^store "`, see [its README](../store/README.md)).
The same run writes `why_<n>[_de].png` here, the store's tablet screens without
the headline, for the cards of the landing page.
