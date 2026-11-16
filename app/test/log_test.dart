import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('the settings copy the diagnostic log', (tester) async {
    useTabletSize(tester, landscape: false);
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
    await tester.tap(find.byKey(const Key('copy-log')));
    await tester.pumpAndSettle();
    expect(copied, contains('[sync] Sync stopped: network'));
    expect(find.text('Diagnostic log copied'), findsOneWidget);
    await app.dispose(tester);
  });
}
