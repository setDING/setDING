#!/usr/bin/env bash
# Prints the version a server deploy is stamped with (ADR-0014, ADR-0028):
# x.y.z on a clean checkout of the release tag vx.y.z, otherwise
# x.y.z-dev+<commit> (with ".dirty" for uncommitted changes), so a deploy that is
# not a release can always be told apart.
#
#   version-stamp.sh [source-dir]     (default: the repository root)
set -euo pipefail

SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
version="$(sed -n 's/^version: *\([^+]*\).*/\1/p' "$SRC/app/pubspec.yaml")"
[ -n "$version" ] || { echo "no version in $SRC/app/pubspec.yaml" >&2; exit 1; }

dirty=""
[ -z "$(git -C "$SRC" status --porcelain --untracked-files=no)" ] || dirty=".dirty"
if [ -z "$dirty" ] &&
  git -C "$SRC" describe --tags --exact-match --match "v$version" HEAD >/dev/null 2>&1; then
  echo "$version"
else
  echo "$version-dev+$(git -C "$SRC" rev-parse --short HEAD)$dirty"
fi
