import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'observability_service.dart';

class RemoteConfigService {
  RemoteConfigService._();

  static FirebaseRemoteConfig? _remoteConfig;

  /// Initialize Remote Config: configure settings, defaults and fetch & activate
  static Future<void> init() async {
    try {
      ObservabilityService.logEvent('remote_config_init_start');

      _remoteConfig = FirebaseRemoteConfig.instance;

      // Configure settings: adjust fetch timeout and minimum fetch interval
      try {
        await _remoteConfig!.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 10),
            minimumFetchInterval: const Duration(hours: 1),
          ),
        );
      } catch (_) {
        // Older/newer versions of the plugin may use a different API; ignore failure here
        if (kDebugMode)
          debugPrint(
            'RemoteConfig: setConfigSettings may not be available on this version.',
          );
      }

      // Set sensible defaults so app has deterministic behavior before fetch
      final defaults = <String, dynamic>{
        'feature_new_home_enabled': false,
        'welcome_message': 'Bem-vindo ao ORBE!',
      };

      try {
        await _remoteConfig!.setDefaults(defaults);
      } catch (_) {
        // Some versions expect Map<String, String> or Map<String, dynamic>
        try {
          await _remoteConfig!.setDefaults(
            defaults.map((k, v) => MapEntry(k, v.toString())),
          );
        } catch (e, s) {
          await ObservabilityService.reportError(
            e,
            s,
            reason: 'RemoteConfig.setDefaults',
          );
        }
      }

      // Fetch and activate remote values
      try {
        await _remoteConfig!.fetchAndActivate();
      } catch (e, s) {
        // Non-fatal: log to observability but don't block app startup
        await ObservabilityService.reportError(
          e,
          s,
          reason: 'RemoteConfig.fetchAndActivate',
        );
      }

      ObservabilityService.logEvent('remote_config_init_success');
    } catch (e, s) {
      try {
        await ObservabilityService.reportError(
          e,
          s,
          reason: 'RemoteConfig.init',
        );
      } catch (_) {}
    }
  }

  /// Helper to get a typed value
  static String getString(String key, {String? fallback}) {
    try {
      return _remoteConfig?.getString(key) ?? (fallback ?? '');
    } catch (_) {
      return fallback ?? '';
    }
  }

  static bool getBool(String key, {bool fallback = false}) {
    try {
      return _remoteConfig?.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static int getInt(String key, {int fallback = 0}) {
    try {
      return _remoteConfig?.getInt(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static double getDouble(String key, {double fallback = 0.0}) {
    try {
      return _remoteConfig?.getDouble(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
