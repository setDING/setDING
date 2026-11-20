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

## Background

- Data model, migrations and hooks: ADR-0015; tested against a real PocketBase in
  `make check`, `make backend` runs it locally.
- Roles and permission matrix: ADR-0023. Registration modes: ADR-0024.
- Minimum client version (HTTP 426): ADR-0029. Soft delete, trash and purge: ADR-0044.
- Hosting and operations: ADR-0014, [`docs/operations/server.md`](../docs/operations/server.md).
