#!/usr/bin/env bash
# Copies a checkout to the server and runs install.sh there (make server-install,
# ADR-0014): hooks, migrations, the web client built from the same checkout,
# and the version stamp read by /api/setding/config
# (serverVersion).
#
# Environment:
#   SERVER          SSH target (required)
#   SSH             ssh command (default: ssh)
#   PB_VERSION      PocketBase version for install.sh (required)
#   SRC             checkout to deploy (default: the repository root)
#   SERVER_VERSION  version to stamp (default: tool/release/version-stamp.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="${SERVER:?SERVER is not set}"
SSH="${SSH:-ssh}"
PB_VERSION="${PB_VERSION:?PB_VERSION is not set}"
SRC="${SRC:-$ROOT}"
version="${SERVER_VERSION:-$("$ROOT/tool/release/version-stamp.sh" "$SRC")}"

echo "Server version: $version"
case "$version" in
  *-dev+*) echo "Not a release; production deploys use 'make server-release' (git workflow section 10)." ;;
esac

if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi
# A fresh checkout (make server-release) has no packages yet; build-web.sh
# compiles the drift worker before Flutter would fetch them (#348).
(cd "$SRC/app" && flutter pub get >/dev/null)
"$SRC/tool/build-web.sh"

# Ends up in the server's pb_hooks; PocketBase only loads *.pb.js from there.
stamp="$SRC/app/build/server-stamp"
mkdir -p "$stamp/server/pb_hooks"
echo "$version" >"$stamp/server/pb_hooks/setding-version.txt"

tar -czf - --transform 's,^app/build/web,web,' \
  -C "$SRC" tool/server server/pb_hooks server/pb_migrations app/build/web \
  -C "$stamp" server/pb_hooks/setding-version.txt |
  $SSH "$SERVER" "d=\$(mktemp -d /tmp/setding-setup.XXXXXX) && tar -C \$d -xzf - && bash \$d/tool/server/install.sh $PB_VERSION"
