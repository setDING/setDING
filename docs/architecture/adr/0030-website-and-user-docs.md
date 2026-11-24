# ADR-0030: Website and user documentation

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

setDING needs a public face at `https://setding.app`: a page that presents the app
to bands, schools and churches and links to the downloads, plus complete **user
documentation** for members, set planners, band leaders, librarians and
organization admins. The app stores will also need a public privacy policy URL.

Constraints:

- The documentation must follow the app: a feature PR should be able to update its
  user documentation in the same branch (ADR-0010), and the documentation must not
  describe a version that is not released.
- Both UI languages, Swiss Standard German and English (ADR-0008).
- The owner hosts everything on the Proxmox container of ADR-0014 for now, deploys
  it with the `make server-*` targets and has no Cloudflare Pages setup; agents have
  SSH access to the container but not to the Cloudflare account.
- New dependencies must be MIT-compatible and the newest versions
  (docs/development/dependencies.md).

## Decision

1. **In this repository**, in `website/`: landing page and user documentation in one
   static site. The developer documentation stays in `docs/`.
2. **Generator: [Astro](https://astro.build) with
   [Starlight](https://starlight.astro.build)** (both MIT). Pages are Markdown/MDX in
   `website/src/content/docs/`; **Swiss Standard German is the root locale**, English
   lives under `/en/` with the same page paths. Starlight brings navigation, a
   language switcher, offline full-text search (Pagefind) and light/dark themes.
   `starlight-links-validator` (MIT) fails the build on broken internal links.
   Logo and screenshots are taken from `app/branding/` and `docs/screenshots/`, not
   copied.
3. **Test gate:** `make check` builds the website (`tool/build-site.sh`), so pages
   that do not compile or link to missing pages block the merge;
   `tool/check-deps.sh` checks the npm packages like the Dart packages.
4. **Hosting on the existing server** (ADR-0014): **Caddy** from Debian serves the
   static build from `/var/www/setding-site` on `127.0.0.1:8081`; the Cloudflare
   Tunnel publishes it as `setding.app` (and `www.setding.app`, redirected by Caddy).
   Hashed assets are cached for a year, everything else is revalidated.
5. **Deployment like the web client:** `make server-install` and `make server-release`
   build the website from the same checkout and deploy it (`install-site.sh`), so
   production shows the documentation of the released version. `make server-site`
   deploys only the website from the working tree, for documentation fixes between
   releases. No build on GitHub.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Astro Starlight** (chosen) | Landing page and docs from one build, i18n with fallbacks, offline search, link validation, MIT | Node.js toolchain next to Flutter |
| MkDocs Material | Mature, very good docs theme | Python toolchain; landing page needs template overrides; i18n through a plugin |
| Hand-written HTML | No toolchain | Navigation, search and two languages maintained by hand |
| Separate repository | Independent of the app's test gate | Docs drift from the features; two places to change |
| Cloudflare Pages | No server needed, stays up when the home lab is down, PR previews | Agents have no Cloudflare access; deployment differs from the rest |
| Served by PocketBase (`pb_public`) | No extra service | `pb_public` already holds the web client for every hostname; host-based routing would need hooks |
| nginx instead of Caddy | Widespread | Longer configuration for the same result; Caddy is in Debian as well |

## Consequences

- The development machine needs **Node.js with npm** to run `make check`, `make site`
  and the server deploys.
- The documentation is deployed with releases; `make server-site` is the exception
  for fixes and is run by hand.
- The server gets a second service (Caddy); `make server-status` and
  `make server-logs` include it. The owner adds the tunnel hostnames once
  (docs/operations/server.md, section 8).
- If the server moves to external hosting, the website moves with it, since it is
  provisioned by the same scripts.

## Decision log

- 2026-11-17: Proposed (#388). The owner chose this repository, deployment through
  `make server-*` and hosting on the container of ADR-0014 for now; moving the whole server to external
  hosting (e.g. a Swiss VPS) is a separate decision.
- 2026-11-17: Accepted by the owner (#388). The website does not link to the web
  client, which is not open to the public.
- 2026-11-17: The landing page has no sidebar; a custom header
  (`website/src/components/Header.astro`) links to the documentation and the
  downloads on every page, with a short language switch on phones (#400).
- 2026-11-19: The header also shows the current version, linking to the news page
  with the "What's new" notes of every version (ADR-0041, #568).
- 2026-11-21: Screenshots are rendered per PR only for the feature the PR adds or
  changes (`make screenshots ONLY=…`); the release PR renders all of them and
  commits the ones that changed in passing. The screenshot tests are split into
  one file per area and skip the PNG encoding in the test gate (#759).
- 2026-11-22: Example songs to try a feature are served by the website itself
  under `/examples/` (copied from `docs/examples` by the build, not stored in
  `website/`), as song archives `.setDING.zip` and the existing example ZIPs,
  instead of links to GitHub (#923). Pages embed the song to copy with the
  `ExampleSong` component.

- 2026-11-23: Resolved the open point of a help entry in the app (#993): a
  *User guide* entry under *Storage & info → Help & info* and a help button
  (book icon) where a concept needs more than a hint: every settings category,
  the roles, the ChordPro editor and a band's arrangement (ui-design.md,
  section 10). The app links to pages of one enum `DocsPage`, never to heading
  anchors, which differ per language; UI languages the site does not have
  (e.g. those of #983) get the English pages. A website test
  (`src/app-docs-links.test.ts`) fails when a linked page is missing in a
  language of the site.

- 2026-11-24: **ADR-0063** (proposed, #1048): the website is project infrastructure, not part of self-hosting; it stays on the owner's server with its own deployment (`make server-site`, `SITE_SERVER`) and web server configuration, and installing or updating the backend no longer touches it. A new "Self-hosting" chapter documents the backend for operators.

## Open points

- Remaining documentation chapters (sets, live mode, songs and the editor, bands and
  roles, settings, self-hosting) in follow-up PRs.
- Privacy policy and legal notice (needed for the app stores).
- Whether feature PRs must update the user documentation (a rule in the git
  workflow, which only the owner may change).
