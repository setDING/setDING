import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../update/app_update.dart';

/// Whether this app was installed with the Windows setup (ADR-0035): Inno
/// Setup puts its uninstaller next to the executable. The portable zip has
/// none, so it is never updated in place (a setup would install a second
/// copy elsewhere).
bool isInstalledWithSetup({String? executable, bool? windows}) {
  if (!(windows ?? Platform.isWindows)) return false;
  final dir = p.dirname(executable ?? Platform.resolvedExecutable);
  return File(p.join(dir, 'unins000.exe')).existsSync();
}

/// Downloads the setup of [update] into a new temporary folder and returns
/// its path. Throws [UpdateException] (and deletes the download) if the file
/// does not match the release's checksum.
Future<String> downloadVerifiedUpdate(
  http.Client client,
  AvailableUpdate update, {
  void Function(double progress)? onProgress,
  Directory? into,
}) async {
  final dir = into ?? await Directory.systemTemp.createTemp('setding-update-');
  final file = File(p.join(dir.path, update.setupName));
  try {
    final response = await client.send(http.Request('GET', update.setupUrl));
    if (response.statusCode != 200) {
      throw UpdateException('setup: HTTP ${response.statusCode}');
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

/// Starts the setup without questions ([installerArguments]) and ends the
/// app, so that the setup can replace its files. The setup starts the new
/// version afterwards.
Future<void> runInstallerAndExit(String setupPath) async {
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
