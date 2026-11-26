import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/ui/bands/join_screen.dart';
import 'package:setding/ui/bands/qr_scanner.dart';

import 'test_app.dart';

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');
const _bob = AuthUser(id: 'bob', email: 'bob@example.test', name: 'Bob');

/// Scanning an invitation QR code on the join screen (#1103, ADR-0005).
void main() {
  // What the fake scanner reads; null as if the person closed it.
  String? scanned;

  setUp(() => scanned = null);

  Future<TestApp> pump(WidgetTester tester) async {
    useTabletSize(tester);
    final app = await TestApp.create(prefs: {'language': 'en'}, user: _bob);
    app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
    app.backend.organizations['o1'] = 'School';
    await tester.pumpWidget(
      app.build(
        home: const JoinScreen(),
        extra: [qrScannerProvider.overrideWithValue((_) async => scanned)],
      ),
    );
    await tester.pumpAndSettle();
    return app;
  }

  Future<String> invite(TestApp app) async {
    app.backend.user = _ann;
    final created = await app.backend.createInvite('o1');
    app.backend.user = _bob;
    return created.url;
  }

  testWidgets('a scanned invitation link is checked and joins', (tester) async {
    final app = await pump(tester);
    scanned = ' ${await invite(app)}\n';

    await tester.tap(find.byKey(const Key('join-scan')));
    await tester.pumpAndSettle();
    expect(find.text('Join School?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-button')));
    await tester.pumpAndSettle();
    expect(
      app.backend.orgMembers.where((m) => m.user.id == 'bob').single.scopeId,
      'o1',
    );
    await app.dispose(tester);
  });

  testWidgets('another QR code is not an invitation', (tester) async {
    scanned = 'https://example.com/menu';
    final app = await pump(tester);
    await tester.tap(find.byKey(const Key('join-scan')));
    await tester.pumpAndSettle();
    expect(find.text('This is not a valid invitation link.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('closing the scanner changes nothing', (tester) async {
    final app = await pump(tester);
    await tester.tap(find.byKey(const Key('join-scan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-error')), findsNothing);
    expect(find.byKey(const Key('join-continue')), findsOneWidget);
    await app.dispose(tester);
  });

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    testWidgets('no scan button on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final app = await pump(tester);
        expect(find.byKey(const Key('join-scan')), findsNothing);
        expect(find.byKey(const Key('join-link')), findsOneWidget);
        await app.dispose(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test('scanning works on Android and iOS only', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        canScanQrCodes,
        platform == TargetPlatform.android || platform == TargetPlatform.iOS,
        reason: platform.name,
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('the scanner shows the app\'s own texts in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final texts = ScannerTexts(l10n);
      expect(texts.close, l10n.scannerClose);
      expect(texts.permissionMessage, l10n.scannerPermissionMessage);
      expect(texts.hintCode, l10n.joinScanHint);
      for (final text in [
        texts.close,
        texts.torchOn,
        texts.torchOff,
        texts.switchCamera,
        texts.pickImage,
        texts.starting,
        texts.permissionTitle,
        texts.permissionMessage,
        texts.unavailableTitle,
        texts.unavailableMessage,
        texts.inUseMessage,
        texts.unsupportedMessage,
        texts.photoFallback,
        texts.openSettings,
        texts.tryAgain,
        texts.choosePhoto,
        texts.noCodeInPhoto,
        texts.scanCode,
      ]) {
        expect(text, isNot(contains('ß')), reason: '$locale');
      }
    }
    expect(
      ScannerTexts(lookupAppLocalizations(const Locale('de'))).close,
      'Scanner schliessen',
    );
  });
}
