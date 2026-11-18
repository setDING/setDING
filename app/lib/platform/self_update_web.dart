import 'package:http/http.dart' as http;

import '../update/app_update.dart';

/// The web client is updated by reloading it (ADR-0018), never by a setup.
bool isInstalledWithSetup() => false;

/// Not available on the web (see [isInstalledWithSetup]).
Future<String> downloadVerifiedUpdate(
  http.Client client,
  AvailableUpdate update, {
  void Function(double progress)? onProgress,
}) => throw UnsupportedError('No setup on the web');

/// Not available on the web (see [isInstalledWithSetup]).
Future<void> runInstallerAndExit(String setupPath) =>
    throw UnsupportedError('No setup on the web');
