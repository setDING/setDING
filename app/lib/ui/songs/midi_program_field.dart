import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_connection.dart';
import '../../midi/midi_message.dart';
import '../../midi/midi_profile.dart';
import '../../providers.dart';
import '../widgets/dialogs.dart';

/// [patch] as the musician reads it, e.g. "Program K:33" or "Song 2, part 3".
String midiPatchLabel(AppLocalizations l10n, MidiPatch patch) =>
    switch (patch) {
      NordProgram(:final label) => l10n.midiProgramValueNord(label),
      NordLiveMemory(:final number) => l10n.midiProgramValueLive(number),
      NordSong(:final song, :final part) => l10n.midiProgramValueSong(
        song,
        part,
      ),
      MotifVoice(:final label) => l10n.midiProgramValueMotifVoice(label),
      MotifPerformance(:final label) => l10n.midiProgramValueMotifPerformance(
        label,
      ),
      GenericProgram(:final msb, :final lsb, :final program) => [
        l10n.midiProgramValueGeneric(program),
        if (msb != null) l10n.midiProgramValueMsb(msb),
        if (lsb != null) l10n.midiProgramValueLsb(lsb),
      ].join(' · '),
    };

/// The name of the device profile [kind] (ADR-0039).
String midiProfileName(AppLocalizations l10n, MidiProfileKind kind) =>
    switch (kind) {
      MidiProfileKind.generic => l10n.midiProfileGeneric,
      MidiProfileKind.nordStage3 => l10n.midiProfileNordStage3,
      MidiProfileKind.motifXf => l10n.midiProfileMotifXf,
    };

/// The keyboard programs of a song in its personal adjustments (ADR-0039,
/// ADR-0042): shown when MIDI program changes are on for this device or
/// the song already has a program. The program of this device's profile
/// comes first: chosen in [showMidiProgramPicker], removed, and "Test"
/// sends it once to the connected keyboard. The programs of other
/// keyboards (profiles) follow and can be edited or removed, and a program
/// can be prepared for another keyboard; nothing else here sends anything.
class MidiProgramField extends ConsumerWidget {
  const MidiProgramField({
    super.key,
    required this.songId,
    this.programs = const MidiPrograms(),
  });

  final String songId;

  /// The stored programs per profile, as [SongRepository.midiProgramsOf]
  /// reads them.
  final MidiPrograms programs;

