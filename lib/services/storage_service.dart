abstract class StorageService {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

// Factory helper to obtain a platform-appropriate implementation when
// an explicit instance is not supplied.
StorageService defaultStorageService() {
  // Note: the concrete implementations are defined in storage_mobile.dart and storage_web.dart
  // to avoid conditional imports complexity here we return null and callers can construct
  // appropriate instance using kIsWeb if needed.
  throw UnimplementedError(
    'Use platform-specific storage constructors (MobileStorageService / WebStorageService)',
  );
}
