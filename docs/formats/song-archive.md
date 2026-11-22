# Song archive format (`setding-songs`)

Reference for the ZIP file that setDING writes with **Export …** → **setDING archive (ZIP)**
and reads with the normal song import (ADR-0043 §1c). Use it to write song archives
from other tools, for example an exporter from another song database, that
setDING imports with its preview.

Source of truth is the code: `app/lib/data/song_archive.dart` (export, read,
import) and `app/lib/data/backup.dart` (shared song and attachment import). The
example manifest below is imported by a test (`app/test/song_archive_test.dart`,
"the documented example archive imports"), so this reference and the importer stay
in sync.

## ZIP layout

One archive holds **one or several songs**, and every song **any number of
attachments** (none, one or several). The example archive holds three songs:

```text
setDING-Songs 2026-11-21.zip
├── manifest.json
├── songs/
│   ├── Amazing Grace (7012345).cho
│   └── Morning Song (7054321).cho
└── attachments/
    ├── Amazing Grace (7012345) - Lead Sheet.pdf
    ├── Amazing Grace (7012345) - Vocal Sheet.pdf
    ├── Morning Song (7054321) - Chord Chart.png
    └── Only a Score (7098765) - Score.pdf
```

- **`manifest.json`** at the root of the ZIP is required. The importer finds every
  other file only through the paths in the manifest.
- **Paths** are relative to the ZIP root, with `/` as separator (`\` is converted
  to `/` when reading). They are compared **exactly and case-sensitive**. Entries in
  `__MACOSX/` and folder entries are ignored. setDING itself writes
  `songs/<title> (<short id>).cho` and
  `attachments/<title> (<short id>) - <attachment name><ext>`, but the importer does
  not care about the names; any path that the manifest points to works.
- **Compression:** stored or deflated (standard ZIP).
- **Encoding:** `manifest.json` and `.cho` files are UTF-8, without BOM.
- **File name** of the ZIP: free, but it must end in `.zip` to be recognised by the
  import. setDING uses the song title for one song and `setDING-Songs <yyyy-mm-dd>.zip`
  for several.

## `manifest.json`

### Top level

| Field | Type | Required | Meaning |
|---|---|---|---|
| `format` | string | yes | Always `"setding-songs"`. Any other value: the ZIP is not read as a song archive. |
| `formatVersion` | integer | yes | `1`. A higher number is refused with a message ("made by a newer setDING"). |
| `songs` | array | yes | The songs, in the order shown in the preview. Must be an array (may be empty). |
| `options` | object | **yes, in practice** | What the archive holds, see below. Without `"attachments": true` **no attachments are imported**. |
| `app` | string | no | Version of the writing app; informational. |
| `createdAt` | string | no | ISO 8601 time in UTC; informational. |
| `source` | object | no | `{ "id": string, "name": string }` of the library the songs come from. `name` is shown in the import preview. |
| `band` | object | no | `{ "id": string, "name": string }`, the band whose arrangements the archive holds. Only with `arrangements`. |
| `arrangements` | array | no | Band arrangements per song, see below. |
| `overlays`, `annotations` | array | no | The exporting person's own adjustments and annotations (ADR-0006, ADR-0032). Internal format of the backup archive; external tools leave them out. |

Unknown fields are ignored, so a newer minor addition does not change
`formatVersion`.

### `options`

| Field | Type | Meaning |
|---|---|---|
| `attachments` | boolean | The archive holds attachments. Must be `true` for them to be imported. |
| `arrangements` | boolean | The archive holds band arrangements (`arrangements`, `band`). |
| `personal` | boolean | The archive holds personal adjustments and annotations. |

Only the literal value `true` counts; a missing field or any other value is
`false`. The import takes what the archive holds **and** the person chooses in
the preview.

### `songs[]`

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique within the archive. Links attachments and arrangements to the song, and finds a song that already exists with this ID in the target library (a song exported from setDING). External tools use a stable ID of their own, for example `"ccli-<number>"`. |
| `title` | string | yes | Title. Used to find an existing song and for the preview; for a new song only if the ChordPro text has no `{title}`. |
| `artist` | string | no | Artist; same rules as `title`. |
| `file` | string | no | Path of the ChordPro file in the ZIP. Without it (or if the file is missing) the song is imported **without text**, for example a song that only has a PDF. |
| `attachments` | array | no | The song's attachments, see below. |
| `language` | string | no | Language of the song set by hand (ADR-0053): `de`, `gsw` (Swiss German), `en`, `fr`, `it`, `es`, `pt`, `nl` or `other`. Another value is ignored; without it setDING detects the language from the lyrics. |
| `workId` | string | no | Group of language versions (ADR-0053): songs of the archive with the same `workId` are translations or adaptations of one work and are linked again on import. Any string that is the same for the versions, for example `"amazing-grace"`. |

### `songs[].attachments[]`

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique within the archive. Used by personal annotations on the attachment; otherwise only an identifier. |
| `name` | string | yes | Name shown in setDING (for example "Lead Sheet"). Also decides whether an existing song already has the attachment, see below. |
| `file` | string | yes | Path of the file in the ZIP. Its **extension decides the type**: `.pdf`, or an image (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`). Without an extension the file is taken as PDF. |
| `pages` | integer | no | Number of pages of a PDF; stored as metadata. Leave it out if unknown. |

Limits: an attachment larger than **20 MiB** is skipped without an error, as is one
whose `file` is not in the ZIP.

### `arrangements[]` (optional)

Key, sequence and tempo of a band for a song (ADR-0025). They go to the band the
person picks in the preview.

