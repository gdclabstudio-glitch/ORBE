import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/community_node.dart';
import 'package:labomba_app/features/social/widgets/community_bubble.dart';
import 'package:labomba_app/features/social/widgets/community_bubble_map.dart';

CommunityNode node(String uid, String name) {
  return CommunityNode(
    uid: uid,
    displayName: name,
    avatarUrl: null,
    isOnline: true,
    isCloseFriend: false,
    isCurrentUser: false,
    hasStory: false,
    status: null,
    interactionScore: 50,
    normalizedScore: 0.5,
    size: 50,
    distance: 100,
    rotation: 0,
    position: Offset.zero,
    seed: uid.hashCode,
  );
}

Widget mapFor(List<CommunityNode> nodes) {
  return MaterialApp(
    home: SizedBox(
      width: 360,
      height: 640,
      child: CommunityBubbleMap(
        nodes: nodes,
        currentUserName: 'Me',
        currentUserAvatar: null,
        onOpenProfile: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('clears preview when the selected node disappears',
      (tester) async {
    await tester.pumpWidget(mapFor([node('friend', 'Friend')]));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byType(CommunityBubble));
    await tester.pump();

    expect(find.text('Ver perfil'), findsOneWidget);

    await tester.pumpWidget(mapFor(const []));
    await tester.pump();

    expect(find.text('Ver perfil'), findsNothing);
  });
}
