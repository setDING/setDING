#!/usr/bin/env python3
"""Coverage ratchet of the critical areas (make coverage-ratchet, issue #1247).

Reads the lcov reports that make coverage wrote and compares the line coverage
of each area in ratchet.json (sync, permission checks, import/backup, the
ChordPro package) with its checked-in minimum:

- below the minimum (minus the tolerance for rounding): the check fails;
- a library file of the area that no test loads at all: the check fails too
  (it is missing from the lcov report, so it would not lower the percentage);
- more than `raise_hint` points above the minimum: a hint to raise the value in
  ratchet.json (the check does not fail for that).

Lowering a minimum is an owner decision (docs/development/coverage.md).

Usage:
  ratchet.py [--ratchet FILE] [--root DIR] [--markdown FILE]
"""

import argparse
import json
import os
import sys

import summary

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
DEFAULT_RATCHET = os.path.join(HERE, "ratchet.json")


def in_area(path, paths):
    """Whether path (relative to the part's folder) belongs to an area: it is
    one of the files or lies below one of the folders (ending in /)."""
    return any(path == p or (p.endswith("/") and path.startswith(p)) for p in paths)


def measure(area, files, all_files):
    """Returns (percent, hit, found, not_loaded) of an area."""
    paths = area["paths"]
    selected = [f for path, f in files.items() if in_area(path, paths)]
    found = sum(len(f) for f in selected)
    hit = sum(1 for f in selected for h in f.values() if h > 0)
    not_loaded = [p for p in all_files if in_area(p, paths) and p not in files]
    return summary.percent(hit, found), hit, found, not_loaded


def evaluate(config, parts):
    """config: the parsed ratchet.json; parts: {name: (files, all_files)}.

    Returns a list of results, one per area: dict with name, minimum, actual,
    hit, found, not_loaded and status (ok, raise, drop, unloaded, empty).
    """
    tolerance = config.get("tolerance", 0.1)
    raise_hint = config.get("raise_hint", 1.0)
    results = []
    for area in config["areas"]:
        files, all_files = parts[area["part"]]
        actual, hit, found, not_loaded = measure(area, files, all_files)
        minimum = area["minimum"]
        if found == 0:
            status = "empty"  # no measured line: a wrong path or no tests
        elif actual < minimum - tolerance:
            status = "drop"
        elif not_loaded:
            status = "unloaded"
        elif actual > minimum + raise_hint:
            status = "raise"
        else:
            status = "ok"
        results.append(dict(name=area["name"], minimum=minimum, actual=actual,
                            hit=hit, found=found, not_loaded=not_loaded,
                            status=status))
    return results


FAILED = ("drop", "unloaded", "empty")

MESSAGE = {
    "ok": "ok",
    "raise": "went up: raise its minimum in tool/coverage/ratchet.json to %.1f",
    "drop": "DROPPED below its minimum: add tests (lowering it is an owner decision)",
    "unloaded": "FILES NOT LOADED by any test: %s",
    "empty": "NO MEASURED LINES: check the area's paths in ratchet.json",
}


def message(result):
    status = result["status"]
    if status == "raise":
        return MESSAGE[status] % floor1(result["actual"])
    if status == "unloaded":
        return MESSAGE[status] % ", ".join(result["not_loaded"])
    return MESSAGE[status]


def floor1(value):
    """value rounded down to one decimal: the value to put into ratchet.json."""
    return int(value * 10 + 1e-9) / 10


def text(results):
    lines = ["Coverage ratchet (tool/coverage/ratchet.json):", ""]
    for r in results:
        lines.append("  %-16s %5.1f %% (minimum %5.1f %%, %d/%d lines)  %s"
                     % (r["name"], r["actual"], r["minimum"], r["hit"], r["found"],
                        message(r)))
    failed = [r["name"] for r in results if r["status"] in FAILED]
    lines.append("")
    lines.append("Ratchet failed: %s" % ", ".join(failed) if failed else "Ratchet passed.")
    return "\n".join(lines)


def markdown(results):
    out = [
        "## Coverage ratchet",
        "",
        "Minimum line coverage of the critical areas "
        "([ratchet.json](tool/coverage/ratchet.json), "
        "[coverage.md](docs/development/coverage.md)).",
        "",
        "| Area | Coverage | Minimum | Lines | Result |",
        "|---|---:|---:|---:|---|",
    ]
    for r in results:
        result = message(r)
        if r["status"] in FAILED:
            result = "**%s**" % result
        out.append("| %s | %.1f %% | %.1f %% | %d/%d | %s |"
                   % (r["name"], r["actual"], r["minimum"], r["hit"], r["found"], result))
    return "\n".join(out) + "\n"


def load_parts(config, root):
    parts = {}
    for name, part in config["parts"].items():
        package_dir = os.path.join(root, part["dir"])
        lcov = os.path.join(root, part["lcov"])
        if not os.path.exists(lcov):
            raise SystemExit("%s is missing: run make coverage first" % lcov)
        with open(lcov, encoding="utf-8") as f:
            files = summary.parse_lcov(f.read(), package_dir)
        parts[name] = (files, summary.library_files(package_dir))
    return parts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ratchet", default=DEFAULT_RATCHET)
    parser.add_argument("--root", default=DEFAULT_ROOT,
                        help="repository root the paths in the ratchet file are relative to")
    parser.add_argument("--markdown", metavar="FILE",
                        help="also append a Markdown summary to FILE (e.g. $GITHUB_STEP_SUMMARY)")
    args = parser.parse_args(argv)
    with open(args.ratchet, encoding="utf-8") as f:
        config = json.load(f)
    results = evaluate(config, load_parts(config, args.root))
    print(text(results))
    if args.markdown:
        with open(args.markdown, "a", encoding="utf-8") as f:
            f.write(markdown(results))
    return 1 if any(r["status"] in FAILED for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
