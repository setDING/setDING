import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../midi/midi_connection.dart';
import '../../midi/midi_output.dart';
import '../../settings/settings.dart';

/// The device settings of MIDI program changes to a keyboard (ADR-0039):
/// on or off, the output, the device profile, the Nord addresses and the
/// channel, with hints for the Nord Stage 3.
class MidiSettings extends ConsumerWidget {
  const MidiSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final status = ref.watch(midiConnectionProvider);
    final nord = s.midiProfile == MidiProfileKind.nordStage3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('settings-midi-enabled'),
          title: Text(l10n.settingsMidiEnabled),
          subtitle: Text(l10n.settingsMidiEnabledHint),
          value: s.midiEnabled,
          onChanged: (v) => notifier.update((s) => s.copyWith(midiEnabled: v)),
        ),
        if (s.midiEnabled) ...[
          ListTile(
            key: const Key('settings-midi-status'),
            leading: Icon(
              status.connected ? Icons.usb : Icons.usb_off,
              color: status.connected
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(
              status.connected
                  ? l10n.settingsMidiConnected(status.deviceName!)
                  : l10n.settingsMidiNotConnected,
            ),
          ),
          const _OutputPicker(),
          _segments(
            context,
            l10n.settingsMidiProfile,
            l10n.settingsMidiProfileHint,
            s.midiProfile,
            {
              MidiProfileKind.nordStage3: l10n.midiProfileNordStage3,
              MidiProfileKind.generic: l10n.midiProfileGeneric,
            },
            (v) => notifier.update((s) => s.copyWith(midiProfile: v)),
            key: const Key('settings-midi-profile'),
          ),
          if (nord)
            _segments(
              context,
              l10n.settingsNordAddresses,
              l10n.settingsNordAddressesHint,
              s.nordAddresses,
              {
                NordAddresses.programs: l10n.nordAddressesPrograms,
                NordAddresses.songs: l10n.nordAddressesSongs,
              },
              (v) => notifier.update((s) => s.copyWith(nordAddresses: v)),
              key: const Key('settings-nord-addresses'),
            ),
          ListTile(
            key: const Key('settings-midi-channel'),
            title: Text(l10n.settingsMidiChannel),
            subtitle: Text(l10n.settingsMidiChannelHint),
            trailing: DropdownButton<int>(
              value: s.midiChannel,
              items: [
                for (var c = 1; c <= 16; c++)
                  DropdownMenuItem(value: c, child: Text('$c')),
              ],
              onChanged: (v) {
                if (v != null) {
                  notifier.update((s) => s.copyWith(midiChannel: v));
                }
              },
            ),
          ),
          if (nord)
            ListTile(
              key: const Key('settings-midi-nord-hint'),
              leading: const Icon(Icons.info_outline),
              subtitle: Text(l10n.settingsMidiNordHint),
            ),
        ],
      ],
    );
  }
}

Widget _segments<T>(
  BuildContext context,
  String title,
  String hint,
  T value,
  Map<T, String> options,
  void Function(T) onChanged, {
  Key? key,
}) => ListTile(
  key: key,
  title: Text(title),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint)),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final e in options.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {value},
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      ),
    ],
  ),
);

/// The MIDI devices connected now; the chosen one is remembered by name.
class _OutputPicker extends ConsumerStatefulWidget {
  const _OutputPicker();

  @override
  ConsumerState<_OutputPicker> createState() => _OutputPickerState();
}

class _OutputPickerState extends ConsumerState<_OutputPicker> {
  List<MidiPortInfo>? _devices;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    final output = ref.read(midiOutputProvider);
    try {
      _changes = output.changes.listen((_) => _load());
    } catch (_) {
      // MIDI not available: the list stays empty.
    }
    _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final devices = await ref.read(midiOutputProvider).devices();
    if (mounted) setState(() => _devices = devices);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chosen = ref.watch(settingsProvider.select((s) => s.midiOutputName));
    final devices = _devices;
    final names = {for (final d in devices ?? const <MidiPortInfo>[]) d.name};
    void choose(String name) => ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(midiOutputName: name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(l10n.settingsMidiOutput),
          subtitle: Text(l10n.settingsMidiOutputHint),
          trailing: IconButton(
            key: const Key('settings-midi-search'),
            tooltip: l10n.settingsMidiSearch,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _load();
              ref.read(midiConnectionProvider.notifier).retry();
            },
          ),
        ),
        if (devices == null)
          const LinearProgressIndicator()
        else ...[
          for (final name in names)
            _option(name, name, selected: name == chosen, onTap: choose),
          if (chosen.isNotEmpty && !names.contains(chosen))
            _option(
              chosen,
              l10n.settingsMidiOutputMissing(chosen),
              selected: true,
              onTap: choose,
            ),
          if (names.isEmpty)
            ListTile(
              key: const Key('settings-midi-no-devices'),
              leading: const Icon(Icons.info_outline),
              subtitle: Text(l10n.settingsMidiNoDevices),
            ),
        ],
      ],
    );
  }

  Widget _option(
    String name,
    String label, {
    required bool selected,
    required void Function(String) onTap,
  }) => ListTile(
    key: Key('settings-midi-output-$name'),
    contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
    ),
    title: Text(label),
    selected: selected,
    onTap: () => onTap(name),
  );
}
