#!/usr/bin/env bash
# Deploys the server from a release tag once its release build passed
# (make server-release; git workflow section 10, ADR-0014, ADR-0021).
#
#   deploy-server.sh [x.y.z]     (default: the newest release tag)
#
# 1. The tag must exist and be on origin/main.
# 2. Waits for the tag's run of the Release workflow; refuses to deploy unless it
#    succeeded and the GitHub Release exists, so the apps for this version can be
#    downloaded before the server may refuse older ones (ADR-0029).
# 3. Deploys hooks, migrations and the web client from a clean checkout of the
#    tag (tool/server/deploy.sh, like make server-install), stamped with the
#    version, and checks it.
#
# Environment: SERVER, SSH and PB_VERSION as in the Makefile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="${SERVER:?SERVER is not set}"
SSH="${SSH:-ssh}"

fail() { echo "server-release: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

command -v gh >/dev/null || fail "the GitHub CLI (gh) is required"

step "Release tag"
git -C "$ROOT" fetch -q --tags origin
if [ -n "${1:-}" ]; then
  tag="v${1#v}"
else
  tag="$(git -C "$ROOT" tag --list 'v*' --sort=-v:refname | head -n 1)"
fi
[ -n "$tag" ] || fail "no release tag found"
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
# A clean checkout of the tag OUTSIDE the repository: inside it (e.g. under
# app/build) Flutter would resolve the outer app's package config and fail
# (#348). git removes it again afterwards.
dir="$(mktemp -d "${TMPDIR:-/tmp}/setding-release-$version.XXXXXX")"
git -C "$ROOT" worktree add -q --detach "$dir" "$tag"
trap 'git -C "$ROOT" worktree remove --force "$dir"' EXIT
SRC="$dir" SERVER_VERSION="$version" SERVER="$SERVER" SSH="$SSH" \
  PB_VERSION="${PB_VERSION:?PB_VERSION is not set}" "$ROOT/tool/server/deploy.sh"

step "Check"
deployed="$($SSH "$SERVER" cat /opt/pocketbase/pb_hooks/setding-version.txt)"
[ "$deployed" = "$version" ] || fail "the server reports '$deployed', expected $version"
echo "Server runs setDING $version."
