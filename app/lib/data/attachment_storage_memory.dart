import 'dart:async';
import 'dart:typed_data';

import 'attachment_storage.dart';

/// Attachment files kept in memory.
///
/// Used by the web client, which has no file system and does not preload
/// attachments (ADR-0018); files added in the browser stay until they are
/// uploaded and the tab is closed.
class MemoryAttachmentStorage implements AttachmentStorage {
  final _files = <String, Uint8List>{};

  @override
  StoredFile file(String fileName) => _MemoryFile(this, fileName);

  @override
  Future<void> write(String fileName, Uint8List bytes) async =>
      _files[fileName] = Uint8List.fromList(bytes);

  @override
  Future<void> writeWith(
    String fileName,
    Future<void> Function(StreamSink<List<int>> sink) fill,
  ) async {
    final builder = BytesBuilder(copy: false);
    final controller = StreamController<List<int>>();
    final collected = controller.stream.forEach(builder.add);
    try {
      await fill(controller.sink);
    } finally {
      await controller.close();
      await collected;
    }
    _files[fileName] = builder.takeBytes();
  }

  @override
  Future<void> copy(String from, String to) async {
    final bytes = _files[from];
    if (bytes != null) _files[to] = bytes;
  }

  @override
  Future<bool> exists(String fileName) async => _files.containsKey(fileName);

  @override
  Future<void> delete(String fileName) async => _files.remove(fileName);

  @override
  Future<int> usedBytes() async =>
      _files.values.fold<int>(0, (sum, bytes) => sum + bytes.length);
}

class _MemoryFile implements StoredFile {
  _MemoryFile(this._storage, this.name);

  final MemoryAttachmentStorage _storage;

  @override
  final String name;

  @override
  String get id => 'memory:${identityHashCode(_storage)}/$name';

  Uint8List? get _bytes => _storage._files[name];

  @override
  bool existsSync() => _bytes != null;

  @override
  Future<bool> exists() async => existsSync();

  @override
  Future<Uint8List> readAsBytes() async {
    final bytes = _bytes;
    if (bytes == null) throw StateError('Attachment $name does not exist');
    return bytes;
  }

  @override
  Uint8List? readStartSync(int maxBytes) {
    final bytes = _bytes;
    if (bytes == null) return null;
    return bytes.length <= maxBytes
        ? bytes
        : Uint8List.sublistView(bytes, 0, maxBytes);
  }
}
