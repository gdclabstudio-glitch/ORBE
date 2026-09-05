import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/app_theme.dart';

TextStyle _labombaTextStyle({
  Color? color,
  FontWeight? fontWeight,
  double? fontSize,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontWeight: fontWeight,
    fontSize: fontSize,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class GallerySection extends StatefulWidget {
  const GallerySection({super.key});

  @override
  State<GallerySection> createState() => _GallerySectionState();
}

class _GallerySectionState extends State<GallerySection> {
  late final PageController _pageController;

  final List<String> _images = [
    'assets/images/2022.jpg',
    'assets/images/2023.jpg',
    'assets/images/2024.jpg',
    'assets/images/2025.jpg',
    'assets/images/2026.jpg',
  ];

  final List<String> _years = ['2022', '2023', '2024', '2025', '2026'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75, initialPage: 2);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        Text(
          'EDIÇÕES ANTERIORES',
          style: _labombaTextStyle(
            color: AppTheme.primaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Arraste para relembrar',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: isMobile ? 300 : 350,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page! - index).abs();
                    value = (1 - value * 0.3).clamp(0.0, 1.0);
                  } else {
                    value = index == 2 ? 1.0 : 0.7;
                  }

                  double rotationY = 0;
                  if (_pageController.position.haveDimensions) {
                    rotationY = (_pageController.page! - index) * 0.4;
                  }

                  return Center(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..multiply(Matrix4.diagonal3Values(1.05, 1.05, 1.0))
                        ..setEntry(3, 2, 0.002)
                        ..rotateY(-rotationY)
                        ..multiply(Matrix4.diagonal3Values(value, value, 1.0)),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: value.clamp(0.4, 1.0),
                        child: _GalleryItem(
                          imagePath: _images[index],
                          year: _years[index],
                          index: index,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final int index;
  final String imagePath;
  final String year;

  const _GalleryItem({
    required this.index,
    required this.imagePath,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final gradients = [
      [AppTheme.primary, const Color(0xFF2D1B69)],
      [AppTheme.pink, AppTheme.primary],
      [const Color(0xFF22D3EE), const Color(0xFF3B82F6)],
      [AppTheme.accent, const Color(0xFFF97316)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
    ];
    final gradient = gradients[index % gradients.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            (imagePath.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  )
                : Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  )),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              child: Text(
                'LaBomba\n$year',
                style: _labombaTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
