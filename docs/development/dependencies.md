# External libraries

**Rule (owner decision 2026-11-16): external libraries are always used in
their newest version.**

- Direct dependencies and dev_dependencies of `packages/chordpro`, `server`,
  `tool/sbom` and `app` must be the latest release on pub.dev.
- The CycloneDX Gradle plugin of the SBOM (`tool/sbom/gradle/cyclonedx.init.gradle`,
  ADR-0037) must be the latest release on the Gradle plugin portal; raise its
  version in the init script by hand.
- The check tools pinned in `tool/fetch-tool.sh` (ShellCheck, Caddy; issue
  #644) must be the latest GitHub release; raise them by hand
  ([operations tests](operations-tests.md)).
- Transitive dependencies must be the newest version the other packages
  allow.
- Exceptions are deliberate pins only, marked in `pubspec.yaml` with a
  `# Pinned …` comment directly above the line and a reason (e.g.
  `pocketbase`, pinned to the server version, ADR-0004).

`tool/check-deps.sh` enforces this (`make deps` runs it alone). It fails
`make check-full` and `make release-gate`, and `make check` when the branch
changes a `pubspec.yaml`/`pubspec.lock`, `package.json` or the SBOM's Gradle
plugin; otherwise `make check` only warns, so a new upstream release does not
block unrelated changes (#684). Upgrade in its own PR. It queries pub.dev;
without network it warns and skips.

## Updating

**First check that no other session is already raising a dependency**
(owner rule 2026-11-23, #995). Parallel upgrades in several worktrees raise
the same library twice, conflict in the lock files and waste a full check.
`make upgrade` runs this check first; before raising a constraint, a pinned
tool or the Gradle plugin by hand, run it alone:

```bash
make upgrade-guard   # stop if dependencies are already being changed elsewhere
make upgrade         # upgrade-guard, pub upgrade in all packages, then the check
```

`tool/upgrade_guard.py` stops with a list of what it found:

- other local worktrees (`.worktrees/`) whose branch or uncommitted changes
  touch a dependency file (a `pubspec.yaml` or `pubspec.lock`,
  `website/package.json` or its lock, the SBOM's Gradle plugin,
  `tool/fetch-tool.sh`),
- open pull requests that change such a file,
- open `agent:in-progress` issues whose title is about dependencies
  (deps, dependency, upgrade, bump).

A `pubspec.yaml` change of only the `version:` line (a release) does not
count; the branch's own PR and issue are skipped. Without `gh` or network it
warns that pull requests and issues were not checked. When it finds
something, coordinate instead of upgrading in parallel: wait for that PR's
merge and upgrade on top, or leave the upgrade to that session. A feature
branch never raises a library on the side; that is an upgrade PR of its own.
`UPGRADE_FORCE=1 make upgrade` overrides the check only for a deliberate
parallel upgrade of a different library.

If the check reports a direct dependency, raise its constraint in
`pubspec.yaml` (a new major version may need code changes and its own PR),
then run `make upgrade` and `make check`. Libraries with extra files have
their own steps:

- `sqlite3`: update `app/web/sqlite3.wasm` and its pin
  ([web.md](web.md)).
- `drift`: run `make codegen`; the web worker is compiled from the new
  version by `make web`.
