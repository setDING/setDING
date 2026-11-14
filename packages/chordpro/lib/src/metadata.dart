/// Metadata in texts: `%{name}`, `%{name|true|false}`, `%{name=value|…}`.
library;

/// Looks up all values of a metadata item; empty if it has none.
typedef MetaLookup = List<String> Function(String name);

/// Separator for items with several values.
const metadataSeparator = ', ';

/// Replaces metadata references in [text] (ChordPro "Using metadata in
/// texts"). Supports conditionals, `=` comparison, `%{}` for the
/// controlling value, `name.1`/`name.-1` for single values and `\` escapes.
String substituteMetadata(String text, MetaLookup lookup) {
  if (!text.contains('%{') && !text.contains(r'\')) return text;
  return _Substituter(text, lookup).run();
}

class _Substituter {
  _Substituter(this.text, this.lookup);

  final String text;
  final MetaLookup lookup;
  var pos = 0;

  String run() => _sequence(null, controlling: null);

  /// Reads text until one of [stops] at nesting level 0 (or the end).
  String _sequence(Set<String>? stops, {required String? controlling}) {
    final out = StringBuffer();
    while (pos < text.length) {
      final c = text[pos];
      if (c == r'\' && pos + 1 < text.length) {
        out.write(text[pos + 1]);
        pos += 2;
        continue;
      }
      if (stops != null && stops.contains(c)) break;
      if (c == '%' && pos + 1 < text.length && text[pos + 1] == '{') {
        pos += 2;
        out.write(_reference(controlling));
        continue;
      }
      out.write(c);
      pos++;
    }
    return out.toString();
  }

  /// Parses `name[=value][|true[|false]]}` after `%{`.
  String _reference(String? outerControlling) {
    // Name (may be empty for %{}).
    final nameStart = pos;
    while (pos < text.length && !'=|}'.contains(text[pos])) {
      pos++;
    }
    final name = text.substring(nameStart, pos).trim();
    String? compare;
    if (pos < text.length && text[pos] == '=') {
      pos++;
      compare = _sequence(const {'|', '}'}, controlling: outerControlling);
    }

    final value = name.isEmpty ? (outerControlling ?? '') : _value(name);
    final hasBranches = pos < text.length && text[pos] == '|';
    String? trueText;
    String? falseText;
    if (hasBranches) {
      pos++;
      trueText = _sequence(const {'|', '}'}, controlling: value);
      if (pos < text.length && text[pos] == '|') {
        pos++;
        falseText = _sequence(const {'}'}, controlling: value);
      }
    }
    if (pos < text.length && text[pos] == '}') pos++;

    final condition = compare != null ? value == compare : value.isNotEmpty;
    if (!hasBranches) return compare != null ? (condition ? value : '') : value;
    return condition ? (trueText ?? '') : (falseText ?? '');
  }

  String _value(String name) {
    final dot = RegExp(r'^(.*)\.(-?\d+)$').firstMatch(name);
    if (dot != null) {
      final values = lookup(dot.group(1)!);
      final index = int.parse(dot.group(2)!);
      final i = index < 0 ? values.length + index : index - 1;
      return i >= 0 && i < values.length ? values[i] : '';
    }
    return lookup(name).join(metadataSeparator);
  }
}
