#!/usr/bin/env bash
# Measures the line coverage of the Dart tests (make coverage, issue #640):
# the ChordPro package and the app (unit, widget and screenshot tests, as in
# make check). Writes lcov reports, prints a summary (tool/coverage/summary.py)
# and, if genhtml (lcov) is installed, an HTML report. Report only: there is no
# threshold, and make check does not run it. COVERAGE_MARKDOWN=<file> also
# appends a Markdown summary to <file> (the nightly CI run's page, #1249).
#
# The server's API rules and hooks run inside PocketBase and are not measured
# (docs/development/coverage.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE="$ROOT/packages/chordpro"
APP="$ROOT/app"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

step() { printf '\n==> %s\n' "$*"; }

step "chordpro: tests with coverage"
(cd "$PACKAGE" && dart pub get >/dev/null && dart test --coverage-path=coverage/lcov.info)

step "app: tests with coverage"
(cd "$APP" && flutter pub get >/dev/null && flutter test --coverage test test_screenshots)

step "summary"
python3 "$ROOT/tool/coverage/summary.py" \
  --part chordpro "$PACKAGE/coverage/lcov.info" "$PACKAGE" \
  --part app "$APP/coverage/lcov.info" "$APP" \
  --lowest "${COVERAGE_LOWEST:-15}" \
  ${COVERAGE_MARKDOWN:+--markdown "$COVERAGE_MARKDOWN"}

echo
echo "lcov reports: $PACKAGE/coverage/lcov.info, $APP/coverage/lcov.info"
if command -v genhtml >/dev/null 2>&1; then
  for dir in "$PACKAGE" "$APP"; do
    genhtml --quiet --ignore-errors unused,inconsistent \
      --exclude '*.g.dart' --exclude '*/l10n/generated/*' \
      --output-directory "$dir/coverage/html" "$dir/coverage/lcov.info"
    echo "HTML report: $dir/coverage/html/index.html"
  done
else
  echo "HTML report: install lcov (genhtml) to get one."
fi
