#!/usr/bin/env python3
"""Summarizes the JSON test reports of tool/check.sh as Markdown (#1249).

tool/check.sh writes one report per test run when TEST_REPORT_DIR is set
(`dart test` / `flutter test --file-reporter json:<file>`). The nightly CI
workflow appends this summary to the run's page ($GITHUB_STEP_SUMMARY): per
report the passed, failed and skipped tests, the failures with their error,
and the slowest tests.

Usage:
  test_report.py REPORT.json [REPORT.json ...] [--slowest N]
"""

import argparse
import json
import os
import sys


def parse(lines):
    """Returns the tests of one JSON report: a list of dicts with name, suite,
    result ('passed', 'failed', 'skipped'), ms and error.

    Hidden entries (setUpAll/tearDownAll and loading a suite that worked) are
    left out; a suite that failed to load counts as a failed test.
    """
    suites = {}
    tests = {}
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except ValueError:
            continue
        kind = event.get("type")
        if kind == "suite":
            suites[event["suite"]["id"]] = event["suite"].get("path") or ""
        elif kind == "testStart":
            t = event["test"]
            tests[t["id"]] = {
                "name": t.get("name", ""),
                "suite": suites.get(t.get("suiteID"), ""),
                "start": event.get("time", 0),
                "result": None,
                "ms": 0,
                "error": "",
                "hidden": False,
            }
        elif kind == "error" and event.get("testID") in tests:
            t = tests[event["testID"]]
            if not t["error"]:
                t["error"] = event.get("error", "")
        elif kind == "testDone" and event.get("testID") in tests:
            t = tests[event["testID"]]
            t["ms"] = event.get("time", 0) - t["start"]
            t["hidden"] = bool(event.get("hidden"))
            if event.get("skipped"):
                t["result"] = "skipped"
            elif event.get("result") == "success":
                t["result"] = "passed"
            else:
                t["result"] = "failed"
    result = []
    for t in tests.values():
        if t["result"] is None:
            # Started but never finished: the run was killed (e.g. a timeout).
            t["result"] = "failed"
            t["error"] = t["error"] or "did not finish"
        if t["hidden"] and t["result"] != "failed":
            continue
        result.append(t)
    return result


def seconds(ms):
    return "%.1f s" % (ms / 1000.0)


def one_line(text, limit=300):
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def markdown(reports, slowest=10):
    """reports: list of (name, tests). Returns the Markdown summary."""
    out = ["## Tests", "", "| Run | Passed | Failed | Skipped |", "|---|---:|---:|---:|"]
    totals = [0, 0, 0]
    for name, tests in reports:
        counts = [sum(1 for t in tests if t["result"] == r) for r in ("passed", "failed", "skipped")]
        totals = [a + b for a, b in zip(totals, counts)]
        mark = " ❌" if counts[1] else ""
        out.append("| %s%s | %d | %d | %d |" % (name, mark, *counts))
    out.append("| **Total** | **%d** | **%d** | **%d** |" % tuple(totals))
    failed = [(name, t) for name, tests in reports for t in tests if t["result"] == "failed"]
    if failed:
        out += ["", "### Failed tests", ""]
        for name, t in failed:
            where = " (`%s`)" % t["suite"] if t["suite"] else ""
            out.append("- **%s**: %s%s" % (name, t["name"], where))
            if t["error"]:
                out.append("  <br>`%s`" % one_line(t["error"]).replace("`", "'"))
    timed = sorted(
        ((t["ms"], name, t) for name, tests in reports for t in tests if t["result"] != "skipped"),
        key=lambda item: -item[0],
    )[:slowest]
    if timed:
        out += ["", "<details><summary>Slowest tests</summary>", "",
                "| Time | Run | Test |", "|---:|---|---|"]
        for ms, name, t in timed:
            out.append("| %s | %s | %s |" % (seconds(ms), name, t["name"].replace("|", "\\|")))
        out += ["", "</details>"]
    return "\n".join(out) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("reports", nargs="+")
    parser.add_argument("--slowest", type=int, default=10)
    args = parser.parse_args(argv)
    reports = []
    for path in sorted(args.reports):
        with open(path, encoding="utf-8") as f:
            reports.append((os.path.splitext(os.path.basename(path))[0], parse(f)))
    sys.stdout.write(markdown(reports, args.slowest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
