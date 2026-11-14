import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/attachment_storage.dart';
import 'data/data_location.dart';
import 'data/database.dart';
import 'data/demo_song.dart';
import 'data/song_repository.dart';
import 'providers.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Font embedded in PDF set lists (ADR-0013).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans',
    ], await rootBundle.loadString('assets/fonts/NotoSans-OFL.txt'));
  });

  final prefs = await SharedPreferences.getInstance();
  // All data lives in the app's private directory (ADR-0001). On desktop
  // the documents directory is the user's visible "Documents" folder.
  // BANDCHORDS_DATA_DIR (development only, see Makefile) runs an isolated
  // test instance and never touches existing data.
  final override = Platform.environment['BANDCHORDS_DATA_DIR'];
  final supportDir = override != null && override.isNotEmpty
      ? Directory(override)
      : await getApplicationSupportDirectory();
  final dbFile = await resolveDatabaseFile(
    supportDir,
    legacyDir: override == null ? await _legacyDocumentsDir() : null,
  );
  final db = AppDatabase(
    driftDatabase(
      name: 'bandchords',
      native: DriftNativeOptions(databasePath: () async => dbFile.path),
    ),
  );
  // After a schema upgrade, fill new columns from the ChordPro sources.
  db.afterUpgrade = (db) => SongRepository(
    db,
    AttachmentStorage(Directory(supportDir.path)),
  ).refreshAllMetadata();
  final storage = AttachmentStorage(
    Directory(p.join(supportDir.path, 'attachments')),
  );

  // Add an example song on the very first start.
  if (!(prefs.getBool('demoSeeded') ?? false)) {
    await SongRepository(db, storage).createSong(source: demoSongSource);
    await prefs.setBool('demoSeeded', true);
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        attachmentStorageProvider.overrideWithValue(storage),
      ],
      child: const BandChordsApp(),
    ),
  );
}

/// Where earlier versions stored the database, or null if unavailable.
Future<Directory?> _legacyDocumentsDir() async {
  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {
    return null;
  }
}
