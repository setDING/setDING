// Helpers of the end-to-end tests (make e2e, issue #692,
// docs/development/e2e-tests.md): two clients run the real app at the same
// time against one backend and coordinate their steps through it
// (server/lib/e2e_coordinator.dart).
//
// Works on every platform: the Linux client gets its proxy's URL with
// --dart-define, the web client is served through its proxy and uses the
// page's origin.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:setding/data/database.dart';
import 'package:setding/providers.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support.dart';

/// This client's name (`a`, `b`).
const e2eClient = String.fromEnvironment('SETDING_E2E_CLIENT');
const _server = String.fromEnvironment('SETDING_E2E_SERVER');

const annaEmail = String.fromEnvironment('SETDING_E2E_ANNA_EMAIL');
const benEmail = String.fromEnvironment('SETDING_E2E_BEN_EMAIL');
const carlaEmail = String.fromEnvironment('SETDING_E2E_CARLA_EMAIL');
const e2ePassword = String.fromEnvironment('SETDING_E2E_PASSWORD');
const fixtureSong = String.fromEnvironment('SETDING_E2E_SONG');
const fixtureSheet = String.fromEnvironment('SETDING_E2E_SHEET');

/// The band of the fixture (server/bin/e2e_backend.dart).
const e2eBand = 'E2E Band';

/// This client's server: its proxy.
Uri get e2eServer => Uri.parse(_server.isNotEmpty ? _server : Uri.base.origin);

/// The device settings of both clients, set before the app starts: English,
/// and the automatic sync mode (realtime events and local changes start a
/// sync; the default only syncs at start, ADR-0004). [server] for the
/// native client; the web client's server is the page's origin.
Future<void> e2eSettings({Uri? server}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', 'en');
  await prefs.setString('syncMode', 'automatic');
  if (server != null) await prefs.setString('serverUrl', '$server');
}

Uri _control(String path, [Map<String, String>? query]) =>
    e2eServer.replace(path: '/__e2e/$path', queryParameters: query);

/// One end-to-end test: when it fails, the other client stops waiting for
/// it ([barrier] fails there with the reason).
void e2eTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Duration timeout = const Duration(minutes: 10),
}) {
  testWidgets(description, (tester) async {
    expect(e2eClient, isNotEmpty, reason: 'started by tool/e2e-test.sh');
    try {
      await body(tester);
    } catch (e) {
      final reason = 'client $e2eClient failed: ${'$e'.split('\n').first}';
      await tester.runAsync(() async {
        try {
          await http.post(_control('abort'), body: reason);
        } catch (_) {}
      });
      rethrow;
    }
  }, timeout: Timeout(timeout));
}

/// Tells the other client that this one reached [step].
Future<void> signal(WidgetTester tester, String step) async {
  final response = await tester.runAsync(
    () => http.post(_control('signal/$step')),
  );
  expect(response!.statusCode, 200, reason: 'signal $step');
  // ignore: avoid_print
  print('e2e[$e2eClient]: reached $step');
}

/// Puts this client offline (like a lost network: its requests fail, its
/// realtime connection ends) or online again. The coordination endpoints
/// keep working.
Future<void> setOnline(WidgetTester tester, {required bool online}) async {
  final response = await tester.runAsync(
    () => http.post(_control('${online ? 'online' : 'offline'}/$e2eClient')),
  );
  expect(response!.statusCode, 200, reason: 'online: $online');
  // ignore: avoid_print
  print('e2e[$e2eClient]: ${online ? 'online' : 'offline'}');
}

/// Waits until the other client reached [step]; keeps the app running
/// (pumping frames) meanwhile.
Future<void> barrier(
  WidgetTester tester,
  String step, {
  Duration timeout = const Duration(minutes: 3),
}) async {
  // ignore: avoid_print
  print('e2e[$e2eClient]: waiting for $step');
  final end = DateTime.now().add(timeout);
  while (true) {
    final response = await tester.runAsync(
      () => http.get(_control('wait/$step', {'timeout': '0.5'})),
    );
    switch (response!.statusCode) {
      case 200:
        return;
      case 410:
        fail('the other client gave up: ${response.body}');
    }
    if (DateTime.now().isAfter(end)) {
      fail('the other client did not reach $step within $timeout');
    }
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
}

/// Pumps frames until [condition] holds, checked against the database or
/// other platform state.
Future<void> eventually(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!(await tester.runAsync(condition))!) {
    if (DateTime.now().isAfter(end)) fail('$reason (within $timeout)');
    await pumpFor(tester, const Duration(milliseconds: 250));
  }
}

