import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../domain/community/community_errors.dart';
import '../domain/community/community_membership.dart';
import '../domain/content/community_content_repository.dart';
import '../models/orb_type.dart';
import '../models/social_community.dart';
import '../models/social_orb.dart';
import '../models/social_topic.dart';
import '../presentation/community/community_ui_controller.dart';
import '../projections/community_universe_projection.dart';
import 'orb_universe_page.dart';
import '../widgets/orb_renderer.dart';
import '../presentation/community/community_content_ui_controller.dart';
import 'community_content_pages.dart';
import 'community_moderation_page.dart';
import '../domain/content/community_moderation.dart';
import '../presentation/community/community_moderation_ui_controller.dart';

class CommunityDetailPage extends StatefulWidget {
  const CommunityDetailPage({
    super.key,
    required this.community,
    required this.controller,
    this.contentRepository,
    this.moderationRepository,
  });

  final SocialCommunity community;
  final CommunityUiController controller;
  final CommunityContentRepository? contentRepository;
  final CommunityModerationRepository? moderationRepository;

  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  late Future<void> _membershipLoad;
  late Future<void> _membersLoad;
  late final CommunityContentUiController? _contentController;
  late final CommunityModerationUiController? _moderationController;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _membershipLoad = _loadMembership();
    _membersLoad = Future<void>.delayed(
      Duration.zero,
      () => widget.controller.loadMembers(widget.community.id),
    );
    final contentRepository = widget.contentRepository;
    _contentController = contentRepository == null
        ? null
        : CommunityContentUiController(
            repository: contentRepository,
            userId: widget.controller.userId,
          );
    _contentController?.loadContents(widget.community.id);
    final moderationRepository = widget.moderationRepository;
    _moderationController = moderationRepository == null
        ? null
        : CommunityModerationUiController(
            repository: moderationRepository,
            userId: widget.controller.userId,
          );
  }

  @override
  void dispose() {
    _contentController?.dispose();
    _moderationController?.dispose();
    super.dispose();
  }

  Future<void> _loadMembership() async {
    await widget.controller.membershipFor(widget.community.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        backgroundColor: LaBombaColors.obsidian,
        appBar: AppBar(
          title: const Text('Universo da comunidade'),
          backgroundColor: Colors.transparent,
          foregroundColor: LaBombaColors.textPrimary,
        ),
        body: Container(
          decoration: LaBombaDecorations.shell,
          child: SafeArea(
            child: FutureBuilder<void>(
              future: _membershipLoad,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return LaBombaErrorState(
                    title: 'Não foi possível verificar o acesso',
                    message:
                        CommunityUiController.friendlyError(snapshot.error!),
                    onRetry: () =>
                        setState(() => _membershipLoad = _loadMembership()),
                  );
                }
                return FutureBuilder<void>(
                  future: _membersLoad,
                  builder: (context, _) {
                    return _buildContent();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final membership =
        widget.controller.cachedMembershipFor(widget.community.id);
    final canJoin = membership == null &&
        widget.controller.userId?.trim().isNotEmpty == true;
    final isJoining =
        widget.controller.joiningCommunityId == widget.community.id;
    final members = widget.controller.membersFor(widget.community.id);
    final membersError = widget.controller.membersErrorFor(widget.community.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              OrbRenderer(
                orb: SocialOrb(
                  id: widget.community.id,
                  type: OrbType.community,
                  title: widget.community.name,
                ),
                isSelected: false,
                isCenter: true,
                onTap: () {},
              ),
              const SizedBox(height: 18),
              Text(widget.community.name,
                  textAlign: TextAlign.center,
                  style: LaBombaTypography.headlineMedium),
              if (widget.community.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(widget.community.description!,
                    textAlign: TextAlign.center,
                    style: LaBombaTypography.bodyLarge),
              ],
              const SizedBox(height: 24),
              _MembershipStatus(membership: membership),
              if (_actionError != null) ...[
                const SizedBox(height: 12),
                Text(_actionError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: LaBombaColors.error)),
              ],
              const SizedBox(height: 20),
              if (canJoin)
                FilledButton.icon(
                  onPressed: isJoining ? null : _join,
                  icon: isJoining
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label:
                      Text(isJoining ? 'Entrando...' : 'Entrar na comunidade'),
                )
              else if (membership?.isActive == true)
                OutlinedButton.icon(
                  onPressed: _openUniverse,
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text('Abrir universo'),
                )
              else if (membership?.status == null &&
                  widget.controller.userId == null)
                const Text('Entre na sua conta para participar.',
                    style: TextStyle(color: LaBombaColors.textMuted)),
              if (membership == null) ...[
                const SizedBox(height: 26),
                const Text(
                  'O universo interno será preenchido quando houver conteúdo real disponível.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LaBombaColors.textMuted),
                ),
              ],
              const SizedBox(height: 28),
              _MembersSection(
                members: members,
                error: membersError,
                isLoading:
                    widget.controller.isLoadingMembers(widget.community.id),
                hasMore: widget.controller.hasMoreMembers(widget.community.id),
                isLoadingMore:
                    widget.controller.isLoadingMoreMembers(widget.community.id),
                onRetry: () =>
                    widget.controller.loadMembers(widget.community.id),
                onLoadMore: () =>
                    widget.controller.loadMoreMembers(widget.community.id),
                onOpenProfile: (userId) =>
                    Navigator.pushNamed(context, '/profile/$userId'),
              ),
              if (widget.community.topic != null) ...[
                const SizedBox(height: 24),
                _TopicSection(topic: widget.community.topic!),
              ],
              if (_contentController != null) ...[
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _contentController!,
                  builder: (context, _) {
                    final membership = widget.controller
                        .cachedMembershipFor(widget.community.id);
                    final canModerate = membership != null &&
                        membership.isActive &&
                        membership.role != CommunityMemberRole.member;
                    return CommunityKnowledgeSection(
                      communityId: widget.community.id,
                      controller: _contentController!,
                      onOpen: (content) => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CommunityContentDetailPage(
                            communityId: widget.community.id,
                            content: content,
                            controller: _contentController!,
                            moderationController: _moderationController,
                          ),
                        ),
                      ),
                      onCreate: () => showDialog<void>(
                        context: context,
                        builder: (_) => CommunityContentCreateDialog(
                          communityId: widget.community.id,
                          controller: _contentController!,
                        ),
                      ),
                      onModerate: canModerate && _moderationController != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CommunityModerationPage(
                                    communityId: widget.community.id,
                                    controller: _moderationController!,
                                  ),
                                ),
                              )
                          : null,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _actionError = null);
    try {
      await widget.controller.join(widget.community.id);
    } catch (error) {
      if (mounted) {
        setState(
            () => _actionError = CommunityUiController.friendlyError(error));
      }
    }
  }

  void _openUniverse() {
    final memberships = widget.controller.membersFor(widget.community.id);
    final contextOrbs = memberships
        .map((membership) => SocialOrb(
              id: membership.userId,
              type: OrbType.person,
            ))
        .toList();
    final topic = widget.community.topic;
    if (topic != null) {
      contextOrbs.add(SocialOrb(
        id: topic.id,
        type: OrbType.topic,
        title: topic.title,
      ));
    }
    final universe = CommunityUniverseProjection.fromCommunity(
      community: widget.community,
      center: SocialOrb(
        id: widget.community.id,
        type: OrbType.community,
        title: widget.community.name,
      ),
      memberOrbs: contextOrbs,
      memberships: memberships,
    );
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrbUniversePage(initialUniverse: universe),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.members,
    required this.error,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpenProfile,
  });

  final List<CommunityMembership> members;
  final CommunityError? error;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (isLoading && members.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    } else if (error != null && members.isEmpty) {
      content = Column(
        children: [
          Text(
            _memberErrorMessage(error!),
            textAlign: TextAlign.center,
            style: const TextStyle(color: LaBombaColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    } else if (members.isEmpty) {
      content = const Text(
        'Ainda não há membros ativos disponíveis neste contexto.',
        textAlign: TextAlign.center,
        style: TextStyle(color: LaBombaColors.textMuted),
      );
    } else {
      content = Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: members
                .map(
                  (membership) => Semantics(
                    button: true,
                    label: 'Abrir perfil do membro',
                    child: _MemberOrb(
                      userId: membership.userId,
                      onTap: () => onOpenProfile(membership.userId),
                    ),
                  ),
                )
                .toList(),
          ),
          if (hasMore) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: isLoadingMore ? null : onLoadMore,
              icon: isLoadingMore
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Carregar mais membros'),
            ),
          ],
        ],
      );
    }
    return Column(
      children: [
        const Text('Membros ativos', style: LaBombaTypography.titleMedium),
        const SizedBox(height: 14),
        content,
        if (error != null && members.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_memberErrorMessage(error!),
              style: const TextStyle(color: LaBombaColors.textMuted)),
        ],
      ],
    );
  }

  String _memberErrorMessage(CommunityError error) {
    if (error.code == CommunityErrorCode.forbidden) {
      return 'Os membros desta comunidade não estão disponíveis para visualização.';
    }
    return CommunityUiController.friendlyError(error);
  }
}

