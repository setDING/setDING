import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chordpro/chordpro.dart' as cp;
import 'package:path/path.dart' as p;

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

/// Result of an import.
class ImportResult {
  const ImportResult(this.imported, this.skipped);

  final int imported;
  final List<String> skipped;
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

    Future<void> importOne(String name, Uint8List bytes) async {
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
        await songs.createSong(
          source: parts[i],
          title: parts.length == 1 ? base : '$base (${i + 1})',
        );
        imported++;
      }
    }

    for (final file in files) {
      if (p.extension(file.name).toLowerCase() == '.zip') {
        final archive = ZipDecoder().decodeBytes(file.bytes);
        for (final entry in archive.files) {
          if (!entry.isFile) continue;
          final base = p.basename(entry.name);
          if (base.startsWith('.') || entry.name.contains('__MACOSX')) continue;
          await importOne(base, Uint8List.fromList(entry.content));
        }
      } else {
        await importOne(file.name, file.bytes);
      }
    }
    return ImportResult(imported, skipped);
  }

  /// A ChordPro file for a single song.
  Uint8List exportSong(SongEntry song) =>
      Uint8List.fromList(utf8.encode(_sourceWithMeta(song)));

  String songFileName(SongEntry song) => '${safeFileName(song.title)}.cho';

  /// Exports a set as ZIP: numbered ChordPro files, PDF attachments and a
  /// plain-text setlist.
  Future<Uint8List> exportSet(SetlistEntry set) async {
    final archive = Archive();
    final items = await sets.getItems(set.id);
    final setlist = StringBuffer('${set.name}\n\n');
    var number = 0;
    for (final view in items) {
      number++;
      final prefix = number.toString().padLeft(2, '0');
      final song = view.song;
      if (view.item.type != SetItemType.song || song == null) {
        setlist.writeln('$prefix  -- ${view.item.note ?? ''} --');
        continue;
      }
      setlist.writeln(
        '$prefix  ${song.title}${song.songKey == null ? '' : ' (${song.songKey})'}',
      );
      final base = '$prefix - ${safeFileName(song.title)}';
      if (song.chordproSource.trim().isNotEmpty) {
        final bytes = utf8.encode(_sourceWithMeta(song));
        archive.addFile(ArchiveFile('$base.cho', bytes.length, bytes));
      }
      for (final attachment in await songs.getAttachments(song.id)) {
        final file = songs.storage.file(attachment.fileName);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile(
            '$base - ${safeFileName(attachment.name)}.pdf',
            bytes.length,
            bytes,
          ),
        );
      }
    }
    final listBytes = utf8.encode(setlist.toString());
    archive.addFile(ArchiveFile('setlist.txt', listBytes.length, listBytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
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

/// Removes characters that are not allowed in file names.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').trim();
  return cleaned.isEmpty ? 'untitled' : cleaned;
}
