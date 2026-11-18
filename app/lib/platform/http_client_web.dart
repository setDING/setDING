import 'package:http/http.dart' as http;

/// Browsers check certificates themselves.
http.Client createHttpClient() => http.Client();
