import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_connection.dart';
import 'live_beat.dart';
import 'live_control_bar.dart';
import 'song_page_controller.dart';

/// The line below the stage (ADR-0007): what comes next, the notices (web,
/// no audio for the click, no wake lock, MIDI), the page of the song and
/// the position in the set.
class LiveInfoBar extends StatelessWidget {
  const LiveInfoBar({
    super.key,
    required this.beat,
    required this.compactLandscape,
    required this.web,
    required this.midi,
    required this.wakeLockFailed,
    required this.nextLabel,
    required this.songPages,
    required this.song,
    required this.index,
    required this.count,
  });

  final LiveBeat beat;

  /// A small screen in landscape (ADR-0026): the line only shows for its
  /// notices.
  final bool compactLandscape;

  /// The web client (ADR-0018): no offline guarantee.
  final bool web;
  final MidiStatus midi;

  /// The screen may turn off (ADR-0007).
  final bool wakeLockFailed;

  /// The next item, null at the end of the set.
  final String? nextLabel;

  /// The pages of the current song.
  final SongPageController songPages;

  /// The current song, null for a marker.
  final SongEntry? song;

  /// Position of the current item in the set, and the number of items.
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: beat.metronome.clickUnavailable,
      builder: (context, clickUnavailable, bar) =>
          compactLandscape &&
              !web &&
              !(midi.enabled && !midi.connected) &&
              !clickUnavailable &&
              !wakeLockFailed
          ? const SizedBox.shrink(key: Key('live-info-hidden'))
          : bar!,
      child: Container(
        key: const Key('live-info'),
        color: theme.colorScheme.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            if (compactLandscape)
              const Spacer()
            else
              Expanded(
                child: Text(
                  switch (nextLabel) {
                    null => l10n.liveEnd,
                    final label => l10n.liveNext(label),
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            // Web: no offline guarantee (ADR-0018).
            if (web) ...[
              const SizedBox(width: 12),
              Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.liveWebNotice,
                  key: const Key('live-web-notice'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // The click was asked for but there is no audio.
            ValueListenableBuilder<bool>(
              valueListenable: beat.metronome.clickUnavailable,
              builder: (context, unavailable, _) => !unavailable
                  ? const SizedBox.shrink()
                  : Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          l10n.clickNoAudioLive,
                          key: const Key('live-click-notice'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
            ),
            // The screen may turn off: say so, so the band can
            // check the device's power settings before the show.
            if (wakeLockFailed) ...[
              Icon(
                Icons.screen_lock_portrait,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.liveWakeLockNotice,
                  key: const Key('live-wakelock-notice'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            ListenableBuilder(
              listenable: songPages,
              builder: (context, _) {
                if (songPages.count <= 1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    l10n.liveSongPage(songPages.page + 1, songPages.count),
                    key: const Key('live-song-page'),
                    style: theme.textTheme.titleSmall,
                  ),
                );
              },
            ),
            // The keyboard (ADR-0039), only while MIDI program
            // changes are on, with the program the current song
            // wants on it, if it has one (#605).
            if (midi.enabled)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: midi.connected
                          ? l10n.liveMidiConnected(midi.deviceName ?? '')
                          : l10n.liveMidiNotConnected,
                      child: Icon(
                        midi.connected ? Icons.piano : Icons.piano_off,
                        key: Key(
                          midi.connected
                              ? 'live-midi-connected'
                              : 'live-midi-not-connected',
                        ),
                        size: 18,
                        semanticLabel: midi.connected
                            ? l10n.liveMidiConnected(midi.deviceName ?? '')
                            : l10n.liveMidiNotConnected,
                        color: midi.connected ? null : theme.colorScheme.error,
                      ),
                    ),
                    if (song case final song?)
                      LiveMidiProgramLabel(songId: song.id),
                  ],
                ),
              ),
            Text(
              l10n.livePosition(index + 1, count),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
