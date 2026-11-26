#!/usr/bin/env bash
# Installs a server bundle on one of the owner's hosts (make server-install,
# make server-release; ADR-0014, ADR-0063 §7): copies tool/server/install.sh,
# backup-now.sh, the systemd unit of the self-hosting docs and the bundle,
# and runs install.sh there as root (directly or with sudo -n).
#
#   deploy.sh                 a bundle built now from the working tree (or SRC),
#                             stamped X.Y.Z-dev+<commit> (test servers)
#   deploy.sh --release X.Y.Z the bundle published with the GitHub Release vX.Y.Z,
#                             checked against its SHA256SUMS
#
# Environment:
#   SERVER          SSH target (required)
#   SSH             ssh command (default: ssh)
#   SRC             checkout to build from (default: the repository root)
#   SERVER_VERSION  version to stamp a built bundle with (default:
#                   tool/release/version-stamp.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER="${SERVER:?SERVER is not set}"
SSH="${SSH:-ssh}"
fail() { echo "deploy: $*" >&2; exit 1; }

release=""
if [ "${1:-}" = --release ]; then
  release="${2:?usage: deploy.sh --release X.Y.Z}"
  release="${release#v}"
fi

# shellcheck disable=SC2086 # SSH may carry options
arch="$($SSH "$SERVER" dpkg --print-architecture)"
case "$arch" in amd64 | arm64) ;; *) fail "unsupported architecture on $SERVER: $arch" ;; esac

setup="$(mktemp -d)"
trap 'rm -rf "$setup"' EXIT

if [ -n "$release" ]; then
  command -v gh >/dev/null || fail "the GitHub CLI (gh) is required"
  asset="setding-server-$release-linux-$arch.tar.gz"
  echo "Bundle: $asset (GitHub Release v$release)"
  gh release download "v$release" --repo tafli/setDING \
    --pattern "$asset" --pattern SHA256SUMS --dir "$setup" ||
    fail "v$release has no published $asset"
  (cd "$setup" && sha256sum --ignore-missing -c SHA256SUMS >/dev/null) ||
    fail "$asset does not match SHA256SUMS"
  mv "$setup/$asset" "$setup/bundle.tar.gz"
  rm -f "$setup/SHA256SUMS"
else
  src="${SRC:-$ROOT}"
  version="${SERVER_VERSION:-$("$ROOT/tool/release/version-stamp.sh" "$src")}"
  echo "Bundle: built from $src, $version ($arch)"
  case "$version" in
    *-dev+*) echo "Not a release; production gets releases only (make server-release)." ;;
  esac
  built="$(ARCH="$arch" OUT="$setup/out" SERVER_VERSION="$version" SRC="$src" \
    "$ROOT/tool/server-dist/build-bundle.sh")"
  mv "$built" "$setup/bundle.tar.gz"
  rm -rf "$setup/out"
fi

cp "$ROOT/tool/server/install.sh" "$ROOT/tool/server/backup-now.sh" "$setup/"
# The unit the self-hosting docs show (the same in both languages).
"$ROOT/tool/server-dist/doc-example.py" native setding.service >"$setup/setding.service"

# shellcheck disable=SC2016 # expanded on the server
remote='d=$(mktemp -d /tmp/setding-setup.XXXXXX) && tar -C "$d" -xzf - &&
  if [ "$(id -u)" -eq 0 ]; then bash "$d/install.sh" "$d"; else sudo -n bash "$d/install.sh" "$d"; fi;
  s=$?; rm -rf "$d"; exit $s'
# shellcheck disable=SC2086 # SSH may carry options
tar -czf - -C "$setup" . | $SSH "$SERVER" "$remote"
