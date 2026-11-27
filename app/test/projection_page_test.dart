import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setding/l10n/generated/app_localizations.dart';
import 'package:setding/projection/projection_page.dart';
import 'package:setding/projection/projection_server_io.dart';
import 'package:setding/projection/projection_state.dart';

/// The projected page of the lyrics projection (ADR-0068 §3, §5, §8–10,
/// #1168).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String template;
  setUpAll(() async {
    template = await rootBundle.loadString(projectionPageAsset);
  });

  test('the page is a bundled asset', () {
    expect(template, startsWith('<!doctype html>'));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- $projectionPageAsset'),
    );
  });

  test('placeholders are filled in and escaped', () {
    final page = projectionPage(
      template,
      lang: 'de',
      fullScreen: 'Voll"<bild>',
    );
    expect(page, contains('<html lang="de">'));
    expect(page, contains('aria-label="Voll&quot;&lt;bild&gt;"'));
    expect(page, isNot(contains('{{')));
  });

  test('every language has the full screen label', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.projectionFullScreen, isNotEmpty, reason: '$locale');
    }
  });

  test('self-contained: no external scripts, styles, fonts or images', () {
    expect(template, isNot(matches(RegExp(r'https?://'))));
    expect(
      template,
      isNot(matches(RegExp(r'''(src|href)\s*=''', caseSensitive: false))),
    );
    expect(template, isNot(contains('@import')));
    expect(template, isNot(contains('url(')));
    expect(template, isNot(contains('innerHTML')));
  });

  test('follows the stream next to the page and knows the lower third', () {
    expect(template, contains("new EventSource(base + '/events')"));
    expect(template, contains('lower-third'));
    expect(template, contains("addEventListener('state'"));
  });

  test('the server serves the filled page with its stream', () async {
    final server = ProjectionServer(
      page: projectionPage(template, lang: 'en', fullScreen: 'Full screen'),
    );
    await server.start(port: 0);
    addTearDown(server.stop);
    // The test binding mocks HttpClient (every request 400); a real one.
    final http = HttpOverrides.runWithHttpOverrides(HttpClient.new, _Real());
    addTearDown(() => http.close(force: true));
    for (final path in ['', '/lower-third']) {
      final response = await (await http.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/p/${server.token}$path'),
      )).close();
      expect(response.statusCode, 200);
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('<html lang="en">'));
      expect(body, contains('title="Full screen"'));
    }
  });

  test('the state carries the style of the page', () {
    const style = ProjectionStyle(
      theme: ProjectionTheme.light,
      font: ProjectionFont.serif,
      align: ProjectionAlign.left,
    );
    expect(const ProjectionState.blank(style: style).toJson()['style'], {
      'theme': 'light',
      'font': 'serif',
      'align': 'left',
    });
    expect(const ProjectionState.marker('Prayer').toJson()['style'], {
      'theme': 'dark',
      'font': 'sans',
      'align': 'center',
    });
  });
}

class _Real extends HttpOverrides {}
