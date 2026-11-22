# ADR-0027: Personal settings synced with the account

- **Status:** Accepted
- **Date:** 2026-11-17

## Context

ADR-0006 splits what a person sees into layers. Layer 3 (personal overlays per
song) is synced with the account since ADR-0020. Layer 4 (device settings) is
stored locally per device in `SharedPreferences` (`AppSettings`,
`app/lib/settings/settings.dart`) and never leaves the device.

Many of these settings belong to the person, not to the device:

- A bassist uses `bass` as the instrument and `alto` as their voice
  (conditional directives, ADR-0012) on every tablet.
- Chord notation B/H, Nashville numbers and the chord display style
  (ADR-0003, ADR-0022) are a matter of how a person reads music.
- A singer shows lyrics only, everywhere.

Today a person sets all of this again on every device, and on the web client
(ADR-0018) after every sign-in, because signing out there deletes the local
data. On shared devices (music schools, churches; ADR-0020) the next person
sees the previous person's instrument and notation.

Other settings really depend on the device: the font size and the number of
columns depend on the screen size, the black live appearance on an OLED
screen, the sync mode on the network, the server URL on the installation.
Syncing those would make a phone look wrong after the tablet was adjusted.

The user must be able to see clearly which settings are synced and which are
not.

## Decision

1. **Two fixed scopes.** Layer 4 is split into
   - **4a personal settings**: belong to a person, synced with the account;
   - **4b device settings**: belong to the device, never synced.

   Every setting has exactly one scope, fixed in the code. There is no switch
   per setting and no per-device override of a personal setting.

2. **Classification** (current settings):

   | Setting (`AppSettings`) | Scope | Reason |
   |---|---|---|
   | `instrument`, `bassStrings`, `userName` | personal | Instrument (with the strings of a bass) and voice of the person (ADR-0012) |
   | `notation`, `nashville` | personal | How the person reads chords (ADR-0003) |
   | `chordStyle`, `chordSuperscript` | personal | Chord spelling (ADR-0022) |
   | `displayMode` | personal | Lyrics and chords vs. lyrics only |
   | `chorusRepeat`, `diagrams` | personal | Musical preference |
   | `setProgress` | personal | Preference for live mode, not screen-dependent |
   | `themeMode`, `accent` | personal | Taste; `system` still follows the device |
   | `language` | personal | Language of the person (changes ADR-0008) |
   | `fontSize` | device | Depends on the screen size |
   | `columns`, `autoFit`, `pageTurn` | device | Depend on the screen size and orientation |
   | `liveAppearance` | device | Black is meant for OLED screens |
   | `serverUrl`, `syncMode` | device | Installation and network |
   | Drummer settings (ADR-0026): click on/off, accent on 1, sound, start, duration, count-in bars | personal | How the drummer plays |
   | Drummer settings (ADR-0026): click volume, latency compensation | device | Depend on the audio output of the device (wired, USB, Bluetooth) |

   UI state stored in `SharedPreferences` outside `AppSettings` (selected band
   and library, song sort, collapsed past sets, `demoSeeded`, the overlay
   adoption flag) stays per device.

3. **One registry in the code.** Each setting is declared once with its key,
   default and scope (`SettingScope.personal | device`). Storage, sync and the
   scope indicators in the UI are derived from it; a test fails if a setting
   has no scope. `AppSettings` stays the combined view, so the rest of the app
   does not change.

4. **Visible in the settings.**
   - The category list is grouped under the headings *Personal – on all your
     devices* and *This device*, followed by *Account & organization* (account
     and sync, organizations and bands), which is neither. Categories are cut
     so that none mixes both scopes (the live mode category keeps the device
     settings, the progress bar moves to display). The personal group starts
     with *General* (language and theme), followed by the most used
     categories. In developer mode a last group *Development* lists the
     *Test features*.
   - Each category of a scope starts with one line explaining it; personal
     settings carry a cloud icon, device settings a device icon.
   - Signed out, the personal heading says that the settings stay on this
     device and are synced after signing in.
   - All texts in both ARB files (ADR-0008).

5. **Owner, as for overlays (ADR-0020).** Personal settings are stored per
   owner: the user ID when signed in, `local` when signed out. Signing out
   switches back to the `local` values, so on a shared device nobody gets the
   previous person's settings. The web client works the same way; its local
   data is deleted on sign-out anyway.

6. **First sign-in on a device.**
   - The server has no settings for the user: the current `local` values are
     copied to the user and uploaded (the first device brings its settings
     along).
   - The server has settings: they win, the device takes over the person's
     settings, and a message says so. Values changed in `local` before the
     sign-in are kept under `local`.

