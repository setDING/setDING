# Website and user documentation (development)

The website at https://setding.app – landing page and user documentation – lives in
[`website/`](../../website) and is built with Astro Starlight (ADR-0030). It needs
Node.js with npm on the development machine.

## Build and preview

```bash
make site-dev     # live reload on http://localhost:4321
make site         # build into website/dist (also part of `make check`)
```

`make site` (`tool/build-site.sh`) installs the locked packages (`npm ci`) and builds
the site. The build fails on failing unit tests of the website code, on pages that
do not compile and on broken internal links.

## Writing pages

- Pages are Markdown (`.md`) or MDX (`.mdx`, for components and images) in
  `website/src/content/docs/`. **Swiss Standard German** pages live at the root, the
  **English** ones under `en/` with the **same path** (`start/install.md` and
  `en/start/install.md`), so the language switcher finds them. Write both; a page
  missing in English shows the German one with a notice.
- German texts address the reader with **"du"** (never "ihr" or "Sie"); where a
  sentence is about the whole band, name the band ("legt die Band fest").
- German texts follow the app's rules: Swiss Standard German, no "ß", the same terms
  and button labels as in `app_de.arb` / `app_en.arb`, written in **bold**.
- Links between pages are absolute without the domain: `/start/install/` and
  `/en/start/install/`.
- Sidebar: one group per directory, configured in `website/astro.config.mjs`; the
  order within a group comes from `sidebar.order` in the front matter. The landing
  page (`index.mdx`) has no sidebar; the header links to the documentation and the
  downloads (`website/src/components/Header.astro`, which replaces Starlight's
  header).
- Screenshots come from `docs/screenshots/` (`make screenshots`); import them in MDX
  (see `index.mdx`) so Astro converts and sizes them. Do not copy them into
  `website/`.
- **Example songs** to try a feature live in `docs/examples/` as `<name>-de.cho` and
  `<name>-en.cho` (same chords, original lyrics), each with a song archive
  `<name>.setDING.zip` written by `make examples`. A page shows its song with
  `<ExampleSong name="<name>-de" />` (`src/components/ExampleSong.astro`: the text
  to copy and the archive to download); other example ZIPs are linked as
  `/examples/<file>`. The build serves every ZIP of `docs/examples` under
  `/examples/` (`src/examples-integration.mjs`); `src/examples.test.ts` checks the
  links. See [`docs/examples/README.md`](../examples/README.md).
- **Every page that documents a feature shows it in a screenshot** (in both
  languages). A new or visibly changed feature comes with a screenshot test in
  `app/test_screenshots/`, a line in `tool/copy-screenshots.sh` and the image on
  its page, rendered with `make screenshots ONLY="<test name>"`; see
  [`docs/screenshots/README.md`](../screenshots/README.md). Pages that only explain
  concepts or installation (`start/`, `bands/roles`) need none.
- **The app links to pages here** (#993): its help buttons open the pages of
  `DocsPage` in `app/lib/ui/widgets/docs_link.dart`, never heading anchors.
  Renaming or moving such a page changes the enum in the same PR;
  `src/app-docs-links.test.ts` fails otherwise. A new language of the site is
  one entry in `docsSiteLanguages` there.

## News page and version

The page *Neuigkeiten* / *What's new* (`news.mdx`, `en/news.mdx`) and the version in
the header are generated from the checkout the site is built from (ADR-0041): the
notes of every version from `app/assets/whats_new.json`, the release dates from
`CHANGELOG.md` (`website/src/releases.ts`, `website/src/release-data.ts`). They need
no editing; the release PR writes both files, and `make server-release` builds the
site from the tag. The build runs the unit tests (`node --test src/*.test.ts`) and
fails on a version without a released `CHANGELOG.md` section.

## Dependencies

`website/package.json` lists the npm packages; `package-lock.json` locks them.
`tool/check-deps.sh` (part of `make check`) fails if one is not the newest version;
`make upgrade` runs `npm update`. A new major version needs its range in
`package.json` raised by hand, then `npm install`.

## Deployment

The server deploys build the website from the same checkout:
`make server-release` (production, released versions), `make server-install`
(test instances) and `make server-site` (only the website, from the working tree, for
documentation fixes between releases). Hosting:
[server operations, section 8](../operations/server.md#8-website-owner-once).
