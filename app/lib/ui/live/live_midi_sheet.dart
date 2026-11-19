import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/song_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_connection.dart';
import '../../midi/midi_message.dart';
import '../../providers.dart';
import '../../settings/settings.dart';
import '../songs/midi_program_field.dart';
import '../widgets/dialogs.dart';

/// A song earlier in the live sequence, for "Same as previous song".
typedef LiveEarlierSong = ({String id, String title});

/// The keyboard program of the current song in live mode (#607,
/// ADR-0039): a sheet opened by the keyboard symbol of the control bar
/// shows the program of this device's profile and offers to send it again,
/// change it (with an optional preview on the keyboard), take the one of
/// the nearest earlier song that has one, or remove it. Changes are saved
/// at once in the personal adjustments (ADR-0006, ADR-0042) with "Undo";
/// a changed program is sent, a removed one leaves the keyboard as it is.
///
/// [earlier] are the songs before the current one, nearest first;
/// [sendAgain] sends the stored program (the live sender). [context] is
/// below the stage theme and the live mode's scaffold.
Future<void> showLiveMidiSheet(
  BuildContext context,
  WidgetRef ref, {
  required String songId,
  required List<LiveEarlierSong> earlier,
  required Future<bool> Function() sendAgain,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(songRepositoryProvider);
  final profile = ref.read(midiProfileProvider);
  final connection = ref.read(midiConnectionProvider.notifier);

  final overlay = await repo.getOverlay(songId);
  // As stored, null included, for "Undo".
  final stored = overlay.midiPrograms;
  final program = SongRepository.midiProgramsOf(
    overlay,
    profile.id,
  )[profile.id];
  final previous = await previousMidiProgram(
    repo,
    earlier,
    profile.id,
    exclude: songId,
  );
  if (!context.mounted) return;

  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _LiveMidiSheet(
      program: program == null
          ? null
          : midiPatchLabel(l10n, profile.toPatch(program)),
      profileName: midiProfileName(l10n, profile.kind),
      previous: previous == null || previous.program == program
          ? null
          : l10n.liveMidiPreviousProgram(
              midiPatchShortLabel(l10n, profile.toPatch(previous.program)),
              previous.title,
            ),
    ),
  );
  if (action == null || !context.mounted) return;

  /// Saves [chosen] (null removes it), sends it and offers "Undo".
  Future<void> save(MidiProgram? chosen) async {
    await repo.setMidiProgram(
      songId,
      profile.id,
      chosen,
      deviceProfile: profile.id,
    );
    if (chosen != null) connection.send(chosen);
    showUndo(
      messenger,
      chosen == null ? l10n.liveMidiRemoved : l10n.liveMidiSaved,
      undoLabel: l10n.undo,
      onUndo: () async {
        await repo.restoreMidiPrograms(songId, stored);
        // The keyboard plays the changed program; the old one comes back.
        if (chosen != null && program != null) connection.send(program);
      },
    );
  }

  switch (action) {
    case _Action.sendAgain:
      await sendAgain();
    case _Action.change:
      var previewed = false;
      final settings = ref.read(settingsProvider.notifier);
      final chosen = await showMidiProgramPicker(
        context,
        profile: profile,
        initial: program,
        preview: ref.read(settingsProvider).midiPreview,
        onPreview: (p) {
          previewed = true;
          connection.send(p);
        },
        onPreviewChanged: (on) =>
            settings.update((s) => s.copyWith(midiPreview: on)),
      );
      if (chosen != null) {
        await save(chosen);
      } else if (previewed && program != null) {
        // Cancelled after a preview: the keyboard plays the song's program
        // again.
        connection.send(program);
      }
    case _Action.previous:
      if (previous != null) await save(previous.program);
    case _Action.remove:
      await save(null);
  }
}

/// The program for [profile] of the nearest song in [earlier] that has
/// one, skipping [exclude] (the current song, when it is played twice);
/// null when none has.
Future<({MidiProgram program, String title})?> previousMidiProgram(
  SongRepository repo,
  List<LiveEarlierSong> earlier,
  String profile, {
  String? exclude,
}) async {
  for (final song in earlier) {
    if (song.id == exclude) continue;
    final program = await repo.midiProgram(song.id, profile);
    if (program != null) return (program: program, title: song.title);
  }
  return null;
}

enum _Action { sendAgain, change, previous, remove }

class _LiveMidiSheet extends ConsumerWidget {
  const _LiveMidiSheet({
    required this.program,
    required this.profileName,
    required this.previous,
  });

  /// The current program as the musician reads it; null for none.
  final String? program;
  final String profileName;

  /// The program of the nearest earlier song and its title; null when
  /// there is none or it is the current one.
  final String? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final connected = ref.watch(midiConnectionProvider).connected;
    void pick(_Action action) => Navigator.pop(context, action);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          key: const Key('live-midi-sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.midiProgramTitle,
                style: theme.textTheme.titleLarge,
              ),
              subtitle: Text(l10n.midiProgramDevice(profileName)),
            ),
            ListTile(
              leading: const Icon(Icons.piano),
              title: Text(
                program ?? l10n.midiProgramNone,
                key: const Key('live-midi-sheet-current'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(),
            ListTile(
              key: const Key('live-midi-sheet-send'),
              leading: const Icon(Icons.send),
              title: Text(l10n.liveMidiSendAgain),
              subtitle: connected ? null : Text(l10n.midiProgramNotConnected),
              enabled: program != null && connected,
              onTap: () => pick(_Action.sendAgain),
            ),
            ListTile(
              key: const Key('live-midi-sheet-change'),
              leading: const Icon(Icons.edit),
              title: Text(
                program == null ? l10n.midiProgramChoose : l10n.liveMidiChange,
              ),
              onTap: () => pick(_Action.change),
            ),
            ListTile(
              key: const Key('live-midi-sheet-previous'),
              leading: const Icon(Icons.history),
              title: Text(l10n.liveMidiSameAsPrevious),
              subtitle: Text(previous ?? l10n.liveMidiNoPrevious),
              enabled: previous != null,
              onTap: () => pick(_Action.previous),
            ),
            if (program != null)
              ListTile(
                key: const Key('live-midi-sheet-remove'),
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.midiProgramRemove),
                onTap: () => pick(_Action.remove),
              ),
          ],
        ),
      ),
    );
  }
}
