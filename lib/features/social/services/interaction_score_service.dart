import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/interaction_score.dart';

class InteractionScoreService {
  static const double _maxScore = 100;

  static double calculate({
    required String userId,
    required Map<String, dynamic> userData,
    required String currentUserId,
    required Set<String> currentUserFriends,
    required Set<String> currentUserCloseFriends,
  }) {
    return calculateScore(
      userId: userId,
      userData: userData,
      currentUserId: currentUserId,
      currentUserFriends: currentUserFriends,
      currentUserCloseFriends: currentUserCloseFriends,
    ).total;
  }

  static InteractionScore calculateScore({
    required String userId,
    required Map<String, dynamic> userData,
    required String currentUserId,
    required Set<String> currentUserFriends,
    required Set<String> currentUserCloseFriends,
  }) {
    final uid = userId;
    final friends = (userData['friends'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    final closeFriends = (userData['closeFriends'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    final followers = (userData['followers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    final stats = userData['stats'] is Map
        ? Map<String, dynamic>.from(userData['stats'] as Map)
        : <String, dynamic>{};

    final followerCount =
        (stats['followers'] as num?)?.toDouble() ?? followers.length.toDouble();
    final followingCount = (stats['following'] as num?)?.toDouble() ?? 0;
    final isFriend = currentUserFriends.contains(uid);
    final isCloseFriend = currentUserCloseFriends.contains(uid) ||
        closeFriends.contains(currentUserId) ||
        userData['isCloseFriend'] == true;
    final isCurrentUser = uid == currentUserId;
    final isOnline =
        (userData['presence'] as String? ?? 'offline').toLowerCase() ==
            'online';
    final isVip = userData['vip'] == true;
    final hasStory = userData['hasStory'] == true || userData['story'] == true;

    final recentAt = userData['lastActiveAt'];
    final recencyBoost = _recencyBoost(recentAt);

    return InteractionScore(
      socialRelevance: followerCount * 0.6 + followingCount * 0.35,
      interactionFrequency: friends.length * 4.5,
      relationshipStrength: (isCurrentUser ? 8 : 0) +
          (isFriend ? 28 : 0) +
          (isCloseFriend ? 26 : 0),
      activity: (isVip ? 12 : 0) + (hasStory ? 10 : 0),
      recency: recencyBoost,
      presence: isOnline ? 14 : 0,
      maxScore: _maxScore,
    );
  }

  static double normalized(double score) => (score / _maxScore).clamp(0.0, 1.0);

  static double bubbleSizeFromScore(double normalizedScore) {
    final clamped = normalizedScore.clamp(0.0, 1.0);
    return 38 + (clamped * 42);
  }

  static double distanceFromScore(double normalizedScore) {
    final clamped = normalizedScore.clamp(0.0, 1.0);
    return 0.34 + (1 - clamped) * 0.76;
  }

  static double _recencyBoost(dynamic recentAt) {
    if (recentAt is Timestamp) {
      final diff = DateTime.now().difference(recentAt.toDate());
      if (diff.inMinutes <= 15) return 18;
      if (diff.inHours <= 8) return 12;
      if (diff.inDays <= 3) return 7;
      if (diff.inDays <= 14) return 4;
      return 1;
    }

    if (recentAt is DateTime) {
      final diff = DateTime.now().difference(recentAt);
      if (diff.inMinutes <= 15) return 18;
      if (diff.inHours <= 8) return 12;
      if (diff.inDays <= 3) return 7;
      if (diff.inDays <= 14) return 4;
      return 1;
    }

    return 0;
  }
}
