import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import 'attachment_storage.dart';
import 'database.dart';
import 'set_repository.dart';
import 'song_repository.dart';

/// File extensions recognised as ChordPro files.
const chordProExtensions = ['cho', 'chordpro', 'chopro', 'crd', 'pro', 'txt'];

/// A file selected for import.
class ImportFile {
  const ImportFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// An imported song whose ChordPro source has problems (#314).
typedef ImportProblem = ({
  String songId,
  String title,

  /// Number of problems (`validateChordPro`).
  int count,

  /// At least one of them can be fixed automatically.
  bool fixable,
});

/// Result of an import.
class ImportResult {
  const ImportResult(
    this.imported,
    this.skipped, [
    this.problems = const [],
    this.legacyLabels = const [],
  ]);

  final int imported;
  final List<String> skipped;

  /// Imported songs with ChordPro problems, in import order.
  final List<ImportProblem> problems;

  /// Ids of imported songs with section labels in the short form
  /// `{start_of_verse: Verse 1}` (#672), in import order.
  final List<String> legacyLabels;

  /// Whether the import has something to report beyond the counts.
  bool get needsReview => problems.isNotEmpty || legacyLabels.isNotEmpty;

  ImportResult copyWith({
    List<ImportProblem>? problems,
    List<String>? legacyLabels,
  }) => ImportResult(
    imported,
    skipped,
    problems ?? this.problems,
    legacyLabels ?? this.legacyLabels,
  );
}

/// Decodes text files leniently (UTF-8 with BOM, fallback Latin-1).
String decodeText(Uint8List bytes) {
  var data = bytes;
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = data.sublist(3);
  }
  try {
    return utf8.decode(data);
  } on FormatException {
    return latin1.decode(data);
  }
}

bool _isChordPro(String name) => chordProExtensions.contains(
  p.extension(name).replaceFirst('.', '').toLowerCase(),
);

/// Import and export of ChordPro files and sets.
class ImportExportService {
  ImportExportService(this.songs, this.sets);

  final SongRepository songs;
  final SetRepository sets;

  /// Imports ChordPro files and ZIP archives containing ChordPro files.
  ///
  /// With [germanNotation], chords are converted from H/B to international
  /// notation before saving (ADR-0003).
  Future<ImportResult> importFiles(
    List<ImportFile> files, {
    bool germanNotation = false,
  }) async {
    var imported = 0;
    final skipped = <String>[];
    final problems = <ImportProblem>[];
    final legacyLabels = <String>[];

    Future<void> importOne(
      String name,
      Uint8List bytes, {
      Map<String, (String, Uint8List)> images = const {},
    }) async {
      if (!_isChordPro(name)) {
        skipped.add(name);
        return;
      }
      var text = decodeText(bytes);
      if (germanNotation) text = cp.convertGermanToInternational(text);
      // A file may contain several songs separated by {new_song}.
      final parts = cp.splitChordProSongs(text);
      final base = p.basenameWithoutExtension(name);
      for (var i = 0; i < parts.length; i++) {
        final title = parts.length == 1 ? base : '$base (${i + 1})';
        final id = await songs.createSong(source: parts[i], title: title);
        imported++;
        final found = cp.validateChordPro(parts[i]);
        if (found.isNotEmpty) {
          problems.add((
            songId: id,
            title: cp.parseChordPro(parts[i]).title ?? title,
            count: found.length,
            fixable: found.any(cp.canFixChordProProblem),
          ));
        }
        if (cp.findLegacySectionLabels(parts[i]).isNotEmpty) {
          legacyLabels.add(id);
        }
        // Attach images from the same archive that {image} refers to.
        if (images.isNotEmpty) await _attachImages(id, parts[i], images);
      }
    }

    for (final file in files) {
      if (p.extension(file.name).toLowerCase() == '.zip') {
        final entries = await unzipFiles(file.bytes);
        final images = <String, (String, Uint8List)>{
          for (final (name, bytes) in entries)
            if (isImageFile(name))
              p.basename(name).toLowerCase(): (name, bytes),
        };
        for (final (name, bytes) in entries) {
          if (isImageFile(name)) continue;
          await importOne(name, bytes, images: images);
        }
      } else {
        await importOne(file.name, file.bytes);
      }
    }
    return ImportResult(imported, skipped, problems, legacyLabels);
  }

  /// Fixes the ChordPro problems of [songIds] that can be fixed
  /// automatically (`fixChordProProblems`, #314); returns how many songs
  /// changed.
  Future<int> fixProblems(Iterable<String> songIds) async {
    var fixed = 0;
    for (final id in songIds) {
      final song = await songs.getSong(id);
      if (song == null) continue;
      final source = cp.fixChordProProblems(song.chordproSource);
      if (source == song.chordproSource) continue;
      await songs.updateSource(id, source);
      fixed++;
    }
    return fixed;
  }

