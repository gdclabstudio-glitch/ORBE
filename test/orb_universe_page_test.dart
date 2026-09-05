import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/orb_relationship.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/orb_universe.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/views/orb_universe_page.dart';

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
}
