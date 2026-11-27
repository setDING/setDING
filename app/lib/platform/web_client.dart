import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this is the web client (ADR-0018): signing in is required, the
/// local library and file import/export are hidden, and signing out deletes
/// the local data. Overridden in tests.
final webClientProvider = Provider<bool>((ref) => kIsWeb);
