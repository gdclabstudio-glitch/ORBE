import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/community/community_errors.dart';
import 'package:labomba_app/features/social/domain/community/community_membership.dart';
import 'package:labomba_app/features/social/domain/community/community_pagination.dart';
import 'package:labomba_app/features/social/domain/community/membership_identity.dart';

void main() {
  group('CommunityMembership', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final updatedAt = DateTime.utc(2026, 1, 2);

    test('creates a valid immutable domain value', () {
      final membership = CommunityMembership(
        membershipId: 'community::user',
        communityId: 'community',
        userId: 'user',
        role: CommunityMemberRole.member,
        status: CommunityMembershipStatus.active,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(membership.isActive, isTrue);
      expect(membership.role, CommunityMemberRole.member);
      expect(membership.status, CommunityMembershipStatus.active);
    });

    test('rejects empty identities', () {
      expect(
        () => CommunityMembership(
          membershipId: '',
          communityId: 'community',
          userId: 'user',
          role: CommunityMemberRole.member,
          status: CommunityMembershipStatus.pending,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => CommunityMembership(
          membershipId: 'membership',
          communityId: ' ',
          userId: 'user',
          role: CommunityMemberRole.member,
          status: CommunityMembershipStatus.pending,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => CommunityMembership(
          membershipId: 'membership',
          communityId: 'community',
          userId: '',
          role: CommunityMemberRole.member,
          status: CommunityMembershipStatus.pending,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects incoherent timestamps', () {
      expect(
        () => CommunityMembership(
          membershipId: 'membership',
          communityId: 'community',
          userId: 'user',
          role: CommunityMemberRole.member,
          status: CommunityMembershipStatus.active,
          createdAt: updatedAt,
          updatedAt: createdAt,
        ),
        throwsArgumentError,
      );
    });

    test('preserves values through copyWith', () {
      final membership = CommunityMembership(
        membershipId: 'membership',
        communityId: 'community',
        userId: 'user',
        role: CommunityMemberRole.member,
        status: CommunityMembershipStatus.pending,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final active = membership.copyWith(
        status: CommunityMembershipStatus.active,
      );

      expect(active.membershipId, membership.membershipId);
      expect(active.status, CommunityMembershipStatus.active);
    });
  });

  group('MembershipIdentity', () {
    test('is deterministic and distinguishes encoded pairs', () {
      final first = MembershipIdentity.forPair(
        communityId: 'physics',
        userId: 'user/1',
      );
      final same = MembershipIdentity.forPair(
        communityId: 'physics',
        userId: 'user/1',
      );
      final different = MembershipIdentity.forPair(
        communityId: 'physics/user',
        userId: '1',
      );

      expect(first, same);
      expect(first, isNot(different));
      expect(first, contains('::'));
    });

    test('rejects empty pair components', () {
      expect(
        () => MembershipIdentity.forPair(communityId: '', userId: 'user'),
        throwsArgumentError,
      );
      expect(
        () => MembershipIdentity.forPair(communityId: 'community', userId: ' '),
        throwsArgumentError,
      );
    });
  });

  test('keeps pagination framework-independent and bounded by contract', () {
    const page = CommunityPage<String>(items: ['one'], nextCursor: 'next');
    const request = CommunityPageRequest(limit: 25, cursor: 'cursor');

    expect(page.hasNextPage, isTrue);
    expect(page.items, ['one']);
    expect(request.limit, 25);
    expect(request.cursor, 'cursor');
    expect(() => CommunityPageRequest(limit: 0), throwsAssertionError);
    expect(() => CommunityPageRequest(limit: 101), throwsAssertionError);
  });

  test('exposes small extensible contract errors', () {
    const error = CommunityError(
      CommunityErrorCode.forbidden,
      'Access denied',
    );

    expect(error.code, CommunityErrorCode.forbidden);
    expect(error.toString(), contains('Access denied'));
  });
}
