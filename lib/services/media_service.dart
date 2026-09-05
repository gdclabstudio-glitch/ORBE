import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// MediaService: compress images and produce thumbnails before upload.
class MediaService {
  const MediaService();

  /// Compress an image file and return the compressed File.
  /// maxWidth controls the largest dimension (preserving aspect ratio).
  /// quality is 0-100.
  Future<File> compressImageFile(
    File input, {
    int maxWidth = 1200,
    int quality = 80,
    String? targetFileName,
  }) async {
    final inputPath = input.path;
    final outDir = await getTemporaryDirectory();
    final targetName =
        targetFileName ?? 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = '${outDir.path}/$targetName';

    final result = await FlutterImageCompress.compressWithFile(
      inputPath,
      minWidth: maxWidth,
      minHeight: maxWidth,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (result == null) return input;

    final outFile = File(targetPath);
    await outFile.writeAsBytes(result);
    return outFile;
  }

  /// Create a thumbnail (smaller dimensions) and return File.
  Future<File> createThumbnail(
    File input, {
    int maxWidth = 300,
    int quality = 60,
  }) async {
    return compressImageFile(
      input,
      maxWidth: maxWidth,
      quality: quality,
      targetFileName: 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  /// Convenience to compress from bytes and return bytes (useful for in-memory flows).
  Future<Uint8List?> compressBytes(
    Uint8List data, {
    int maxWidth = 1200,
    int quality = 80,
  }) async {
    return await FlutterImageCompress.compressWithList(
      data,
      minWidth: maxWidth,
      minHeight: maxWidth,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }
}