  /// Converts the section labels of [songIds] to the attribute form
  /// `{start_of_verse: label="Verse 1"}` (#672); returns how many songs
  /// changed.
  Future<int> convertLegacyLabels(Iterable<String> songIds) async {
    var converted = 0;
    for (final id in songIds) {
      final song = await songs.getSong(id);
      if (song == null) continue;
      final source = cp.convertLegacySectionLabels(song.chordproSource);
      if (source == song.chordproSource) continue;
      await songs.updateSource(id, source);
      converted++;
    }
    return converted;
  }

  Future<void> _attachImages(
    String songId,
    String source,
    Map<String, (String, Uint8List)> images,
  ) async {
    final song = cp.parseChordPro(source);
    final attached = <String>{};
    for (final line in song.sections.expand((s) => s.lines)) {
      if (line is! cp.ImageLine) continue;
      final key = p
          .basename((line.src ?? '').replaceAll(r'\', '/'))
          .toLowerCase();
      final image = images[key];
      if (image == null || !attached.add(key)) continue;
      if (image.$2.length > maxAttachmentBytes) continue;
      await songs.addAttachment(
        songId,
        name: image.$1,
        bytes: image.$2,
        extension: p.extension(image.$1).replaceFirst('.', ''),
      );
    }
  }

  /// A ChordPro file for a single song.
  Uint8List exportSong(SongEntry song) =>
      Uint8List.fromList(utf8.encode(_sourceWithMeta(song)));

  String songFileName(SongEntry song) => '${safeFileName(song.title)}.cho';

  /// Exports a set as ZIP: numbered ChordPro files, PDF attachments and a
  /// plain-text setlist. [markerTitle] names pauses and text items in the
  /// setlist (the UI passes the localized label, #289); by default their
  /// note.
  Future<Uint8List> exportSet(
    SetlistEntry set, {
    String Function(SetItemEntry item)? markerTitle,
  }) async {
    final files = <(String, Uint8List)>[];
    final items = await sets.getItems(set.id);
    final setlist = StringBuffer('${set.name}\n\n');
    var number = 0;
    for (final view in items) {
      number++;
      final prefix = number.toString().padLeft(2, '0');
      final song = view.song;
      if (view.item.type != SetItemType.song || song == null) {
        final marker = view.item.type != SetItemType.song;
        final name =
            (marker ? markerTitle?.call(view.item) : null) ??
            view.item.note ??
            '';
        setlist.writeln('$prefix  -- $name --');
        continue;
      }
      setlist.writeln(
        '$prefix  ${song.title}${song.songKey == null ? '' : ' (${song.songKey})'}',
      );
      final base = '$prefix - ${safeFileName(song.title)}';
      if (song.chordproSource.trim().isNotEmpty) {
        files.add(('$base.cho', utf8.encode(_sourceWithMeta(song))));
      }
      for (final attachment in await songs.getAttachments(song.id)) {
        final file = songs.storage.file(attachment.fileName);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final ext = isPdfFile(attachment.fileName)
            ? '.pdf'
            : p.extension(attachment.fileName);
        final stem = isPdfFile(attachment.fileName)
            ? attachment.name
            : p.basenameWithoutExtension(attachment.name);
        files.add(('$base - ${safeFileName(stem)}$ext', bytes));
      }
    }
    files.add(('setlist.txt', utf8.encode(setlist.toString())));
    return compute(_zip, files);
  }

  String setFileName(SetlistEntry set) => '${safeFileName(set.name)}.zip';

  /// Adds title/artist directives for songs whose source lacks them.
  String _sourceWithMeta(SongEntry song) {
    final source = song.chordproSource;
    final parsed = cp.parseChordPro(source);
    final header = StringBuffer();
    if (parsed.title == null && song.title.isNotEmpty) {
      header.writeln('{title: ${song.title}}');
    }
    if (parsed.artist == null && song.artist != null) {
      header.writeln('{artist: ${song.artist}}');
    }
    return header.isEmpty ? source : '$header$source';
  }
}

/// The files of a ZIP archive as (base name, bytes), without folders, hidden
/// files and macOS metadata; decoded outside the UI isolate.
Future<List<(String, Uint8List)>> unzipFiles(Uint8List zip) =>
    compute(_unzip, zip);

List<(String, Uint8List)> _unzip(Uint8List zip) => [
  for (final entry in ZipDecoder().decodeBytes(zip).files)
    if (entry.isFile &&
        !p.basename(entry.name).startsWith('.') &&
        !entry.name.contains('__MACOSX'))
      (p.basename(entry.name), Uint8List.fromList(entry.content)),
];

Uint8List _zip(List<(String, Uint8List)> files) {
  final archive = Archive();
  for (final (name, bytes) in files) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Removes characters that are not allowed in file names.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').trim();
  return cleaned.isEmpty ? 'untitled' : cleaned;
}
