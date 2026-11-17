import 'package:chordpro/chordpro.dart' hide Key;
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Title, artist and key/capo/tempo of a song.
class SongHeader extends StatelessWidget {
  const SongHeader({
    super.key,
    required this.title,
    this.artist,
    required this.song,
    required this.formatter,
    this.compact = false,
    this.setSequence,
    this.bandSequence,
    this.bandTempo,
    this.hiddenParts = const [],
    this.showTitle = true,
    this.stage = false,
  });

  final String title;
  final String? artist;
  final Song song;
  final ChordFormatter formatter;
  final bool compact;

  /// Set-specific sequence (ADR-0006); replaces the band's and the song's.
  final String? setSequence;

  /// Sequence of the band arrangement (ADR-0025); replaces the song's own.
  final String? bandSequence;

  /// Tempo of the band arrangement (ADR-0025); replaces the song's own.
  final int? bandTempo;

  /// Parts not shown because they are not in the sequence (live view of a
  /// set); shown as a hint below the sequence.
  final List<String> hiddenParts;

  /// Shows [title]; off where the app bar already shows it (song screen).
  final bool showTitle;

  /// Live mode (ADR-0007): key, capo, tempo and time are what the band
  /// checks before counting in, so they are shown as large chips beside the
  /// title (below it on narrow screens) instead of the small info line.
  final bool stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final layered = setSequence ?? bandSequence;
    final sequence = layered == null ? song.sequence : parseSequence(layered);
    final tempo = bandTempo ?? song.tempo;
    // On stage the values are chips; elsewhere a small line at the end.
    final infoChips = <Widget>[];
    final info = <String>[];
    if (stage) {
      final key = keyText(l10n, formatter);
      final capo = capoText(l10n, formatter);
      infoChips.addAll([
        if (key != null) _StageChip(key, key: const Key('stage-key')),
        if (capo != null) _StageChip(capo, key: const Key('stage-capo')),
        if (tempo != null)
          _StageChip(l10n.bpm(tempo), key: const Key('stage-tempo')),
        if (song.time case final time?)
          _StageChip(time, key: const Key('stage-time')),
      ]);
    } else {
      final keyAndCapo = keyAndCapoText(l10n, formatter);
      info.addAll([
        if (keyAndCapo.isNotEmpty) keyAndCapo,
        if (tempo != null) l10n.bpm(tempo),
        ?song.time,
      ]);
    }
    final subtitle = [
      if (artist != null && artist!.isNotEmpty) artist!,
      ?song.subtitle,
    ].join(' · ');
    final titleText = Text(
      title,
      style: compact
          ? theme.textTheme.titleLarge
          : theme.textTheme.headlineSmall,
      maxLines: compact ? 1 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle && infoChips.isNotEmpty)
          _StageTitleRow(title: titleText, chips: infoChips)
        else if (showTitle)
          titleText
        else if (infoChips.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 6, children: infoChips),
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
              fromBand: setSequence == null && bandSequence != null,
            ),
          ),
        if (hiddenParts.isNotEmpty)
          Padding(
            key: const Key('hidden-parts'),
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 16,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.hiddenParts(hiddenParts.join(', ')),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                    maxLines: compact ? 1 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                  ),
                ),
              ],
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

/// Minimum width for the stage chips beside the title; narrower headers
/// show them in a row of their own below the title.
const _stageChipsBeside = 600.0;

/// Title with the stage chips beside it, or below it on narrow screens.
class _StageTitleRow extends StatelessWidget {
  const _StageTitleRow({required this.title, required this.chips});

  final Widget title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < _stageChipsBeside;
      final row = Wrap(
        key: const Key('stage-info'),
        alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
        spacing: 8,
        runSpacing: 6,
        children: chips,
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 6), row],
        );
      }
      // The chips take the width they need (at most 70 %, then they wrap),
      // the title the rest.
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
            child: row,
          ),
        ],
      );
    },
  );
}

