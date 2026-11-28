#!/usr/bin/env python3
"""Keeps the lines of `systemd-analyze verify` that are problems of our unit.

tool/check-ops.sh verifies the systemd unit of the self-hosting docs. verify
also loads the machine's own units and prints their problems (on GitHub's
runner, e.g. "/usr/lib/systemd/system/walinuxagent.service:21: Support for
option CPUAccounting= has been removed"); those are not ours (#1254). The
binaries our unit starts exist only on a server, so "is not executable"
messages are dropped as well.

Usage: systemd-analyze verify UNIT 2>&1 | systemd_verify_filter.py UNIT
"""

import os
import re
import sys

# "<path to a unit file>:<line>: message" or "<path>: message".
UNIT_LINE = re.compile(
    r"^(/[^:\s]+\.(?:service|socket|slice|target|timer|mount|path|scope|swap|automount|device))(?::\d+)?:"
)
NOT_EXECUTABLE = re.compile(r"Command .* is not executable: No such file or directory")


def problems(lines, unit):
    ours = os.path.realpath(unit)
    result = []
    for line in lines:
        line = line.rstrip("\n")
        if not line.strip() or NOT_EXECUTABLE.search(line):
            continue
        match = UNIT_LINE.match(line)
        if match and os.path.realpath(match.group(1)) != ours:
            continue
        result.append(line)
    return result


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        sys.exit(__doc__.strip().splitlines()[-1])
    for line in problems(sys.stdin, argv[0]):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
