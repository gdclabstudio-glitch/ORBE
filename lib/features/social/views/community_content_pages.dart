import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../domain/community/community_errors.dart';
import '../domain/content/community_content.dart';
import '../presentation/community/community_content_ui_controller.dart';
import '../domain/content/community_moderation.dart';
import '../presentation/community/community_moderation_ui_controller.dart';
import 'community_report_dialog.dart';

String contentTypeLabel(ContentType type) {
  switch (type) {
    case ContentType.fact:
      return 'FACT · afirmação factual';
    case ContentType.opinion:
      return 'OPINION · opinião';
    case ContentType.hypothesis:
      return 'HYPOTHESIS · hipótese';
    case ContentType.discussion:
      return 'DISCUSSION · discussão';
    case ContentType.question:
      return 'QUESTION · pergunta';
    case ContentType.interpretation:
      return 'INTERPRETATION · interpretação';
  }
}

String evidenceTypeLabel(EvidenceType type) => _enumLabel(type.name);
String sourceTypeLabel(SourceType type) => _enumLabel(type.name);

String _enumLabel(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .replaceFirst(value[0], value[0].toUpperCase());

class CommunityKnowledgeSection extends StatelessWidget {
  const CommunityKnowledgeSection({
    super.key,
    required this.communityId,
    required this.controller,
    required this.onOpen,
    required this.onCreate,
    this.onModerate,
  });

  final String communityId;
  final CommunityContentUiController controller;
  final ValueChanged<CommunityContent> onOpen;
  final VoidCallback onCreate;
  final VoidCallback? onModerate;

  @override
  Widget build(BuildContext context) {
    final contents = controller.contentsFor(communityId);
    final error = controller.contentErrorFor(communityId);
    Widget content;
    if (controller.isLoadingContents(communityId) && contents.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    } else if (error != null && contents.isEmpty) {
      content = Column(
        children: [
          Text(
            _errorMessage(error),
            textAlign: TextAlign.center,
            style: const TextStyle(color: LaBombaColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => controller.loadContents(communityId),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    } else if (contents.isEmpty) {
      content = const Text(
        'Esta comunidade ainda não construiu conhecimento.',
        textAlign: TextAlign.center,
        style: TextStyle(color: LaBombaColors.textMuted),
      );
    } else {
      content = Column(
        children: [
          ...contents.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContentCard(
                content: item,
                controller: controller,
                onTap: () => onOpen(item),
              ),
            ),
          ),
          if (controller.hasMoreContents(communityId))
            TextButton.icon(
              onPressed: controller.isLoadingMoreContents(communityId)
                  ? null
                  : () => controller.loadMoreContents(communityId),
              icon: controller.isLoadingMoreContents(communityId)
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Carregar mais conhecimento'),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Conhecimento da comunidade',
                style: LaBombaTypography.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Criar conhecimento',
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
            ),
            if (onModerate != null)
              IconButton(
                tooltip: 'Revisar reports',
                onPressed: onModerate,
                icon: const Icon(Icons.gavel_rounded),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Afirmações, contexto e referências construídos por membros.',
          style: TextStyle(color: LaBombaColors.textMuted),
        ),
        const SizedBox(height: 14),
        content,
      ],
    );
  }

  String _errorMessage(CommunityError error) {
    if (error.code == CommunityErrorCode.forbidden) {
      return 'O conhecimento desta comunidade não está disponível para você.';
    }
    return 'Não foi possível carregar o conhecimento desta comunidade.';
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.content,
    required this.controller,
    required this.onTap,
  });

  final CommunityContent content;
  final CommunityContentUiController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir conhecimento ${content.title}',
      child: Card(
        color: LaBombaColors.cardElevated,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LaBombaRadius.large),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        color: LaBombaColors.cyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contentTypeLabel(content.type),
                        style: LaBombaTypography.labelMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: LaBombaColors.textMuted),
                  ],
                ),
                const SizedBox(height: 10),
                Text(content.title, style: LaBombaTypography.titleMedium),
                const SizedBox(height: 6),
                Text(
                  content.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: LaBombaTypography.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Publicado por ${content.createdBy}',
                  style: LaBombaTypography.caption,
                ),
                const SizedBox(height: 8),
                Text(
                  'Evidências: ${controller.evidenceFor(content.contentId).length} · '
                  'Fontes: ${controller.sourcesFor(content.communityId).length} · '
                  'Correções: ${controller.correctionsFor(content.contentId).length}',
                  style: LaBombaTypography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CommunityContentDetailPage extends StatefulWidget {
  const CommunityContentDetailPage({
    super.key,
    required this.communityId,
    required this.content,
    required this.controller,
    this.moderationController,
  });

  final String communityId;
  final CommunityContent content;
  final CommunityContentUiController controller;
  final CommunityModerationUiController? moderationController;

  @override
  State<CommunityContentDetailPage> createState() =>
      _CommunityContentDetailPageState();
}

class _CommunityContentDetailPageState
    extends State<CommunityContentDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadRelations(
      communityId: widget.communityId,
      contentId: widget.content.contentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final evidence =
            widget.controller.evidenceFor(widget.content.contentId);
        final corrections =
            widget.controller.correctionsFor(widget.content.contentId);
        final sources = widget.controller.sourcesFor(widget.communityId);
        final associatedSourceIds =
            evidence.map((item) => item.sourceId).whereType<String>().toSet();
        final associatedSources = sources
            .where((source) => associatedSourceIds.contains(source.sourceId))
            .toList();
        final hasConflictingEvidence = evidence.any(
              (item) => item.position == EvidencePosition.supports,
            ) &&
            evidence.any(
              (item) => item.position == EvidencePosition.challenges,
            );
        final loading =
            widget.controller.isLoadingRelations(widget.content.contentId);
        final error =
            widget.controller.relationErrorFor(widget.content.contentId);
        return Scaffold(
          backgroundColor: LaBombaColors.obsidian,
          appBar: AppBar(
            title: const Text('Conhecimento da comunidade'),
            backgroundColor: Colors.transparent,
            foregroundColor: LaBombaColors.textPrimary,
          ),
          body: Container(
            decoration: LaBombaDecorations.shell,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  _TypeBadge(type: widget.content.type),
                  if (widget.content.lifecycle !=
                      CommunityContentLifecycle.active) ...[
                    const SizedBox(height: 8),
                    _LifecycleNotice(lifecycle: widget.content.lifecycle),
                  ],
                  const SizedBox(height: 14),
                  Text(widget.content.title,
                      style: LaBombaTypography.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Publicado por ${widget.content.createdBy}',
                      style: LaBombaTypography.caption),
                  const SizedBox(height: 20),
                  Text(widget.content.body, style: LaBombaTypography.bodyLarge),
                  const SizedBox(height: 24),
                  _MetaSummary(
                    evidenceCount: evidence.length,
                    sourceCount: associatedSources.length,
                    correctionCount: corrections.length,
                  ),
                  const SizedBox(height: 22),
                  if (loading && evidence.isEmpty && corrections.isEmpty)
                    const Center(child: CircularProgressIndicator()),
                  if (error != null) ...[
                    Text('Não foi possível carregar todas as referências.',
                        style: const TextStyle(color: LaBombaColors.error)),
                    TextButton.icon(
                      onPressed: () => widget.controller.loadRelations(
                        communityId: widget.communityId,
                        contentId: widget.content.contentId,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                  _EvidenceBlock(evidence: evidence),
                  if (hasConflictingEvidence) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Há evidências que apoiam e contestam esta afirmação.',
                      style: TextStyle(color: LaBombaColors.warning),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _SourceBlock(sources: associatedSources),
                  const SizedBox(height: 20),
                  _CorrectionBlock(corrections: corrections),
                  const SizedBox(height: 24),
                  if (widget.controller.userId?.trim().isNotEmpty == true)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (widget.moderationController != null)
                          TextButton.icon(
                            onPressed: _showReportDialog,
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Reportar'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _showEvidenceDialog(sources),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Adicionar evidência'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showSourceDialog,
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Adicionar fonte'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showCorrectionDialog,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Sugerir correção'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEvidenceDialog(List<Source> sources) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EvidenceDialog(
        controller: widget.controller,
        contentId: widget.content.contentId,
        sources: sources,
      ),
    );
  }

  Future<void> _showSourceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SourceDialog(
        controller: widget.controller,
        communityId: widget.communityId,
      ),
    );
  }

  Future<void> _showCorrectionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CorrectionDialog(
        controller: widget.controller,
        contentId: widget.content.contentId,
      ),
    );
  }

  Future<void> _showReportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => CommunityReportDialog(
        controller: widget.moderationController!,
        communityId: widget.communityId,
        targetId: widget.content.contentId,
        targetType: CommunityReportTargetType.content,
      ),
    );
  }
}

