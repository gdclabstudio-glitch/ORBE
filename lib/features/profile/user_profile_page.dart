import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/storage_upload_service.dart';
import './user_profile_service.dart';
import '../../services/outbox_service.dart';
import '../../features/chat/views/chat_page.dart';
import './follow_requests_page.dart';
import '../social/views/story_viewer_page.dart';
import './followers_following_pages.dart';

class UserProfilePage extends StatefulWidget {
  final String? userId;

  const UserProfilePage({super.key, this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late final UserProfileService _service;
  String? _uid;
  UserProfile? _profile;
  bool _loading = true;
  final _editNameController = TextEditingController();
  final _editBioController = TextEditingController();

  // social state
  bool _isFollowing = false;
  bool _followRequested =
      false; // whether current user has an outstanding follow request to this profile
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _currentUserSub;
  StreamSubscription<UserProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _service = UserProfileService(storage: Provider.of(context, listen: false));
    // determine uid: provided or current user
    final auth = Provider.of<AuthService>(context, listen: false);
    _uid = widget.userId ?? auth.currentUser?.uid;
    if (_uid != null) {
      _loadProfile(_uid!);
      _profileSub = _service.userProfileStream(_uid!).listen((p) {
        if (!mounted) return;
        if (p != null) setState(() => _profile = p);
      });

      // listen to current user's doc to determine follow state
      final currentUid = Provider.of<AuthService>(
        context,
        listen: false,
      ).currentUser?.uid;
      if (currentUid != null) {
        _currentUserSub = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .snapshots()
            .listen((s) {
          if (!mounted) return;
          final following =
              (s.data()?['following'] as List<dynamic>?)?.cast<String>() ??
                  <String>[];
          final isFollowing = following.contains(_uid);
          final outgoing =
              (s.data()?['outgoingFollowRequests'] as List<dynamic>?)
                      ?.cast<String>() ??
                  <String>[];
          final requested = outgoing.contains(_uid);
          setState(() {
            _isFollowing = isFollowing;
            _followRequested = requested;
          });
        });
      }
    } else {
      _loading = false;
    }
  }

  Future<void> _loadProfile(String uid) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final p = await _service.getUserProfile(uid);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editBioController.dispose();
    _profileSub?.cancel();
    _currentUserSub?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uid == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      final file = File(picked.path);
      // compress
      final compressed = await MediaService().compressImageFile(
        file,
        maxWidth: 1200,
        quality: 80,
      );
      final thumb = await MediaService().createThumbnail(
        file,
        maxWidth: 300,
        quality: 60,
      );

      // upload
      final storage = StorageUploadService();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final avatarPath = storage.userAvatarPath(_uid!);
      final avatarUrl = await storage.uploadFile(
        avatarPath,
        compressed,
        ownerUid: _uid!,
      );

      // optionally upload thumbnail
      final thumbPath = 'users/${_uid}/thumb_avatar_$timestamp.jpg';
      await storage.uploadFile(thumbPath, thumb, ownerUid: _uid!);

      // update profile
      final updated = _profile!.copyWith(avatarUrl: avatarUrl);
      await _service.updateProfile(updated);
      // ensure local reload
      await _loadProfile(_uid!);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Avatar atualizado')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Falha ao enviar avatar')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditDialog() async {
    if (_profile == null) return;
    _editNameController.text = _profile!.displayName;
    _editBioController.text = _profile!.bio ?? '';
    final updated = await showDialog<UserProfile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editNameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              maxLength: 60,
            ),
            TextField(
              controller: _editBioController,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLength: 1000,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newProfile = _profile!.copyWith(
                displayName: _editNameController.text.trim(),
                bio: _editBioController.text.trim(),
              );
              Navigator.of(ctx).pop(newProfile);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (updated != null) {
      setState(() => _loading = true);
      try {
        await _service.updateProfile(updated);
        // reload locally
        await _loadProfile(updated.id);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao salvar perfil')),
          );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = Provider.of<AuthService>(
      context,
      listen: false,
    ).currentUser?.uid;
    final isOwn =
        current != null && _profile != null && current == _profile!.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Usuário não encontrado'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: _profile!.avatarUrl != null
                                ? NetworkImage(_profile!.avatarUrl!)
                                : null,
                            child: _profile!.avatarUrl == null
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                          if (isOwn)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton(
                                tooltip: 'Alterar avatar',
                                icon: const Icon(Icons.camera_alt, size: 20),
                                onPressed: _pickAndUploadAvatar,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _profile!.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if ((_profile!.bio ?? '').isNotEmpty)
                        Text(_profile!.bio!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () => _openPosts(),
                            child: _statTile(
                              'Posts',
                              _profile!.stats['posts'] ?? 0,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _openFollowers(),
                            child: _statTile(
                              'Seguidores',
                              _profile!.stats['followers'] ?? 0,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _openFollowing(),
                            child: _statTile(
                              'Seguindo',
                              _profile!.stats['following'] ?? 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!isOwn)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _toggleFollow,
                              child: Text(_isFollowing ? 'Seguindo' : 'Seguir'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChatPage(privateUserId: _profile!.id),
                                ),
                              ),
                              child: const Text('Mensagem'),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (s) async {
                                if (s == 'block') await _blockUser();
                                if (s == 'mute') await _muteUser();
                                if (s == 'report') await _reportUser();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'block',
                                  child: Text('Bloquear'),
                                ),
                                const PopupMenuItem(
                                  value: 'mute',
                                  child: Text('Silenciar'),
                                ),
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('Denunciar'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            FilledButton(
                              onPressed: _showEditDialog,
                              child: const Text('Editar perfil'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FollowRequestsPage(),
                                  ),
                                );
                              },
                              child: const Text('Solicitações'),
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // Highlights / stories
                      const SizedBox(height: 8),
                      _buildHighlights(),
                    ],
                  ),
                ),
    );
  }

