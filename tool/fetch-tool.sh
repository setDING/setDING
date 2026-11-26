#!/usr/bin/env bash
# Downloads a pinned check tool of the test gate into a cache and prints the path
# of its binary (issue #644, docs/development/operations-tests.md):
#
#   fetch-tool.sh shellcheck   ShellCheck (GPL-3.0): lints the shell scripts
#   fetch-tool.sh caddy        Caddy (Apache-2.0): validates and serves tool/site/Caddyfile
#   fetch-tool.sh geckodriver  geckodriver (MPL-2.0): runs the web integration tests in Firefox (make web-test BROWSER=firefox)
#
# The tools only run on the development machine and in CI; nothing of them is
# copied into the repository or shipped. The cache is
# ${SETDING_CACHE:-${XDG_CACHE_HOME:-~/.cache}/setding}. Downloads are verified:
# ShellCheck and geckodriver against the SHA-256 sums pinned below,
# Caddy against the release's checksums.txt. tool/check-deps.sh checks that the
# pinned versions are the newest; raising a version needs the ShellCheck and
# geckodriver sums updated (sha256sum of the release's archives, or the
# digests GitHub shows for them).
set -euo pipefail

SHELLCHECK_VERSION=0.11.0
CADDY_VERSION=2.11.9
GECKODRIVER_VERSION=0.37.1

tool="${1:?usage: fetch-tool.sh shellcheck|caddy|geckodriver}"

case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

case "$tool" in
  shellcheck) version="$SHELLCHECK_VERSION" ;;
  caddy) version="$CADDY_VERSION" ;;
  geckodriver) version="$GECKODRIVER_VERSION" ;;
  *) echo "unknown tool: $tool (shellcheck, caddy or geckodriver)" >&2; exit 1 ;;
esac

cache="${SETDING_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/setding}/$tool/$version"
bin="$cache/$tool"
if [ -x "$bin" ]; then
  echo "$bin"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

case "$tool" in
  shellcheck)
    case "$os/$arch" in
      linux/amd64) platform=linux.x86_64 sum=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 ;;
      linux/arm64) platform=linux.aarch64 sum=12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588 ;;
      darwin/amd64) platform=darwin.x86_64 sum=3c89db4edcab7cf1c27bff178882e0f6f27f7afdf54e859fa041fca10febe4c6 ;;
      darwin/arm64) platform=darwin.aarch64 sum=56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79 ;;
    esac
    archive="shellcheck-v$version.$platform.tar.xz"
    curl -fsSL -o "$tmp/$archive" \
      "https://github.com/koalaman/shellcheck/releases/download/v$version/$archive"
    echo "$sum  $tmp/$archive" | sha256sum -c - >/dev/null
    tar -xJf "$tmp/$archive" -C "$tmp"
    src="$tmp/shellcheck-v$version/shellcheck"
    ;;
  caddy)
    [ "$os" = darwin ] && os=mac
    archive="caddy_${version}_${os}_${arch}.tar.gz"
    base="https://github.com/caddyserver/caddy/releases/download/v$version"
    curl -fsSL -o "$tmp/$archive" "$base/$archive"
    curl -fsSL -o "$tmp/checksums.txt" "$base/caddy_${version}_checksums.txt"
    (cd "$tmp" && grep " $archive\$" checksums.txt | sha512sum -c - >/dev/null)
    tar -xzf "$tmp/$archive" -C "$tmp" caddy
    src="$tmp/caddy"
    ;;
  geckodriver)
    case "$os/$arch" in
      linux/amd64) platform=linux64 sum=e815130ea95983e162ae91843b48d3a3ce991735635fce83a647afde21e09f7e ;;
      linux/arm64) platform=linux-aarch64 sum=8fd90b951422fbad5b56539fb344dff66eb3f986d615d8d6fde9f1f62dad610c ;;
      darwin/amd64) platform=macos sum=d02b3f7003f999caf90974a2ef5da0286c05d01cee19112c86846d759fdba4f5 ;;
      darwin/arm64) platform=macos-aarch64 sum=d02b3f7003f999caf90974a2ef5da0286c05d01cee19112c86846d759fdba4f5 ;;
    esac
    archive="geckodriver-v$version-$platform.tar.gz"
    curl -fsSL -o "$tmp/$archive" \
      "https://github.com/mozilla/geckodriver/releases/download/v$version/$archive"
    echo "$sum  $tmp/$archive" | sha256sum -c - >/dev/null
    tar -xzf "$tmp/$archive" -C "$tmp" geckodriver
    src="$tmp/geckodriver"
    ;;
esac

mkdir -p "$cache"
install -m 755 "$src" "$bin"
echo "$bin"
