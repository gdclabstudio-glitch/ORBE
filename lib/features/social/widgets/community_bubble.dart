import 'package:flutter/material.dart';

import '../models/community_node_social_orb.dart';
import '../models/community_node.dart';
import 'orb_renderer.dart';

class CommunityBubble extends StatelessWidget {
  const CommunityBubble({
    super.key,
    required this.node,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  final CommunityNode node;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return OrbRenderer(
      orb: node.toSocialOrb(),
      isSelected: isSelected,
      isCenter: node.isCurrentUser,
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
    );
  }
}
