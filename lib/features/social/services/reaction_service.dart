import 'package:cloud_firestore/cloud_firestore.dart';

/// ReactionService: stores reactions in subcollections to avoid hot-document
/// contention. Structure used:
/// - posts/{postId}/reactions/{reactionId}
/// - posts/{postId}/comments/{commentId}/reactions/{reactionId}
///
/// Each reaction document id is deterministic per user+emoji to allow simple
/// toggle semantics: `<userId>_<emojiHex>`.
class ReactionService {
  final FirebaseFirestore _firestore;

  ReactionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String _docIdFor(String userId, String emoji) {
    // encode emoji runes into hex joined by - to keep id filesystem-friendly
    final hex = emoji.runes.map((r) => r.toRadixString(16)).join('-');
    return '${userId}_$hex'; // prefix to reduce chance of numeric-leading ids
  }

  CollectionReference _postReactionsRef(String postId) =>
      _firestore.collection('posts').doc(postId).collection('reactions');

  CollectionReference _commentReactionsRef(String postId, String commentId) =>
      _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('reactions');

  /// Toggle reaction for a post by creating/deleting a single reaction doc.
  Future<void> toggleReactionOnPost({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    final id = _docIdFor(userId, emoji);
    final ref = _postReactionsRef(postId).doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': userId,
        'type': emoji,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream aggregated counts per emoji for a post (computed client-side).
  Stream<Map<String, int>> reactionsCountStream(String postId) {
    final col = _postReactionsRef(postId);
    return col.snapshots().map((q) {
      final Map<String, int> counts = <String, int>{};
      for (final doc in q.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final type = data['type'] as String? ?? '❤️';
          counts[type] = (counts[type] ?? 0) + 1;
        } catch (_) {}
      }
      return counts;
    });
  }

  /// Toggle reaction for a comment (stored in a comment-level reactions subcollection).
  Future<void> toggleReactionOnComment({
    required String postId,
    required String commentId,
    required String userId,
    required String emoji,
  }) async {
    final id = _docIdFor(userId, emoji);
    final ref = _commentReactionsRef(postId, commentId).doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': userId,
        'type': emoji,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream aggregated counts per emoji for a comment.
  Stream<Map<String, int>> reactionsCountStreamForComment(
    String postId,
    String commentId,
  ) {
    final col = _commentReactionsRef(postId, commentId);
    return col.snapshots().map((q) {
      final Map<String, int> counts = <String, int>{};
      for (final doc in q.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final type = data['type'] as String? ?? '❤️';
          counts[type] = (counts[type] ?? 0) + 1;
        } catch (_) {}
      }
      return counts;
    });
  }

  // --- Story reactions: stored under users/{ownerId}/stories/{storyId}/reactions/{reactionId}
  CollectionReference _storyReactionsRef(String ownerId, String storyId) =>
      _firestore
          .collection('users')
          .doc(ownerId)
          .collection('stories')
          .doc(storyId)
          .collection('reactions');

  /// Toggle reaction for a story (ownerId = story owner's uid)
  Future<void> toggleReactionOnStory({
    required String ownerId,
    required String storyId,
    required String userId,
    required String emoji,
  }) async {
    final id = _docIdFor(userId, emoji);
    final ref = _storyReactionsRef(ownerId, storyId).doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': userId,
        'type': emoji,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream aggregated counts per emoji for a story.
  Stream<Map<String, int>> reactionsCountStreamForStory(
    String ownerId,
    String storyId,
  ) {
    final col = _storyReactionsRef(ownerId, storyId);
    return col.snapshots().map((q) {
      final Map<String, int> counts = <String, int>{};
      for (final doc in q.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final type = data['type'] as String? ?? '❤️';
          counts[type] = (counts[type] ?? 0) + 1;
        } catch (_) {}
      }
      return counts;
    });
  }

  /// Check whether a specific user reacted with a given emoji to a story.
  Future<bool> userHasReactedToStory({
    required String ownerId,
    required String storyId,
    required String userId,
    required String emoji,
  }) async {
    final id = _docIdFor(userId, emoji);
    final ref = _storyReactionsRef(ownerId, storyId).doc(id);
    final snap = await ref.get();
    return snap.exists;
  }
}
