import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/community/community_errors.dart';
import 'package:labomba_app/features/social/domain/community/community_pagination.dart';
import 'package:labomba_app/features/social/domain/community/membership_identity.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreCommunityRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreCommunityRepository(firestore: firestore);
  });

  test('maps community and embedded topic without leaking Firebase types',
      () async {
    await firestore.collection('communities').doc('physics').set({
      'name': ' Physics ',
      'description': 'A community',
      'topic': {'id': 'science', 'title': 'Science'},
    });

    final community = await repository.getCommunity('physics');

    expect(community?.id, 'physics');
    expect(community?.name, 'Physics');
    expect(community?.topic?.title, 'Science');
  });

  test('returns null for a missing community and rejects invalid ids',
      () async {
    expect(await repository.getCommunity('missing'), isNull);
    expect(
      () => repository.getCommunity(' '),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.invalidCommunity,
      )),
    );
  });

  test('maps membership timestamps, enums, and deterministic identity',
      () async {
    final id =
        MembershipIdentity.forPair(communityId: 'physics', userId: 'user-1');
    await firestore.collection('community_memberships').doc(id).set({
      'communityId': 'physics',
      'userId': 'user-1',
      'role': 'member',
      'status': 'active',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
    });

    final membership = await repository.getMembership(
      userId: 'user-1',
      communityId: 'physics',
    );

    expect(membership?.isActive, isTrue);
    expect(membership?.createdAt, DateTime.utc(2026, 1, 1));
    expect(await repository.isMember(userId: 'user-1', communityId: 'physics'),
        isTrue);
  });

  test('rejects incomplete membership documents', () async {
    final id =
        MembershipIdentity.forPair(communityId: 'physics', userId: 'user-1');
    await firestore.collection('community_memberships').doc(id).set({
      'communityId': 'physics',
      'userId': 'user-1',
      'role': 'not-a-role',
      'status': 'active',
    });

    expect(
      () => repository.getMembership(userId: 'user-1', communityId: 'physics'),
      throwsA(isA<CommunityError>().having(
        (error) => error.code,
        'code',
        CommunityErrorCode.invalidMembership,
      )),
    );
  });

  test('keeps community listing bounded and returns a cursor', () async {
    for (final name in ['Alpha', 'Beta', 'Gamma']) {
      await firestore.collection('communities').add({'name': name});
    }

    final first = await repository.listCommunities(
      page: const CommunityPageRequest(limit: 2),
    );
    final second = await repository.listCommunities(
      page: CommunityPageRequest(limit: 2, cursor: first.nextCursor),
    );

    expect(first.items.map((item) => item.name), ['Alpha', 'Beta']);
    expect(first.hasNextPage, isTrue);
    expect(second.items.map((item) => item.name), ['Gamma']);
    expect(second.hasNextPage, isFalse);
  });
}
