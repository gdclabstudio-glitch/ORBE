import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_guard.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> _tabs = [
    'Overview',
    'Users',
    'Content',
    'Communities',
    'Notifications',
    'Security',
    'Audit',
  ];

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _metricsStream =>
      _firestore.collection('system_metrics').doc('overview').snapshots();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  List<String> _buildAlerts(Map<String, dynamic> metrics) {
    final alerts = <String>[];
    final authFailures = _asInt(metrics['authFailuresToday']);
    final openReports = _asInt(metrics['openReports']);
    final backendHealth =
        (metrics['backendHealth'] as String? ?? 'healthy').toLowerCase();
    final uploadSpike = _asInt(metrics['uploadSpikeToday']);
    final criticalEvents = _asInt(metrics['criticalEventsToday']);
    final messagesToday = _asInt(metrics['messagesSentToday']);

    if (authFailures >= 10) {
      alerts.add('Muitas falhas de autenticação');
    }
    if (openReports >= 25) {
      alerts.add('Aumento anormal de denúncias');
    }
    if (backendHealth != 'healthy') {
      alerts.add('Falhas de backend ou indisponibilidade');
    }
    if (uploadSpike >= 50) {
      alerts.add('Aumento anormal de uploads');
    }
    if (criticalEvents >= 3) {
      alerts.add('Eventos críticos repetidos');
    }
    if (messagesToday >= 500) {
      alerts.add('Possível comportamento de spam');
    }
    if (alerts.isEmpty) {
      alerts.add('Sem alertas críticos');
    }
    return alerts;
  }

  Future<void> _submitBackendRequest({
    required String action,
    required String resourceType,
    String? resourceId,
    required String reason,
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'submitAdminRequest',
      );
      final response = await callable.call(<String, dynamic>{
        'type': action,
        'resourceType': resourceType,
        'resourceId': resourceId ?? 'bulk',
        'reason': reason,
        'details': {'source': 'control_center', ...(details ?? const {})},
      });

      final requestId = response.data['requestId'] as String? ?? 'pending';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ação "$action" registrada no backend com confirmação recente (request $requestId).',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Não foi possível enviar a ação administrativa.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao processar ação administrativa: ${error.toString()}',
          ),
        ),
      );
    }
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _metricsStream,
      builder: (context, metricsSnap) {
        final metrics = metricsSnap.data?.data() ?? <String, dynamic>{};
        final onlineUsers = _asInt(metrics['onlineUsers']);
        final activeUsers = _asInt(metrics['activeUsers']);
        final newUsersToday = _asInt(metrics['newUsersToday']);
        final newPostsToday = _asInt(metrics['newPostsToday']);
        final storiesPublishedToday = _asInt(metrics['storiesPublishedToday']);
        final activeStories = _asInt(metrics['activeStories']);
        final messagesToday = _asInt(metrics['messagesSentToday']);
        final communitiesActive = _asInt(metrics['communitiesActive']);
        final alerts = _buildAlerts(metrics);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operação em tempo real',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Métricas agregadas e eventos do backend, sem depender de refresh manual.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.1,
                children: [
                  _buildMetricCard(
                    label: 'Usuários online',
                    value: '$onlineUsers',
                    color: const Color(0xFF8B5CF6),
                    icon: Icons.people_alt,
                  ),
                  _buildMetricCard(
                    label: 'Usuários ativos',
                    value: '$activeUsers',
                    color: const Color(0xFF22C55E),
                    icon: Icons.track_changes,
                  ),
                  _buildMetricCard(
                    label: 'Novos usuários',
                    value: '$newUsersToday',
                    color: const Color(0xFF60A5FA),
                    icon: Icons.person_add,
                  ),
                  _buildMetricCard(
                    label: 'Posts hoje',
                    value: '$newPostsToday',
                    color: const Color(0xFF34D399),
                    icon: Icons.article,
                  ),
                  _buildMetricCard(
                    label: 'Stories ativos',
                    value: '$activeStories',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.auto_awesome,
                  ),
                  _buildMetricCard(
                    label: 'Stories publicadas',
                    value: '$storiesPublishedToday',
                    color: const Color(0xFFFACC15),
                    icon: Icons.camera_alt,
                  ),
                  _buildMetricCard(
                    label: 'Mensagens hoje',
                    value: '$messagesToday',
                    color: const Color(0xFF38BDF8),
                    icon: Icons.chat,
                  ),
                  _buildMetricCard(
                    label: 'Comunidades ativas',
                    value: '$communitiesActive',
                    color: const Color(0xFFFB7185),
                    icon: Icons.groups,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPanel(
                      title: 'Alertas operacionais',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final alert in alerts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    alert.startsWith('Sem')
                                        ? Icons.check_circle
                                        : Icons.warning_amber_rounded,
                                    color: alert.startsWith('Sem')
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(alert)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildPanel(
                      title: 'Ações rápidas',
                      child: Column(
                        children: [
                          _buildListAction(
                            title: 'Banir usuário',
                            subtitle:
                                'Solicitar remoção de acesso via backend.',
                            onPressed: () => _submitBackendRequest(
                              action: 'ban_user',
                              resourceType: 'user',
                              resourceId: 'user_42',
                              reason:
                                  'Requisição de banimento a partir do Control Center.',
                            ),
                          ),
                          _buildListAction(
                            title: 'Excluir post',
                            subtitle: 'Pedido de moderação com auditoria.',
                            onPressed: () => _submitBackendRequest(
                              action: 'delete_post',
                              resourceType: 'post',
                              resourceId: 'post_99',
                              reason:
                                  'Conteúdo violando política da comunidade.',
                            ),
                          ),
                          _buildListAction(
                            title: 'Broadcast',
                            subtitle: 'Notificação institucional pelo backend.',
                            onPressed: () => _submitBackendRequest(
                              action: 'mass_fcm',
                              resourceType: 'broadcast',
                              resourceId: 'mass_fcm',
                              reason:
                                  'Campanha operacional ou mudança de política.',
                              details: {
                                'title': 'Atualização da operação',
                                'body':
                                    'Acompanhe as instruções da operação em andamento.',
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return _buildPanel(
      title: 'Usuários e acesso',
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _buildUserRow(
            'Luan Costa',
            'owner@labomba.app',
            'OWNER',
            Colors.purple,
          ),
          _buildUserRow('Ana Sousa', 'ana@labomba.app', 'ADMIN', Colors.blue),
          _buildUserRow(
            'Pedro Silva',
            'pedro@labomba.app',
            'MODERATOR',
            Colors.orange,
          ),
          _buildUserRow(
            'Maria Reis',
            'maria@labomba.app',
            'USER',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(String name, String email, String role, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF111827),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(name.substring(0, 1), style: TextStyle(color: color)),
        ),
        title: Text(name),
        subtitle: Text(email),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            role,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTab() {
    return _buildPanel(
      title: 'Conteúdo e comunidade',
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _buildListAction(
            title: 'Remover post com alerta',
            subtitle:
                'Envia requisição para exclusão de conteúdo com auditoria.',
            onPressed: () => _submitBackendRequest(
              action: 'delete_post',
              resourceType: 'post',
              resourceId: 'post_1204',
              reason: 'Post com conteúdo duplicado e sinal de spam.',
            ),
          ),
          _buildListAction(
            title: 'Ajustar reputação de comunidade',
            subtitle: 'Ação de moderação com aprovação do backend.',
            onPressed: () => _submitBackendRequest(
              action: 'moderate_community',
              resourceType: 'community',
              resourceId: 'community_74',
              reason:
                  'Comunidade com comportamento repetitivo e sinal de abuso.',
            ),
          ),
          _buildListAction(
            title: 'Revisar stories pendentes',
            subtitle: 'Solicita revisão de publicação de stories.',
            onPressed: () => _submitBackendRequest(
              action: 'review_story',
              resourceType: 'story',
              resourceId: 'story_21',
              reason: 'Story exige revisão de visibilidade e conteúdo.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunitiesTab() {
    return _buildPanel(
      title: 'Comunidades',
      child: Column(
        children: const [
          _StatusRow(label: 'Comunidades ativas', value: '42', ok: true),
          _StatusRow(label: 'Comunidades sinalizadas', value: '03', ok: false),
          _StatusRow(label: 'Posts em revisão', value: '19', ok: true),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return _buildPanel(
      title: 'Notificações',
      child: Column(
        children: [
          _buildListAction(
            title: 'Enviar notificação global',
            subtitle: 'Exige processamento de backend e registro de auditoria.',
            onPressed: () => _submitBackendRequest(
              action: 'mass_fcm',
              resourceType: 'broadcast',
              resourceId: 'mass_fcm',
              reason: 'Campanha de segurança ou comunicação comercial.',
              details: {
                'title': 'Atualização importante',
                'body': 'Confira as novas regras da comunidade.',
              },
            ),
          ),
          _buildListAction(
            title: 'Ajustar alarme de risco',
            subtitle: 'Dispara alerta operacional do backend.',
            onPressed: () => _submitBackendRequest(
              action: 'system_alert',
              resourceType: 'system',
              resourceId: 'system_alerts',
              reason: 'Alerta operacional solicitado pelo controle central.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return _buildPanel(
      title: 'Segurança e políticas',
      child: Column(
        children: const [
          _StatusRow(label: 'Firestore rules', value: 'Hardened', ok: true),
          _StatusRow(label: 'Storage rules', value: 'Owner-bound', ok: true),
          _StatusRow(
            label: 'Admin requests',
            value: 'Requer backend',
            ok: true,
          ),
          _StatusRow(label: 'Mutability guards', value: 'Ativos', ok: true),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    return _buildPanel(
      title: 'Auditoria administrativa',
      child: ListView(
        children: const [
          _AuditEntry(
            title: 'assignRoleClaims',
            detail: 'Role back-office emitida por backend autorizado',
            time: 'há 12 min',
          ),
          _AuditEntry(
            title: 'delete_post',
            detail: 'Requisição processada com aprovação e auditoria',
            time: 'há 31 min',
          ),
          _AuditEntry(
            title: 'mass_fcm',
            detail: 'Envio global registrado com origem admin_requests',
            time: 'há 1h',
          ),
          _AuditEntry(
            title: 'ban_user',
            detail: 'Suspensão registrada como ação backend-only',
            time: 'há 2h',
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Card(
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildListAction({
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Card(
      color: const Color(0xFF0F172A),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Enviar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('La Bomba Control Center'),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                avatar: Icon(Icons.shield_rounded, size: 16),
                label: Text('Backend-authoritative'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Material(
                color: const Color(0xFF0F172A),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _tabs.map((e) => Tab(text: e)).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildUsersTab(),
                    _buildContentTab(),
                    _buildCommunitiesTab(),
                    _buildNotificationsTab(),
                    _buildSecurityTab(),
                    _buildAuditTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: ok ? Colors.greenAccent : Colors.orangeAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditEntry extends StatelessWidget {
  final String title;
  final String detail;
  final String time;

  const _AuditEntry({
    required this.title,
    required this.detail,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F172A),
      child: ListTile(
        title: Text(title),
        subtitle: Text(detail),
        trailing: Text(time, style: const TextStyle(color: Colors.white54)),
      ),
    );
  }
}
