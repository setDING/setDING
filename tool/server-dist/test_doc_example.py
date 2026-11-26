"""Tests of tool/server-dist/doc-example.py (ADR-0063 §5)."""

import importlib.util
import pathlib
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
SCRIPT = HERE / 'doc-example.py'
spec = importlib.util.spec_from_file_location('doc_example', SCRIPT)
doc_example = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doc_example)

PAGE = '''# Page

1. A step:

   ```ini title="x.service"
   [Unit]
   Description=example
   ```
'''


class DocExampleTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.docs = pathlib.Path(self.tmp.name)
        (self.docs / 'self-hosting').mkdir()
        (self.docs / 'en' / 'self-hosting').mkdir(parents=True)
        doc_example.DOCS = self.docs

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, de, en):
        (self.docs / 'self-hosting' / 'p.mdx').write_text(de)
        (self.docs / 'en' / 'self-hosting' / 'p.mdx').write_text(en)

    def run_main(self, *args):
        argv, sys.argv = sys.argv, ['doc-example.py', *args]
        try:
            doc_example.main()
        finally:
            sys.argv = argv

    def test_block_without_the_list_indentation(self):
        self.write(PAGE, PAGE)
        self.assertEqual(
            doc_example.block(self.docs / 'self-hosting' / 'p.mdx', 'x.service'),
            '[Unit]\nDescription=example\n')

    def test_languages_must_match(self):
        self.write(PAGE, PAGE.replace('example', 'other'))
        with self.assertRaises(SystemExit) as e:
            self.run_main('p', 'x.service')
        self.assertIn('differs', str(e.exception.code))

    def test_missing_block_fails(self):
        self.write(PAGE, PAGE)
        with self.assertRaises(SystemExit) as e:
            self.run_main('p', 'y.service')
        self.assertIn('expected one code block', str(e.exception.code))

    def test_the_real_examples_exist(self):
        for page, title in (('docker', 'docker-compose.yml'),
                            ('native', 'setding.service'),
                            ('reverse-proxy', 'Caddyfile')):
            out = subprocess.run([sys.executable, str(SCRIPT), page, title],
                                 capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)
            self.assertTrue(out.stdout.strip())


if __name__ == '__main__':
    unittest.main()
