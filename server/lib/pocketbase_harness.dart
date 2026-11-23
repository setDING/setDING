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
  PocketBase._(
    this._process,
    this._dir,
    this._binaryPath,
    this._root,
    this._environment,
    this.baseUrl,
    this.superuserToken,
  );

  final Process _process;
  final Directory _dir;
  final String _binaryPath;
  final String _root;
  final Map<String, String> _environment;
  final Uri baseUrl;

  /// Token of a superuser; superusers bypass all access rules.
  final String superuserToken;

  static const _superuserEmail = 'root@setding.test';
  static const _superuserPassword = 'superuser-password';

  /// [environment] is added to the server's environment (e.g. deep-link
  /// settings read by the hooks). Unless it says otherwise, sign-up is open
  /// (`SETDING_REGISTRATION=open`, ADR-0024), so tests can create users, and
  /// invitation tokens are stored encrypted (`SETDING_INVITE_KEY`).
  /// [publicDir] holds static files (e.g. the web client, ADR-0018).
  /// The rate limits are turned off after the start unless [rateLimits].
  ///
  /// With [migrationsBefore] (a migration file name) only the older
  /// migrations run, so a test can create data in the old schema and then
  /// [upgrade] to apply the rest.
  static Future<PocketBase> start({
    Map<String, String>? environment,
    String? publicDir,
    bool rateLimits = false,
    String? migrationsBefore,
  }) async {
    environment = {
      'SETDING_REGISTRATION': 'open',
      'SETDING_INVITE_KEY': 'test-invite-key',
      ...?environment,
    };
    final root = _repositoryRoot();
    final binary = await _binary(root);
    final dir = await Directory.systemTemp.createTemp('setding-pb-');
    var migrations = '$root/server/pb_migrations';
    if (migrationsBefore != null) {
      final older = Directory('${dir.path}/pb_migrations')..createSync();
      for (final f in Directory(migrations).listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name.compareTo(migrationsBefore) < 0) {
          f.copySync('${older.path}/$name');
        }
      }
      migrations = older.path;
    }
    return _launch(
      binary: binary,
      root: root,
      dir: dir,
      migrations: migrations,
      environment: environment,
      publicDir: publicDir,
      rateLimits: rateLimits,
    );
  }

  /// The server's data directory (`pb_data`: `data.db` and `storage/`).
  String get dataDir => '${_dir.path}/pb_data';

  /// Restarts the server on the same data with all migrations (see
  /// `migrationsBefore` of [start]); this instance must not be used
  /// afterwards.
  Future<PocketBase> upgrade() => restart();

  /// Stops the server, runs [whileStopped] (e.g. a restore into [dataDir])
  /// and starts it again on the same directory with all migrations; this
  /// instance must not be used afterwards.
  Future<PocketBase> restart({FutureOr<void> Function()? whileStopped}) async {
    _process.kill();
    await _process.exitCode;
    await whileStopped?.call();
    return _launch(
      binary: _binaryPath,
      root: _root,
      dir: _dir,
      migrations: '$_root/server/pb_migrations',
      environment: _environment,
      publicDir: null,
      rateLimits: false,
    );
  }

  static Future<PocketBase> _launch({
    required String binary,
    required String root,
    required Directory dir,
    required String migrations,
    required Map<String, String> environment,
    required String? publicDir,
    required bool rateLimits,
  }) async {
    final data = '${dir.path}/pb_data';
    final upsert = await Process.run(binary, [
      'superuser',
      'upsert',
      _superuserEmail,
      _superuserPassword,
      '--dir',
      data,
      '--migrationsDir',
      migrations,
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
      migrations,
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
    final pb = PocketBase._(
      process,
      dir,
      binary,
      root,
      environment,
      baseUrl,
      token as String,
    );
    if (!rateLimits) {
      final r = await pb.superuser.send(
        'PATCH',
        '/api/settings',
        body: {
          'rateLimits': {'enabled': false},
        },
      );
      r.expectStatus(200);
    }
    return pb;
  }

  /// Runs a console command of the server's binary on its data, with the
  /// repository's hooks (e.g. `founder-invite`, ADR-0024).
  Future<ProcessResult> command(
    List<String> args, {
    Map<String, String>? environment,
  }) => Process.run(_binaryPath, [
    ...args,
    '--dir',
    '${_dir.path}/pb_data',
    '--hooksDir',
    '$_root/server/pb_hooks',
    '--migrationsDir',
    '$_root/server/pb_migrations',
  ], environment: environment);

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
  /// [name] becomes the nickname, so it is the user's display name
  /// (ADR-0062); without one the user is "User `n`".
  Future<User> signUp([String? name]) async {
    final n = ++_users;
    final email =
        'user$n-${DateTime.now().microsecondsSinceEpoch}@setding.test';
    const password = 'password-123';
    // As superuser, so it also works on invite-only servers (ADR-0024).
    final created = await superuser.post('users', {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'first_name': name ?? 'User',
      'last_name': name == null ? '$n' : 'Test',
      'nickname': ?name,
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
