import 'package:flutter/foundation.dart';

/// Optional compile-time override: `--dart-define=API_BASE_URL=https://example.com/api/`
const String _kApiUrlOverride = String.fromEnvironment('API_BASE_URL');

/// Production API (HTTPS via Caddy). Used for `--release` when `API_BASE_URL` is not set.
const String kProductionApiBaseUrl = 'https://professorccs260.click/api/';

/// Debug/profile default when `API_BASE_URL` is unset.
/// Android emulator → [10.0.2.2]. iOS simulator / desktop / web → [localhost].
String _devDefaultBaseUrl() {
  if (kIsWeb) return 'http://localhost:8000/api/';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/';
  }
  return 'http://localhost:8000/api/';
}

/// Resolves the Laravel API base URL (with trailing slash).
class ApiConfig {
  ApiConfig._();

  static String? _cached;

  static Future<String> getBaseUrl() async {
    if (_cached != null) return _cached!;

    if (_kApiUrlOverride.isNotEmpty) {
      _cached = _withTrailingSlash(_kApiUrlOverride);
      return _cached!;
    }

    if (!kReleaseMode) {
      _cached = _devDefaultBaseUrl();
      return _cached!;
    }

    _cached = _withTrailingSlash(kProductionApiBaseUrl);
    return _cached!;
  }

  static String _withTrailingSlash(String url) {
    if (url.endsWith('/')) return url;
    return '$url/';
  }
}
