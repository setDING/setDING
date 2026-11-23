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
import '../widgets/docs_link.dart';
import '../widgets/key_picker.dart';
import '../widgets/scope_info.dart';
import '../widgets/side_panel.dart';
import '../widgets/sequence_dialog.dart';

/// The arrangement of [band] for [song] (ADR-0025): the band's key,
/// sequence and tempo, applied on top of the song, in a side panel of the
/// song screen. Band leaders, set planners and organization admins change it
/// here; everyone else sees it.
class BandArrangementPanel extends ConsumerWidget {
  const BandArrangementPanel({
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

    return SidePanel(
      key: const Key('band-arrangement'),
      icon: Icons.groups_outlined,
      title: l10n.arrangementOf(band.name),
      scope: SettingScope.band,
      docs: DocsPage.keyAndSequence,
      children: [
        ArrangementBandChoice(band: band, song: song),
        if (details.isNotEmpty)
          Text(details.join(' · '), style: theme.textTheme.bodyMedium),
        if (sequence != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SongSequenceView(
              cp.parseSequence(sequence),
              compact: true,
              fromBand: true,
            ),
          ),
        if (canEdit) ...[
          const SizedBox(height: 16),
          KeyPicker(
            key: const Key('arrangement-key'),
            baseKey: songKey,
            transpose: a?.transpose ?? 0,
            notation: notation,
            tooltip: l10n.keyPickerBand,
            onChanged: (value) => _save(ref, transpose: value),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('arrangement-sequence'),
            style: _flushLeft,
            icon: const Icon(Icons.format_list_numbered),
            label: Text(l10n.arrangementSequence),
            onPressed: () => _editSequence(context, ref),
          ),
          TextButton.icon(
            key: const Key('arrangement-tempo'),
            style: _flushLeft,
            icon: const Icon(Icons.speed),
            label: Text(l10n.arrangementTempo),
            onPressed: () => _editTempo(context, ref),
          ),
          if (a != null)
            TextButton.icon(
              key: const Key('arrangement-reset'),
              style: _flushLeft,
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.arrangementReset),
              onPressed: () => ref
                  .read(arrangementRepositoryProvider)
                  .reset(band.id, song.id),
            ),
        ],
      ],
    );
  }
}

/// The band whose arrangement or play history a panel shows, for users in
/// several bands of the song's library; it is the band of the sets tab, so
/// everything follows it (#556). Nothing for a single band.
class ArrangementBandChoice extends ConsumerWidget {
  const ArrangementBandChoice({
    super.key,
    required this.band,
    required this.song,
  });

  final BandView band;
  final SongEntry song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(arrangementBandsProvider(song.libraryId));
    if (bands.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButton<String>(
        key: const Key('arrangement-band'),
        value: band.id,
        isExpanded: true,
        hint: Text(AppLocalizations.of(context).arrangementBand),
        items: [
          for (final b in bands)
            DropdownMenuItem(value: b.id, child: Text(b.name)),
        ],
        onChanged: (id) {
          if (id == null || id == band.id) return;
          ref.read(selectedBandIdProvider.notifier).select(id);
        },
      ),
    );
  }
}

/// Text buttons with their icon at the panel's left edge, in line with the
/// key picker above them.
final _flushLeft = TextButton.styleFrom(
  padding: const EdgeInsetsDirectional.only(end: 12),
  alignment: AlignmentDirectional.centerStart,
);
