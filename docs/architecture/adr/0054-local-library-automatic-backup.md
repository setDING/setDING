# ADR-0054: Automatic backup of the local library

- **Status:** Proposed
- **Date:** 2026-11-22

## Context

The local library "On this device" (ADR-0005) is never synced: its songs, sets
and attachments exist only on one device. ADR-0043 gave it a backup archive, a
full backup in the settings and a reminder after 30 days without a backup, but
**no automatic backups**, and an import **always as a copy** with new IDs. So
a lost or replaced tablet loses everything since the last manual backup, and
moving the library to a new device means importing copies.

Other chord apps offer backup or sync to the user's own storage (WebDAV,
OneDrive, Dropbox). People who start alone, before they play in a band with an
organization (ADR-0017), expect at least that their library is safe in their
own cloud storage. The owner's own experience shows the other side: a private
WebDAV sync of such an app grew into the band's server, run by one person,
without roles, permissions or conflict handling. That is what organizations
and the server sync (ADR-0004) are for.

The local library is mainly the way into setDING; using several devices with
one library is meant to go through an organization later (when the server is
open to everyone, ADR-0024). Many people who play only in organizations never
use the local library and still see it everywhere.

Constraints: offline-first (ADR-0001); the archive format of ADR-0043 is a
public interface; ChordPro stays the single source of truth (ADR-0003); the
settings layout of ADR-0050; the web client has no local library (ADR-0018);
external libraries must have an MIT-compatible licence.

## Decision

### 1. Automatic backup of the local library

An **optional automatic backup** writes the backup archive of the local
library (ADR-0043 section 1, format version 1) into a **folder the person
chooses**. It is a device setting, **off by default**, on the native apps
only.

- **Folder:** chosen with the operating system's folder picker. Cloud storage
  comes through the operating system, setDING talks to **no storage provider
  itself**: on Android a folder of any document provider that offers folders
  (e.g. Nextcloud, OneDrive, Dropbox), with a persisted permission; on iOS a
  folder in the Files app (iCloud Drive and other providers), kept with a
  security-scoped bookmark; on Windows and Linux any folder, e.g. one that the
  OneDrive, Dropbox or Nextcloud client syncs.
- **Content:** only the local library: songs, attachments, the sets and
  arrangements of its band, the personal adjustments and annotations on its
  songs. Everything else (organizations, own adjustments in organizations,
  personal settings) is already on the server.
- **File name:** `setDING-Backup <device> <yyyy-mm-dd HHmm>.zip`. The device
  name defaults to the operating system's device name and can be changed in the
  setting, so several devices can write into the same folder without
  overwriting each other.
- **When:** at most **once a day** and only when the local library changed
  since the last automatic backup; checked at the start and when the app goes
  to the background (where the platform lets it finish), never in live mode and
  never during another import or export. **Back up now** writes one at once.
- **Safe writing:** the archive is written under a temporary name and renamed
  when complete, so a sync client never uploads half a file.
- **Keeping:** the newest **10** automatic backups of this device stay in the
  folder; older ones of this device are deleted. Other files are never
  touched.
- **Errors:** when the folder is not reachable or the permission was lost, the
  app shows a hint at the start (at most once a day, never in live mode) with
  an action to choose the folder again. The setting shows the last automatic
  backup and the last error.
- **Reminder:** the reminder of ADR-0043 (30 days without a backup) is not
  shown while automatic backups succeed; an automatic backup counts as the
  last backup of the local library.
- Works signed in and signed out; it needs no server.

### 2. Restoring by replacing the local library

