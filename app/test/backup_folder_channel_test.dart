import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/platform/backup_folder.dart';

/// The backup folder through the native channel on Android and iOS
/// (ADR-0054).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.setding/backup_folder.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<Object?, Object?>> writes;

  /// Answers every "write" with [error] while it has a "part" ([partError])
  /// or not ([directError]).
  void answer({String? partError, String? directError}) {
    writes = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      writes.add(args);
      final error = args.containsKey('part') ? partError : directError;
      if (error != null) throw PlatformException(code: error);
      return null;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final bytes = Uint8List.fromList([1, 2, 3]);
  const name = 'Backup Pixel 2026-11-26 2217.setDING.zip';

  test('writes under the temporary name first', () async {
    answer();
    await ChannelBackupFolder(channel).write('tree', name, bytes);
    expect(writes, hasLength(1));
    expect(writes.single['part'], '$name$backupPartSuffix');
    expect(writes.single['name'], name);
  });

  test('a folder that rejects the temporary name gets the file directly '
      '(#1106)', () async {
    // A Nextcloud server forbids ".part" files: the provider cannot create
    // the document, the channel reports it as unavailable.
    answer(partError: 'unavailable');
    await ChannelBackupFolder(channel).write('tree', name, bytes);
    expect(writes, hasLength(2));
    expect(writes.last.containsKey('part'), isFalse);
    expect(writes.last['name'], name);
    expect(writes.last['bytes'], bytes);
  });

  test('an unreachable folder still fails', () async {
    answer(partError: 'unavailable', directError: 'unavailable');
    await expectLater(
      ChannelBackupFolder(channel).write('tree', name, bytes),
      throwsA(
        isA<BackupFolderException>().having(
          (e) => e.error,
          'error',
          BackupFolderError.unavailable,
        ),
      ),
    );
  });

  test('a lost permission is not retried', () async {
    answer(partError: 'permission');
    await expectLater(
      ChannelBackupFolder(channel).write('tree', name, bytes),
      throwsA(
        isA<BackupFolderException>().having(
          (e) => e.error,
          'error',
          BackupFolderError.permission,
        ),
      ),
    );
    expect(writes, hasLength(1));
  });
}
