#!/usr/bin/env python3
"""CHANGELOG.md tool: the changelog is the source of the GitHub Release notes.

  changelog.py check [--version X.Y.Z]   validate the format (make check); with
                                         --version, that version needs a section
  changelog.py notes X.Y.Z               print the release notes of a version
                                         (release.yml publishes them)
  changelog.py draft [--since vX.Y.Z]    group the commits since the last tag by
                                         Keep a Changelog category, as a starting
                                         point for the section in a release PR

Format: Keep a Changelog 1.1.0 (https://keepachangelog.com/en/1.1.0/), see
docs/development/releases.md#changelog. Standard library only.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FILE = ROOT / "CHANGELOG.md"
REPO_URL = "https://github.com/tafli/setDING"

# "Update required" comes first when devices must be updated (releases.md);
# the others are the Keep a Changelog categories in their recommended order.
CATEGORIES = [
    "Update required",
    "Added",
    "Changed",
    "Deprecated",
    "Removed",
    "Fixed",
    "Security",
]

VERSION = r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?"
RELEASE_HEADING = re.compile(rf"^## \[({VERSION})\] - (\d{{4}}-\d{{2}}-\d{{2}})$")
UNRELEASED_HEADING = re.compile(r"^## \[Unreleased\]$")
LINK = re.compile(r"^\[([^\]]+)\]: (\S+)$")


class ChangelogError(Exception):
    pass


@dataclass
class Section:
    name: str  # version or "Unreleased"
    date: str | None
    line: int
    body: list[str] = field(default_factory=list)


@dataclass
class Changelog:
    sections: list[Section]
    links: dict[str, str]

    def section(self, version: str) -> Section | None:
        return next((s for s in self.sections if s.name == version), None)


def version_key(version: str) -> tuple:
    core, _, pre = version.partition("-")
    # A pre-release sorts before its release (1.0.0-beta.1 < 1.0.0).
    return tuple(int(p) for p in core.split(".")) + ((0, pre) if pre else (1, ""))


def parse(text: str) -> Changelog:
    """Parses and validates a changelog; raises ChangelogError on the first problem."""
    lines = text.splitlines()
    if not lines or lines[0] != "# Changelog":
        raise ChangelogError("line 1: must be '# Changelog'")

    sections: list[Section] = []
    links: dict[str, str] = {}
    current: Section | None = None
    for number, line in enumerate(lines, start=1):
        if line.startswith("## "):
            if links:
                raise ChangelogError(f"line {number}: section after the link definitions")
            match = RELEASE_HEADING.match(line)
            if match:
                current = Section(match.group(1), match.group(2), number)
            elif UNRELEASED_HEADING.match(line):
                if sections:
                    raise ChangelogError(f"line {number}: [Unreleased] must be the first section")
                current = Section("Unreleased", None, number)
            else:
                raise ChangelogError(
                    f"line {number}: expected '## [X.Y.Z] - YYYY-MM-DD' or '## [Unreleased]'"
                )
            sections.append(current)
            continue
        match = LINK.match(line)
        if match and current is not None:
            links[match.group(1)] = match.group(2)
            continue
        if links and line.strip():
            raise ChangelogError(f"line {number}: only link definitions may follow them")
        if current is not None:
            current.body.append(line)

    if not sections:
        raise ChangelogError("no version sections")
    for section in sections:
        _check_section(section)
    _check_order(sections)
    for section in sections:
        if section.name not in links:
            raise ChangelogError(f"[{section.name}]: missing link definition at the end")
    unused = set(links) - {s.name for s in sections}
    if unused:
        raise ChangelogError(f"link definitions without a section: {sorted(unused)}")
    return Changelog(sections, links)


def _check_section(section: Section) -> None:
    seen: list[str] = []
    entries = 0
    for offset, line in enumerate(section.body, start=section.line + 1):
        if line.startswith("### "):
            category = line[4:]
            if category not in CATEGORIES:
                raise ChangelogError(
                    f"line {offset}: unknown category '{category}' (allowed: {', '.join(CATEGORIES)})"
                )
            if category in seen:
                raise ChangelogError(f"line {offset}: category '{category}' appears twice")
            if seen and CATEGORIES.index(category) < CATEGORIES.index(seen[-1]):
                raise ChangelogError(
                    f"line {offset}: category '{category}' must come before '{seen[-1]}'"
                )
            seen.append(category)
        elif line.startswith("#"):
            raise ChangelogError(f"line {offset}: only '### <category>' headings inside a version")
        elif line.startswith("- "):
            if not seen:
                raise ChangelogError(f"line {offset}: entry outside a '### <category>'")
            entries += 1
    if section.name != "Unreleased" and entries == 0:
        raise ChangelogError(f"[{section.name}]: no entries")


def _check_order(sections: list[Section]) -> None:
    releases = [s for s in sections if s.name != "Unreleased"]
    for newer, older in zip(releases, releases[1:]):
        if version_key(newer.name) <= version_key(older.name):
            raise ChangelogError(
                f"line {older.line}: [{older.name}] must come after a lower version than "
                f"[{newer.name}] (newest first, each version once)"
            )
        if newer.date < older.date:
            raise ChangelogError(f"line {older.line}: [{older.name}] is dated after [{newer.name}]")


def release_notes(changelog: Changelog, version: str) -> str:
    """The section of a version as GitHub Release notes, with the compare link."""
    section = changelog.section(version)
    if section is None:
        raise ChangelogError(f"CHANGELOG.md has no section [{version}]")
    body = "\n".join(section.body).strip()
    link = changelog.links[version]
    label = "Full Changelog" if "/compare/" in link else "Source"
    return f"{body}\n\n**{label}**: {link}\n"


def pubspec_version(root: Path = ROOT) -> str:
    text = (root / "app" / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version: *([^+\s]+)", text, re.MULTILINE)
    if not match:
        raise ChangelogError("app/pubspec.yaml: no version")
    return match.group(1)


# --- draft ------------------------------------------------------------------

COMMIT = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]*)\))?(?P<breaking>!)?: (?P<subject>.+)$")


def draft(subjects: list[str]) -> str:
    """Groups Conventional Commit subjects by Keep a Changelog category.

    Only a starting point: the release PR rewrites the entries for users and
    drops what is not relevant to them (see releases.md#changelog).
    """
    groups: dict[str, list[str]] = {c: [] for c in CATEGORIES}
    skipped: list[str] = []
    for subject in subjects:
        match = COMMIT.match(subject)
        if not match:
            skipped.append(subject)
            continue
        kind, scope = match.group("type"), match.group("scope") or ""
        text = match.group("subject")
        text = text[0].upper() + text[1:]
        if match.group("breaking"):
            text = f"**Breaking:** {text}"
        if kind == "feat":
            groups["Added"].append(text)
        elif kind == "fix" and scope not in ("ci", "test"):
            groups["Fixed"].append(text)
        elif kind in ("perf", "refactor") or scope == "deps" or match.group("breaking"):
            groups["Changed"].append(text)
        elif kind == "chore" and scope == "release":
            continue
        else:
            skipped.append(subject)
    out = []
    for category, entries in groups.items():
        if entries:
            out.append(f"### {category}\n")
            out.extend(f"- {e}" for e in entries)
            out.append("")
    if skipped:
        out.append("<!-- Probably not relevant to users, check:")
        out.extend(f"  {s}" for s in skipped)
        out.append("-->")
    text = "\n".join(out).rstrip() + "\n"
    return re.sub(r"#(\d+)\b", rf"[#\1]({REPO_URL}/pull/\1)", text)


def _git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], check=True, capture_output=True, text=True
    ).stdout


# --- CLI --------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--file", type=Path, default=DEFAULT_FILE)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("check", help="validate CHANGELOG.md")
    check.add_argument("--version", help="require a section for this version ('pubspec': app/pubspec.yaml)")
    notes = commands.add_parser("notes", help="print the release notes of a version")
    notes.add_argument("version")
    draft_cmd = commands.add_parser("draft", help="draft a section from the commits since the last tag")
    draft_cmd.add_argument("--since", help="tag to start from (default: the newest tag)")
    args = parser.parse_args(argv)

    try:
        if args.command == "draft":
            since = args.since or _git("describe", "--tags", "--abbrev=0").strip()
            subjects = _git("log", "--reverse", "--format=%s", f"{since}..HEAD").splitlines()
            print(draft(subjects), end="")
            print(
                "Also add the version's user notes in de-CH and en to "
                "app/assets/whats_new.json (docs/development/releases.md, ADR-0041).",
                file=sys.stderr,
            )
            return 0
        changelog = parse(args.file.read_text(encoding="utf-8"))
        if args.command == "check":
            version = pubspec_version() if args.version == "pubspec" else args.version
            if version and changelog.section(version) is None:
                raise ChangelogError(
                    f"no section [{version}]: a release PR adds it together with the version"
                )
            print(f"changelog: OK ({len(changelog.sections)} sections)")
        else:
            print(release_notes(changelog, args.version.removeprefix("v")), end="")
        return 0
    except ChangelogError as error:
        print(f"{args.file.name}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
