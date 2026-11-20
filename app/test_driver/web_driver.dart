// Host side of `make web-test` (tool/web-test.sh,
// docs/development/web-tests.md): opens the web client, built from an
// integration test and served by the local PocketBase, in headless Chrome
// through chromedriver and waits for the test's result.
//
//   dart run test_driver/web_driver.dart <chromedriver url> <page url>
//
// It speaks the W3C WebDriver protocol directly and asks the page for the
// result like `flutter drive` does (window.$flutterDriver, request_data):
// `flutter drive` serves the app from its own development server, without
// the server's same origin and isolation headers. The browser's console
// (the test's output) is printed while the test runs.
//
// CHROME_BINARY selects the browser, WEB_TEST_WINDOW=1 shows its window.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Time for the whole test, including loading the page.
const _timeout = Duration(minutes: 6);

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: web_driver.dart <chromedriver url> <page url>');
    exit(64);
  }
  final driver = _WebDriver(Uri.parse(args[0]));
  var passed = false;
  try {
    await driver.start();
    await driver.open(args[1]);
    passed = await _run(driver);
  } catch (e) {
    stderr.writeln('web-test: $e');
  } finally {
    await driver.printConsole();
    if (!passed) await driver.screenshot('build/web-itest-failure.png');
    await driver.quit();
  }
  exit(passed ? 0 : 1);
}

Future<bool> _run(_WebDriver driver) async {
  final end = DateTime.now().add(_timeout);
  void checkTime(String what) {
    if (DateTime.now().isAfter(end)) throw TimeoutException(what, _timeout);
  }

  // The integration test binding registers window.$flutterDriver once the
  // app has started.
  while (await driver.execute(r'return typeof window.$flutterDriver') !=
      'function') {
    checkTime('the test did not start');
    await driver.printConsole();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  await driver.execute(r'window.$flutterDriver(arguments[0])', [
    jsonEncode({'command': 'request_data'}),
  ]);
  // request_data answers once all tests have finished.
  Object? result;
  while ((result = await driver.execute(r'return $flutterDriverResult')) ==
      null) {
    checkTime('the test did not finish');
    await driver.printConsole();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  final reply = jsonDecode(result! as String) as Map<String, dynamic>;
  if (reply['isError'] == true) {
    stderr.writeln('web-test: ${reply['response']}');
    return false;
  }
  final message = jsonDecode(
    (reply['response'] as Map<String, dynamic>)['message'] as String,
  ) as Map<String, dynamic>;
  if (message['result'] == 'true') {
    stdout.writeln('web-test: all tests passed');
    return true;
  }
  for (final failure in message['failureDetails'] as List) {
    final details = jsonDecode(failure as String) as Map<String, dynamic>;
    stderr.writeln(
      'web-test: FAILED ${details['methodName']}\n${details['details']}',
    );
  }
  return false;
}

/// A minimal W3C WebDriver client for chromedriver.
class _WebDriver {
  _WebDriver(this._base);

  final Uri _base;
  final _client = http.Client();
  String? _session;

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, _base.resolve(path))
      ..headers['content-type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final value = json['value'];
    if (response.statusCode != 200) {
      final error = value is Map
          ? '${value['error']}: ${value['message']}'
          : value;
      throw HttpException('$method $path: $error');
    }
    return value;
  }

  Future<void> start() async {
    final chrome = Platform.environment['CHROME_BINARY'];
    final window = Platform.environment['WEB_TEST_WINDOW'] == '1';
    final value = await _send('POST', 'session', {
      'capabilities': {
        'alwaysMatch': {
          'browserName': 'chrome',
          'goog:loggingPrefs': {'browser': 'ALL'},
          'goog:chromeOptions': {
            'binary': ?chrome,
            'args': [
              if (!window) '--headless=new',
              '--window-size=1600,1024',
              '--no-first-run',
              '--no-default-browser-check',
              '--disable-search-engine-choice-screen',
            ],
          },
        },
      },
    });
    _session = (value! as Map<String, dynamic>)['sessionId'] as String;
  }

  Future<void> open(String url) =>
      _send('POST', 'session/$_session/url', {'url': url});

  Future<Object?> execute(String script, [List<Object?> args = const []]) =>
      _send('POST', 'session/$_session/execute/sync', {
        'script': script,
        'args': args,
      });

  /// Prints the browser's console messages since the last call.
  Future<void> printConsole() async {
    if (_session == null) return;
    try {
      final entries = await _send('POST', 'session/$_session/se/log', {
        'type': 'browser',
      });
      for (final entry in entries! as List) {
        final message = (entry as Map<String, dynamic>)['message'] as String;
        stdout.writeln('  ${_unquote(message)}');
      }
    } catch (_) {
      // The log is a convenience; the result decides.
    }
  }

  /// Saves what the browser shows, for a failed test.
  Future<void> screenshot(String path) async {
    if (_session == null) return;
    try {
      final png = await _send('GET', 'session/$_session/screenshot');
      File(path).writeAsBytesSync(base64Decode(png! as String));
      stderr.writeln('web-test: screenshot of the failure in app/$path');
    } catch (_) {}
  }

  Future<void> quit() async {
    if (_session != null) {
      try {
        await _send('DELETE', 'session/$_session');
      } catch (_) {}
    }
    _client.close();
  }
}

/// Chrome logs `console.log('text')` as `<source> <line>:<col> "text"`.
String _unquote(String message) {
  final match = RegExp(
    r'^\S+ \d+:\d+ (".*")$',
    dotAll: true,
  ).firstMatch(message);
  if (match == null) return message;
  try {
    return jsonDecode(match.group(1)!) as String;
  } catch (_) {
    return message;
  }
}
