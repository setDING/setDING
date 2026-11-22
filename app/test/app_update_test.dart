import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/app.dart';
import 'package:setding/platform/self_update_io.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/sync_backend.dart';
import 'package:setding/sync/update_check.dart';
import 'package:setding/ui/home_screen.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/update/app_update.dart';
import 'package:setding/update/update_providers.dart';

import 'sync_ui_test.dart' show syncNow;
import 'test_app.dart';

const _sums =
    'https://github.com/tafli/setDING/releases/download/v0.9.0/'
    'SHA256SUMS';
const _setup =
    'https://github.com/tafli/setDING/releases/download/v0.9.0/'
    'setding-0.9.0-windows-x64-setup.exe';
final _setupBytes = utf8.encode('the setup');
final _setupHash = sha256.convert(_setupBytes).toString();

/// The GitHub release v0.9.0 with [sums] as its checksums.
MockClient _github({String? sums, int sumsStatus = 200}) =>
    MockClient((request) async {
      final url = request.url.toString();
      if (url == _sums) {
        return http.Response(
          sums ??
              '${'0' * 64}  setding-0.9.0-windows-x64.zip\n'
                  '$_setupHash  setding-0.9.0-windows-x64-setup.exe\n',
          sumsStatus,
        );
      }
      if (url == _setup) return http.Response.bytes(_setupBytes, 200);
      return http.Response('not found', 404);
    });

const _ann = AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann');

