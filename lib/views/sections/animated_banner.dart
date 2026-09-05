import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/app_theme.dart';

class AnimatedBanner extends StatefulWidget {
  const AnimatedBanner({super.key});

  @override
  State<AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  bool _isHovered = false;
  Offset _mouseOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatingOffset = sin(_floatController.value * pi) * 10;
        final scale = _isHovered ? 1.02 : 1.0;

        return MouseRegion(
          onEnter: (_) {
            if (mounted) setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (mounted) {
              setState(() {
                _isHovered = false;
                _mouseOffset = Offset.zero;
              });
            }
          },
          onHover: (event) {
            final renderObject = context.findRenderObject();
            if (renderObject is RenderBox) {
              final center = renderObject.size.center(Offset.zero);
              if (mounted) {
                setState(() {
                  _mouseOffset = event.localPosition - center;
                });
              }
            }
          },
          child: Transform(
            alignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_isHovered ? -_mouseOffset.dy * 0.0003 : 0)
              ..rotateY(_isHovered ? _mouseOffset.dx * 0.0003 : 0)
              ..setTranslationRaw(0.0, floatingOffset, 0.0)
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(
                        alpha: _isHovered ? 0.6 : 0.2,
                      ),
                      blurRadius: _isHovered ? 50 : 30,
                      spreadRadius: _isHovered ? 5 : 0,
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1 / 1,
                  child: ('assets/images/labomba_banner.png'.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: 'assets/images/labomba_banner.png',
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildFallbackBanner(),
                        )
                      : Image.asset(
                          'assets/images/labomba_banner.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => _buildFallbackBanner(),
                        )),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Center(
        child: Icon(Icons.celebration, size: 80, color: Colors.white),
      ),
    );
  }
}
