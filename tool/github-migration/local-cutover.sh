#!/usr/bin/env bash
# Switch a development machine to the GitHub repository (issue #116, runbook:
# docs/development/github-migration.md).
#
# The history rewrite changes every commit id, so existing checkouts cannot be
# rebased onto GitHub; a fresh clone replaces them. This script
#
#   1. clones the GitHub repository into NEW_DIR,
#   2. copies the local, untracked data from OLD_DIR (test instance, server
#      backups, local Claude settings) – nothing tracked by git,
#   3. checks the commit identity: the new clone has no repository-local
#      `factoryd` identity, so the global one applies (the owner's name and
#      e-mail, GPG-signed commits and tags), and signing must work.
#
#   local-cutover.sh OLD_DIR NEW_DIR [--apply]
#
# Without --apply it only prints what it would do and runs the identity check.
set -euo pipefail

GITHUB_REPO=${GITHUB_REPO:-tafli/RealChord}
GITHUB_URL=${GITHUB_URL:-git@github.com:$GITHUB_REPO.git}
# Untracked local data worth keeping (relative to the repository root).
KEEP=(.dev-data .server-backups .claude/settings.local.json)

die() { echo "error: $*" >&2; exit 1; }
[ $# -ge 2 ] || { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
OLD=$(realpath "$1"); NEW=$(realpath -m "$2"); APPLY=${3:-}
[ -d "$OLD/.git" ] || die "$OLD is not a git checkout"
[ ! -e "$NEW" ] || die "$NEW exists"

run() { if [ "$APPLY" = --apply ]; then "$@"; else echo "would run: $*"; fi; }

# Work must not be lost: the old checkout must not have unpushed work.
dirty=$(git -C "$OLD" status --porcelain --untracked-files=no)
[ -z "$dirty" ] || die "$OLD has uncommitted changes:"$'\n'"$dirty"
for wt in $(git -C "$OLD" worktree list --porcelain | sed -n 's/^worktree //p'); do
  [ "$wt" = "$OLD" ] || echo "note: worktree $wt belongs to the old checkout; finish or remove it"
done

run git clone "$GITHUB_URL" "$NEW"
for path in "${KEEP[@]}"; do
  if [ -e "$OLD/$path" ]; then
    run mkdir -p "$(dirname "$NEW/$path")"
    run cp -a "$OLD/$path" "$NEW/$path"
  fi
done

echo
echo "Commit identity (global git config, used by the new clone):"
name=$(git config --global user.name || true)
email=$(git config --global user.email || true)
key=$(git config --global user.signingkey || true)
sign=$(git config --global commit.gpgsign || true)
echo "  user:    $name <$email>"
echo "  key:     ${key:-<none>}  commit.gpgsign=${sign:-false}  tag.gpgsign=$(git config --global tag.gpgsign || echo false)"
[ -n "$name" ] && [ -n "$email" ] || die "global user.name/user.email not set"
[ "$sign" = true ] || die "global commit.gpgsign is not true"
[ -n "$key" ] || die "global user.signingkey not set"
gpg --list-secret-keys "$key" >/dev/null 2>&1 || die "secret key $key not in the GPG keyring"
echo test | gpg --batch --local-user "$key" --sign >/dev/null 2>&1 \
  || die "signing with $key failed (gpg-agent locked? run: echo test | gpg --sign >/dev/null)"
echo "  signing: OK"
if [ "$APPLY" = --apply ] && [ -n "$(git -C "$NEW" config --local --get user.name || true)" ]; then
  die "$NEW has a repository-local user.name; remove it"
fi
echo
if [ "$APPLY" = --apply ]; then
  echo "New checkout: $NEW. Run 'make setup' there; keep $OLD read-only until you delete it."
else
  echo "Dry run. Re-run with --apply to clone."
fi