  Widget _statTile(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildHighlights() {
    // Show story highlights (stories with isHighlight flag) if any
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(_profile!.id)
          .collection('stories')
          .where('isHighlight', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Destaques',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final d = docs[index].data();
                  final media = d['mediaUrl'] as String?;
                  return GestureDetector(
                    onTap: () {
                      // open story viewer at this user's stories
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoryViewerPage(userId: _profile!.id),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage:
                          media != null ? NetworkImage(media) : null,
                      child:
                          media == null ? const Icon(Icons.auto_stories) : null,
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: docs.length,
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  void _openPosts() {
    // Reuse memories screen if posts are stored in memories; otherwise fallback
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('Posts de ${_profile!.displayName}')),
        ),
      ),
    );
  }

  void _openFollowers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowersListPage(targetId: _profile!.id),
      ),
    );
  }

  void _openFollowing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowingListPage(targetId: _profile!.id),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final me = Provider.of<AuthService>(context, listen: false).currentUser;
    if (me == null || _profile == null) return;
    final myRef = FirebaseFirestore.instance.collection('users').doc(me.uid);
    final targetRef =
        FirebaseFirestore.instance.collection('users').doc(_profile!.id);
    final targetFollowerRef = targetRef.collection('followers').doc(me.uid);
    final sourceFollowingRef = myRef.collection('following').doc(_profile!.id);

    try {
      final targetSnap = await targetRef.get();
      final isPrivate = (targetSnap.data()?['private'] as bool?) ?? false;

      if (isPrivate) {
        final requestRef =
            myRef.collection('outgoingFollowRequests').doc(_profile!.id);
        final incomingRef =
            targetRef.collection('incomingFollowRequests').doc(me.uid);

        if (_followRequested) {
          await requestRef.delete();
          await incomingRef.delete();
          await myRef.update({
            'outgoingFollowRequests': FieldValue.arrayRemove([_profile!.id]),
          });
          if (mounted) setState(() => _followRequested = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitação cancelada')),
          );
        } else {
          final requestPayload = {
            'requesterId': me.uid,
            'targetId': _profile!.id,
            'createdAt': FieldValue.serverTimestamp(),
          };
          await requestRef.set(requestPayload);
          await incomingRef.set(requestPayload);
          await myRef.update({
            'outgoingFollowRequests': FieldValue.arrayUnion([_profile!.id]),
          });
          if (mounted) setState(() => _followRequested = true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Solicitação enviada')));
        }
        return;
      }

      final targetFollowDoc = await targetFollowerRef.get();
      final sourceFollowingDoc = await sourceFollowingRef.get();

      if (_isFollowing || sourceFollowingDoc.exists) {
        if (targetFollowDoc.exists) {
          await targetFollowerRef.delete();
        }
        if (sourceFollowingDoc.exists) {
          await sourceFollowingRef.delete();
        }
        await myRef.update({
          'following': FieldValue.arrayRemove([_profile!.id]),
        });
        await targetRef.update({
          'followers': FieldValue.arrayRemove([me.uid]),
        });
        await OutboxService.instance.enqueue({
          'type': 'unfollow',
          'payload': {'from': me.uid, 'to': _profile!.id},
        });
        if (mounted) setState(() => _isFollowing = false);
      } else {
        if (!targetFollowDoc.exists) {
          await targetFollowerRef.set({
            'followerId': me.uid,
            'userId': _profile!.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        if (!sourceFollowingDoc.exists) {
          await sourceFollowingRef.set({
            'followingId': _profile!.id,
            'userId': me.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await myRef.update({
          'following': FieldValue.arrayUnion([_profile!.id]),
        });
        await targetRef.update({
          'followers': FieldValue.arrayUnion([me.uid]),
        });
        await OutboxService.instance.enqueue({
          'type': 'follow',
          'payload': {'from': me.uid, 'to': _profile!.id},
        });
        if (mounted) setState(() => _isFollowing = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar seguimento')),
      );
    }
  }

  Future<void> _blockUser() async {
    final me = Provider.of<AuthService>(context, listen: false).currentUser;
    if (me == null || _profile == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(me.uid).update({
        'blocked': FieldValue.arrayUnion([_profile!.id]),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuário bloqueado')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao bloquear usuário')));
    }
  }

  Future<void> _muteUser() async {
    final me = Provider.of<AuthService>(context, listen: false).currentUser;
    if (me == null || _profile == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(me.uid).update({
        'muted': FieldValue.arrayUnion([_profile!.id]),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuário silenciado')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao silenciar usuário')),
      );
    }
  }

  Future<void> _reportUser() async {
    if (_profile == null) return;
    final me = Provider.of<AuthService>(context, listen: false).currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para denunciar.')),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitReport');
      await callable.call(<String, dynamic>{
        'resourceType': 'user',
        'resourceId': _profile!.id,
        'category': 'harassment',
        'reason': 'Denúncia enviada pelo usuário via perfil.',
        'details': {'source': 'user_profile'},
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Denúncia enviada')));
    } catch (_) {
      // enqueue if offline
      try {
        await OutboxService.instance.enqueue({
          'type': 'report_user',
          'payload': {
            'resourceType': 'user',
            'resourceId': _profile!.id,
            'reporterId': me.uid,
            'category': 'harassment',
            'reason': 'Denúncia enviada via perfil',
          },
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Denúncia agendada')));
      } catch (_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Falha ao denunciar')));
      }
    }
  }
}
