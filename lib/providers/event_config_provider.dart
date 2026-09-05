import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../config/event_config.dart';
import '../services/auth_service.dart';
import '../services/observability_service.dart';

class EventConfigProvider with ChangeNotifier {
  late final ApiService _api;

  EventConfigProvider({AuthService? authService}) {
    _api = ApiService(authService: authService);
    // initial load (deferred to avoid blocking synchronous startup)
    // schedule fetch on next microtask so constructors/build won't be blocked
    scheduleMicrotask(() async {
      await fetch();
    });
  }

  String _title = 'ORBE • A COMUNIDADE EM MOVIMENTO';
  String _date = '05 de Fevereiro de 2027';
  String _location = 'Peçanha - MG';

  bool _loading = false;

  // Optional stream to allow fine-grained subscriptions
  final StreamController<Map<String, String>> _onChange =
      StreamController.broadcast();

  Stream<Map<String, String>> get onChange => _onChange.stream;

  String get title => _title;
  String get date => _date;
  String get location => _location;
  bool get isLoading => _loading;

  /// Returns a concrete DateTime for the configured event date when possible.
  /// Falls back to the static EventConfig.eventDate when parsing fails.
  DateTime get eventDate {
    try {
      return DateTime.parse(_date);
    } catch (_) {
      return EventConfig.eventDate;
    }
  }

  // WhatsApp helpers (defaults kept in EventConfig)
  String get whatsappSupportMessage => EventConfig.whatsappSupportMessage;
  String get whatsappPurchaseMessage => EventConfig.whatsappPurchaseMessage;
  String get whatsappPhone => EventConfig.whatsappPhone;

  Future<void> fetch() async {
    _loading = true;
    notifyListeners();
    try {
      await ObservabilityService.logEvent('EventConfigProvider.fetch_start');
      final data = await _api.getEventConfig();
      _title = data['title']?.toString() ?? _title;
      _date = data['date']?.toString() ?? _date;
      _location = data['location']?.toString() ?? _location;
      _onChange.add({'title': _title, 'date': _date, 'location': _location});
      await ObservabilityService.logEvent('EventConfigProvider.fetch_success');
    } catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'EventConfigProvider.fetch',
      );
      await ObservabilityService.logEvent(
        'EventConfigProvider.fetch_failure',
        parameters: {'error': e.toString()},
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> update(Map<String, String> data) async {
    _loading = true;
    notifyListeners();
    try {
      await _api.updateEventConfig(data);
      // update local state immediately for reactivity
      _title = data['title'] ?? _title;
      _date = data['date'] ?? _date;
      _location = data['location'] ?? _location;
      _onChange.add({'title': _title, 'date': _date, 'location': _location});
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void disposeProvider() {
    _onChange.close();
  }
}
