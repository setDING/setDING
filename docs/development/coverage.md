# Test coverage

`make check` says whether the tests pass, not what they leave out. `make coverage`
measures the line coverage of the Dart tests so gaps become visible (issue #640).
The measurement itself is a **report only**, without a threshold for the whole.
The critical areas have a **coverage ratchet** (`make coverage-ratchet`, below,
#1247). `make check` runs neither, because measuring coverage slows the tests
down; the nightly CI run does.

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

## Coverage ratchet of the critical areas

```bash
make coverage-ratchet             # make coverage, then the ratchet
python3 tool/coverage/ratchet.py  # only the ratchet, on the last make coverage
```

[`tool/coverage/ratchet.json`](../../tool/coverage/ratchet.json) holds the
minimum line coverage of the areas where an untested change hurts most:

| Area | Files |
|---|---|
| `sync` | `app/lib/sync/` |
| `permissions` | `app/lib/data/band_view.dart` (the client's permission checks) |
| `import/backup` | `app/lib/data/backup.dart`, `zip_reader.dart`, `import_export.dart` (ChordPro and ZIP import) |
| `chordpro` | `packages/chordpro/lib/` |

[`tool/coverage/ratchet.py`](../../tool/coverage/ratchet.py) reads the lcov
reports of `make coverage` and

- **fails** when an area is more than 0.1 points (`tolerance`, for rounding)
  below its minimum,
- **fails** when a library file of an area is not loaded by any test (it is
  missing from the lcov report, so it would not lower the percentage), or when
  an area has no measured lines (a path in `ratchet.json` is wrong),
- **asks to raise the minimum** when an area is more than 1 point
  (`raise_hint`) above it, and prints the value to write; it does not fail for
  that.

Rules for the minimums:

- **Raise** a minimum in the PR whose tests raised the area (or in any later
  PR): the ratchet only moves up.
- **Lowering a minimum is an owner decision.** Never lower it to make the check
  pass; add tests instead. If code moved out of an area or a large untested
  part is deliberate, ask the owner and name the decision in the commit.
- A new critical area or a moved file changes `ratchet.json`;
  `test_ratchet.py` (the `tools` job of `make check`) checks that every path in
  it exists.

The minimums were set from the measurement of 2026-11-28 (#1247): sync 90.6 %,
permissions 71.2 %, import/backup 97.5 %, chordpro 92.8 % (the suggested value is
rounded down to one decimal). A drop on
`main` fails the nightly run, which opens the nightly issue (git workflow,
section 7).

## Nightly on GitHub

The nightly CI run (`.github/workflows/nightly.yml`, #1249) runs `make coverage`
on `main` with `COVERAGE_MARKDOWN` set: `summary.py --markdown` appends the
coverage of each part, its areas (the folders below `lib/`), the least covered
files and the files no test loads to the run's page. Then the coverage ratchet
runs (`ratchet.py --markdown`) and appends its table; an area below its minimum
fails the run. The lcov files and the HTML reports are in the run's artifact
`nightly-reports`.

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
