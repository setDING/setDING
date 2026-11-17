import 'package:path/path.dart' as p;

import 'attachment_storage.dart';
import 'database.dart';

/// Finds the image attachment that a ChordPro `{image: src=…}` refers to.
///
/// Images are matched by file name (case-insensitive), with or without
/// extension; directories in [src] are ignored (ADR-0012).
AttachmentEntry? imageAttachmentFor(
  List<AttachmentEntry> attachments,
  String src,
) {
  final wanted = p.basename(src.replaceAll(r'\', '/')).toLowerCase();
  final wantedStem = p.basenameWithoutExtension(wanted);
  AttachmentEntry? stemMatch;
  for (final a in attachments) {
    if (!isImageFile(a.fileName)) continue;
    final name = a.name.toLowerCase();
    final withExt = '$name${p.extension(a.fileName).toLowerCase()}';
    if (name == wanted || withExt == wanted) return a;
    if (p.basenameWithoutExtension(name) == wantedStem) stemMatch ??= a;
  }
  return stemMatch;
}

/// The PDF that live mode shows for a song, or null for its ChordPro text
/// (ADR-0006, ADR-0009).
///
/// [liveView] is the personal choice (an attachment ID, null for ChordPro).
/// A choice that is no longer a PDF attachment of the song falls back to
/// ChordPro; a song without ChordPro content ([hasChordPro] false) falls back
/// to its first PDF. The song screen, the set view and live mode share this
/// rule.
AttachmentEntry? livePdfFor(
  List<AttachmentEntry> attachments,
  String? liveView, {
  required bool hasChordPro,
}) {
  final pdfs = [
    for (final a in attachments)
      if (isPdfFile(a.fileName)) a,
  ];
  if (liveView != null) {
    final chosen = pdfs.where((a) => a.id == liveView).firstOrNull;
    if (chosen != null) return chosen;
  }
  return hasChordPro ? null : pdfs.firstOrNull;
}
