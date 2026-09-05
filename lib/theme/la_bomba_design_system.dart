import 'package:flutter/material.dart';

class LaBombaColors {
  // Brand foundations
  static const Color obsidian = Color(0xFF080D10);
  static const Color obsidianSoft = Color(0xFF0E1318);
  static const Color background = obsidian;
  static const Color backgroundSoft = Color(0xFF0F1721);

  // Surfaces
  static const Color surface = Color(0xFF101A22);
  static const Color surfaceElevated = Color(0xFF141D28);
  static const Color card = Color(0xFF131C26);
  static const Color cardElevated = Color(0xFF18242D);

  // Text and borders
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFB7C4D4);
  static const Color textMuted = Color(0xFF7D8EA5);
  static const Color border = Color(0x29F5F7FA);
  static const Color borderSoft = Color(0x3D8CA2B8);

  // Base palette
  static const Color cloud = Color(0xFFF5F7FA);
  static const Color cloudSoft = Color(0xFFE8EDF3);
  static const Color slate = Color(0xFF64748B);
  static const Color slateSoft = Color(0xFF94A3B8);
  static const Color electricViolet = Color(0xFF7C3AED);
  static const Color violetBright = Color(0xFF9C7BFF);
  static const Color violetSoft = Color(0xFF2E1E4D);
  static const Color digitalBlue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFF60A5FA);
  static const Color magenta = Color(0xFFB026FF);
  static const Color pink = Color(0xFFEC4899);
  static const Color orange = Color(0xFFFF8A3D);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF3B43B);
  static const Color error = Color(0xFFF87171);

  // Legacy aliases for continuity with existing code
  static const Color midnight = obsidian;
  static const Color primary = electricViolet;
  static const Color primaryStrong = Color(0xFF5B2CCF);
  static const Color cyan = Color(0xFF4CC9F0);
  static const Color teal = success;
  static const Color rose = orange;
  static const Color white = cloud;
  static const Color shadow = Color(0x1E08121A);

  static const List<Color> premiumGradient = [
    electricViolet,
    digitalBlue,
  ];

  static const List<Color> accentGradient = [
    electricViolet,
    magenta,
  ];
}

class LaBombaTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    height: 1.08,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    height: 1.12,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.18,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.2,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: LaBombaColors.textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: LaBombaColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: LaBombaColors.textMuted,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.15,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: LaBombaColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    color: LaBombaColors.textMuted,
  );

  static const TextStyle headline = headlineLarge;
  static const TextStyle title = titleLarge;
  static const TextStyle body = bodyMedium;
}

class LaBombaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;
  static const double xhuge = 40;
  static const double giant = 48;
  static const double massive = 64;
}

class LaBombaRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double xLarge = 20;
  static const double xxLarge = 24;
  static const double pill = 999;

  static const double xs = small;
  static const double sm = medium;
  static const double md = large;
  static const double lg = xLarge;
  static const double xl = xxLarge;
}

class LaBombaElevation {
  static const double none = 0;
  static const double subtle = 4;
  static const double medium = 10;
  static const double floating = 18;
}

class LaBombaDecorations {
  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      LaBombaColors.obsidian,
      LaBombaColors.backgroundSoft,
      Color(0xFF0D1620),
    ],
  );

  static BoxDecoration get shell => const BoxDecoration(
        gradient: shellGradient,
      );

  static BoxDecoration get panel => BoxDecoration(
        color: LaBombaColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(LaBombaRadius.xLarge),
        border: Border.all(color: LaBombaColors.border),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F08131A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration get chip => BoxDecoration(
        color: LaBombaColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(LaBombaRadius.pill),
        border: Border.all(color: LaBombaColors.borderSoft),
      );

  static BoxDecoration get selectedChip => BoxDecoration(
        gradient: const LinearGradient(
          colors: [LaBombaColors.primary, LaBombaColors.digitalBlue],
        ),
        borderRadius: BorderRadius.circular(LaBombaRadius.pill),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D7C3AED),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      );
}