/// Updates of the Windows app from the GitHub releases (ADR-0035).
void main() {
  group('fetchUpdate', () {
    test('finds the setup of the version and its checksum', () async {
      final update = await fetchUpdate(
        _github(),
        '0.9.0',
        SelfUpdateKind.windowsSetup,
      );
      expect(update.version, '0.9.0');
      expect(update.setupName, 'setding-0.9.0-windows-x64-setup.exe');
      expect(update.setupUrl, Uri.parse(_setup));
      expect(update.sha256, _setupHash);
    });

    test('finds the AppImage of the version (ADR-0038)', () async {
      final update = await fetchUpdate(
        _github(
          sums:
              '$_setupHash  setding-0.9.0-windows-x64-setup.exe\n'
              '${'a' * 64}  setding-0.9.0-linux-x64.AppImage\n',
        ),
        '0.9.0',
        SelfUpdateKind.appImage,
      );
      expect(update.setupName, 'setding-0.9.0-linux-x64.AppImage');
      expect(
        update.setupUrl.toString(),
        'https://github.com/tafli/setDING/releases/download/v0.9.0/'
        'setding-0.9.0-linux-x64.AppImage',
      );
      expect(update.sha256, 'a' * 64);
    });

    test('fails without a checksum for the setup or without SHA256SUMS', () {
      expect(
        fetchUpdate(
          _github(sums: '${'1' * 64}  other.exe\n'),
          '0.9.0',
          SelfUpdateKind.windowsSetup,
        ),
        throwsA(isA<UpdateException>()),
      );
      expect(
        fetchUpdate(
          _github(sumsStatus: 404),
          '0.9.0',
          SelfUpdateKind.windowsSetup,
        ),
        throwsA(isA<UpdateException>()),
      );
    });
  });

  test('parseSha256Sums reads text and binary mode lines', () {
    final a = 'A' * 64;
    final b = 'b' * 64;
    expect(parseSha256Sums('$a  one.exe\n$b *two words.zip\nnot a line\n'), {
      'one.exe': 'a' * 64,
      'two words.zip': b,
    });
  });

  group('downloadVerifiedUpdate', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('setding_update'));
    tearDown(() => dir.deleteSync(recursive: true));

    AvailableUpdate update(String hash) => AvailableUpdate(
      version: '0.9.0',
      setupName: 'setding-0.9.0-windows-x64-setup.exe',
      setupUrl: Uri.parse(_setup),
      sha256: hash,
    );

    test('saves the setup when the checksum matches', () async {
      final progress = <double>[];
      final path = await downloadVerifiedUpdate(
        _github(),
        update(_setupHash),
        into: dir,
        onProgress: progress.add,
      );
      expect(File(path).readAsBytesSync(), _setupBytes);
      expect(progress.last, 1.0);
    });

    test('refuses and deletes a setup with another checksum', () async {
      await expectLater(
        downloadVerifiedUpdate(_github(), update('0' * 64), into: dir),
        throwsA(isA<UpdateException>()),
      );
      expect(dir.listSync(), isEmpty);
    });
  });

  test('only the Windows app installed with the setup updates itself', () {
    final dir = Directory.systemTemp.createTempSync('setding_install');
    addTearDown(() => dir.deleteSync(recursive: true));
    final exe = '${dir.path}${Platform.pathSeparator}setding.exe';
    // The portable zip: no uninstaller next to the executable.
    expect(isInstalledWithSetup(executable: exe, windows: true), isFalse);
    File('${dir.path}${Platform.pathSeparator}unins000.exe').createSync();
    expect(isInstalledWithSetup(executable: exe, windows: true), isTrue);
    expect(isInstalledWithSetup(executable: exe, windows: false), isFalse);
  });

  test('only the Linux app started as an AppImage updates itself', () {
    final dir = Directory.systemTemp.createTempSync('setding_appimage');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/setding.AppImage')..createSync();
    expect(
      runningAppImage(environment: {'APPIMAGE': file.path}, linux: true),
      file.path,
    );
    // The unpacked tar.gz: no AppImage runtime.
    expect(runningAppImage(environment: {}, linux: true), isNull);
    expect(
      runningAppImage(
        environment: {'APPIMAGE': '${dir.path}/gone'},
        linux: true,
      ),
      isNull,
    );
    expect(
      runningAppImage(environment: {'APPIMAGE': file.path}, linux: false),
      isNull,
    );
  });

  test('a downloaded AppImage replaces the old one, executable', () async {
    final dir = Directory.systemTemp.createTempSync('setding_appimage');
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = File('${dir.path}/setding.AppImage')
      ..writeAsStringSync('old');
    await Process.run('chmod', ['750', target.path]);
    final path = await downloadVerifiedUpdate(
      _github(),
      AvailableUpdate(
        version: '0.9.0',
        setupName: 'setding-0.9.0-linux-x64.AppImage',
        setupUrl: Uri.parse(_setup),
        sha256: _setupHash,
      ),
      to: '${target.path}.update',
    );
    await replaceAppImage(path, target.path);
    expect(target.readAsBytesSync(), _setupBytes);
    expect(File(path).existsSync(), isFalse);
    expect(target.statSync().mode & 0x1ff, 0x1e8); // 0750

    // A file that lost its executable bit gets it back.
    await Process.run('chmod', ['644', target.path]);
    File(path).writeAsStringSync('new');
    await replaceAppImage(path, target.path);
    expect(target.statSync().mode & 0x1ff, 0x1ed); // 0755
  }, skip: Platform.isWindows);

  group('installableUpdateProvider', () {
    ProviderContainer container({
      required bool supported,
      String? checked,
      String? latest,
    }) {
      final c = ProviderContainer(
        overrides: [
          selfUpdateKindProvider.overrideWithValue(
            supported ? SelfUpdateKind.windowsSetup : null,
          ),
          clientVersionProvider.overrideWithValue('0.8.0'),
          updateCheckProvider.overrideWithBuild((ref, _) => checked),
          serverConfigProvider.overrideWith(
            (ref) async => ServerConfig(latestClientVersion: latest),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('the version from the update check (ADR-0036)', () {
      expect(
        container(
          supported: true,
          checked: '0.9.0',
        ).read(installableUpdateProvider),
        '0.9.0',
      );
    });

    test('nothing where the app does not update itself', () {
      expect(
        container(
          supported: false,
          checked: '0.9.0',
        ).read(installableUpdateProvider),
        isNull,
      );
    });

    test('falls back to the server config, newer versions only', () async {
      for (final (latest, expected) in [
        ('0.9.0', '0.9.0'),
        ('0.8.0', null),
        (null, null),
      ]) {
        final c = container(supported: true, latest: latest);
        c.listen(installableUpdateProvider, (_, _) {});
        await c.read(serverConfigProvider.future);
        expect(c.read(installableUpdateProvider), expected, reason: latest);
      }
    });
  });

  group('UI', () {
    Widget build(
      TestApp app, {
      bool supported = true,
      bool enabled = true,
      Widget home = const HomeScreen(),
    }) => ProviderScope(
      overrides: [
        ...app.overrides,
        clientVersionProvider.overrideWithValue('0.8.0'),
        updateCheckEnabledProvider.overrideWithValue(enabled),
        selfUpdateKindProvider.overrideWithValue(
          supported ? SelfUpdateKind.windowsSetup : null,
        ),
      ],
      child: SetdingApp(home: home),
    );

    Future<TestApp> create(WidgetTester tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: _ann,
      );
      app.backend.addBand('b1', 'Rock', admin: _ann, organizationId: 'o1');
      app.backend.config = const ServerConfig(latestClientVersion: '0.9.0');
      return app;
    }

    Future<void> afterStartDelay(WidgetTester tester) async {
      await tester.pump(UpdateCheck.startDelay);
      await tester.pumpAndSettle();
    }

    final snackbar = find.byKey(const Key('update-available-snackbar'));
    final install = find.byKey(const Key('update-available-install'));

    Future<void> openAbout(WidgetTester tester) async {
      final about = find.byKey(const Key('settings-category-about'));
      await tester.scrollUntilVisible(
        about,
        300,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Not the last category: it may be scrolled in only partly.
      await tester.ensureVisible(about);
      await tester.pumpAndSettle();
      await tester.tap(about);
      await tester.pumpAndSettle();
    }

    testWidgets('the one-time hint offers to install, after asking', (
      tester,
    ) async {
      final app = await create(tester);
      await tester.pumpWidget(build(app));
      await afterStartDelay(tester);
      expect(snackbar, findsOneWidget);
      // In the hint; the overview's footer shows it too (ADR-0045).
      expect(
        find.descendant(
          of: snackbar,
          matching: find.text('setDING 0.9.0 is available'),
        ),
        findsOneWidget,
      );
      expect(install, findsOneWidget);
      expect(find.byKey(const Key('overview-update-install')), findsOneWidget);
      expect(find.text('Details'), findsNothing);

      // Installing asks first; cancelling changes nothing.
      await tester.tap(install);
      await tester.pumpAndSettle();
      expect(find.text('Install setDING 0.9.0?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-update-progress')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('the Storage & info tile offers to install', (tester) async {
      final app = await create(tester);
      await tester.pumpWidget(build(app, home: const SettingsScreen()));
      await afterStartDelay(tester);
      await openAbout(tester);
      expect(find.byKey(const Key('update-available')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('update-available')),
          matching: install,
        ),
        findsOneWidget,
      );
      // Installing replaces the how-to text.
      expect(find.textContaining('Obtainium'), findsNothing);

      await tester.ensureVisible(install);
      await tester.pumpAndSettle();
      await tester.tap(install);
      await tester.pumpAndSettle();
      expect(find.text('Install setDING 0.9.0?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await app.dispose(tester);
    });

    testWidgets('no install action where the app does not update itself', (
      tester,
    ) async {
      final app = await create(tester);
      await tester.pumpWidget(
        build(app, supported: false, home: const SettingsScreen()),
      );
      await afterStartDelay(tester);
      await openAbout(tester);
      expect(find.byKey(const Key('update-available')), findsOneWidget);
      expect(install, findsNothing);
      expect(find.textContaining('Obtainium'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a refused version offers to install the update', (
      tester,
    ) async {
      final app = await create(tester);
      // Before the daily check knew of the update: from the server config.
      await tester.pumpWidget(build(app, enabled: false));
      await tester.pumpAndSettle();
      app.backend.config = const ServerConfig(
        minClientVersion: '0.9.0',
        latestClientVersion: '0.9.0',
      );
      app.backend.failWith = BackendErrorKind.updateRequired;
      await syncNow(tester);

      expect(find.byKey(const Key('update-required-banner')), findsOneWidget);
      expect(find.byKey(const Key('update-install')), findsOneWidget);
      expect(find.byKey(const Key('update-copy-link')), findsNothing);
      expect(find.textContaining('Obtainium'), findsNothing);
      await app.dispose(tester);
    });
  });
}
