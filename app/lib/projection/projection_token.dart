/// The token of the projection address (ADR-0068 §2); pure Dart, used by
/// the server and its screenshot tool.
library;

import 'dart:convert';
import 'dart:math';

/// A random 128-bit token, URL-safe base64 without padding (22 characters).
String newProjectionToken() {
  final random = Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Whether [value] has the form of [newProjectionToken].
bool isProjectionToken(String? value) =>
    value != null && RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value);
