#!/usr/bin/env bash
# Builds the website from the working tree and deploys only the website to the
# server (make server-site, ADR-0030), e.g. for a documentation fix between
# releases. make server-install and make server-release deploy it as well.
#
# Environment:
#   SERVER   SSH target (required)
#   SSH      ssh command (default: ssh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="${SERVER:?SERVER is not set}"
SSH="${SSH:-ssh}"

"$ROOT/tool/build-site.sh"
tar -czf - --transform 's,^website/dist,site,' \
  -C "$ROOT" tool/server/install-site.sh tool/server/Caddyfile website/dist |
  $SSH "$SERVER" "d=\$(mktemp -d /tmp/setding-site.XXXXXX) && tar -C \$d -xzf - && bash \$d/tool/server/install-site.sh \$d; s=\$?; rm -rf \$d; exit \$s"
