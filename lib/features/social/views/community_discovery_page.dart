import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../domain/community/community_read_service.dart';
import '../domain/community/community_write_service.dart';
import '../domain/content/community_content_repository.dart';
import '../domain/content/community_moderation.dart';
import '../models/social_community.dart';
import '../presentation/community/community_ui_controller.dart';
import 'community_detail_page.dart';

class CommunityDiscoveryPage extends StatefulWidget {
  const CommunityDiscoveryPage({
    super.key,
    required this.readService,
    required this.writeService,
    required this.userId,
    this.contentRepository,
    this.moderationRepository,
  });

  final CommunityReadService readService;
  final CommunityWriteService writeService;
  final String? userId;
  final CommunityContentRepository? contentRepository;
  final CommunityModerationRepository? moderationRepository;

  @override
  State<CommunityDiscoveryPage> createState() => _CommunityDiscoveryPageState();
}

class _CommunityDiscoveryPageState extends State<CommunityDiscoveryPage> {
  late final CommunityUiController _controller;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _controller = CommunityUiController(
      readService: widget.readService,
      writeService: widget.writeService,
      userId: widget.userId,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: LaBombaColors.obsidian,
        appBar: AppBar(
          title: const Text('Comunidades'),
          backgroundColor: Colors.transparent,
          foregroundColor: LaBombaColors.textPrimary,
          actions: [
            IconButton(
              tooltip: 'Criar comunidade',
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        body: Container(
          decoration: LaBombaDecorations.shell,
          child: SafeArea(
            child: Consumer<CommunityUiController>(
              builder: (context, controller, _) => _buildBody(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CommunityUiController controller) {
    if (controller.isLoading && controller.communities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.communities.isEmpty) {
      return LaBombaErrorState(
        title: 'Não foi possível carregar',
        message: CommunityUiController.friendlyError(controller.error!),
        onRetry: controller.load,
      );
    }
    final communities = controller.communities.where((community) {
      final query = _search.toLowerCase();
      return query.isEmpty ||
          community.name.toLowerCase().contains(query) ||
          (community.description?.toLowerCase().contains(query) ?? false);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: AppSearchField(
            hintText: 'Explorar comunidades',
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
        ),
        Expanded(
          child: communities.isEmpty
              ? LaBombaEmptyState(
                  title: _search.isEmpty
                      ? 'Seu universo de comunidades está vazio.'
                      : 'Nenhuma comunidade encontrada.',
                  message: _search.isEmpty
                      ? 'Explore novos universos para encontrar pessoas e ideias.'
                      : 'Tente buscar por outro nome ou descrição.',
                  action: _search.isEmpty
                      ? FilledButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Criar comunidade'),
                        )
                      : null,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 620
                            ? 2
                            : 1;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: communities.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: columns == 1 ? 2.4 : 1.35,
                          ),
                          itemBuilder: (context, index) => _CommunityCard(
                            community: communities[index],
                            controller: controller,
                            contentRepository: widget.contentRepository,
                            moderationRepository: widget.moderationRepository,
                          ),
                        ),
                        if (controller.hasNextPage && _search.isEmpty) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: FilledButton.tonalIcon(
                              onPressed: controller.isLoadingMore
                                  ? null
                                  : controller.loadMore,
                              icon: controller.isLoadingMore
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.expand_more_rounded),
                              label: const Text('Carregar mais'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog() async {
    final community = await showDialog<SocialCommunity>(
      context: context,
      builder: (_) => _CreateCommunityDialog(controller: _controller),
    );
    if (community != null && mounted) _openCommunity(community);
  }

  void _openCommunity(SocialCommunity community) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommunityDetailPage(
          community: community,
          controller: _controller,
          contentRepository: widget.contentRepository,
        ),
      ),
    );
  }
}

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog({required this.controller});

  final CommunityUiController controller;

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => AlertDialog(
        title: const Text('Criar comunidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _descriptionController,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: widget.controller.isCreating ? null : _submit,
            icon: widget.controller.isCreating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Informe um nome.');
      return;
    }
    if (name.length > 80) {
      setState(() => _validationError = 'Use até 80 caracteres.');
      return;
    }
    try {
      final community = await widget.controller.createCommunity(
        name: name,
        description: _descriptionController.text.trim(),
      );
      if (mounted && community != null) Navigator.pop(context, community);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _validationError = CommunityUiController.friendlyError(error));
      }
    }
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.controller,
    required this.contentRepository,
    required this.moderationRepository,
  });
  final CommunityModerationRepository? moderationRepository;

  final SocialCommunity community;
  final CommunityUiController controller;
  final CommunityContentRepository? contentRepository;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir comunidade ${community.name}',
      child: Card(
        color: LaBombaColors.card.withValues(alpha: 0.88),
        child: InkWell(
          borderRadius: BorderRadius.circular(LaBombaRadius.large),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CommunityDetailPage(
                community: community,
                controller: controller,
                contentRepository: contentRepository,
                moderationRepository: moderationRepository,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded,
                    color: LaBombaColors.cyan, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(community.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LaBombaTypography.titleMedium),
                      if (community.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(community.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: LaBombaTypography.bodySmall),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: LaBombaColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
