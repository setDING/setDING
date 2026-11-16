/// Reading and changing metadata directives in the ChordPro source text,
/// for forms that edit e.g. the title or key without the user searching for
/// the directive (the text stays the source of truth, ADR-0003).
library;

import 'directive_names.dart';

/// A metadata directive found in the source: [start]/[end] cover the value.
class _Found {
  const _Found(this.lineStart, this.lineEnd, this.start, this.end);

  /// The line including its line break.
  final int lineStart;
  final int lineEnd;
  final int start;
  final int end;
}

final _directiveLine = RegExp(
  r'^([ \t]*\{[ \t]*([A-Za-z_][\w-]*)(?:[ \t]*:[ \t]*|[ \t]+|(?=\})))'
  r'([^}\n]*)\}[ \t]*$',
);
final _metaValue = RegExp(r'^([A-Za-z_][\w-]*)(?:[ \t]+|$)');
final _newSong = RegExp(r'^[ \t]*\{[ \t]*(new_song|ns)[ \t]*\}');

/// Walks the lines of the first song in [source] (up to `{new_song}`).
Iterable<(int, int, String)> _lines(String source) sync* {
  var pos = 0;
  while (pos < source.length) {
    final lineEnd = source.indexOf('\n', pos);
    final end = lineEnd < 0 ? source.length : lineEnd;
    final line = source.substring(pos, end);
    if (pos > 0 && _newSong.hasMatch(line)) return;
    yield (pos, end, line);
    pos = lineEnd < 0 ? source.length : lineEnd + 1;
  }
}

String _canonical(String name) =>
    metaDirectiveAliases[name.toLowerCase()] ?? name.toLowerCase();

_Found? _find(String source, String name) {
  for (final (start, end, line) in _lines(source)) {
    final m = _directiveLine.firstMatch(line);
    if (m == null) continue;
    final directive = m.group(2)!.toLowerCase();
    var value = m.group(3)!;
    var valueStart = start + m.group(1)!.length;
    if (directive == 'meta') {
      final meta = _metaValue.firstMatch(value);
      if (meta == null || _canonical(meta.group(1)!) != name) continue;
      valueStart += meta.end;
      value = value.substring(meta.end);
    } else if (_canonical(directive) != name) {
      continue;
    }
    final trimmed = value.trimRight();
    final lineEnd = end < source.length ? end + 1 : end;
    return _Found(start, lineEnd, valueStart, valueStart + trimmed.length);
  }
  return null;
}

/// Value of the first directive for metadata [name] (e.g. `title`, also
/// written as `{t: …}` or `{meta: title …}`) in the first song of
/// [source]; null when there is none.
String? sourceMetadata(String source, String name) {
  final found = _find(source, _canonical(name));
  if (found == null) return null;
  return source.substring(found.start, found.end).trim();
}

/// Offset after the header of [source]: the directive lines at the top,
/// before the first empty line, other text or section.
int metadataHeaderEnd(String source) {
  final header = RegExp(
    r'^[ \t]*\{(?!start_of|so[a-z]\b|new_song)[^}]*\}[ \t]*$',
  );
  for (final (start, _, line) in _lines(source)) {
    if (line.trim().isEmpty || !header.hasMatch(line)) return start;
  }
  return source.length;
}

/// Sets metadata [name] to [value] in [source]: the value of an existing
/// directive is replaced in place, a missing one is added at the end of the
/// header as `{name: value}`, and an empty [value] removes the directive.
String setSourceMetadata(String source, String name, String? value) {
  final canonical = _canonical(name);
  final text = value?.trim() ?? '';
  final found = _find(source, canonical);
  if (found == null) {
    if (text.isEmpty) return source;
    final pos = metadataHeaderEnd(source);
    final prefix = pos > 0 && source[pos - 1] != '\n' ? '\n' : '';
    return source.replaceRange(pos, pos, '$prefix{$canonical: $text}\n');
  }
  if (text.isEmpty) {
    return source.replaceRange(found.lineStart, found.lineEnd, '');
  }
  // `{key}` without a separator needs one before the new value.
  final needsSeparator =
      found.start == found.end &&
      source[found.start - 1] != ':' &&
      source[found.start - 1] != ' ';
  return source.replaceRange(
    found.start,
    found.end,
    needsSeparator ? ': $text' : text,
  );
}
