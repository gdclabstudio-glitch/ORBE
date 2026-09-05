import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/orb_position.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/widgets/orb_renderer.dart';

SocialOrb fixture(OrbType type, {String title = 'Teste'}) => SocialOrb(
      id: type.name,
      type: type,
      title: title,
      position: const OrbPosition(radius: 28, scale: 1),
    );

void main() {
  testWidgets('renders a person orb with accessible identity', (tester) async {
    await tester.pumpWidget(
      _host(
        OrbRenderer(
          orb: fixture(OrbType.person, title: 'Joao'),
          isSelected: false,
          onTap: () {},
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    expect(find.text('J'), findsOneWidget);
    expect(tester.getSemantics(find.byType(OrbRenderer)).label,
        startsWith('Pessoa: Joao'));
    semantics.dispose();
  });

  testWidgets('renders content types with distinct fallback language',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Row(
          children: [
            OrbRenderer(
              orb: fixture(OrbType.image),
              isSelected: false,
              onTap: () {},
            ),
            OrbRenderer(
              orb: fixture(OrbType.video),
              isSelected: false,
              onTap: () {},
            ),
            OrbRenderer(
              orb: fixture(OrbType.group),
              isSelected: false,
              onTap: () {},
            ),
            OrbRenderer(
              orb: fixture(OrbType.community),
              isSelected: false,
              onTap: () {},
            ),
            OrbRenderer(
              orb: fixture(OrbType.topic),
              isSelected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    expect(find.byType(OrbRenderer), findsNWidgets(5));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('marks selected center separately', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        OrbRenderer(
          orb: fixture(OrbType.person, title: 'Centro'),
          isSelected: true,
          isCenter: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    await tester.tap(find.byType(OrbRenderer));
    expect(tapped, isTrue);
    expect(tester.getSemantics(find.byType(OrbRenderer)).label,
        startsWith('Pessoa: Centro, centro do universo'));
    semantics.dispose();
  });
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));
