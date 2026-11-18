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

/// A GitHub "latest release" answer.
Map<String, Object?> _release({
  String tag = 'v0.9.0',
  bool prerelease = false,
  bool withSetup = true,
  bool withSums = true,
}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': prerelease,
  'assets': [
    {
      'name': 'setding-0.9.0-windows-x64.zip',
      'browser_download_url': 'https://example.test/zip',
    },
    if (withSetup)
      {
        'name': 'setding-0.9.0-windows-x64-setup.exe',
        'browser_download_url': _setup,
      },
    if (withSums) {'name': 'SHA256SUMS', 'browser_download_url': _sums},
  ],
};

/// GitHub with [release] as the latest release and [sums] as its checksums.
MockClient _github(Object? release, {String? sums, int status = 200}) =>
    MockClient((request) async {
      final url = request.url.toString();
      if (url == 'https://api.github.com/repos/tafli/setDING/releases/latest') {
        expect(request.headers['Accept'], 'application/vnd.github+json');
        return http.Response(jsonEncode(release), status);
      }
      if (url == _sums) {
        return http.Response(
          sums ??
              '${'0' * 64}  setding-0.9.0-windows-x64.zip\n'
                  '$_setupHash  setding-0.9.0-windows-x64-setup.exe\n',
          200,
        );
      }
      if (url == _setup) return http.Response.bytes(_setupBytes, 200);
      return http.Response('not found', 404);
    });

