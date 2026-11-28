"""Tests of the job selection of make check (tool/check_select.py, #684)."""

import unittest

from check_select import JOBS, select


def jobs(*files, **kw):
    return select(list(files), **kw)[0]


class SelectTest(unittest.TestCase):
    def test_empty_change_runs_everything_strictly(self):
        self.assertEqual(select([]), (JOBS, True, 'no changes against main'))

    def test_app_code_runs_the_app_jobs(self):
        self.assertEqual(jobs('app/lib/ui/song_screen.dart'),
                         ['app-static', 'app-tests', 'app-web'])

    def test_app_tests_skip_the_web_build(self):
        self.assertEqual(jobs('app/test/song_screen_test.dart'),
                         ['app-static', 'app-tests'])

    def test_chordpro_runs_the_app_too(self):
        self.assertEqual(jobs('packages/chordpro/lib/src/parser.dart'),
                         ['chordpro', 'app-static', 'app-tests', 'app-web'])

    def test_server_runs_the_app_sync_tests(self):
        self.assertEqual(jobs('server/pb_migrations/1_x.js'),
                         ['server', 'app-static', 'app-tests'])

    def test_website_and_screenshots(self):
        self.assertEqual(jobs('website/src/content/docs/en/sets.md',
                              'docs/screenshots/en/sets.png'), ['website'])

    def test_whats_new_reaches_the_website(self):
        self.assertIn('website', jobs('app/assets/whats_new.json'))

    def test_upgrade_guard_runs_its_tests(self):
        self.assertEqual(jobs('tool/upgrade_guard.py'), ['tools'])

    def test_nightly_test_summary_runs_its_tests(self):
        self.assertEqual(jobs('tool/ci/test_report.py'), ['tools'])

    def test_help_links_reach_the_website(self):
        # The website tests that the app's help pages exist (#993).
        self.assertEqual(jobs('app/lib/ui/widgets/docs_link.dart'),
                         ['website', 'app-static', 'app-tests', 'app-web'])

    def test_version_bump_checks_the_changelog(self):
        self.assertIn('changelog', jobs('app/pubspec.yaml'))

    def test_docs_only_runs_nothing(self):
        self.assertEqual(jobs('docs/architecture/adr/0010-git-workflow.md',
                              'AGENTS.md', 'README.md'), [])

    def test_shell_scripts_run_shellcheck(self):
        self.assertEqual(jobs('tool/android-test.sh'), ['ops'])
        self.assertEqual(jobs('tool/site/Caddyfile'), ['server', 'ops'])

    def test_server_bundle_runs_its_tests(self):
        self.assertEqual(
            jobs('tool/server-dist/build-bundle.sh'), ['server', 'ops'])
        self.assertEqual(
            jobs('tool/server-dist/doc-example.py'), ['server', 'ops', 'tools'])

    def test_self_hosting_docs_run_their_examples(self):
        self.assertEqual(
            jobs('website/src/content/docs/self-hosting/docker.mdx'),
            ['server', 'ops', 'website'])
        self.assertEqual(
            jobs('website/src/content/docs/en/self-hosting/native.mdx'),
            ['server', 'ops', 'website'])

    def test_server_image_pins_its_base_image(self):
        self.assertEqual(select(['tool/server-dist/Dockerfile'])[1], True)

    def test_prefix_needs_a_separator(self):
        # tool/sbom matches tool/sbom/… and tool/sbom.sh, not tool/sbomx.
        self.assertEqual(jobs('tool/sbom/lib/main.dart'), ['sbom'])
        self.assertEqual(jobs('tool/sbom.sh'), ['ops', 'sbom'])

    def test_check_files_run_everything(self):
        for f in ('Makefile', 'tool/check.sh', 'tool/check_select.py',
                  '.github/workflows/ci.yml'):
            selected, strict, reason = select([f])
            self.assertEqual(selected, JOBS, f)
            self.assertTrue(strict)
            self.assertIn(f, reason)

    def test_unknown_files_run_everything(self):
        selected, _, reason = select(['something/new.txt'])
        self.assertEqual(selected, JOBS)
        self.assertIn('matches no rule', reason)

    def test_large_changes_run_everything(self):
        files = [f'app/lib/f{i}.dart' for i in range(41)]
        self.assertEqual(select(files)[0], JOBS)
        self.assertEqual(jobs(*files[:40]), ['app-static', 'app-tests', 'app-web'])
        self.assertEqual(select(files[:5], threshold=4)[0], JOBS)

    def test_deps_strict_only_when_pins_change(self):
        self.assertFalse(select(['app/lib/main.dart'])[1])
        self.assertTrue(select(['app/pubspec.lock'])[1])
        self.assertTrue(select(['website/package.json'])[1])
        self.assertTrue(select(['server/pubspec.yaml'])[1])

    def test_jobs_keep_the_order_of_check_sh(self):
        selected = jobs('app/lib/a.dart', 'website/x.md', 'packages/chordpro/a.dart')
        self.assertEqual(selected, [j for j in JOBS if j in selected])


if __name__ == '__main__':
    unittest.main()
