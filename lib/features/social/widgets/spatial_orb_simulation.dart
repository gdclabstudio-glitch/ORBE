import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/social_orb.dart';
import '../services/community_layout_service.dart';
import '../services/orb_physics_engine.dart';

typedef SpatialOrbBuilder = Widget Function(
  BuildContext context,
  SocialOrb orb,
);

class SpatialOrbSimulation extends StatefulWidget {
  const SpatialOrbSimulation({
    super.key,
    required this.orbs,
    required this.builder,
    this.onFrame,
  });

  final List<SocialOrb> orbs;
  final SpatialOrbBuilder builder;
  final ValueChanged<List<SocialOrb>>? onFrame;

  @override
  State<SpatialOrbSimulation> createState() => _SpatialOrbSimulationState();
}

class _SpatialOrbSimulationState extends State<SpatialOrbSimulation>
    with SingleTickerProviderStateMixin {
  final OrbPhysicsEngine _physicsEngine = const OrbPhysicsEngine();
  late final Ticker _ticker;
  List<SocialOrb> _simulationOrbs = const [];
  String _simulationKey = '';
  Size _simulationSize = Size.zero;
  Duration? _lastElapsed;
  double _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SpatialOrbSimulation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _simulationKey = '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _ensureSimulation(size);
        final rendered = _simulationOrbs.toList()
          ..sort((a, b) => b.position.distanceFromCenter
              .compareTo(a.position.distanceFromCenter));
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final orb in rendered)
              Positioned(
                left: orb.position.x - orb.position.radius,
                top: orb.position.y - orb.position.radius,
                child: widget.builder(context, orb),
              ),
          ],
        );
      },
    );
  }

  void _ensureSimulation(Size size) {
    final key = widget.orbs.map(_inputKeyFor).join('|');
    if (key == _simulationKey &&
        size == _simulationSize &&
        _simulationOrbs.length == widget.orbs.length) {
      return;
    }
    _simulationKey = key;
    _simulationSize = size;
    final laidOut = CommunityLayoutService.layoutOrbs(
      orbs: widget.orbs,
      size: size,
    );
    final currentById = <String, SocialOrb>{
      for (final orb in _simulationOrbs) orb.id: orb,
    };
    _simulationOrbs = [
      for (final laidOutOrb in laidOut)
        currentById[laidOutOrb.id]?.copyWith(
              type: laidOutOrb.type,
              title: laidOutOrb.title,
              imageUrl: laidOutOrb.imageUrl,
              score: laidOutOrb.score,
              relationship: laidOutOrb.relationship,
              activity: laidOutOrb.activity,
              metadata: laidOutOrb.metadata,
            ) ??
            laidOutOrb,
    ];
  }

  void _onTick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null || _simulationSize == Size.zero) return;

    final frameDelta =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    if (frameDelta <= 0 || _simulationOrbs.isEmpty) return;

    var remaining = frameDelta.clamp(0, 0.25).toDouble();
    while (remaining > 0) {
      final step = remaining.clamp(0.001, 0.05).toDouble();
      _elapsedSeconds += step;
      _simulationOrbs = _physicsEngine.step(
        orbs: _simulationOrbs,
        size: _simulationSize,
        deltaSeconds: step,
        timeSeconds: _elapsedSeconds,
      );
      remaining -= step;
    }

    if (mounted) {
      setState(() {});
      widget.onFrame?.call(_simulationOrbs);
    }
  }

  String _inputKeyFor(SocialOrb orb) {
    return [
      orb.id,
      orb.type,
      orb.title,
      orb.imageUrl,
      orb.score.normalized,
      orb.relationship,
      orb.activity,
      orb.metadata,
    ].join(':');
  }
}
