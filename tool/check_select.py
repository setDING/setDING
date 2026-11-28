#!/usr/bin/env python3
"""Selects the jobs of `make check` that a change affects (issue #684).

Reads the changed files (one path per line, relative to the repository root)
from stdin and prints two lines:

    jobs: <job> <job> ...     the jobs to run, in the order of tool/check.sh
    deps: strict|warn         whether outdated libraries fail the check

Every job runs ("full") when
- the change set is empty (nothing to compare, e.g. on main),
- a file belongs to the check itself or to the whole build (FULL),
- a file matches no rule (unknown files are never skipped silently),
- more than the threshold of files changed (a larger change).

The dependency check is strict in a full run and when a file that pins
libraries changed; otherwise it only warns (docs/development/git-workflow.md).
"""

import argparse
import sys

# All jobs of tool/check.sh, in its order.
JOBS = [
    'chordpro', 'server', 'ops', 'sbom', 'changelog', 'tools',
    'website', 'app-static', 'app-tests', 'app-web',
]

APP = ['app-static', 'app-tests', 'app-web']

# Files that shape every job: a change runs the full check.
FULL = (
    'Makefile',
    'tool/check.sh',
    'tool/check_select.py',
    'tool/test_check_select.py',
    'tool/check-deps.sh',
    'tool/fetch-tool.sh',
    '.github/',
)

# Path prefix -> jobs. A file gets the jobs of every rule it matches; the
# first matching rule of a prefix group is enough, so longer prefixes come
# first where it matters.
RULES = [
    # The app depends on the ChordPro package; the showcase is a regression
    # test of both (AGENTS.md).
    ('packages/chordpro/', ['chordpro'] + APP),
    ('docs/examples/', ['chordpro', 'app-tests']),
    # The app's tests use the server's PocketBase harness and schema.
    ('server/', ['server', 'app-static', 'app-tests']),
    # Website server, backup and deploy files: ops checks, server tests.
    ('tool/server/', ['ops', 'server']),
    # Server bundle (ADR-0063): build script and example unit, tested by
    # server/test/bundle_test.dart.
    ('tool/server-dist/test_doc_example.py', ['tools']),
    ('tool/server-dist/test_previous_bundle.py', ['tools']),
    ('tool/server-dist/previous-bundle.sh', ['ops', 'server', 'tools']),
    ('tool/server-dist/doc-example.py', ['ops', 'server', 'tools']),
    ('tool/server-dist/', ['ops', 'server']),
    # Website server (ADR-0030): Caddyfile check, site_server_test.
    ('tool/site/', ['ops', 'server']),
    # The self-hosting docs hold the examples the server tests and the ops
    # checks run (ADR-0063 §5).
    ('website/src/content/docs/self-hosting/', ['website', 'ops', 'server']),
    ('website/src/content/docs/en/self-hosting/', ['website', 'ops', 'server']),
    ('tool/sbom', ['sbom']),
    ('tool/release/', ['changelog']),
    ('CHANGELOG.md', ['changelog']),
    ('tool/coverage/', ['tools']),
    ('tool/ci/', ['tools']),  # nightly CI test summary (#1249)
    ('tool/build-web.sh', ['app-web']),
    ('tool/build-site.sh', ['website']),
    ('tool/check-ops.sh', ['ops']),
    ('tool/upgrade_guard.py', ['tools']),
    ('tool/test_upgrade_guard.py', ['tools']),
    ('tool/test_server_targets.py', ['tools']),
    ('tool/systemd_verify_filter.py', ['ops', 'tools']),
    ('tool/test_systemd_verify_filter.py', ['tools']),
    ('tool/', []),  # other tools (perf, branding, integration test runners)
    ('website/', ['website']),
    ('docs/screenshots/', ['website']),
    # The website shows the app's logo and its what's-new notes.
    ('app/branding/', ['website', 'app-tests']),
    ('app/assets/', APP + ['website']),
    # The version in the pubspec needs its CHANGELOG.md section.
    ('app/pubspec.yaml', APP + ['changelog']),
    # The website tests that the app's help links have their pages (#993).
    ('app/lib/ui/widgets/docs_link.dart', APP + ['website']),
    ('app/lib/', APP),
    ('app/web/', APP),
    ('app/pubspec.lock', APP),
    ('app/analysis_options.yaml', APP),
    ('app/l10n.yaml', APP),
    ('app/build.yaml', APP),
    ('app/', ['app-static', 'app-tests']),
    # Documentation that no job builds or tests.
    ('docs/', []),
    ('.claude/', []),
    ('.gitignore', []),
    ('LICENSE', []),
]

# Files that pin external libraries (docs/development/dependencies.md).
DEPS = (
    'pubspec.yaml', 'pubspec.lock', 'package.json', 'package-lock.json',
    'cyclonedx.init.gradle', 'Dockerfile',
)

DEFAULT_THRESHOLD = 40


def select(files, threshold=DEFAULT_THRESHOLD):
    """Returns (jobs, deps_strict, reason); reason explains a full run."""
    files = [f.strip() for f in files if f.strip()]
    if not files:
        return JOBS, True, 'no changes against main'
    if len(files) > threshold:
        return JOBS, True, f'{len(files)} files changed (more than {threshold})'
    jobs = set()
    for f in files:
        if any(f == p or (p.endswith('/') and f.startswith(p)) for p in FULL):
            return JOBS, True, f'{f} affects every job'
        matched = False
        for prefix, rule_jobs in RULES:
            if f == prefix or (f.startswith(prefix) and (
                    prefix.endswith('/') or f[len(prefix):len(prefix) + 1] in ('/', '.', '-', '_'))):
                jobs.update(rule_jobs)
                matched = True
                break
        if not matched and f.endswith('.md') and '/' not in f:
            matched = True  # README.md, AGENTS.md, CLAUDE.md
        if not matched:
            return JOBS, True, f'{f} matches no rule'
        if f.endswith('.sh'):
            jobs.add('ops')
    deps = any(f.rsplit('/', 1)[-1] in DEPS for f in files)
    return [j for j in JOBS if j in jobs], deps, None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--threshold', type=int, default=DEFAULT_THRESHOLD)
    args = parser.parse_args()
    jobs, deps, reason = select(sys.stdin.read().splitlines(), args.threshold)
    if reason:
        print(f'full check: {reason}', file=sys.stderr)
    print('jobs: ' + ' '.join(jobs))
    print('deps: ' + ('strict' if deps else 'warn'))


if __name__ == '__main__':
    main()
