import 'package:flutter/material.dart';
import '../../../theme/la_bomba_design_system.dart';
import '../domain/content/community_moderation.dart';
import '../presentation/community/community_moderation_ui_controller.dart';

class CommunityReportDialog extends StatefulWidget {
  const CommunityReportDialog(
      {super.key,
      required this.communityId,
      required this.targetType,
      required this.targetId,
      required this.controller,
      this.parentContentId});
  final String communityId;
  final CommunityReportTargetType targetType;
  final String targetId;
  final CommunityModerationUiController controller;
  final String? parentContentId;
  @override
  State<CommunityReportDialog> createState() => _CommunityReportDialogState();
}

class _CommunityReportDialogState extends State<CommunityReportDialog> {
  CommunityReportReason _reason = CommunityReportReason.other;
  final _description = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Reportar para revisão'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<CommunityReportReason>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Motivo'),
            items: CommunityReportReason.values
                .map((reason) =>
                    DropdownMenuItem(value: reason, child: Text(reason.name)))
                .toList(),
            onChanged: (value) => setState(() => _reason = value!),
          ),
          TextField(
              controller: _description,
              maxLines: 4,
              decoration:
                  const InputDecoration(labelText: 'Contexto opcional')),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: LaBombaColors.error)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Enviar report')),
        ],
      );
  Future<void> _submit() async {
    try {
      await widget.controller.createReport(
          communityId: widget.communityId,
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: _reason,
          description: _description.text,
          parentContentId: widget.parentContentId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Seu report foi enviado para revisão.')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar o report.');
    }
  }
}
