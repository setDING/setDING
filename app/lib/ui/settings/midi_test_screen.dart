import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_message.dart';
import '../../midi/midi_output.dart';

/// Prototype of ADR-0039 (#512): sends a program change to a keyboard
/// connected by USB and logs what the keyboard sends back, to check the
/// MIDI library on every platform and the addressing of a Nord Stage 3.
class MidiTestScreen extends ConsumerStatefulWidget {
  const MidiTestScreen({super.key});

  @override
  ConsumerState<MidiTestScreen> createState() => _MidiTestScreenState();
}

enum _Mode { nordProgram, nordSong, nordLive, raw, controlChange }

class _MidiTestScreenState extends ConsumerState<MidiTestScreen> {
  late final MidiOutput _midi;
  final _subscriptions = <StreamSubscription<void>>[];

  List<MidiPortInfo>? _devices;
  final _connected = <String>{};
  var _channel = 1;
  var _mode = _Mode.nordProgram;
  var _bank = 0;
  var _live = 1;
  final _number = TextEditingController(text: '1');
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
    _number.dispose();
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
  }

  void _add(String line) {
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
      case _Mode.nordSong:
        final n = read(_number, 1, NordStage3.programsPerBank);
        if (n == null) return null;
        return (_mode == _Mode.nordProgram
                ? NordStage3.program(_bank, n)
                : NordStage3.song(_bank, n))
            .bytes(_channel);
      case _Mode.nordLive:
        return NordStage3.live(_live).bytes(_channel);
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

  void _send(Uint8List bytes) {
    final l10n = AppLocalizations.of(context);
    try {
      _midi.send(bytes);
      _add(l10n.midiTestSent(midiHex(bytes)));
    } catch (e) {
      _add(l10n.midiTestError('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final devices = _devices;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.midiTestTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(subtitle: Text(l10n.midiTestHint)),
          ListTile(
            title: Text(
              l10n.midiTestDevices,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            trailing: TextButton.icon(
              key: const Key('midi-refresh'),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.midiTestRefresh),
            ),
          ),
          if (devices == null)
            const Center(child: CircularProgressIndicator())
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
              onChanged: (v) => setState(() => _channel = v ?? _channel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_Mode>(
                segments: [
                  ButtonSegment(
                    value: _Mode.nordProgram,
                    label: Text(l10n.midiTestModeNordProgram),
                  ),
                  ButtonSegment(
                    value: _Mode.nordSong,
                    label: Text(l10n.midiTestModeNordSong),
                  ),
                  ButtonSegment(
                    value: _Mode.nordLive,
                    label: Text(l10n.midiTestModeNordLive),
                  ),
                  ButtonSegment(
                    value: _Mode.raw,
                    label: Text(l10n.midiTestModeRaw),
                  ),
                  ButtonSegment(
                    value: _Mode.controlChange,
                    label: Text(l10n.midiTestModeCc),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (m) => setState(() => _mode = m.single),
              ),
            ),
          ),
          ..._valueFields(l10n),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected == null ? l10n.midiTestInvalid : midiHex(selected),
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
          ListTile(
            title: Text(
              l10n.midiTestLog,
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.midiTestCopied)),
                          );
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: SelectableText(
                line,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
        ],
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

    return switch (_mode) {
      _Mode.nordProgram || _Mode.nordSong => [
        ListTile(
          title: Text(l10n.midiTestBank),
          trailing: DropdownButton<int>(
            key: const Key('midi-bank'),
            value: _bank,
            items: [
              for (var b = 0; b < NordStage3.banks.length; b++)
                DropdownMenuItem(value: b, child: Text(NordStage3.banks[b])),
            ],
            onChanged: (v) => setState(() => _bank = v ?? _bank),
          ),
        ),
        field(_number, l10n.midiTestNumber, const Key('midi-number')),
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