class _LifecycleNotice extends StatelessWidget {
  const _LifecycleNotice({required this.lifecycle});
  final CommunityContentLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    String message;
    switch (lifecycle) {
      case CommunityContentLifecycle.underReview:
        message = 'Em revisão pela comunidade.';
        break;
      case CommunityContentLifecycle.restricted:
        message =
            'Este conteúdo está temporariamente restrito enquanto passa por revisão.';
        break;
      case CommunityContentLifecycle.corrected:
        message = 'Este conteúdo possui correções registradas.';
        break;
      case CommunityContentLifecycle.archived:
        message = 'Este conteúdo foi arquivado e permanece no histórico.';
        break;
      case CommunityContentLifecycle.active:
        message = '';
        break;
    }
    return Text(message, style: const TextStyle(color: LaBombaColors.warning));
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(Icons.label_outline_rounded, size: 18),
        label: Text(contentTypeLabel(type)),
      ),
    );
  }
}

class _MetaSummary extends StatelessWidget {
  const _MetaSummary({
    required this.evidenceCount,
    required this.sourceCount,
    required this.correctionCount,
  });

  final int evidenceCount;
  final int sourceCount;
  final int correctionCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _CountChip(
            icon: Icons.fact_check_outlined,
            label: 'Evidências',
            count: evidenceCount),
        _CountChip(
            icon: Icons.link_rounded, label: 'Fontes', count: sourceCount),
        _CountChip(
            icon: Icons.edit_note_rounded,
            label: 'Correções',
            count: correctionCount),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.icon, required this.label, required this.count});

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 17),
        label: Text('$label: $count'),
      );
}

