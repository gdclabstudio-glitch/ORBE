import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/services/observability_service.dart';

void main() {
  group('ObservabilityService', () {
    test('sanitizes sensitive payload keys before logging', () {
      final sanitized = ObservabilityService.sanitizeParameters({
        'userId': 'user_123',
        'password': 'super-secret',
        'authorization': 'Bearer token-value',
        'nested': {'apiKey': 'abc123', 'safe': 'ok'},
        'array': [
          {'token': 'abc'},
          'safe-value',
        ],
      });

      expect(sanitized, isNotNull);
      expect(sanitized!['userId'], 'user_123');
      expect(sanitized['password'], '[REDACTED]');
      expect(sanitized['authorization'], '[REDACTED]');
      expect(sanitized['nested'], isA<Map>());
      expect((sanitized['nested'] as Map)['apiKey'], '[REDACTED]');
      expect((sanitized['array'] as List<Object?>)[0], isA<Map>());
      expect(((sanitized['array'] as List<Object?>)[0] as Map)['token'],
          '[REDACTED]');
      expect((sanitized['array'] as List<Object?>)[1], 'safe-value');
    });

    test('creates a correlation ID with a stable prefix', () {
      final id = ObservabilityService.generateCorrelationId('ui');
      expect(id, startsWith('ui_'));
      expect(id.length, greaterThan(10));
    });
  });
}
