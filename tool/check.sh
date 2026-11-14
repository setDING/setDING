#!/usr/bin/env bash
# Runs all local checks: format, static analysis and tests.
# Used by agents before every PR and merge (docs/development/git-workflow.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

step() { printf '\n==> %s\n' "$*"; }

step "packages/chordpro"
cd "$ROOT/packages/chordpro"
dart pub get >/dev/null
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test

if [ -d "$ROOT/app" ]; then
  step "app"
  cd "$ROOT/app"
  flutter pub get >/dev/null
  python3 - <<'PY'
import json, sys
keys = lambda f: {k for k in json.load(open(f)) if not k.startswith('@')}
de, en = keys('lib/l10n/app_de.arb'), keys('lib/l10n/app_en.arb')
if de != en:
    print('l10n: keys differ between app_de.arb and app_en.arb:', sorted(de ^ en))
    sys.exit(1)
if 'ß' in open('lib/l10n/app_de.arb', encoding='utf-8').read():
    print('l10n: app_de.arb must use Swiss spelling (no ß)')
    sys.exit(1)
print('l10n: OK (%d keys)' % len(de))
PY
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze --fatal-infos
  flutter test
fi

step "All checks passed"
