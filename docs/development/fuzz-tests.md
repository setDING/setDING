# Fuzz tests

Everything another person can send is an attack surface: ChordPro text, import
archives and attachments (issue #1244). Fuzz tests feed these parts with random
and damaged input and check that they never throw an unhandled error, never hang
and keep the properties they promise.

## What is fuzzed

| Area | Test | Properties |
|---|---|---|
| ChordPro parser (`packages/chordpro`) | `packages/chordpro/test/fuzz_test.dart` | Mutated example songs (`docs/examples/**/*.cho`, the feature showcase first) and random text: parsing, validation, fixes, conversions, editor functions, ABC, LilyPond and markup never throw and take at most 2 s per input; the highlighting tokens cover the text without gaps; metadata that is set reads back the same; a parsed chord reads back the same, also transposed |
| Archive import (`app/lib/data/zip_reader.dart`, `backup.dart`, `import_export.dart`, the song and set archives) | `app/test/archive_fuzz_test.dart` | Damaged, cut and mutated archives (the example archives and archives of every kind made in the test, also with a damaged `manifest.json`) are read or refused, never more: previews and imports never throw, nothing is written outside the attachment folder; ZIP bombs, path traversal, odd, long and duplicate names |
| Sync (ADR-0004) | `app/test/sync_convergence_test.dart` | Four simulated devices of three people (organization admin with two devices, band admin, member) make random changes to songs (create, edit, delete, restore, conflicts), sets (create, rename, items, delete, restore), attachments (PDFs and images: add, rename, delete, restore, purge, upload again) and personal adjustments, go offline and online and sync in random order, while the fake server fails requests (network, 500, 503, 429), loses answers after storing the change and refuses attachment changes for good. After a final round: every device's songs, sets, attachments and files agree with the server, nothing is left in the outbox, refused changes were reported (#1225, #1229), and personal adjustments stay with their person. Open decisions (ADR-0004) are left out: refused song, set and adjustment changes are not injected, and set items of songs that were deleted at some time are not compared |
| Attachment type detection (`attachmentTypeOf`, `contentMatchesType`) | `app/test/attachment_storage_test.dart` | Truncated magic bytes, polyglots and SVG prologs; the SVG cases mirror what the server's type detection accepts, which `server/test/image_attachments_test.dart` pins |

## Seeds and iterations

The seeds are fixed, so every run checks the same inputs and a failure can be
reproduced; the failing input is printed (URL-encoded for text). `make check` runs
the tests with few inputs, a few seconds per area.

A longer run raises the inputs per test with `FUZZ_ITERATIONS`:

```bash
make fuzz                         # 10000 inputs per test
make fuzz FUZZ_ITERATIONS=100000  # longer
FUZZ_ITERATIONS=50000 dart test test/fuzz_test.dart   # in packages/chordpro
```

A failure found this way becomes a named regression test at the lowest level
(see `docs/development/git-workflow.md`), not a change of the seed.

The sync test counts operations, not scenarios: each scenario (one seed) is 60
random operations, so `FUZZ_ITERATIONS=10000` runs 166 scenarios (a few
seconds per 100); without it, 10 scenarios. A failure prints the seed and the
operation log, with the errors the server gave; run that scenario alone with
`SYNC_FUZZ_SEED`:

```bash
SYNC_FUZZ_SEED=1300 flutter test test/sync_convergence_test.dart   # in app/
```

## Limits of an archive import

`readZipFiles` (`app/lib/data/zip_reader.dart`) refuses an archive before it
decompresses anything if it has more than 50,000 files, a file over 64 MB, or
more than 1 GB, or 64 MB plus 100 times its own size, together
(`ArchiveTooLargeException`, ADR-0043); a damaged archive (also a wrong
checksum) is refused instead of read in part. A ChordPro ZIP that cannot be read
is listed as skipped in the import report; a backup shows a message.