/// The app's provider container (on any screen).
ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
  listen: false,
);

AppDatabase databaseOf(WidgetTester tester) =>
    containerOf(tester).read(databaseProvider);

/// The song titled [title] in the local database, if any (not deleted).
Future<SongEntry?> songTitled(AppDatabase db, String title) =>
    (db.select(db.songs)
          ..where((s) => s.title.equals(title) & s.deleted.equals(false)))
        .getSingleOrNull();

/// The song with [id] in the local database, deleted or not.
Future<SongEntry?> songById(AppDatabase db, String id) =>
    (db.select(db.songs)..where((s) => s.id.equals(id))).getSingleOrNull();

/// Whether the local changes of [recordId] are pushed (not in the outbox).
Future<bool> pushed(AppDatabase db, String recordId) async =>
    await (db.select(
      db.syncOutbox,
    )..where((o) => o.recordId.equals(recordId))).getSingleOrNull() ==
    null;

/// The fixture's band in the local database, if synced.
Future<BandEntry?> fixtureBand(AppDatabase db) => (db.select(
  db.bands,
)..where((b) => b.name.equals(e2eBand))).getSingleOrNull();

/// The song ids of a set's items in their order.
Future<List<String?>> setOrder(AppDatabase db, String setId) async {
  final items =
      await (db.select(db.setItems)
            ..where((i) => i.setId.equals(setId))
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .get();
  return [for (final i in items) i.songId];
}

/// The set named [name] in the local database, if any (not deleted).
Future<SetlistEntry?> setNamed(AppDatabase db, String name) =>
    (db.select(db.setlists)
          ..where((s) => s.name.equals(name) & s.deleted.equals(false)))
        .getSingleOrNull();

/// Waits until the first sync brought the fixture (band and both songs).
Future<void> waitForFixture(WidgetTester tester) async {
  final db = databaseOf(tester);
  await eventually(
    tester,
    () async =>
        await fixtureBand(db) != null &&
        await songTitled(db, fixtureSong) != null &&
        await songTitled(db, fixtureSheet) != null,
    reason: 'the fixture was not synced',
    timeout: const Duration(seconds: 60),
  );
}

/// Text in an app bar, e.g. a song's title on its screen.
Finder appBarText(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

/// Signs [email] in through Settings → Account on a native client and goes
/// back to the home screen (the web client: `signIn` of web_support.dart).
Future<void> signInOnDesktop(WidgetTester tester, String email) async {
  final context = tester.element(find.byType(HomeScreen));
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  await pumpUntil(tester, find.byType(SettingsScreen));
  final account = find.byKey(
    Key('settings-category-${SettingsCategory.account.name}'),
  );
  await tester.scrollUntilVisible(
    account,
    200,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(account);
  await pumpUntil(tester, find.byKey(const Key('account-open-sign-in')));
  await tester.tap(find.byKey(const Key('account-open-sign-in')));
  await pumpUntil(tester, find.byKey(const Key('account-email')));
  await tester.enterText(find.byKey(const Key('account-email')), email);
  await tester.enterText(
    find.byKey(const Key('account-password')),
    e2ePassword,
  );
  await tester.tap(find.byKey(const Key('account-submit')));
  await pumpUntil(tester, find.byKey(const Key('account-sign-out')));
  expect(find.byKey(const Key('account-error')), findsNothing);
  Navigator.of(tester.element(find.byType(SettingsScreen)))
      .popUntil((route) => route.isFirst);
  await pumpUntil(tester, find.byType(HomeScreen));
}

/// Makes the fixture's band the current one; returns it.
Future<BandEntry> selectFixtureBand(WidgetTester tester) async {
  final container = containerOf(tester);
  final band = (await tester.runAsync(() => fixtureBand(databaseOf(tester))))!;
  await tester.runAsync(
    () => container.read(selectedBandIdProvider.notifier).select(band.id),
  );
  await eventually(
    tester,
    () async => container.read(currentBandProvider).id == band.id,
    reason: 'the band was not selected',
  );
  return band;
}
