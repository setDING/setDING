import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap/platform_services.dart';
import 'data/demo_song.dart';
import 'data/song_repository.dart';
import 'providers.dart';
import 'settings/settings.dart';
import 'sync/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Font embedded in PDF set lists (ADR-0013).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans',
    ], await rootBundle.loadString('assets/fonts/NotoSans-OFL.txt'));
  });

  final (:db, :storage, :sessionStore) = await openPlatformServices();
  final prefs = await SharedPreferences.getInstance();
  // After a schema upgrade, fill new columns from the ChordPro sources.
  db.afterUpgrade = (db) => SongRepository(db, storage).refreshAllMetadata();
  await sessionStore.load();

  // Add an example song on the very first start. Not on web: the local
  // library it would go to is hidden there (ADR-0018).
  if (!kIsWeb && !(prefs.getBool('demoSeeded') ?? false)) {
    await SongRepository(db, storage).createSong(source: demoSongSource);
    await prefs.setBool('demoSeeded', true);
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        attachmentStorageProvider.overrideWithValue(storage),
        sessionStoreProvider.overrideWithValue(sessionStore),
      ],
      child: const RealChordApp(),
    ),
  );
}
