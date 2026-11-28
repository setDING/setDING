#!/usr/bin/env python3
"""Summarizes lcov reports of the Dart tests (make coverage, issue #640).

For each part (e.g. the app or the ChordPro package) it prints the line
coverage, the least covered files and the library files that no test loads at
all: those are missing from the lcov report, so a plain lcov total would
overstate the coverage.

Usage:
  summary.py --part NAME LCOV_FILE PACKAGE_DIR [--part ...] [--lowest N]
             [--markdown FILE]

Generated code (*.g.dart, the l10n output) is left out.
"""

import argparse
import fnmatch
import os
import re
import sys

# Generated files: their coverage says nothing about the tests.
EXCLUDED = ("*.g.dart", "*.freezed.dart", "lib/l10n/generated/*")


def excluded(rel_path):
    return any(fnmatch.fnmatch(rel_path, pattern) for pattern in EXCLUDED)


def parse_lcov(text, package_dir):
    """Returns {path relative to package_dir: {line: hits}}.

    Entries of the same file are merged (a line counts as hit if any entry hit
    it). Files outside package_dir and generated files are dropped.
    """
    package_dir = os.path.abspath(package_dir)
    files = {}
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("SF:"):
            path = line[3:]
            if not os.path.isabs(path):
                path = os.path.join(package_dir, path)
            rel = os.path.relpath(os.path.normpath(path), package_dir)
            if rel.startswith("..") or excluded(rel):
                current = None
            else:
                current = files.setdefault(rel, {})
        elif line.startswith("DA:") and current is not None:
            number, hits = line[3:].split(",")[:2]
            number, hits = int(number), int(hits)
            current[number] = max(current.get(number, 0), hits)
        elif line == "end_of_record":
            current = None
    return files


# Statements that hold no executable code: a file of only these and simple
# enums (e.g. a library of exports) never appears in an lcov report.
DIRECTIVES = ("export ", "import ", "library", "part ")
SIMPLE_ENUM = re.compile(r"\benum\s+\w+\s*\{[^;(){}]*\}")


def has_code(path):
    with open(path, encoding="utf-8") as f:
        lines = [raw.strip() for raw in f]
    code = " ".join(line for line in lines if not line.startswith(("//", "/*", "*")))
    code = SIMPLE_ENUM.sub(";", code)
    statements = [s.strip() for s in code.split(";")]
    return any(s and not s.startswith(DIRECTIVES) for s in statements)


def library_files(package_dir):
    """Dart files with code under lib/, relative to package_dir, without generated ones."""
    result = []
    lib = os.path.join(package_dir, "lib")
    for root, _, names in os.walk(lib):
        for name in names:
            if name.endswith(".dart"):
                rel = os.path.relpath(os.path.join(root, name), package_dir)
                if not excluded(rel) and has_code(os.path.join(package_dir, rel)):
                    result.append(rel)
    return sorted(result)


def percent(hit, found):
    return 100.0 * hit / found if found else 100.0


def summarize(name, files, all_files, lowest):
    lines = []
    found = sum(len(f) for f in files.values())
    hit = sum(1 for f in files.values() for h in f.values() if h > 0)
    not_loaded = [p for p in all_files if p not in files]
    lines.append(
        "%-10s %5.1f %%  %d/%d lines in %d files, %d files not loaded by any test"
        % (name, percent(hit, found), hit, found, len(files), len(not_loaded))
    )
    ranked = sorted(
        (
            (percent(sum(1 for h in f.values() if h > 0), len(f)), len(f), path, f)
            for path, f in files.items()
            if f
        ),
        key=lambda item: (item[0], -item[1], item[2]),
    )
    if ranked and lowest > 0:
        lines.append("  Least covered files:")
        for pct, total, path, f in ranked[:lowest]:
            covered = sum(1 for h in f.values() if h > 0)
            lines.append("    %5.1f %%  %4d/%-4d  %s" % (pct, covered, total, path))
    if not_loaded:
        lines.append("  Not loaded by any test (0 %, not in the total above):")
        lines.extend("    %s" % path for path in not_loaded)
    return lines


def area(path):
    """The area of a file for the Markdown summary: its first folder below
    lib/ (lib/sync/engine/x.dart -> sync), or lib for files directly in it."""
    parts = path.split(os.sep)
    return parts[1] if len(parts) > 2 and parts[0] == "lib" else parts[0]


def markdown(parts, lowest):
    """parts: list of (name, files, all_files). The Markdown summary for the
    nightly CI run's page (#1249): each part, its areas and the least covered
    files."""
    out = [
        "## Line coverage",
        "",
        "Report only, no threshold; the critical areas have a minimum (coverage ratchet, "
        "[coverage.md](docs/development/coverage.md)).",
        "",
        "| Part | Coverage | Lines | Files | Not loaded by any test |",
        "|---|---:|---:|---:|---:|",
    ]
    for name, files, all_files in parts:
        found = sum(len(f) for f in files.values())
        hit = sum(1 for f in files.values() for h in f.values() if h > 0)
        not_loaded = [p for p in all_files if p not in files]
        out.append(
            "| %s | %.1f %% | %d/%d | %d | %d |"
            % (name, percent(hit, found), hit, found, len(files), len(not_loaded))
        )
    for name, files, all_files in parts:
        areas = {}
        for path, f in files.items():
            a = areas.setdefault(area(path), [0, 0])
            a[0] += sum(1 for h in f.values() if h > 0)
            a[1] += len(f)
        out += ["", "<details><summary>%s by area</summary>" % name, "",
                "| Area | Coverage | Lines |", "|---|---:|---:|"]
        for a, (hit, found) in sorted(areas.items(), key=lambda item: percent(*item[1])):
            out.append("| %s | %.1f %% | %d/%d |" % (a, percent(hit, found), hit, found))
        ranked = sorted(
            (
                (percent(sum(1 for h in f.values() if h > 0), len(f)), len(f), path, f)
                for path, f in files.items()
                if f
            ),
            key=lambda item: (item[0], -item[1], item[2]),
        )[:lowest]
        if ranked:
            out += ["", "Least covered files:", "", "| Coverage | Lines | File |", "|---:|---:|---|"]
            for pct, total, path, f in ranked:
                covered = sum(1 for h in f.values() if h > 0)
                out.append("| %.1f %% | %d/%d | `%s` |" % (pct, covered, total, path))
        not_loaded = [p for p in all_files if p not in files]
        if not_loaded:
            out += ["", "Not loaded by any test: " + ", ".join("`%s`" % p for p in not_loaded)]
        out += ["", "</details>"]
    return "\n".join(out) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--part",
        nargs=3,
        action="append",
        required=True,
        metavar=("NAME", "LCOV_FILE", "PACKAGE_DIR"),
    )
    parser.add_argument("--lowest", type=int, default=15)
    parser.add_argument(
        "--markdown",
        metavar="FILE",
        help="also append a Markdown summary to FILE (e.g. $GITHUB_STEP_SUMMARY)",
    )
    args = parser.parse_args(argv)
    output = ["Line coverage (report only; make coverage-ratchet checks the critical areas):"]
    parts = []
    for name, lcov, package_dir in args.part:
        with open(lcov, encoding="utf-8") as f:
            files = parse_lcov(f.read(), package_dir)
        all_files = library_files(package_dir)
        parts.append((name, files, all_files))
        output.append("")
        output.extend(summarize(name, files, all_files, args.lowest))
    print("\n".join(output))
    if args.markdown:
        with open(args.markdown, "a", encoding="utf-8") as f:
            f.write(markdown(parts, args.lowest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
