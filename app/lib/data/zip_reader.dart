import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Most files an archive to import may hold (ADR-0043, #1244): far more
/// than a backup of a large library, far fewer than a ZIP bomb.
const maxZipEntries = 50000;

/// Largest file in an archive to import (#1244): more than an attachment
/// (`maxAttachmentBytes`) or the manifest of a large library.
const maxZipEntryBytes = 64 * 1024 * 1024;

/// Most bytes all files of an archive to import may have together (#1244).
const maxZipBytes = 1024 * 1024 * 1024;

/// How much larger than the archive its files may be together beyond
/// [maxZipEntryBytes] (#1244): songs and attachments compress far less, a
/// ZIP bomb far more.
const maxZipRatio = 100;

/// An archive whose files are too many or too large to import: a ZIP bomb
/// or something else than an archive of setDING or of ChordPro files
/// (#1244). Nothing of it is read.
class ArchiveTooLargeException implements Exception {
  const ArchiveTooLargeException();

  @override
  String toString() => 'The archive has too many or too large files';
}

/// The files of [zip] (no folders) as (name, bytes), in archive order.
///
/// Throws [ArchiveTooLargeException] before anything is decompressed if
/// the archive has more than [maxZipEntries] files, a file over
/// [maxZipEntryBytes] or more than [maxZipBytes] together, or more than
/// [maxZipEntryBytes] plus [maxZipRatio] times its own size together. The declared sizes are what
/// the decoder decompresses at most, so a file that lies about its size
/// throws instead of growing. A damaged archive (no ZIP, a broken
/// directory, a wrong checksum) throws what the decoder throws.
/// Names stay as they are in the archive; nothing is written anywhere.
List<(String, Uint8List)> readZipFiles(Uint8List zip) {
  final files = [
    // A damaged archive is refused, not read in part (#1244).
    for (final entry in ZipDecoder().decodeBytes(zip, throwOnError: true).files)
      if (entry.isFile) entry,
  ];
  if (files.length > maxZipEntries) throw const ArchiveTooLargeException();
  final budget = min(maxZipBytes, maxZipEntryBytes + maxZipRatio * zip.length);
  var total = 0;
  for (final entry in files) {
    // A zip64 size over 2^63 reads as negative, without a limit.
    if (entry.size < 0 || entry.size > maxZipEntryBytes) {
      throw const ArchiveTooLargeException();
    }
    total += entry.size;
    if (total > budget) throw const ArchiveTooLargeException();
  }
  return [
    for (final entry in files) (entry.name, Uint8List.fromList(entry.content)),
  ];
}
