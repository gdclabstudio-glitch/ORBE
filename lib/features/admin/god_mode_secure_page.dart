import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_guard.dart';

/// Secure God Mode page (scaffold) that exposes admin-only UI but DOES NOT
/// perform destructive actions directly from the client. Instead it creates
/// documents under `admin_requests` which should be processed by a Cloud
/// Function or admin worker that has the necessary privileges.
class GodModeSecurePage extends StatefulWidget {
  const GodModeSecurePage({super.key});

  @override
  State<GodModeSecurePage> createState() => _GodModeSecurePageState();
}

class _GodModeSecurePageState extends State<GodModeSecurePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _broadcastTitle = TextEditingController();
  final TextEditingController _broadcastBody = TextEditingController();
  bool _sending = false;

  Stream<int> _activeUsersCountStream() {
    // count aggregation is not universally available on all SDKs; fallback to query snapshot length
    return _firestore
        .collection('users')
        .where('presence', isEqualTo: 'online')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _postsTodayCountStream() {
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _firestore
        .collection('posts')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _systemStatusStream() {
    return _firestore.doc('system/status').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _reportsQueue() {
    return _firestore
        .collection('posts')
        .where('reports', isGreaterThan: 0)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _enqueueAdminRequest(Map<String, dynamic> payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final requestId =
        'admin_req_${DateTime.now().toUtc().microsecondsSinceEpoch}_${user.uid}';
    final action = (payload['type'] as String?) ?? 'unknown_action';
    final req = {
      'id': requestId,
      'requestId': requestId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'requestedBy': user.uid,
      'actorUid': user.uid,
      'action': action,
      'status': 'pending',
      'result': 'pending',
      'resourceType':
          payload['resourceType'] ?? _inferResourceTypeFromPayload(payload),
      'resourceId': payload['resourceId'] ??
          payload['postId'] ??
          payload['userId'] ??
          payload['targetId'],
      'reason':
          payload['reason'] ?? 'Admin request submitted from secure dashboard',
      'requestedAt': FieldValue.serverTimestamp(),
      'details': payload,
    };
    await _firestore.collection('admin_requests').add(req);
  }

  String _inferResourceTypeFromPayload(Map<String, dynamic> payload) {
    if (payload.containsKey('userId')) return 'user';
    if (payload.containsKey('postId')) return 'post';
    if (payload.containsKey('targetId')) return 'target';
    if (payload.containsKey('broadcast')) return 'broadcast';
    return 'unknown';
  }

  Future<void> _requestDeletePost(String postId) async {
    await _enqueueAdminRequest({
      'type': 'delete_post',
      'resourceType': 'post',
      'resourceId': postId,
      'postId': postId,
      'reason': 'Solicitação de exclusão de conteúdo por administrador.',
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de exclusão enviada')),
      );
  }

  Future<void> _requestBanUser(String userId) async {
    await _enqueueAdminRequest({
      'type': 'ban_user',
      'resourceType': 'user',
      'resourceId': userId,
      'userId': userId,
      'reason': 'Solicitação de banimento por administrador.',
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação de banimento enviada')),
      );
  }

  Future<void> _requestMassFcm(String title, String body) async {
    setState(() => _sending = true);
    try {
      await _enqueueAdminRequest({
        'type': 'mass_fcm',
        'resourceType': 'broadcast',
        'resourceId': 'mass_fcm',
        'reason': 'Solicitação de envio massivo de notificação.',
        'title': title,
        'body': body,
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação de envio FCM enviada')),
        );
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _toggleFlag(String key, bool value) async {
    await _firestore.collection('admin_config').doc('flags').set({
      key: value,
    }, SetOptions(merge: true));
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuração atualizada')));
  }

  @override
  void dispose() {
    _broadcastTitle.dispose();
    _broadcastBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0A0A),
          title: const Text(
            'God Mode — Painel Executivo',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
              tooltip: 'Sair',
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Metrics
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: const Color(0xFF111214),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: StreamBuilder<int>(
                            stream: _activeUsersCountStream(),
                            builder: (context, snap) {
                              final val = snap.data ?? 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Foliões Ativos',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    val.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: const Color(0xFF111214),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: StreamBuilder<int>(
                            stream: _postsTodayCountStream(),
                            builder: (context, snap) {
                              final val = snap.data ?? 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Posts Hoje',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    val.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: const Color(0xFF111214),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _systemStatusStream(),
                            builder: (context, snap) {
                              final data = snap.data?.data();
                              final ok = data == null
                                  ? '—'
                                  : (data['fcm_ok'] == true
                                      ? 'OK'
                                      : 'Problemas');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status FCM',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ok,
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Moderation queue and controls
                Expanded(
                  child: Card(
                    color: const Color(0xFF0E0E0F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fila de Moderação',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: _reportsQueue(),
                              builder: (context, snap) {
                                if (snap.hasError)
                                  return const Center(
                                    child: Text('Erro ao carregar reports'),
                                  );
                                if (!snap.hasData)
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                final docs = snap.data!.docs;
                                if (docs.isEmpty)
                                  return const Center(
                                    child: Text(
                                      'Nenhum post reportado',
                                      style: TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  );
                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(color: Colors.white12),
                                  itemBuilder: (context, index) {
                                    final d = docs[index];
                                    final data = d.data();
                                    final postId = d.id;
                                    final authorId =
                                        data['userId'] as String? ?? '';
                                    final content = (data['content'] ??
                                        data['text'] ??
                                        '') as String;
                                    final reports =
                                        (data['reports'] ?? 0) as int;
                                    return ListTile(
                                      title: Text(
                                        content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Reports: $reports • Author: $authorId',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _requestDeletePost(postId),
                                            child: const Text(
                                              'Solicitar exclusão',
                                              style: TextStyle(
                                                color: Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () =>
                                                _requestBanUser(authorId),
                                            child: const Text(
                                              'Solicitar ban',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Mass FCM form
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          const Text(
                            'Disparo FCM em Massa',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _broadcastTitle,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Título',
                              hintStyle: TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Color(0xFF141416),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _broadcastBody,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Mensagem',
                              hintStyle: TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Color(0xFF141416),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                  ),
                                  onPressed: _sending
                                      ? null
                                      : () async {
                                          final title =
                                              _broadcastTitle.text.trim();
                                          final body =
                                              _broadcastBody.text.trim();
                                          if (title.isEmpty || body.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Preencha título e mensagem',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          // Require long-press confirmation: show confirmation dialog
                                          final sure = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Confirmar envio em massa',
                                              ),
                                              content: const Text(
                                                'Enviar notificação para todos os dispositivos é uma ação sensível. Confirma?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text(
                                                    'Confirmar',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (sure == true)
                                            await _requestMassFcm(title, body);
                                        },
                                  child: Text(
                                    _sending
                                        ? 'Enviando...'
                                        : 'Enviar (Requer confirmação)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Master toggles
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: const Color(0xFF111214),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Configurações Master',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Ativar Abadá 2026',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  Switch(
                                    value: false,
                                    onChanged: (v) =>
                                        _toggleFlag('abadá_2026_enabled', v),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Limpar Cache',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _firestore
                                          .collection('admin_requests')
                                          .add({
                                        'type': 'clear_cache',
                                        'createdAt':
                                            FieldValue.serverTimestamp(),
                                        'createdBy': FirebaseAuth
                                            .instance.currentUser?.uid,
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Solicitação de limpeza de cache enviada',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Solicitar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
