import 'orb_membership.dart';
import 'social_orb.dart';
import 'universe_type.dart';

class OrbUniverse {
  const OrbUniverse({
    required this.id,
    required this.type,
    required this.title,
    required this.center,
    this.subtitle,
    this.context,
    this.contextId,
    this.parentId,
    this.orbs = const <SocialOrb>[],
    this.memberships = const <OrbMembership>[],
    this.isActive = true,
  });

  final String id;
  final UniverseType type;
  final String title;
  final String? subtitle;
  final SocialOrb center;
  final String? context;
  final String? contextId;
  final String? parentId;
  final List<SocialOrb> orbs;
  final List<OrbMembership> memberships;
  final bool isActive;

  OrbUniverse copyWith({
    String? id,
    UniverseType? type,
    String? title,
    String? subtitle,
    SocialOrb? center,
    String? context,
    String? contextId,
    String? parentId,
    List<SocialOrb>? orbs,
    List<OrbMembership>? memberships,
    bool? isActive,
  }) {
    return OrbUniverse(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      center: center ?? this.center,
      context: context ?? this.context,
      contextId: contextId ?? this.contextId,
      parentId: parentId ?? this.parentId,
      orbs: List.unmodifiable(orbs ?? this.orbs),
      memberships: List.unmodifiable(memberships ?? this.memberships),
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isEmpty => orbs.isEmpty;

  bool get hasMultipleOrbs => orbs.length > 1;

  bool containsOrb(String orbId) =>
      center.id == orbId || orbs.any((orb) => orb.id == orbId);

  OrbMembership? membershipFor(String orbId) {
    for (final membership in memberships) {
      if (membership.orbId == orbId) return membership;
    }
    return null;
  }

  static OrbUniverse personal({
    required SocialOrb center,
    List<SocialOrb> orbs = const <SocialOrb>[],
    String title = 'Meu Universo',
    String? subtitle,
  }) {
    return OrbUniverse(
      id: center.id,
      type: UniverseType.personal,
      title: title,
      subtitle: subtitle,
      center: center,
      orbs: orbs,
    );
  }

  static OrbUniverse community({
    required SocialOrb center,
    required String communityId,
    required String title,
    String? subtitle,
    String? context,
    String? parentId,
    List<SocialOrb> orbs = const <SocialOrb>[],
    List<OrbMembership> memberships = const <OrbMembership>[],
  }) {
    return OrbUniverse(
      id: communityId,
      type: UniverseType.community,
      title: title,
      subtitle: subtitle,
      context: context,
      center: center,
      contextId: communityId,
      parentId: parentId,
      orbs: orbs,
      memberships: memberships,
    );
  }

  static OrbUniverse topic({
    required SocialOrb center,
    required String topicId,
    required String title,
    String? subtitle,
    String? context,
    String? parentId,
    List<SocialOrb> orbs = const <SocialOrb>[],
    List<OrbMembership> memberships = const <OrbMembership>[],
  }) {
    return OrbUniverse(
      id: topicId,
      type: UniverseType.topic,
      title: title,
      subtitle: subtitle,
      context: context,
      center: center,
      contextId: topicId,
      parentId: parentId,
      orbs: orbs,
      memberships: memberships,
    );
  }

  static OrbUniverse group({
    required SocialOrb center,
    required String groupId,
    required String title,
    String? subtitle,
    String? context,
    String? parentId,
    List<SocialOrb> orbs = const <SocialOrb>[],
    List<OrbMembership> memberships = const <OrbMembership>[],
  }) {
    return OrbUniverse(
      id: groupId,
      type: UniverseType.group,
      title: title,
      subtitle: subtitle,
      context: context,
      center: center,
      contextId: groupId,
      parentId: parentId,
      orbs: orbs,
      memberships: memberships,
    );
  }
}
