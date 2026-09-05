import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/admin/services/moderation_service.dart';
import '../../providers/admin_auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/user_appbar_actions.dart';

class AdminModerationPage extends StatelessWidget {
  const AdminModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AdminAuthProvider>().isAuthenticated) {
      return const Scaffold(
        body: Center(child: Text('Acesso restrito a administradores.')),
      );
    }
    final service = ModerationService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderação'),
        actions: [UserAppBarActions()],
      ),
      body: StreamBuilder<List<ModerationReport>>(
        stream: service.openReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar denúncias.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(child: Text('Nenhuma denúncia pendente.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: Colors.orange,
                  ),
                  title: Text('${report.contentType}: ${report.contentId}'),
                  subtitle: Text(report.reason),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      final moderatorId =
                          context.read<AuthService>().currentUser?.uid ??
                              'admin';
                      if (action == 'hide') {
                        await service.hideMemory(
                          memoryId: report.contentId,
                          reportId: report.id,
                          moderatorId: moderatorId,
                        );
                      } else {
                        await service.resolveReport(
                          reportId: report.id,
                          moderatorId: moderatorId,
                          resolution: 'dismissed',
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'hide',
                        child: Text('Ocultar conteúdo'),
                      ),
                      PopupMenuItem(
                        value: 'dismiss',
                        child: Text('Ignorar denúncia'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
