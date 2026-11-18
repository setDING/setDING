import 'package:http/http.dart' as http;

import '../update/app_update.dart';

/// The web client is updated by reloading it (ADR-0018), never by itself.
SelfUpdateKind? detectSelfUpdateKind() => null;

/// Not available on the web (see [detectSelfUpdateKind]).
Future<void> installUpdateAndExit(
  http.Client client,
  AvailableUpdate update,
  SelfUpdateKind kind, {
  void Function(double progress)? onProgress,
}) => throw UnsupportedError('No self-update on the web');
