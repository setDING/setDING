"""Tests of the make server-* targets: which server they work on (#1055).

The deploy scripts and ssh are replaced by stubs that print what they got, so
nothing reaches a server. The owner's local.mk is overridden on the command
line (an empty SERVER and SITE_SERVER, test values for the others).
"""

import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ServerTargetsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        stub = pathlib.Path(self.tmp.name) / 'stub'
        stub.write_text('#!/bin/sh\necho "SERVER=$SERVER SERVER_SITE=$SERVER_SITE TARGET=$TARGET ARGS=$*"\n')
        stub.chmod(0o755)
        self.stub = str(stub)

    def tearDown(self):
        self.tmp.cleanup()

    def make(self, *args, **variables):
        values = {
            'SERVER': '', 'SITE_SERVER': '',
            'SERVER_PROD': 'debian@prod', 'SERVER_STAGING': 'root@staging',
            'SERVER_SITE': 'debian@site',
            'SERVER_DEPLOY': self.stub, 'SERVER_RELEASE_DEPLOY': self.stub,
            'SITE_DEPLOY': self.stub, 'SSH': self.stub,
        }
        values.update(variables)
        cmd = ['make', '-s', '--no-print-directory', '-C', str(ROOT), *args,
               *(f'{k}={v}' for k, v in values.items())]
        env = {**os.environ, 'MAKEFLAGS': ''}
        return subprocess.run(cmd, capture_output=True, text=True, env=env)

    def test_install_goes_to_staging_by_default(self):
        out = self.make('server-install')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('SERVER=root@staging', out.stdout)

    def test_install_on_production_needs_force(self):
        out = self.make('server-install', TARGET='prod')
        self.assertNotEqual(out.returncode, 0)
        self.assertIn('Production gets releases only', out.stdout + out.stderr)
        out = self.make('server-install', TARGET='prod', FORCE='1')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('SERVER=debian@prod', out.stdout)

    def test_release_goes_to_production_by_default(self):
        out = self.make('server-release', VERSION='1.2.3')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('SERVER=debian@prod', out.stdout)
        self.assertIn('ARGS=1.2.3', out.stdout)
        self.assertIn('TARGET=prod', out.stdout)
        out = self.make('server-release', TARGET='staging')
        self.assertIn('SERVER=root@staging', out.stdout)
        self.assertIn('TARGET=staging', out.stdout)

    def test_pre_release_goes_to_staging_by_default(self):
        # ADR-0069 (#1178): a pre-release never reaches production by default.
        out = self.make('server-release', VERSION='1.3.0-beta.1')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('SERVER=root@staging', out.stdout)
        self.assertIn('TARGET=staging', out.stdout)
        self.assertIn('ARGS=1.3.0-beta.1', out.stdout)
        # An explicit TARGET=prod reaches the deploy script, which refuses it.
        out = self.make('server-release', VERSION='1.3.0-beta.1', TARGET='prod')
        self.assertIn('TARGET=prod', out.stdout)

    def test_other_targets_default_to_production(self):
        out = self.make('server-ssh')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('ARGS=debian@prod', out.stdout)
        out = self.make('server-ssh', TARGET='staging')
        self.assertIn('ARGS=root@staging', out.stdout)

    def test_remote_commands_run_as_root_or_with_sudo(self):
        out = self.make('server-backup')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('sudo -n', out.stdout)
        self.assertIn('/usr/local/bin/setding-backup-now', out.stdout)

    def test_site_goes_to_the_site_server(self):
        out = self.make('server-site', VERSION='1.2.3')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('SERVER_SITE=debian@site', out.stdout)
        self.assertIn('ARGS=1.2.3', out.stdout)

    def test_unknown_target_fails(self):
        out = self.make('server-status', TARGET='production')
        self.assertNotEqual(out.returncode, 0)
        self.assertIn('TARGET must be prod or staging', out.stdout + out.stderr)

    def test_missing_server_is_named(self):
        out = self.make('server-install', SERVER_STAGING='')
        self.assertNotEqual(out.returncode, 0)
        self.assertIn('Set SERVER_STAGING', out.stdout + out.stderr)

    def test_old_variables_are_refused(self):
        for name in ('SERVER', 'SITE_SERVER'):
            out = self.make('server-status', **{name: 'root@old'})
            self.assertNotEqual(out.returncode, 0, name)
            self.assertIn('were renamed', out.stdout + out.stderr)
            out = self.make('server-site', **{name: 'root@old'})
            self.assertNotEqual(out.returncode, 0, name)


if __name__ == '__main__':
    unittest.main()