class _MemberOrb extends StatelessWidget {
  const _MemberOrb({required this.userId, required this.onTap});

  final String userId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: OrbRenderer(
        orb: SocialOrb(id: userId, type: OrbType.person),
        isSelected: false,
        onTap: onTap,
      ),
    );
  }
}

class _TopicSection extends StatelessWidget {
  const _TopicSection({required this.topic});

  final SocialTopic topic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Tópico contextual', style: LaBombaTypography.titleMedium),
        const SizedBox(height: 10),
        Chip(
          avatar: const Icon(Icons.topic_rounded, size: 18),
          label: Text(topic.title),
        ),
        if (topic.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(topic.description!,
              textAlign: TextAlign.center, style: LaBombaTypography.bodySmall),
        ],
      ],
    );
  }
}

class _MembershipStatus extends StatelessWidget {
  const _MembershipStatus({required this.membership});

  final CommunityMembership? membership;

  @override
  Widget build(BuildContext context) {
    final currentMembership = membership;
    String label = 'Não membro';
    if (currentMembership != null) {
      switch (currentMembership.status) {
        case CommunityMembershipStatus.active:
          label = 'Membro ativo';
          break;
        case CommunityMembershipStatus.pending:
          label = 'Membership pendente';
          break;
        case CommunityMembershipStatus.blocked:
          label = 'Acesso bloqueado';
          break;
        case CommunityMembershipStatus.left:
          label = 'Membership encerrada';
          break;
      }
    }
    final color = currentMembership == null
        ? LaBombaColors.textMuted
        : currentMembership.isActive
            ? LaBombaColors.success
            : currentMembership.status == CommunityMembershipStatus.blocked
                ? LaBombaColors.error
                : LaBombaColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(LaBombaRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
