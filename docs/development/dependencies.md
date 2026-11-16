# External libraries

**Rule (owner decision 2026-11-16): external libraries are always used in
their newest version.**

- Direct dependencies and dev_dependencies of `packages/chordpro`, `server`
  and `app` must be the latest release on pub.dev.
- Transitive dependencies must be the newest version the other packages
  allow.
- Exceptions are deliberate pins only, marked in `pubspec.yaml` with a
  `# Pinned …` comment directly above the line and a reason (e.g.
  `pocketbase`, pinned to the server version, ADR-0004).

`make check` enforces this with `tool/check-deps.sh` (`make deps` runs it
alone). It queries pub.dev; without network it warns and skips.

## Updating

```bash
make upgrade     # pub upgrade in all packages, then the check
```

If the check reports a direct dependency, raise its constraint in
`pubspec.yaml` (a new major version may need code changes and its own PR),
then run `make upgrade` and `make check`. Libraries with extra files have
their own steps:

- `sqlite3`: update `app/web/sqlite3.wasm` and its pin
  ([web.md](web.md)).
- `drift`: run `make codegen`; the web worker is compiled from the new
  version by `make web`.
