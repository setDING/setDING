"""Tests of tool/server-dist/previous-bundle.sh (#1073).

Release v0.22.0 published the rebuilt 0.21.0 bundles: the script wrote them to
the caller's OUT (the release's own bundles). It must use PREVIOUS_OUT only.
"""

import os
import pathlib
import subprocess
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SCRIPT = HERE / 'previous-bundle.sh'
TAG = 'v0.21.0'


def has_tag(tag):
    return subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '-q', '--verify',
                           f'refs/tags/{tag}'], capture_output=True).returncode == 0


@unittest.skipUnless(has_tag(TAG), f'needs the tag {TAG}')
class PreviousBundleTest(unittest.TestCase):
    def test_the_callers_out_stays_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = pathlib.Path(tmp) / 'release'
            previous = pathlib.Path(tmp) / 'previous'
            out.mkdir()
            env = {**os.environ, 'OUT': str(out), 'PREVIOUS_OUT': str(previous),
                   'PREVIOUS': TAG, 'ARCH': 'amd64',
                   # No GitHub access: always the bundle built from the tag.
                   'PATH': os.environ['PATH'], 'GH_TOKEN': 'invalid'}
            run = subprocess.run([str(SCRIPT)], capture_output=True, text=True, env=env)
            self.assertEqual(run.returncode, 0, run.stderr)
            printed = pathlib.Path(run.stdout.strip().splitlines()[-1])
            self.assertEqual(printed.parent, previous)
            self.assertTrue(printed.name.startswith('setding-server-0.21.0-linux-amd64'))
            self.assertTrue(printed.exists())
            self.assertEqual(list(out.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
