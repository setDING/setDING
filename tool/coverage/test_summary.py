"""Tests of summary.py (python3 -m unittest test_summary, run by make check)."""

import contextlib
import io
import os
import tempfile
import unittest

import summary


class ParseLcovTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def test_paths_become_relative_and_entries_merge(self):
        text = (
            "SF:%s/lib/a.dart\nDA:1,0\nDA:2,3\nend_of_record\n"
            "SF:lib/a.dart\nDA:1,1\nDA:3,0\nend_of_record\n" % self.dir
        )
        files = summary.parse_lcov(text, self.dir)
        self.assertEqual(files, {"lib/a.dart": {1: 1, 2: 3, 3: 0}})

    def test_generated_and_outside_files_are_dropped(self):
        text = (
            "SF:lib/data/database.g.dart\nDA:1,0\nend_of_record\n"
            "SF:lib/l10n/generated/app_localizations_de.dart\nDA:1,0\nend_of_record\n"
            "SF:/elsewhere/lib/b.dart\nDA:1,0\nend_of_record\n"
            "SF:lib/l10n/strings.dart\nDA:1,1\nend_of_record\n"
        )
        files = summary.parse_lcov(text, self.dir)
        self.assertEqual(list(files), ["lib/l10n/strings.dart"])


class SummarizeTest(unittest.TestCase):
    def test_reports_total_lowest_and_not_loaded_files(self):
        files = {
            "lib/good.dart": {1: 1, 2: 1, 3: 1, 4: 1},
            "lib/bad.dart": {1: 1, 2: 0, 3: 0, 4: 0},
        }
        all_files = ["lib/bad.dart", "lib/good.dart", "lib/unused.dart"]
        text = "\n".join(summary.summarize("app", files, all_files, lowest=1))
        self.assertIn("62.5 %  5/8 lines in 2 files, 1 files not loaded", text)
        self.assertIn("25.0 %     1/4     lib/bad.dart", text)
        self.assertNotIn("lib/good.dart", text)
        self.assertIn("    lib/unused.dart", text)

    def test_main_reads_lcov_and_library_files(self):
        root = tempfile.mkdtemp()
        os.makedirs(os.path.join(root, "lib", "src"))
        for name in ("lib/x.dart", "lib/src/y.dart", "lib/src/y.g.dart"):
            with open(os.path.join(root, name), "w") as f:
                f.write("int f() => 1;\n")
        with open(os.path.join(root, "lib", "all.dart"), "w") as f:
            f.write("/// Exports.\nlibrary;\n\nexport 'x.dart';\nexport 'src/y.dart'\n    show f;\n")
        with open(os.path.join(root, "lib", "roles.dart"), "w") as f:
            f.write("enum Role { admin, member }\n\nenum Mode {\n  a,\n\n  b,\n}\n")
        with open(os.path.join(root, "lib", "rich.dart"), "w") as f:
            f.write("enum Rich { a(1); const Rich(this.v); final int v; }\n")
        lcov = os.path.join(root, "lcov.info")
        with open(lcov, "w") as f:
            f.write("SF:lib/x.dart\nDA:1,1\nDA:2,0\nend_of_record\n")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            summary.main(["--part", "pkg", lcov, root])
        self.assertIn("pkg         50.0 %  1/2 lines in 1 files, 2 files", out.getvalue())
        self.assertIn("    lib/src/y.dart", out.getvalue())
        self.assertNotIn("y.g.dart", out.getvalue())
        self.assertNotIn("all.dart", out.getvalue())
        self.assertNotIn("roles.dart", out.getvalue())
        self.assertIn("    lib/rich.dart", out.getvalue())

    def test_markdown_lists_parts_areas_and_lowest_files(self):
        files = {
            "lib/sync/engine/a.dart": {1: 1, 2: 0},
            "lib/sync/b.dart": {1: 1, 2: 1},
            "lib/main.dart": {1: 0, 2: 0},
        }
        all_files = sorted(files) + ["lib/ui/unused.dart"]
        text = summary.markdown([("app", files, all_files)], lowest=1)
        self.assertIn("| app | 50.0 % | 3/6 | 3 | 1 |", text)
        self.assertIn("| sync | 75.0 % | 3/4 |", text)
        self.assertIn("| lib | 0.0 % | 0/2 |", text)
        # Lowest area first.
        self.assertLess(text.index("| lib |"), text.index("| sync |"))
        self.assertIn("| 0.0 % | 0/2 | `lib/main.dart` |", text)
        self.assertNotIn("`lib/sync/b.dart`", text)
        self.assertIn("Not loaded by any test: `lib/ui/unused.dart`", text)

    def test_main_appends_markdown_to_a_file(self):
        root = tempfile.mkdtemp()
        os.makedirs(os.path.join(root, "lib"))
        with open(os.path.join(root, "lib", "x.dart"), "w") as f:
            f.write("int f() => 1;\n")
        lcov = os.path.join(root, "lcov.info")
        with open(lcov, "w") as f:
            f.write("SF:lib/x.dart\nDA:1,1\nend_of_record\n")
        target = os.path.join(root, "summary.md")
        with open(target, "w") as f:
            f.write("## Tests\n")
        with contextlib.redirect_stdout(io.StringIO()):
            summary.main(["--part", "pkg", lcov, root, "--markdown", target])
        with open(target) as f:
            text = f.read()
        self.assertTrue(text.startswith("## Tests\n## Line coverage"))
        self.assertIn("| pkg | 100.0 % | 1/1 | 1 | 0 |", text)


if __name__ == "__main__":
    unittest.main()
