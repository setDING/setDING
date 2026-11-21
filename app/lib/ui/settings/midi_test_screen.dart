import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_message.dart';
import '../../midi/midi_output.dart';
import '../../midi/midi_profile.dart';
import '../../util/log.dart';
import '../songs/midi_program_field.dart';
import 'midi_guide.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_header.dart';
import '../widgets/page_width.dart';

/// Prototype of ADR-0039 (#512): sends a program change to a keyboard
/// connected by USB and logs what the keyboard sends back, to check the
/// MIDI library on every platform and the addressing of a Nord Stage 3.
/// The guided tests need only taps: send a step, tap what happened; or
/// choose anything on the keyboard and tap whether what setDING received
/// matches its display (#613, #615). There is one send and one receive
/// test per keyboard.
class MidiTestScreen extends ConsumerStatefulWidget {
  const MidiTestScreen({super.key});

  @override
  ConsumerState<MidiTestScreen> createState() => _MidiTestScreenState();
}

enum _Mode { nordProgram, nordSong, nordLive, motif, raw, controlChange }

class _MidiTestScreenState extends ConsumerState<MidiTestScreen> {
  late final MidiOutput _midi;
  final _subscriptions = <StreamSubscription<void>>[];

  List<MidiPortInfo>? _devices;
  final _connected = <String>{};
  var _channel = 1;
  var _mode = _Mode.nordProgram;
  var _bank = 0;
  var _page = 1;
  var _button = 1;
  var _song = 1;
  var _part = 1;
  var _live = 1;

  /// Motif XF: performance banks first, then the voice banks.
  var _motifBank = 0;
  var _motifIndex = 0;
  var _guideKind = MidiGuide.nordSend;
  var _guide = MidiGuide.nordSend.steps();
  var _step = 0;
  var _stepSent = false;

  /// Collects what the keyboard sends during a free receive (#615).
  MidiProgramReceiver? _receiver;

  /// The program last received and not yet judged.
  MidiProgram? _received;

