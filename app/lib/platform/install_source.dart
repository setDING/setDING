/// Which store installed the app (ADR-0067; no `dart:io`, ADR-0018).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../util/log.dart';

const _log = Log('install');

/// The package name of Google Play, as Android reports the installer.
const googlePlayInstaller = 'com.android.vending';

/// Whether Google Play installed this app; false on other platforms, for
/// other installers (Obtainium, adb) and when Android does not say.
Future<bool> detectGooglePlayInstall({
  MethodChannel channel = const MethodChannel('app.setding/install_source'),
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await channel.invokeMethod<String>('installer') ==
        googlePlayInstaller;
  } catch (e) {
    _log.info('Installer unknown: $e');
    return false;
  }
}
