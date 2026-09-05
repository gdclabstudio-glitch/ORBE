import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// StorageUploadService: standardize uploads to Firebase Storage and return download URLs.
class StorageUploadService {
  final FirebaseStorage _storage;
  StorageUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Upload bytes to a given path and return the download URL.
  Future<String> uploadBytes(
    String path,
    List<int> bytes, {
    String contentType = 'image/jpeg',
    String? ownerUid,
  }) async {
    final ref = _storage.ref().child(path);
    final meta = SettableMetadata(
      contentType: contentType,
      customMetadata: {if (ownerUid != null) 'ownerUid': ownerUid},
    );
    final task = await ref.putData(Uint8List.fromList(bytes), meta);
    final url = await task.ref.getDownloadURL();
    return url;
  }

  /// Upload a File to a given path and return download URL.
  Future<String> uploadFile(
    String path,
    File file, {
    String contentType = 'image/jpeg',
    String? ownerUid,
  }) async {
    final ref = _storage.ref().child(path);
    final meta = SettableMetadata(
      contentType: contentType,
      customMetadata: {if (ownerUid != null) 'ownerUid': ownerUid},
    );
    final uploadTask = await ref.putFile(file, meta);
    final url = await uploadTask.ref.getDownloadURL();
    return url;
  }

  /// Build a standardized path for user avatars.
  String userAvatarPath(String uid) => 'users/$uid/avatar.jpg';

  /// Build a path for post images.
  String postImagePath(String postId, {String filename = 'image.jpg'}) =>
      'posts/$postId/$filename';

  /// Build a path for chat images.
  String chatImagePath(String chatId, int timestamp, {String ext = 'jpg'}) =>
      'chats/$chatId/$timestamp.$ext';
}
