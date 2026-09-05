import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../models/community_node.dart';
import '../models/community_node_social_orb.dart';
import '../models/social_orb.dart';
import '../services/community_layout_service.dart';
import '../services/orb_physics_engine.dart';
import 'community_bubble.dart';
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

class _CommunityBubbleMapState extends State<CommunityBubbleMap>
    with SingleTickerProviderStateMixin {
  CommunityNode? _selected;
  late final AnimationController _animationController;
  final OrbPhysicsEngine _physicsEngine = const OrbPhysicsEngine();
  List<SocialOrb> _simulationOrbs = const [];
  String _simulationKey = '';
  Size _simulationSize = Size.zero;
  bool _physicsFailed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final positionedNodes = CommunityLayoutService.layoutNodes(
          nodes: widget.nodes,
          size: constraints.biggest,
        );
        _ensureSimulation(positionedNodes, constraints.biggest);

        return InteractiveViewer(
          minScale: 0.75,
          maxScale: 1.35,
          panEnabled: true,
          scaleEnabled: true,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final animatedNodes = _physicsFailed
                  ? positionedNodes
                  : _advanceSimulation(positionedNodes, constraints.biggest);
              final renderedNodes = animatedNodes.toList()
                ..sort((a, b) => b.distance.compareTo(a.distance));
              final selectedNode = _selected;

              return SizedBox(
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
                    ...renderedNodes.map((node) {
                      final isSelected =
                          _selected != null && _selected!.uid == node.uid;
                      return Positioned(
                        left: node.position.dx - (node.size / 2),
                        top: node.position.dy - (node.size / 2),
                        child: CommunityBubble(
                          node: node,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selected = node);
                          },
                          onLongPress: () {
                            setState(() => _selected = node);
                          },
                          onDoubleTap: widget.onOpenUniverse == null
                              ? null
                              : () => widget.onOpenUniverse!(node),
                        ),
                      );
                    }).toList(),
                    if (selectedNode != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: _buildPreview(selectedNode),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _ensureSimulation(List<CommunityNode> nodes, Size size) {
    final key = nodes.map((node) => node.uid).join('|');
    if (key == _simulationKey && size == _simulationSize) return;

    _simulationKey = key;
    _simulationSize = size;
    _physicsFailed = false;
    if (_selected != null && !nodes.any((node) => node.uid == _selected!.uid)) {
      _selected = null;
    }

    if (nodes.length == 1) {
      _selected = nodes.single;
    }

    _simulationOrbs = CommunityLayoutService.layoutOrbs(
      orbs: nodes.map((node) => node.toSocialOrb()).toList(),
      size: size,
    );
  }


  List<CommunityNode> _advanceSimulation(
    List<CommunityNode> fallbackNodes,
    Size size,
  ) {
    try {
      _simulationOrbs = _physicsEngine.step(
        orbs: _simulationOrbs,
        size: size,
        timeSeconds: _animationController.value * 16,
      );
      final byId = <String, SocialOrb>{
        for (final orb in _simulationOrbs) orb.id: orb,
      };
      return [
        for (final node in fallbackNodes)
          _nodeWithOrbPosition(node, byId[node.uid]),
      ];
    } catch (_) {
      _physicsFailed = true;
      return fallbackNodes;
    }
  }

  CommunityNode _nodeWithOrbPosition(CommunityNode node, SocialOrb? orb) {
    if (orb == null) return node;
    return node.copyWith(
      position: Offset(orb.position.x, orb.position.y),
      size: orb.position.radius * 2,
      distance: orb.position.distanceFromCenter,
      rotation: orb.position.angle,
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
