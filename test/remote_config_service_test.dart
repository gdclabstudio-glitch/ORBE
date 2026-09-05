import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/services/remote_config_service.dart';

void main() {
  group('RemoteConfigService (fallback behavior)', () {
    test('getString returns fallback when not initialized', () {
      final value = RemoteConfigService.getString(
        'nonexistent_key',
        fallback: 'fallback',
      );
      expect(value, 'fallback');
    });

    test('getBool returns fallback when not initialized', () {
      final value = RemoteConfigService.getBool('flag_x', fallback: true);
      expect(value, isTrue);
    });

    test('getInt returns fallback when not initialized', () {
      final value = RemoteConfigService.getInt('count', fallback: 42);
      expect(value, 42);
    });

    test('getDouble returns fallback when not initialized', () {
      final value = RemoteConfigService.getDouble('ratio', fallback: 3.14);
      expect(value, closeTo(3.14, 0.0001));
    });
  });
}
