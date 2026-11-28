"""Tests of systemd_verify_filter.py (python3 -m unittest test_systemd_verify_filter, run by make check)."""

import unittest

import systemd_verify_filter as f

UNIT = "/tmp/examples/setding.service"


class ProblemsTest(unittest.TestCase):
    def test_problems_of_other_units_are_dropped(self):
        # As on GitHub's runner (#1254).
        out = [
            "/usr/lib/systemd/system/xfs_scrub_all.service:26: Support for option CPUAccounting= has been removed and it is ignored\n",
            "/usr/lib/systemd/system/system-xfs_scrub.slice:15: Support for option CPUAccounting= has been removed and it is ignored\n",
        ]
        self.assertEqual(f.problems(out, UNIT), [])

    def test_problems_of_our_unit_stay(self):
        out = [
            "/tmp/examples/setding.service:12: Unknown key name 'Restartt' in section 'Service', ignoring.\n",
            "/usr/lib/systemd/system/walinuxagent.service:21: Support for option CPUAccounting= has been removed\n",
        ]
        self.assertEqual(
            f.problems(out, UNIT),
            ["/tmp/examples/setding.service:12: Unknown key name 'Restartt' in section 'Service', ignoring."],
        )

    def test_messages_without_a_unit_path_stay(self):
        out = ["Failed to load unit: Invalid argument\n", "\n"]
        self.assertEqual(f.problems(out, UNIT), ["Failed to load unit: Invalid argument"])

    def test_missing_binaries_of_the_server_are_dropped(self):
        out = [
            "setding.service: Command /opt/setding/pocketbase is not executable: No such file or directory\n",
        ]
        self.assertEqual(f.problems(out, UNIT), [])


if __name__ == "__main__":
    unittest.main()
