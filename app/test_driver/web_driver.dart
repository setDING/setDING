// Host side of `make web-test` (tool/web-test.sh,
// docs/development/web-tests.md): opens the web client, built from an
// integration test and served like in production, in a headless browser
// through its WebDriver (chromedriver, geckodriver) and waits for the
// test's result.
//
//   dart test_driver/web_driver.dart <webdriver url> <page url>
//
// It speaks the W3C WebDriver protocol directly and asks the page for the
// result like `flutter drive` does (window.$flutterDriver, request_data):
// `flutter drive` serves the app from its own development server, without
// the server's same origin and isolation headers.
//
// A test can span several page loads and tabs (integration_test/web/
// web_support.dart): after a load's test has passed, its report data says
// what to do next ({"next": "reload" | "open" | "replace" | "back",
// "step": ...}), and the driver waits for the next load's result.
//
// BROWSER is chrome (default) or firefox, BROWSER_BINARY selects the
// browser's binary, WEB_TEST_WINDOW=1 shows its window. The browser's
// console (the test's output) is printed while the test runs: Chrome's from
// its log, Firefox's from geckodriver's output in WEBDRIVER_LOG.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Time for each page load's test, including loading the page.
const _timeout = Duration(minutes: 6);

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: web_driver.dart <webdriver url> <page url>');
    exit(64);
  }
  final driver = _WebDriver(Uri.parse(args[0]));
  final page = Uri.parse(args[1]);
  var passed = false;
  try {
    await driver.start();
    await driver.open(page.toString());
    passed = await _run(driver, page);
  } catch (e) {
    stderr.writeln('web-test: $e');
  } finally {
    await driver.printConsole();
    if (!passed) await driver.screenshot('build/web-itest-failure.png');
    await driver.quit();
  }
  exit(passed ? 0 : 1);
}

/// Runs the test's page loads until one asks for nothing more.
Future<bool> _run(_WebDriver driver, Uri page) async {
  final tabs = [await driver.currentTab()];
  while (true) {
    final data = await _result(driver);
    if (data == null) return false;
    final step = data['step'] as String?;
    Uri stepPage() => page.replace(queryParameters: {'step': ?step});
    switch (data['next']) {
      case null:
        return true;
      case 'reload':
        stdout.writeln('web-test: reloading the tab');
        await driver.reload();
      case 'open':
        stdout.writeln('web-test: opening a new tab ($step)');
        tabs.add(await driver.newTab());
        await driver.switchTo(tabs.last);
        await driver.open(stepPage().toString());
      case 'replace':
        stdout.writeln('web-test: closing the tab, opening a new one ($step)');
        // A new tab before closing the last one, so the browser stays open.
        final tab = await driver.newTab();
        await driver.closeTab();
        tabs
          ..removeLast()
          ..add(tab);
        await driver.switchTo(tab);
        await driver.open(stepPage().toString());
      case 'back':
        stdout.writeln('web-test: closing the tab, back to the previous one');
        await driver.closeTab();
        tabs.removeLast();
        await driver.switchTo(tabs.last);
      case final next:
        stderr.writeln('web-test: unknown next action $next');
        return false;
    }
  }
}