/// Updates of the Windows app from the GitHub releases (ADR-0035).
void main() {
  group('fetchAvailableUpdate', () {
    test('offers a newer release with its setup and checksum', () async {
      final update = await fetchAvailableUpdate(
        _github(_release()),
        currentVersion: '0.8.2',
      );
      expect(update, isNotNull);
      expect(update!.version, '0.9.0');
      expect(update.setupName, 'setding-0.9.0-windows-x64-setup.exe');
      expect(update.setupUrl, Uri.parse(_setup));
      expect(update.sha256, _setupHash);
    });

    test('offers nothing for the same or an older version', () async {
      for (final current in ['0.9.0', '0.10.0', '1.0.0']) {
        expect(
          await fetchAvailableUpdate(
            _github(_release()),
            currentVersion: current,
          ),
          isNull,
          reason: current,
        );
      }
    });

    test(
      'offers nothing for pre-releases and releases without a setup',
      () async {
        for (final release in [
          _release(prerelease: true),
          _release(withSetup: false),
          _release(withSums: false),
        ]) {
          expect(
            await fetchAvailableUpdate(
              _github(release),
              currentVersion: '0.8.0',
            ),
            isNull,
          );
        }
      },
    );

    test('offers nothing before the first release', () async {
      expect(
        await fetchAvailableUpdate(
          _github({'message': 'Not Found'}, status: 404),
          currentVersion: '0.8.0',
        ),
        isNull,
      );
    });

    test('fails without a checksum for the setup or on server errors', () {
      expect(
        fetchAvailableUpdate(
          _github(_release(), sums: '${'1' * 64}  other.exe\n'),
          currentVersion: '0.8.0',
        ),
        throwsA(isA<UpdateException>()),
      );
      expect(
        fetchAvailableUpdate(
          _github({'message': 'rate limited'}, status: 403),
          currentVersion: '0.8.0',
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
        _github(_release()),
        update(_setupHash),
        into: dir,
        onProgress: progress.add,
      );
      expect(File(path).readAsBytesSync(), _setupBytes);
      expect(progress.last, 1.0);
    });

    test('refuses and deletes a setup with another checksum', () async {
      await expectLater(
        downloadVerifiedUpdate(
          _github(_release()),
          update('0' * 64),
          into: dir,
        ),
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

  group('UI', () {
    final update = AvailableUpdate(
      version: '0.9.0',
      setupName: 'setding-0.9.0-windows-x64-setup.exe',
      setupUrl: Uri.parse(_setup),
      sha256: _setupHash,
    );

    Widget build(
      TestApp app,
      Widget home, {
      required Future<AvailableUpdate?> Function() check,
    }) => ProviderScope(
      overrides: [
        ...app.overrides,
        clientVersionProvider.overrideWithValue('0.8.0'),
        selfUpdateSupportedProvider.overrideWithValue(true),
        availableUpdateProvider.overrideWith((ref) => check()),
      ],
      child: SetdingApp(home: home),
    );

    testWidgets('the banner offers a newer version until put off', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.pumpWidget(
        build(app, const HomeScreen(), check: () async => update),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-update-banner')), findsOneWidget);
      expect(find.text('setDING 0.9.0 is available.'), findsOneWidget);

      // Installing asks first; cancelling changes nothing.
      await tester.tap(find.byKey(const Key('app-update-install')));
      await tester.pumpAndSettle();
      expect(find.text('Install setDING 0.9.0?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-update-progress')), findsNothing);

      await tester.tap(find.byKey(const Key('app-update-later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-update-banner')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('no banner when the app is current', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.pumpWidget(
        build(app, const HomeScreen(), check: () async => null),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-update-banner')), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('a refused version offers to install the update', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(
        prefs: {'language': 'en', 'currentBandId': 'b1'},
        user: const AuthUser(id: 'ann', email: 'ann@example.test', name: 'Ann'),
      );
      await tester.pumpWidget(
        build(app, const HomeScreen(), check: () async => update),
      );
      await tester.pumpAndSettle();
      app.backend.config = const ServerConfig(minClientVersion: '0.9.0');
      app.backend.failWith = BackendErrorKind.updateRequired;
      await syncNow(tester);

      // The update-required banner replaces the offer and installs directly.
      expect(find.byKey(const Key('update-required-banner')), findsOneWidget);
      expect(find.byKey(const Key('app-update-banner')), findsNothing);
      expect(find.byKey(const Key('update-install')), findsOneWidget);
      expect(find.byKey(const Key('update-copy-link')), findsNothing);
      expect(find.textContaining('Obtainium'), findsNothing);
      await app.dispose(tester);
    });

    Future<void> openCategory(WidgetTester tester) async {
      final category = find.byKey(const Key('settings-category-about'));
      if (category.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          category,
          100,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(category);
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
    }

    Future<void> openAbout(WidgetTester tester) async {
      await openCategory(tester);
      await tester.ensureVisible(find.byKey(const Key('app-update-tile')));
      await tester.pumpAndSettle();
    }

    testWidgets('the settings show the update and check again on tap', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      var checks = 0;
      AvailableUpdate? next;
      await tester.pumpWidget(
        build(
          app,
          const SettingsScreen(),
          check: () async {
            checks++;
            return next;
          },
        ),
      );
      await tester.pumpAndSettle();
      await openAbout(tester);
      expect(
        find.text('setDING is up to date. Tap to check again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('app-update-tile-install')), findsNothing);

      next = update;
      final before = checks;
      await tester.tap(find.byKey(const Key('app-update-tile')));
      await tester.pumpAndSettle();
      expect(checks, before + 1);
      expect(find.text('setDING 0.9.0 is available.'), findsWidgets);
      expect(find.byKey(const Key('app-update-tile-install')), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('a failed check says so in the settings', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.pumpWidget(
        build(
          app,
          const SettingsScreen(),
          check: () async => throw const UpdateException('offline'),
        ),
      );
      await tester.pumpAndSettle();
      await openAbout(tester);
      expect(
        find.textContaining('Could not check for updates'),
        findsOneWidget,
      );
      await app.dispose(tester);
    });

    testWidgets('no update tile where the app does not update itself', (
      tester,
    ) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.pumpWidget(app.build(home: const SettingsScreen()));
      await tester.pumpAndSettle();
      await openCategory(tester);
      expect(find.byKey(const Key('app-version')), findsOneWidget);
      expect(find.byKey(const Key('app-update-tile')), findsNothing);
      await app.dispose(tester);
    });
  });
}
