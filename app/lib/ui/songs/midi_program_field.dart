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

/// [patch] as short as the keyboard shows it, e.g. "K:33", "S2:3" or
/// "P USR2 C05", for the keyboard program list (#599); [midiPatchLabel]
/// is the full form.
String midiPatchShortLabel(AppLocalizations l10n, MidiPatch patch) =>
    switch (patch) {
      NordProgram(:final label) => label,
      NordLiveMemory(:final number) => l10n.midiProgramShortLive(number),
      NordSong(:final song, :final part) => l10n.midiProgramShortSong(
        song,
        part,
      ),
      MotifVoice(:final label) => label,
      MotifPerformance(:final label) => l10n.midiProgramShortPerformance(label),
      GenericProgram(:final msb, :final lsb, :final program) =>
        msb == null && lsb == null
            ? '$program'
            : l10n.midiProgramShortGeneric(
                program,
                msb?.toString() ?? '–',
                lsb?.toString() ?? '–',
              ),
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
/// the song already has a program. One list of *profile: program* rows
/// (#597) under "This device: …": this device's profile always
/// comes first, highlighted: its program is chosen in
/// [showMidiProgramPicker], changed, removed, and "Test" sends it once to
/// the connected keyboard. Other profiles follow only when they have a
/// program and can be changed or removed, and a program can be prepared
/// for another keyboard; nothing else here sends anything.
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

    final testButton = IconButton(
      key: const Key('midi-program-test'),
      tooltip: status.connected
          ? l10n.midiProgramTestHint
          : l10n.midiProgramNotConnected,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.play_arrow),
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
                l10n.midiProgramsTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.midiProgramDevice(midiProfileName(l10n, profile.kind)),
          key: const Key('midi-program-device'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        // This device's profile: always listed, highlighted (#597).
        _ProgramRow(
          key: const Key('midi-program-active'),
          name: midiProfileName(l10n, profile.kind),
          active: true,
          patch: program == null ? null : profile.toPatch(program),
          valueKey: const Key('midi-program-value'),
          onEdit: choose,
          test: program == null ? null : testButton,
          removeKey: const Key('midi-program-remove'),
          onRemove: program == null ? null : () => remove(profile.id),
        ),
        // Other keyboards (ADR-0042): only those with a program.
        for (final id in others)
          _otherRow(l10n, id, programs[id]!, chooseFor, remove),
        const SizedBox(height: 4),
        Text(
          program == null ? l10n.midiProgramNone : l10n.midiProgramHint,
          style: theme.textTheme.bodySmall,
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

  /// The row of another keyboard (profile [id]): editable with that
  /// profile's picker (without sending) and removable. A profile this
  /// client does not know shows the raw values and can only be removed.
  Widget _otherRow(
    AppLocalizations l10n,
    String id,
    MidiProgram program,
    Future<void> Function(MidiProfile) chooseFor,
    Future<void> Function(String) remove,
  ) {
    final known = MidiProfile.byId(id);
    return _ProgramRow(
      key: Key('midi-other-$id'),
      name: known == null
          ? l10n.midiProgramUnknownKeyboard(id)
          : midiProfileName(l10n, known.kind),
      active: false,
      patch: (known ?? const GenericProfile()).toPatch(program),
      valueKey: Key('midi-other-value-$id'),
      onEdit: known == null ? null : () => chooseFor(known),
      removeKey: Key('midi-other-remove-$id'),
      onRemove: () => remove(id),
    );
  }
}

/// One *profile: program* row of [MidiProgramField] (#597): the profile's
/// name, its program as an edit chip in its short form (#599; "Choose
/// program" without one), an optional [test] button and a remove button. The [active] row (this
/// device's profile) is highlighted with a check mark.
class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    super.key,
    required this.name,
    required this.active,
    required this.patch,
    required this.valueKey,
    required this.onEdit,
    required this.removeKey,
    required this.onRemove,
    this.test,
  });

  final String name;
  final bool active;

  /// The program; null = none yet.
  final MidiPatch? patch;
  final Key valueKey;

  /// Opens the profile's picker; null = not editable (unknown profile).
  final VoidCallback? onEdit;
  final Widget? test;
  final Key removeKey;

  /// Removes the program; null = nothing to remove.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final patch = this.patch;
    // Short in the list, the full form as the tooltip (#599).
    final Widget chip = switch ((patch, onEdit)) {
      (null, _) => ActionChip(
        key: valueKey,
        avatar: const Icon(Icons.add, size: 18),
        label: Text(l10n.midiProgramChoose),
        onPressed: onEdit,
      ),
      (final p?, null) => Tooltip(
        message: midiPatchLabel(l10n, p),
        child: Text(
          midiPatchShortLabel(l10n, p),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      (final p?, final edit?) => ActionChip(
        key: valueKey,
        avatar: const Icon(Icons.edit, size: 18),
        visualDensity: VisualDensity.compact,
        labelPadding: const EdgeInsets.only(left: 2, right: 4),
        label: Text(
          midiPatchShortLabel(l10n, p),
          overflow: TextOverflow.ellipsis,
        ),
        tooltip: midiPatchLabel(l10n, p),
        onPressed: edit,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: active
          ? BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      constraints: const BoxConstraints(minHeight: 48),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Icon(
              active ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: active ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: active
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Keeps its width, the profile name is shortened instead (#599);
            // only on a very narrow row the chip shortens too.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(
                  0,
                  constraints.maxWidth -
                      _fixedWidth(hasTest: test != null) -
                      _minNameWidth,
                ),
              ),
              child: chip,
            ),
            ?test,
            if (onRemove != null)
              IconButton(
                key: removeKey,
                tooltip: l10n.midiProgramRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// The width the profile name keeps at least before the chip shortens.
  static const _minNameWidth = 40.0;

  /// The width of the row besides the name and the chip: check mark, gaps
  /// and the compact buttons.
  double _fixedWidth({required bool hasTest}) =>
      18 + 8 + 8 + (hasTest ? 40 : 0) + (onRemove != null ? 40 : 8);
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
///
/// With [onPreview] (live mode, #607) the dialog offers a switch "Send
/// while selecting", starting as [preview]; while it is on, every program
/// chosen is passed to [onPreview] at once, and [onPreviewChanged] is told
/// when the switch changes.
Future<MidiProgram?> showMidiProgramPicker(
  BuildContext context, {
  required MidiProfile profile,
  MidiProgram? initial,
  ValueChanged<MidiProgram>? onPreview,
  bool preview = false,
  ValueChanged<bool>? onPreviewChanged,
}) => showDialog<MidiProgram>(
  context: context,
  builder: (_) => MidiProgramPicker(
    profile: profile,
    initial: initial,
    onPreview: onPreview,
    preview: preview,
    onPreviewChanged: onPreviewChanged,
  ),
);

/// The dialog of [showMidiProgramPicker].
class MidiProgramPicker extends StatefulWidget {
  const MidiProgramPicker({
    super.key,
    required this.profile,
    this.initial,
    this.onPreview,
    this.preview = false,
    this.onPreviewChanged,
  });

  /// Below this screen width (phones), the dialog keeps a narrow margin, so
  /// the grid gets as much width as possible.
  static const narrowWidth = 480.0;

  final MidiProfile profile;
  final MidiProgram? initial;

  /// Receives each program chosen while [preview] is on; null offers no
  /// preview (song screen).
  final ValueChanged<MidiProgram>? onPreview;

  /// Whether the preview switch starts on.
  final bool preview;

  /// Told when the preview switch changes, to remember it.
  final ValueChanged<bool>? onPreviewChanged;

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

  /// Whether choices are sent at once (#607).
  late bool _preview = widget.preview;

  /// The program last shown or sent: the initial one, then each one sent;
  /// only another one is sent.
  MidiProgram? _sent;

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
    // What is shown first is not sent: only a choice is (also when the
    // song has no program yet and the picker starts with a default).
    _sent = widget.initial ?? widget.profile.toMidi(start);
  }

  /// Sends [patch] when the preview is on and it is not the program the
  /// keyboard already plays.
  void _previewPatch(MidiPatch? patch) {
    final onPreview = widget.onPreview;
    if (!_preview || onPreview == null || patch == null) return;
    final program = widget.profile.toMidi(patch);
    if (program == _sent) return;
    _sent = program;
    onPreview(program);
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
    _previewPatch(patch);

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < MidiProgramPicker.narrowWidth ? 12 : 40,
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
              if (widget.onPreview != null)
                SwitchListTile(
                  key: const Key('midi-program-preview-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.midiProgramPreviewSwitch),
                  subtitle: Text(l10n.midiProgramPreviewHint),
                  value: _preview,
                  onChanged: (on) {
                    setState(() => _preview = on);
                    widget.onPreviewChanged?.call(on);
                  },
                ),
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
    spacing: 8,
    runSpacing: 8,
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
        final size = math.min(56.0, (constraints.maxWidth - 4 * 8) / 5);
        return Column(
          children: [
            for (var page = 1; page <= NordStage3.pages; page++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var button = 1; button <= NordStage3.buttons; button++)
                      Padding(
                        padding: EdgeInsets.only(left: button == 1 ? 0 : 8),
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
