#!/usr/bin/env bash
# Static checks of the operations files (issue #644, part of make check;
# docs/development/operations-tests.md):
# - ShellCheck on every shell script of the repository (*.sh and files with a
#   sh/bash shebang, not documentation that shows one);
# - tool/site/Caddyfile: `caddy validate` and `caddy fmt` (formatted as Caddy
#   writes it);
# - the Caddyfile and systemd unit of the self-hosting docs (doc-example.py);
# - the systemd unit of the docs' example (also the owner's servers) with `systemd-analyze verify`, if the
#   machine has it (unknown keys, bad values; the installed binaries the units
#   start are missing on a development machine and are ignored).
# ShellCheck and Caddy are pinned and fetched by tool/fetch-tool.sh. Their
# behaviour (backup restore, the website server) is tested in server/test/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
status=0

# --- Shell scripts ----------------------------------------------------------
shellcheck="$("$ROOT/tool/fetch-tool.sh" shellcheck)"
mapfile -t scripts < <(
  {
    git ls-files '*.sh'
    git grep -lI -E '^#!(/usr/bin/env (ba)?sh|/bin/(ba)?sh)' -- ':!*.sh' ':!*.md' ':!*.mdx' || true
  } | sort -u
)
if "$shellcheck" --external-sources "${scripts[@]}"; then
  echo "ops: shellcheck: OK (${#scripts[@]} scripts)"
else
  echo "ops: shellcheck: failed (see above; disable a check only with a reason: # shellcheck disable=SCxxxx)"
  status=1
fi

# --- Caddyfile --------------------------------------------------------------
caddy="$("$ROOT/tool/fetch-tool.sh" caddy)"
caddyfile="$ROOT/tool/site/Caddyfile"
if ! out="$("$caddy" validate --adapter caddyfile --config "$caddyfile" 2>&1)"; then
  echo "$out"
  echo "ops: Caddyfile: invalid"
  status=1
elif ! "$caddy" fmt "$caddyfile" | diff -u "$caddyfile" -; then
  echo "ops: Caddyfile: not formatted (caddy fmt --overwrite tool/site/Caddyfile)"
  status=1
else
  echo "ops: Caddyfile: OK"
fi

# --- Examples of the self-hosting docs (ADR-0063 §5) ------------------------
# The unit and the Caddyfile shown on the website (the same in both languages);
# the compose file is run by server/test/image_test.dart.
examples="$(mktemp -d)"
trap 'rm -rf "$examples"' EXIT
if "$ROOT/tool/server-dist/doc-example.py" native setding.service >"$examples/setding.service" &&
  "$ROOT/tool/server-dist/doc-example.py" reverse-proxy Caddyfile >"$examples/Caddyfile"; then
  if ! out="$("$caddy" validate --adapter caddyfile --config "$examples/Caddyfile" 2>&1)"; then
    echo "$out"
    echo "ops: Caddyfile of the self-hosting docs: invalid"
    status=1
  elif ! "$caddy" fmt "$examples/Caddyfile" | diff -u "$examples/Caddyfile" -; then
    echo "ops: Caddyfile of the self-hosting docs: not formatted as caddy fmt writes it"
    status=1
  else
    echo "ops: Caddyfile of the self-hosting docs: OK"
  fi
else
  echo "ops: examples of the self-hosting docs: missing or different between de and en"
  status=1
fi

# --- systemd units ----------------------------------------------------------
if command -v systemd-analyze >/dev/null 2>&1; then
  # The units start binaries that only exist on the server.
  # The owner's servers use the unit of the self-hosting docs as well.
  # Only the problems of our unit count: verify also loads the machine's own
  # units and reports theirs (e.g. on GitHub's runner, #1254).
  out="$(systemd-analyze verify --man=no "$examples/setding.service" 2>&1 |
    "$ROOT/tool/systemd_verify_filter.py" "$examples/setding.service" || true)"
  if [ -n "$out" ]; then
    echo "$out"
    echo "ops: systemd units: problems found"
    status=1
  else
    echo "ops: systemd units: OK"
  fi
else
  echo "ops: systemd units: systemd-analyze not found, skipped" >&2
fi

exit $status
