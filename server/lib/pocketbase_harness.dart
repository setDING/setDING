import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// A throw-away PocketBase instance with the repository's migrations and
/// hooks, started for one test file.
///
/// The binary is taken from `POCKETBASE_BIN`, otherwise the pinned version
/// (`PB_VERSION` in the Makefile) is downloaded with
/// `tool/server/fetch-pocketbase.sh`.
class PocketBase {
  PocketBase._(this._process, this._dir, this.baseUrl, this.superuserToken);

  final Process _process;
  final Directory _dir;
  final Uri baseUrl;

  /// Token of a superuser; superusers bypass all access rules.
  final String superuserToken;

  static const _superuserEmail = 'root@realchord.test';
  static const _superuserPassword = 'superuser-password';

  /// [environment] is added to the server's environment (e.g. deep-link
  /// settings read by the hooks). [publicDir] holds static files (e.g. the
  /// web client, ADR-0018).
  static Future<PocketBase> start({
    Map<String, String>? environment,
    String? publicDir,
  }) async {
    final root = _repositoryRoot();
    final binary = await _binary(root);
    final dir = await Directory.systemTemp.createTemp('realchord-pb-');
    final data = '${dir.path}/pb_data';

    final upsert = await Process.run(binary, [
      'superuser',
      'upsert',
      _superuserEmail,
      _superuserPassword,
      '--dir',
      data,
      '--migrationsDir',
      '$root/server/pb_migrations',
    ]);
    if (upsert.exitCode != 0) {
      throw StateError('superuser upsert failed: ${upsert.stderr}');
    }

    final port = await _freePort();
    final process = await Process.start(environment: environment, binary, [
      'serve',
      '--dev=false',
      '--hooksWatch=false',
      '--dir',
      data,
      '--hooksDir',
      '$root/server/pb_hooks',
      '--migrationsDir',
      '$root/server/pb_migrations',
      '--http',
      '127.0.0.1:$port',
      if (publicDir != null) ...['--publicDir', publicDir],
    ]);
    final log = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(log.write);
    process.stderr.transform(utf8.decoder).listen(log.write);

    final baseUrl = Uri.parse('http://127.0.0.1:$port');
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (true) {
      try {
        final r = await http.get(baseUrl.resolve('/api/health'));
        if (r.statusCode == 200) break;
      } on SocketException {
        // not up yet
      }
      if (DateTime.now().isAfter(deadline)) {
        process.kill();
        throw StateError('PocketBase did not start:\n$log');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final auth = await http.post(
      baseUrl.resolve('/api/collections/_superusers/auth-with-password'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'identity': _superuserEmail,
        'password': _superuserPassword,
      }),
    );
    final token = (jsonDecode(auth.body) as Map<String, dynamic>)['token'];
    return PocketBase._(process, dir, baseUrl, token as String);
  }

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
    await _dir.delete(recursive: true);
  }

  /// A client acting as a superuser.
  Client get superuser => Client(this, superuserToken);

  /// A client without authentication.
  Client get guest => Client(this, null);

  int _users = 0;

  /// Signs up a new user and returns a client signed in as that user.
  Future<User> signUp([String? name]) async {
    final n = ++_users;
    final email =
        'user$n-${DateTime.now().microsecondsSinceEpoch}@realchord.test';
    const password = 'password-123';
    final created = await guest.post('users', {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'name': name ?? 'User $n',
    });
    created.expectStatus(200);
    final auth = await guest.send(
      'POST',
      '/api/collections/users/auth-with-password',
      body: {'identity': email, 'password': password},
    );
    auth.expectStatus(200);
    return User(
      this,
      created.json['id'] as String,
      auth.json['token'] as String,
    );
  }

