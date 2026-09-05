import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../domain/content/community_moderation_repository.dart';
import '../presentation/community/community_moderation_ui_controller.dart';

class CommunityModerationPage extends StatefulWidget {
  const CommunityModerationPage({
    super.key,
    required this.communityId,
    this.repository,
    this.userId,
    this.controller,
  });

  final String communityId;
  final CommunityModerationRepository? repository;
  final String? userId;
  final CommunityModerationUiController? controller;

  @override
  State<CommunityModerationPage> createState() =>
      _CommunityModerationPageState();
}

class _CommunityModerationPageState extends State<CommunityModerationPage> {
  late final CommunityModerationUiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        CommunityModerationUiController(
          repository: widget.repository!,
          userId: widget.userId,
        )
      ..loadReports(widget.communityId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final reports = _controller.reportsFor(widget.communityId);
          final error = _controller.errorFor(widget.communityId);
          return Scaffold(
            backgroundColor: LaBombaColors.obsidian,
            appBar: AppBar(
              title: const Text('Revisão da comunidade'),
              backgroundColor: Colors.transparent,
              foregroundColor: LaBombaColors.textPrimary,
            ),
            body: Container(
              decoration: LaBombaDecorations.shell,
              child: _controller.isLoading(widget.communityId) &&
                      reports.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : error != null && reports.isEmpty
                      ? Center(
                          child: Text('Não foi possível carregar os reports.',
                              style: const TextStyle(
                                  color: LaBombaColors.textMuted)))
                      : reports.isEmpty
                          ? const Center(
                              child: Text('Nenhum report pendente.',
                                  style: TextStyle(
                                      color: LaBombaColors.textMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: reports.length,
                              itemBuilder: (context, index) {
                                final report = reports[index];
                                return Card(
                                  color: LaBombaColors.cardElevated,
                                  child: ListTile(
                                    leading: const Icon(Icons.flag_outlined,
                                        color: LaBombaColors.warning),
                                    title: Text(
                                        '${report.reason.name} · ${report.targetType.name}'),
                                    subtitle: Text(report.description ??
                                        'Sem descrição adicional'),
                                    onTap: () => _resolve(report),
                                  ),
                                );
                              },
                            ),
            ),
          );
        },
      );

  Future<void> _resolve(CommunityContentReport report) async {
    final resolution = await showDialog<ReportResolution>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Registrar resolução'),
        children: ReportResolution.values
            .map((value) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, value),
                  child: Text(value.name),
                ))
            .toList(),
      ),
    );
    if (resolution == null) return;
    await _controller.resolveReport(
      report: report,
      status: ReportStatus.resolved,
      resolution: resolution,
    );
    await _controller.loadReports(widget.communityId);
  }
}
