import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class MediaCompressor {
  /// Compress an image file and return compressed bytes. Falls back to original bytes on error.
  static Future<Uint8List> compressImageFile(
    File inputFile, {
    int quality = 85,
    int maxWidth = 1280,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        inputFile.absolute.path,
        quality: quality,
        minWidth: maxWidth,
        keepExif: true,
      );
      if (result != null && result.isNotEmpty)
        return Uint8List.fromList(result);
    } catch (e) {
      // ignore and fallback to original
      if (kDebugMode) debugPrint('Image compression failed: $e');
    }
    return await inputFile.readAsBytes();
  }

  /// Compress a video file and return a File pointing to the compressed file.
  /// NOTE: Dedicated client-side video compression is optional and may require
  /// additional native setup. As a safe fallback this method returns the
  /// original file while providing a single place to add a native compressor
  /// (e.g., flutter_video_compress) later.
  static Future<File> compressVideoFile(File inputFile) async {
    if (kDebugMode) {
      debugPrint(
        'Video compression not available in this build — returning original file.',
      );
    }
    return inputFile;
  }
}
