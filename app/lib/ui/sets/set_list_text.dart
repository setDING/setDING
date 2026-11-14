import 'package:chordpro/chordpro.dart' as cp;

import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../widgets/dialogs.dart';
import '../widgets/key_picker.dart';

/// Separator between title, key and sequence of a song line.
const setListSeparator = ' – ';

/// Plain-text set list: a header (name, date, venue) and one line per song
/// with its title, the key for this set (set transposition, ADR-0006) and
/// the sequence (set-specific or from the song). Pauses and text items
/// appear as their own lines.
///
/// ```
/// Summer Festival
/// 21 Jun 2027 · Bern
///
/// 1. Late Train Home – A – V1, C, V2, C x2
/// — Break —
/// 2. Blue Monday Groove – Bb
/// ```
String setListText(
  SetlistEntry set,
  List<SetItemView> items, {
  required cp.ChordNotation notation,
  required String Function(DateTime date) formatDate,
  required String untitled,
  required String songMissing,
}) {
  final out = StringBuffer()..writeln(set.name);
  final details = [
    if (set.gigDate case final date?) formatDate(date),
    if (set.venue case final venue? when venue.trim().isNotEmpty) venue.trim(),
  ];
  if (details.isNotEmpty) out.writeln(details.join(' · '));
  out.writeln();

  var number = 0;
  for (final view in items) {
    final item = view.item;
    if (item.type != SetItemType.song) {
      final note = item.note?.trim() ?? '';
      if (note.isNotEmpty) {
        out.writeln(item.type == SetItemType.pause ? '— $note —' : note);
      }
      continue;
    }
    number++;
    final song = view.song;
    if (song == null) {
      out.writeln('$number. $songMissing');
      continue;
    }
    out.writeln(
      '$number. ${setListLine(song, item, notation: notation, untitled: untitled)}',
    );
  }
  return out.toString();
}

/// Title, key and sequence of one song in a set, in one line.
String setListLine(
  SongEntry song,
  SetItemEntry item, {
  required cp.ChordNotation notation,
  required String untitled,
}) {
  final base = song.songKey == null ? null : cp.Key.tryParse(song.songKey!);
  final key = base != null
      ? base.transpose(item.transpose).format(notation)
      : (normalizeSemitones(item.transpose) == 0
            ? null
            : formatSemitones(item.transpose));
  final sequence = item.sequence ?? cp.findSequence(song.chordproSource);
  return [
    song.title.isEmpty ? untitled : song.title,
    ?key,
    ?sequence,
  ].join(setListSeparator);
}
