# Test coverage

`make check` says whether the tests pass, not what they leave out. `make coverage`
measures the line coverage of the Dart tests so gaps become visible (issue #640).
It is a **report only**: there is no threshold, and `make check` does not run it,
because measuring coverage slows the tests down.

## Running the measurement

```bash
make coverage                     # 15 least covered files per part
make coverage COVERAGE_LOWEST=40  # longer list
```

[`tool/coverage/coverage.sh`](../../tool/coverage/coverage.sh) runs

- the tests of the ChordPro package (`dart test --coverage-path`), and
- the app's unit, widget and screenshot tests, the same set as `make check`
  (`flutter test --coverage test test_screenshots`),

writes the lcov reports to `packages/chordpro/coverage/lcov.info` and
`app/coverage/lcov.info` (ignored by git), and prints a summary
([`tool/coverage/summary.py`](../../tool/coverage/summary.py)):

- the line coverage of each part,
- the least covered files,
- the library files **no test loads at all**. lcov only lists files a test
  imported, so these files are missing from the reported total; the summary
  lists them separately. Files of only directives and simple enums (e.g. a
  library of exports) have no code to cover and are not listed.

Generated code (`*.g.dart`, the l10n output in `app/lib/l10n/generated/`) is left out.
If `genhtml` (package `lcov`) is installed, an HTML report is written to
`coverage/html/index.html` of each part.

## Nightly on GitHub

The nightly CI run (`.github/workflows/nightly.yml`, #1249) runs `make coverage`
on `main` with `COVERAGE_MARKDOWN` set: `summary.py --markdown` appends the
coverage of each part, its areas (the folders below `lib/`), the least covered
files and the files no test loads to the run's page. The lcov files and the HTML
reports are in the run's artifact `nightly-reports`.

## Reading the numbers

- Line coverage shows which code ran during a test, not whether a test checked
  its result. A covered file can still be poorly tested; an uncovered one is
  certainly not tested.
- Use the report to find gaps when working on an area, not as a goal in itself.
  New or changed behaviour comes with tests anyway (git workflow).

## Not measured

- **Server:** the API rules and hooks in `server/` run inside PocketBase
  (JavaScript); the Dart tests in `server/test/` call them over HTTP, so Dart
  coverage says nothing about them. They are covered by the permission matrix
  test and the per-collection tests (AGENTS.md, "Permissions on the server").
- **Platform code** that only runs on devices (MIDI, audio, secure storage,
  file system): the tests replace it with fakes. `make perf` runs the app on a
  real Android device ([performance.md](performance.md)).
- **Shell scripts** of `tool/` and the website code.
