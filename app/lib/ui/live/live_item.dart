import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../sets/set_item_label.dart';

/// One entry of the live sequence.
class LiveItem {
  const LiveItem.song(
    SongEntry this.song, {
    this.arrangement,
    this.setTranspose = 0,
    this.setSequence,
    this.setItemId,
    this.attachmentId,
  }) : type = SetItemType.song,
       icon = null,
       label = null;

  const LiveItem.marker(this.icon, this.label)
    : type = SetItemType.marker,
      song = null,
      arrangement = null,
      setTranspose = 0,
      setSequence = null,
      setItemId = null,
      attachmentId = null;

  final SetItemType type;
  final SongEntry? song;

  /// The band's arrangement of the song (ADR-0025): key, sequence and tempo
  /// between the song and the set item. For a single song only its
  /// sequence (#552).
  final BandArrangement? arrangement;

  /// The band's key as semitones relative to the song.
  int get bandTranspose => arrangement?.transpose ?? 0;

  /// Transposition from the set item (layer 2, ADR-0006).
  final int setTranspose;

  /// Song sequence from the set item (layer 2, ADR-0006).
  final String? setSequence;

  /// The set item this entry comes from; null when a single song is played.
  final String? setItemId;

  /// A PDF attachment to show instead of the personal live view choice,
  /// when an attachment is opened from the song screen (#507). The choice
  /// itself is not changed.
  final String? attachmentId;
  final String? label;

  /// Key of a marker's icon (ADR-0047).
  final String? icon;

  LiveItem withSetTranspose(int value) => LiveItem.song(
    song!,
    arrangement: arrangement,
    setTranspose: value,
    setSequence: setSequence,
    setItemId: setItemId,
    attachmentId: attachmentId,
  );

  /// The song title, or the name of a marker: its own text, otherwise its
  /// icon's name in the current language (#289, ADR-0047).
  String title(AppLocalizations l10n) => song == null
      ? markerTitle(l10n, icon, label)
      : (song!.title.isEmpty ? l10n.untitled : song!.title);
}
