import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_service.dart';

class MobileStorageService implements StorageService {
  final FlutterSecureStorage _storage;

  MobileStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}

// Platform-aliased class used by conditional imports
class PlatformStorageService extends MobileStorageService {
  PlatformStorageService({FlutterSecureStorage? storage})
      : super(storage: storage);
}
