import 'package:chordpro/chordpro.dart' as cp;

import '../../data/database.dart';
import '../../data/set_repository.dart';
import '../widgets/dialogs.dart';
import '../widgets/key_picker.dart';
import 'set_item_label.dart';

/// One row of the printable set list (ADR-0013).
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
/// items become markers. A pause without a note of its own shows [pause],
/// the type label in the current language (#289); a text item without text
/// is left out.
SetList buildSetList(
  SetlistEntry set,
  List<SetItemView> items, {
  Map<String, BandArrangement> arrangements = const {},
  required cp.ChordNotation notation,
  required String Function(DateTime date) formatDate,
  required String untitled,
  required String songMissing,
  required String pause,
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
      final note = markerNote(item.type, item.note);
      if (item.type == SetItemType.pause) {
        rows.add(SetListMarker(note ?? pause, pause: true));
      } else if (note != null) {
        rows.add(SetListMarker(note, pause: false));
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
