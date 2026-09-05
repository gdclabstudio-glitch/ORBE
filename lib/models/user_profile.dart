import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final Map<String, int> stats; // e.g., posts, followers, following

  UserProfile({
    required this.id,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    DateTime? createdAt,
    Map<String, int>? stats,
  })  : createdAt = createdAt ?? DateTime.now(),
        stats = Map<String, int>.from(
          stats ?? {'posts': 0, 'followers': 0, 'following': 0},
        );

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    Map<String, int>? stats,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'stats': stats,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final rawStats = Map<String, dynamic>.from(
      map['stats'] as Map<String, dynamic>? ?? {},
    );
    final stats = <String, int>{
      'posts': (rawStats['posts'] as int?) ?? 0,
      'followers': (rawStats['followers'] as int?) ?? 0,
      'following': (rawStats['following'] as int?) ?? 0,
    };

    // enforce size limits to avoid Firestore document bloat
    final bio = (map['bio'] as String?)?.substring(
      0,
      (map['bio'] as String?)?.length.clamp(0, 1000) ?? 0,
    );
    final displayName = (map['displayName'] as String?) ?? '';

    return UserProfile(
      id: map['id'] as String,
      displayName:
          displayName.length > 60 ? displayName.substring(0, 60) : displayName,
      bio: bio,
      avatarUrl: map['avatarUrl'] as String?,
      createdAt: createdAt,
      stats: stats,
    );
  }
}
