import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/orb_relationship.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/orb_universe.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/views/orb_universe_page.dart';
import 'package:labomba_app/features/social/widgets/orb_renderer.dart';
import 'package:labomba_app/features/social/widgets/spatial_orb_simulation.dart';

void main() {
  testWidgets('renders an empty universe and returns to its caller',
      (tester) async {
    final universe = OrbUniverse.personal(
      center: const SocialOrb(
        id: 'me',
        type: OrbType.person,
        title: 'Meu Universo',
        relationship: OrbRelationship.self,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => OrbUniversePage(initialUniverse: universe),
                ),
              ),
              child: const Text('Abrir universo'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir universo'));
    await tester.pumpAndSettle();
    expect(find.text('Meu Universo'), findsNWidgets(3));
    expect(find.text('Seu universo ainda está começando.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Abrir universo'), findsOneWidget);
  });

  testWidgets('simulates and selects contextual orbs', (tester) async {
    final universe = OrbUniverse.personal(
      center: const SocialOrb(
        id: 'me',
        type: OrbType.person,
        title: 'Meu Universo',
        relationship: OrbRelationship.self,
      ),
      orbs: const [
        SocialOrb(id: 'friend', type: OrbType.person, title: 'Friend'),
        SocialOrb(id: 'topic', type: OrbType.topic, title: 'Topic'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: OrbUniversePage(initialUniverse: universe)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SpatialOrbSimulation), findsOneWidget);
    expect(find.byType(OrbRenderer), findsNWidgets(2));

    await tester.tap(find.byType(OrbRenderer).first);
    await tester.pump();
    expect(find.byType(OrbRenderer), findsNWidgets(2));
  });

  testWidgets(
      'keeps contextual selection local when no child universe contract exists',
      (tester) async {
    final universe = OrbUniverse.personal(
      center: const SocialOrb(
        id: 'me',
        type: OrbType.person,
        title: 'Meu Universo',
        relationship: OrbRelationship.self,
      ),
      orbs: const [
        SocialOrb(id: 'topic', type: OrbType.topic, title: 'Topic'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: OrbUniversePage(initialUniverse: universe)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byType(OrbRenderer));
    await tester.pump();

    expect(find.byTooltip('Voltar ao universo anterior'), findsNothing);
    expect(find.text('Dentro de Meu Universo'), findsNothing);
  });
}
