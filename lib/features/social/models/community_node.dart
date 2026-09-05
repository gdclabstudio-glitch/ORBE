import 'package:flutter/material.dart';

class CommunityNode {
  const CommunityNode({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.isOnline,
    required this.isCloseFriend,
    required this.isCurrentUser,
    required this.hasStory,
    required this.status,
    required this.interactionScore,
    required this.normalizedScore,
    required this.size,
    required this.distance,
    required this.rotation,
    required this.position,
    required this.seed,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final bool isOnline;
  final bool isCloseFriend;
  final bool isCurrentUser;
  final bool hasStory;
  final String? status;
  final double interactionScore;
  final double normalizedScore;
  final double size;
  final double distance;
  final double rotation;
  final Offset position;
  final int seed;

  CommunityNode copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    bool? isCloseFriend,
    bool? isCurrentUser,
    bool? hasStory,
    String? status,
    double? interactionScore,
    double? normalizedScore,
    double? size,
    double? distance,
    double? rotation,
    Offset? position,
    int? seed,
  }) {
    return CommunityNode(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      isCloseFriend: isCloseFriend ?? this.isCloseFriend,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      hasStory: hasStory ?? this.hasStory,
      status: status ?? this.status,
      interactionScore: interactionScore ?? this.interactionScore,
      normalizedScore: normalizedScore ?? this.normalizedScore,
      size: size ?? this.size,
      distance: distance ?? this.distance,
      rotation: rotation ?? this.rotation,
      position: position ?? this.position,
      seed: seed ?? this.seed,
    );
  }
}
