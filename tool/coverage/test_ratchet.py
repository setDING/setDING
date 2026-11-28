"""Tests of ratchet.py (python3 -m unittest test_ratchet, run by make check)."""

import contextlib
import io
import json
import os
import tempfile
import unittest

import ratchet


def config(minimum, **kw):
    c = {
        "tolerance": 0.1,
        "raise_hint": 1.0,
        "parts": {"app": {"lcov": "app/coverage/lcov.info", "dir": "app"}},
        "areas": [{"name": "sync", "part": "app", "paths": ["lib/sync/"], "minimum": minimum}],
    }
    c.update(kw)
    return c


# 3 of 4 lines of lib/sync/ hit: 75 %. lib/ui/ does not belong to the area.
FILES = {
    "lib/sync/a.dart": {1: 1, 2: 1},
    "lib/sync/engine/b.dart": {1: 2, 2: 0},
    "lib/ui/c.dart": {1: 0, 2: 0, 3: 0},
}
ALL = sorted(FILES)


def status(minimum, files=FILES, all_files=ALL):
    return ratchet.evaluate(config(minimum), {"app": (files, all_files)})[0]


class EvaluateTest(unittest.TestCase):
    def test_area_counts_only_its_files(self):
        r = status(75.0)
        self.assertEqual((r["hit"], r["found"], r["actual"]), (3, 4, 75.0))
        self.assertEqual(r["status"], "ok")

    def test_single_file_area(self):
        c = config(0)
        c["areas"][0]["paths"] = ["lib/sync/a.dart"]
        r = ratchet.evaluate(c, {"app": (FILES, ALL)})[0]
        self.assertEqual((r["hit"], r["found"]), (2, 2))

    def test_drop_below_minimum_fails(self):
        self.assertEqual(status(76.0)["status"], "drop")

    def test_rounding_within_tolerance_passes(self):
        self.assertEqual(status(75.1)["status"], "ok")
        self.assertEqual(status(75.11)["status"], "drop")

    def test_rise_of_more_than_the_hint_asks_to_raise(self):
        self.assertEqual(status(74.0)["status"], "ok")
        r = status(73.9)
        self.assertEqual(r["status"], "raise")
        self.assertIn("raise its minimum", ratchet.message(r))
        self.assertIn("75.0", ratchet.message(r))

    def test_file_no_test_loads_fails(self):
        r = status(75.0, all_files=ALL + ["lib/sync/new.dart"])
        self.assertEqual(r["status"], "unloaded")
        self.assertIn("lib/sync/new.dart", ratchet.message(r))

    def test_area_without_lines_fails(self):
        self.assertEqual(status(0.0, files={}, all_files=[])["status"], "empty")


class FloorTest(unittest.TestCase):
    def test_rounds_down_to_one_decimal(self):
        self.assertEqual(ratchet.floor1(82.97), 82.9)
        self.assertEqual(ratchet.floor1(82.9), 82.9)


class MainTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.root, "app/coverage"))
        os.makedirs(os.path.join(self.root, "app/lib/sync"))
        with open(os.path.join(self.root, "app/lib/sync/a.dart"), "w") as f:
            f.write("int a() => 1;\n")
        with open(os.path.join(self.root, "app/coverage/lcov.info"), "w") as f:
            f.write("SF:lib/sync/a.dart\nDA:1,1\nDA:2,0\nend_of_record\n")
        self.ratchet = os.path.join(self.root, "ratchet.json")
        self.summary = os.path.join(self.root, "summary.md")

    def run_main(self, minimum):
        with open(self.ratchet, "w") as f:
            json.dump(config(minimum), f)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ratchet.main(["--ratchet", self.ratchet, "--root", self.root,
                                 "--markdown", self.summary])
        return code, out.getvalue()

    def test_passes_and_writes_markdown(self):
        code, out = self.run_main(50.0)
        self.assertEqual(code, 0)
        self.assertIn("Ratchet passed.", out)
        with open(self.summary) as f:
            md = f.read()
        self.assertIn("## Coverage ratchet", md)
        self.assertIn("| sync | 50.0 % | 50.0 % | 1/2 | ok |", md)

    def test_drop_exits_non_zero(self):
        code, out = self.run_main(60.0)
        self.assertEqual(code, 1)
        self.assertIn("Ratchet failed: sync", out)
        with open(self.summary) as f:
            self.assertIn("**DROPPED", f.read())

    def test_missing_lcov_asks_for_make_coverage(self):
        os.remove(os.path.join(self.root, "app/coverage/lcov.info"))
        with self.assertRaises(SystemExit) as raised:
            self.run_main(50.0)
        self.assertIn("make coverage", str(raised.exception))


class CheckedInRatchetTest(unittest.TestCase):
    def test_areas_name_existing_paths(self):
        with open(ratchet.DEFAULT_RATCHET, encoding="utf-8") as f:
            c = json.load(f)
        self.assertTrue(c["areas"])
        for area in c["areas"]:
            part = c["parts"][area["part"]]
            for path in area["paths"]:
                full = os.path.join(ratchet.DEFAULT_ROOT, part["dir"], path)
                self.assertTrue(os.path.exists(full), full)
            self.assertIsInstance(area["minimum"], (int, float))


if __name__ == "__main__":
    unittest.main()
