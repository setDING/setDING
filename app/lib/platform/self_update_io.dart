import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../update/app_update.dart';

/// How this app updates itself, or null if it does not.
SelfUpdateKind? detectSelfUpdateKind() {
  if (isInstalledWithSetup()) return SelfUpdateKind.windowsSetup;
  if (runningAppImage() != null) return SelfUpdateKind.appImage;
  return null;
}

/// Whether this app was installed with the Windows setup (ADR-0035): Inno
/// Setup puts its uninstaller next to the executable. The portable zip has
/// none, so it is never updated in place (a setup would install a second
/// copy elsewhere).
bool isInstalledWithSetup({String? executable, bool? windows}) {
  if (!(windows ?? Platform.isWindows)) return false;
  final dir = p.dirname(executable ?? Platform.resolvedExecutable);
  return File(p.join(dir, 'unins000.exe')).existsSync();
}

/// The AppImage file this app runs from (ADR-0038), or null: the AppImage
/// runtime sets `APPIMAGE` to it. The unpacked tar.gz has none and never
/// updates itself.
String? runningAppImage({Map<String, String>? environment, bool? linux}) {
  if (!(linux ?? Platform.isLinux)) return null;
  final path = (environment ?? Platform.environment)['APPIMAGE'];
  if (path == null || path.isEmpty || !File(path).existsSync()) return null;
  return path;
}

/// Downloads the file of [update] and returns its path: into a new temporary
/// folder, or to [to] if given. Throws [UpdateException] (and deletes the
/// download) if the file does not match the release's checksum.
Future<String> downloadVerifiedUpdate(
  http.Client client,
  AvailableUpdate update, {
  void Function(double progress)? onProgress,
  Directory? into,
  String? to,
}) async {
  final file = File(
    to ??
        p.join(
          (into ?? await Directory.systemTemp.createTemp('setding-update-'))
              .path,
          update.setupName,
        ),
  );
  try {
    final response = await client.send(http.Request('GET', update.setupUrl));
    if (response.statusCode != 200) {
      throw UpdateException('${update.setupName}: HTTP ${response.statusCode}');
    }
    final total = response.contentLength;
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    final out = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        out.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) onProgress?.call(received / total);
      }
    } finally {
      await out.close();
    }
    hasher.close();
    if (digest.value.toString() != update.sha256) {
      throw UpdateException('checksum mismatch for ${update.setupName}');
    }
    return file.path;
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
}

/// Downloads and installs [update] of [kind], then ends the app; the new
/// version starts by itself. Throws (and leaves the installed app as it was)
/// if the download or its check fails.
Future<void> installUpdateAndExit(
  http.Client client,
  AvailableUpdate update,
  SelfUpdateKind kind, {
  void Function(double progress)? onProgress,
}) async {
  switch (kind) {
    case SelfUpdateKind.windowsSetup:
      final setup = await downloadVerifiedUpdate(
        client,
        update,
        onProgress: onProgress,
      );
      await _runInstallerAndExit(setup);
    case SelfUpdateKind.appImage:
      final target = runningAppImage();
      if (target == null) throw const UpdateException('not an AppImage');
      final path = await downloadVerifiedUpdate(
        client,
        update,
        onProgress: onProgress,
        to: '$target.update',
      );
      await replaceAppImage(path, target);
      // Started a moment after this app ended, so the two never share the
      // database (the Linux app is not single-instance).
      await Process.start('/bin/sh', [
        '-c',
        r'sleep 2; exec "$0"',
        target,
      ], mode: ProcessStartMode.detached);
      exit(0);
  }
}

/// Puts the verified AppImage [downloaded] in place of [target] (ADR-0038):
/// executable like the old one, then renamed over it in one step, so a
/// failure never leaves a broken AppImage. The running app keeps its old,
/// mounted file until it ends.
Future<void> replaceAppImage(String downloaded, String target) async {
  // Executable for everyone who may read it, like a fresh AppImage.
  final mode = (await File(target).stat()).mode & 0x1ff; // 0777
  final executable = mode | ((mode & 0x124) >> 2); // read 0444 → exec 0111
  final result = await Process.run('chmod', [
    executable.toRadixString(8),
    downloaded,
  ]);
  if (result.exitCode != 0) {
    await File(downloaded).delete();
    throw UpdateException('chmod: ${result.stderr}');
  }
  await File(downloaded).rename(target);
}

/// Starts the setup without questions ([installerArguments]) and ends the
/// app, so that the setup can replace its files. The setup starts the new
/// version afterwards.
Future<void> _runInstallerAndExit(String setupPath) async {
  await Process.start(
    setupPath,
    installerArguments,
    mode: ProcessStartMode.detached,
  );
  exit(0);
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
