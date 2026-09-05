import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/post_service.dart';

class GodModeContentPage extends StatefulWidget {
  const GodModeContentPage({super.key});

  @override
  State<GodModeContentPage> createState() => _GodModeContentPageState();
}

class _GodModeContentPageState extends State<GodModeContentPage> {
  final PostService _postService = PostService();

  void _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1B2E),
        title: const Text(
          'Excluir Postagem',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja apagar esta postagem definitivamente?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _postService.deletePost(postId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Postagem excluída com sucesso.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao excluir postagem.')),
          );
        }
      }
    }
  }

  void _togglePin(Post post) async {
    try {
      await _postService.togglePinPost(post.id, !post.isPinned);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao alterar fixação.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: _postService.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('Sem postagens.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          padding: const EdgeInsets.all(16.0),
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              color: const Color(0xFF1F1B2E),
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                title: Text(
                  post.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      post.content,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${post.id}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        post.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: post.isPinned ? Colors.redAccent : Colors.grey,
                      ),
                      onPressed: () => _togglePin(post),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePost(post.id),
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
