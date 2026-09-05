import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../theme/la_bomba_design_system.dart';
import '../../../services/storage_platform.dart';
import '../../../services/storage_service.dart';
import '../../../services/outbox_service.dart';
import '../../social/models/post_interaction_model.dart';
import '../services/reaction_service.dart';
import 'stories_carousel.dart';
import '../../../services/post_service.dart';

import 'package:flutter/services.dart';

/// Social feed page. Shows posts from 'posts' collection and allows simple
/// interactions (add reaction, add comment, delete by author).
class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storage = PlatformStorageService();
  bool _onlyCloseFriends = false;

  // pagination with cursor-based snapshots, not a growing limit value.
  static const int _pageSize = 20;
  DocumentSnapshot<Map<String, dynamic>>? _lastVisiblePost;
  bool _hasMorePosts = true;
  bool _loadingMorePosts = false;

  // Memoized future to prevent rebuild-triggered duplicate queries
  Future<QuerySnapshot<Map<String, dynamic>>>? _cachedCurrentPageFuture;
  bool _lastLoadHadError = false;
  int _connectionGeneration = 0;

  String? get _currentUid => context.read<AuthService>().currentUser?.uid;

  // Keys for cached posts
  String _postsCacheKey() => 'social:posts_cache_v1';

  Future<QuerySnapshot<Map<String, dynamic>>> _loadPostsPage() async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_lastVisiblePost != null) {
      query = query.startAfterDocument(_lastVisiblePost!);
    }

    final snapshot = await query.get();
    await _persistPostsCache(snapshot.docs);
    return snapshot;
  }

  Future<void> _refresh() async {
    _connectionGeneration++;
    setState(() {
      _lastVisiblePost = null;
      _hasMorePosts = true;
      _loadingMorePosts = false;
      _cachedCurrentPageFuture = null; // Reset memoized future on refresh
      _lastLoadHadError = false;
    });
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _loadMore() async {
    if (_loadingMorePosts || !_hasMorePosts) return;
    setState(() => _loadingMorePosts = true);
    final currentGen = _connectionGeneration;
    try {
      final snap = await _loadPostsPage();
      if (!mounted || _connectionGeneration != currentGen) return;
      final docs = snap.docs;
      if (docs.isEmpty) {
        setState(() => _hasMorePosts = false);
        return;
      }
      setState(() {
        _lastVisiblePost = docs.last;
        _hasMorePosts = docs.length >= _pageSize;
        _lastLoadHadError = false;
      });
    } catch (e) {
      if (mounted && _connectionGeneration == currentGen) {
        setState(() {
          _lastLoadHadError = true;
        });
      }
    } finally {
      if (mounted && _connectionGeneration == currentGen) {
        setState(() => _loadingMorePosts = false);
      }
    }
  }

  Future<void> _persistPostsCache(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    try {
      final list = docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        // Normalize nested timestamps inside comments/reactions to ISO strings
        if (data['comments'] is List) {
          data['comments'] = (data['comments'] as List).map((c) {
            final m = Map<String, dynamic>.from(c as Map);
            final created = m['createdAt'];
            if (created is Timestamp)
              m['createdAt'] = created.toDate().toIso8601String();
            return m;
          }).toList();
        }
        if (data['reactions'] is List) {
          data['reactions'] = (data['reactions'] as List).map((r) {
            final m = Map<String, dynamic>.from(r as Map);
            final created = m['createdAt'];
            if (created is Timestamp)
              m['createdAt'] = created.toDate().toIso8601String();
            return m;
          }).toList();
        }
        return {'id': d.id, 'data': data};
      }).toList(growable: false);
      await _storage.write(key: _postsCacheKey(), value: jsonEncode(list));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _readCachedPosts() async {
    try {
      final raw = await _storage.read(key: _postsCacheKey());
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded =
          (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      return decoded
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  PostInteraction _mapToInteractionFromCache(Map<String, dynamic> entry) {
    final id = entry['id'] as String? ?? '';
    final data = Map<String, dynamic>.from(
      entry['data'] as Map<String, dynamic>? ?? {},
    );

    final commentsRaw = data['comments'] as List<dynamic>? ?? [];
    final reactionsRaw = data['reactions'] as List<dynamic>? ?? [];

    final comments = commentsRaw.map((c) {
      final map = Map<String, dynamic>.from(c as Map);
      final createdStr = map['createdAt'] as String?;
      final createdAt = createdStr != null
          ? DateTime.tryParse(createdStr) ?? DateTime.now()
          : DateTime.now();
      return Comment(
        id: map['id'] as String,
        authorId: map['authorId'] as String,
        text: map['text'] as String,
        createdAt: createdAt,
        deleted: map['deleted'] as bool? ?? false,
      );
    }).toList();

    final reactions = reactionsRaw.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final createdStr = map['createdAt'] as String?;
      final createdAt = createdStr != null
          ? DateTime.tryParse(createdStr) ?? DateTime.now()
          : DateTime.now();
      return Reaction(
        id: map['id'] as String,
        userId: map['userId'] as String,
        type: map['type'] as String,
        createdAt: createdAt,
      );
    }).toList();

    return PostInteraction(
      postId: id,
      comments: comments,
      reactions: reactions,
    );
  }

  /// Build feed UI from cached posts (used when network fails).
  Widget _buildFeedFromCache(List<Map<String, dynamic>> cached) {
    return FutureBuilder<List<String>>(
      future: _fetchCloseFriends(),
      builder: (context, cfSnap) {
        final closeFriends = cfSnap.data ?? <String>[];
        final entries = cached
            .map<MapEntry<Map<String, dynamic>, PostInteraction>>(
              (e) => MapEntry<Map<String, dynamic>, PostInteraction>(
                Map<String, dynamic>.from(e),
                _mapToInteractionFromCache(e),
              ),
            )
            .toList();
        final filtered = entries.where((entry) {
          if (!_onlyCloseFriends) return true;
          final data = entry.key['data'] as Map<String, dynamic>?;
          final author = data != null ? data['authorId'] as String? : null;
          return author != null && closeFriends.contains(author);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('Nenhuma postagem encontrada'),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              StoriesCarousel(),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length + (_hasMorePosts ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == filtered.length) {
                    if (_lastLoadHadError) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('Falha ao carregar mais postagens'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadMore,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      );
                    }
                    return Center(
                      child: _loadingMorePosts
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            )
                          : TextButton(
                              onPressed: _loadMore,
                              child: const Text('Carregar mais'),
                            ),
                    );
                  }
                  final entry = filtered[index].key;
                  final post = filtered[index].value;
                  final docId = entry['id'] as String;
                  return _buildPostCard(post, docId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Feed Social'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LaBombaColors.card.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: LaBombaColors.borderSoft),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite_border_rounded,
                    size: 16, color: LaBombaColors.primary),
                const SizedBox(width: 6),
                const Text('Melhores amigos',
                    style: TextStyle(
                        fontSize: 12, color: LaBombaColors.textSecondary)),
                const SizedBox(width: 4),
                Switch(
                  value: _onlyCloseFriends,
                  onChanged: (v) => setState(() => _onlyCloseFriends = v),
                  activeTrackColor: LaBombaColors.primary,
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _cachedCurrentPageFuture ??= _loadPostsPage(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _lastVisiblePost == null) {
              return const LaBombaLoadingState(label: 'Sincronizando o feed');
            }

            if (snapshot.hasError && _lastVisiblePost == null) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _readCachedPosts(),
                builder: (context, cacheSnap) {
                  if (cacheSnap.connectionState == ConnectionState.waiting) {
                    return const LaBombaLoadingState(
                        label: 'Preparando conteúdo');
                  }
                  final cached = cacheSnap.data ?? <Map<String, dynamic>>[];
                  if (cached.isEmpty) {
                    return LaBombaErrorState(
                      title: 'Não conseguimos carregar o feed',
                      message:
                          'Verifique sua conexão e tente novamente em alguns instantes.',
                      onRetry: () {
                        setState(() {
                          _cachedCurrentPageFuture = null;
                          _lastLoadHadError = false;
                        });
                      },
                    );
                  }

                  return _buildFeedFromCache(cached);
                },
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _readCachedPosts(),
                builder: (context, cacheSnap) {
                  final cached = cacheSnap.data ?? <Map<String, dynamic>>[];
                  if (cached.isEmpty) {
                    return LaBombaEmptyState(
                      title: 'Ainda não há conteúdo por aqui',
                      message:
                          'Quando os foliões compartilharem memórias e avisos, eles aparecerão aqui.',
                      icon: Icons.celebration_rounded,
                    );
                  }
                  return _buildFeedFromCache(cached);
                },
              );
            }

            final docs = snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            return FutureBuilder<List<String>>(
              future: _fetchCloseFriends(),
              builder: (context, cfSnap) {
                final closeFriends = cfSnap.data ?? <String>[];

                final seenPostIds = <String>{};
                final entries = docs
                    .where((d) => seenPostIds.add(d.id))
                    .map((d) => MapEntry(d, _docToInteraction(d)))
                    .toList();

                final filtered = entries.where((entry) {
                  if (!_onlyCloseFriends) return true;
                  final d = entry.key;
                  final author = (d.data()
                      as Map<String, dynamic>?)?['authorId'] as String?;
                  return author != null && closeFriends.contains(author);
                }).toList();

                if (filtered.isEmpty)
                  return LaBombaEmptyState(
                    title: 'Nenhuma publicação por enquanto',
                    message:
                        'Abra espaço para memórias, fotos e momentos da turma.',
                    icon: Icons.photo_library_outlined,
                  );

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      StoriesCarousel(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length + (_hasMorePosts ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            return Center(
                              child: _loadingMorePosts
                                  ? const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    )
                                  : TextButton(
                                      onPressed: _loadMore,
                                      child: const Text('Carregar mais'),
                                    ),
                            );
                          }
                          final doc = filtered[index].key;
                          final post = filtered[index].value;
                          return _buildPostCard(post, doc.id);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<String>> _fetchCloseFriends() async {
    try {
      final uid = _currentUid;
      if (uid == null) return <String>[];
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final raw = data['closeFriends'] as List<dynamic>?;
      return raw?.map((e) => e as String).toList() ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  PostInteraction _docToInteraction(QueryDocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    final postId = d.id;
    final commentsRaw = data['comments'] as List<dynamic>? ?? [];
    final reactionsRaw = data['reactions'] as List<dynamic>? ?? [];

    final comments = commentsRaw.map((c) {
      final map = Map<String, dynamic>.from(c as Map);
      final created = map['createdAt'];
      DateTime createdAt;
      if (created is Timestamp) {
        createdAt = created.toDate();
      } else if (created is String) {
        createdAt = DateTime.tryParse(created) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
      return Comment(
        id: map['id'] as String,
        authorId: map['authorId'] as String,
        text: map['text'] as String,
        createdAt: createdAt,
        deleted: map['deleted'] as bool? ?? false,
      );
    }).toList();

    final reactions = reactionsRaw.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final created = map['createdAt'];
      DateTime createdAt;
      if (created is Timestamp) {
        createdAt = created.toDate();
      } else if (created is String) {
        createdAt = DateTime.tryParse(created) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
      return Reaction(
        id: map['id'] as String,
        userId: map['userId'] as String,
        type: map['type'] as String,
        createdAt: createdAt,
      );
    }).toList();

    return PostInteraction(
      postId: postId,
      comments: comments,
      reactions: reactions,
    );
  }

  Widget _buildPostCard(PostInteraction post, String docId) {
    final summary = post.reactionsSummary();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LaBombaColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(LaBombaRadius.lg),
        border:
            Border.all(color: LaBombaColors.borderSoft.withValues(alpha: 0.75)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0A1220),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: LaBombaColors.primary.withValues(alpha: 0.18),
                child: const Icon(Icons.person, color: LaBombaColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Folião ${post.postId.substring(0, 5)}',
                      style: const TextStyle(
                        color: LaBombaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Há alguns minutos',
                      style: TextStyle(
                        color: LaBombaColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: LaBombaColors.textSecondary),
                onSelected: (v) async {
                  if (v == 'refresh')
                    setState(() {});
                  else if (v == 'edit')
                    await _editPost(docId);
                  else if (v == 'delete')
                    await _deletePost(docId);
                  else if (v == 'save')
                    await _savePost(docId);
                  else if (v == 'hide')
                    await _hidePost(docId);
                  else if (v == 'report')
                    await _reportPost(docId);
                  else if (v == 'share') await _sharePost(docId);
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(
                      value: 'refresh', child: Text('Atualizar')),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  const PopupMenuItem(value: 'save', child: Text('Salvar')),
                  const PopupMenuItem(value: 'hide', child: Text('Ocultar')),
                  const PopupMenuItem(
                      value: 'report', child: Text('Denunciar')),
                  const PopupMenuItem(
                      value: 'share', child: Text('Compartilhar')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('posts').doc(docId).get(),
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final content = data != null && data.containsKey('content')
                  ? data['content'] as String
                  : '';
              return Text(
                content.isNotEmpty
                    ? content
                    : 'Momentos que valem guardar na memória da folia.',
                style: const TextStyle(
                  color: LaBombaColors.textPrimary,
                  fontSize: 15,
                  height: 1.55,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2A44), Color(0xFF101B32)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: LaBombaColors.borderSoft),
            ),
            child: Row(
              children: [
                _ActionPill(
                  icon: Icons.favorite_rounded,
                  label: '${summary['like'] ?? 0}',
                  onTap: () => _addReaction(docId, 'like'),
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.activeCommentsCount}',
                  onTap: () => _showAddCommentDialog(docId),
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.share_outlined,
                  label: 'Compartilhar',
                  onTap: () => _sharePost(docId),
                ),
              ],
            ),
          ),
          if (post.comments.where((c) => !c.deleted).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Comentários',
              style: TextStyle(
                color: LaBombaColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...post.comments.where((c) => !c.deleted).take(2).map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LaBombaColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: LaBombaColors.borderSoft.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          LaBombaColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        c.authorId.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: LaBombaColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Folião • ${DateTime.now().difference(c.createdAt).inMinutes < 60 ? '${DateTime.now().difference(c.createdAt).inMinutes}m' : 'recentemente'}',
                                  style: const TextStyle(
                                    color: LaBombaColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (_canDeleteComment(c, post))
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _deleteComment(docId, c),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.text,
                            style: const TextStyle(
                              color: LaBombaColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _ActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: LaBombaColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: LaBombaColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canDeleteComment(Comment c, PostInteraction post) {
    final uid = _currentUid;
    if (uid == null) return false;
    // author of comment or author of post (post.postId used as identifier here)
    return c.authorId == uid || post.postId == uid;
  }

  // --- Post actions: edit/delete/save/hide/report/share
  Future<void> _editPost(String postId) async {
    final uid = _currentUid;
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      final data = doc.data();
      if (data == null) return;
      if (uid != data['userId']) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sem permissão para editar')),
          );
        return;
      }
      final current = data['content'] as String? ?? '';
      final controller = TextEditingController(text: current);
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Editar postagem'),
          content: TextField(controller: controller, maxLines: 5),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (save != true) return;
      final newContent = controller.text.trim();
      await _firestore.collection('posts').doc(postId).update({
        'content': newContent,
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post atualizado')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao editar post')));
    }
  }

  Future<void> _deletePost(String postId) async {
    final uid = _currentUid;
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      final data = doc.data();
      if (data == null) return;
      if (uid != data['userId']) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sem permissão para excluir')),
          );
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir postagem'),
          content: const Text('Tem certeza que deseja excluir esta postagem?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await PostService().deletePost(postId);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post excluído')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao excluir post')));
    }
  }

  Future<void> _savePost(String postId) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final meRef = _firestore.collection('users').doc(uid);
      await meRef.update({
        'savedPosts': FieldValue.arrayUnion([postId]),
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post salvo')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao salvar post')));
    }
  }

  Future<void> _hidePost(String postId) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final meRef = _firestore.collection('users').doc(uid);
      await meRef.update({
        'hiddenPosts': FieldValue.arrayUnion([postId]),
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post ocultado')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao ocultar post')));
    }
  }

  Future<void> _reportPost(String postId) async {
    final uid = _currentUid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faça login para denunciar.')),
        );
      }
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitReport');
      await callable.call(<String, dynamic>{
        'resourceType': 'post',
        'resourceId': postId,
        'category': 'spam',
        'reason': 'Denúncia enviada pelo usuário via feed.',
        'details': {'source': 'social_feed'},
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Denúncia enviada')));
      }
    } catch (_) {
      try {
        await OutboxService.instance.enqueue({
          'type': 'report_post',
          'payload': {'postId': postId, 'reporterId': uid},
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Denúncia agendada')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao denunciar')),
          );
        }
      }
    }
  }

  Future<void> _sharePost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      final data = doc.data();
      final content = data?['content'] as String? ?? '';
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conteúdo copiado para área de transferência'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao compartilhar')));
    }
  }

  Future<void> _addReaction(String postId, String type) async {
    final uid = _currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Faça login para reagir.')));
      return;
    }
    try {
      await ReactionService().toggleReactionOnPost(
        postId: postId,
        userId: uid,
        emoji: type,
      );
    } catch (e) {
      // enqueue to outbox as fallback for offline
      try {
        final id = '$uid:${DateTime.now().millisecondsSinceEpoch}';
        await OutboxService.instance.enqueue({
          'id': 'post_reaction_add:${postId}:$id',
          'type': 'post_reaction_add',
          'payload': {
            'postId': postId,
            'reaction': {
              'id': id,
              'userId': uid,
              'type': type,
              'createdAt': DateTime.now().toIso8601String(),
            },
          },
          'createdAt': DateTime.now().toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reação enfileirada e será sincronizada quando online',
            ),
          ),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível registrar a reação.')),
        );
      }
    }
  }

  Future<void> _showAddCommentDialog(String postId) async {
    final uid = _currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para comentar.')),
      );
      return;
    }
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar comentário'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (send != true) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final id = '$uid:${DateTime.now().millisecondsSinceEpoch}';
    final map = {
      'id': id,
      'authorId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    };
    try {
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([map]),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Comentário enviado')));
    } catch (e) {
      try {
        await OutboxService.instance.enqueue({
          'id': 'post_comment_add:${postId}:${map['id']}',
          'type': 'post_comment_add',
          'payload': {'postId': postId, 'comment': map},
          'createdAt': DateTime.now().toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comentário enfileirado e será sincronizado quando online',
            ),
          ),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao enviar comentário')),
        );
      }
    }
  }

  Future<void> _deleteComment(String postId, Comment comment) async {
    // Attempt to remove the exact comment object from the array (requires exact match)
    final map = {
      'id': comment.id,
      'authorId': comment.authorId,
      'text': comment.text,
      'createdAt': Timestamp.fromDate(comment.createdAt),
      'deleted': comment.deleted,
    };
    try {
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayRemove([map]),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Comentário removido')));
    } catch (e) {
      // If arrayRemove fails (e.g., timestamp mismatch), fallback to marking as deleted
      try {
        await _firestore.collection('posts').doc(postId).update({
          'deletedCommentIds': FieldValue.arrayUnion([comment.id]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário marcado como removido')),
        );
      } catch (_) {
        // enqueue delete attempt
        try {
          final fallbackMap = {
            'id': comment.id,
            'authorId': comment.authorId,
            'text': comment.text,
            'createdAt': comment.createdAt.toIso8601String(),
            'deleted': comment.deleted,
          };
          await OutboxService.instance.enqueue({
            'id':
                'post_comment_delete:${postId}:${comment.id}:${DateTime.now().millisecondsSinceEpoch}',
            'type': 'post_comment_delete',
            'payload': {'postId': postId, 'comment': fallbackMap},
            'createdAt': DateTime.now().toIso8601String(),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Remoção enfileirada e será sincronizada quando online',
              ),
            ),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao remover comentário')),
          );
        }
      }
    }
  }
}