class _EvidenceBlock extends StatelessWidget {
  const _EvidenceBlock({required this.evidence});

  final List<Evidence> evidence;

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      return const _InfoBlock(
        title: 'Evidências',
        message: 'Este conteúdo ainda não possui evidências associadas.',
      );
    }
    return _DetailBlock(
      title: 'Evidências',
      children: evidence
          .map((item) => _RelationTile(
                icon: Icons.fact_check_outlined,
                title: evidenceTypeLabel(item.type),
                body: item.description,
                footer:
                    'Por ${item.createdBy}${item.sourceId == null ? '' : ' · Fonte ${item.sourceId}'} · ${_positionLabel(item.position)}',
              ))
          .toList(),
    );
  }

  String _positionLabel(EvidencePosition position) {
    switch (position) {
      case EvidencePosition.supports:
        return 'apoia';
      case EvidencePosition.challenges:
        return 'contesta';
      case EvidencePosition.contextualizes:
        return 'contextualiza';
    }
  }
}

class _SourceBlock extends StatelessWidget {
  const _SourceBlock({required this.sources});

  final List<Source> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const _InfoBlock(
        title: 'Fontes',
        message: 'Nenhuma fonte foi associada.',
      );
    }
    return _DetailBlock(
      title: 'Fontes associadas',
      children: sources
          .map((item) => _RelationTile(
                icon: Icons.link_rounded,
                title: item.title,
                body: '${sourceTypeLabel(item.type)} · ${item.locator}',
                footer: [item.author, item.publisher]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
              ))
          .toList(),
    );
  }
}

class _CorrectionBlock extends StatelessWidget {
  const _CorrectionBlock({required this.corrections});

  final List<ContentCorrection> corrections;

  @override
  Widget build(BuildContext context) {
    if (corrections.isEmpty) {
      return const _InfoBlock(
        title: 'Correções',
        message: 'Nenhuma correção foi registrada.',
      );
    }
    return _DetailBlock(
      title: 'Histórico de correções',
      children: corrections
          .map((item) => _RelationTile(
                icon: Icons.edit_note_rounded,
                title: 'Correção registrada',
                body: item.explanation,
                footer: 'Por ${item.createdBy}',
              ))
          .toList(),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _DetailBlock(
        title: title,
        children: [
          Text(message, style: const TextStyle(color: LaBombaColors.textMuted)),
        ],
      );
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LaBombaTypography.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      );
}

class _RelationTile extends StatelessWidget {
  const _RelationTile(
      {required this.icon,
      required this.title,
      required this.body,
      required this.footer});

  final IconData icon;
  final String title;
  final String body;
  final String footer;

  @override
  Widget build(BuildContext context) => Card(
        color: LaBombaColors.surface,
        child: ListTile(
          leading: Icon(icon, color: LaBombaColors.cyan),
          title: Text(title),
          subtitle: Text('$body\n$footer'),
          isThreeLine: true,
        ),
      );
}

class CommunityContentCreateDialog extends StatefulWidget {
  const CommunityContentCreateDialog(
      {required this.communityId, required this.controller});

  final String communityId;
  final CommunityContentUiController controller;

  @override
  State<CommunityContentCreateDialog> createState() =>
      _CommunityContentCreateDialogState();
}

class _CommunityContentCreateDialogState
    extends State<CommunityContentCreateDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  ContentType _type = ContentType.fact;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => AlertDialog(
          title: const Text('Criar conhecimento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ContentType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: ContentType.values
                      .map((type) => DropdownMenuItem(
                          value: type, child: Text(contentTypeLabel(type))))
                      .toList(),
                  onChanged: widget.controller.isSubmitting('create-content')
                      ? null
                      : (value) => setState(() => _type = value!),
                ),
                TextField(
                    controller: _title,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Título')),
                TextField(
                    controller: _body,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                        labelText: 'Contexto ou descrição')),
                if (_error != null)
                  Text(_error!,
                      style: const TextStyle(color: LaBombaColors.error)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: widget.controller.isSubmitting('create-content')
                  ? null
                  : _submit,
              icon: widget.controller.isSubmitting('create-content')
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.publish_rounded),
              label: const Text('Publicar'),
            ),
          ],
        ),
      );

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = 'Informe título e contexto.');
      return;
    }
    try {
      final created = await widget.controller.createContent(
        communityId: widget.communityId,
        type: _type,
        title: _title.text,
        body: _body.text,
      );
      if (mounted && created != null) Navigator.pop(context, created);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível publicar este conteúdo.');
    }
  }
}

