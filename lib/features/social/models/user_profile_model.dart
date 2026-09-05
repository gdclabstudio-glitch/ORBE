import 'package:flutter/foundation.dart';

/// UserProfile model used by the social features.
///
/// Fields:
/// - uid: unique identifier for the user (required)
/// - name, email, photoUrl: basic public profile information
/// - isCloseFriend: boolean flag used to mark "Close Friends" (green list)
/// - status: short user-defined presence/status message
/// - friends: list of connected friend UIDs
/// - pendingRequests: list of UIDs which have pending friend requests
@immutable
class UserProfile {
  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;
  final bool isCloseFriend;
  final String? status;
  final List<String> friends;
  final List<String> pendingRequests;

  UserProfile({
    required this.uid,
    this.name,
    this.email,
    this.photoUrl,
    this.isCloseFriend = false,
    this.status,
    List<String>? friends,
    List<String>? pendingRequests,
  })  : friends = List.unmodifiable(friends ?? const []),
        pendingRequests = List.unmodifiable(pendingRequests ?? const []);

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    bool? isCloseFriend,
    String? status,
    List<String>? friends,
    List<String>? pendingRequests,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isCloseFriend: isCloseFriend ?? this.isCloseFriend,
      status: status ?? this.status,
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isCloseFriend': isCloseFriend,
      'status': status,
      'friends': friends,
      'pendingRequests': pendingRequests,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isCloseFriend: json['isCloseFriend'] as bool? ?? false,
      status: json['status'] as String?,
      friends:
          (json['friends'] as List<dynamic>?)?.map((e) => e as String).toList(),
      pendingRequests: (json['pendingRequests'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  @override
  String toString() {
    return 'UserProfile(uid: $uid, name: $name, email: $email, isCloseFriend: $isCloseFriend, status: $status, friends: ${friends.length}, pending: ${pendingRequests.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.uid == uid &&
        other.name == name &&
        other.email == email &&
        other.photoUrl == photoUrl &&
        other.isCloseFriend == isCloseFriend &&
        other.status == status &&
        listEquals(other.friends, friends) &&
        listEquals(other.pendingRequests, pendingRequests);
  }

  @override
  int get hashCode => Object.hash(
        uid,
        name,
        email,
        photoUrl,
        isCloseFriend,
        status,
        Object.hashAll(friends),
        Object.hashAll(pendingRequests),
      );
}