Importing a backup archive of a **local library** (the manifest's source, also
the local library's folder of a full backup) into the local library offers two
ways:

- **Add as a copy**, as before (ADR-0043).
- **Replace the local library:** the whole local library is replaced by the
  backup, **with the original IDs**. This is the way to move to a new device
  or to go back to an earlier state.

Replacing:

- A **preview** shows the backup (device, date) and what is replaced (songs
  and sets now and in the backup); it is confirmed like every destructive
  action (`confirm()`, ADR-0051).
- **Safety backup first:** before anything is removed, the current local
  library is saved as a backup archive: into the automatic backup folder when
  one is set, otherwise to a place the person chooses; the person can skip it
  explicitly.
- The songs, attachments, sets, arrangements, personal adjustments and
  annotations of the local library, and its trash, are **removed on the
  device**; then the records of the archive are written with their IDs.
  Language version groups (ADR-0053) come with the songs. The play history of
  the local band stays for the songs that are in the backup.
- Settings are not changed (the full backup restores them on request, as
  before).
- **Only the local library.** Organizations stay "import as a copy": their
  records have server revisions, rights and other people's changes
  (ADR-0043). The local library is never synced, so its IDs only need to be
  unique on the device.

### 3. Showing the local library

A device setting **Show the local library** (on by default) lets people who
play only in organizations hide it:

- It can be switched off **only when signed in**, also when the library is
  not empty; the person decides. Signed out, the local library is always
  shown (the setting stays as it is).
- **Switching off** shows a hint with the number of songs and sets that stay
  on the device and come back when the setting is switched on again; when the
  automatic backup is on, the hint adds that it keeps running and can be
  switched off in the settings.
- Hidden, the local library does not appear in the library switcher, on the
  overview, in the song and set lists, as a target of imports or as the source
  of "copy from the local library". New songs go to the current organization.
- The data is not changed; the full backup and the automatic backup still
  include it. The backup reminder of ADR-0043 is not shown while it is hidden.

Both settings are in *Storage & info → Storage & backup* (ADR-0050).

### Not done: sync through the user's own storage

No sync of the local library through WebDAV, Dropbox, OneDrive or other
storage. Several devices with one library are a case for an organization and
the server sync (ADR-0004).

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Automatic backup into a folder chosen through the operating system** (chosen) | No provider code, no OAuth; every provider the platform knows; same archive as the manual backup; data stays with the person | Depends on the provider's document integration (e.g. folders of Google Drive on Android); no background backups on iOS |
| Sync of the local library through WebDAV, Dropbox or OneDrive | Several devices without an account, like other apps | A second sync engine on a store without revisions, rights or realtime; turns a private store into a band server; provider-specific code and OAuth |
| Backup through the providers' APIs | Works where the platform has no folder integration | OAuth apps and client IDs per provider, Google's verification, code per provider |
| Automatic full backup (format version 2) | One file for everything | Organization data is already on the server; needs the mandatory sync first; larger files |
| Restore by replacing also for organizations | One way for all libraries | Conflicts with revisions, rights and other people's changes (ADR-0043) |
| Replaced records into the trash instead of a safety backup | Restorable in the app | The restored records have the same IDs as those in the trash |
| Hide the local library only when it is empty | Nothing can be forgotten | Takes the decision from the person; no song could be created in it while hidden |

## Consequences

- A lost or replaced device no longer loses the local library, if the
  automatic backup is on; a new device gets the exact library back.
- Platform code or a library for writing into a folder of a document provider
  (Android Storage Access Framework, iOS security-scoped bookmarks) is needed,
  with an MIT-compatible licence.
- Two new device settings and an import path that removes the local library;
  the import of the backup archive gets a second mode.
- Code that lists libraries, import targets and the overview has to respect the
  hidden local library.
- ADR-0043 no longer holds "No automatic backups" and "import always as a
  copy" for the local library; its decision log says so.
- Several devices with one library stay a case for organizations, to be
  decided with the opening of the server (ADR-0024).

## Decision log

- 2026-11-22: Proposed (#832). Owner decisions: an automatic backup of the
  local library only, as an option; folder through the operating system, no
  provider APIs; restoring by replacing the whole local library with a
  question; a setting to hide the local library, also when it is not empty,
  with a hint that names the automatic backup; no sync through WebDAV,
  Dropbox or OneDrive.

## Open points

- Library or platform code for folders of document providers on Android and
  iOS; which providers offer folders (Google Drive on Android).
- Whether the number of kept backups (10) should be a setting.
- Size of large PDF libraries in a daily archive (ADR-0043: archives zipped in
  memory).
