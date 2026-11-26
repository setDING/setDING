#!/usr/bin/env bash
# Static checks of the operations files (issue #644, part of make check;
# docs/development/operations-tests.md):
# - ShellCheck on every shell script of the repository (*.sh and files with a
#   sh/bash shebang);
# - tool/site/Caddyfile: `caddy validate` and `caddy fmt` (formatted as Caddy
#   writes it);
# - the systemd units of tool/server/ and tool/server-dist/ with `systemd-analyze verify`, if the
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
    git grep -lI -E '^#!(/usr/bin/env (ba)?sh|/bin/(ba)?sh)' -- ':!*.sh' || true
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

# --- systemd units ----------------------------------------------------------
if command -v systemd-analyze >/dev/null 2>&1; then
  # The units start binaries that only exist on the server.
  out="$(systemd-analyze verify --man=no "$ROOT"/tool/server/*.service "$ROOT"/tool/server/*.timer \
    "$ROOT"/tool/server-dist/*.service 2>&1 |
    grep -v -E 'Command .* is not executable: No such file or directory' || true)"
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
