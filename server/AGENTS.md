# AGENTS.md – server

Rules for working on the PocketBase server in `server/` (migrations, hooks, tests).
The repository-wide rules in the root [`AGENTS.md`](../AGENTS.md) apply as well.

## Permissions on the server (mandatory)

The server is the only place where permissions are enforced (owner rule, issue #632).
Anyone can call the PocketBase API directly (curl, Bruno, a modified client), so
nobody may be able to do through the API what the app does not let them do.

- **Every permission is enforced by the server**: collection API rules in
  `server/pb_migrations/`, hooks and custom routes in `server/pb_hooks/`. Client
  checks (`canManageSets`, `canEditSong`, … in `app/lib/data/band_view.dart`) only
  hide the UI and never replace a server check.
- **Deny by default.** The server refuses everything the permission matrix of
  ADR-0023 does not grant, also actions the app never offers and fields it never
  sends (e.g. `deleted`, `role`, tenant fields such as `organization`/`band`/`user`,
  server-maintained fields such as `revision`, `updated_by`, `created_by`).
- **Tested through the API.** Every new or changed collection, field, rule, hook,
  route or role comes with server tests in `server/test/` that call the API
  directly as each role that must be refused (and one that is allowed), and check
  on the server that nothing changed, not only the status code. The permission
  matrix test `server/test/permissions_test.dart` is kept complete.
- **Client and server change together.** A change to a client permission check
  changes the server rules, their tests and ADR-0023's matrix in the same PR.

## Golden file of the API rules (mandatory)

[`test/golden/rules.txt`](test/golden/rules.txt) holds the effective API rules
(list, view, create, update, delete; auth and manage for auth collections) and
the fields of every non-system collection after all migrations, one rule per
entry, wrapped before every `&&` and `||` (issue #1201).
`test/rules_golden_test.dart` compares a fresh test server against it, so every
rule change shows up as a readable diff in its PR.

- A PR that changes a rule or field runs `make rules-golden` and commits the
  updated file; review the diff as the actual change of the rules. After a
  rebase onto a `main` with other rule changes, run it again.
- Never edit the file by hand, and never update it to make the test pass
  without understanding the diff.
- In a migration, edit an existing rule only with `replaceInRule(rule, from,
  to)` (defined in each migration that needs it), which throws if `from` is
  not in the rule, in the up and the down migration; a plain
  `String.replace` silently does nothing when the text is missing. The same
  test downgrades through every migration that edits a rule and checks that
  the down migrations restore the older rules.

## Background

- Data model, migrations and hooks: ADR-0015; tested against a real PocketBase in
  `make check`, `make backend` runs it locally.
- Roles and permission matrix: ADR-0023. Registration modes: ADR-0024.
- Minimum client version (HTTP 426): ADR-0029. Soft delete, trash and purge: ADR-0044.
- Hosting and operations: ADR-0014, [`docs/operations/server.md`](../docs/operations/server.md).
