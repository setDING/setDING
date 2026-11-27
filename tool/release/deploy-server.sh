#!/usr/bin/env bash
# Deploys the server from a release tag once its release build passed
# (make server-release; git workflow section 10, ADR-0014, ADR-0021).
#
#   deploy-server.sh [x.y.z]     (default: the newest release tag)
#
# 0. The tag (tool/release/release_tag.py, ADR-0069): production gets final
#    releases only (default the newest final tag); staging also gets
#    pre-releases (default the newest tag, pre-releases included).
# 1. The tag must exist and be on origin/main.
# 2. Waits for the tag's run of the Release workflow; refuses to deploy unless it
#    succeeded and the GitHub Release exists, so the apps for this version can be
#    downloaded before the server may refuse older ones (ADR-0029).
# 3. Installs the server bundle published with the release (checked against
#    its SHA256SUMS, tool/server/deploy.sh --release) and checks the version.
#
# Environment: SERVER (the server), TARGET (prod or staging, default prod) and
# SSH, as in the Makefile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="${SERVER:?SERVER is not set}"
SSH="${SSH:-ssh}"
TARGET="${TARGET:-prod}"

fail() { echo "server-release: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

command -v gh >/dev/null || fail "the GitHub CLI (gh) is required"

step "Release tag"
git -C "$ROOT" fetch -q --tags origin
tag="$("$ROOT/tool/release/release_tag.py" "$TARGET" "${1:-}")" || exit 1
git -C "$ROOT" rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null ||
  fail "tag $tag does not exist"
git -C "$ROOT" merge-base --is-ancestor "$tag^{commit}" origin/main ||
  fail "tag $tag is not on origin/main"
version="${tag#v}"
echo "$tag"

step "Release build"
run="$(gh run list --workflow release.yml --event push --branch "$tag" --limit 1 \
  --json databaseId,status,conclusion \
  --jq '.[0] | "\(.databaseId) \(.status) \(.conclusion)"')"
[ -n "$run" ] || fail "no release build for $tag; push the tag first"
read -r id status conclusion <<<"$run"
if [ "$status" != completed ]; then
  echo "Waiting for run $id ($status) …"
  gh run watch "$id" --interval 30 >/dev/null || true
  conclusion="$(gh run view "$id" --json conclusion --jq .conclusion)"
fi
[ "$conclusion" = success ] ||
  fail "release build $id for $tag ended with '$conclusion'; nothing deployed (fix it and release the next patch version)"
gh release view "$tag" --json tagName >/dev/null 2>&1 ||
  fail "the release build passed, but there is no GitHub Release $tag"
echo "run $id passed, GitHub Release $tag published"

step "Deploy $tag to $SERVER"
# The bundle published with the release, as self-hosters get it (ADR-0063 §7).
SERVER="$SERVER" SSH="$SSH" "$ROOT/tool/server/deploy.sh" --release "$version"

step "Check"
# shellcheck disable=SC2086 # SSH may carry options
deployed="$($SSH "$SERVER" cat /opt/setding/current/VERSION)"
[ "$deployed" = "$version" ] || fail "the server reports '$deployed', expected $version"
echo "Server runs setDING $version."
