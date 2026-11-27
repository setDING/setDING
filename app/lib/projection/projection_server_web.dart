import 'projection_state.dart';

/// The web client cannot listen on a socket, so it has no projection
/// (ADR-0068 §1). Same API as the native server; [start] throws.
class ProjectionServer {
  ProjectionServer({
    required this.page,
    this.heartbeat = const Duration(seconds: 5),
    this.maxClients = 32,
  });

  static const supported = false;
  static const defaultPort = 8231;

  final String page;
  final Duration heartbeat;
  final int maxClients;

  bool get running => false;
  int? get port => null;
  String? get token => null;
  int get clients => 0;
  ProjectionState get state => const ProjectionState.blank();

  Future<void> start({int port = defaultPort, String? token}) =>
      Future.error(UnsupportedError('No lyrics projection on the web'));

  Future<void> stop() async {}

  void update(ProjectionState state) {}

  Future<List<Uri>> urls() async => const [];
}
