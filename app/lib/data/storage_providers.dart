import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attachment_storage.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final attachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);
