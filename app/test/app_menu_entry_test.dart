import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:setding/platform/app_menu_entry_io.dart';
import 'package:setding/ui/settings/settings_layout.dart';
import 'package:setding/ui/settings_screen.dart';
import 'package:setding/update/app_menu_entry.dart';

import 'test_app.dart';

/// The application menu entry of the Linux AppImage (#1006).
void main() {
  group('DesktopFileMenuEntry', () {
    late Directory root;
    late String bundle;
    late String data;
    late String appImage;
    var refreshed = 0;
    var registered = 0;

    setUp(() {
      root = Directory.systemTemp.createTempSync('setding-menu-');
      bundle = p.join(root.path, 'bundle');
      data = p.join(root.path, 'share');
      appImage = p.join(root.path, 'Apps', 'setding.AppImage');
      Directory(p.join(bundle, 'data')).createSync(recursive: true);
      // The template of the bundle (app/linux/packaging).
      File('linux/packaging/app.setding.desktop.in')
          .copySync(p.join(bundle, 'app.setding.desktop.in'));
      File(p.join(bundle, 'data', 'app_icon.png')).writeAsStringSync('png');
      File(p.join(bundle, 'data', 'app_icon.svg')).writeAsStringSync('svg');
      File(appImage)
        ..createSync(recursive: true)
        ..writeAsStringSync('appimage');
      refreshed = 0;
      registered = 0;
    });
    tearDown(() => root.deleteSync(recursive: true));

    DesktopFileMenuEntry entry([String? image]) => DesktopFileMenuEntry(
      appImage: image ?? appImage,
      bundleDir: bundle,
      dataHome: data,
      refresh: (_) async => refreshed++,
      registerLinks: () async => registered++,
    );
    File desktopFile() =>
        File(p.join(data, 'applications', 'app.setding.desktop'));

    test('installs the entry and the icon, and removes them', () async {
      final e = entry();
      expect(await e.state(), AppMenuEntryState.missing);
      await e.install();
      expect(await e.state(), AppMenuEntryState.installed);
      final content = desktopFile().readAsStringSync();
      // Opens setding:// invitation links (#1015).
      expect(content, contains('Exec="$appImage" %u\n'));
      expect(content, contains('MimeType=x-scheme-handler/setding;\n'));
      expect(DesktopFileMenuEntry.handlesLinks(content), isTrue);
      expect(registered, 1);
      expect(content, contains('Icon=app.setding\n'));
      expect(content, contains('Name=setDING\n'));
      expect(content, endsWith('${DesktopFileMenuEntry.marker}\n'));
      final icons = p.join(data, 'icons', 'hicolor');
      expect(
        File(p.join(icons, '256x256', 'apps', 'app.setding.png'))
            .readAsStringSync(),
        'png',
      );
      expect(
        File(p.join(icons, 'scalable', 'apps', 'app.setding.svg'))
            .readAsStringSync(),
        'svg',
      );
      expect(refreshed, 1);

      await e.remove();
      expect(await e.state(), AppMenuEntryState.missing);
      expect(
        Directory(icons).listSync(recursive: true).whereType<File>(),
        isEmpty,
      );
      expect(refreshed, 2);
    });

    test('an entry of another copy is elsewhere and gets replaced', () async {
      desktopFile()
        ..createSync(recursive: true)
        ..writeAsStringSync('[Desktop Entry]\nExec="/opt/setding/setding"\n');
      final e = entry();
      expect(await e.state(), AppMenuEntryState.elsewhere);
      // Not added by an AppImage: never changed at start.
      expect(await e.repairIfMoved(), isFalse);
      await e.install();
      expect(await e.state(), AppMenuEntryState.installed);
    });

    test('follows a moved AppImage, but not to a second one', () async {
      await entry().install();
      // Still there: a second AppImage leaves the entry alone.
      final other = p.join(root.path, 'other.AppImage');
      File(other).writeAsStringSync('appimage');
      expect(await entry(other).repairIfMoved(), isFalse);
      expect(await entry().state(), AppMenuEntryState.installed);
      // Moved: the entry follows.
      File(appImage).renameSync(p.join(root.path, 'moved.AppImage'));
      final moved = entry(p.join(root.path, 'moved.AppImage'));
      expect(await moved.repairIfMoved(), isTrue);
      expect(await moved.state(), AppMenuEntryState.installed);
      expect(await moved.repairIfMoved(), isFalse);
      // Without an entry nothing is added.
      await moved.remove();
      expect(await moved.repairIfMoved(), isFalse);
      expect(desktopFile().existsSync(), isFalse);
    });

    test('updates an entry that does not open setding:// links', () async {
      // Written before #1015: no MimeType, no %u.
      final old = File('linux/packaging/app.setding.desktop.in')
          .readAsStringSync()
          .replaceAll(RegExp(r'^MimeType=.*\n', multiLine: true), '')
          .replaceAll(
            RegExp(r'^Exec=.*$', multiLine: true),
            'Exec=${DesktopFileMenuEntry.execValue(appImage)}',
          );
      desktopFile()
        ..createSync(recursive: true)
        ..writeAsStringSync('$old${DesktopFileMenuEntry.marker}\n');
      expect(DesktopFileMenuEntry.handlesLinks(old), isFalse);
      expect(await entry().repairIfMoved(), isTrue);
      expect(
        DesktopFileMenuEntry.handlesLinks(desktopFile().readAsStringSync()),
        isTrue,
      );
      expect(registered, 1);
      expect(await entry().repairIfMoved(), isFalse);
    });

    test('the desktop template opens setding:// links', () {
      final template = File('linux/packaging/app.setding.desktop.in')
          .readAsStringSync();
      expect(DesktopFileMenuEntry.handlesLinks(template), isTrue);
      expect(template, contains('Exec="@EXEC@" %u\n'));
      expect(
        DesktopFileMenuEntry.handlesLinks('MimeType=text/plain;\n'),
        isFalse,
      );
    });

    test('quotes and escapes the path of Exec', () {
      for (final path in [
        '/home/a/setding.AppImage',
        '/home/a/My Apps/set "DING" 100%.AppImage',
        r'/home/a/$x`y\z.AppImage',
      ]) {
        final value = DesktopFileMenuEntry.execValue(path);
        expect(
          DesktopFileMenuEntry.execPath('[Desktop Entry]\nExec=$value\n'),
          path,
          reason: value,
        );
      }
      expect(DesktopFileMenuEntry.execValue('/a b/100%'), '"/a b/100%%"');
      expect(
        DesktopFileMenuEntry.execPath('Exec=/usr/bin/setding %U'),
        '/usr/bin/setding',
      );
      expect(DesktopFileMenuEntry.execPath('Name=x'), isNull);
    });
  });

  // The script of the tar.gz and of make dev / make start (ADR-0019).
  group('install-desktop-entry.sh', () {
    late Directory root;
    late String bundle;
    late String data;
    late String log;
    late Map<String, String> env;

    setUp(() {
      root = Directory.systemTemp.createTempSync('setding-script-');
      bundle = p.join(root.path, 'bundle');
      data = p.join(root.path, 'share');
      log = p.join(root.path, 'xdg-mime.log');
      Directory(p.join(bundle, 'data')).createSync(recursive: true);
      for (final name in [
        'app.setding.desktop.in',
        'install-desktop-entry.sh',
      ]) {
        File(p.join('linux', 'packaging', name)).copySync(p.join(bundle, name));
      }
      File(p.join(bundle, 'data', 'app_icon.png')).writeAsStringSync('png');
      File(p.join(bundle, 'data', 'app_icon.svg')).writeAsStringSync('svg');
      // A fake xdg-mime that records its arguments.
      final bin = Directory(p.join(root.path, 'bin'))..createSync();
      final fake = File(p.join(bin.path, 'xdg-mime'))
        ..writeAsStringSync('#!/bin/sh\necho "\$@" >> "$log"\n');
      Process.runSync('chmod', ['+x', fake.path]);
      env = {'XDG_DATA_HOME': data, 'PATH': '${bin.path}:/usr/bin:/bin'};
    });
    tearDown(() => root.deleteSync(recursive: true));

    ProcessResult run(List<String> args) => Process.runSync('sh', [
      p.join(bundle, 'install-desktop-entry.sh'),
      ...args,
    ], environment: env);
    File desktopFile() =>
        File(p.join(data, 'applications', 'app.setding.desktop'));

    test('registers setding:// links and replaces older entries', () {
      // An entry from before #1015 is replaced by --if-missing.
      desktopFile()
        ..createSync(recursive: true)
        ..writeAsStringSync('[Desktop Entry]\nExec="/old/setding"\n');
      expect(run(['--hidden', '--if-missing']).exitCode, 0);
      final content = desktopFile().readAsStringSync();
      expect(content, contains('Exec="$bundle/setding" %u\n'));
      expect(DesktopFileMenuEntry.handlesLinks(content), isTrue);
      expect(content, endsWith('NoDisplay=true\n'));
      expect(
        File(log).readAsStringSync(),
        'default app.setding.desktop x-scheme-handler/setding\n',
      );

      // A current entry is kept.
      desktopFile().writeAsStringSync('$content# kept\n');
      expect(run(['--if-missing']).exitCode, 0);
      expect(desktopFile().readAsStringSync(), endsWith('# kept\n'));
    });
  });

  group('settings', () {
    Future<(_FakeEntry, TestApp)> open(
      WidgetTester tester,
      AppMenuEntryState initial, {
      bool fail = false,
    }) async {
      useTabletSize(tester);
      final fake = _FakeEntry(initial, fail: fail);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.pumpWidget(
        app.build(
          home: const SettingsScreen(),
          extra: [appMenuEntryProvider.overrideWithValue(fake)],
        ),
      );
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.about);
      return (fake, app);
    }

    final tile = find.byKey(const Key('app-menu-entry'));

    testWidgets('adds the AppImage to the menu and removes it', (tester) async {
      final (fake, app) = await open(tester, AppMenuEntryState.missing);
      // In This device, with an icon (ADR-0050).
      expect(
        find.ancestor(
          of: tile,
          matching: find.byWidgetPredicate(
            (w) => w is SettingsSection && w.title == 'This device',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Add to application menu'), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(fake.state_, AppMenuEntryState.installed);
      expect(
        find.text('setDING is now in the application menu'),
        findsOneWidget,
      );
      expect(find.text('In the application menu'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app-menu-entry-remove')));
      await tester.pumpAndSettle();
      expect(fake.state_, AppMenuEntryState.missing);
      expect(find.text('Add to application menu'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('an entry of another copy can be replaced', (tester) async {
      final (fake, app) = await open(tester, AppMenuEntryState.elsewhere);
      expect(find.text('Add to application menu'), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(fake.state_, AppMenuEntryState.installed);
      await app.dispose(tester);
    });

    testWidgets('reports an error', (tester) async {
      final (_, app) = await open(
        tester,
        AppMenuEntryState.missing,
        fail: true,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Application menu not changed'),
        findsOneWidget,
      );
      expect(find.text('Add to application menu'), findsOneWidget);
      await app.dispose(tester);
    });

    testWidgets('hidden where the app is no AppImage', (tester) async {
      useTabletSize(tester);
      final app = await TestApp.create(prefs: {'language': 'en'});
      await tester.pumpWidget(app.build(home: const SettingsScreen()));
      await tester.pumpAndSettle();
      await openSettingsCategory(tester, SettingsCategory.about);
      expect(find.byKey(const Key('settings-docs')), findsOneWidget);
      expect(tile, findsNothing);
      await app.dispose(tester);
    });
  });
}

class _FakeEntry implements AppMenuEntry {
  _FakeEntry(this.state_, {this.fail = false});

  AppMenuEntryState state_;
  final bool fail;

  @override
  Future<AppMenuEntryState> state() async => state_;

  @override
  Future<void> install() async {
    if (fail) throw const FileSystemException('read-only');
    state_ = AppMenuEntryState.installed;
  }

  @override
  Future<void> remove() async => state_ = AppMenuEntryState.missing;

  @override
  Future<bool> repairIfMoved() async => false;
}
