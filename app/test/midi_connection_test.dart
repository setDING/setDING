import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/midi/midi_connection.dart';
import 'package:setding/midi/midi_message.dart';
import 'package:setding/midi/midi_output.dart';
import 'package:setding/midi/midi_profile.dart';
import 'package:setding/settings/settings.dart';

import 'fake_midi_output.dart';
import 'test_app.dart';

const _nord = MidiPortInfo(id: 'usb-1', name: 'Nord Stage 3', connected: false);
const _other = MidiPortInfo(id: 'usb-2', name: 'Other', connected: false);

/// The MIDI connection to the keyboard (ADR-0039).
void main() {
  late TestApp app;
  late ProviderContainer container;
  late FakeMidiOutput midi;

  Future<void> start([
    Map<String, Object> prefs = const {},
    List<MidiPortInfo> ports = const [],
  ]) async {
    app = await TestApp.create(prefs: {'instrument': 'keyboard', ...prefs});
    midi = app.midiOutput..ports = ports;
    container = ProviderContainer(overrides: app.overrides);
    // As the app does from its start.
    container.listen(midiConnectionProvider, (_, _) {});
  }

  tearDown(() async {
    container.dispose();
    await app.db.close();
    app.dir.deleteSync(recursive: true);
  });

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  MidiStatus status() => container.read(midiConnectionProvider);
  MidiConnection connection() =>
      container.read(midiConnectionProvider.notifier);

  Future<void> change(AppSettings Function(AppSettings) f) async {
    await container.read(settingsProvider.notifier).update(f);
    await settle();
  }

  test('off for another instrument: does not touch MIDI, sends nothing and '
      'connects once the instrument is keyboard (#578)', () async {
    await start(
      {
        'instrument': 'guitar',
        'midiEnabled': true,
        'midiOutputName': 'Nord Stage 3',
      },
      [_nord],
    );
    await settle();
    expect(status(), MidiStatus.off);
    expect(midi.connects, isEmpty);
    expect(connection().send(const MidiProgram(program: 1)), isFalse);
    expect(midi.sent, isEmpty);

    await change((s) => s.copyWith(instrument: 'keyboard'));
    expect(status().enabled, isTrue);
    expect(status().connected, isTrue);
  });

  test('off by default: does not touch MIDI and sends nothing', () async {
    await start();
    midi.ports = [_nord];
    await settle();
    expect(status(), MidiStatus.off);
    expect(status().enabled, isFalse);
    expect(midi.connects, isEmpty);
    expect(connection().send(const MidiProgram(program: 1)), isFalse);
    expect(midi.sent, isEmpty);
  });

  test('connects to the remembered output from the start and sends on the '
      'channel of the settings', () async {
    await start({
      'midiEnabled': true,
      'midiOutputName': 'Nord Stage 3',
      'midiChannel': 3,
    });
    // Plugged in after the start.
    midi.plugIn([_other, _nord]);
    await settle();
    expect(status().connected, isTrue);
    expect(status().deviceName, 'Nord Stage 3');
    expect(midi.connected, {'usb-1'});

    const program = MidiProgram(msb: 0, lsb: 2, program: 12);
    expect(connection().send(program), isTrue);
    expect(midi.sent, [program.bytes(3)]);
    expect(midi.sentTo, ['usb-1']);

    // The channel is read when sending.
    await change((s) => s.copyWith(midiChannel: 16));
    expect(status().connected, isTrue);
    connection().send(program);
    expect(midi.sent.last, program.bytes(16));
  });

  test('a device that is there at the start is connected', () async {
    await start(
      {'midiEnabled': true, 'midiOutputName': 'Nord Stage 3'},
      [_nord],
    );
    await settle();
    expect(status(), const MidiStatus.connected('usb-1', 'Nord Stage 3'));
  });

  test('not connected without a chosen output or when it is not plugged in; '
      'reconnects without asking when it is plugged in again', () async {
    await start({'midiEnabled': true});
    midi.ports = [_nord];
    await settle();
    expect(status(), MidiStatus.notConnected);
    expect(status().enabled, isTrue);
    expect(midi.connects, isEmpty);

    // Chosen in the settings: connected.
    await change((s) => s.copyWith(midiOutputName: 'Nord Stage 3'));
    expect(status().connected, isTrue);

    // Unplugged: not connected, nothing is sent.
    midi.plugIn([_other]);
    await settle();
    expect(status(), MidiStatus.notConnected);
    expect(connection().send(const MidiProgram(program: 1)), isFalse);
    expect(midi.sent, isEmpty);

    // Plugged in again, with a new id: connected again.
    midi.plugIn([
      _other,
      const MidiPortInfo(id: 'usb-9', name: 'Nord Stage 3', connected: false),
    ]);
    await settle();
    expect(status(), const MidiStatus.connected('usb-9', 'Nord Stage 3'));
    expect(midi.connects, ['usb-1', 'usb-9']);

    // Other changes do not connect again.
    midi.plugIn([...midi.ports]);
    await settle();
    expect(midi.connects, ['usb-1', 'usb-9']);
  });

  test('a failing connect is logged and leaves it not connected; the next '
      'change tries again', () async {
    await start({'midiEnabled': true, 'midiOutputName': 'Nord Stage 3'});
    midi.failConnect = true;
    midi.plugIn([_nord]);
    await settle();
    expect(status(), MidiStatus.notConnected);

    midi.failConnect = false;
    midi.plugIn([_nord]);
    await settle();
    expect(status().connected, isTrue);
  });

  test('switching MIDI off or choosing another output lets go of the '
      'device', () async {
    await start({'midiEnabled': true, 'midiOutputName': 'Nord Stage 3'});
    midi.plugIn([_nord, _other]);
    await settle();
    expect(status().connected, isTrue);

    await change((s) => s.copyWith(midiOutputName: 'Other'));
    expect(midi.disconnected, ['usb-1']);
    expect(status(), const MidiStatus.connected('usb-2', 'Other'));

    await change((s) => s.copyWith(midiEnabled: false));
    expect(midi.disconnected, ['usb-1', 'usb-2']);
    expect(status(), MidiStatus.off);
    expect(connection().send(const MidiProgram(program: 1)), isFalse);

    // Changes of the devices do nothing while MIDI is off.
    midi.plugIn([_nord, _other]);
    await settle();
    expect(midi.connects, ['usb-1', 'usb-2']);
  });

  test('the profile follows the settings', () async {
    await start();
    expect(container.read(midiProfileProvider), const NordStage3Profile());
    await change((s) => s.copyWith(midiProfile: MidiProfileKind.generic));
    expect(container.read(midiProfileProvider), const GenericProfile());
  });
}