  /// Whether the field is shown on this device: only for keyboard players
  /// (ADR-0039), when MIDI is on or the song already has a program.
  static bool visible({
    required bool keyboard,
    required bool midiEnabled,
    MidiPrograms programs = const MidiPrograms(),
  }) => keyboard && (midiEnabled || !programs.isEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(midiProfileProvider);
    final status = ref.watch(midiConnectionProvider);
    final repo = ref.read(songRepositoryProvider);
    final program = programs[profile.id];

    Future<void> chooseFor(MidiProfile target) async {
      final chosen = await showMidiProgramPicker(
        context,
        profile: target,
        initial: programs[target.id],
      );
      if (chosen != null) {
        await repo.setMidiProgram(
          songId,
          target.id,
          chosen,
          deviceProfile: profile.id,
        );
      }
    }

    Future<void> choose() => chooseFor(profile);

    Future<void> remove(String id) =>
        repo.removeMidiProgram(songId, id, deviceProfile: profile.id);

    // Programs of other keyboards, in the order of the profiles; ids this
    // client does not know last (written by a newer client).
    final others = [
      for (final kind in MidiProfileKind.values)
        if (kind.name != profile.id && programs[kind.name] != null) kind.name,
      for (final id in programs.byProfile.keys)
        if (MidiProfile.byId(id) == null) id,
    ];
    final addable = [
      for (final kind in MidiProfileKind.values)
        if (kind.name != profile.id && programs[kind.name] == null) kind,
    ];

    void test() {
      if (program == null) return;
      final sent = ref.read(midiConnectionProvider.notifier).send(program);
      showMessage(
        context,
        sent
            ? l10n.midiProgramSent(status.deviceName ?? '')
            : l10n.midiProgramSendFailed,
      );
    }

    final testButton = OutlinedButton.icon(
      key: const Key('midi-program-test'),
      icon: const Icon(Icons.play_arrow, size: 18),
      label: Text(l10n.midiProgramTest),
      onPressed: program != null && status.connected ? test : null,
    );

    return Column(
      key: const Key('midi-program-field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.piano,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.midiProgramTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          program == null ? l10n.midiProgramNone : l10n.midiProgramHint,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              key: const Key('midi-program-value'),
              avatar: Icon(program == null ? Icons.add : Icons.edit, size: 18),
              label: Text(
                program == null
                    ? l10n.midiProgramChoose
                    : midiPatchLabel(l10n, profile.toPatch(program)),
              ),
              onPressed: choose,
            ),
            if (program != null) ...[
              Tooltip(
                message: status.connected
                    ? l10n.midiProgramTestHint
                    : l10n.midiProgramNotConnected,
                child: testButton,
              ),
              IconButton(
                key: const Key('midi-program-remove'),
                tooltip: l10n.midiProgramRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => remove(profile.id),
              ),
            ],
          ],
        ),
        if (!status.enabled) ...[
          const SizedBox(height: 4),
          Text(l10n.midiProgramOff, style: theme.textTheme.bodySmall),
        ] else if (program != null && !status.connected) ...[
          const SizedBox(height: 4),
          Text(
            l10n.midiProgramNotConnected,
            key: const Key('midi-program-not-connected'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        // Other keyboards (ADR-0042): kept when the profile changes.
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.midiProgramOtherKeyboards,
            style: theme.textTheme.labelLarge,
          ),
          for (final id in others)
            _OtherProgram(
              key: Key('midi-other-$id'),
              id: id,
              program: programs[id]!,
              onEdit: switch (MidiProfile.byId(id)) {
                final known? => () => chooseFor(known),
                null => null,
              },
              onRemove: () => remove(id),
            ),
        ],
        if (addable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MenuAnchor(
              menuChildren: [
                for (final kind in addable)
                  MenuItemButton(
                    key: Key('midi-add-${kind.name}'),
                    onPressed: () => chooseFor(MidiProfile.of(kind)),
                    child: Text(midiProfileName(l10n, kind)),
                  ),
              ],
              builder: (context, menu, _) => TextButton.icon(
                key: const Key('midi-program-add-other'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.midiProgramForOtherKeyboard),
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              ),
            ),
          ),
      ],
    );
  }
}

/// The program of another keyboard (profile [id]) in [MidiProgramField]:
/// its name and value, editable with that profile's picker (without
/// sending) and removable. A profile this client does not know shows the
/// raw values and can only be removed.
class _OtherProgram extends StatelessWidget {
  const _OtherProgram({
    super.key,
    required this.id,
    required this.program,
    required this.onEdit,
    required this.onRemove,
  });

