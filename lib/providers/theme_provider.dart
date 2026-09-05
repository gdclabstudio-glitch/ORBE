import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage;
  bool _isDark = true;

  static const _keyDarkTheme = 'settings_dark_theme';

  ThemeProvider(this._storage) {
    _load();
  }

  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> _load() async {
    try {
      final value = await _storage.read(key: _keyDarkTheme);
      if (value != null) {
        _isDark = value == 'true';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleTheme([bool? dark]) async {
    _isDark = dark ?? !_isDark;
    notifyListeners();
    try {
      await _storage.write(
        key: _keyDarkTheme,
        value: _isDark ? 'true' : 'false',
      );
    } catch (_) {}
  }
}
