import 'package:chordpro/chordpro.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Title, artist and key/capo/tempo of a song.
class SongHeader extends StatelessWidget {
  const SongHeader({
    super.key,
    required this.title,
    this.artist,
    required this.song,
    required this.formatter,
    this.capo = 0,
    this.compact = false,
    this.setSequence,
  });

  final String title;
  final String? artist;
  final Song song;
  final ChordFormatter formatter;
  final int capo;
  final bool compact;

  /// Set-specific sequence (layer 2, ADR-0006); replaces the song's own.
  final String? setSequence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sequence = setSequence == null
        ? song.sequence
        : parseSequence(setSequence!);
    final info = <String>[
      if (formatter.formatKey() case final key?) l10n.keyLabel(key),
      if (capo > 0) l10n.capoValue(capo),
      if (song.tempo case final tempo?) l10n.bpm(tempo),
      ?song.time,
    ];
    final subtitle = [
      if (artist != null && artist!.isNotEmpty) artist!,
      ?song.subtitle,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: compact
              ? theme.textTheme.titleLarge
              : theme.textTheme.headlineSmall,
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (sequence.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SongSequenceView(
              sequence,
              compact: compact,
              fromSet: setSequence != null,
            ),
          ),
        if (info.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              info.join('   '),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// The song sequence from `{x_sequence: …}` as a row of small chips.
class SongSequenceView extends StatelessWidget {
  const SongSequenceView(
    this.sequence, {
    super.key,
    this.compact = false,
    this.fromSet = false,
  });

  final List<SequenceItem> sequence;
  final bool compact;

  /// Marks a set-specific sequence (layer 2, ADR-0006).
  final bool fromSet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelMedium;
    return Semantics(
      label: l10n.sequenceLabel,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (fromSet)
            Tooltip(
              message: l10n.sequenceFromSet,
              child: Icon(
                Icons.playlist_play,
                key: const ValueKey('sequence-from-set'),
                size: compact ? 18 : 20,
                color: scheme.primary,
              ),
            ),
          for (final item in sequence)
            Tooltip(
              message: _partName(l10n, item),
              child: Container(
                key: const ValueKey('sequence-chip'),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 5 : 7,
                  vertical: compact ? 1 : 2,
                ),
                decoration: BoxDecoration(
                  color: _background(scheme, item.part),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.code,
                  style: style?.copyWith(
                    color: _foreground(scheme, item.part),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _background(ColorScheme scheme, SequencePart part) =>
      switch (part) {
        SequencePart.chorus => scheme.primaryContainer,
        SequencePart.preChorus ||
        SequencePart.postChorus => scheme.secondaryContainer,
        SequencePart.bridge => scheme.tertiaryContainer,
        _ => scheme.surfaceContainerHighest,
      };

  static Color _foreground(ColorScheme scheme, SequencePart part) =>
      switch (part) {
        SequencePart.chorus => scheme.onPrimaryContainer,
        SequencePart.preChorus ||
        SequencePart.postChorus => scheme.onSecondaryContainer,
        SequencePart.bridge => scheme.onTertiaryContainer,
        _ => scheme.onSurfaceVariant,
      };

  static String _partName(AppLocalizations l10n, SequenceItem item) {
    final name = switch (item.part) {
      SequencePart.intro => l10n.sectionIntro,
      SequencePart.verse => l10n.sectionVerse,
      SequencePart.preChorus => l10n.sectionPreChorus,
      SequencePart.chorus => l10n.sectionChorus,
      SequencePart.postChorus => l10n.sectionPostChorus,
      SequencePart.bridge => l10n.sectionBridge,
      SequencePart.interlude => l10n.sectionInterlude,
      SequencePart.instrumental => l10n.sectionInstrumental,
      SequencePart.solo => l10n.sectionSolo,
      SequencePart.tag => l10n.sectionTag,
      SequencePart.outro => l10n.sectionOutro,
      SequencePart.other => item.code,
    };
    return [
      name,
      if (item.part != SequencePart.other && item.number != null)
        '${item.number}',
      if (item.repeat != null) '×${item.repeat}',
    ].join(' ');
  }
}
