# Tests of the operations files

The scripts and configuration that install, deploy and back up the server run
only on the server, so a mistake in them would otherwise show up there first.
`make check` tests them (issue #644).

## Static checks (`tool/check-ops.sh`, job `ops`)

- **ShellCheck** on every shell script of the repository: `*.sh` and files with
  a `sh`/`bash` shebang. Turn a check off only for a line and with a reason
  (`# shellcheck disable=SCxxxx # why`).
- **Caddyfile** (`tool/server/Caddyfile`): `caddy validate` and `caddy fmt`; it
  must be formatted as Caddy writes it (`caddy fmt --overwrite`).
- **systemd units** of `tool/server/`: `systemd-analyze verify` (unknown keys,
  bad values). Skipped on machines without systemd. The binaries the units
  start exist only on the server and are ignored.

## Behaviour tests (`server/test/`, job `server`)

- **Backup and restore** (`backup_test.dart`): runs
  `tool/server/setding-backup.sh` against a running PocketBase with a band, a
  song and a PDF attachment, changes data, restores the archive exactly as
  [the server guide](../operations/server.md#restore) describes and checks that
  the records, the users' passwords and the file are back as they were. Also:
  backups older than `KEEP_DAYS` are deleted, other files are kept, and a server
  without a database writes no backup. The script takes `PB_DATA` and
  `BACKUP_DIR` from the environment for this; on the server they keep their
  defaults. Needs `sqlite3` and `tar`.
- **Website server** (`site_server_test.dart`): runs Caddy with the real
  Caddyfile (only the port and site directory replaced) and checks the
  `www` redirect, the 404 page, compression and the cache headers.

## Check tools

ShellCheck (GPL-3.0), Caddy (Apache-2.0) and geckodriver (MPL-2.0, for
`make web-test BROWSER=firefox`, [web-tests.md](web-tests.md)) are pinned in
[`tool/fetch-tool.sh`](../../tool/fetch-tool.sh), downloaded into the cache
(`~/.cache/setding`) and verified (ShellCheck and geckodriver against SHA-256
sums pinned in the script, Caddy against the release's `checksums.txt`). They only run on the
development machine and in CI; nothing of them is copied into the repository or
shipped (owner decision 2026-11-20). `CADDY_BIN` overrides the Caddy binary, as
`POCKETBASE_BIN` does for PocketBase.

`tool/check-deps.sh` checks that the pinned versions are the latest GitHub
releases. To raise ShellCheck, update `SHELLCHECK_VERSION` and the four
SHA-256 sums (`sha256sum` of the release's `.tar.xz` archives). To raise
geckodriver, update `GECKODRIVER_VERSION` and its four sums (the digests
GitHub shows for the release's `.tar.gz` archives).

## Not tested

`install.sh`, `deploy.sh` and the release scripts need root, SSH to a server or
Docker; they are only linted. The restore on a Debian container was tested by
hand (see the server guide).
