import 'package:flutter/material.dart';

import 'package:labomba_app/features/event/presentation/widgets/sections/header_section.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/animated_banner.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/countdown_section.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/ticket_section.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/event_info_section.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/gallery_section.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/rules_section.dart';
import 'package:labomba_app/features/event/presentation/widgets/sections/footer_section.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ValueNotifier<Offset> _pointerPositionNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );

  @override
  void dispose() {
    _pointerPositionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final contentMaxWidth = isCompact ? 560.0 : 850.0;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              'LABOMBA 2027',
              style: labombaTextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: isCompact ? 2 : 4,
              ),
            ),
            actions: [const SizedBox(width: 8)],
          ),
          body: Listener(
            onPointerHover: (event) {
              _pointerPositionNotifier.value = event.position;
            },
            onPointerMove: (event) {
              _pointerPositionNotifier.value = event.position;
            },
            child: ValueListenableBuilder<Offset>(
              valueListenable: _pointerPositionNotifier,
              builder: (context, pointerOffset, child) {
                return AnimatedCarnivalBackground(
                  pointerOffset: pointerOffset,
                  child: child!,
                );
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 16 : 20,
                        isCompact ? 90 : 120,
                        isCompact ? 16 : 20,
                        60,
                      ),
                      child: Column(
                        children: [
                          AnimatedBanner(),
                          SizedBox(height: 50),
                          HeaderSection(),
                          SizedBox(height: 50),
                          EventInfoSection(),
                          SizedBox(height: 50),
                          CountdownSection(),
                          SizedBox(height: 80),
                          GallerySection(),
                          SizedBox(height: 80),
                          TicketSection(),
                          SizedBox(height: 50),
                          RulesSection(),
                          SizedBox(height: 80),
                          FooterSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedCarnivalBackground extends StatelessWidget {
  const AnimatedCarnivalBackground({
    required this.pointerOffset,
    required this.child,
    super.key,
  });

  final Offset pointerOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CarnivalBackgroundPainter(pointerOffset),
      child: child,
    );
  }
}

class _CarnivalBackgroundPainter extends CustomPainter {
  const _CarnivalBackgroundPainter(this.pointerOffset);

  final Offset pointerOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2 + (pointerOffset.dx - size.width / 2) * 0.03,
      size.height / 2 + (pointerOffset.dy - size.height / 2) * 0.03,
    );
    final radius = (size.width > size.height ? size.width : size.height) * 0.8;
    final gradient = RadialGradient(
      colors: [Colors.deepPurple.shade900, Colors.black],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Offset.zero & size, Paint()..shader = gradient);
  }

  @override
  bool shouldRepaint(covariant _CarnivalBackgroundPainter oldDelegate) =>
      oldDelegate.pointerOffset != pointerOffset;
}
