#!/usr/bin/env bash
# Builds the website and user documentation (ADR-0030) and deploys it to its
# own server (make server-site). The website is project infrastructure,
# independent of the backend (ADR-0063 §8): installing or updating the server
# never touches it, and this never touches the server.
#
#   deploy-site.sh            the working tree (e.g. a documentation fix)
#   deploy-site.sh X.Y.Z      the release tag vX.Y.Z (after a release)
#
# Environment:
#   SITE_SERVER   SSH target of the website server (required)
#   SSH           ssh command (default: ssh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SITE_SERVER="${SITE_SERVER:?SITE_SERVER is not set}"
SSH="${SSH:-ssh}"
fail() { echo "deploy-site: $*" >&2; exit 1; }

src="$ROOT"
if [ -n "${1:-}" ]; then
  tag="v${1#v}"
  git -C "$ROOT" fetch -q --tags origin
  git -C "$ROOT" rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null ||
    fail "tag $tag does not exist"
  git -C "$ROOT" merge-base --is-ancestor "$tag^{commit}" origin/main ||
    fail "tag $tag is not on origin/main"
  # A clean checkout of the tag outside the repository, removed afterwards.
  src="$(mktemp -d "${TMPDIR:-/tmp}/setding-site-$tag.XXXXXX")"
  git -C "$ROOT" worktree add -q --detach "$src" "$tag"
  trap 'git -C "$ROOT" worktree remove --force "$src"' EXIT
  echo "Website of $tag"
fi

"$ROOT/tool/build-site.sh" "$src"
# The web server configuration and installer of this checkout (not the tag's),
# so an older tag gets today's setup.
tar -czf - --transform 's,^website/dist,site,' \
  -C "$ROOT" tool/site/install-site.sh tool/site/Caddyfile \
  -C "$src" website/dist |
  $SSH "$SITE_SERVER" "d=\$(mktemp -d /tmp/setding-site.XXXXXX) && tar -C \$d -xzf - && bash \$d/tool/site/install-site.sh \$d; s=\$?; rm -rf \$d; exit \$s"