  final String id;
  final MidiProgram program;
  final VoidCallback? onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = MidiProfile.byId(id);
    final name = profile == null
        ? l10n.midiProgramUnknownKeyboard(id)
        : midiProfileName(l10n, profile.kind);
    final value = midiPatchLabel(
      l10n,
      (profile ?? const GenericProfile()).toPatch(program),
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: onEdit == null
              ? Text(value)
              : ActionChip(
                  key: Key('midi-other-value-$id'),
                  avatar: const Icon(Icons.edit, size: 18),
                  label: Text(value, overflow: TextOverflow.ellipsis),
                  onPressed: onEdit,
                ),
        ),
        IconButton(
          key: Key('midi-other-remove-$id'),
          tooltip: l10n.midiProgramRemove,
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// What a program addresses, as chosen in the picker.
enum MidiPatchKind { program, live, song, performance, voice, generic }

MidiPatchKind _kindOf(MidiPatch patch) => switch (patch) {
  NordProgram() => MidiPatchKind.program,
  NordLiveMemory() => MidiPatchKind.live,
  NordSong() => MidiPatchKind.song,
  MotifPerformance() => MidiPatchKind.performance,
  MotifVoice() => MidiPatchKind.voice,
  GenericProgram() => MidiPatchKind.generic,
};

/// The kinds [profile] offers (the Nord Stage 3: programs, live memories
/// and songs, #586), plus the kind of the stored [current] value, so it
/// can be kept and changed.
List<MidiPatchKind> midiPatchKinds(MidiProfile profile, MidiPatch? current) {
  final kinds = switch (profile) {
    NordStage3Profile() => [
      MidiPatchKind.program,
      MidiPatchKind.live,
      MidiPatchKind.song,
    ],
    MotifXfProfile() => [MidiPatchKind.performance, MidiPatchKind.voice],
    GenericProfile() => [MidiPatchKind.generic],
  };
  if (current != null && !kinds.contains(_kindOf(current))) {
    kinds.add(_kindOf(current));
  }
  return MidiPatchKind.values.where(kinds.contains).toList();
}

/// Lets the musician choose a keyboard program in the terms of [profile]
/// without typing (except the generic values); starts with [initial].
/// Returns the raw values, or null when cancelled.
Future<MidiProgram?> showMidiProgramPicker(
  BuildContext context, {
  required MidiProfile profile,
  MidiProgram? initial,
}) => showDialog<MidiProgram>(
  context: context,
  builder: (_) => MidiProgramPicker(profile: profile, initial: initial),
);

/// The dialog of [showMidiProgramPicker].
class MidiProgramPicker extends StatefulWidget {
  const MidiProgramPicker({super.key, required this.profile, this.initial});

  final MidiProfile profile;
  final MidiProgram? initial;

  /// Forgets the kind last saved (tests).
  @visibleForTesting
  static void resetLastKind() => _MidiProgramPickerState._lastKind = null;

  @override
  State<MidiProgramPicker> createState() => _MidiProgramPickerState();
}

class _MidiProgramPickerState extends State<MidiProgramPicker> {
  /// The kind last saved while the app runs: a new program starts with it,
  /// so a keyboard player who works with Nord songs need not switch each
  /// time.
  static MidiPatchKind? _lastKind;

  late final List<MidiPatchKind> _kinds;
  late MidiPatchKind _kind;

  var _bank = 0;
  var _page = 1;
  var _button = 1;
  var _live = 1;
  var _song = 1;
  var _part = 1;
  var _voiceBank = 0;
  var _performanceBank = 0;
  var _motifIndex = 0;
  final _msb = TextEditingController();
  final _lsb = TextEditingController();
  final _program = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    final stored = switch (widget.initial) {
      final p? => widget.profile.toPatch(p),
      null => null,
    };
    _kinds = midiPatchKinds(widget.profile, stored);
    final start = stored ?? widget.profile.initialPatch;
    _kind = _kindOf(start);
    final last = _lastKind;
    if (stored == null && last != null && _kinds.contains(last)) _kind = last;
    switch (start) {
      case NordProgram(:final bank, :final page, :final button):
        _bank = bank;
        _page = page;
        _button = button;
      case NordLiveMemory(:final number):
        _live = number;
      case NordSong(:final song, :final part):
        _song = song;
        _part = part;
      case MotifVoice(:final bank, :final index):
        _voiceBank = bank;
        _motifIndex = index;
      case MotifPerformance(:final bank, :final index):
        _performanceBank = bank;
        _motifIndex = index;
      case GenericProgram(:final msb, :final lsb, :final program):
        _msb.text = msb?.toString() ?? '';
        _lsb.text = lsb?.toString() ?? '';
        _program.text = '$program';
    }
  }

  @override
  void dispose() {
    _msb.dispose();
    _lsb.dispose();
    _program.dispose();
    super.dispose();
  }

  /// The value of a generic field: null when empty, -1 when invalid.
  static int? _field(TextEditingController c, int min, int max) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    return value != null && value >= min && value <= max ? value : -1;
  }

  /// The chosen patch; null while the generic values are invalid.
  MidiPatch? get _patch {
    switch (_kind) {
      case MidiPatchKind.program:
        return NordProgram(_bank, _page, _button);
      case MidiPatchKind.live:
        return NordLiveMemory(_live);
      case MidiPatchKind.song:
        return NordSong(_song, _part);
      case MidiPatchKind.performance:
        return MotifPerformance(
          _performanceBank,
          _motifClamped(MotifXf.performanceBanks[_performanceBank]),
        );
      case MidiPatchKind.voice:
        return MotifVoice(
          _voiceBank,
          _motifClamped(MotifXf.voiceBanks[_voiceBank]),
        );
      case MidiPatchKind.generic:
        final msb = _field(_msb, 0, 127);
        final lsb = _field(_lsb, 0, 127);
        final program = _field(_program, 1, 128);
        if (msb == -1 || lsb == -1 || program == null || program == -1) {
          return null;
        }
        return GenericProgram(msb: msb, lsb: lsb, program: program);
    }
  }

