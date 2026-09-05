import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../services/street_mode_service.dart';

class LaBombaExplosionOverlay extends StatefulWidget {
  final String message;
  final VoidCallback? onFinished;
  final bool soundEnabled;
  final bool visualEnabled;
  final bool hapticEnabled;
  final bool reducedMotion;

  const LaBombaExplosionOverlay({
    super.key,
    this.message = 'LA BOMBA!',
    this.onFinished,
    this.soundEnabled = true,
    this.visualEnabled = true,
    this.hapticEnabled = true,
    this.reducedMotion = false,
  });

  static Future<void> show(
    BuildContext context, {
    String message = 'LA BOMBA!',
  }) async {
    final storage = context.read<StorageService>();
    final soundEnabled =
        await storage.read(key: 'settings_alert_sound') != 'false';
    final visualEnabled =
        await storage.read(key: 'settings_alert_visual') != 'false';
    final hapticEnabled =
        await storage.read(key: 'settings_alert_haptic') != 'false';
    final streetMode = await storage.read(key: StreetModeService.key) == 'true';
    if ((!visualEnabled || streetMode) && !soundEnabled && !hapticEnabled)
      return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => LaBombaExplosionOverlay(
        message: message,
        soundEnabled: soundEnabled,
        visualEnabled: visualEnabled,
        hapticEnabled: hapticEnabled,
        reducedMotion: streetMode,
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    entry.remove();
  }

  @override
  State<LaBombaExplosionOverlay> createState() =>
      _LaBombaExplosionOverlayState();
}

class _LaBombaExplosionOverlayState extends State<LaBombaExplosionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.reducedMotion ? 550 : 1100),
    )..forward();
    if (widget.soundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
    if (widget.hapticEnabled) {
      HapticFeedback.mediumImpact();
    }
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visualEnabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutBack,
            ).value;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.deepPurple.withValues(
                    alpha: (1 - _controller.value) * .58,
                  ),
                ),
                Center(
                  child: Transform.scale(
                    scale: progress,
                    child: Transform.rotate(
                      angle: (1 - progress) * .25,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6A00), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.orangeAccent,
                              blurRadius: 35,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
