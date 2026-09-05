import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RankingPage extends StatelessWidget {
  final FirebaseFirestore? firestore;
  const RankingPage({super.key, this.firestore});

  FirebaseFirestore get _fs => firestore ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking Semanal')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs
            .collection('userStats')
            .orderBy('score', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(data['displayName'] as String? ?? 'Usuário'),
                trailing: Text('${data['score'] ?? 0} pts'),
              );
            },
          );
        },
      ),
    );
  }
}