/// One large, high-contrast value of the stage header (key, tempo, …).
class _StageChip extends StatelessWidget {
  const _StageChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The key part of [keyAndCapoText], e.g. "Key: A"; null without a key.
String? keyText(AppLocalizations l10n, ChordFormatter formatter) {
  final asWritten = formatter.effectiveCapo == formatter.songCapo;
  final key = asWritten ? formatter.formatShapeKey() : formatter.formatKey();
  return key == null ? null : l10n.keyLabel(key);
}

/// Key and capo of [formatter], e.g. "Key: A, Capo: 3 (C)". With the song's
/// own capo the key is the one written (the shapes) and the sounding key
/// follows the capo; with a personal capo the key is the sounding one and
/// the shapes follow the capo ("Key: A, Capo: 2 (G)"). Empty without key
/// and capo.
String keyAndCapoText(AppLocalizations l10n, ChordFormatter formatter) =>
    [?keyText(l10n, formatter), ?capoText(l10n, formatter)].join(', ');

/// The capo part of [keyAndCapoText], e.g. "Capo: 2 (G)"; null without a
/// capo.
String? capoText(AppLocalizations l10n, ChordFormatter formatter) {
  final capo = formatter.effectiveCapo;
  if (capo <= 0) return null;
  final other = capo == formatter.songCapo
      ? formatter.formatKey()
      : formatter.formatShapeKey();
  return other == null
      ? l10n.capoLabel(capo)
      : l10n.capoLabelWithKey(capo, other);
}

/// The song sequence from `{x_sequence: …}` as a row of small chips.
class SongSequenceView extends StatelessWidget {
  const SongSequenceView(
    this.sequence, {
    super.key,
    this.compact = false,
    this.fromSet = false,
    this.fromBand = false,
  });

  final List<SequenceItem> sequence;
  final bool compact;

  /// Marks a set-specific sequence (layer 2, ADR-0006).
  final bool fromSet;

  /// Marks the sequence of the band arrangement (ADR-0025).
  final bool fromBand;

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
            )
          else if (fromBand)
            Tooltip(
              message: l10n.sequenceFromBand,
              child: Icon(
                Icons.groups_outlined,
                key: const ValueKey('sequence-from-band'),
                size: compact ? 18 : 20,
                color: scheme.primary,
              ),
            ),
          for (final item in sequence)
            Tooltip(
              message: partName(l10n, item),
              child: Container(
                key: const ValueKey('sequence-chip'),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 5 : 7,
                  vertical: compact ? 1 : 2,
                ),
                decoration: BoxDecoration(
                  color: background(scheme, item.part),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.code,
                  style: style?.copyWith(
                    color: foreground(scheme, item.part),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Background of the chip of [part] (docs/development/branding.md,
  /// "Sequence chips").
  ///
  /// With the red brand seed the light `primaryContainer`,
  /// `secondaryContainer` and `surfaceContainerHighest` are all the same
  /// blush (issue #288), so the parts use clearly different roles: the
  /// chorus is filled with the primary colour, pre- and post-chorus use a
  /// softer tone of it (tone 80 on light, tone 30 on dark), the bridge the
  /// tertiary container (gold) and all other parts a neutral surface.
  static Color background(ColorScheme scheme, SequencePart part) =>
      switch (part) {
        SequencePart.chorus => scheme.primary,
        SequencePart.preChorus || SequencePart.postChorus =>
          scheme.brightness == Brightness.light
              ? scheme.primaryFixedDim
              : scheme.primaryContainer,
        SequencePart.bridge => scheme.tertiaryContainer,
        _ => scheme.surfaceContainerHighest,
      };

  /// Text (and icon) colour on [background].
  static Color foreground(ColorScheme scheme, SequencePart part) =>
      switch (part) {
        SequencePart.chorus => scheme.onPrimary,
        SequencePart.preChorus || SequencePart.postChorus =>
          scheme.brightness == Brightness.light
              ? scheme.onPrimaryFixed
              : scheme.onPrimaryContainer,
        SequencePart.bridge => scheme.onTertiaryContainer,
        _ => scheme.onSurfaceVariant,
      };

  static String partName(AppLocalizations l10n, SequenceItem item) {
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
