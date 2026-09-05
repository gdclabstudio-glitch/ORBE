import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/interaction_score.dart';
import 'package:labomba_app/features/social/models/orb_relationship.dart';
import 'package:labomba_app/features/social/models/orb_position.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/widgets/spatial_orb_simulation.dart';

SocialOrb simulationOrb({
  required String title,
  double score = 20,
  double angle = 0.5,
}) {
  return SocialOrb(
    id: 'orb',
    type: OrbType.person,
    title: title,
    score: InteractionScore(socialRelevance: score),
    relationship: OrbRelationship.unknown,
    position: OrbPosition(angle: angle),
    metadata: const <String, Object?>{'seed': 7},
  );
}

void main() {
  testWidgets('synchronizes visual changes without rebuilding the simulation',
      (tester) async {
    final frames = <SocialOrb>[];
    var currentOrb = simulationOrb(title: 'Before');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: StatefulBuilder(
            builder: (context, setState) => SpatialOrbSimulation(
              orbs: [currentOrb],
              onFrame: (orbs) => frames.add(orbs.last),
              builder: (_, orb) => Text(orb.title ?? ''),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    currentOrb = simulationOrb(title: 'After');
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: SpatialOrbSimulation(
            orbs: [currentOrb],
            onFrame: (orbs) => frames.add(orbs.last),
            builder: (_, orb) => Text(orb.title ?? ''),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('After'), findsOneWidget);
    expect(frames.last.title, 'After');
  });

  testWidgets('keeps orbital movement continuous across elapsed time',
      (tester) async {
    final frames = <SocialOrb>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: SpatialOrbSimulation(
            orbs: [simulationOrb(title: 'Orbit')],
            onFrame: (orbs) => frames.add(orbs.last),
            builder: (_, orb) => SizedBox(
              key: ValueKey(orb.position.x),
              width: 40,
              height: 40,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16000));
    final before = frames.last.position;
    await tester.pump(const Duration(milliseconds: 40));
    final after = frames.last.position;

    expect(after.x, isNot(before.x));
    expect(after.y, isNot(before.y));
  });
}