/// Waits for the test of the page loaded in the current tab and returns its
/// report data (empty if none), or null when it failed.
Future<Map<String, dynamic>?> _result(_WebDriver driver) async {
  final end = DateTime.now().add(_timeout);
  void checkTime(String what) {
    if (DateTime.now().isAfter(end)) throw TimeoutException(what, _timeout);
  }

  // The integration test binding registers window.$flutterDriver once the
  // app has started; __itestDone marks a page whose result was taken (a tab
  // that reloads by itself still shows it until then).
  while (await driver.execute(
        r'return typeof window.$flutterDriver === "function" && '
        r'!window.__itestDone',
      ) !=
      true) {
    checkTime('the test did not start');
    await driver.printConsole();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  await driver.execute(r'window.$flutterDriver(arguments[0])', [
    jsonEncode({'command': 'request_data'}),
  ]);
  // request_data answers once all tests of the page have finished.
  Object? result;
  while ((result = await driver.execute(r'return $flutterDriverResult')) ==
      null) {
    checkTime('the test did not finish');
    await driver.printConsole();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  await driver.execute('window.__itestDone = true');
  final reply = jsonDecode(result! as String) as Map<String, dynamic>;
  if (reply['isError'] == true) {
    stderr.writeln('web-test: ${reply['response']}');
    return null;
  }
  final message = jsonDecode(
    (reply['response'] as Map<String, dynamic>)['message'] as String,
  ) as Map<String, dynamic>;
  if (message['result'] != 'true') {
    for (final failure in message['failureDetails'] as List) {
      final details = jsonDecode(failure as String) as Map<String, dynamic>;
      stderr.writeln(
        'web-test: FAILED ${details['methodName']}\n${details['details']}',
      );
    }
    return null;
  }
  return (message['data'] as Map<String, dynamic>?) ?? const {};
}

/// A minimal W3C WebDriver client for chromedriver and geckodriver.
class _WebDriver {
  _WebDriver(this._base);

  final Uri _base;
  final _client = http.Client();
  final _firefox = Platform.environment['BROWSER'] == 'firefox';
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
    final binary = Platform.environment['BROWSER_BINARY'];
    final window = Platform.environment['WEB_TEST_WINDOW'] == '1';
    final Map<String, Object?> capabilities;
    if (_firefox) {
      capabilities = {
        'browserName': 'firefox',
        'moz:firefoxOptions': {
          'binary': ?binary,
          'args': [if (!window) '-headless'],
          'prefs': {
            // The page's console on geckodriver's output.
            'devtools.console.stdout.content': true,
          },
        },
      };
    } else {
      capabilities = {
        'browserName': 'chrome',
        'goog:loggingPrefs': {'browser': 'ALL'},
        'goog:chromeOptions': {
          'binary': ?binary,
          'args': [
            if (!window) '--headless=new',
            '--window-size=1600,1024',
            '--no-first-run',
            '--no-default-browser-check',
            '--disable-search-engine-choice-screen',
            // Tabs in the background keep running (several tabs).
            '--disable-background-timer-throttling',
            '--disable-backgrounding-occluded-windows',
            '--disable-renderer-backgrounding',
          ],
        },
      };
    }
    final value = await _send('POST', 'session', {
      'capabilities': {'alwaysMatch': capabilities},
    });
    _session = (value! as Map<String, dynamic>)['sessionId'] as String;
    if (_firefox) {
      // geckodriver runs for all tests: only this test's console.
      final log = Platform.environment['WEBDRIVER_LOG'];
      if (log != null && File(log).existsSync()) {
        _logOffset = File(log).lengthSync();
      }
      await _send('POST', 'session/$_session/window/rect', {
        'width': 1600,
        'height': 1024,
      });
    }
  }

  Future<void> open(String url) =>
      _send('POST', 'session/$_session/url', {'url': url});

  Future<void> reload() => _send('POST', 'session/$_session/refresh', {});

  Future<String> currentTab() async =>
      (await _send('GET', 'session/$_session/window'))! as String;

  Future<String> newTab() async {
    final value = await _send('POST', 'session/$_session/window/new', {
      'type': 'tab',
    });
    return (value! as Map<String, dynamic>)['handle'] as String;
  }

  Future<void> switchTo(String tab) =>
      _send('POST', 'session/$_session/window', {'handle': tab});

  Future<void> closeTab() => _send('DELETE', 'session/$_session/window');

  Future<Object?> execute(String script, [List<Object?> args = const []]) =>
      _send('POST', 'session/$_session/execute/sync', {
        'script': script,
        'args': args,
      });

  /// Offset in Firefox's WEBDRIVER_LOG up to which it was printed.
  var _logOffset = 0;

  /// Prints the browser's console messages since the last call.
  Future<void> printConsole() async {
    if (_session == null) return;
    if (_firefox) return _printFirefoxConsole();
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

  /// Firefox writes the page's console to geckodriver's output as
  /// `console.log: "text"`.
  void _printFirefoxConsole() {
    final path = Platform.environment['WEBDRIVER_LOG'];
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() <= _logOffset) return;
    final raf = file.openSync();
    try {
      raf.setPositionSync(_logOffset);
      final bytes = raf.readSync(file.lengthSync() - _logOffset);
      // Up to the last complete line.
      final end = bytes.lastIndexOf(10) + 1;
      _logOffset += end;
      final text = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
      for (final line in const LineSplitter().convert(text)) {
        final match = RegExp(r'^console\.(?:log|info|warn|error): (.*)$')
            .firstMatch(line);
        if (match == null) continue;
        stdout.writeln('  ${_unquoteFirefox(match.group(1)!)}');
      }
    } finally {
      raf.closeSync();
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

/// Firefox logs `console.log('text')` as `"text"`.
String _unquoteFirefox(String message) {
  try {
    final value = jsonDecode(message);
    if (value is String) return value;
  } catch (_) {}
  return message;
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
