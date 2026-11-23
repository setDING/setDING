#!/usr/bin/env python3
"""Stops a dependency upgrade that another session is already doing (#995).

Before a dependency is raised (`make upgrade` runs this first, a constraint
raised by hand runs `make upgrade-guard`), it looks for work in flight on the
dependencies:

- other local worktrees whose branch or working tree changes a dependency
  file (sessions work in `.worktrees/`, docs/development/git-workflow.md),
- open pull requests that change a dependency file,
- open issues labelled `agent:in-progress` whose title is about dependencies.

A pubspec change that only touches the `version:` line (a release) does not
count. It exits 1 when it finds something, unless `UPGRADE_FORCE=1` is set
(a deliberate parallel upgrade, e.g. of a different library). Without `gh`
or network it warns that pull requests and issues were not checked.
"""

import json
import os
import re
import subprocess
import sys

# Files whose change raises (or adds) a dependency: the pubspecs and their
# locks, the website's npm packages, the SBOM's Gradle plugin and the pinned
# check tools (docs/development/dependencies.md).
EXACT = {
    'website/package.json',
    'website/package-lock.json',
    'tool/sbom/gradle/cyclonedx.init.gradle',
    'tool/fetch-tool.sh',
}

TITLE = re.compile(r'\b(deps|dependenc|upgrade|bump)', re.IGNORECASE)


def is_dependency_file(path):
    name = path.rsplit('/', 1)[-1]
    return name in ('pubspec.yaml', 'pubspec.lock') or path in EXACT


def changes_dependencies(path, diff):
    """Whether a change of [path] with the unified [diff] touches a
    dependency; a pubspec.yaml whose only changed line is `version:` does
    not. Without a diff any change of a dependency file counts."""
    if not is_dependency_file(path):
        return False
    if not path.endswith('pubspec.yaml') or diff is None:
        return True
    for line in diff.splitlines():
        if line.startswith(('+++', '---')) or line[:1] not in '+-':
            continue
        body = line[1:].strip()
        if body and not body.startswith('version:'):
            return True
    return False


def git(*args, cwd=None):
    return subprocess.run(['git', *args], cwd=cwd, check=True,
                          capture_output=True, text=True).stdout


def worktrees(cwd):
    """(path, branch) of every worktree of the repository."""
    result, path = [], None
    for line in git('worktree', 'list', '--porcelain', cwd=cwd).splitlines():
        if line.startswith('worktree '):
            path = line[len('worktree '):]
            result.append([path, None])
        elif line.startswith('branch '):
            result[-1][1] = line[len('branch refs/heads/'):]
    return [tuple(w) for w in result]


def worktree_changes(path, base):
    """Dependency files a worktree changes against [base]: committed on its
    branch or not yet committed."""
    try:
        # The fork point: a branch behind main does not change what main
        # changed since.
        fork = git('merge-base', base, 'HEAD', cwd=path).strip()
        files = set(git('diff', '--name-only', f'{fork}..HEAD', cwd=path).split())
        files |= set(git('diff', '--name-only', 'HEAD', cwd=path).split())
        files |= set(git('ls-files', '--others', '--exclude-standard',
                         cwd=path).split())
    except subprocess.CalledProcessError:
        return []
    found = []
    for f in sorted(files):
        if not is_dependency_file(f):
            continue
        try:
            diff = git('diff', fork, '--', f, cwd=path)
        except subprocess.CalledProcessError:
            diff = None
        if changes_dependencies(f, diff):
            found.append(f)
    return found


def local_findings(cwd, base):
    here = os.path.realpath(git('rev-parse', '--show-toplevel', cwd=cwd).strip())
    found = []
    for path, branch in worktrees(cwd):
        if os.path.realpath(path) == here or not os.path.isdir(path):
            continue
        files = worktree_changes(path, base)
        if files:
            found.append(f'worktree {path} ({branch or "detached"}): '
                         + ', '.join(files))
    return found


def gh(*args):
    return json.loads(subprocess.run(['gh', *args], check=True,
                                     capture_output=True, text=True).stdout)


def pr_findings(prs, branch, diff_of):
    """Open pull requests (gh's JSON) that change a dependency, except the
    one of [branch]. [diff_of] returns a PR's diff of a file."""
    found = []
    for pr in prs:
        if pr['headRefName'] == branch:
            continue
        files = [f['path'] for f in pr.get('files') or []]
        deps = [f for f in files if is_dependency_file(f)]
        # A pubspec change without its lock may be a version bump only.
        if deps and all(f.endswith('pubspec.yaml') for f in deps):
            deps = [f for f in deps if changes_dependencies(f, diff_of(pr, f))]
        if deps:
            found.append(f'PR #{pr["number"]} {pr["title"]} '
                         f'({pr["headRefName"]}): ' + ', '.join(deps))
    return found


def issue_findings(issues, own):
    return [f'issue #{i["number"]} {i["title"]} (agent:in-progress)'
            for i in issues if i['number'] not in own and TITLE.search(i['title'])]


def file_diff(diff, path):
    """The part of a multi-file unified [diff] that belongs to [path]."""
    parts = re.split(r'(?m)^diff --git ', diff)
    for part in parts:
        if part.startswith(f'a/{path} '):
            return part
    return None


def remote_findings(branch):
    prs = gh('pr', 'list', '--state', 'open', '--limit', '200',
             '--json', 'number,title,headRefName,files')

    def diff_of(pr, path):
        try:
            out = subprocess.run(['gh', 'pr', 'diff', str(pr['number'])],
                                 check=True, capture_output=True, text=True).stdout
        except (OSError, subprocess.CalledProcessError):
            return None
        return file_diff(out, path)

    issues = gh('issue', 'list', '--state', 'open', '--label', 'agent:in-progress',
                '--limit', '200', '--json', 'number,title')
    own = {int(n) for n in re.findall(r'^[a-z]+/(\d+)-', branch or '')}
    return pr_findings(prs, branch, diff_of) + issue_findings(issues, own)


def main():
    cwd = os.getcwd()
    base = os.environ.get('UPGRADE_BASE', 'origin/main')
    branch = git('branch', '--show-current', cwd=cwd).strip()
    found = local_findings(cwd, base)
    if os.environ.get('UPGRADE_GUARD_OFFLINE') == '1':
        print('upgrade-guard: pull requests and issues not checked (offline)')
    else:
        try:
            found += remote_findings(branch)
        except (OSError, subprocess.CalledProcessError, ValueError) as e:
            print(f'upgrade-guard: warning: pull requests and issues not checked ({e})')
    if not found:
        print('upgrade-guard: no other dependency upgrade in progress')
        return 0
    print('upgrade-guard: dependencies are already being changed elsewhere:')
    for f in found:
        print(f'  - {f}')
    if os.environ.get('UPGRADE_FORCE') == '1':
        print('upgrade-guard: UPGRADE_FORCE=1, continuing')
        return 0
    print('Coordinate with that session (or wait for its merge) instead of '
          'upgrading in parallel; UPGRADE_FORCE=1 overrides '
          '(docs/development/dependencies.md).')
    return 1


if __name__ == '__main__':
    sys.exit(main())
