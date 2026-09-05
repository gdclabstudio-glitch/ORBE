import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'story_viewer_page.dart';

class StoriesCarousel extends StatelessWidget {
  final FirebaseFirestore? firestore;
  const StoriesCarousel({super.key, this.firestore});

  FirebaseFirestore get _fs => firestore ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final threshold = DateTime.now().toUtc().subtract(
          const Duration(hours: 24),
        );
    return SizedBox(
      height: 110,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Keep story carousel bounded: we only need the newest active stories and a small
        // result window to avoid streaming every story from every user at once.
        stream: _fs
            .collectionGroup('stories')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(threshold),
            )
            .orderBy('createdAt', descending: true)
            .limit(60)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: SizedBox(height: 60));
          final docs = snap.data!.docs;

          // Build a map of ownerId -> latest story doc to show one avatar per owner
          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
              latestByOwner = {};
          for (final d in docs) {
            // ownerId is the parent of the stories collection: /users/{ownerId}/stories/{storyId}
            final parent = d.reference.parent.parent;
            if (parent == null) continue;
            final ownerId = parent.id;
            if (!latestByOwner.containsKey(ownerId)) {
              latestByOwner[ownerId] = d;
            }
          }

          final owners = latestByOwner.entries.toList(growable: false);

          if (owners.isEmpty) return const Center(child: SizedBox(height: 60));

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final entry = owners[index];
              final ownerId = entry.key;
              final data = entry.value.data();
              final name = (data['authorName'] as String?) ??
                  (data['displayName'] as String?) ??
                  'Usuário';
              final avatar = (data['authorPhoto'] as String?) ??
                  (data['photoURL'] as String?);
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StoryViewerPage(userId: ownerId, firestore: _fs),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Colors.pinkAccent, Colors.orangeAccent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.08 * 255).round()),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage:
                              avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 72,
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: owners.length,
          );
        },
      ),
    );
  }
}
