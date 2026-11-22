import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../util/log.dart';

/// What the platform tells about keyboards (ADR-0057).
enum InputDeviceSupport {
  /// The device of every key and the connected keyboards, with names and
  /// IDs: pairing and connection (Android, Windows).
  devices,

  /// Only whether a hardware keyboard is connected, without a name (iOS).
  keyboardOnly,

  /// Nothing (web, Linux, macOS).
  none,
}

/// A keyboard as the platform reports it; a page turner is one.
@immutable
class InputDeviceInfo {
  const InputDeviceInfo({
    required this.name,
    this.vendorId = 0,
    this.productId = 0,
  });

  factory InputDeviceInfo.fromMap(Map<Object?, Object?> map) => InputDeviceInfo(
    name: (map['name'] as String?)?.trim() ?? '',
    vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
    productId: (map['productId'] as num?)?.toInt() ?? 0,
  );

  final String name;

  /// USB / Bluetooth vendor and product ID; 0 when the platform does not
  /// know them.
  final int vendorId;
  final int productId;

  bool get hasIds => vendorId != 0 || productId != 0;

  /// Whether this is the device [paired] (ADR-0057): with vendor and
  /// product ID on both sides those alone, so a name that changes with the
  /// firmware (e.g. "DUO500 v3.0.13 6887") still matches; otherwise the
  /// name.
  bool matches(InputDeviceInfo paired) {
    if (hasIds && paired.hasIds) {
      return vendorId == paired.vendorId && productId == paired.productId;
    }
    return name == paired.name;
  }

  @override
  bool operator ==(Object other) =>
      other is InputDeviceInfo &&
      other.name == name &&
      other.vendorId == vendorId &&
      other.productId == productId;

  @override
  int get hashCode => Object.hash(name, vendorId, productId);

  @override
  String toString() =>
      'InputDeviceInfo($name, ${vendorId.toRadixString(16)}:'
      '${productId.toRadixString(16)})';
}

/// The keyboards of the platform (ADR-0057): which are connected, which one
/// a key came from, and when that changes. Tests use a fake.
abstract class InputDevices {
  InputDeviceSupport get support;

  /// The connected external keyboards. With [InputDeviceSupport.keyboardOnly]
  /// one entry without a name when a keyboard is connected.
  Future<List<InputDeviceInfo>> devices();

  /// The device of every key pressed down (only with
  /// [InputDeviceSupport.devices]).
  Stream<InputDeviceInfo> get keys;

  /// A keyboard was connected or disconnected.
  Stream<void> get changes;
}

/// The support of the platform the app runs on.
InputDeviceSupport platformInputDeviceSupport() {
  if (kIsWeb) return InputDeviceSupport.none;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.windows => InputDeviceSupport.devices,
    TargetPlatform.iOS => InputDeviceSupport.keyboardOnly,
    _ => InputDeviceSupport.none,
  };
}

/// [InputDevices] through the channel `app.setding/input_devices` of the
/// Android, Windows and iOS runners. Errors are logged; a missing platform
/// side means no devices.
class ChannelInputDevices implements InputDevices {
  ChannelInputDevices({InputDeviceSupport? support})
    : support = support ?? platformInputDeviceSupport();

  static const _log = Log('input');
  static const _methods = MethodChannel('app.setding/input_devices');
  static const _events = EventChannel('app.setding/input_devices/events');

  @override
  final InputDeviceSupport support;

  Stream<Map<Object?, Object?>>? _stream;

  Stream<Map<Object?, Object?>> get _all =>
      _stream ??= support == InputDeviceSupport.none
      ? const Stream.empty()
      : _events
            .receiveBroadcastStream()
            .where((e) => e is Map)
            .cast<Map<Object?, Object?>>()
            .handleError((Object e) => _log.warning('Input events failed', e))
            .asBroadcastStream();

  @override
  Future<List<InputDeviceInfo>> devices() async {
    if (support == InputDeviceSupport.none) return const [];
    try {
      final list = await _methods.invokeListMethod<Object?>('devices');
      return [
        for (final d in list ?? const [])
          if (d is Map) InputDeviceInfo.fromMap(d),
      ];
    } on MissingPluginException {
      return const [];
    } catch (e) {
      _log.warning('Input devices failed', e);
      return const [];
    }
  }

  @override
  Stream<InputDeviceInfo> get keys => _all
      .where((e) => e['type'] == 'key' && e['device'] is Map)
      .map((e) => InputDeviceInfo.fromMap(e['device']! as Map));

  @override
  Stream<void> get changes => _all.where((e) => e['type'] == 'changed');
}