  /// How many received programs were judged.
  var _checked = 0;
  final _msb = TextEditingController();
  final _lsb = TextEditingController();
  final _program = TextEditingController(text: '1');
  final _controller = TextEditingController(text: '3');
  final _value = TextEditingController(text: '127');
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _midi = ref.read(midiOutputProvider);
    _receiver = MidiProgramReceiver(_channel);
    _subscriptions
      ..add(_midi.received.listen(_onReceived))
      ..add(_midi.changes.listen((_) => _refresh()));
    _refresh();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final id in _connected) {
      unawaited(_midi.disconnect(id).catchError((Object _) {}));
    }
    _msb.dispose();
    _lsb.dispose();
    _program.dispose();
    _controller.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final devices = await _midi.devices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      // A device that was unplugged is no longer connected.
      _connected.retainWhere((id) => devices.any((d) => d.id == id));
    });
  }

  Future<void> _toggle(MidiPortInfo device) async {
    final l10n = AppLocalizations.of(context);
    final connect = !_connected.contains(device.id);
    try {
      if (connect) {
        await _midi.connect(device.id);
      } else {
        await _midi.disconnect(device.id);
      }
      if (!mounted) return;
      setState(() {
        connect ? _connected.add(device.id) : _connected.remove(device.id);
      });
    } catch (e) {
      if (mounted) _add(l10n.midiTestError('$e'));
    }
  }

  void _onReceived(List<int> data) {
    // Clock, active sensing and other real-time bytes would flood the log.
    if (!mounted || (data.length == 1 && data[0] >= 0xF8)) return;
    final l10n = AppLocalizations.of(context);
    _add(switch (MidiEvent.parse(data)) {
      MidiControlChange(:final controller, :final value, :final channel) =>
        l10n.midiTestReceivedCc(controller, value, channel, midiHex(data)),
      MidiProgramChange(:final program, :final channel) =>
        l10n.midiTestReceivedPc(program + 1, program, channel, midiHex(data)),
      null => l10n.midiTestReceivedOther(midiHex(data)),
    });
    _judge(data);
  }

  /// Shows what arrived during a free receive (#615); a program that
  /// arrives before an answer replaces the one shown.
  void _judge(List<int> data) {
    if (!_guideKind.receives) return;
    final received = _receiver?.add(data);
    if (received != null) setState(() => _received = received);
  }

  /// Logs whether the program shown matches the keyboard's display, then
  /// waits for the next one.
  void _confirm(bool matches) {
    final received = _received;
    if (received == null) return;
    final l10n = AppLocalizations.of(context);
    _add(
      l10n.midiGuideFreeResult(
        midiPatchLabel(l10n, _guideKind.profile.toPatch(received)),
        midiValues(received),
        matches ? l10n.midiGuideMatches : l10n.midiGuideNoMatch,
      ),
    );
    setState(() {
      _received = null;
      _checked++;
    });
  }

  // Every line also goes to the app log (logcat, "copy log" in the
  // settings), so the results can be read after the screen is closed.
  static const _appLog = Log('midi-test');

  void _add(String line) {
    _appLog.info(line);
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    setState(() => _log.insert(0, '$time  $line'));
  }

  /// The bytes to send, or null if a value is invalid.
  Uint8List? get _selected {
    int? read(TextEditingController c, int min, int max) {
      final v = int.tryParse(c.text.trim());
      return v != null && v >= min && v <= max ? v : null;
    }

    switch (_mode) {
      case _Mode.nordProgram:
        return NordStage3.program(_bank, _page, _button).bytes(_channel);
      case _Mode.nordSong:
        return NordStage3.song(_song, _part).bytes(_channel);
      case _Mode.nordLive:
        return NordStage3.live(_live).bytes(_channel);
      case _Mode.motif:
        final b = _motifBanks[_motifBank];
        final index = _motifIndex.clamp(0, b.size - 1);
        final program = _motifBank < MotifXf.performanceBanks.length
            ? MotifXf.performance(_motifBank, index)
            : MotifXf.voice(
                _motifBank - MotifXf.performanceBanks.length,
                index,
              );
        // With the mode change of the profile, as in live mode (#591).
        return const MotifXfProfile().bytes(program, _channel);
      case _Mode.raw:
        final program = read(_program, 1, 128);
        final msb = read(_msb, 0, 127);
        final lsb = read(_lsb, 0, 127);
        if (program == null ||
            (_msb.text.trim().isNotEmpty && msb == null) ||
            (_lsb.text.trim().isNotEmpty && lsb == null)) {
          return null;
        }
        return MidiProgram(
          msb: msb,
          lsb: lsb,
          program: program - 1,
        ).bytes(_channel);
      case _Mode.controlChange:
        final controller = read(_controller, 0, 127);
        final value = read(_value, 0, 127);
        if (controller == null || value == null) return null;
        return midiControlChange(_channel, controller, value);
    }
  }

  static final _motifBanks = [
    ...MotifXf.performanceBanks,
    ...MotifXf.voiceBanks,
  ];

  void _send(Uint8List bytes) {
    final l10n = AppLocalizations.of(context);
    try {
      _midi.send(bytes);
      _add(l10n.midiTestSent(midiHex(bytes)));
    } catch (e) {
      _add(l10n.midiTestError('$e'));
    }
  }

  void _sendStep() {
    _send(_guide[_step].bytes(_channel));
    setState(() => _stepSent = true);
  }

  void _answer(MidiGuideAnswer answer) {
    final l10n = AppLocalizations.of(context);
    _add(
      l10n.midiGuideResult(
        _step + 1,
        _guide[_step].title(l10n),
        answer.label(l10n),
      ),
    );
    _goTo(_step + 1);
  }

  void _goTo(int step) => setState(() {
    _step = step.clamp(0, _guide.length);
    _stepSent = false;
  });

  void _chooseGuide(MidiGuide guide) {
    _guideKind = guide;
    _guide = guide.steps();
    _listen();
    _goTo(0);
  }

  /// Starts a free receive afresh, e.g. on another channel.
  void _listen() => setState(() {
    _receiver = MidiProgramReceiver(_channel);
    _received = null;
    _checked = 0;
  });

  List<Widget> _freeReceive(AppLocalizations l10n, ThemeData theme) {
    final received = _received;
    return [
      Text(
        received == null
            ? l10n.midiGuideWaiting
            : l10n.midiGuideFreeReceived(
                midiPatchLabel(l10n, _guideKind.profile.toPatch(received)),
              ),
        key: const Key('midi-guide-received'),
        style: theme.textTheme.titleMedium,
      ),
      if (received != null) ...[
        const SizedBox(height: 4),
        Text(
          midiValues(received),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            key: const Key('midi-guide-matches'),
            onPressed: received == null ? null : () => _confirm(true),
            child: Text(l10n.midiGuideMatches),
          ),
          OutlinedButton(
            key: const Key('midi-guide-no-match'),
            onPressed: received == null ? null : () => _confirm(false),
            child: Text(l10n.midiGuideNoMatch),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        l10n.midiGuideChecked(_checked),
        key: const Key('midi-guide-checked'),
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _guideSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final done = _step >= _guide.length;
    final step = done ? null : _guide[_step];
    return [
      SectionHeader(
        l10n.midiGuideTitle,
        trailing: DropdownButton<MidiGuide>(
          key: const Key('midi-guide-kind'),
          value: _guideKind,
          items: [
            for (final g in MidiGuide.values)
              DropdownMenuItem(value: g, child: Text(g.label(l10n))),
          ],
          onChanged: (g) {
            if (g != null) _chooseGuide(g);
          },
        ),
      ),
      ListTile(
        key: const Key('midi-guide-hint'),
        subtitle: Text(_guideKind.hint(l10n)),
      ),
      Card(
        key: const Key('midi-guide'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_guideKind.receives)
                ..._freeReceive(l10n, theme)
              else if (step == null) ...[
                Text(l10n.midiGuideDone, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('midi-guide-restart'),
                  onPressed: () => _goTo(0),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.midiGuideRestart),
                ),
              ] else ...[
                Text(
                  l10n.midiGuideStep(
                    _step + 1,
                    _guide.length,
                    step.title(l10n),
                  ),
                  key: const Key('midi-guide-step'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(l10n.midiGuideExpected(step.expected(l10n))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const Key('midi-guide-send'),
                      onPressed: _connected.isEmpty ? null : _sendStep,
                      icon: const Icon(Icons.send),
                      label: Text(l10n.midiTestSend),
                    ),
                    Text(
                      midiHex(step.bytes(_channel)),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in step.answers)
                      OutlinedButton(
                        key: Key('midi-guide-answer-${a.name}'),
                        onPressed: _stepSent ? () => _answer(a) : null,
                        child: Text(a.label(l10n)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      key: const Key('midi-guide-back'),
                      onPressed: _step == 0 ? null : () => _goTo(_step - 1),
                      child: Text(l10n.midiGuideBack),
                    ),
                    TextButton(
                      key: const Key('midi-guide-skip'),
                      onPressed: () => _goTo(_step + 1),
                      child: Text(l10n.midiGuideSkip),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      const Divider(),
      SectionHeader(l10n.midiTestFree),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devices = _devices;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.midiTestTitle)),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(subtitle: Text(l10n.midiTestHint)),
            SectionHeader(
              l10n.midiTestDevices,
              trailing: TextButton.icon(
                key: const Key('midi-refresh'),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.midiTestRefresh),
              ),
            ),
            if (devices == null)
              const LoadingIndicator()
            else if (devices.isEmpty)
              ListTile(subtitle: Text(l10n.midiTestNoDevices))
            else
              for (final d in devices)
                ListTile(
                  key: Key('midi-device-${d.id}'),
                  leading: const Icon(Icons.piano_outlined),
                  title: Text(d.name),
                  subtitle: _connected.contains(d.id)
                      ? Text(l10n.midiTestConnected)
                      : null,
                  trailing: OutlinedButton(
                    onPressed: () => _toggle(d),
                    child: Text(
                      _connected.contains(d.id)
                          ? l10n.midiTestDisconnect
                          : l10n.midiTestConnect,
                    ),
                  ),
                ),
            const Divider(),
            ListTile(
              title: Text(l10n.midiTestChannel),
              trailing: DropdownButton<int>(
                key: const Key('midi-channel'),
                value: _channel,
                items: [
                  for (var c = 1; c <= 16; c++)
                    DropdownMenuItem(value: c, child: Text('$c')),
                ],
                onChanged: (v) {
                  setState(() => _channel = v ?? _channel);
                  // The free receive listens on the new channel.
                  _listen();
                },
              ),
            ),
            ..._guideSection(l10n),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // Chips that wrap: all modes stay visible in the column of
              // the page (#770), unlike a segmented button that scrolls.
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (mode, label) in [
                    (_Mode.nordProgram, l10n.midiTestModeNordProgram),
                    (_Mode.nordSong, l10n.midiTestModeNordSong),
                    (_Mode.nordLive, l10n.midiTestModeNordLive),
                    (_Mode.motif, l10n.midiTestModeMotif),
                    (_Mode.raw, l10n.midiTestModeRaw),
                    (_Mode.controlChange, l10n.midiTestModeCc),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                    ),
                ],
              ),
            ),
            ..._valueFields(l10n),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected == null
                          ? l10n.midiTestInvalid
                          : midiHex(selected),
                      key: const Key('midi-preview'),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('midi-send'),
                    onPressed: selected == null || _connected.isEmpty
                        ? null
                        : () => _send(selected),
                    icon: const Icon(Icons.send),
                    label: Text(l10n.midiTestSend),
                  ),
                ],
              ),
            ),
            const Divider(),
            SectionHeader(
              l10n.midiTestLog,
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    key: const Key('midi-copy'),
                    tooltip: l10n.midiTestCopy,
                    icon: const Icon(Icons.copy),
                    onPressed: _log.isEmpty
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(
                              ClipboardData(text: _log.reversed.join('\n')),
                            );
                            showMessageOn(messenger, l10n.midiTestCopied);
                          },
                  ),
                  IconButton(
                    tooltip: l10n.midiTestClear,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _log.isEmpty ? null : () => setState(_log.clear),
                  ),
                ],
              ),
            ),
            for (final line in _log)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: SelectableText(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _valueFields(AppLocalizations l10n) {
    Widget field(TextEditingController c, String label, Key key) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        key: key,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
      ),
    );

    Widget dropdown(
      String title,
      Key key,
      int value,
      List<int> values,
      String Function(int) label,
      void Function(int) onChanged,
    ) => ListTile(
      title: Text(title),
      trailing: DropdownButton<int>(
        key: key,
        value: value,
        items: [
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(label(v))),
        ],
        onChanged: (v) => setState(() {
          if (v != null) onChanged(v);
        }),
      ),
    );

    return switch (_mode) {
      _Mode.nordProgram => [
        dropdown(
          l10n.midiTestBank,
          const Key('midi-bank'),
          _bank,
          [for (var b = 0; b < NordStage3.banks.length; b++) b],
          (b) => NordStage3.banks[b],
          (v) => _bank = v,
        ),
        dropdown(
          l10n.midiTestPage,
          const Key('midi-page'),
          _page,
          [for (var p = 1; p <= NordStage3.pages; p++) p],
          (p) => '$p',
          (v) => _page = v,
        ),
        dropdown(
          l10n.midiTestButton,
          const Key('midi-button'),
          _button,
          [for (var b = 1; b <= NordStage3.buttons; b++) b],
          (b) => '$b',
          (v) => _button = v,
        ),
        ListTile(subtitle: Text(NordStage3.programName(_bank, _page, _button))),
      ],
      _Mode.nordSong => [
        dropdown(
          l10n.midiTestSong,
          const Key('midi-song'),
          _song,
          [for (var n = 1; n <= NordStage3.maxSong; n++) n],
          (n) => '$n',
          (v) => _song = v,
        ),
        dropdown(
          l10n.midiTestPart,
          const Key('midi-part'),
          _part,
          [for (var n = 1; n <= NordStage3.partsPerSong; n++) n],
          (n) => '$n',
          (v) => _part = v,
        ),
      ],
      _Mode.nordLive => [
        ListTile(
          title: Text(l10n.midiTestLive),
          trailing: DropdownButton<int>(
            key: const Key('midi-live'),
            value: _live,
            items: [
              for (var n = 1; n <= NordStage3.liveMemories; n++)
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: (v) => setState(() => _live = v ?? _live),
          ),
        ),
      ],
      _Mode.motif => () {
        final b = _motifBanks[_motifBank];
        final index = _motifIndex.clamp(0, b.size - 1);
        final perf = _motifBank < MotifXf.performanceBanks.length;
        return [
          dropdown(
            l10n.midiTestBank,
            const Key('midi-motif-bank'),
            _motifBank,
            [for (var i = 0; i < _motifBanks.length; i++) i],
            (i) => i < MotifXf.performanceBanks.length
                ? '${l10n.midiProgramKindPerformance} ${_motifBanks[i].name}'
                : '${l10n.midiProgramKindVoice} ${_motifBanks[i].name}',
            (v) => _motifBank = v,
          ),
          dropdown(
            l10n.midiProgramMotifNumber,
            const Key('midi-motif-index'),
            index,
            [for (var i = 0; i < b.size; i++) i],
            MotifXf.programName,
            (v) => _motifIndex = v,
          ),
          ListTile(
            subtitle: Text(
              perf
                  ? l10n.midiProgramValueMotifPerformance(
                      '${b.name} ${MotifXf.programName(index)}',
                    )
                  : l10n.midiProgramValueMotifVoice(
                      '${b.name} ${MotifXf.programName(index)}',
                    ),
            ),
          ),
        ];
      }(),
      _Mode.raw => [
        field(_msb, l10n.midiTestMsb, const Key('midi-msb')),
        field(_lsb, l10n.midiTestLsb, const Key('midi-lsb')),
        field(_program, l10n.midiTestProgram, const Key('midi-program')),
        ListTile(subtitle: Text(l10n.midiTestEmptyNotSent)),
      ],
      _Mode.controlChange => [
        field(_controller, l10n.midiTestController, const Key('midi-cc')),
        field(_value, l10n.midiTestValue, const Key('midi-cc-value')),
        ListTile(subtitle: Text(l10n.midiTestCcHint)),
      ],
    };
  }
}
