"""Tests of the parallel-upgrade check of make upgrade (tool/upgrade_guard.py, #995)."""

import os
import subprocess
import tempfile
import unittest

from upgrade_guard import (changes_dependencies, file_diff, is_dependency_file,
                           issue_findings, local_findings, pr_findings)

VERSION_ONLY = """\
--- a/app/pubspec.yaml
+++ b/app/pubspec.yaml
@@ -1,3 +1,3 @@
 name: setding
-version: 1.4.0+14
+version: 1.5.0+15
"""

RAISED = VERSION_ONLY + """\
@@ -20,1 +20,1 @@
-  drift: ^2.30.0
+  drift: ^2.31.0
"""


class DependencyFileTest(unittest.TestCase):
    def test_dependency_files(self):
        for f in ('app/pubspec.yaml', 'packages/chordpro/pubspec.lock',
                  'website/package-lock.json', 'tool/fetch-tool.sh',
                  'tool/sbom/gradle/cyclonedx.init.gradle',
                  'tool/server-dist/Dockerfile'):
            self.assertTrue(is_dependency_file(f), f)

    def test_other_files(self):
        for f in ('app/lib/main.dart', 'website/src/pages/index.astro',
                  'docs/development/dependencies.md'):
            self.assertFalse(is_dependency_file(f), f)

    def test_version_bump_alone_does_not_count(self):
        self.assertFalse(changes_dependencies('app/pubspec.yaml', VERSION_ONLY))

    def test_raised_constraint_counts(self):
        self.assertTrue(changes_dependencies('app/pubspec.yaml', RAISED))

    def test_lock_always_counts(self):
        self.assertTrue(changes_dependencies('app/pubspec.lock', ''))


def pr(number, branch, *files, title='x'):
    return {'number': number, 'title': title, 'headRefName': branch,
            'files': [{'path': f} for f in files]}


class RemoteTest(unittest.TestCase):
    def test_pr_with_a_lock_is_found(self):
        found = pr_findings([pr(7, 'chore/7-deps', 'app/pubspec.lock')],
                            'main', lambda p, f: None)
        self.assertEqual(len(found), 1)
        self.assertIn('PR #7', found[0])

    def test_own_pr_and_unrelated_prs_are_ignored(self):
        prs = [pr(7, 'chore/7-deps', 'app/pubspec.lock'),
               pr(8, 'feat/8-x', 'app/lib/main.dart')]
        self.assertEqual(pr_findings(prs, 'chore/7-deps', lambda p, f: None), [])

    def test_release_pr_is_ignored(self):
        prs = [pr(9, 'chore/9-release', 'app/pubspec.yaml', 'CHANGELOG.md')]
        self.assertEqual(pr_findings(prs, 'main', lambda p, f: VERSION_ONLY), [])
        self.assertEqual(len(pr_findings(prs, 'main', lambda p, f: RAISED)), 1)

    def test_file_diff_picks_the_file(self):
        diff = ('diff --git a/CHANGELOG.md b/CHANGELOG.md\n+x\n'
                'diff --git a/app/pubspec.yaml b/app/pubspec.yaml\n' + VERSION_ONLY)
        self.assertIn('version:', file_diff(diff, 'app/pubspec.yaml'))
        self.assertIsNone(file_diff(diff, 'server/pubspec.yaml'))

    def test_issues_about_dependencies(self):
        issues = [{'number': 1, 'title': 'chore(deps): upgrade drift'},
                  {'number': 2, 'title': 'Bump flutter_svg'},
                  {'number': 3, 'title': 'Song review status'},
                  {'number': 4, 'title': 'Upgrade guard'}]
        found = issue_findings(issues, own={4})
        self.assertEqual([f.split()[1] for f in found], ['#1', '#2'])


def run(*args, cwd):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True)


class WorktreeTest(unittest.TestCase):
    """Real worktrees: a session's committed and uncommitted changes."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, 'repo')
        os.makedirs(os.path.join(self.root, 'app'))
        run('git', 'init', '-q', '-b', 'main', cwd=self.root)
        for k, v in (('user.name', 't'), ('user.email', 't@t'),
                     ('commit.gpgsign', 'false')):
            run('git', 'config', k, v, cwd=self.root)
        self.write(self.root, 'app/pubspec.yaml', 'version: 1.0.0\ndrift: ^2.0.0\n')
        self.write(self.root, 'app/pubspec.lock', 'drift: 2.0.0\n')
        run('git', 'add', '.', cwd=self.root)
        run('git', 'commit', '-qm', 'init', cwd=self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, root, path, text):
        with open(os.path.join(root, path), 'w', encoding='utf-8') as f:
            f.write(text)

    def worktree(self, name):
        path = os.path.join(self.root, '.worktrees', name)
        run('git', 'worktree', 'add', '-q', '-b', name, path, 'main', cwd=self.root)
        return path

    def test_no_other_work(self):
        self.worktree('feat-1')
        self.assertEqual(local_findings(self.root, 'main'), [])

    def test_uncommitted_lock_change_is_found(self):
        wt = self.worktree('chore-2-deps')
        self.write(wt, 'app/pubspec.lock', 'drift: 2.1.0\n')
        found = local_findings(self.root, 'main')
        self.assertEqual(len(found), 1)
        self.assertIn('chore-2-deps', found[0])
        self.assertIn('app/pubspec.lock', found[0])

    def test_committed_constraint_is_found(self):
        wt = self.worktree('chore-3-deps')
        self.write(wt, 'app/pubspec.yaml', 'version: 1.0.0\ndrift: ^2.1.0\n')
        run('git', 'commit', '-qam', 'raise', cwd=wt)
        self.assertEqual(len(local_findings(self.root, 'main')), 1)

    def test_version_bump_is_ignored(self):
        wt = self.worktree('chore-4-release')
        self.write(wt, 'app/pubspec.yaml', 'version: 1.1.0\ndrift: ^2.0.0\n')
        self.assertEqual(local_findings(self.root, 'main'), [])

    def test_branch_behind_main_is_not_blamed_for_main(self):
        wt = self.worktree('feat-6-x')
        self.write(self.root, 'app/pubspec.yaml', 'version: 1.0.0\ndrift: ^2.1.0\n')
        run('git', 'commit', '-qam', 'upgrade on main', cwd=self.root)
        self.write(wt, 'app/pubspec.yaml', 'version: 1.1.0\ndrift: ^2.0.0\n')
        self.assertEqual(local_findings(self.root, 'main'), [])

    def test_own_worktree_is_ignored(self):
        wt = self.worktree('chore-5-deps')
        self.write(wt, 'app/pubspec.lock', 'drift: 2.1.0\n')
        self.assertEqual(local_findings(wt, 'main'), [])


if __name__ == '__main__':
    unittest.main()
