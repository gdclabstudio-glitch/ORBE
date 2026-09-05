import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/services/reaction_service.dart';

void main() {
  group('ReactionService (subcollection model)', () {
    late FakeFirebaseFirestore fake;
    late ReactionService service;

    setUp(() {
      fake = FakeFirebaseFirestore();
      service = ReactionService(firestore: fake);
    });

    test('toggleReactionOnPost adds then removes a reaction doc', () async {
      const postId = 'post1';
      const userId = 'user1';
      const emoji = '❤️';

      // initially empty
      var col = fake.collection('posts').doc(postId).collection('reactions');
      var snap = await col.get();
      expect(snap.docs, isEmpty);

      // add
      await service.toggleReactionOnPost(
        postId: postId,
        userId: userId,
        emoji: emoji,
      );
      snap = await col.get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['userId'], userId);
      expect(snap.docs.first.data()['type'], emoji);

      // remove
      await service.toggleReactionOnPost(
        postId: postId,
        userId: userId,
        emoji: emoji,
      );
      snap = await col.get();
      expect(snap.docs, isEmpty);
    });

    test('reactionsCountStream emits correct counts', () async {
      const postId = 'post2';
      const userA = 'uA';
      const userB = 'uB';
      const heart = '❤️';
      const fire = '🔥';

      final stream = service.reactionsCountStream(postId);
      final events = <Map<String, int>>[];
      final sub = stream.listen((e) => events.add(Map<String, int>.from(e)));

      // add two different reactions
      await service.toggleReactionOnPost(
        postId: postId,
        userId: userA,
        emoji: heart,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await service.toggleReactionOnPost(
        postId: postId,
        userId: userB,
        emoji: fire,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // we expect at least one event with both counts present (order of arrival may vary)
      expect(events.any((m) => (m[heart] == 1 && m[fire] == 1)), isTrue);

      await sub.cancel();
    });
  });
}
