"""Tests of test_report.py (python3 -m unittest test_test_report, run by make check)."""

import json
import unittest

import test_report


def events(*items):
    return [json.dumps(e) for e in items]


REPORT = events(
    {"type": "start", "time": 0},
    {"type": "suite", "suite": {"id": 0, "path": "test/a_test.dart"}},
    # A hidden loading entry that worked is not a test.
    {"type": "testStart", "test": {"id": 1, "name": "loading test/a_test.dart", "suiteID": 0}, "time": 0},
    {"type": "testDone", "testID": 1, "result": "success", "hidden": True, "skipped": False, "time": 50},
    {"type": "testStart", "test": {"id": 2, "name": "adds", "suiteID": 0}, "time": 100},
    {"type": "testDone", "testID": 2, "result": "success", "hidden": False, "skipped": False, "time": 300},
    {"type": "testStart", "test": {"id": 3, "name": "fails", "suiteID": 0}, "time": 300},
    {"type": "error", "testID": 3, "error": "Expected: 1\n  Actual: 2", "stackTrace": "", "isFailure": True, "time": 400},
    {"type": "testDone", "testID": 3, "result": "failure", "hidden": False, "skipped": False, "time": 2300},
    {"type": "testStart", "test": {"id": 4, "name": "later", "suiteID": 0}, "time": 2300},
    {"type": "testDone", "testID": 4, "result": "success", "hidden": False, "skipped": True, "time": 2300},
    {"type": "testStart", "test": {"id": 5, "name": "killed", "suiteID": 0}, "time": 2400},
    {"type": "done", "success": False, "time": 9000},
)


class ParseTest(unittest.TestCase):
    def test_results_suites_and_errors(self):
        tests = {t["name"]: t for t in test_report.parse(REPORT)}
        self.assertNotIn("loading test/a_test.dart", tests)
        self.assertEqual(tests["adds"]["result"], "passed")
        self.assertEqual(tests["adds"]["ms"], 200)
        self.assertEqual(tests["fails"]["result"], "failed")
        self.assertEqual(tests["fails"]["suite"], "test/a_test.dart")
        self.assertIn("Expected: 1", tests["fails"]["error"])
        self.assertEqual(tests["later"]["result"], "skipped")

    def test_an_unfinished_test_counts_as_failed(self):
        tests = {t["name"]: t for t in test_report.parse(REPORT)}
        self.assertEqual(tests["killed"]["result"], "failed")
        self.assertEqual(tests["killed"]["error"], "did not finish")

    def test_a_suite_that_fails_to_load_is_reported(self):
        report = events(
            {"type": "suite", "suite": {"id": 0, "path": "test/b_test.dart"}},
            {"type": "testStart", "test": {"id": 1, "name": "loading test/b_test.dart", "suiteID": 0}, "time": 0},
            {"type": "error", "testID": 1, "error": "Compilation failed", "time": 10},
            {"type": "testDone", "testID": 1, "result": "error", "hidden": True, "skipped": False, "time": 20},
        )
        (test,) = test_report.parse(report)
        self.assertEqual(test["result"], "failed")
        self.assertEqual(test["error"], "Compilation failed")

    def test_lines_that_are_not_json_are_ignored(self):
        self.assertEqual(test_report.parse(["", "not json", "{}"]), [])


class MarkdownTest(unittest.TestCase):
    def test_counts_failures_and_slowest(self):
        text = test_report.markdown([("app", test_report.parse(REPORT))], slowest=2)
        self.assertIn("| app ❌ | 1 | 2 | 1 |", text)
        self.assertIn("| **Total** | **1** | **2** | **1** |", text)
        self.assertIn("- **app**: fails (`test/a_test.dart`)", text)
        self.assertIn("`Expected: 1 Actual: 2`", text)
        slowest = text.split("Slowest tests")[1]
        self.assertIn("| 2.0 s | app | fails |", slowest)
        self.assertNotIn("later", slowest)

    def test_a_green_run_has_no_failure_section(self):
        passed = [t for t in test_report.parse(REPORT) if t["result"] == "passed"]
        text = test_report.markdown([("server", passed)])
        self.assertIn("| server | 1 | 0 | 0 |", text)
        self.assertNotIn("Failed tests", text)


if __name__ == "__main__":
    unittest.main()