| Field | Type | Meaning |
|---|---|---|
| `songId` | string | `id` of a song in `songs`. |
| `transpose` | integer | Semitones, for example `-2`. |
| `sequence` | string | Optional sequence of the parts. |
| `tempo` | integer | Optional tempo in BPM. |

## Several songs and several attachments

- `songs` lists every song of the archive; there is no limit on their number. The
  import preview shows them in this order and imports them one after the other.
- Each song lists **its own** attachments in `attachments`. An attachment belongs
  to the song whose entry lists it; the folder or file name does not matter.
- `file` paths must be unique within the ZIP: two attachments that are different
  files need different paths. Two songs with the same title therefore need
  different paths too; setDING adds the short song ID, and on a clash ` (2)`,
  ` (3)` … before the extension.
- `id` values must be unique across the whole archive (songs and attachments).
- Each song is matched and imported on its own (next section): in one import some
  songs may be new, others already exist and only get their missing attachments.
- Several attachments of one song should have **different `name`s**; an existing
  song only gets attachments whose name it does not have yet.

## How the import treats the songs

1. **Matching:** an archive song is the same as an existing song of the target
   library if it has the same `id`, else the same `title` and `artist` (ignoring
   case and surrounding spaces).
2. **Same text** (the ChordPro text is identical, also after setDING has added
   missing `{title}` and `{artist}` directives): the existing song is used.
3. **Different text:** the preview lets the person keep the existing song or add
   the archive's song as an additional one.
4. **New songs** are created with a new ID, their ChordPro text and their
   attachments. Title and artist come from the ChordPro directives, else from the
   manifest.
5. **Existing songs get the attachments they lack:** an archive attachment whose
   `name` the existing song does not have (ignoring case and surrounding spaces) is
   added, if the person may edit the song. Existing attachments are never replaced.

6. **Language versions** (`workId`): the **new** songs with the same `workId` are
   linked as language versions under a new group of the target library. They are
   never linked with songs that were already there, also not with an existing song
   that is used instead of an identical one; a new song alone in its group stays
   unlinked. `language` is set on new songs only; existing songs keep theirs.

So an exporter can be run again with new PDFs: existing songs keep their text and
get the new attachments, as long as each attachment has a new `name`.

The import needs the right to create songs in the library (ADR-0023); it is
offered in the song import (**Import** in the song list).

## The ChordPro file

The `.cho` file is the song in [ChordPro](https://www.chordpro.org/) as described
in ADR-0003 and ADR-0012. Write at least `{title: …}` and, if known,
`{artist: …}`; keys, tempo and other metadata go into their usual directives
(`{key: …}`, `{tempo: …}`, `{ccli: …}`, `{copyright: …}`). setDING-specific
directives start with `x_`.

A ChordPro file **downloaded from CCLI SongSelect** can be put into the archive
unchanged: setDING reads its structure (`{comment: …}` section headings, the
`[|] [.]` chord grid, `{ccli}`, `{ccli_license}`, the footer lines), see
`packages/chordpro/lib/src/songselect.dart`.

## Example manifest

The example holds three songs:

- "Amazing Grace" with ChordPro text, **two** PDFs and its language,
- "Morning Song" with ChordPro text and an image,
- "Only a Score" without text, with only a PDF.

It is the file
[`song-archive-manifest.example.json`](song-archive-manifest.example.json):

```json
{
  "format": "setding-songs",
  "formatVersion": 1,
  "app": "ccli-export 0.1.0",
  "createdAt": "2026-11-21T10:00:00.000Z",
  "source": { "id": "ccli", "name": "CCLI SongSelect" },
  "options": { "attachments": true, "arrangements": false, "personal": false },
  "songs": [
    {
      "id": "ccli-7012345",
      "title": "Amazing Grace",
      "artist": "John Newton",
      "language": "en",
      "file": "songs/Amazing Grace (7012345).cho",
      "attachments": [
        {
          "id": "ccli-7012345-lead",
          "name": "Lead Sheet",
          "file": "attachments/Amazing Grace (7012345) - Lead Sheet.pdf",
          "pages": 2
        },
        {
          "id": "ccli-7012345-vocal",
          "name": "Vocal Sheet",
          "file": "attachments/Amazing Grace (7012345) - Vocal Sheet.pdf",
          "pages": 3
        }
      ]
    },
    {
      "id": "ccli-7054321",
      "title": "Morning Song",
      "artist": "Some Band",
      "file": "songs/Morning Song (7054321).cho",
      "attachments": [
        {
          "id": "ccli-7054321-chart",
          "name": "Chord Chart",
          "file": "attachments/Morning Song (7054321) - Chord Chart.png"
        }
      ]
    },
    {
      "id": "ccli-7098765",
      "title": "Only a Score",
      "artist": "Some Writer",
      "attachments": [
        {
          "id": "ccli-7098765-score",
          "name": "Score",
          "file": "attachments/Only a Score (7098765) - Score.pdf"
        }
      ]
    }
  ]
}
```

A matching `songs/Amazing Grace (7012345).cho`:

```chordpro
{title: Amazing Grace}
{artist: John Newton}
{key: G}
{ccli: 7012345}

[G]Amazing [G7]grace, how [C]sweet the [G]sound
```

## Checklist for writers

- `manifest.json` at the ZIP root, UTF-8, `format` `"setding-songs"`,
  `formatVersion` `1`.
- `options.attachments` set to `true` if there are attachments.
- Every `id` (songs and attachments) is a unique string.
- Every `file` matches a ZIP entry exactly, with `/` and the same case.
- Attachments are `.pdf` or a supported image, at most 20 MiB each.
- The ZIP file name ends in `.zip`.
