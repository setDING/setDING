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
