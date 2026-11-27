"""Tests of play_notes.py (run by make check: python3 -m unittest in tool/release)."""

import json
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

import play_notes
from play_notes import LIMIT, NotesError, notes


class NotesTest(unittest.TestCase):
    def test_lines_become_bullets(self):
        self.assertEqual(notes(["One.", " Two. "], "en"), "• One.\n• Two.")

    def test_no_lines_give_the_fallback(self):
        self.assertEqual(notes([], "de"), play_notes.FALLBACK["de"])
        self.assertEqual(notes([], "en"), play_notes.FALLBACK["en"])

    def test_whole_lines_within_the_limit(self):
        lines = [("x" * 200) + f" {i}" for i in range(5)]
        text = notes(lines, "en")
        self.assertLessEqual(len(text), LIMIT)
        self.assertEqual(text.count("•"), 2)
        self.assertTrue(text.endswith(" 1"))

    def test_one_long_line_is_cut_at_a_word(self):
        text = notes(["word " * 200], "en")
        self.assertLessEqual(len(text), LIMIT)
        self.assertTrue(text.endswith("word…"))


class PlayNotesTest(unittest.TestCase):
    def test_locales(self):
        result = play_notes.play_notes({"1.0.0": {"de": ["Neu."], "en": ["New."]}}, "1.0.0")
        self.assertEqual(result, {"de-DE": "• Neu.", "en-US": "• New."})

    def test_missing_version(self):
        with self.assertRaises(NotesError):
            play_notes.play_notes({}, "1.0.0")

    def test_real_file_has_notes_within_the_limit(self):
        whats_new = json.loads(play_notes.WHATS_NEW.read_text(encoding="utf-8"))
        for version in whats_new:
            for text in play_notes.play_notes(whats_new, version).values():
                self.assertLessEqual(len(text), LIMIT, version)

    def test_main_writes_the_files(self):
        version = next(iter(json.loads(play_notes.WHATS_NEW.read_text(encoding="utf-8"))))
        with tempfile.TemporaryDirectory() as tmp, redirect_stdout(StringIO()):
            self.assertEqual(play_notes.main([f"v{version}", tmp]), 0)
            files = sorted(p.name for p in Path(tmp).iterdir())
        self.assertEqual(files, ["whatsnew-de-DE", "whatsnew-en-US"])


if __name__ == "__main__":
    unittest.main()
