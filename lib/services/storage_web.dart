// ignore_for_file: deprecated_member_use
// Web implementation using window.localStorage
import 'dart:html' as html;

import 'storage_service.dart';

class WebStorageService implements StorageService {
  WebStorageService();

  @override
  Future<void> write({required String key, required String value}) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return html.window.localStorage[key];
  }

  @override
  Future<void> delete({required String key}) async {
    html.window.localStorage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    html.window.localStorage.clear();
  }
}

// Platform-aliased class used by conditional imports
class PlatformStorageService extends WebStorageService {
  PlatformStorageService();
}
