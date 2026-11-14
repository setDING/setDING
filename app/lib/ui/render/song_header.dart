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
  });

  final String title;
  final String? artist;
  final Song song;
  final ChordFormatter formatter;
  final int capo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