class _EvidenceDialog extends StatefulWidget {
  const _EvidenceDialog(
      {required this.controller,
      required this.contentId,
      required this.sources});

  final CommunityContentUiController controller;
  final String contentId;
  final List<Source> sources;

  @override
  State<_EvidenceDialog> createState() => _EvidenceDialogState();
}

class _EvidenceDialogState extends State<_EvidenceDialog> {
  final _description = TextEditingController();
  EvidenceType _type = EvidenceType.observation;
  EvidencePosition _position = EvidencePosition.contextualizes;
  String? _sourceId;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Adicionar evidência'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<EvidenceType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: EvidenceType.values
                    .map((type) => DropdownMenuItem(
                        value: type, child: Text(evidenceTypeLabel(type))))
                    .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              DropdownButtonFormField<EvidencePosition>(
                initialValue: _position,
                decoration: const InputDecoration(labelText: 'Relação'),
                items: EvidencePosition.values
                    .map((position) => DropdownMenuItem(
                          value: position,
                          child: Text(_positionLabel(position)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _position = value!),
              ),
              TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descrição')),
              DropdownButtonFormField<String?>(
                initialValue: _sourceId,
                decoration: const InputDecoration(labelText: 'Fonte opcional'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Sem fonte associada')),
                  ...widget.sources.map((source) => DropdownMenuItem<String?>(
                      value: source.sourceId,
                      child:
                          Text(source.title, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) => setState(() => _sourceId = value),
              ),
              if (_error != null)
                Text(_error!,
                    style: const TextStyle(color: LaBombaColors.error)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Adicionar')),
        ],
      );

  Future<void> _submit() async {
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'Descreva a evidência.');
      return;
    }
    try {
      await widget.controller.createEvidence(
        contentId: widget.contentId,
        type: _type,
        description: _description.text,
        sourceId: _sourceId,
        position: _position,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível adicionar a evidência.');
    }
  }

  String _positionLabel(EvidencePosition position) {
    switch (position) {
      case EvidencePosition.supports:
        return 'Apoia';
      case EvidencePosition.challenges:
        return 'Contesta';
      case EvidencePosition.contextualizes:
        return 'Contextualiza';
    }
  }
}

class _SourceDialog extends StatefulWidget {
  const _SourceDialog({required this.controller, required this.communityId});

  final CommunityContentUiController controller;
  final String communityId;

  @override
  State<_SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends State<_SourceDialog> {
  final _title = TextEditingController();
  final _locator = TextEditingController();
  SourceType _type = SourceType.other;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _locator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Adicionar fonte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<SourceType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: SourceType.values
                    .map((type) => DropdownMenuItem(
                        value: type, child: Text(sourceTypeLabel(type))))
                    .toList(),
                onChanged: (value) => setState(() => _type = value!)),
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título')),
            TextField(
                controller: _locator,
                decoration:
                    const InputDecoration(labelText: 'URL ou referência')),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: LaBombaColors.error)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Adicionar')),
        ],
      );

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _locator.text.trim().isEmpty) {
      setState(() => _error = 'Informe título e referência.');
      return;
    }
    try {
      await widget.controller.createSource(
          communityId: widget.communityId,
          type: _type,
          title: _title.text,
          locator: _locator.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível adicionar a fonte.');
    }
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.controller, required this.contentId});

  final CommunityContentUiController controller;
  final String contentId;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _explanation = TextEditingController();
  final _proposedBody = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _explanation.dispose();
    _proposedBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sugerir correção'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _explanation,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'O que precisa de contexto ou correção?')),
            TextField(
                controller: _proposedBody,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Texto proposto (opcional)')),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: LaBombaColors.error)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Registrar')),
        ],
      );

  Future<void> _submit() async {
    if (_explanation.text.trim().isEmpty) {
      setState(() => _error = 'Explique a correção.');
      return;
    }
    try {
      await widget.controller.createCorrection(
          contentId: widget.contentId,
          explanation: _explanation.text,
          proposedBody:
              _proposedBody.text.trim().isEmpty ? null : _proposedBody.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível registrar a correção.');
    }
  }
}
