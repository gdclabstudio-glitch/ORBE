import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';

class PostService {
  final CollectionReference _postsCollection =
      FirebaseFirestore.instance.collection('posts');

  Future<void> createPost({
    required String userId,
    required String userName,
    String? avatarUrl,
    required String content,
  }) async {
    final newPost = Post(
      id: '',
      userId: userId,
      userName: userName,
      avatarUrl: avatarUrl,
      content: content,
      createdAt: DateTime.now(),
      isPinned: false,
    );

    await _postsCollection.add(newPost.toMap());
  }

  Stream<List<Post>> getPostsStream() {
    return _postsCollection
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    });
  }

  Future<void> deletePost(String postId) async {
    await _postsCollection.doc(postId).delete();
  }

  Future<void> togglePinPost(String postId, bool isPinned) async {
    await _postsCollection.doc(postId).update({'isPinned': isPinned});
  }
}
