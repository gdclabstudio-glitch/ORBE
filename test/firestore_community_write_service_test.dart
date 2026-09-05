import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:labomba_app/features/social/domain/community/community_errors.dart';
import 'package:labomba_app/features/social/domain/community/community_membership.dart';
import 'package:labomba_app/features/social/domain/community/membership_identity.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_write_service.dart';

void main() {
  test('creates community and owner membership in one write flow', () async {
    final firestore = FakeFirebaseFirestore();
    final service = FirestoreCommunityWriteService(
      firestore: firestore,
      currentUserId: () => 'alice',
    );

    final community = await service.createCommunity(
      name: ' Physics ',
      description: ' Shared study ',
    );
    final communitySnapshot =
        await firestore.collection('communities').doc(community.id).get();
    final membershipId = MembershipIdentity.forPair(
      communityId: community.id,
      userId: 'alice',
    );
    final membershipSnapshot = await firestore
        .collection('community_memberships')
        .doc(membershipId)
        .get();

    expect(community.name, 'Physics');
    expect(communitySnapshot.data(), containsPair('ownerId', 'alice'));
    expect(communitySnapshot.data(), containsPair('status', 'active'));
    expect(membershipSnapshot.data(), containsPair('role', 'owner'));
    expect(membershipSnapshot.data(), containsPair('status', 'active'));
    expect(membershipSnapshot.data(), containsPair('userId', 'alice'));
  });

  test('join is idempotent for an existing active membership', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('communities').doc('physics').set({
      'name': 'Physics',
      'ownerId': 'owner',
      'status': 'active',
    });
    final service = FirestoreCommunityWriteService(
      firestore: firestore,
      currentUserId: () => 'alice',
    );

    final first = await service.joinCommunity(communityId: 'physics');
    final second = await service.joinCommunity(communityId: 'physics');

    expect(first.membershipId, second.membershipId);
    expect(first.userId, 'alice');
    expect(first.isActive, isTrue);
    expect(
      (await firestore.collection('community_memberships').get()).docs,
      hasLength(1),
    );
  });

  test('concurrent joins converge to one consistent membership', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('communities').doc('physics').set({
      'name': 'Physics',
      'ownerId': 'owner',
      'status': 'active',
    });
    final service = FirestoreCommunityWriteService(
      firestore: firestore,
      currentUserId: () => 'alice',
    );

    final results = await Future.wait(
      List.generate(
        10,
        (_) => service.joinCommunity(communityId: 'physics'),
      ),
    );
    final documents = await firestore.collection('community_memberships').get();

    expect(results, hasLength(10));
    expect(results.every((membership) => membership.isActive), isTrue);
    expect(results.map((membership) => membership.membershipId).toSet(),
        hasLength(1));
    expect(documents.docs, hasLength(1));
    expect(documents.docs.single.data()['role'], 'member');
  });

  test('existing pending, blocked, and left memberships are not promoted',
      () async {
    final statuses = <CommunityMembershipStatus, CommunityErrorCode>{
      CommunityMembershipStatus.pending: CommunityErrorCode.conflict,
      CommunityMembershipStatus.blocked: CommunityErrorCode.forbidden,
      CommunityMembershipStatus.left: CommunityErrorCode.conflict,
    };

    for (final entry in statuses.entries) {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('communities').doc('physics').set({
        'name': 'Physics',
        'ownerId': 'owner',
        'status': 'active',
      });
      final membershipId =
          MembershipIdentity.forPair(communityId: 'physics', userId: 'alice');
      final now = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
      await firestore
          .collection('community_memberships')
          .doc(membershipId)
          .set({
        'communityId': 'physics',
        'userId': 'alice',
        'role': 'member',
        'status': entry.key.name,
        'createdAt': now,
        'updatedAt': now,
      });
      final service = FirestoreCommunityWriteService(
        firestore: firestore,
        currentUserId: () => 'alice',
      );

      expect(
        () => service.joinCommunity(communityId: 'physics'),
        throwsA(isA<CommunityError>().having(
          (error) => error.code,
          'code',
          entry.value,
        )),
      );
      final stored = await firestore
          .collection('community_memberships')
          .doc(membershipId)
          .get();
      expect(stored.data()!['status'], entry.key.name);
    }
  });

  test('requires an authenticated user and rejects missing communities',
      () async {
    final firestore = FakeFirebaseFirestore();
    final unauthenticated = FirestoreCommunityWriteService(
      firestore: firestore,
      currentUserId: () => null,
    );

    expect(
      () => unauthenticated.createCommunity(name: 'Physics'),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.unauthorized,
      )),
    );
    expect(
      () => unauthenticated.joinCommunity(communityId: 'missing'),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.unauthorized,
      )),
    );

    final authenticated = FirestoreCommunityWriteService(
      firestore: firestore,
      currentUserId: () => 'alice',
    );
    expect(
      () => authenticated.joinCommunity(communityId: 'missing'),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.notFound,
      )),
    );
  });
}
