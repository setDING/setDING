# Screenshots

Screenshots of the app shown in the repository [README](../../README.md) and on the
website (`website/`). They are rendered by `make screenshots`
(`app/test_screenshots/screenshots_test.dart`) and copied here by
[`tool/copy-screenshots.sh`](../../tool/copy-screenshots.sh), which lists which
rendered file becomes which file here.

- `<name>.png` – English, dark theme (README, English website pages)
- `<name>_de.png` – Swiss Standard German, light theme (German website pages)

After a visible UI change, run `make screenshots` and commit the changed files.
For a new screenshot, add a test that renders it and a line to the list in
`tool/copy-screenshots.sh`. The test gate (`make check`) runs the same tests without
writing files, so a UI change that breaks them fails the check.
