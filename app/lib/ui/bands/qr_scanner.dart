import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/scanner.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Reads one QR code with the camera and returns its text, or `null` when
/// the person closes the scanner.
typedef QrScanner = Future<String?> Function(BuildContext context);

/// Whether this device scans QR codes with its camera: phones and tablets
/// (Android, iOS), not the web or the desktop (ADR-0005).
bool get canScanQrCodes =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// The scanner of the join screen: flutter_zxing (zxing-cpp, on the
/// device, no Google services). Overridden in tests.
final qrScannerProvider = Provider<QrScanner>((ref) => _scan);

Future<String?> _scan(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final barcode = await scanBarcode(
    context,
    formats: const {BarcodeFormat.qrCode},
    hint: l10n.joinScanHint,
    template: const ScannerTemplate.minimal(zoomButtons: false),
    texts: ScannerTexts(l10n),
  );
  return barcode?.text;
}

/// The texts the scanner shows, from the app's own translations: the
/// library has no Italian or Portuguese and writes "ß" in German (ADR-0008).
@visibleForTesting
class ScannerTexts extends ScannerLocalizationsEn {
  ScannerTexts(this._l10n) : super(_l10n.localeName);

  final AppLocalizations _l10n;

  @override
  String get close => _l10n.scannerClose;
  @override
  String get torchOn => _l10n.scannerTorchOn;
  @override
  String get torchOff => _l10n.scannerTorchOff;
  @override
  String get switchCamera => _l10n.scannerSwitchCamera;
  @override
  String get pickImage => _l10n.scannerPickImage;
  @override
  String get starting => _l10n.scannerStarting;
  @override
  String get permissionTitle => _l10n.scannerPermissionTitle;
  @override
  String get permissionMessage => _l10n.scannerPermissionMessage;
  @override
  String get unavailableTitle => _l10n.scannerUnavailableTitle;
  @override
  String get unavailableMessage => _l10n.scannerUnavailableMessage;
  @override
  String get inUseMessage => _l10n.scannerInUseMessage;
  @override
  String get unsupportedMessage => _l10n.scannerUnavailableMessage;
  @override
  String get photoFallback => _l10n.scannerPhotoFallback;
  @override
  String get openSettings => _l10n.scannerOpenSettings;
  @override
  String get tryAgain => _l10n.scannerTryAgain;
  @override
  String get choosePhoto => _l10n.scannerChoosePhoto;
  @override
  String get noCodeInPhoto => _l10n.scannerNoCodeInPhoto;
  @override
  String get hintCode => _l10n.joinScanHint;
  @override
  String get scanCode => _l10n.joinScan;
}
