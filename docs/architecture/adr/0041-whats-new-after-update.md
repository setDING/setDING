# ADR-0041: "What's new" notes after an update

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

The installed apps now update themselves (Windows setup ADR-0035, Linux
AppImage ADR-0038) or are pointed to new versions by the update check
(ADR-0036), but people do not learn what a new version changed. ADR-0036 left
"release notes in the app" open.

[`CHANGELOG.md`](../../../CHANGELOG.md) is not suitable to show them:

- it is English only, while the UI is de-CH and en (ADR-0008);
- it is written for developers and operators (PR links, ADR numbers, dependency
  upgrades, SBOM);
- its published form, the GitHub Release, is not available offline (ADR-0001).

setDING runs on stage: nothing may pop up in live mode or block the start
before a gig (ADR-0007, ADR-0036).

## Decision

### The notes

- **`app/assets/whats_new.json`**, bundled with the app, so the notes work
  offline and need no server:

  ```json
  {
    "0.15.0": {
      "de": ["Kurzer Satz für Benutzer.", "…"],
      "en": ["Short sentence for users.", "…"]
    }
  }
  ```

- Per version a few (about 3–5) short sentences in **de-CH and en**, the same
  number in both, written for band members: what they can do now, not how it
  was built. No PR or ADR references.
- An **empty list** deliberately says nothing (e.g. a patch without
  user-visible changes).
- The **release PR** writes the entry together with the `CHANGELOG.md` section,
  shortened from it. `make check` fails when the version in `app/pubspec.yaml`
  has no entry, when a language is missing, when the two languages differ in
  length or when the German text contains "ß" (`test/whats_new_test.dart`).

### When they are shown

- The last version whose notes were offered is kept on the device
  (`shared_preferences`, `whatsNew.lastSeen`).
- On a **new installation** nothing is shown; the running version counts as
  seen. A device that already used setDING before this feature counts as
  updated and gets the notes of the running version.
- After an update the app collects the notes of **all versions after the last
  seen one up to the running one** (SemVer precedence, ADR-0028), so a skipped
  version is not lost. Versions with an empty list are skipped; if nothing is
  left, the app stays silent and marks the version as seen.
- On every platform, including the web client (a new deploy is an update
  there too) and debug builds.

### How they are shown

- **Once**, a short SnackBar *"New in setDING x.y.z"* with *Show*, which opens a
  dialog with the notes, newest version first, and a link to all changes (the
  GitHub Release, ADR-0036). The SnackBar goes away by itself
  (`persist: false`), like the update hint.
- Only while the main navigation is on top, so never in live mode or while
  editing; otherwise at a later start.
- **Any time** with the *What's new* button next to the version under
  *Settings → Storage & info*, with the notes of
  all versions up to the running one.
- The notes are shown in the app language; a language without notes falls back
  to English.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Bundled bilingual notes, SnackBar + dialog** (chosen) | Offline, in the UI language, not disturbing, no server change | One more text to write per release |
| Show the `CHANGELOG.md` section | No extra writing | English only, developer-oriented |
| Fetch the GitHub Release body | Always the published text | Online only, a third party, English only, developer-oriented |
| Dialog at the first start of a new version | Hard to miss | Blocks the start, possibly right before a gig |
| Notes in the ARB files | Existing translation workflow | ARB keys per release pile up; the notes are content, not UI texts |
| Generate the notes from `CHANGELOG.md` | Single source | The changelog has no German and no user wording |

## Consequences

- People learn what changed, in their language, without being interrupted.
- Every release PR writes a few user-facing sentences in two languages; the
  test gate enforces it.
- The website (ADR-0030) shows the same file as a news page, without a second
  source; its header shows the current version.

## Decision log

- 2026-11-19: Proposed (#544), implemented in #546.
- 2026-11-19: Accepted by the owner.
- 2026-11-19: The website (ADR-0030) shows the same notes on a news page
  (`/news/`, `/en/news/`), newest first, with the release date from the
  version's `CHANGELOG.md` section and a link to the full changelog for older
  versions; its header shows the current version (the newest entry) and links
  to that page (#568). The website build fails on a version without a released
  changelog section. Resolves the open point "a news page on the website".

## Open points

- Notes with links into the app (e.g. "open the new setting").
