import 'dart:io';

import 'package:path/path.dart' as p;

import '../update/app_menu_entry.dart';
import '../util/log.dart';
import 'self_update_io.dart' show runningAppImage;

const _log = Log('menu-entry');

/// The application menu entry of the running AppImage, or null when this
/// app is not an AppImage (the tar.gz has `install-desktop-entry.sh`).
AppMenuEntry? createAppMenuEntry() {
  final appImage = runningAppImage();
  if (appImage == null) return null;
  return DesktopFileMenuEntry(
    appImage: appImage,
    bundleDir: p.dirname(Platform.resolvedExecutable),
  );
}

/// The desktop entry `app.setding.desktop` and the icon in the user's data
/// folder (`$XDG_DATA_HOME`, else `~/.local/share`), like
/// `install-desktop-entry.sh` of the tar.gz (ADR-0019), but starting the
/// AppImage file [appImage]. Under Wayland the window only shows the setDING
/// icon with this entry: the compositor looks it up by the app ID. The entry
/// also opens `setding://` invitation links (ADR-0005, #1015).
class DesktopFileMenuEntry implements AppMenuEntry {
  DesktopFileMenuEntry({
    required this.appImage,
    required this.bundleDir,
    String? dataHome,
    Future<void> Function(String applications)? refresh,
    Future<void> Function()? registerLinks,
  }) : dataHome = dataHome ?? _defaultDataHome(),
       _refresh = refresh ?? _refreshDesktop,
       _registerLinks = registerLinks ?? _registerLinkHandler;

  static const id = 'app.setding';

  /// Marks an entry written by an AppImage, so that only those follow the
  /// AppImage when it moves ([repairIfMoved]).
  static const marker = 'X-setDING-AppImage=true';

  /// The MIME type of `setding://` links, which the entry handles.
  static const linkScheme = 'x-scheme-handler/setding';

  /// The AppImage file the entry starts.
  final String appImage;

  /// The unpacked bundle inside the AppImage, with the template of the
  /// entry and `data/app_icon.png` / `.svg`.
  final String bundleDir;

  /// The user's data folder (`~/.local/share`).
  final String dataHome;

  final Future<void> Function(String applications) _refresh;
  final Future<void> Function() _registerLinks;

  String get _applications => p.join(dataHome, 'applications');
  File get _entry => File(p.join(_applications, '$id.desktop'));
  String get _icons => p.join(dataHome, 'icons', 'hicolor');
  File get _png => File(p.join(_icons, '256x256', 'apps', '$id.png'));
  File get _svg => File(p.join(_icons, 'scalable', 'apps', '$id.svg'));

  @override
  Future<AppMenuEntryState> state() async {
    if (!await _entry.exists()) return AppMenuEntryState.missing;
    final exec = execPath(await _entry.readAsString());
    return exec == appImage
        ? AppMenuEntryState.installed
        : AppMenuEntryState.elsewhere;
  }

  @override
  Future<void> install() async {
    final template = await File(p.join(bundleDir, '$id.desktop.in'))
        .readAsString();
    final content = template.replaceAll(
      RegExp(r'^Exec=.*$', multiLine: true),
      'Exec=${execValue(appImage)} %u',
    );
    await _png.parent.create(recursive: true);
    await _svg.parent.create(recursive: true);
    await File(p.join(bundleDir, 'data', 'app_icon.png')).copy(_png.path);
    await File(p.join(bundleDir, 'data', 'app_icon.svg')).copy(_svg.path);
    await _entry.parent.create(recursive: true);
    // Written next to it and renamed, so the menu never reads half a file.
    final tmp = File('${_entry.path}.tmp');
    await tmp.writeAsString(
      '${content.endsWith('\n') ? content : '$content\n'}$marker\n',
    );
    await tmp.rename(_entry.path);
    _log.info('Desktop entry installed for $appImage');
    await _refresh(_applications);
    await _registerLinks();
  }

  @override
  Future<void> remove() async {
    for (final file in [_entry, _png, _svg]) {
      if (await file.exists()) await file.delete();
    }
    _log.info('Desktop entry removed');
    await _refresh(_applications);
  }

  @override
  Future<bool> repairIfMoved() async {
    if (!await _entry.exists()) return false;
    final content = await _entry.readAsString();
    if (!content.split('\n').contains(marker)) return false;
    final exec = execPath(content);
    if (exec == appImage) {
      // Entries from before #1015 do not open setding:// links yet.
      if (handlesLinks(content)) return false;
      await install();
      return true;
    }
    // Another AppImage that is still there keeps its entry.
    if (exec != null && await File(exec).exists()) return false;
    await install();
    return true;
  }

  /// Whether [desktopFile] opens `setding://` links.
  static bool handlesLinks(String desktopFile) => desktopFile
      .split('\n')
      .any(
        (l) =>
            l.startsWith('MimeType=') &&
            l.substring('MimeType='.length).split(';').contains(linkScheme),
      );

  /// The value of `Exec=` that starts [path]: quoted and escaped as the
  /// Desktop Entry Specification asks (quoting, then `%` and the string
  /// escape of `\`).
  static String execValue(String path) {
    final quoted = path.replaceAllMapped(
      RegExp(r'["`$\\]'),
      (m) => '\\${m[0]}',
    );
    return '"$quoted"'.replaceAll(r'\', r'\\').replaceAll('%', '%%');
  }

  /// The program the `Exec=` line of [desktopFile] starts, or null.
  static String? execPath(String desktopFile) {
    final line = desktopFile
        .split('\n')
        .firstWhere((l) => l.startsWith('Exec='), orElse: () => '');
    if (line.isEmpty) return null;
    final value = line
        .substring('Exec='.length)
        .replaceAll(r'\\', '\u0000')
        .replaceAll('%%', '%')
        .replaceAll('\u0000', r'\');
    if (!value.startsWith('"')) {
      final end = value.indexOf(' ');
      return end < 0 ? value : value.substring(0, end);
    }
    final out = StringBuffer();
    for (var i = 1; i < value.length; i++) {
      final c = value[i];
      if (c == r'\' && i + 1 < value.length) {
        out.write(value[++i]);
      } else if (c == '"') {
        return out.toString();
      } else {
        out.write(c);
      }
    }
    return null;
  }

  static String _defaultDataHome() {
    final env = Platform.environment;
    final xdg = env['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) return xdg;
    return p.join(env['HOME'] ?? '', '.local', 'share');
  }

  /// Makes the entry the handler of `setding://` links (optional tool).
  static Future<void> _registerLinkHandler() async {
    try {
      await Process.run('xdg-mime', ['default', '$id.desktop', linkScheme]);
    } on ProcessException {
      // Not installed; update-desktop-database still lists the entry.
    }
  }

  /// Lets the desktop pick up the change; each tool is optional.
  static Future<void> _refreshDesktop(String applications) async {
    for (final command in [
      ['update-desktop-database', '-q', applications],
      ['kbuildsycoca6'],
      ['kbuildsycoca5'],
    ]) {
      try {
        final result = await Process.run(command.first, command.sublist(1));
        // One KDE tool is enough.
        if (command.first.startsWith('kbuildsycoca') && result.exitCode == 0) {
          break;
        }
      } on ProcessException {
        // Not installed.
      }
    }
  }
}
