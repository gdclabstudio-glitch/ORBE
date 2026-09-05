import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/outbox_service.dart';
import '../../../views/admin/content_dashboard_page.dart';
import '../admin_guard.dart';

/// Master Developer Dashboard (God-Mode)
/// A secure read-only / request-based admin console. All destructive actions must
/// be submitted to backend-managed `admin_requests`, never executed directly from
/// the client.

class MasterDeveloperDashboardPage extends StatefulWidget {
  const MasterDeveloperDashboardPage({super.key});

  @override
  State<MasterDeveloperDashboardPage> createState() =>
      _MasterDeveloperDashboardPageState();
}

class _MasterDeveloperDashboardPageState
    extends State<MasterDeveloperDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _submitAdminRequest({
    required String action,
    required String resourceType,
    required String resourceId,
    required String reason,
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sessão expirada.')));
      }
      return;
    }

    final requestId =
        'admin_req_${DateTime.now().toUtc().microsecondsSinceEpoch}_${user.uid}';
    await _firestore.collection('admin_requests').add({
      'id': requestId,
      'requestId': requestId,
      'type': action,
      'resourceType': resourceType,
      'resourceId': resourceId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'requestedBy': user.uid,
      'actorUid': user.uid,
      'status': 'pending',
      'result': 'pending',
      'reason': reason,
      'details': {
        'source': 'master_developer_dashboard',
        ...(details ?? const {}),
      },
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ação "$action" enviada para processamento autorizado.',
          ),
        ),
      );
    }
  }

  // User management actions
  Future<void> _banUser(String userId) async {
    await _submitAdminRequest(
      action: 'ban_user',
      resourceType: 'user',
      resourceId: userId,
      reason: 'Solicitação de banimento emitida do painel master.',
    );
  }

  Future<void> _deleteUser(String userId) async {
    await _submitAdminRequest(
      action: 'delete_user',
      resourceType: 'user',
      resourceId: userId,
      reason: 'Solicitação de exclusão de usuário emitida do painel master.',
    );
  }

  Future<void> _exportDeadLetter() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/outbox_deadletter.json';
    await OutboxService.instance.exportDeadLetterToFile(path);
    await _submitAdminRequest(
      action: 'export_deadletter',
      resourceType: 'system',
      resourceId: path,
      reason: 'Exportação de dead-letter solicitada.',
      details: {'exportPath': path},
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Dead-letter exportado: $path')));
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Master Developer Dashboard')),
        body: _buildDashboard(),
      ),
    );
  }

  Widget _buildDashboard() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.primary,
            child: TabBar(
              isScrollable: true,
              tabs: const [
                Tab(text: 'Clientes'),
                Tab(text: 'Operações'),
                Tab(text: 'CMS'),
                Tab(text: 'Auditoria'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUsersTab(),
                _buildOperationsTab(),
                _buildCmsTab(),
                _buildAuditTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operações do Carnaval',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Painel de controle operacional exclusivo para o modo mestre. Aqui ficam as métricas, alertas e gestão de vendas em produção.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _MetricTile(
                label: 'Ingressos',
                value: '1.248',
                color: Colors.blue,
              ),
              _MetricTile(
                label: 'Vendas Hoje',
                value: 'R\$ 84.5k',
                color: Colors.green,
              ),
              _MetricTile(label: 'Alertas', value: '03', color: Colors.orange),
              _MetricTile(
                label: 'Operação',
                value: 'Online',
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCmsTab() {
    return const ContentDashboardPage(embedded: true);
  }

  Widget _buildAuditTab() {
    return Column(
      children: [
        Expanded(child: _buildInteractionsTab()),
        const Divider(),
        SizedBox(height: 250, child: _buildOutboxTab()),
      ],
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar por nome ou email',
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['name'] as String?)?.toLowerCase() ?? '';
                final email = (data['email'] as String?)?.toLowerCase() ?? '';
                if (_search.isEmpty) return true;
                return name.contains(_search) ||
                    email.contains(_search) ||
                    d.id.contains(_search);
              }).toList();
              if (filtered.isEmpty)
                return const Center(child: Text('Nenhum usuário encontrado'));
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['name'] as String? ?? d.id),
                    subtitle: Text(data['email'] as String? ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.block, color: Colors.orange),
                          onPressed: () => _banUser(d.id),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteUser(d.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('Nenhuma postagem'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final created = data['createdAt'];
            return ExpansionTile(
              title: Text('Post ${d.id} — ${data['authorId'] ?? 'unknown'}'),
              subtitle: Text('${data['content'] ?? ''}'),
              children: [
                ListTile(
                  title: Text(
                    'Criado em: ${created is Timestamp ? created.toDate() : created ?? 'n/a'}',
                  ),
                ),
                FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('posts')
                      .doc(d.id)
                      .collection('comments')
                      .get(),
                  builder: (c, cs) {
                    final comments = cs.data?.docs ?? [];
                    return Column(
                      children: comments.map((cm) {
                        final cd = cm.data() as Map<String, dynamic>;
                        final cAt = cd['createdAt'];
                        return ListTile(
                          title: Text(cd['text'] as String? ?? ''),
                          subtitle: Text(
                            'por ${cd['authorId'] ?? 'unknown'} — ${cAt is Timestamp ? cAt.toDate() : cAt ?? ''}',
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOutboxTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: OutboxService.instance.readDeadLetter(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final items = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportDeadLetter,
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar dead-letter'),
                  ),
                  const SizedBox(width: 12),
                  Text('Itens: ${items.length}'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(it['type'] as String? ?? 'unknown'),
                    subtitle: Text(
                      'id: ${it['id'] ?? 'n/a'} — reason: ${it['deadReason'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(it['deadLetterAt'] ?? ''),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        color: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
