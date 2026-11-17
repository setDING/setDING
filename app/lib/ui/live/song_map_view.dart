import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../render/song_header.dart' show SongSequenceView;
import '../render/song_style.dart' show StageColors;

/// The song map of the drummer mode (ADR-0026): instead of the chord
/// sheet, the parts as played, each with a cue from the lyrics and the
/// drum notes of its section.
class SongMapView extends StatelessWidget {
  const SongMapView({
    super.key,
    required this.entries,
    this.scale = 1.0,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final List<SongMapEntry> entries;

  /// Personal font scale (ADR-0006).
  final double scale;
  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          l10n.songMapEmpty,
          key: const Key('song-map-empty'),
          style: theme.textTheme.titleMedium,
        ),
      );
    }
    return SingleChildScrollView(
      key: const Key('song-map'),
      controller: controller,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, entry) in entries.indexed)
            _SongMapBlock(key: Key('song-map-$i'), entry: entry, scale: scale),
        ],
      ),
    );
  }
}

class _SongMapBlock extends StatelessWidget {
  const _SongMapBlock({super.key, required this.entry, required this.scale});

  final SongMapEntry entry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final notes = theme.extension<StageColors>()?.chord ?? scheme.tertiary;
    TextStyle? scaled(TextStyle? style) => style?.copyWith(
      fontSize: style.fontSize == null ? null : style.fontSize! * scale,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: SongSequenceView.background(scheme, entry.part.part),
            width: 8,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SongSequenceView.partName(l10n, entry.part),
            style: scaled(text.headlineSmall)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (entry.cue case final cue?)
            Text(
              '„$cue“',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: scaled(text.titleMedium)
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          for (final note in entry.notes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note,
                style: scaled(text.titleLarge)
                    ?.copyWith(color: notes, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
