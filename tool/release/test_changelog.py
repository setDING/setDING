"""Tests of changelog.py (run by make check: python3 -m unittest in tool/release)."""

import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path

import changelog
from changelog import ChangelogError, draft, parse, release_notes

URL = "https://github.com/tafli/setDING"

VALID = f"""# Changelog

Intro text.

## [Unreleased]

## [0.2.0] - 2026-11-17

### Update required

- Every device of a band must update

### Added

- Something new ([#3]({URL}/pull/3))

### Fixed

- Something broken

## [0.1.0] - 2026-11-16

### Added

- First release

[Unreleased]: {URL}/compare/v0.2.0...HEAD
[0.2.0]: {URL}/compare/v0.1.0...v0.2.0
[0.1.0]: {URL}/releases/tag/v0.1.0
"""


def mutate(old: str, new: str) -> str:
    assert old in VALID, old
    return VALID.replace(old, new, 1)


class ParseTest(unittest.TestCase):
    def test_valid(self):
        log = parse(VALID)
        self.assertEqual([s.name for s in log.sections], ["Unreleased", "0.2.0", "0.1.0"])

    def test_repository_changelog_is_valid(self):
        log = parse(changelog.DEFAULT_FILE.read_text(encoding="utf-8"))
        self.assertIsNotNone(log.section(changelog.pubspec_version()))

    def assert_invalid(self, text: str, message: str):
        with self.assertRaises(ChangelogError) as error:
            parse(text)
        self.assertIn(message, str(error.exception))

    def test_title(self):
        self.assert_invalid(mutate("# Changelog", "# Changes"), "line 1")

    def test_heading_without_date(self):
        self.assert_invalid(mutate("## [0.1.0] - 2026-11-16", "## [0.1.0]"), "expected")

    def test_unreleased_not_first(self):
        text = mutate("## [Unreleased]\n\n", "").replace(
            "## [0.1.0]", "## [Unreleased]\n\n## [0.1.0]"
        )
        self.assert_invalid(text, "must be the first")

    def test_versions_newest_first(self):
        self.assert_invalid(mutate("[0.2.0] - ", "[0.0.9] - "), "lower version")

    def test_duplicate_version(self):
        text = mutate("[0.2.0] - ", "[0.1.0] - ").replace(f"[0.2.0]: {URL}/compare/v0.1.0...v0.2.0\n", "")
        self.assert_invalid(text, "each version once")

    def test_dates_newest_first(self):
        self.assert_invalid(mutate("2026-11-17", "2026-11-15"), "dated after")

    def test_unknown_category(self):
        self.assert_invalid(mutate("### Fixed", "### Bugfixes"), "unknown category")

    def test_category_order(self):
        text = mutate("### Added\n\n- Something new", "### Fixed\n\n- Something new").replace(
            "### Fixed\n\n- Something broken", "### Added\n\n- Something broken"
        )
        self.assert_invalid(text, "must come before")

    def test_duplicate_category(self):
        self.assert_invalid(mutate("### Fixed", "### Added"), "")

    def test_release_without_entries(self):
        self.assert_invalid(mutate("- First release\n", ""), "[0.1.0]: no entries")

    def test_entry_outside_category(self):
        self.assert_invalid(mutate("Intro text.\n\n## [Unreleased]\n", "## [Unreleased]\n\n- loose\n"), "outside")

    def test_missing_link(self):
        self.assert_invalid(mutate(f"[0.1.0]: {URL}/releases/tag/v0.1.0\n", ""), "missing link")

    def test_unused_link(self):
        self.assert_invalid(VALID + f"[0.0.1]: {URL}\n", "without a section")

    def test_text_after_links(self):
        self.assert_invalid(VALID + "\nMore text\n", "only link definitions")


class NotesTest(unittest.TestCase):
    def test_notes_with_compare_link(self):
        notes = release_notes(parse(VALID), "0.2.0")
        self.assertTrue(notes.startswith("### Update required\n\n- Every device"))
        self.assertIn("- Something broken\n\n**Full Changelog**: " + f"{URL}/compare/v0.1.0...v0.2.0\n", notes)
        self.assertNotIn("0.1.0] -", notes)

    def test_first_release_links_its_source(self):
        notes = release_notes(parse(VALID), "0.1.0")
        self.assertTrue(notes.endswith(f"**Source**: {URL}/releases/tag/v0.1.0\n"))

    def test_missing_version(self):
        with self.assertRaises(ChangelogError):
            release_notes(parse(VALID), "0.3.0")

    def test_cli_notes_accepts_tag(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "CHANGELOG.md"
            path.write_text(VALID, encoding="utf-8")
            with redirect_stderr(StringIO()), redirect_stdout(StringIO()) as out:
                self.assertEqual(changelog.main(["--file", str(path), "notes", "v0.2.0"]), 0)
                self.assertEqual(changelog.main(["--file", str(path), "notes", "0.3.0"]), 1)
                self.assertEqual(changelog.main(["--file", str(path), "check", "--version", "0.3.0"]), 1)
            self.assertTrue(out.getvalue().startswith("### Update required"))


class DraftTest(unittest.TestCase):
    def test_groups_by_category(self):
        text = draft(
            [
                "feat(songs): show the key (#1)",
                "fix(ui): readable button (#2)",
                "chore(deps): upgrade pdfrx (#3)",
                "refactor!: rename the app (#4)",
                "docs(adr): propose ADR-0040 (#5)",
                "chore(release): v1.0.0 (#6)",
                "not conventional",
            ]
        )
        self.assertIn(f"### Added\n\n- Show the key ([#1]({URL}/pull/1))\n", text)
        self.assertIn("### Changed\n\n- Upgrade pdfrx ([#3]", text)
        self.assertIn("- **Breaking:** Rename the app ([#4]", text)
        self.assertIn(f"### Fixed\n\n- Readable button ([#2]({URL}/pull/2))\n", text)
        self.assertIn("docs(adr): propose ADR-0040 ([#5]", text.split("<!--")[1])
        self.assertIn("not conventional", text)
        self.assertNotIn("v1.0.0", text)


if __name__ == "__main__":
    unittest.main()
