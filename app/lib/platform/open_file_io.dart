import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens [bytes] as [fileName] in the system's default app for [mimeType].
/// Returns false if no app could open it.
///
/// Opens a copy in the app's cache, not the file the user saved: on Android
/// the save dialog does not tell where it saved the file (ADR-0048).
Future<bool> openFileInDefaultApp(
  String fileName,
  Uint8List bytes, {
  required String mimeType,
}) async {
  try {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'opened'),
    );
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, p.basename(fileName)));
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: mimeType);
    return result.type == ResultType.done;
  } catch (_) {
    return false;
  }
}
