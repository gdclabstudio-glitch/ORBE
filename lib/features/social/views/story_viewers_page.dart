import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../chat/services/chat_service.dart';
import '../../admin/admin_guard.dart';

class StoryViewersPage extends StatelessWidget {
  final String ownerId;
  final String storyId;
  final FirebaseFirestore? firestore;

  const StoryViewersPage({
    super.key,
    required this.ownerId,
    required this.storyId,
    this.firestore,
  });

  FirebaseFirestore get _fs => firestore ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visualizações')),
        body: const Center(
          child: Text('Faça login para ver os visualizadores'),
        ),
      );
    }

    final isOwner = user.uid == ownerId;
    final page = _ViewersList(
      ownerId: ownerId,
      storyId: storyId,
      firestore: _fs,
    );
    if (isOwner) return page;

    return AdminGuard(
      child: page,
      onDenied: Scaffold(
        appBar: AppBar(title: const Text('Visualizações')),
        body: const Center(
          child: Text(
            'Você não tem permissão para ver os visualizadores desse story.',
          ),
        ),
      ),
    );
  }
}

class _ViewersList extends StatefulWidget {
  final String ownerId;
  final String storyId;
  final FirebaseFirestore firestore;

  const _ViewersList({
    required this.ownerId,
    required this.storyId,
    required this.firestore,
  });

  @override
  State<_ViewersList> createState() => _ViewersListState();
}

class _ViewersListState extends State<_ViewersList> {
  static const int _pageSize = 25;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;

  Future<QuerySnapshot<Map<String, dynamic>>> _viewsPage() async {
    Query<Map<String, dynamic>> query = widget.firestore
        .collection('users')
        .doc(widget.ownerId)
        .collection('stories')
        .doc(widget.storyId)
        .collection('views')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    return query.get();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await _viewsPage();
      final docs = snap.docs;
      if (!mounted) return;
      setState(() {
        _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
        _hasMore = docs.length >= _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    try {
      final doc = await widget.firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visualizações')),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _viewsPage(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data == null || snap.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma visualização ainda'));
          }

          final docs = snap.data!.docs;
          final count = docs.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Visualizações: $count',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${docs.isNotEmpty ? docs.last.data()['createdAt'] ?? '' : ''}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == docs.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : TextButton.icon(
                                  onPressed: _loadMore,
                                  icon: const Icon(Icons.expand_more),
                                  label: const Text('Carregar mais'),
                                ),
                        ),
                      );
                    }

                    final doc = docs[index];
                    final viewerId = doc.data()['viewerId'] as String? ??
                        (doc.data()['viewer'] as String? ?? 'unknown');
                    final ts = doc.data()['createdAt'];
                    return ListTile(
                      leading: FutureBuilder<Map<String, dynamic>?>(
                        future: _loadProfile(viewerId),
                        builder: (c, p) {
                          final data = p.data;
                          final avatar = data?['photoURL'] as String? ??
                              data?['authorPhoto'] as String?;
                          final name = (data?['displayName'] as String?) ??
                              (data?['authorName'] as String?) ??
                              viewerId;
                          if (p.connectionState == ConnectionState.waiting) {
                            return const CircleAvatar(
                              child: SizedBox.square(dimension: 10),
                            );
                          }
                          return CircleAvatar(
                            backgroundImage:
                                avatar != null ? NetworkImage(avatar) : null,
                            child: avatar == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                  )
                                : null,
                          );
                        },
                      ),
                      title: FutureBuilder<Map<String, dynamic>?>(
                        future: _loadProfile(viewerId),
                        builder: (c, p) {
                          final data = p.data;
                          final name = (data?['displayName'] as String?) ??
                              (data?['authorName'] as String?) ??
                              viewerId;
                          return Text(name);
                        },
                      ),
                      subtitle: Text(_formatTimestamp(ts)),
                      trailing: IconButton(
                        icon: const Icon(Icons.message_outlined),
                        onPressed: () async {
                          final current = FirebaseAuth.instance.currentUser;
                          if (current == null) return;
                          final roomId = ChatService.privateRoomId(
                            current.uid,
                            viewerId,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPageShim(roomId: roomId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      DateTime dt;
      if (ts is Timestamp)
        dt = ts.toDate();
      else if (ts is String)
        dt = DateTime.parse(ts);
      else if (ts is DateTime)
        dt = ts;
      else
        return '';
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// Lightweight ChatPage shim to navigate to chat — reuse existing chat UI if available
class ChatPageShim extends StatelessWidget {
  final String roomId;
  const ChatPageShim({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    // The project has multiple ChatPage implementations; try to locate a common one via routes
    // If a ChatPage exists under features/chat/views/chat_page.dart it can be used. Here we navigate by route name if present.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(body: Center(child: Text('Chat room: $roomId'))),
      ),
    );
    return const SizedBox.shrink();
  }
}
