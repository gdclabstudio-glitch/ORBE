import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final FirebaseFirestore? firestore;
  const ChatPage({super.key, required this.chatId, this.firestore});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  late final ChatService _service;

  @override
  void initState() {
    super.initState();
    _service = ChatService(firestore: widget.firestore);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat ${widget.chatId}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.messagesStream(widget.chatId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text('Erro ao carregar mensagens.'),
                      ],
                    ),
                  );
                }
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final isRead = data['isRead'] as bool? ?? false;
                    final deliveredAt = data['deliveredAt'];
                    return ListTile(
                      title: Text(data['text'] as String? ?? ''),
                      subtitle: Text(
                        '${data['senderId'] as String? ?? ''}${deliveredAt != null ? ' • entregue' : ''}',
                      ),
                      trailing: isRead
                          ? const Icon(Icons.done_all, color: Colors.blue)
                          : (deliveredAt != null
                              ? const Icon(Icons.done, color: Colors.grey)
                              : const SizedBox.shrink()),
                    );
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
                    decoration: const InputDecoration(hintText: 'Mensagem'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final text = _ctrl.text.trim();
                    if (text.isEmpty) return;
                    await _service.sendMessage(widget.chatId, {
                      'text': text,
                      'createdAt': FieldValue.serverTimestamp(),
                      'senderId': 'me',
                    });
                    _ctrl.clear();
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
