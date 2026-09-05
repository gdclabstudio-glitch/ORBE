import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/group_service.dart';

class GroupChannelPage extends StatefulWidget {
  final String? groupId;
  final FirebaseFirestore? firestore;
  const GroupChannelPage({super.key, this.groupId, this.firestore});

  @override
  State<GroupChannelPage> createState() => _GroupChannelPageState();
}

class _GroupChannelPageState extends State<GroupChannelPage> {
  late final GroupService _service;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = GroupService(firestore: widget.firestore);
  }

  @override
  Widget build(BuildContext context) {
    final gid = widget.groupId;
    if (gid == null) {
      // Show list of groups
      return Scaffold(
        appBar: AppBar(title: const Text('Canais')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.groupsStream(),
          builder: (context, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty)
              return const Center(child: Text('Nenhum canal encontrado'));
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final d = docs[index];
                final name = (d.data()['name'] as String?) ?? 'Canal';
                final desc = (d.data()['description'] as String?) ?? '';
                return ListTile(
                  title: Text(name),
                  subtitle: Text(desc),
                  onTap: () => Navigator.pushNamed(context, '/group/${d.id}'),
                );
              },
            );
          },
        ),
      );
    }

    // Chat view for a specific group
    return Scaffold(
      appBar: AppBar(title: Text('Canal')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.messagesStream(gid),
              builder: (context, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty)
                  return const Center(child: Text('Nenhuma mensagem ainda'));
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final text = data['text'] as String? ?? '';
                    final sender = data['senderId'] as String? ?? 'anônimo';
                    return ListTile(title: Text(text), subtitle: Text(sender));
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Mensagem para o canal',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final text = _ctrl.text.trim();
                    if (text.isEmpty) return;
                    try {
                      await _service.sendMessage(gid, {
                        'text': text,
                        'senderId': 'me',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      _ctrl.clear();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Falha ao enviar')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
