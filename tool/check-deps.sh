#!/usr/bin/env bash
# Fails if an external Dart/Flutter library is not the newest version
# (owner rule, see docs/development/dependencies.md):
# - direct dependencies and dev_dependencies must be the latest release,
#   unless the pubspec marks the line as a deliberate pin with a
#   "# Pinned ..." comment directly above it (e.g. pocketbase, ADR-0004);
# - transitive dependencies must be the newest version the other packages
#   allow (`pub upgrade` gets them there).
# Needs the pub.dev API; without network the check is skipped with a warning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

status=0
for dir in packages/chordpro server app; do
  cd "$ROOT/$dir"
  if [ "$dir" = app ]; then pub=(flutter pub); else pub=(dart pub); fi
  if ! json="$("${pub[@]}" outdated --json 2>/dev/null)"; then
    echo "deps: $dir: could not query pub.dev (offline?), skipped" >&2
    continue
  fi
  python3 - "$dir" "$json" <<'PY' || status=1
import json, re, sys
dir, data = sys.argv[1], json.loads(sys.argv[2])
lines = open('pubspec.yaml', encoding='utf-8').read().splitlines()
pinned = {
    m.group(1)
    for prev, line in zip(lines, lines[1:])
    if 'Pinned' in prev and (m := re.match(r'\s+([a-z0-9_]+):', line))
}
version = lambda p, k: (p.get(k) or {}).get('version')
problems = []
for p in data['packages']:
    name, kind = p['package'], p['kind']
    current, resolvable, latest = (version(p, k) for k in ('current', 'resolvable', 'latest'))
    if current is None:
        continue
    if kind in ('direct', 'dev'):
        if name not in pinned and current != latest:
            problems.append(f'{name} {current} -> {latest} ({kind}; raise the constraint in pubspec.yaml)')
    elif current != resolvable:
        problems.append(f'{name} {current} -> {resolvable} (transitive; run pub upgrade)')
if problems:
    print(f'deps: {dir}: outdated:', *problems, sep='\n  ')
    sys.exit(1)
print(f'deps: {dir}: OK' + (f' (pinned: {", ".join(sorted(pinned))})' if pinned else ''))
PY
done
exit $status
