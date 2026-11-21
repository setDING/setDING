# ADR-0052: Deleting the own account

- **Status:** Proposed
- **Date:** 2026-11-21

## Context

A signed-in user cannot delete their account in the app (issue #780).

- **Server gap, now closed:** until #778 PocketBase's default `deleteRule` on `users` let anyone delete their own account with a direct API call. The delete hard-deleted their memberships through `cascadeDelete` (other devices never learned about it through sync) and could leave an organization without an admin. Since #778 only superusers can delete accounts (ADR-0015).
- **References to a user:**
  - `memberships.user` and `org_memberships.user` (`cascadeDelete: true`, synced to every member's device);
  - private data: `overlays.user`, `annotations.user`, `user_settings.user` (`cascadeDelete: true`, ADR-0020, ADR-0027, ADR-0032);
  - `updated_by` on every synced record and `created_by`/`used_by` on invitations (no cascade: PocketBase clears them, and each cleared record gets a new revision through the sync hooks).
- **Last admin:** an organization must keep at least one active admin and a band at least one leader (`keepLastAdmin`, ADR-0015, ADR-0017, ADR-0023).
- **Offline-first and sync:** other devices learn about removals only through soft deletes and delta sync (ADR-0001, ADR-0004).
- **Server backups** keep a copy for 14 days (ADR-0014).
- **Precedent:** deleting bands and closing organizations use `DELETE` on the records API, turned into a soft delete with a cascade by a hook (ADR-0044).

The owner decided the main questions on 2026-11-21 (#780): deleting is refused while the user is the last admin of an organization, and it is immediate and final, confirmed with the password.

## Decision

### 1. Who and when

- **Any signed-in user** may delete **their own** account, nobody else's (superusers excepted, section 5).
- **Refused while the user is the last active admin of an organization** that is not closed. The answer names those organizations; the user first makes someone else admin or closes the organization (ADR-0044). A closed organization in the trash does not block: it is purged after 30 days anyway, and its other admins, if any, can still restore it.
- **Band leaders are not blocked:** the organization admins can name a new leader, as for any band (ADR-0023). A band whose last leader deletes their account stays without a leader until then.
- **Needs a connection.** Offline, the app explains that the server must be reachable.

### 2. Interface: the PocketBase standard path

- `DELETE /api/collections/users/records/{id}` with the current password in the body (`{"password": "…"}`); the Dart SDK sends it with `collection('users').delete(id, body: …)`.
- `users.deleteRule = "id = @request.auth.id"` again; a hook (`onRecordDeleteRequest`, `users`) checks the password for users (400 with a field error if it is wrong), refuses the last admin (400 naming the organizations) and runs section 3 in one transaction before the record is deleted.
- **Rate limit** `users:delete` (5 per minute), like sign-up, so the route cannot be used to guess passwords.
- Afterwards every token of the account is invalid: other devices get 401 on their next request and sign out (as after a password change).

### 3. What happens to the data

**Soft-deleted** (so other devices learn it through sync), then cut off from the account:

- all **organization memberships** and **band memberships** of the user, also those of closed organizations. `memberships.user` and `org_memberships.user` change to `cascadeDelete: false`, so PocketBase clears the reference when the user record is deleted and the soft-deleted membership stays as a tombstone without a person.

**Removed at once** (hard delete; only the user's own devices had them):

- **personal adjustments** (`overlays`), **annotations** and **personal settings** (`user_settings`), through their existing cascade.

**Revoked:** open invitations the user created.

**Cleared without a new revision:** `updated_by` on synced records and `created_by`/`used_by` on invitations are cleared by the hook with a direct database update before the delete, so that removing one account does not make every device download every record that person ever edited. Devices do not show `updated_by`.

**Stays with the organization:** songs, attachments, sets, arrangements and play history (ADR-0017, ADR-0046). They are shared content, not personal data of the account.

**The account itself** (email, name, password hash, avatar) is deleted. It remains in the server backups for up to 14 days (ADR-0014); the app's confirmation and the website say so.

### 4. App

- **Account management** in the settings (account section, ADR-0050) gets *Delete account* as its last, destructive action (`destructiveButtonStyle()`, ADR-0051).
- **Confirmation:** a dialog explains what is deleted and what stays with the organizations, mentions the backups, and asks for the password. When the server refuses because of the last admin, the dialog lists the organizations.
- **After deleting**, the device signs out and removes the data of the account's organizations (`removeOrganizationData`, as after closing an organization) and the account's private data. The local library (songs not in any organization) stays. The web client deletes the browser data as on sign-out.

### 5. Superusers

Deleting a user in the admin UI runs the same hook without the password check: memberships are soft-deleted, private data removed, references cleared. The last-admin refusal applies to superusers too (like `keepLastAdmin`, ADR-0015); the operator first makes someone else admin or closes the organization.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Immediate deletion, refused for the last admin** (chosen) | Simple, final, matches a deletion request; no organization without an admin | No undo; the user must hand over admin rights first |
| Close the organizations of the last admin automatically | One step for the user | Deletes the shared library of everyone else as a side effect of a personal action |
| 30-day grace period (account locked, sign-in restores it) | Undo for mistakes | New account state, purge job and locked-account handling in every rule; the owner preferred final |
| Anonymize the account instead of deleting it | References stay valid | Leaves an account record behind; unclear for a deletion request; the email must be freed by hand |
| Own route `POST /api/setding/account/delete` | No body on `DELETE` | Second path next to the records API; ADR-0044 chose the standard path |
| Confirm by signing in again in the app only | No password in the delete call | Not enforced on the server: a stolen token could delete the account |

## Consequences

- Users can leave the service completely; a deletion request no longer needs the operator.
- An organization never loses its last admin through account deletion.
- Members see a soft-deleted membership disappear from their member lists with the next sync.
- A band may be left without a leader until an organization admin names one.
- Implementation (#780): migration (`deleteRule`, the two `cascadeDelete` changes, the rate limit), the hook with server tests through the API (own and other accounts, wrong password, last admin, closed organization, superuser, the cascade and cleared references, the permission matrix), the app (dialog, local cleanup), texts in both languages, website page and screenshot, and ADR-0015 (rules, decision log), ADR-0023 (matrix row).

## Decision log

- 2026-11-21: Proposed (#780). The owner decided: refused while the user is the last admin of an organization; immediate and final, confirmed with the password; changing the display name and the password come first (#779), changing the email address later.

## Open points

- Whether the app should offer a backup archive of the account's organizations before deleting (ADR-0043), as before closing an organization.
