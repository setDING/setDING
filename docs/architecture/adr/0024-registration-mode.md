# ADR-0024: Registration mode set by the server operator

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

Today anyone who reaches the server can create an account (PocketBase sign-up,
ADR-0016). A signed-in user may create bands without an organization, and the
server then creates a new organization with that user as its admin (ADR-0017,
`pb_hooks/bands.pb.js`; `organizations.createRule` allows every signed-in user).
An invitation only decides whether the new account also joins an existing
organization.

On a private, self-hosted server (ADR-0014) this means strangers can create any
number of accounts, organizations, songs and PDF attachments. That costs storage,
backup space and possibly money, and the operator cannot prevent it. The owner
wants **self-registration off** on the production server, while other operators
may want an open server.

## Decision

### Registration mode

The **server operator** sets the registration mode in the server environment
(`/opt/pocketbase/pocketbase.env`, like `REALCHORD_WEB_URL`, ADR-0014):

```
REALCHORD_REGISTRATION=invite_only   # or: open
```

| Mode | Who can create an account | Who can found an organization |
|---|---|---|
| `invite_only` *(default)* | Only people with a valid invitation | Only people with a **founder invitation** from the operator |
| `open` | Anyone | Any signed-in user (today's behaviour) |

- The default is **`invite_only`**: a new server is closed until the operator
  opens it deliberately.
- Changing the mode means editing the environment file and restarting PocketBase;
  `make server-install` keeps an existing value and documents the variable.
- The setting is a server concern, not an in-app role: there is **no in-app
  super-admin** that sees all organizations. The operator's full access stays the
  PocketBase superuser in the server's admin UI, as today.

### Sign-up with an invitation

- In `invite_only` mode a hook rejects `users` create requests that do not carry a
  **valid invitation token** (exists, not expired, not revoked; checked by its hash
  like `pb_hooks/invites.pb.js`). The token is sent with the sign-up request.
- Signing up and joining happen together: the app passes the token it got from the
  invitation link (deep link, pasted link, QR code) to the sign-up form, and redeems
  it right after the account exists (ADR-0005 flow, unchanged otherwise).
- Existing accounts are not affected; signing in always works.
- Server routes for invitations stay usable without an account (preview), so the
  app can show "Join *organization*?" before the sign-up form.

### Founder invitations (new organizations on a closed server)

- The operator creates a **founder invitation** on the server, e.g.
  `make server-founder-invite NAME="Music school"`. It is a one-time link in the
  same format as other invitations (`https://api.realchord.app/invite/<token>`).
- Redeeming it creates the **organization** with the given name (renamable later)
  and makes the person its **admin**; with a new account, the account is created in
  the same step.
- Founder invitations are single-use, valid for 7 days, revocable by the operator
  and stored as a hash like other invitations.
- In `invite_only` mode, only redeeming a founder invitation creates organizations:
  creating a band without an organization is rejected; organization admins create
  further bands inside their organization (ADR-0017, unchanged).
- The first organization and admin of a new server come about the same way, so no
  manual record editing is needed.

### What the app shows

- A small public route (`GET /api/realchord/config`) returns the registration mode.
- In `invite_only` mode the account screen offers **Sign in** and **Join with an
  invitation**; "Create account" appears only together with an invitation.
  "Create band" is offered only inside an organization the user administers.
- If the server rejects a sign-up anyway (mode changed meanwhile), the app explains
  that an invitation is needed.
- The local library ("On this device") stays usable without any account
  (issue #15).

### Flood protection in both modes

- PocketBase's built-in **rate limits** are enabled for sign-up, sign-in and the
  invitation routes (configured by the migration or install script).
- Existing limits stay: 20 MB per PDF (ADR-0009), Cloudflare in front (ADR-0014).
- Email verification for open servers is left for when SMTP exists (ADR-0016 open
  point).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Operator setting `open` / `invite_only`, founder invitations** (chosen) | Closed by default, no in-app super-admin, works for private and public servers | One more server setting and invitation kind |
| Status quo (open sign-up) | No work | Anyone can fill the server; costs |
| Sign-up open, only organization creation restricted | Accounts are cheap | Accounts still pile up (spam, password reset mails later); does not meet the owner's goal |
| In-app super-admin role | Manage everything in the app | Sees all organizations' data, privacy (ADR-0017); a high-value account to protect |
| Operator approves every new account | Full control | Manual work, people wait; needs a notification channel |
| Accounts created only by the operator | Simplest rule | Every new musician needs the operator |
| Setting in a database collection editable in the admin UI | Changeable without restart | Another collection and rule for a value that rarely changes |

## Consequences

- New hooks on `users` create and band create, a founder invitation type, a public
  config route, a `make` target for founder invitations, and server tests for both
  modes against a real PocketBase (ADR-0015).
- The app needs the registration mode on the account screen and the invitation
  token in the sign-up flow; new UI texts in both ARB files (ADR-0008).
- With `invite_only` as the default, a fresh installation needs a founder
  invitation before anyone can use it; `docs/operations/server.md` describes this.
- The production server switches to `invite_only` when this is implemented; existing
  accounts and organizations stay.
- Related to ADR-0023 (finer-grained roles): invitations by band leaders also work as
  sign-up tickets.

## Decision log

- 2026-11-17: Proposed with issue #209. Owner requirement: the server operator can
  turn off sign-up without an invitation to avoid floods and costs.

## Open points

- Should an organization admin be able to issue founder invitations for *new*
  organizations, or only the operator?
- Limits per organization (number of songs, attachment storage) as a further cost
  guard.
- Email verification and a captcha-free spam protection for `open` servers.
