import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/attachment_storage.dart';
import 'data/database.dart';
import 'data/demo_song.dart';
import 'data/song_repository.dart';
import 'providers.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final supportDir = await getApplicationSupportDirectory();
  final db = AppDatabase(driftDatabase(name: 'bandchords'));
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
