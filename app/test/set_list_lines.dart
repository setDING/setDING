import 'package:setding/ui/sets/set_list.dart';

/// [list] as readable lines for tests: the header, then one line per song
/// (number, title, key and sequence) and per marker, as a divider.
String describeSetList(SetList list) {
  final out = StringBuffer()..writeln(list.name);
  if (list.details case final details?) out.writeln(details);
  out.writeln();
  for (final row in list.rows) {
    switch (row) {
      case SetListMarker(:final text):
        out.writeln('— $text —');
      case SetListSong(
        :final number,
        :final title,
        :final key,
        :final sequence,
      ):
        out.writeln('$number. ${[title, ?key, ?sequence].join(' – ')}');
    }
  }
  return out.toString();
}