class LaBombaEmptyState extends StatelessWidget {
  const LaBombaEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.auto_awesome,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: LaBombaDecorations.panel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [LaBombaColors.primary, LaBombaColors.cyan],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x553f46e5),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 18),
              Text(title, style: LaBombaTypography.title),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: LaBombaTypography.body,
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LaBombaErrorState extends StatelessWidget {
  const LaBombaErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LaBombaEmptyState(
      icon: Icons.wifi_tethering_error_rounded,
      title: title,
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        style: FilledButton.styleFrom(
          backgroundColor: LaBombaColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}

class LaBombaLoadingState extends StatelessWidget {
  const LaBombaLoadingState({super.key, this.label = 'Carregando...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [LaBombaColors.primary, LaBombaColors.cyan],
              ),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(label, style: LaBombaTypography.body),
        ],
      ),
    );
  }
}

class LaBombaSkeleton extends StatelessWidget {
  const LaBombaSkeleton({
    super.key,
    this.height = 18,
    this.width = double.infinity,
    this.radius = 12,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            LaBombaColors.cardElevated,
            LaBombaColors.surface,
            LaBombaColors.cardElevated,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? LaBombaColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(borderRadius ?? LaBombaRadius.lg),
        border:
            Border.all(color: LaBombaColors.borderSoft.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0A1220),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(LaBombaRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B1024),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.padding,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [LaBombaColors.primary, LaBombaColors.cyan],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553B82F6),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.subtitle,
  });

  final String title;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LaBombaTypography.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: LaBombaTypography.caption),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Buscar...',
    this.onChanged,
    this.prefixIcon = Icons.search_rounded,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final IconData prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: LaBombaColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: LaBombaColors.borderSoft.withValues(alpha: 0.5)),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: LaBombaColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: LaBombaColors.textMuted),
          prefixIcon: Icon(prefixIcon, color: LaBombaColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.radius = 30,
    this.isActive = false,
    this.onTap,
  });

  final String name;
  final String? avatar;
  final double radius;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = isActive
        ? const LinearGradient(
            colors: [
              LaBombaColors.primary,
              LaBombaColors.cyan,
              LaBombaColors.primary
            ],
          )
        : null;

    final avatarWidget = Container(
      padding: const EdgeInsets.all(3),
      decoration: border != null
          ? BoxDecoration(
              gradient: border,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x553B82F6),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: LaBombaColors.surface,
        backgroundImage: avatar != null ? NetworkImage(avatar!) : null,
        child: avatar == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: LaBombaColors.textPrimary,
                ),
              )
            : null,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatarWidget,
          const SizedBox(height: 8),
          SizedBox(
            width: radius * 2.4,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: LaBombaColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusArc extends StatelessWidget {
  const StatusArc({
    super.key,
    required this.items,
  });

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final positions = [0.12, 0.28, 0.44, 0.61, 0.78, 0.94];
    return SizedBox(
      height: 132,
      child: CustomPaint(
        painter: _ArcPainter(),
        child: Stack(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final size = index == 3 ? 64.0 : (index % 2 == 0 ? 48.0 : 54.0);
            final left = index < 3 ? (index + 1) * 48.0 : (index - 2) * 52.0;
            final top = 28 + (positions[index % positions.length] * 52);
            return Positioned(
              left: left,
              top: top,
              child: Transform.scale(
                scale: index == 3 ? 1.08 : 1.0,
                child: SizedBox(
                  width: size + 16,
                  height: size + 26,
                  child: item,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          LaBombaColors.primary,
          LaBombaColors.cyan,
          LaBombaColors.primary
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.2,
        size.width * 0.38,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.08,
        size.width * 0.62,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.2,
        size.width * 0.9,
        size.height * 0.7,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedLikeButton extends StatefulWidget {
  const AnimatedLikeButton({
    super.key,
    required this.liked,
    required this.onTap,
    this.count = 0,
  });

  final bool liked;
  final VoidCallback onTap;
  final int count;

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.9,
      upperBound: 1.12,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: widget.liked
                    ? LaBombaColors.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.liked
                        ? LaBombaColors.primary
                        : LaBombaColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: widget.liked
                          ? LaBombaColors.primary
                          : LaBombaColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
