#!/usr/bin/env bash
# Rewrite the git history for GitHub and push it (issue #116, runbook:
# docs/development/github-migration.md).
#
# No reference to the Forgejo instance may reach GitHub, and the squash commits
# carry "Reviewed-on: https://<forgejo>/…/pulls/N" lines, older docs name the
# Forgejo host and CI image. So the history is rewritten with git filter-repo in
# a separate bare clone (EXPORT_DIR/repo.git) – the working checkouts are never
# touched – using the rules of `migrate.py rules` on file contents and commit
# messages. All commit ids change; filter-repo writes the old -> new map that
# `migrate.py import` uses to fix commit ids in issue texts. Commit signatures
# are dropped by the rewrite (they would no longer match).
#
#   history.sh prepare   clone main + tags from Forgejo, rewrite, verify (local only)
#   history.sh verify    check the rewritten clone for references to the Forgejo host
#   history.sh push      push main and the tags to the empty GitHub repository
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HERE=$ROOT/tool/github-migration
EXPORT_DIR=${EXPORT_DIR:-$ROOT/.github-migration}
# The Forgejo remote is taken from `origin` on purpose: the repository must not
# name the Forgejo instance once it is on GitHub (set FORGEJO_URL after the move).
FORGEJO_URL=${FORGEJO_URL:-$(git -C "$ROOT" remote get-url origin)}
case "$FORGEJO_URL" in *github.com*) echo "error: origin is GitHub; set FORGEJO_URL" >&2; exit 1 ;; esac
FORGEJO_HOST=${FORGEJO_HOST:-$(echo "$FORGEJO_URL" | sed -E 's#^([a-z+]+://)?([^@/]+@)?([^/:]+).*#\3#')}
FORGEJO_REPO=${FORGEJO_REPO:-$(echo "$FORGEJO_URL" | sed -E 's#^([a-z+]+://)?([^@/]+@)?[^/:]+(:[0-9]+)?[:/]##; s#\.git$##')}
GITHUB_REPO=${GITHUB_REPO:-tafli/RealChord}
GITHUB_URL=${GITHUB_URL:-git@github.com:$GITHUB_REPO.git}
REPO=$EXPORT_DIR/repo.git
export EXPORT_DIR FORGEJO_HOST FORGEJO_REPO GITHUB_REPO

die() { echo "error: $*" >&2; exit 1; }

prepare() {
  command -v git-filter-repo >/dev/null || die "git-filter-repo is not installed"
  [ ! -e "$REPO" ] || die "$REPO exists; remove it to start over (rm -rf $REPO)"
  mkdir -p "$EXPORT_DIR"
  echo "Cloning main and tags from $FORGEJO_URL …"
  git clone -q --bare --single-branch --branch main "$FORGEJO_URL" "$REPO"
  git -C "$REPO" fetch -q origin 'refs/tags/*:refs/tags/*'
  git -C "$REPO" remote remove origin
  python3 "$HERE/migrate.py" rules >"$EXPORT_DIR/replacements.txt"
  echo "Rewriting history (contents and messages) …"
  # --replace-message uses the same rules; "Reviewed-on:" lines then point to
  # the GitHub pull request number, which the issue import keeps identical.
  # MAILMAP=<file> optionally rewrites authors too (git mailmap format).
  git -C "$REPO" filter-repo --force \
    --replace-text "$EXPORT_DIR/replacements.txt" \
    --replace-message "$EXPORT_DIR/replacements.txt" \
    ${MAILMAP:+--mailmap "$(realpath "$MAILMAP")"}
  verify
  echo "Rewritten clone: $REPO ($(git -C "$REPO" rev-list --count main) commits on main)"
  echo "Commit map:      $REPO/filter-repo/commit-map"
}

verify() {
  [ -d "$REPO" ] || die "$REPO missing, run '$0 prepare' first"
  local refs hits
  refs=$(git -C "$REPO" for-each-ref --format='%(refname)')
  [ "$(echo "$refs" | grep -cv '^refs/\(heads/main\|tags/\)')" = 0 ] \
    || die "unexpected refs in $REPO:"$'\n'"$refs"
  # Every file version appears in some diff, every message in the log.
  hits=$(git -C "$REPO" log --all -p --format='%H%n%B%n%an <%ae>%n%cn <%ce>' \
    | grep -ci -- "$FORGEJO_HOST" || true)
  [ "$hits" = 0 ] || {
    git -C "$REPO" log --all -p --format='commit %H%n%B' | grep -in -- "$FORGEJO_HOST" | head -20
    die "$hits line(s) still reference $FORGEJO_HOST"
  }
  # File names, just in case.
  ! git -C "$REPO" log --all --name-only --format= | grep -qi -- "$FORGEJO_HOST" \
    || die "a file name references $FORGEJO_HOST"
  echo "OK: no reference to $FORGEJO_HOST in contents, messages or file names."
}

push() {
  verify
  gh repo view "$GITHUB_REPO" --json name >/dev/null || die "GitHub repository $GITHUB_REPO not reachable with gh"
  [ -z "$(git ls-remote "$GITHUB_URL")" ] || die "$GITHUB_URL is not empty"
  echo "Pushing main and tags to $GITHUB_URL …"
  git -C "$REPO" push "$GITHUB_URL" refs/heads/main:refs/heads/main
  git -C "$REPO" push "$GITHUB_URL" --tags
  echo "Done. Now import the issues: tool/github-migration/migrate.py import"
}

case "${1:-}" in
  prepare) prepare ;;
  verify) verify ;;
  push) push ;;
  *) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
