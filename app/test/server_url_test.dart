import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/settings/settings.dart';
import 'package:setding/sync/auth_providers.dart';
import 'package:setding/sync/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which server the app talks to when none is chosen (ADR-0069, #1178).
void main() {
  Future<String> serverUrl({String? chosen, String? session}) async {
    SharedPreferences.setMockInitialValues({'serverUrl': ?chosen});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(MemorySessionStore(session)),
      ],
    );
    addTearDown(container.dispose);
    return container.read(serverUrlProvider);
  }

  String sessionOn(String server) =>
      jsonEncode({'server': server, 'auth': '{"token":"t"}'});

  test('without a session the build default is used', () async {
    expect(await serverUrl(), initialServerUrl());
  });

  test('a stored session keeps its server', () async {
    // An installation signed in to production that updates to a pre-release
    // (default: staging) stays on production and signed in.
    expect(
      await serverUrl(session: sessionOn('https://api.setding.app')),
      'https://api.setding.app',
    );
    expect(
      await serverUrl(session: sessionOn('https://api.setding.dev')),
      'https://api.setding.dev',
    );
  });

  test('a chosen server wins over the session', () async {
    expect(
      await serverUrl(
        chosen: 'https://chords.example.org',
        session: sessionOn('https://api.setding.app'),
      ),
      'https://chords.example.org',
    );
  });

  test('the server of a stored session', () {
    expect(sessionServer(null), isNull);
    expect(sessionServer(''), isNull);
    expect(sessionServer('not json'), isNull);
    expect(sessionServer('[1]'), isNull);
    expect(sessionServer('{"server":""}'), isNull);
    expect(sessionServer(sessionOn('https://x.test')), 'https://x.test');
  });
}
