"""Tests of release_tag.py (run by make check: python3 -m unittest in tool/release)."""

import unittest

from release_tag import TagError, pick, version_key

TAGS = ["v1.2.0", "v1.3.0-beta.1", "v1.3.0-beta.2", "v1.1.9", "v-old", "vnext"]


class PickTest(unittest.TestCase):
    def test_production_gets_the_newest_final_tag(self):
        # git's version sort puts v1.3.0-beta.2 first; production must not
        # get it (#1178).
        self.assertEqual(pick(TAGS, "prod"), "v1.2.0")

    def test_staging_gets_the_newest_tag_with_pre_releases(self):
        self.assertEqual(pick(TAGS, "staging"), "v1.3.0-beta.2")

    def test_a_release_sorts_after_its_pre_releases(self):
        tags = TAGS + ["v1.3.0"]
        self.assertEqual(pick(tags, "staging"), "v1.3.0")
        self.assertEqual(pick(tags, "prod"), "v1.3.0")

    def test_production_refuses_a_pre_release_version(self):
        with self.assertRaisesRegex(TagError, "staging only"):
            pick(TAGS, "prod", "1.3.0-beta.1")
        self.assertEqual(pick(TAGS, "staging", "v1.3.0-beta.1"), "v1.3.0-beta.1")
        self.assertEqual(pick(TAGS, "prod", "1.1.9"), "v1.1.9")

    def test_no_tag(self):
        with self.assertRaisesRegex(TagError, "no final release tag"):
            pick(["v1.3.0-rc.1"], "prod")
        with self.assertRaisesRegex(TagError, "no release tag"):
            pick([], "staging")

    def test_unknown_target(self):
        with self.assertRaisesRegex(TagError, "TARGET must be"):
            pick(TAGS, "production")


class VersionKeyTest(unittest.TestCase):
    def test_semantic_order(self):
        ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-beta.2", "1.0.0-beta.10",
                   "1.0.0-rc.1", "1.0.0", "1.0.1", "1.10.0"]
        self.assertEqual(sorted(reversed(ordered), key=version_key), ordered)


if __name__ == "__main__":
    unittest.main()
