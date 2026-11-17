import 'package:chordpro/chordpro.dart' as cp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/band_view.dart';
import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../render/song_header.dart';
import '../widgets/dialogs.dart';
import '../widgets/key_picker.dart';
import '../widgets/sequence_dialog.dart';

/// The arrangement of [band] for [song] (ADR-0025): the band's key,
/// sequence and tempo, applied on top of the song. Band leaders, set
/// planners and organization admins change it here; everyone else sees it.
class BandArrangementCard extends ConsumerWidget {
  const BandArrangementCard({
    super.key,
    required this.band,
    required this.song,
    required this.parsed,
    required this.arrangement,
  });

  final BandView band;
  final SongEntry song;
  final cp.Song parsed;
  final BandArrangement? arrangement;

  Future<void> _save(
    WidgetRef ref, {
    int? transpose,
    String? Function()? sequence,
    int? Function()? tempo,
  }) => ref
      .read(arrangementRepositoryProvider)
      .save(
        band.id,
        song.id,
        transpose: transpose ?? arrangement?.transpose ?? 0,
        sequence: sequence != null ? sequence() : arrangement?.sequence,
        tempo: tempo != null ? tempo() : arrangement?.tempo,
      );

  Future<void> _editSequence(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final original = cp.findSequence(song.chordproSource);
    final choice = await editSequence(
      context,
      title: l10n.arrangementSequence,
      parts: cp.songParts(parsed),
      initial: arrangement?.sequence ?? original,
      original: original,
      showOriginal: true,
      canRestore: arrangement?.sequence != null,
    );
    if (choice == null) return;
    // The song's own sequence is no band-specific one.
    final value = choice.value?.trim();
    await _save(ref, sequence: () => value == original?.trim() ? null : value);
  }

  Future<void> _editTempo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final text = await askText(
      context,
      title: l10n.arrangementTempo,
      label: l10n.arrangementTempoLabel,
      hint: parsed.tempo?.toString(),
      initial: arrangement?.tempo?.toString() ?? '',
      allowEmpty: true,
    );
    if (text == null) return;
    final value = int.tryParse(text.trim());
    await _save(
      ref,
      tempo: () => value == null || value <= 0 || value == parsed.tempo
          ? null
          : value.clamp(1, 400),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notation = ref.watch(settingsProvider.select((s) => s.notation));
    final canEdit = band.canManageSets;
    final a = arrangement;
    final songKey = parsed.key;
    final sequence = a?.sequence;

    final details = <String>[
      if (a == null)
        l10n.arrangementAsWritten
      else ...[
        if (normalizeSemitones(a.transpose) != 0)
          l10n.arrangementKey(
            songKey == null
                ? formatSemitones(a.transpose)
                : songKey.transpose(a.transpose).format(notation),
          ),
        if (a.tempo case final tempo?) l10n.bpm(tempo),
      ],
    ];

    return Card(
      key: const Key('band-arrangement'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.arrangementOf(band.name),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details.join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (canEdit && a != null)
                  IconButton(
                    key: const Key('arrangement-reset'),
                    tooltip: l10n.arrangementReset,
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () => ref
                        .read(arrangementRepositoryProvider)
                        .reset(band.id, song.id),
                  ),
              ],
            ),
            if (sequence != null)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 4),
                child: SongSequenceView(
                  cp.parseSequence(sequence),
                  compact: true,
                  fromBand: true,
                ),
              ),
            if (canEdit)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    KeyPicker(
                      key: const Key('arrangement-key'),
                      dense: true,
                      baseKey: songKey,
                      transpose: a?.transpose ?? 0,
                      notation: notation,
                      onChanged: (value) => _save(ref, transpose: value),
                    ),
                    TextButton.icon(
                      key: const Key('arrangement-sequence'),
                      icon: const Icon(Icons.format_list_numbered),
                      label: Text(l10n.arrangementSequence),
                      onPressed: () => _editSequence(context, ref),
                    ),
                    TextButton.icon(
                      key: const Key('arrangement-tempo'),
                      icon: const Icon(Icons.speed),
                      label: Text(l10n.arrangementTempo),
                      onPressed: () => _editTempo(context, ref),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
