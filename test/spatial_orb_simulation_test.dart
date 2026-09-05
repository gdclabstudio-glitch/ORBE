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
    await tester.pump(const Duration(milliseconds: 16));
    final beforeUpdate = frames.last;

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

    final afterUpdate = frames.last;
    expect(find.text('After'), findsOneWidget);
    expect(afterUpdate.title, 'After');
    expect(afterUpdate.id, beforeUpdate.id);
    expect(
      Offset(
        afterUpdate.position.x - beforeUpdate.position.x,
        afterUpdate.position.y - beforeUpdate.position.y,
      ).distance,
      greaterThan(0),
    );
    expect(
      Offset(afterUpdate.physics.velocityX, afterUpdate.physics.velocityY)
          .distance,
      greaterThan(0),
    );
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

  testWidgets('removes stale orbs and inserts new orbs without resetting peers',
      (tester) async {
    var currentOrbs = [
      simulationOrb(title: 'First').copyWith(id: 'first'),
      simulationOrb(title: 'Second').copyWith(
        id: 'second',
        position: const OrbPosition(angle: 1.4),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: StatefulBuilder(
            builder: (context, setState) => SpatialOrbSimulation(
              orbs: currentOrbs,
              builder: (_, orb) => Text(orb.title ?? ''),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    currentOrbs = [
      simulationOrb(title: 'First').copyWith(id: 'first'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: SpatialOrbSimulation(
            orbs: currentOrbs,
            builder: (_, orb) => Text(orb.title ?? ''),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);

    currentOrbs = [
      ...currentOrbs,
      simulationOrb(title: 'Third').copyWith(
        id: 'third',
        position: const OrbPosition(angle: 2.2),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: SpatialOrbSimulation(
            orbs: currentOrbs,
            builder: (_, orb) => Text(orb.title ?? ''),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
  });
}
