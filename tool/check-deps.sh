#!/usr/bin/env bash
# Fails if an external Dart/Flutter or npm library is not the newest version
# (owner rule, see docs/development/dependencies.md):
# - direct dependencies and dev_dependencies must be the latest release,
#   unless the pubspec marks the line as a deliberate pin with a
#   "# Pinned ..." comment directly above it (e.g. pocketbase, ADR-0004);
# - transitive dependencies must be the newest version the other packages
#   allow (`pub upgrade` gets them there).
# - npm packages of the website (website/package.json, ADR-0030) must be the
#   latest release; `make upgrade` runs `npm update`.
# - the CycloneDX Gradle plugin of the SBOM (tool/sbom/gradle, ADR-0037) must be
#   the latest release on the Gradle plugin portal (raised by hand).
# - the distroless base image of the server image (tool/server-dist/Dockerfile,
#   ADR-0063) must be pinned to the current digest of its tag, and no newer
#   Debian series of it may exist (raised by hand).
# - the check tools pinned in tool/fetch-tool.sh (ShellCheck, Caddy,
#   geckodriver) must be the latest GitHub release (raised by hand, with the
#   ShellCheck and geckodriver sums).
# Needs the pub.dev and npm registries; without network the check is skipped
# with a warning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

status=0
for dir in packages/chordpro server tool/sbom app; do
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
if [ -f "$ROOT/website/package.json" ]; then
  cd "$ROOT/website"
  # npm outdated compares the installed packages; a fresh checkout has none yet.
  [ -d node_modules ] || npm ci --no-audit --no-fund --loglevel=error >/dev/null 2>&1 || true
  # npm outdated exits 1 when it finds something; empty output means up to date.
  json="$(npm outdated --json 2>/dev/null || true)"
  if [ -z "$json" ] && ! npm ping >/dev/null 2>&1; then
    echo "deps: website: could not query npm (offline?), skipped" >&2
  else
    python3 - "$json" <<'PY' || status=1
import json, sys
data = json.loads(sys.argv[1] or '{}')
problems = [f"{name} {p.get('current', 'missing')} -> {p['latest']}"
            for name, p in sorted(data.items()) if p.get('current') != p.get('latest')]
if problems:
    print('deps: website: outdated (make upgrade; a new major version needs the range in package.json raised):',
          *problems, sep='\n  ')
    sys.exit(1)
print('deps: website: OK')
PY
  fi
fi

# CycloneDX Gradle plugin of the SBOM (ADR-0037).
init="$ROOT/tool/sbom/gradle/cyclonedx.init.gradle"
current="$(sed -n "s/.*org.cyclonedx.bom.gradle.plugin:\([^']*\)'.*/\1/p" "$init")"
metadata=https://plugins.gradle.org/m2/org/cyclonedx/bom/org.cyclonedx.bom.gradle.plugin/maven-metadata.xml
if ! latest="$(curl -fsS "$metadata" 2>/dev/null | sed -n 's:.*<release>\(.*\)</release>.*:\1:p')" || [ -z "$latest" ]; then
  echo "deps: tool/sbom/gradle: could not query the Gradle plugin portal (offline?), skipped" >&2
elif [ "$current" != "$latest" ]; then
  echo "deps: tool/sbom/gradle: outdated:"
  echo "  org.cyclonedx.bom $current -> $latest (raise it in $init)"
  status=1
else
  echo "deps: tool/sbom/gradle: OK"
fi

# Base image of the server image (ADR-0063): the pinned digest must be the
# tag's current one, and there must be no newer Debian series.
dockerfile="$ROOT/tool/server-dist/Dockerfile"
if [ -f "$dockerfile" ]; then
  ref="$(sed -n 's/^FROM gcr\.io\/\([^ ]*\).*/\1/p' "$dockerfile")"
  repo="${ref%%:*}"            # distroless/static-debian13
  tag="${ref#*:}" tag="${tag%%@*}"
  pinned="${ref##*@}"
  # Current digest of a tag (empty if it does not exist).
  digest() {
    local token
    token="$(curl -fsS "https://gcr.io/v2/token?scope=repository:$1:pull" 2>/dev/null |
      sed -n 's/.*"token": *"\([^"]*\)".*/\1/p')" || return 1
    [ -n "$token" ] || return 1
    curl -fsSI -H "Authorization: Bearer $token" \
      -H 'Accept: application/vnd.oci.image.index.v1+json' \
      -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
      "https://gcr.io/v2/$1/manifests/$2" 2>/dev/null |
      tr -d '\r' | sed -n 's/^docker-content-digest: *//Ip'
  }
  series="${repo##*-debian}"
  next="${repo%-debian*}-debian$((series + 1))"
  if ! current="$(digest "$repo" "$tag")" || [ -z "$current" ]; then
    echo "deps: tool/server-dist/Dockerfile: could not query gcr.io (offline?), skipped" >&2
  elif [ "$current" != "$pinned" ]; then
    echo "deps: tool/server-dist/Dockerfile: outdated:"
    echo "  $repo:$tag $pinned -> $current (raise the digest in $dockerfile)"
    status=1
  elif [ -n "$(digest "$next" "$tag" || true)" ]; then
    echo "deps: tool/server-dist/Dockerfile: outdated:"
    echo "  $repo -> $next (a newer Debian series; raise it in $dockerfile)"
    status=1
  else
    echo "deps: tool/server-dist/Dockerfile: $repo:$tag OK"
  fi
fi

# Check tools of the test gate (tool/fetch-tool.sh, issue #644).
fetch="$ROOT/tool/fetch-tool.sh"
for entry in SHELLCHECK_VERSION:koalaman/shellcheck CADDY_VERSION:caddyserver/caddy GECKODRIVER_VERSION:mozilla/geckodriver; do
  var="${entry%%:*}" repo="${entry#*:}"
  current="$(sed -n "s/^$var=//p" "$fetch")"
  if ! latest="$(curl -fsS "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null |
    sed -n 's/^ *"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p')" || [ -z "$latest" ]; then
    echo "deps: tool/fetch-tool.sh: could not query GitHub for $repo (offline or rate limit?), skipped" >&2
  elif [ "$current" != "$latest" ]; then
    echo "deps: tool/fetch-tool.sh: outdated:"
    echo "  $repo $current -> $latest (raise $var in $fetch)"
    status=1
  else
    echo "deps: tool/fetch-tool.sh: ${repo#*/} $current OK"
  fi
done

exit $status