7. **Sync.**
   - Server collection `user_settings`: `user` (unique), `data` (JSON object
     of the personal settings), `revision`, `updated_by`, `updated`. The
     record ID is a UUID v5 of the user, so two devices never create two
     records (as for overlays). Private: only the user may list, view, create
     and update their record; nobody else, also not organization admins.
     Not a field on `users`, because members of an organization can read
     each other's user records.
   - Client: a Drift table `user_settings` (`owner_id`, `data`, `dirty_keys`,
     `revision`); device settings stay in `SharedPreferences`. Changes go
     through the outbox; the pull is a delta pull with the user as scope
     (ADR-0004), in a new `SettingsSync` in `app/lib/sync/engine/`.
   - **Last writer wins per key**, not per record: the client pushes only the
     changed keys and a server hook merges them into `data`. Two devices that
     change different settings offline keep both changes. Pulled keys that
     are dirty locally are skipped and pushed afterwards.
   - Forward compatibility: unknown keys (from a newer app version) are kept
     and pushed back unchanged; an unknown value shows the default locally
     but does not overwrite the server.
   - Synced settings that arrive during live mode are applied after leaving
     it (ADR-0007, no sync changes what is displayed on stage).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Fixed personal/device scopes** (proposed) | Clear rule, easy to show, little UI | A person cannot keep a different value on one device |
| Sync all settings | Simplest | Font size and columns of a tablet break the phone; server URL and sync mode make no sense across devices |
| Switch per setting ("sync this") | Most flexible | Many decisions for the user; hard to understand which value wins; more UI and state |
| Personal value with an optional override per device | Flexible, still a clear default | Two values per setting, override state has to be shown everywhere; can be added later if needed |
| Store settings as a field on `users` | No new collection | Visible to the members of the organizations; no revision for delta pull |
| Last writer wins per record | Simpler server | Changes of two offline devices to different settings get lost |

## Consequences

- Layer 4 of ADR-0006 becomes 4a (personal, synced) and 4b (device); see the
  ADR-0006 decision log.
- The language becomes personal (ADR-0008 decision log); `USER.locale` is no
  longer needed as a default for new devices.
- New server migration with access rules and a merge hook for
  `user_settings`, tested against a real PocketBase (ADR-0015).
- Local schema change: table `user_settings`; on upgrade the current values
  of the personal settings move from `SharedPreferences` to the owner
  `local`, then take part in the first-sign-in rule above.
- The settings screen is regrouped; widget tests check the scope headings and
  icons.
- Adding a setting now requires choosing its scope.

## Decision log

- 2026-11-17: Proposed (#328). Renumbered from 0026 before the merge, as ADR-0026 (drummer mode, #325) was merged first; its settings added to the classification.
- 2026-11-17: Accepted by the owner as proposed. Resolved open points: the
  language is a personal setting (ADR-0008 decision log); theme and accent
  colour are personal, the live appearance stays per device; no per-device
  override of a personal setting in the first version (can be added later
  if needed).
- 2026-11-17: Implemented (#338). Details:
  - Storage as decided (owner choice: Drift table, not `SharedPreferences`):
    table `user_settings` (schema 15), loaded into memory before the UI
    (`UserSettingsStore`, `app/lib/settings/user_settings_store.dart`), so
    language and theme are known from the first frame; writes go through to
    the table in order. The first start moves the personal values out of
    `SharedPreferences` to the owner `local`.
  - The scopes are declared in `AppSettings.scopes`; a test fails if a
    setting has none. The server URL got its own provider, because the
    backend depends on it and the personal settings depend on the user
    signed in through that backend.
  - Sync in `app/lib/sync/engine/settings_sync.dart`; the server record ID is
    a UUID v5 of the user. "Settings taken over from the account" is shown
    as a message after the sync that replaced them.
  - Settings screen: the account category stays on top; below it the groups
    *Personal – on all your devices* (general, musician, display) and *This
    device* (screen & live mode, storage & info). The scope icon (cloud or
    device) is on the group heading and on the explanation line at the top
    of each category, not on every single setting. Font size moved to the
    device category *Screen & live mode*; chorus repeat and the progress bar
    moved to display.
  - The drummer settings of ADR-0026 do not exist yet; they get their scope
    when they are added (see the classification above).
- 2026-11-17: The drummer settings of ADR-0026 added (#334) as classified above; beat display, edge flash, subdivisions and song map are personal too. Choices that follow the instrument until set (beat display, edge flash, click, start, song map) are left out of the JSON while unset, so an unset choice on one device does not override a choice synced from another.

- 2026-11-19: Settings screen reordered (#548), replacing "the account category stays on top": the account and the organizations and bands are set up once and rarely opened afterwards, so they moved to the bottom under their own heading *Account & organization*. Order: *Personal* (display, song display, musician, general), *This device* (screen & live mode, storage & info), *Account & organization* (account & sync, organization & bands). The wide layout preselects the first category (display) instead of the account.
- 2026-11-19: *General* moved to the top of the personal group (#554), where it is expected: General, Display, Song display, Musician. The wide layout still preselects the first category, now General.
- 2026-11-19: Developer mode (#559): test and diagnostic tools such as the MIDI test (ADR-0039) moved out of *Screen & live mode* into their own category *Test features* under a last heading *Development*, listed only while the personal setting *Developer mode* in *General* is on (default off), so they do not irritate normal users. The category has no scope of its own and starts with a note that its features are experimental, may change or disappear and are not meant for performances. Switching developer mode off while the category is open shows the first category again.
- 2026-11-22: `bassStrings` (4 or 5 strings of a bass, #940) is personal, like the instrument.

## Open points

- None.
