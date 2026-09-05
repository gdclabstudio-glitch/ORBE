// Conditional export: choose the correct implementation for the current platform
export 'storage_mobile.dart' if (dart.library.html) 'storage_web.dart';
