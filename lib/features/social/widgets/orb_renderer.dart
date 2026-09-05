import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../models/orb_relationship.dart';
import '../models/orb_type.dart';
import '../models/social_orb.dart';

class OrbRenderer extends StatelessWidget {
  const OrbRenderer({
    super.key,
    required this.orb,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.isCenter = false,
  });

  final SocialOrb orb;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final bool isCenter;

  @override
  Widget build(BuildContext context) {
    final size = _visualSize;
    final glowColor = _glowColor;
    final opacity = (0.82 + orb.position.scale * 0.18).clamp(0.82, 1.0);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Semantics(
        label: _semanticLabel,
        button: true,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: opacity,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            scale: isSelected ? 1.12 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: size + (isCenter ? 10 : 0),
              height: size + (isCenter ? 10 : 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size + (isCenter ? 28 : 12),
                    height: size + (isCenter ? 28 : 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          glowColor.withValues(alpha: isCenter ? 0.16 : 0.12),
                    ),
                  ),
                  Container(
                    width: size + (isCenter ? 6 : 0),
                    height: size + (isCenter ? 6 : 0),
                    decoration: _decoration(glowColor),
                    child: ClipOval(child: _content(size)),
                  ),
                  if (_isOnline)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: LaBombaColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LaBombaColors.obsidian,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (_hasStory)
                    Positioned(
                      top: 1,
                      left: 1,
                      child: Container(
                        width: size + 8,
                        height: size + 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isCloseFriend
                                ? LaBombaColors.success
                                : LaBombaColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (_isCloseFriend && !isCenter)
                    const Positioned(
                      right: -2,
                      top: 0,
                      child: _TypeBadge(icon: Icons.favorite_rounded),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double get _visualSize =>
      (orb.position.radius > 0 ? orb.position.radius * 2 : 38)
          .clamp(38, 80)
          .toDouble();

  bool get _isOnline => orb.metadata['isOnline'] == true;
  bool get _hasStory => orb.metadata['hasStory'] == true;
  bool get _isCloseFriend => orb.relationship == OrbRelationship.closeFriend;

  Color get _glowColor => _isCloseFriend
      ? LaBombaColors.success.withValues(alpha: 0.8)
      : isCenter
          ? LaBombaColors.primary
          : LaBombaColors.digitalBlue;

  BoxDecoration _decoration(Color glowColor) {
    final isPerson = orb.type == OrbType.person;
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: isCenter
          ? const LinearGradient(
              colors: [LaBombaColors.primary, LaBombaColors.digitalBlue],
            )
          : isPerson
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B2430), Color(0xFF0E1720)],
                )
              : LinearGradient(
                  colors: [
                    glowColor.withValues(alpha: 0.75),
                    LaBombaColors.surfaceElevated,
                  ],
                ),
      border: Border.all(
        color: isSelected ? glowColor : LaBombaColors.borderSoft,
        width: isSelected ? 2.5 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: isCenter ? 0.4 : 0.22),
          blurRadius: isSelected ? 28 : 16,
          spreadRadius: isSelected ? 4 : 0,
        ),
      ],
    );
  }

  Widget _content(double size) {
    if (orb.imageUrl != null && orb.imageUrl!.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: orb.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _typeFallback(),
      );
    }
    return _typeFallback();
  }

  Widget _typeFallback() {
    final label = orb.title?.trim() ?? '';
    final icon = _typeIcon(orb.type);
    return Container(
      color: LaBombaColors.surfaceElevated,
      alignment: Alignment.center,
      child: icon == null
          ? Text(
              label.isEmpty ? '?' : label[0].toUpperCase(),
              style: const TextStyle(
                color: LaBombaColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            )
          : Icon(icon, color: LaBombaColors.textPrimary, size: 24),
    );
  }

  Widget _placeholder() => const ColoredBox(
        color: LaBombaColors.surface,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );

  String get _semanticLabel {
    final title =
        orb.title?.trim().isNotEmpty == true ? orb.title! : 'sem título';
    final type = _typeName(orb.type);
    return isCenter ? '$type: $title, centro do universo' : '$type: $title';
  }

  IconData? _typeIcon(OrbType type) {
    switch (type) {
      case OrbType.video:
        return Icons.play_arrow_rounded;
      case OrbType.music:
        return Icons.music_note_rounded;
      case OrbType.conversation:
        return Icons.forum_rounded;
      case OrbType.group:
        return Icons.groups_rounded;
      case OrbType.community:
        return Icons.public_rounded;
      case OrbType.topic:
        return Icons.auto_awesome_rounded;
      case OrbType.event:
        return Icons.event_rounded;
      case OrbType.image:
        return Icons.image_rounded;
      case OrbType.story:
        return Icons.auto_awesome_rounded;
      case OrbType.content:
        return Icons.article_rounded;
      case OrbType.person:
        return null;
    }
  }

  String _typeName(OrbType type) {
    switch (type) {
      case OrbType.person:
        return 'Pessoa';
      case OrbType.image:
        return 'Foto';
      case OrbType.video:
        return 'Vídeo';
      case OrbType.story:
        return 'Story';
      case OrbType.music:
        return 'Música';
      case OrbType.conversation:
        return 'Conversa';
      case OrbType.group:
        return 'Grupo';
      case OrbType.community:
        return 'Comunidade';
      case OrbType.topic:
        return 'Tópico';
      case OrbType.event:
        return 'Evento';
      case OrbType.content:
        return 'Conteúdo';
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: LaBombaColors.success,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}
