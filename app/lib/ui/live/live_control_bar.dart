import 'dart:async';

import 'package:chordpro/chordpro.dart' hide Key;
import 'package:drift/drift.dart' show Value;
import 'package:chordpro/chordpro.dart' as cp show Key;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/annotation_providers.dart';
import '../../data/database.dart';
import '../../data/song_providers.dart';
import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_connection.dart';
import '../../settings/settings.dart';
import '../songs/song_attention.dart' show songReportedIcon;
import '../render/render_cache.dart';
import '../songs/midi_program_field.dart' show midiPatchShortLabel;
import '../widgets/chord_view_picker.dart' show chordViewLabel;
import '../widgets/key_picker.dart';
import '../widgets/verse_chords_picker.dart';
import 'live_beat.dart';
import 'live_chordpro_page.dart';
import 'live_item.dart';

/// The keyboard program the song [songId] wants for this device's profile
/// (ADR-0039, ADR-0042), short as in the song's program list, e.g. "A:11"
/// (#609);
/// nothing when it has none (#605).
class LiveMidiProgramLabel extends ConsumerWidget {
  const LiveMidiProgramLabel({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlay = ref.watch(overlayProvider(songId)).value;
    if (overlay == null) return const SizedBox.shrink();
    final profile = ref.watch(midiProfileProvider);
    final program = SongRepository.midiProgramsOf(
      overlay,
      profile.id,
    )[profile.id];
    if (program == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        midiPatchShortLabel(
          AppLocalizations.of(context),
          profile.toPatch(program),
        ),
        key: const Key('live-midi-program'),
        maxLines: 1,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// Minimum width for the chord view toggle in the same row as the controls.
const _wideControlBar = 720.0;

/// The controls of live mode, shown on a tap in the middle of the stage
/// (ADR-0007).
class LiveControlBar extends ConsumerWidget {
  const LiveControlBar({
    super.key,
    required this.item,
    required this.index,
    required this.onExit,
    required this.onOverview,
    required this.onAdjust,
    this.onAdjustClick,
    required this.onFit,
    required this.onSetKey,
    this.onDraw,
    this.onReport,
    this.onSendProgram,
    this.onEditProgram,
    this.onProject,
    this.projecting = false,
  });

  final LiveItem item;
  final int index;
  final VoidCallback onExit;
  final VoidCallback onOverview;
  final Future<void> Function(SongOverlay Function(SongOverlay))? onAdjust;

  /// Changes the grouping and subdivisions of the click (#698); also where
  /// [onAdjust] is null because the song is not shown.
  final Future<void> Function(SongOverlay Function(SongOverlay))? onAdjustClick;
  final VoidCallback onFit;
  final ValueChanged<int> onSetKey;

  /// Starts drawing mode (ADR-0032); null when the item cannot be drawn on.
  final VoidCallback? onDraw;

  /// Reports a mistake in the song (ADR-0060); null without a song.
  final VoidCallback? onReport;

  /// Sends the song's keyboard program again (ADR-0039), on a long press
  /// of the keyboard symbol.
  final Future<bool> Function()? onSendProgram;

  /// Opens the keyboard program of the song (#607), on a tap of the
  /// keyboard symbol; null hides it.
  final VoidCallback? onEditProgram;

  /// Starts the lyrics projection (ADR-0068), or shows its links while it
  /// is [projecting]; null hides the button.
  final VoidCallback? onProject;
  final bool projecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final adjust = onAdjust;
    final song = item.song;
    final overlay = song == null
        ? null
        : ref.watch(overlayProvider(song.id)).value;
    // In a set, the key is stored on the set item (the song stays
    // unchanged); a single song uses the personal transposition.
    final inSet = item.setItemId != null;
    // The band's key is the reference (ADR-0025).
    final originalKey = song?.songKey == null
        ? null
        : cp.Key.tryParse(song!.songKey!)?.transpose(item.bandTranspose);
    final deviceView = ref.watch(settingsProvider.select((s) => s.chordView));
    final parsed = song == null
        ? null
        : parseChordProCached(
            song.chordproSource,
            selectors: ref.watch(selectorsProvider),
          );
    final toggle = adjust == null || parsed == null
        ? null
        : _ChordViewToggle(
            selected: overlay?.chordView ?? deviceView,
            hasKey: parsed.key != null,
            onChanged: (view) => adjust(
              (o) => o.copyWith(
                chordView: Value(view == deviceView ? null : view),
              ),
            ),
          );
    final leading = <Widget>[
      IconButton(
        tooltip: l10n.liveExit,
        icon: const Icon(Icons.close),
        onPressed: onExit,
      ),
      IconButton(
        tooltip: l10n.liveSetOverview,
        icon: const Icon(Icons.format_list_numbered),
        onPressed: onOverview,
      ),
      // Tap: the program (#607); long press: send it again at once, the
      // quick way on stage (ADR-0039).
      if (onEditProgram case final edit?)
        // No tooltip: on touch screens it would take the long press.
        Semantics(
          label: l10n.liveMidiButton,
          onLongPressHint: l10n.liveMidiSendAgain,
          child: GestureDetector(
            onLongPress: onSendProgram,
            child: IconButton(
              key: const Key('live-midi-button'),
              icon: const Icon(Icons.piano),
              onPressed: edit,
            ),
          ),
        ),
    ];
    final annotated =
        song != null &&
        (ref.watch(annotationCountProvider(song.id)).value ?? 0) > 0;
    final annotationsShown = ref.watch(
      settingsProvider.select((s) => s.showAnnotations),
    );
    // How verses show their chords (#518, #521), and freehand annotations
    // (ADR-0032): draw, and show or hide them.
    // The verse chords are offered for songs where a choice changes
    // something, and always to turn it off again.
    final verseChords = overlay?.verseChords ?? VerseChords.all;
    final stackedChoruses = overlay?.stackedChoruses ?? false;
    final extraButtons = <Widget>[
      // With the extra buttons: on phones they get the row above.
      if (onProject case final project?)
        IconButton(
          key: const Key('live-project'),
          tooltip: projecting ? l10n.projectionLinks : l10n.projectionStart,
          icon: Icon(projecting ? Icons.cast_connected : Icons.cast),
          onPressed: project,
        ),
      if (adjust != null &&
          parsed != null &&
          verseChordsOffered(parsed, verseChords, stackedChoruses))
        VerseChordsPicker(
          song: parsed,
          mode: verseChords,
          stackedChoruses: stackedChoruses,
          compact: true,
          onChanged: (mode) => adjust((o) => o.copyWith(verseChords: mode)),
          onStackedChorusesChanged: (on) =>
              adjust((o) => o.copyWith(stackedChoruses: on)),
        ),
      if (annotated)
        IconButton(
          key: const Key('live-annotations-visible'),
          tooltip: annotationsShown
              ? l10n.annotationsHide
              : l10n.annotationsShow,
          icon: Icon(
            annotationsShown ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => ref
              .read(settingsProvider.notifier)
              .update((s) => s.copyWith(showAnnotations: !annotationsShown)),
        ),
      if (onDraw case final draw?)
        IconButton(
          key: const Key('live-annotations-draw'),
          tooltip: l10n.annotationsDraw,
          icon: const Icon(Icons.draw),
          onPressed: draw,
        ),
      if (onReport case final report?)
        IconButton(
          key: const Key('live-report'),
          tooltip: l10n.reportMistake,
          icon: const Icon(songReportedIcon),
          onPressed: report,
        ),
    ];
    final trailing = <Widget>[
      if (adjust != null) ...[
        KeyPicker(
          baseKey: originalKey,
          transpose: inSet ? item.setTranspose : overlay?.transpose ?? 0,
          notation: ref.watch(settingsProvider.select((s) => s.notation)),
          tooltip: inSet ? l10n.keyPickerSet : l10n.keyPickerPersonal,
          onChanged: (value) => inSet
              ? onSetKey(value)
              : adjust((o) => o.copyWith(transpose: value)),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.fontSmaller,
          icon: const Icon(Icons.text_decrease),
          onPressed: () => adjust(
            (o) => o.copyWith(
              fontScale: (o.fontScale - 0.1).clamp(
                minLiveFontScale,
                maxLiveFontScale,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.fontLarger,
          icon: const Icon(Icons.text_increase),
          onPressed: () => adjust(
            (o) => o.copyWith(
              fontScale: (o.fontScale + 0.1).clamp(
                minLiveFontScale,
                maxLiveFontScale,
              ),
            ),
          ),
        ),
        // With fitting on, 100 % is the fitted size (ADR-0007).
        IconButton(
          tooltip: l10n.fitToPage,
          icon: const Icon(Icons.fit_screen),
          onPressed:
              ref.watch(settingsProvider.select((s) => s.autoFit)) &&
                  (overlay == null || overlay.fontScale == 1.0)
              ? null
              : onFit,
        ),
      ],
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // The toggle sits in the middle, easy to reach on stage; on narrow
        // screens it gets a row of its own above the other controls.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideControlBar;
            // On narrow screens these extra buttons go with the toggle
            // into the row above.
            final row = Row(
              children: [
                ...leading,
                if (wide) ...extraButtons,
                const Spacer(),
                if (toggle != null && wide) ...[toggle, const Spacer()],
                ...trailing,
              ],
            );
            // Tempo on stage (ADR-0026) in a row of its own.
            final beat = LiveBeatScope.of(context);
            // Scaled down on phones rather than cut off (#421).
            final tempo = beat != null && beat.canBeat(index)
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: StageTempoControls(
                      index: index,
                      onAdjust: onAdjustClick,
                    ),
                  )
                : null;
            final narrowExtras = wide ? null : [?toggle, ...extraButtons];
            if ((narrowExtras == null || narrowExtras.isEmpty) &&
                tempo == null) {
              return row;
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?tempo,
                if (narrowExtras != null && narrowExtras.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: narrowExtras,
                  ),
                row,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Switches the current song between chord names, Nashville numbers and
/// Roman numerals (ADR-0055); stored as the personal chord view of the song
/// (ADR-0006).
class _ChordViewToggle extends StatelessWidget {
  const _ChordViewToggle({
    required this.selected,
    required this.hasKey,
    required this.onChanged,
  });

  final ChordView selected;

  /// Numbers and numerals need a key in the song.
  final bool hasKey;
  final ValueChanged<ChordView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: hasKey ? '' : l10n.noKeyForDegrees,
      child: SegmentedButton<ChordView>(
        key: const Key('live-chord-view'),
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final view in ChordView.values)
            ButtonSegment(
              value: view,
              // Short symbols fit the control bar also on phones; the
              // tooltip names the view.
              tooltip: chordViewLabel(l10n, view),
              label: Text(switch (view) {
                ChordView.chords => l10n.liveChordViewChords,
                ChordView.nashville => l10n.liveChordViewNashville,
                ChordView.numerals => l10n.liveChordViewNumerals,
              }, key: Key('live-chord-view-${view.name}')),
            ),
        ],
        selected: {hasKey ? selected : ChordView.chords},
        onSelectionChanged: hasKey ? (s) => onChanged(s.single) : null,
      ),
    );
  }
}
