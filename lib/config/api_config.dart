import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Allow override at compile time: --dart-define=API_BASE_URL=https://api.example.com
  static const _envBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBase.isNotEmpty) return _envBase;

    // Web typically can use the same host
    if (kIsWeb) return 'http://localhost:8080/api/v1';

    // Mobile platforms
    try {
      if (Platform.isAndroid) {
        // Android emulator maps localhost to 10.0.2.2
        return 'http://10.0.2.2:8080/api/v1';
      }
      if (Platform.isIOS) {
        // iOS simulator can use localhost
        return 'http://localhost:8080/api/v1';
      }
    } catch (_) {}

    // Fallback: commonly-used LAN pattern; recommend setting --dart-define when running on device
    return 'http://192.168.0.100:8080/api/v1';
  }
}
