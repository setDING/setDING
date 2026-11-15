import 'dart:io';

import 'package:realchord/app.dart';
import 'package:realchord/data/attachment_storage.dart';
import 'package:realchord/data/database.dart';
import 'package:realchord/data/set_repository.dart';
import 'package:realchord/data/song_repository.dart';
import 'package:realchord/providers.dart';
import 'package:realchord/settings/settings.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App with an in-memory database for widget tests.
class TestApp {
  TestApp._(this.db, this.dir, this.prefs);

  final AppDatabase db;
  final Directory dir;
  final SharedPreferences prefs;

  late final storage = AttachmentStorage(dir);
  late final songs = SongRepository(db, storage);
  late final sets = SetRepository(db, storage);

  static Future<TestApp> create({Map<String, Object> prefs = const {}}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues(prefs);
    return TestApp._(
      AppDatabase(NativeDatabase.memory()),
      Directory.systemTemp.createTempSync('realchord_widget'),
      await SharedPreferences.getInstance(),
    );
  }

  Widget build({Widget? home}) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      attachmentStorageProvider.overrideWithValue(storage),
    ],
    child: RealChordApp(home: home),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Drift cancels stream queries with a zero-duration timer.
    await tester.pump(Duration.zero);
    final closing = db.close();
    await tester.pump(Duration.zero);
    await closing;
    dir.deleteSync(recursive: true);
  }
}

/// Sets a tablet-sized test surface.
void useTabletSize(WidgetTester tester, {bool landscape = true}) {
  tester.view.physicalSize = landscape
      ? const Size(1280, 800)
      : const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
