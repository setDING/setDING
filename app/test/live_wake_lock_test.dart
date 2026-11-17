import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/platform/stage_wake_lock.dart';
import 'package:setding/ui/live/live_screen.dart';

import 'test_app.dart';

/// Turning the screen on takes longer than turning it off.
class _SlowOnPlatform extends FakeWakeLockPlatform {
  @override
  Future<void> setEnabled(bool enabled) async {
    await Future<void>.delayed(Duration(milliseconds: enabled ? 20 : 1));
    await super.setEnabled(enabled);
  }
}

/// The screen stays on while live mode is open (ADR-0007, #294).
void main() {
  group('StageWakeLock', () {
    test('keeps the screen on while a live view holds it', () async {
      final platform = FakeWakeLockPlatform();
      final lock = StageWakeLock(platform);
      await lock.acquire();
      expect(platform.on, isTrue);
      await lock.release();
      expect(platform.on, isFalse);
      expect(lock.failed, isFalse);
    });

    test('a late release of one view does not turn off another', () async {
      final platform = FakeWakeLockPlatform();
      final lock = StageWakeLock(platform);
      await lock.acquire();
      // Live mode opened again before the old view is disposed.
      await lock.acquire();
      await lock.release();
      expect(platform.on, isTrue);
      await lock.release();
      expect(platform.on, isFalse);
      // More releases than acquires do not count below zero.
      await lock.release();
      await lock.acquire();
      expect(platform.on, isTrue);
    });

    test('changes are applied in order, the last one wins', () async {
      final platform = _SlowOnPlatform();
      final lock = StageWakeLock(platform);
      // Not awaited: the slow "on" must not land after the fast "off".
      unawaited(lock.acquire());
      await lock.release();
      // Long enough for a slow "on" to land if it were not in order.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(platform.on, isFalse);
    });

    test('reassert turns the screen on again', () async {
      final platform = FakeWakeLockPlatform();
      final lock = StageWakeLock(platform);
      await lock.acquire();
      platform.on = false; // e.g. reset by the system in the background
      await lock.reassert();
      expect(platform.on, isTrue);
    });

    test('reports a failure and clears it when released', () async {
      final platform = FakeWakeLockPlatform()..fail = true;
      final lock = StageWakeLock(platform);
      var notified = 0;
      lock.addListener(() => notified++);
      await lock.acquire();
      expect(lock.failed, isTrue);
      expect(notified, 1);
      await lock.release();
      expect(lock.failed, isFalse);
      expect(notified, 2);
    });

    test('a platform that does not keep the screen on is a failure', () async {
      final platform = _IgnoringPlatform();
      final lock = StageWakeLock(platform);
      await lock.acquire();
      expect(lock.failed, isTrue);
    });
  });

  group('live mode', () {
    late BuildContext home;

    Future<TestApp> pumpHome(WidgetTester tester, {bool fail = false}) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      app.wakeLock.fail = fail;
      final id = (await tester.runAsync(
        () => app.songs.createSong(source: '{title: One}\n[C]La la'),
      ))!;
      final song = (await tester.runAsync(() => app.songs.getSong(id)))!;
      await tester.pumpWidget(
        app.build(
          home: Builder(
            builder: (context) {
              home = context;
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            LiveScreen(items: [LiveItem.song(song)]),
                      ),
                    ),
                    child: const Text('Live'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return app;
    }

    Future<void> openLive(WidgetTester tester) async {
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the screen on until live mode is left', (tester) async {
      final app = await pumpHome(tester);
      expect(app.wakeLock.on, isFalse);
      await openLive(tester);
      expect(app.wakeLock.on, isTrue);
      expect(find.byKey(const Key('live-wakelock-notice')), findsNothing);

      // A sheet opened from live mode keeps it on.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Set overview'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(app.wakeLock.on, isTrue);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Exit live mode'));
      await tester.pumpAndSettle();
      expect(find.byType(LiveScreen), findsNothing);
      expect(app.wakeLock.on, isFalse);
      await app.dispose(tester);
    });

    testWidgets('leaving and opening live mode again keeps the screen on', (
      tester,
    ) async {
      final app = await pumpHome(tester);
      await openLive(tester);
      // The old live view is disposed only after the new one has started.
      Navigator.of(home).pop();
      await tester.pump();
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(find.byType(LiveScreen), findsOneWidget);
      expect(app.wakeLock.on, isTrue);
      await app.dispose(tester);
    });

    testWidgets('returning to the app turns the screen on again', (
      tester,
    ) async {
      final app = await pumpHome(tester);
      await openLive(tester);
      // The platform reports the states one after another.
      void go(List<AppLifecycleState> states) {
        for (final state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      go(const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump();
      app.wakeLock.on = false; // released by the system in the background
      go(const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pumpAndSettle();
      expect(app.wakeLock.on, isTrue);
      await app.dispose(tester);
    });

    testWidgets('says so when the screen may turn off', (tester) async {
      final app = await pumpHome(tester, fail: true);
      await openLive(tester);
      expect(find.byKey(const Key('live-wakelock-notice')), findsOneWidget);
      expect(
        find.text(
          "The screen may turn off – check the device's power settings",
        ),
        findsOneWidget,
      );
      await app.dispose(tester);
    });
  });
}

/// Accepts the switch but never keeps the screen on.
class _IgnoringPlatform extends FakeWakeLockPlatform {
  @override
  Future<bool> get enabled async => false;
}
