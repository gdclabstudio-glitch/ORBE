import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../models/community_node.dart';
import '../models/community_node_social_orb.dart';
import '../models/orb_universe.dart';
import '../services/interaction_score_service.dart';
import '../widgets/community_bubble_map.dart';
import 'orb_universe_page.dart';

class CommunityPage extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const CommunityPage({super.key, this.firestore});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  FirebaseFirestore get _firestore =>
      widget.firestore ?? FirebaseFirestore.instance;

  String _query = '';
  String? _selectedTag;

  String? _safeCurrentUserId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String? _safeCurrentUserDisplayName() {
    try {
      return FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      return null;
    }
  }

  String? _safeCurrentUserPhotoUrl() {
    try {
      return FirebaseAuth.instance.currentUser?.photoURL;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LaBombaColors.obsidian,
      appBar: AppBar(
        title: const Text('Comunidade'),
        backgroundColor: Colors.transparent,
        foregroundColor: LaBombaColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Encontrar pessoas',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: LaBombaDecorations.shell,
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('users')
                .orderBy('displayName')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: LaBombaEmptyState(
                    title: 'Erro na comunidade',
                    message: 'Não foi possível carregar o universo social.',
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = snapshot.data!.docs;
              final currentUserId = _safeCurrentUserId();
              QueryDocumentSnapshot<Map<String, dynamic>>? currentUserDoc;
              for (final doc in allUsers) {
                if (doc.id == currentUserId) {
                  currentUserDoc = doc;
                  break;
                }
              }

              final filteredDocs = allUsers.where((doc) {
                final data = doc.data();
                final name = (data['displayName'] as String?) ??
                    (data['name'] as String?) ??
                    'Usuário';
                final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ??
                    <String>[];

                final normalizedName = name.toLowerCase();
                final matchesQuery = _query.isEmpty ||
                    normalizedName.contains(_query.toLowerCase());
                final matchesTag = _selectedTag == null ||
                    _selectedTag == 'Todos' ||
                    tags.contains(_selectedTag);

                return matchesQuery && matchesTag;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: LaBombaEmptyState(
                    title: 'Seu universo começa aqui.',
                    message:
                        'Encontre pessoas, conecte-se e veja sua comunidade ganhar vida.',
                    action: FilledButton.tonal(
                      onPressed: () => setState(() => _query = ''),
                      child: const Text('Encontrar pessoas'),
                    ),
                  ),
                );
              }

              final currentFriends = <String>{};
              final currentCloseFriends = <String>{};
              final currentUserMap =
                  currentUserDoc?.data() ?? <String, dynamic>{};
              if (currentUserDoc != null) {
                currentFriends.addAll(
                  ((currentUserMap['friends'] as List<dynamic>?) ?? const [])
                      .map((item) => item.toString()),
                );
                currentCloseFriends.addAll(
                  ((currentUserMap['closeFriends'] as List<dynamic>?) ??
                          const [])
                      .map((item) => item.toString()),
                );
              }

              final nodes = <CommunityNode>[];
              final currentUserName =
                  (currentUserMap['displayName'] as String?) ??
                      _safeCurrentUserDisplayName() ??
                      'Você';
              final currentUserAvatar =
                  (currentUserMap['photoURL'] as String?) ??
                      _safeCurrentUserPhotoUrl();

              for (final doc in filteredDocs) {
                final data = doc.data();
                final userId = doc.id;
                final name = (data['displayName'] as String?) ??
                    (data['name'] as String?) ??
                    'Usuário';
                final avatar = (data['photoURL'] as String?) ??
                    (data['photoUrl'] as String?) ??
                    (data['avatarUrl'] as String?);
                final status =
                    (data['status'] as String?) ?? (data['bio'] as String?);
                final isCloseFriend = currentCloseFriends.contains(userId) ||
                    (data['isCloseFriend'] == true);
                final isOnline = ((data['presence'] as String?) ?? 'offline')
                        .toLowerCase() ==
                    'online';
                final score = InteractionScoreService.calculate(
                  userId: userId,
                  userData: data,
                  currentUserId: currentUserId ?? userId,
                  currentUserFriends: currentFriends,
                  currentUserCloseFriends: currentCloseFriends,
                );
                final normalized = InteractionScoreService.normalized(score);

                nodes.add(
                  CommunityNode(
                    uid: userId,
                    displayName: name,
                    avatarUrl: avatar,
                    isOnline: isOnline,
                    isCloseFriend: isCloseFriend,
                    isCurrentUser:
                        currentUserId != null && userId == currentUserId,
                    hasStory: data['hasStory'] == true || data['story'] == true,
                    status: status,
                    interactionScore: score,
                    normalizedScore: normalized,
                    size:
                        InteractionScoreService.bubbleSizeFromScore(normalized),
                    distance:
                        InteractionScoreService.distanceFromScore(normalized),
                    rotation: 0,
                    position: const Offset(0, 0),
                    seed: userId.hashCode.abs(),
                  ),
                );
              }

              if (currentUserId != null &&
                  !nodes.any((node) => node.uid == currentUserId)) {
                nodes.add(
                  CommunityNode(
                    uid: currentUserId,
                    displayName: currentUserName,
                    avatarUrl: currentUserAvatar,
                    isOnline: true,
                    isCloseFriend: false,
                    isCurrentUser: true,
                    hasStory: false,
                    status: 'Você',
                    interactionScore: 100,
                    normalizedScore: 1,
                    size: 86,
                    distance: 0,
                    rotation: 0,
                    position: const Offset(0, 0),
                    seed: currentUserId.hashCode.abs(),
                  ),
                );
              }

              final rows = nodes.toList()
                ..sort(
                    (a, b) => b.interactionScore.compareTo(a.interactionScore));

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppSearchField(
                      hintText: 'Encontrar pessoas',
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _categoryChip('Todos'),
                        _categoryChip('Online'),
                        _categoryChip('Próximos'),
                        _categoryChip('Amigos'),
                        _categoryChip('Close Friends'),
                        _categoryChip('Ativos'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: CommunityBubbleMap(
                        nodes: rows,
                        currentUserName: currentUserName,
                        currentUserAvatar: currentUserAvatar,
                        onOpenProfile: (uid) {
                          Navigator.pushNamed(context, '/profile/$uid');
                        },
                        onOpenUniverse: (node) {
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              transitionDuration:
                                  const Duration(milliseconds: 520),
                              reverseTransitionDuration:
                                  const Duration(milliseconds: 360),
                              pageBuilder: (_, __, ___) => OrbUniversePage(
                                initialUniverse: OrbUniverse.personal(
                                  center: node.toSocialOrb(),
                                  title: node.isCurrentUser
                                      ? 'Meu Universo'
                                      : node.displayName,
                                  subtitle: node.status,
                                ),
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                final curved = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                  reverseCurve: Curves.easeInCubic,
                                );
                                return FadeTransition(
                                  opacity: curved,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.86, end: 1)
                                        .animate(curved),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label) {
    bool selected;
    switch (label) {
      case 'Todos':
        selected = _selectedTag == null || _selectedTag == 'Todos';
        break;
      case 'Online':
        selected = _selectedTag == 'Online';
        break;
      case 'Próximos':
        selected = _selectedTag == 'Próximos';
        break;
      case 'Amigos':
        selected = _selectedTag == 'Amigos';
        break;
      case 'Close Friends':
        selected = _selectedTag == 'Close Friends';
        break;
      case 'Ativos':
        selected = _selectedTag == 'Ativos';
        break;
      default:
        selected = _selectedTag == label;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (!selected) {
              _selectedTag = label == 'Todos' ? null : label;
            } else {
              _selectedTag = null;
            }
          });
        },
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.presence,
    this.vip = false,
    this.bio = '',
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String presence;
  final bool vip;
  final String bio;

  Color _presenceColor(String p) {
    switch (p.toLowerCase()) {
      case 'online':
      case 'present':
        return Colors.green;
      case 'away':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/profile/$userId'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.04),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  if (vip)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                name,
                key: Key('member_name_$userId'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                bio,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _presenceColor(presence),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        presence,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: Key('member_chat_$userId'),
                    tooltip: 'Abrir chat',
                    onPressed: () => Navigator.pushNamed(context, '/chat',
                        arguments: userId),
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