  String _kindLabel(AppLocalizations l10n, MidiPatchKind kind) =>
      switch (kind) {
        MidiPatchKind.program => l10n.midiProgramKindProgram,
        MidiPatchKind.live => l10n.midiProgramKindLive,
        MidiPatchKind.song => l10n.midiProgramKindSong,
        MidiPatchKind.performance => l10n.midiProgramKindPerformance,
        MidiPatchKind.voice => l10n.midiProgramKindVoice,
        MidiPatchKind.generic => l10n.midiProgramKindGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final patch = _patch;
    final width = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      // Phones keep as much width as possible for the grid.
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 480 ? 12 : 40,
        vertical: 24,
      ),
      title: Text(l10n.midiProgramTitle),
      content: SizedBox(
        width: math.min(440, width),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_kinds.length > 1) ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<MidiPatchKind>(
                    key: const Key('midi-program-kind'),
                    showSelectedIcon: false,
                    segments: [
                      for (final kind in _kinds)
                        ButtonSegment(
                          value: kind,
                          label: Text(
                            _kindLabel(l10n, kind),
                            key: Key('midi-kind-${kind.name}'),
                          ),
                        ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // The result as the musician reads it, e.g. "Program K:33".
              Center(
                child: Text(
                  patch == null ? '–' : midiPatchLabel(l10n, patch),
                  key: const Key('midi-program-preview'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 16),
              ...switch (_kind) {
                MidiPatchKind.program => _nordProgram(l10n, theme),
                MidiPatchKind.live => _nordLive(l10n, theme),
                MidiPatchKind.song => _nordSong(l10n, theme),
                MidiPatchKind.performance => _motif(
                  l10n,
                  theme,
                  MotifXf.performanceBanks,
                  _performanceBank,
                  (b) => _performanceBank = b,
                ),
                MidiPatchKind.voice => _motif(
                  l10n,
                  theme,
                  MotifXf.voiceBanks,
                  _voiceBank,
                  (b) => _voiceBank = b,
                ),
                MidiPatchKind.generic => _generic(l10n),
              },
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('midi-program-save'),
          onPressed: patch == null
              ? null
              : () {
                  _lastKind = _kind;
                  Navigator.pop(context, widget.profile.toMidi(patch));
                },
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: theme.textTheme.titleSmall),
  );

  Widget _choices({
    required String keyPrefix,
    required int count,
    required int selected,
    required String Function(int) label,
    required ValueChanged<int> onSelected,
  }) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (var i = 0; i < count; i++)
        ChoiceChip(
          key: Key('$keyPrefix-$i'),
          label: Text(label(i)),
          showCheckmark: false,
          selected: selected == i,
          onSelected: (_) => setState(() => onSelected(i)),
        ),
    ],
  );

  List<Widget> _nordProgram(AppLocalizations l10n, ThemeData theme) => [
    _label(theme, l10n.midiProgramBank),
    _choices(
      keyPrefix: 'midi-bank',
      count: NordStage3.banks.length,
      selected: _bank,
      label: (i) => NordStage3.banks[i],
      onSelected: (i) => _bank = i,
    ),
    const SizedBox(height: 16),
    _label(theme, l10n.midiProgramPageButton),
    // 5 pages (rows) × 5 buttons, labelled as on the display, e.g. "33".
    LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(56.0, (constraints.maxWidth - 4 * 6) / 5);
        return Column(
          children: [
            for (var page = 1; page <= NordStage3.pages; page++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var button = 1; button <= NordStage3.buttons; button++)
                      Padding(
                        padding: EdgeInsets.only(left: button == 1 ? 0 : 6),
                        child: SizedBox.square(
                          dimension: size,
                          child: _gridButton(theme, page, button),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  ];

  Widget _gridButton(ThemeData theme, int page, int button) {
    final selected = _page == page && _button == button;
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    void onPressed() => setState(() {
      _page = page;
      _button = button;
    });
    final key = Key('midi-cell-$page$button');
    final label = Text('$page$button');
    return selected
        ? FilledButton(
            key: key,
            style: style,
            onPressed: onPressed,
            child: label,
          )
        : OutlinedButton(
            key: key,
            style: style,
            onPressed: onPressed,
            child: label,
          );
  }

  List<Widget> _nordLive(AppLocalizations l10n, ThemeData theme) => [
    _label(theme, l10n.midiProgramKindLive),
    _choices(
      keyPrefix: 'midi-live',
      count: NordStage3.liveMemories,
      selected: _live - 1,
      label: (i) => '${i + 1}',
      onSelected: (i) => _live = i + 1,
    ),
  ];

  List<Widget> _nordSong(AppLocalizations l10n, ThemeData theme) => [
    _label(theme, l10n.midiProgramSongNumber),
    Row(
      children: [
        IconButton.outlined(
          key: const Key('midi-song-down'),
          tooltip: l10n.midiProgramPreviousSong,
          icon: const Icon(Icons.remove),
          onPressed: _song > 1 ? () => setState(() => _song--) : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$_song',
            key: const Key('midi-song-number'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton.outlined(
          key: const Key('midi-song-up'),
          tooltip: l10n.midiProgramNextSong,
          icon: const Icon(Icons.add),
          onPressed: _song < NordStage3.maxSong
              ? () => setState(() => _song++)
              : null,
        ),
      ],
    ),
    // For far jumps; the buttons fine-tune.
    Slider(
      key: const Key('midi-song-slider'),
      min: 1,
      max: NordStage3.maxSong.toDouble(),
      divisions: NordStage3.maxSong - 1,
      value: _song.toDouble(),
      label: '$_song',
      onChanged: (v) => setState(() => _song = v.round()),
    ),
    const SizedBox(height: 8),
    _label(theme, l10n.midiProgramPart),
    _choices(
      keyPrefix: 'midi-part',
      count: NordStage3.partsPerSong,
      selected: _part - 1,
      label: (i) => '${i + 1}',
      onSelected: (i) => _part = i + 1,
    ),
    const SizedBox(height: 12),
    Text(
      l10n.midiProgramSongHint,
      key: const Key('midi-song-hint'),
      style: theme.textTheme.bodySmall,
    ),
  ];

  /// The Motif XF program in [bank], kept inside the bank (a drum bank
  /// has fewer programs than the one chosen before).
  int _motifClamped(MotifBank bank) => math.min(_motifIndex, bank.size - 1);

  /// Bank, group A–H and number 1–16 of a Motif XF voice or performance,
  /// as on its display (#591).
  List<Widget> _motif(
    AppLocalizations l10n,
    ThemeData theme,
    List<MotifBank> banks,
    int bank,
    ValueChanged<int> onBank,
  ) {
    final b = banks[bank];
    final index = _motifClamped(b);
    final group = index ~/ MotifXf.perGroup;
    final inGroup = math.min(
      MotifXf.perGroup,
      b.size - group * MotifXf.perGroup,
    );
    return [
      _label(theme, l10n.midiProgramBank),
      _choices(
        keyPrefix: 'midi-motif-bank',
        count: banks.length,
        selected: bank,
        label: (i) => banks[i].name,
        onSelected: (i) {
          onBank(i);
          _motifIndex = _motifClamped(banks[i]);
        },
      ),
      const SizedBox(height: 16),
      _label(theme, l10n.midiProgramGroup),
      _choices(
        keyPrefix: 'midi-motif-group',
        count: b.groups,
        selected: group,
        label: (i) => MotifXf.groupNames[i],
        onSelected: (i) => _motifIndex = math.min(
          i * MotifXf.perGroup + index % MotifXf.perGroup,
          b.size - 1,
        ),
      ),
      const SizedBox(height: 16),
      _label(theme, l10n.midiProgramMotifNumber),
      _choices(
        keyPrefix: 'midi-motif-number',
        count: inGroup,
        selected: index % MotifXf.perGroup,
        label: (i) => (i + 1).toString().padLeft(2, '0'),
        onSelected: (i) => _motifIndex = group * MotifXf.perGroup + i,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.midiProgramMotifHint,
        key: const Key('midi-motif-hint'),
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _generic(AppLocalizations l10n) {
    Widget field(
      String key,
      TextEditingController c,
      String label,
      int min,
      int max, {
      bool required = false,
    }) {
      final value = _field(c, min, max);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key(key),
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            labelText: label,
            helperText: l10n.midiProgramRange(min, max),
            errorText: value == -1 || (required && value == null)
                ? l10n.midiProgramOutOfRange(min, max)
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      );
    }

    return [
      field('midi-generic-msb', _msb, l10n.midiProgramMsb, 0, 127),
      field('midi-generic-lsb', _lsb, l10n.midiProgramLsb, 0, 127),
      field(
        'midi-generic-program',
        _program,
        l10n.midiProgramNumber,
        1,
        128,
        required: true,
      ),
    ];
  }
}
