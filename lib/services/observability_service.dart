import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ObservabilityService {
  ObservabilityService._();

  static FirebaseAnalytics? analytics;

  static const Set<String> _sensitiveLogKeys = {
    'password',
    'token',
    'authorization',
    'api_key',
    'apikey',
    'secret',
    'refresh_token',
    'session',
    'cookie',
    'email',
    'phone',
    'ssn',
    'cpf',
  };

  static String generateCorrelationId([String prefix = 'obs']) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '${prefix}_${timestamp.toString()}';
  }

  static String _truncateText(String value, {int maxLength = 256}) {
    if (value.length <= maxLength) return value;
    if (maxLength <= 3) return value.substring(0, maxLength);
    return '${value.substring(0, maxLength - 3)}...';
  }

  static Object? _sanitizeValue(Object? value, {int depth = 0}) {
    if (value == null) return null;

    if (value is Map) {
      final sanitized = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final isSensitive = _sensitiveLogKeys.any(
          (sensitiveKey) => key.toLowerCase().contains(sensitiveKey),
        );

        if (isSensitive) {
          sanitized[key] = '[REDACTED]';
          continue;
        }

        if (depth >= 2) {
          sanitized[key] = _truncateText(entry.value.toString());
          continue;
        }

        sanitized[key] = _sanitizeValue(entry.value, depth: depth + 1);
      }
      return sanitized;
    }

    if (value is List) {
      if (depth >= 2) {
        return value
            .take(8)
            .map((item) => _sanitizeValue(item, depth: depth + 1))
            .toList();
      }
      return value
          .map((item) => _sanitizeValue(item, depth: depth + 1))
          .toList();
    }

    if (value is String) {
      return _truncateText(value);
    }

    if (value is num || value is bool) {
      return value;
    }

    return _truncateText(value.toString());
  }

  static Map<String, Object>? sanitizeParameters(
      Map<String, Object>? parameters) {
    if (parameters == null || parameters.isEmpty) {
      return null;
    }

    final sanitized = <String, Object>{};
    for (final entry in parameters.entries) {
      final key = entry.key;
      final isSensitive = _sensitiveLogKeys.any(
        (sensitiveKey) => key.toLowerCase().contains(sensitiveKey),
      );

      if (isSensitive) {
        sanitized[key] = '[REDACTED]';
        continue;
      }

      final safeValue = _sanitizeValue(entry.value);
      sanitized[key] = safeValue is Object ? safeValue : '[REDACTED]';
    }
    return sanitized;
  }

  /// Initialize Analytics & Crashlytics. Safe to call multiple times.
  static Future<void> init() async {
    analytics = FirebaseAnalytics.instance;

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Crashlytics collection could not be enabled at init.');
      }
    }
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    final sanitizedParameters = sanitizeParameters(parameters);
    try {
      await analytics?.logEvent(
        name: name,
        parameters: sanitizedParameters,
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('ObservabilityService.logEvent failed for "$name".');
      }
    }
  }

  static Future<void> setUserId(String? id) async {
    final safeId = id == null || id.trim().isEmpty ? null : id.trim();
    try {
      await analytics?.setUserId(id: safeId);
      await FirebaseCrashlytics.instance.setUserIdentifier(safeId ?? '');
    } catch (_) {
      if (kDebugMode) {
        debugPrint('ObservabilityService.setUserId failed.');
      }
    }
  }

  /// Record a non-fatal error with Crashlytics (object + stacktrace)
  static Future<void> reportError(
    Object error,
    StackTrace stack, {
    String? reason,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
            'ObservabilityService.reportError failed for reason: ${reason ?? 'unknown'}');
      }
    }
  }

  /// Record Flutter framework errors (FlutterErrorDetails) into Crashlytics
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    try {
      await FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Failed to record flutter error to Crashlytics.');
      }
    }
  }
}
