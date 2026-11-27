#!/usr/bin/env python3
"""Picks the release tag that make server-release deploys (ADR-0029, ADR-0069).

    tool/release/release_tag.py <prod|staging> [x.y.z[-pre]]

Prints the tag, e.g. v1.3.0-beta.1, or fails with a message on stderr.

- Production gets final releases only: without a version the newest final tag,
  a pre-release version (with a suffix) is refused.
- Staging gets any release: without a version the newest tag, pre-releases
  included, so a pre-release is tested there before its final release.

Tags are ordered as semantic versions: a pre-release sorts before its release
(1.3.0-beta.1 < 1.3.0) and numeric identifiers numerically (beta.2 < beta.10).
Tags that are no version (v-something) are ignored.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGETS = ("prod", "staging")
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$")


class TagError(Exception):
    pass


def is_prerelease(version: str) -> bool:
    return "-" in version


def version_key(version: str) -> tuple:
    match = VERSION.match(version)
    if not match:
        raise ValueError(f"not a version: {version}")
    core = tuple(int(match.group(i)) for i in (1, 2, 3))
    pre = match.group(4)
    if pre is None:
        return core + (1, ())
    # Semantic versioning: numeric identifiers before alphanumeric ones.
    ids = tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in pre.split("."))
    return core + (0, ids)


def pick(tags: list[str], target: str, version: str | None = None) -> str:
    if target not in TARGETS:
        raise TagError(f"TARGET must be prod or staging, not '{target}'")
    if version:
        version = version.removeprefix("v")
        if target == "prod" and is_prerelease(version):
            raise TagError(
                f"v{version} is a pre-release: it goes to staging only (TARGET=staging, ADR-0069)"
            )
        return f"v{version}"
    versions = [t[1:] for t in tags if t.startswith("v") and VERSION.match(t[1:])]
    if target == "prod":
        versions = [v for v in versions if not is_prerelease(v)]
    if not versions:
        kind = "final release tag" if target == "prod" else "release tag"
        raise TagError(f"no {kind} found")
    return "v" + max(versions, key=version_key)


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if not 1 <= len(args) <= 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    tags = subprocess.run(
        ["git", "-C", str(ROOT), "tag", "--list", "v*"],
        check=True, capture_output=True, text=True,
    ).stdout.split()
    try:
        print(pick(tags, args[0], args[1] if len(args) > 1 else None))
    except TagError as e:
        print(f"server-release: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
