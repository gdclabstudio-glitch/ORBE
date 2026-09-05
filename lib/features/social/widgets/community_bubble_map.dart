import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../models/community_node.dart';
import '../models/community_node_social_orb.dart';
import '../services/community_layout_service.dart';
import 'community_bubble.dart';
import 'spatial_orb_simulation.dart';
import 'universe_backdrop_painter.dart';

class CommunityBubbleMap extends StatefulWidget {
  const CommunityBubbleMap({
    super.key,
    required this.nodes,
    required this.currentUserName,
    required this.currentUserAvatar,
    required this.onOpenProfile,
    this.onOpenUniverse,
  });

  final List<CommunityNode> nodes;
  final String currentUserName;
  final String? currentUserAvatar;
  final ValueChanged<String> onOpenProfile;
  final ValueChanged<CommunityNode>? onOpenUniverse;

  @override
  State<CommunityBubbleMap> createState() => _CommunityBubbleMapState();
}

class _CommunityBubbleMapState extends State<CommunityBubbleMap> {
  CommunityNode? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.nodes.length == 1) {
      _selected = widget.nodes.single;
    }
  }

  @override
  void didUpdateWidget(covariant CommunityBubbleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedUid = _selected?.uid;
    if (widget.nodes.length == 1) {
      _selected = widget.nodes.single;
      return;
    }
    if (selectedUid == null) return;

    CommunityNode? replacement;
    for (final node in widget.nodes) {
      if (node.uid == selectedUid) {
        replacement = node;
        break;
      }
    }
    _selected = replacement;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final positionedNodes = CommunityLayoutService.layoutNodes(
          nodes: widget.nodes,
          size: constraints.biggest,
        );
        return InteractiveViewer(
          minScale: 0.75,
          maxScale: 1.35,
          panEnabled: true,
          scaleEnabled: true,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0),
                        radius: 1,
                        colors: [
                          const Color(0xFF1B1D2E).withValues(alpha: 0.25),
                          LaBombaColors.obsidian.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: UniverseBackdropPainter()),
                  ),
                ),
                SpatialOrbSimulation(
                  orbs: positionedNodes
                      .map((node) => node.toSocialOrb())
                      .toList(),
                  builder: (context, orb) {
                    CommunityNode? node;
                    for (final candidate in positionedNodes) {
                      if (candidate.uid == orb.id) {
                        node = candidate;
                        break;
                      }
                    }
                    if (node == null) return const SizedBox.shrink();
                    final positionedNode = node.copyWith(
                      position: Offset(orb.position.x, orb.position.y),
                      size: orb.position.radius * 2,
                      distance: orb.position.distanceFromCenter,
                      rotation: orb.position.angle,
                    );
                    final isSelected = _selected?.uid == node.uid;
                    return CommunityBubble(
                      node: positionedNode,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selected = positionedNode),
                      onLongPress: () =>
                          setState(() => _selected = positionedNode),
                      onDoubleTap: widget.onOpenUniverse == null
                          ? null
                          : () => widget.onOpenUniverse!(positionedNode),
                    );
                  },
                ),
                if (_selected != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: _buildPreview(_selected!),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(CommunityNode node) {
    return Container(
      key: ValueKey(node.uid),
      margin: const EdgeInsets.only(bottom: 18),
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LaBombaColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LaBombaColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A0D1725),
            blurRadius: 20,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: LaBombaColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: node.avatarUrl != null &&
                          node.avatarUrl!.trim().isNotEmpty
                      ? Image.network(node.avatarUrl!, fit: BoxFit.cover)
                      : Container(
                          color: LaBombaColors.surfaceElevated,
                          alignment: Alignment.center,
                          child: Text(
                            node.displayName.isNotEmpty
                                ? node.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: LaBombaColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: const TextStyle(
                        color: LaBombaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@${node.displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                      style: const TextStyle(
                        color: LaBombaColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar pré-visualização',
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.close_rounded,
                    color: LaBombaColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: node.isOnline
                      ? LaBombaColors.success
                      : LaBombaColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                node.isOnline ? 'Online agora' : 'Disponível',
                style: const TextStyle(
                  color: LaBombaColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (node.isCurrentUser || node.isCloseFriend) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                node.isCurrentUser ? 'Seu centro' : 'Close friend',
                style: const TextStyle(
                  color: LaBombaColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (node.status != null && node.status!.trim().isNotEmpty)
            Text(
              node.status!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LaBombaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: LaBombaColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => widget.onOpenProfile(node.uid),
              child: const Text('Ver perfil'),
            ),
          ),
        ],
      ),
    );
  }
}
