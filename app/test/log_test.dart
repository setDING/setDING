import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:realchord/util/app_version.dart';
import 'package:realchord/ui/settings_screen.dart';
import 'package:realchord/util/log.dart';

import 'test_app.dart';

void main() {
  setUp(Log.clear);

  test('keeps the recent entries with level and area', () {
    const log = Log('sync');
    log.info('started');
    log.warning('Attachment a1 not downloaded', 'offline');
    expect(Log.recent.map((e) => (e.level, e.name)), [
      (LogLevel.info, 'sync'),
      (LogLevel.warning, 'sync'),
    ]);
    expect(
      Log.export(),
      contains('WARNING [sync] Attachment a1 not downloaded: offline'),
    );

    for (var i = 0; i < Log.capacity + 10; i++) {
      log.info('entry $i');
    }
    expect(Log.recent, hasLength(Log.capacity));
    expect(Log.recent.last.message, 'entry ${Log.capacity + 9}');
  });

  test('formats the app version with its build number', () {
    expect(formatAppVersion('0.1.1', '3'), '0.1.1 (3)');
    expect(formatAppVersion('0.1.1', ''), '0.1.1');
  });

  testWidgets('the settings show the version and copy the diagnostic log', (
    tester,
  ) async {
    useTabletSize(tester, landscape: false);
    PackageInfo.setMockInitialValues(
      appName: 'RealChord',
      packageName: 'ch.realchord.realchord',
      version: '0.1.1',
      buildNumber: '3',
      buildSignature: '',
    );
    const Log('sync').warning('Sync stopped', 'network');
    final app = await TestApp.create(prefs: {'language': 'en'});
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app.build(home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('copy-log')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('app-version')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Version 0.1.1 (3)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy-log')));
    await tester.pumpAndSettle();
    expect(copied, startsWith('RealChord 0.1.1 (3)\n'));
    expect(copied, contains('[sync] Sync stopped: network'));
    expect(find.text('Diagnostic log copied'), findsOneWidget);
    await app.dispose(tester);
  });
}
