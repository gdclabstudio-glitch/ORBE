import 'package:flutter/material.dart';

import '../widgets/reaction_bar.dart';
import '../features/social/services/reaction_service.dart';

import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class PostCard extends StatelessWidget {
  final String userName;
  final String timeAgo;
  final String content;
  final String? avatarUrl;
  final String? postId;

  const PostCard({
    super.key,
    required this.userName,
    required this.timeAgo,
    required this.content,
    this.avatarUrl,
    this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B2E),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[800],
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      timeAgo,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12.0),
          // Reaction bar and actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: postId == null
                    ? ReactionBar(
                        onChanged: (emoji, added) {
                          debugPrint(
                            'Reaction $emoji toggled: $added (no postId)',
                          );
                        },
                      )
                    : StreamBuilder<Map<String, int>>(
                        stream: ReactionService().reactionsCountStream(postId!),
                        builder: (context, snap) {
                          final counts = snap.data ?? <String, int>{};
                          return ReactionBar(
                            initialCounts: counts,
                            onChanged: (emoji, added) async {
                              final auth = context.read<AuthService>();
                              final uid = auth.currentUser?.uid;
                              if (uid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Faça login para reagir.'),
                                  ),
                                );
                                return;
                              }
                              try {
                                await ReactionService().toggleReactionOnPost(
                                  postId: postId!,
                                  userId: uid,
                                  emoji: emoji,
                                );
                              } catch (e) {
                                debugPrint('Reaction update failed: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Falha ao atualizar reação'),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) {
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Comentários',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Comentários ainda não implementados.',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          hintText: 'Escreva um comentário...',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      icon: const Icon(Icons.send),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.comment, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
