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
    });
    tearDown(() => root.deleteSync(recursive: true));

    DesktopFileMenuEntry entry([String? image]) => DesktopFileMenuEntry(
      appImage: image ?? appImage,
      bundleDir: bundle,
      dataHome: data,
      refresh: (_) async => refreshed++,
    );
    File desktopFile() =>
        File(p.join(data, 'applications', 'app.setding.desktop'));

    test('installs the entry and the icon, and removes them', () async {
      final e = entry();
      expect(await e.state(), AppMenuEntryState.missing);
      await e.install();
      expect(await e.state(), AppMenuEntryState.installed);
      final content = desktopFile().readAsStringSync();
      expect(content, contains('Exec="$appImage"\n'));
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
