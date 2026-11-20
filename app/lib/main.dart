import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap/platform_services.dart';
import 'data/database.dart' show localBandId;
import 'data/demo_song.dart';
import 'data/play_history.dart';
import 'data/song_repository.dart';
import 'data/trash.dart';
import 'providers.dart';
import 'settings/settings.dart';
import 'sync/auth_providers.dart';
import 'sync/update_check.dart';
import 'update/whats_new.dart';
import 'ui/widgets/logo.dart';
import 'util/log.dart';

const _log = Log('app');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Logo while the local services start. On Android, iOS and the web it
  // replaces the identical native / HTML splash; on Windows and Linux it is
  // the first thing the window shows.
  final splash = Stopwatch()..start();
  runApp(const SplashScreen());
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
  // Sent with every request, so the server can ask for an update (ADR-0029).
  final info = await PackageInfo.fromPlatform();
  final version = info.version;
  // A new installation has nothing new to tell (ADR-0041); before anything
  // else is stored on the device.
  await recordFirstStart(prefs, version);
  // Files of attachments deleted while an undo was offered (#267); before
  // the UI, so that no new deletion is waiting for its undo.
  try {
    // The local library's trash after 30 days (ADR-0043).
    await TrashRepository(db, storage).purgeLocal();
    await SongRepository(db, storage).purgeDeletedFiles();
  } catch (e) {
    _log.warning('Deleted attachment files not purged', e);
  }
  try {
    // How the local library's songs were played at its gigs (ADR-0046); the
    // sync does this for the bands.
    await PlayHistoryRepository(db).freeze(localBandId);
  } catch (e) {
    _log.warning('Play history of the local library not frozen', e);
  }

  // Add an example song on the very first start. Not on web: the local
  // library it would go to is hidden there (ADR-0018).
  if (!kIsWeb && !(prefs.getBool('demoSeeded') ?? false)) {
    await SongRepository(db, storage).createSong(source: demoSongSource);
    await prefs.setBool('demoSeeded', true);
  }

  // Personal settings (ADR-0027): loaded before the UI, so that language
  // and theme are known from the first frame.
  final userSettings = await UserSettingsStore.open(db, prefs);

  await SplashScreen.waitForMinimum(splash);
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        userSettingsStoreProvider.overrideWithValue(userSettings),
        attachmentStorageProvider.overrideWithValue(storage),
        sessionStoreProvider.overrideWithValue(sessionStore),
        clientVersionProvider.overrideWithValue(version),
        // New releases only for installed release builds (ADR-0036).
        updateCheckEnabledProvider.overrideWithValue(
          !kIsWeb && kReleaseMode && !info.packageName.endsWith('.beta'),
        ),
      ],
      child: const SetdingApp(),
    ),
  );
}
