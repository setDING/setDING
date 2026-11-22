import 'dart:async';

import 'package:setding/platform/input_devices.dart';

/// The keyboards of the platform (ADR-0057), in memory: [connected] is what
/// `devices` reports, [press] sends a key from a device and [connect] /
/// [disconnect] change the list and report it.
class FakeInputDevices implements InputDevices {
  FakeInputDevices({this.support = InputDeviceSupport.devices});

  @override
  InputDeviceSupport support;

  final connected = <InputDeviceInfo>[];
  final _keys = StreamController<InputDeviceInfo>.broadcast();
  final _changes = StreamController<void>.broadcast();

  void press(InputDeviceInfo device) => _keys.add(device);

  void connect(InputDeviceInfo device) {
    connected.add(device);
    _changes.add(null);
  }

  void disconnect(InputDeviceInfo device) {
    connected.remove(device);
    _changes.add(null);
  }

  @override
  Future<List<InputDeviceInfo>> devices() async => List.of(connected);

  @override
  Stream<InputDeviceInfo> get keys => _keys.stream;

  @override
  Stream<void> get changes => _changes.stream;
}
