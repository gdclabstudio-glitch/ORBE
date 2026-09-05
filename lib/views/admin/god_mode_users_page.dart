import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/client.dart';

class GodModeUsersPage extends StatefulWidget {
  const GodModeUsersPage({super.key});

  @override
  State<GodModeUsersPage> createState() => _GodModeUsersPageState();
}

class _GodModeUsersPageState extends State<GodModeUsersPage> {
  final CollectionReference _clientsCollection = FirebaseFirestore.instance
      .collection('clients'); // Default collection name

  void _toggleBan(String clientId, bool currentBanStatus) {
    // Exemplo de como um banimento funcionaria (adicionando um field 'isBanned' no Firestore)
    _clientsCollection.doc(clientId).update({'isBanned': !currentBanStatus});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !currentBanStatus ? 'Usuário banido' : 'Usuário desbanido',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _clientsCollection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar usuários',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum usuário encontrado.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16.0),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final client = Client.fromJson({'id': doc.id, ...data});
            final isBanned = data['isBanned'] == true;

            return Card(
              color: const Color(0xFF1F1B2E),
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isBanned ? Colors.red : Colors.grey[800],
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  client.fullName,
                  style: TextStyle(
                    color: isBanned ? Colors.red : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.phone,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'ID: ${client.id}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: const Color(0xFF1F1B2E),
                  onSelected: (value) {
                    if (value == 'ban') {
                      _toggleBan(client.id, isBanned);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'ban',
                      child: Text(
                        isBanned ? 'Desbanir Usuário' : 'Banir Usuário',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'promote',
                      child: Text(
                        'Promover a Admin',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
