import 'package:chordpro/chordpro.dart' as cp;

import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../widgets/dialogs.dart';
import '../widgets/key_picker.dart';

/// Separator between title, key and sequence of a song line.
const setListSeparator = ' – ';

/// One row of a set list, shared by the text and PDF export.
sealed class SetListRow {
  const SetListRow();
}

/// A song with its number in the set, key for this set and sequence.
class SetListSong extends SetListRow {
  const SetListSong(this.number, this.title, {this.key, this.sequence});

  final int number;
  final String title;
  final String? key;
  final String? sequence;
}

/// A pause or text item.
class SetListMarker extends SetListRow {
  const SetListMarker(this.text, {required this.pause});

  final String text;
  final bool pause;
}

/// The header and rows of a set list.
class SetList {
  const SetList(this.name, this.details, this.rows);

  final String name;

  /// Date and venue, e.g. `21 Jun 2027 · Bern`; null if neither is set.
  final String? details;
  final List<SetListRow> rows;
}

/// Builds the set list: songs are numbered and get the key for this set
/// (band arrangement and set transposition, ADR-0025, ADR-0006) and their
/// sequence (set-specific, from the band or from the song); pauses and text
/// items become markers.
SetList buildSetList(
  SetlistEntry set,
  List<SetItemView> items, {
  Map<String, BandArrangement> arrangements = const {},
  required cp.ChordNotation notation,
  required String Function(DateTime date) formatDate,
  required String untitled,
  required String songMissing,
}) {
  final details = [
    if (set.gigDate case final date?) formatDate(date),
    if (set.venue case final venue? when venue.trim().isNotEmpty) venue.trim(),
  ];
  final rows = <SetListRow>[];
  var number = 0;
  for (final view in items) {
    final item = view.item;
    if (item.type != SetItemType.song) {
      final note = item.note?.trim() ?? '';
      if (note.isNotEmpty) {
        rows.add(SetListMarker(note, pause: item.type == SetItemType.pause));
      }
      continue;
    }
    number++;
    final song = view.song;
    if (song == null) {
      rows.add(SetListSong(number, songMissing));
      continue;
    }
    final band = arrangements[song.id];
    final transpose = (band?.transpose ?? 0) + item.transpose;
    final base = song.songKey == null ? null : cp.Key.tryParse(song.songKey!);
    final key = base != null
        ? base.transpose(transpose).format(notation)
        : (normalizeSemitones(transpose) == 0
              ? null
              : formatSemitones(transpose));
    rows.add(
      SetListSong(
        number,
        song.title.isEmpty ? untitled : song.title,
        key: key,
        sequence:
            item.sequence ??
            band?.sequence ??
            cp.findSequence(song.chordproSource),
      ),
    );
  }
  return SetList(set.name, details.isEmpty ? null : details.join(' · '), rows);
}

/// Plain-text set list: a header (name, date, venue) and one line per song
/// with its title, key and sequence; pauses and text items get their own
/// lines.
///
/// ```
/// Summer Festival
/// 21 Jun 2027 · Bern
///
/// 1. Late Train Home – A – V1, C, V2, C x2
/// — Break —
/// 2. Blue Monday Groove – Bb
/// ```
String setListText(SetList list) {
  final out = StringBuffer()..writeln(list.name);
  if (list.details case final details?) out.writeln(details);
  out.writeln();
  for (final row in list.rows) {
    switch (row) {
      case SetListMarker(:final text, :final pause):
        out.writeln(pause ? '— $text —' : text);
      case SetListSong(
        :final number,
        :final title,
        :final key,
        :final sequence,
      ):
        out.writeln(
          '$number. ${[title, ?key, ?sequence].join(setListSeparator)}',
        );
    }
  }
  return out.toString();
}