  static String _repositoryRoot() {
    var dir = Directory.current.absolute;
    while (!File('${dir.path}/Makefile').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError('repository root (Makefile) not found');
      }
      dir = parent;
    }
    return dir.path;
  }

  static Future<String> _binary(String root) async {
    final fromEnv = Platform.environment['POCKETBASE_BIN'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    final makefile = File('$root/Makefile').readAsStringSync();
    final version = RegExp(
      r'^PB_VERSION\s*\?=\s*(\S+)',
      multiLine: true,
    ).firstMatch(makefile)!.group(1)!;
    final fetch = await Process.run('$root/tool/server/fetch-pocketbase.sh', [
      version,
    ]);
    if (fetch.exitCode != 0) {
      throw StateError('fetching PocketBase failed: ${fetch.stderr}');
    }
    return (fetch.stdout as String).trim();
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

/// A signed-in user.
class User extends Client {
  User(super.pb, this.id, String super.token);

  final String id;
}

/// Thin REST client for the PocketBase records API.
class Client {
  Client(this.pb, [String? token]) : _token = token;

  final PocketBase pb;
  final String? _token;

  Future<Response> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final request = http.Request(method, pb.baseUrl.resolve(path));
    if (headers != null) request.headers.addAll(headers);
    if (_token != null) request.headers['authorization'] = _token;
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return Response(await http.Response.fromStream(await request.send()));
  }

  Future<Response> post(String collection, Map<String, dynamic> body) =>
      send('POST', '/api/collections/$collection/records', body: body);

  Future<Response> patch(
    String collection,
    String id,
    Map<String, dynamic> body,
  ) => send('PATCH', '/api/collections/$collection/records/$id', body: body);

  Future<Response> view(String collection, String id) =>
      send('GET', '/api/collections/$collection/records/$id');

  Future<Response> delete(String collection, String id) =>
      send('DELETE', '/api/collections/$collection/records/$id');

  /// Lists all records visible to this client, optionally filtered; synced
  /// collections are sorted by revision.
  Future<List<Map<String, dynamic>>> list(
    String collection, {
    String? filter,
  }) async {
    final query = {
      'perPage': '500',
      if (collection != 'users' && collection != 'invites') 'sort': 'revision',
      'filter': ?filter,
    };
    final uri = Uri(
      path: '/api/collections/$collection/records',
      queryParameters: query,
    );
    final r = await send('GET', uri.toString());
    r.expectStatus(200);
    return (r.json['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Creates a record with a multipart request (file uploads).
  Future<Response> postMultipart(
    String collection,
    Map<String, String> fields, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) => _multipart(
    'POST',
    '/api/collections/$collection/records',
    fields,
    fileField,
    bytes,
    filename,
    contentType,
  );

  Future<Response> patchMultipart(
    String collection,
    String id,
    Map<String, String> fields, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) => _multipart(
    'PATCH',
    '/api/collections/$collection/records/$id',
    fields,
    fileField,
    bytes,
    filename,
    contentType,
  );

  Future<Response> _multipart(
    String method,
    String path,
    Map<String, String> fields,
    String fileField,
    List<int> bytes,
    String filename,
    String contentType,
  ) async {
    final request = http.MultipartRequest(method, pb.baseUrl.resolve(path));
    if (_token != null) request.headers['authorization'] = _token;
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );
    return Response(await http.Response.fromStream(await request.send()));
  }
}

class Response {
  Response(this.raw);

  final http.Response raw;

  int get status => raw.statusCode;

  Map<String, dynamic> get json =>
      raw.body.isEmpty ? {} : jsonDecode(raw.body) as Map<String, dynamic>;

  /// A nested value of the JSON body, e.g. `field('data.email.code')`;
  /// null if a part of the path is missing.
  Object? field(String path) {
    Object? value = json;
    for (final key in path.split('.')) {
      value = value is Map ? value[key] : null;
    }
    return value;
  }

  /// Throws with the response body if the status does not match.
  void expectStatus(int expected) {
    if (status != expected) {
      throw StateError('expected HTTP $expected, got $status: ${raw.body}');
    }
  }

  @override
  String toString() => 'HTTP $status ${raw.body}';
}
