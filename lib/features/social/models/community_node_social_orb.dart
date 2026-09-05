import 'community_node.dart';
import 'interaction_score.dart';
import 'orb_position.dart';
import 'orb_relationship.dart';
import 'orb_type.dart';
import 'social_orb.dart';

extension CommunityNodeSocialOrb on CommunityNode {
  SocialOrb toSocialOrb() {
    return SocialOrb(
      id: uid,
      type: OrbType.person,
      title: displayName,
      imageUrl: avatarUrl,
      score: InteractionScore(
        socialRelevance: interactionScore,
      ),
      position: OrbPosition(
        x: position.dx,
        y: position.dy,
        radius: size / 2,
        angle: rotation,
        distanceFromCenter: distance,
      ),
      relationship: isCurrentUser
          ? OrbRelationship.self
          : isCloseFriend
              ? OrbRelationship.closeFriend
              : OrbRelationship.unknown,
      activity: isOnline ? 1 : 0,
      metadata: <String, Object?>{
        'isOnline': isOnline,
        'hasStory': hasStory,
        'status': status,
        'seed': seed,
      },
    );
  }
}
