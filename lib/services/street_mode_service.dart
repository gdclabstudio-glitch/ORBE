import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class StreetModeService extends ChangeNotifier {
  static const key = 'settings_street_mode';

  final StorageService _storage;
  bool _enabled = false;

  StreetModeService(this._storage) {
    _load();
  }

  bool get enabled => _enabled;

  Future<void> _load() async {
    final value = await _storage.read(key: key);
    _enabled = value == 'true';
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
    await _storage.write(key: key, value: enabled ? 'true' : 'false');
  }
}
