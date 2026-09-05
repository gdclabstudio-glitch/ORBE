import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'observability_service.dart';
import 'storage_platform.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final _storage = PlatformStorageService();

  /// Initialize messaging: request permissions, obtain token and set listeners.
  static Future<void> init() async {
    try {
      // Request permission on supported platforms
      if (!kIsWeb) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await ObservabilityService.logEvent(
          'push_permission_requested',
          parameters: {
            'alert': settings.alert == true,
            'badge': settings.badge == true,
            'sound': settings.sound == true,
          },
        );
      }

      // Get the device token and persist it securely (for later server use)
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: 'fcm_token', value: token);
        await ObservabilityService.logEvent(
          'push_token_acquired',
          parameters: {'token_length': token.length},
        );
      }

      // Listen for messages when app is foregrounded
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          final data = <String, Object>{};
          if (message.notification != null) {
            data['title'] = message.notification?.title ?? '';
            data['body'] = message.notification?.body ?? '';
          }
          // Convert message.data (Map<String, dynamic>) into Map<String, Object>
          try {
            data.addAll(
              message.data.map((k, v) => MapEntry(k, (v ?? '').toString())),
            );
          } catch (_) {}
          ObservabilityService.logEvent('push_received', parameters: data);
        } catch (e, s) {
          ObservabilityService.reportError(e, s, reason: 'Push.onMessage');
        }
      });

      // Optional: handle token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await _storage.write(key: 'fcm_token', value: newToken);
          await ObservabilityService.logEvent(
            'push_token_refreshed',
            parameters: {'len': newToken.length},
          );
        } catch (e, s) {
          ObservabilityService.reportError(e, s, reason: 'Push.onTokenRefresh');
        }
      });
    } catch (e, s) {
      // Log and continue; push notifications shouldn't block app startup
      await ObservabilityService.reportError(e, s, reason: 'Push.init');
    }
  }
}
