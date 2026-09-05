import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/views/community_page.dart';
import 'package:labomba_app/features/social/widgets/community_bubble_map.dart';

void main() {
  group('CommunityPage widget', () {
    late FakeFirebaseFirestore fake;

    setUp(() async {
      fake = FakeFirebaseFirestore();
      await fake.collection('users').doc('u1').set({
        'displayName': 'Alice',
        'photoURL': null,
        'presence': 'online',
        'tags': ['samba'],
      });
      await fake.collection('users').doc('u2').set({
        'displayName': 'Bruno',
        'photoURL': null,
        'presence': 'away',
        'tags': ['samba', 'dance'],
      });
      await fake.collection('users').doc('u3').set({
        'displayName': 'Carla',
        'photoURL': null,
        'presence': 'offline',
        'tags': [],
      });
    });

    testWidgets(
        'renders the bubble universe and supports search/filter controls', (
      tester,
    ) async {
      final widget = MaterialApp(
        home: CommunityPage(firestore: fake),
        routes: {
          '/profile/u1': (_) => const Scaffold(body: Text('Profile u1')),
          '/profile/u2': (_) => const Scaffold(body: Text('Profile u2')),
        },
      );

      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(CommunityBubbleMap), findsOneWidget);
      expect(find.text('Encontrar pessoas'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Bruno');
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('Encontrar pessoas'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
    });
  });
}
