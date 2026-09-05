import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class FollowRequestsPage extends StatelessWidget {
  const FollowRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = Provider.of<AuthService>(
      context,
      listen: false,
    ).currentUser?.uid;
    if (currentUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitações')),
        body: const Center(child: Text('Não autenticado')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('outgoingFollowRequests', arrayContains: currentUid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitações')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('Nenhuma solicitação'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final requesterId = d.id;
              final displayName = (data['displayName'] as String?) ??
                  (data['name'] as String?) ??
                  'Usuário';
              final avatar =
                  data['avatarUrl'] as String? ?? data['photoURL'] as String?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                title: Text(displayName),
                subtitle: Text('Quer seguir você'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        // accept: add requester to our followers and increment count
                        final meRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUid);
                        try {
                          await meRef.update({
                            'followers': FieldValue.arrayUnion([requesterId]),
                          });
                          // increment followers counter inside the stats map
                          await meRef.update({
                            'stats.followers': FieldValue.increment(1),
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Seguidor aceito')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Falha ao aceitar')),
                          );
                        }
                      },
                      child: const Text('Aceitar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        // decline - we won't be able to remove the outgoing mark from requester, but we can record rejection
                        final meRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUid);
                        try {
                          await meRef.update({
                            'rejectedFollowRequests': FieldValue.arrayUnion([
                              requesterId,
                            ]),
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Solicitação recusada'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Falha ao recusar')),
                          );
                        }
                      },
                      child: const Text('Recusar'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
