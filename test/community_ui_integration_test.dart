import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/community/community_errors.dart';
import 'package:labomba_app/features/social/domain/community/community_membership.dart';
import 'package:labomba_app/features/social/domain/community/community_pagination.dart';
import 'package:labomba_app/features/social/domain/community/community_read_service.dart';
import 'package:labomba_app/features/social/domain/community/community_write_service.dart';
import 'package:labomba_app/features/social/models/social_community.dart';
import 'package:labomba_app/features/social/models/social_topic.dart';
import 'package:labomba_app/features/social/presentation/community/community_ui_controller.dart';
import 'package:labomba_app/features/social/views/community_detail_page.dart';
import 'package:labomba_app/features/social/views/community_discovery_page.dart';

class _FakeCommunityReadService implements CommunityReadService {
  _FakeCommunityReadService({this.communities = const <SocialCommunity>[]});

  List<SocialCommunity> communities;
  Object? loadError;
  CommunityMembership? membership;
  List<CommunityMembership> memberItems = const [];
  Object? memberError;

  @override
  Future<SocialCommunity?> getCommunity(String communityId) async {
    for (final community in communities) {
      if (community.id == communityId) return community;
    }
    return null;
  }

  @override
  Future<CommunityPage<SocialCommunity>> listCommunities({
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    if (loadError != null) throw loadError!;
    return CommunityPage(items: communities);
  }

  @override
  Future<CommunityPage<SocialCommunity>> listUserCommunities({
    required String userId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async =>
      const CommunityPage(items: []);

  @override
  Future<bool> isMember({
    required String userId,
    required String communityId,
  }) async =>
      membership?.isActive == true;

  @override
  Future<CommunityMembership?> getMembership({
    required String userId,
    required String communityId,
  }) async =>
      membership;

  @override
  Future<CommunityPage<CommunityMembership>> listMembers({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    if (memberError != null) throw memberError!;
    return CommunityPage(items: memberItems);
  }

  @override
  Future<CommunityPage<SocialCommunity>> listCommunitiesByTopic({
    required String topicId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async =>
      CommunityPage(items: communities);
}

class _FakeCommunityWriteService implements CommunityWriteService {
  int createCalls = 0;
  int joinCalls = 0;
  Object? joinError;

  @override
  Future<SocialCommunity> createCommunity({
    required String name,
    String? description,
  }) async {
    createCalls++;
    return SocialCommunity(id: 'created', name: name, description: description);
  }

  @override
  Future<CommunityMembership> joinCommunity({
    required String communityId,
  }) async {
    joinCalls++;
    if (joinError != null) throw joinError!;
    return CommunityMembership(
      membershipId: '$communityId::alice',
      communityId: communityId,
      userId: 'alice',
      role: CommunityMemberRole.member,
      status: CommunityMembershipStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }
}

void main() {
  final community = const SocialCommunity(
    id: 'physics',
    name: 'Physics',
    description: 'Shared study',
  );

  Widget discovery({
    required _FakeCommunityReadService read,
    required _FakeCommunityWriteService write,
    String? userId = 'alice',
  }) {
    return MaterialApp(
      home: CommunityDiscoveryPage(
        key: UniqueKey(),
        readService: read,
        writeService: write,
        userId: userId,
      ),
    );
  }

  Widget detailWithMembership(CommunityMembershipStatus status) {
    final read = _FakeCommunityReadService()
      ..membership = CommunityMembership(
        membershipId: 'physics::alice',
        communityId: 'physics',
        userId: 'alice',
        role: CommunityMemberRole.member,
        status: status,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    final controller = CommunityUiController(
      readService: read,
      writeService: _FakeCommunityWriteService(),
      userId: 'alice',
    );
    return MaterialApp(
      key: UniqueKey(),
      home: CommunityDetailPage(
        community: community,
        controller: controller,
      ),
    );
  }

  testWidgets('discovers communities and joins from the detail view',
      (tester) async {
    final read = _FakeCommunityReadService(communities: [community]);
    final write = _FakeCommunityWriteService();
    await tester.pumpWidget(discovery(read: read, write: write));
    await tester.pumpAndSettle();

    expect(find.text('Physics'), findsOneWidget);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.text('Não membro'), findsOneWidget);

    await tester.tap(find.text('Entrar na comunidade'));
    await tester.pumpAndSettle();
    expect(write.joinCalls, 1);
    expect(find.text('Membro ativo'), findsOneWidget);
    expect(find.text('Entrar na comunidade'), findsNothing);
  });

  testWidgets('renders empty and error states', (tester) async {
    final write = _FakeCommunityWriteService();
    await tester.pumpWidget(
      discovery(read: _FakeCommunityReadService(), write: write),
    );
    await tester.pumpAndSettle();
    expect(
        find.text('Seu universo de comunidades está vazio.'), findsOneWidget);

    final failingRead = _FakeCommunityReadService()
      ..loadError = const CommunityError(
        CommunityErrorCode.unavailable,
        'offline',
      );
    await tester.pumpWidget(discovery(read: failingRead, write: write));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível conectar agora.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('shows real pending and blocked membership states',
      (tester) async {
    for (final status in <CommunityMembershipStatus>[
      CommunityMembershipStatus.pending,
      CommunityMembershipStatus.blocked,
      CommunityMembershipStatus.left,
    ]) {
      await tester.pumpWidget(detailWithMembership(status));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(status == CommunityMembershipStatus.pending
              ? 'pendente'
              : status == CommunityMembershipStatus.blocked
                  ? 'bloqueado'
                  : 'encerrada'),
          findsOneWidget);
    }
  });

  testWidgets('renders only active member Orbs and opens the real profile',
      (tester) async {
    final active = CommunityMembership(
      membershipId: 'physics::member',
      communityId: 'physics',
      userId: 'member',
      role: CommunityMemberRole.member,
      status: CommunityMembershipStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final inactive = active.copyWith(
      membershipId: 'physics::pending',
      userId: 'pending',
      status: CommunityMembershipStatus.pending,
    );
    final read = _FakeCommunityReadService()..memberItems = [active, inactive];
    final controller = CommunityUiController(
      readService: read,
      writeService: _FakeCommunityWriteService(),
      userId: 'alice',
    );
    await tester.pumpWidget(MaterialApp(
      home: CommunityDetailPage(community: community, controller: controller),
      routes: {
        '/profile/member': (_) => const Scaffold(body: Text('Member profile')),
      },
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Abrir perfil do membro'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Abrir perfil do membro'));
    await tester.pumpAndSettle();
    expect(find.text('Member profile'), findsOneWidget);
  });

  testWidgets('keeps real topics visible when member loading fails',
      (tester) async {
    const topicCommunity = SocialCommunity(
      id: 'physics',
      name: 'Physics',
      topic: SocialTopic(id: 'science', title: 'Science'),
    );
    final read = _FakeCommunityReadService()
      ..memberError = const CommunityError(
        CommunityErrorCode.forbidden,
        'members unavailable',
      );
    final controller = CommunityUiController(
      readService: read,
      writeService: _FakeCommunityWriteService(),
      userId: 'alice',
    );
    await tester.pumpWidget(MaterialApp(
      home: CommunityDetailPage(
        community: topicCommunity,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Science'), findsOneWidget);
    expect(
      find.text(
        'Os membros desta comunidade não estão disponíveis para visualização.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('validates create and submits only once', (tester) async {
    final write = _FakeCommunityWriteService();
    await tester.pumpWidget(
      discovery(read: _FakeCommunityReadService(), write: write),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Criar comunidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pump();
    expect(find.text('Informe um nome.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'New community');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pumpAndSettle();
    expect(write.createCalls, 1);
    expect(find.text('New community'), findsOneWidget);
  });
}
