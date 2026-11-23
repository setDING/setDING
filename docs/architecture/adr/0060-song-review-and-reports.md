# ADR-0060: Song review status and mistake reports

- **Status:** Accepted
- **Date:** 2026-11-23

## Context

Songs reach the library mostly through an **import** of ChordPro files (ADR-0011,
#314): from SongSelect, from other apps, from old collections. An imported song
looks finished, but often is not: wrong chords, a missing verse, a key that does
not match the recording, a sequence that the band plays differently. Today
nothing says whether anybody has looked at a song since the import. The
warning icon (`validateChordPro`) and the magic wand (`countChordProConversions`)
only find what a program can find; a wrong chord is valid ChordPro.

The people who **notice** mistakes are mostly not the people who **fix** them.
A member sees a wrong chord in rehearsal or on stage, but may not edit the song
(ADR-0023); the librarian who may edit it was not there. Today the mistake is
passed on by word of mouth, or forgotten after the rehearsal.

The owner's idea (2026-11-23): a song status that says "needs a check", set
after an import with the comment "After import", so somebody looks at the
import, corrects it and approves it; and every person, also a member, can report
a mistake in a song with a comment, so somebody looks at it.

Forces:

- **Offline-first** (ADR-0001): reports are written in the rehearsal room and on
  stage, often without a network, and on several devices at once. Two reports of
  the same song must both survive.
- **Song conflicts** (ADR-0004, ADR-0015): a change of a song's content is pushed
  with its base revision and may become a conflict. Approving a song must not
  conflict with somebody's edit of its text.
- **Permissions on the server** (owner rule #632, ADR-0023): who may report,
  approve and resolve is enforced by the server rules and tested through the API.
- **No layout is fixed** (ADR-0032): a position on the screen of the reporter
  means nothing on the librarian's device (other font size, columns,
  transposition, capo, personal settings).
- **Live mode** (ADR-0007): reporting must take a few taps and must not stop
  the performance.

## Decision

### 1. Two things: a review status on the song, and reports

- The **review status** is one value per song: *to review* or *approved*
  (no value = approved, so every existing song stays as it is). *To review*
  carries a short **reason** (free text, e.g. "After import").
- A **report** is one entry in a list per song: who, when, category, comment,
  where in the song, an optional screenshot, and whether it is open or resolved.

A song **needs attention** when it is *to review* or has at least one open
report. A single status field with a comment was rejected: a second report would
overwrite the first, and two people reporting offline would lose one of them.

### 2. Review status: fields of the song, last writer wins

Server collection `songs` gets `review_state` (`""` | `to_review`),
`review_reason` (text, at most 200 characters), `reviewed_by` and `reviewed_at`
(who set the current state and when).

Like the language version fields of ADR-0053, the review fields are pushed **on
their own** from the outbox (outbox collection `song_review`, record ID
`<song>`), without a base revision, and do not change `content_revision`: an
approval is never a sync conflict with an edit of the text, and approving a band
leader's own song leaves it theirs (ADR-0023). A pulled review value never
replaces one still in the outbox.

**What sets *to review*** automatically (owner decision):

- An **import of ChordPro or text files** (single files and ZIPs, including files
  from SongSelect, ADR-0011) sets every **new** song to *to review* with the
  reason "After import" (in the language of the importing person's UI). A song
  the import **replaces** with new text is set to *to review* too; a song the
  import reuses unchanged keeps its state.
- **Not**: archive imports (backup, set and song archives, ADR-0043), which
  carry the state the songs had in the archive; songs written by hand in the
  editor; edits of existing songs; copies of a song into another library
  (ADR-0017) keep the state of the original.

Whoever may approve can also set a song to *to review* by hand, with a reason.

**Approving** is an explicit action (*Approve*), never a side effect of saving:
the person who fixes a mistake may need several edits. Approving a song does not
resolve its open reports, and resolving the last report does not approve it;
the approve action offers to resolve the open reports in the same step.

### 3. Reports: a new collection

Server collection `song_reports` (new migration, ADR-0015):

| Field | Content |
|---|---|
| `song` | relation to the song (cascade on purge) |
| `organization` | the song's organization, for the rules and the delta pull |
| `author` | the reporting user, must be the requester on create |
| `category` | `chords` \| `lyrics` \| `key` \| `sequence` \| `tempo` \| `formatting` \| `sheet_music` \| `other` |
| `comment` | text, at most 1000 characters, may be empty when a screenshot is attached |
| `location` | JSON: section label and occurrence, source line, live page and whether a PDF attachment (and which page) was shown; filled by the client |
| `screenshot` | optional file (see 4) |
| `status` | `open` \| `resolved` \| `withdrawn` |
| `resolution` | text of the person who resolved it, at most 1000 characters |
| `resolved_by`, `resolved_at` | who resolved it and when |
| `revision`, `deleted`, `purged` | as for every synced collection |

The record ID is a UUID created on the device, so a report written offline is
created exactly once. Records are **append-mostly**: the author writes the
report, the resolver writes the resolution; two people never edit the same
field, so last writer wins per record is enough. The delta pull follows the
organization like songs.

Reports are kept as **history** (owner decision): a resolved report stays with
the song, folded away. Deleting a song moves its reports to the trash with it and
restoring the song restores them (ADR-0043); purging the song purges them and
their screenshots.

### 4. Screenshot with own markings

A report may carry **one screenshot** of what the reporter sees, with their own
markings on it (owner decision):

- *Attach screenshot* takes the current view (song view or live page, ChordPro
  or PDF) as an image in the client (`RepaintBoundary.toImage`, on every
  platform including web). The person marks the place with the pen and
  highlighter of the freehand annotations (ADR-0032), reused as a widget; the
  markings are **burnt into the image**, not stored as strokes.
- The image is scaled to at most 1600 px on the long side and stored as PNG
  (Flutter encodes it without a further dependency; screenshots of chords and
  lyrics have few colours and keep sharp text), scaled down further until it
  fits 1 MB (server limit on the file field). See the decision log of
  2026-11-23 (#991).
- A real image is chosen over strokes anchored in the song because it shows
  exactly what the reporter saw, with their font size, transposition, capo and
  personal settings; this also shows when the mistake is in a personal overlay
  (ADR-0006) and not in the song. It works for PDF sheet music too.
- Screenshot files are immutable like attachments (ADR-0009): uploaded with the
  report from the outbox, also later when the report was written offline, and
  downloaded on demand when a report is opened (not for offline use in live
  mode). The report itself syncs without waiting for the upload.
- The screenshot is part of the report and visible to the same people. It never
  contains more than the reporter's own screen of that song.

### 5. Permissions (ADR-0023)

New rows of the permission matrix, enforced by the server rules of `songs` and
`song_reports` and tested through the API:

| Action | Org admin | Librarian | Band leader | Set planner | Member |
|---|:-:|:-:|:-:|:-:|:-:|
| Report a mistake in a song of the organization | ✓ | ✓ | ✓ | ✓ | ✓ |
| See the reports of a song | ✓ | ✓ | ✓ | ✓ | own reports |
| Withdraw (or edit while open) an own report | the author | | | | |
| Approve a song, set it to review, resolve reports | ✓ | ✓ | own songs² | – | – |

² as in ADR-0023: whoever may edit the song. A member sees the review status of
every song (decision 6) and their own reports with the answer, not the reports of
others; band leaders and set planners see all reports, so they know before a gig
that a song in their set was reported.

The server sets `author` to the requester and refuses a create for another
person; refuses changes of `author`, `song`, `organization`, `category`,
`location` and `screenshot` after the create except by the author while the
report is open; and allows `status`, `resolution`, `resolved_by` and
`resolved_at` only to people who may approve the song (`withdrawn` only to the
author). `reviewed_by` and `resolved_by` are set by a hook, never by the client.

### 6. User interface

All texts in de-CH and en (ADR-0008); the shared widgets of ADR-0051.

- **Song list** (`song_list.dart`, both the library and the set's song picker):
  a discreet icon at the end of a song that needs attention, **for everyone**
  (owner decision): a song *to review* or with open reports. A member reads it
  as "not checked yet, maybe something is wrong".
- ***To do*** (ADR-0045) and the song list chips, only for people who may
  approve: *To review* and *Reported*, each with its count, opening the song
  list filtered to those songs. The filtered list *To review* offers *Approve
  all* (with Undo).
- **Song view**: a tonal banner under the title for people who may approve
  (*To review: After import*, *2 open reports*) with *Show* and *Approve*;
  members see a short hint only. The reports are listed in a `SidePanel`:
  category, comment, location (a tap jumps to the place in the song or the
  editor), the screenshot as a thumbnail that opens full size, and *Resolve*
  with an answer field.
- **Reporting** (owner decision): *Report a mistake* in the menu of the song
  view and in the live control bar. A sheet with the category chips, the
  comment, the location filled from where the person is (section and page, or
  the PDF page) and *Attach screenshot* (off by default, a tap opens the
  marking view). In live mode the sheet does not stop the set; it closes with
  *Send* or the page turner.
- **Answer to the reporter**: when a report of the person is resolved, the
  next sync shows it **once** as a message ("Your report on *Song* was resolved:
  …"), never in live mode; the report stays readable in the song's panel.
- **Sets**: the set view and the set editor show a hint when a set with a gig
  date from today on contains songs that need attention, with the number of
  songs; the printable set list (ADR-0013) is unchanged.

### 7. Local library

The local library (ADR-0001, `local` owner) has one person, who may do
everything: the review status works the same (an import sets *to review*), and
reports can be written as notes to oneself, without permissions and without
sync. The screenshot is stored in the app's files.

### 8. Versioning

The new fields and the new collection are ignored by older clients, so this is a
**minor** release (ADR-0028); no minimum client version change (ADR-0029).
Older clients that import songs do not set *to review*.

## Alternatives considered

| Option | Pros | Cons |
|---|---|---|
| **Review status on the song plus a list of reports** (chosen) | No report lost, also offline; status and reports answer different questions; approving needs no base revision | Two concepts to explain; a new collection |
| One status field with a comment | Simplest | A second report overwrites the first; offline reports get lost |
| Reports only, the import writes a report "After import" | One concept | An import of 200 songs writes 200 reports; approving a song is resolving a report nobody wrote |
| Review fields pushed with the song's content and base revision | No new outbox kind | Approving while somebody edits becomes a sync conflict |
| Approving and resolving also for band leaders of the playing bands | They know the song in practice | Breaks ADR-0023: the song belongs to the organization; they can report and edit their own songs |
| Every way of creating a song sets *to review* | Nothing unchecked slips through | A hand-written song was checked by its author; archives carry already checked songs; edits would flag everything all the time |
| Review status visible only to people who may approve | Members see nothing they cannot act on | Members do not know that a song is not checked yet |
| Report location as strokes anchored to source lines (ADR-0032) | Small, layout-independent | Imprecise on another layout; does not show the reporter's view, personal settings or PDF pages |
| Screenshot always attached | More information | Larger uploads; often not needed for "chord in bar 3 is G, not Em" |
| Change proposals (the reporter edits a copy, the librarian merges a diff) | Fix arrives with the report | Much more work; members cannot edit the text today; can follow later |
| Resolved reports deleted after some time | Less storage | The owner wants the history |
| Repertoire status per band (new, rehearsing, ready, resting) | Planning aid | Not wanted (owner decision); a property of the band, not the song's content |
| Blocking unchecked songs from sets or live mode | Forces a check | Offline-first and stage use must never be blocked |

## Consequences

- An import no longer looks finished: the librarian gets a work list of imported
  songs, and nobody has to remember which songs were checked.
- Mistakes noticed by members reach the people who can fix them, with a place
  and a picture, also when they were noticed offline on stage.
- Set planners see before a gig whether their set contains reported songs.
- Server: new fields on `songs`, a new collection `song_reports` with a file
  field, rules, hooks (author, resolver, trash and purge cascade) and API tests;
  the permission matrix of ADR-0023 gets the rows of decision 5.
- Client: schema change (songs review fields, `song_reports` table, outbox kinds
  `song_review` and `song_reports`), sync of a new collection with an
  uploaded file, the import, *To do*, song list, song view, live mode, set view;
  the screenshot capture and the marking view reuse the annotation widgets.
- Archives (ADR-0043) carry the review fields; whether they carry reports is an
  open point.
- The website gets a page on checking songs and reporting mistakes, with
  screenshots of the banner, the report sheet and the panel (de and en).
- Storage grows with screenshots (at most 1 MB each); resolved reports are kept.

## Decision log

- 2026-11-23: Proposed after a discussion with the owner (#985). Owner
  decisions: status and reports separate; approve and resolve by whoever may
  edit the song; only file imports set *to review*; everyone sees a discreet
  icon, *To do* only for approvers; report with comment, category and location
  plus an optional screenshot with own markings; reporting from the song view and
  live mode; resolved reports kept as history; no repertoire status per band.
- 2026-11-23: Accepted by the owner (#985); the rows of decision 5 added to the
  permission matrix of ADR-0023. Implementation split into #987 (server), #988
  (data and sync), #989 (review after import and approving), #990 (reporting and
  resolving), #991 (screenshot with markings) and #992 (website page).
- 2026-11-23: Server implemented (#987): migration `1797000000_song_review.js`,
  hooks `song_reports.pb.js`, `lib/songs.js`, `lib/trash.js`. Details settled
  there: an approved song has no reason; a screenshot may be added after the
  create (a report written offline uploads it later) but never replaced, and
  the author's other fields are open to changes only while the report is open;
  an approver may reopen a resolved report; reports cannot be created on a
  deleted song; a purged song leaves its reports as tombstones without text,
  location and screenshot; a deleted account leaves its reports without an
  author (ADR-0052).
- 2026-11-23: Client data and sync implemented (#988): schema 37 with the
  review columns on `songs` and the table `song_reports` (no foreign key on the
  song, removed where songs are removed for good), `SongReviewRepository`
  (`lib/data/song_review.dart`), the outbox collections `song_review` (pushed
  after the songs, last writer wins like the link fields, a pending local value
  wins over a pulled one) and `song_reports` (`ReportSync`: the reporter sends
  category, comment and location, the resolver the answer, both the status; a
  refused change gives way to the server version at the next run), screenshots
  in the attachment storage as `report-<id>.<ext>`, downloaded when a report is
  opened; archives carry `reviewState` and `reviewReason` and set them again on
  import.
- 2026-11-23: Review in the app implemented (#989): the file import sets the
  imported songs to review with "After import" in the importer's language
  (`ImportExportService.importFiles(reviewReason:)`); the song list (library and
  set picker) shows an icon to everyone, the reported one before the one to
  review; *To do* lines and chips *To review* and *Reported* (`SongAttention`)
  for whoever may edit the song, *Approve all* with Undo in the list filtered to
  *To review*; in the song view a banner for approvers (reason, open reports,
  *Approve*, which asks whether to resolve the open reports too) and a short
  hint for everyone else, *Mark for review …* and *Approve* in the song menu;
  the set list and the set show how many songs of an upcoming set need a check.
  The reported icon is `report_outlined`, since set markers use the flag.
- 2026-11-23: Reporting and resolving implemented (#990): *Report a mistake …*
  in the song menu (everyone), a button in the live control bar and *Report a
  mistake* in the reports panel open a sheet with the category chips, the
  comment and the place (the live page; section, line or PDF page when given);
  in the sheet a page turner sends the report once a category is chosen and
  cancels otherwise, not while the comment is typed. The song view gets a
  reports button with the number of open reports and a `SidePanel` (open ones
  first, resolved and withdrawn ones folded away; *Withdraw* for the author,
  *Resolve* with an answer and *Reopen* for whoever may edit the song). After a
  sync outside live mode the reporter is told once that a report was resolved
  by someone else, with the answer; the seen answers are kept per device, and
  on the first run answers already there count as seen.
- 2026-11-23: Screenshot implemented (#991). Owner decision: **PNG instead of
  WebP/JPEG**, since Flutter writes PNG without a dependency and no pure Dart
  package writes WebP. The view is taken from a `RepaintBoundary` around the
  song view and the live pages before the report sheet opens, and attached only
  on *Attach a screenshot*; a marking screen draws with pen or highlighter using
  the stroke painting of the annotations (`paintStrokes`), with undo, and burns
  the strokes into the image. The reports panel shows a thumbnail, loaded (and
  downloaded once) when shown, full size on a tap.

## Open points

- Do song and backup archives (ADR-0043) carry the reports and their
  screenshots, or only the review fields?
- Should a person be notified outside the app (e-mail) about new reports? Not
  planned; the overview and the sync messages are the channel.
- Change proposals by members (a suggested text with a diff) as a later
  extension.
- Limits against abuse: a maximum number of open reports per person and song,
  rate limits of the server (ADR-0004).
