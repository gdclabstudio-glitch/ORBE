import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/reaction_service.dart';
import '../../../services/outbox_service.dart';
import '../../chat/services/chat_service.dart';
import 'story_viewers_page.dart';

class StoryViewerPage extends StatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;
  const StoryViewerPage({super.key, required this.userId, this.firestore});

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with WidgetsBindingObserver {
  FirebaseFirestore get _fs => widget.firestore ?? FirebaseFirestore.instance;
  int _index = 0;
  bool _hasError = false;
  List<Map<String, dynamic>> _stories =
      []; // each story will include '__id' key for doc id

  VideoPlayerController? _videoController;
  Timer? _progressTimer;
  double _progress = 0.0;
  Duration _currentDuration = const Duration(seconds: 5);
  DateTime? _startedAt;
  // focus node for reply TextField — pausing while typing
  final FocusNode _replyFocusNode = FocusNode();
  // track whether pause was initiated by user (long-press)
  bool _userPaused = false;

  final PageController _pageController = PageController();

  // Reaction / like state
  final ReactionService _reactionService = ReactionService();
  StreamSubscription<Map<String, int>>? _reactionsSub;
  bool _liked = false;
  int _likeCount = 0;
  bool _reactionPending = false; // prevent duplicate requests
  static const String _likeEmoji = '❤️';

  void _handleReplyFocusChange() {
    if (_replyFocusNode.hasFocus) {
      _pause();
    } else if (!_userPaused) {
      _resume();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _replyFocusNode.addListener(_handleReplyFocusChange);
    _loadStories();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replyFocusNode.removeListener(_handleReplyFocusChange);
    _replyFocusNode.dispose();
    _reactionsSub?.cancel();
    _disposeVideo();
    _progressTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _disposeVideo() {
    try {
      _videoController?.removeListener(_onVideoUpdate);
      _videoController?.pause();
      _videoController?.dispose();
    } catch (_) {}
    _videoController = null;
  }

  Future<void> _loadStories() async {
    try {
      final threshold = DateTime.now().toUtc().subtract(
            const Duration(hours: 24),
          );
      final snap = await _fs
          .collection('users')
          .doc(widget.userId)
          .collection('stories')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(threshold),
          )
          .orderBy('createdAt', descending: false)
          .get();
      if (!mounted) return;
      setState(() {
        _stories = snap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['__id'] = d.id;
          return m;
        }).toList(growable: false);
        _hasError = false;
      });
      if (_stories.isNotEmpty) {
        _startForIndex(0);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final ctrl = _videoController;
    if (ctrl == null) return;
    if (!ctrl.value.isInitialized) return;
    final dur = ctrl.value.duration;
    final pos = ctrl.value.position;
    if (dur.inMilliseconds > 0) {
      // avoid setState storms by only updating when significant progress changed (e.g., > 50ms)
      final newProgress = pos.inMilliseconds / dur.inMilliseconds;
      if ((newProgress - _progress).abs() > 0.001) {
        setState(() {
          _currentDuration = dur;
          _progress = newProgress;
        });
      }
      if (pos >= dur) {
        _next();
      }
    }
  }

  void _startForIndex(int idx) async {
    _progressTimer?.cancel();
    _disposeVideo();
    _progress = 0.0;
    _index = idx;
    if (idx < 0 || idx >= _stories.length) return;
    final story = _stories[idx];
    final mediaUrl = story['mediaUrl'] as String?;
    final type = (story['type'] as String?) ?? 'image';

    // mark viewed
    _markViewed(story['__id']);

    // start listening to reactions (like counts)
    _reactionsSub?.cancel();
    _reactionsSub = _reactionService
        .reactionsCountStreamForStory(widget.userId, story['__id'] as String)
        .listen((counts) {
      if (!mounted) return;
      setState(() {
        _likeCount = counts[_likeEmoji] ?? 0;
      });
    });

    // check if current user already liked this story
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final has = await _reactionService.userHasReactedToStory(
          ownerId: widget.userId,
          storyId: story['__id'] as String,
          userId: currentUser.uid,
          emoji: _likeEmoji,
        );
        if (!mounted) return;
        _liked = has;
      } else {
        _liked = false;
      }
    } catch (_) {
      if (mounted) {
        _liked = false;
      }
    }

    if (type == 'video' && mediaUrl != null) {
      try {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(mediaUrl),
        );
        await _videoController!.initialize();
        _videoController!.addListener(_onVideoUpdate);
        await _videoController!.play();
        setState(() {
          _currentDuration = _videoController!.value.duration;
        });
      } catch (_) {
        // fallback to image-like timeout
        _startImageTimer(story);
      }
    } else {
      _startImageTimer(story);
    }
  }

  void _startImageTimer(Map<String, dynamic> story) {
    _currentDuration = Duration(seconds: (story['duration'] as int?) ?? 5);
    _progress = 0.0;
    _startedAt = DateTime.now();
    const tickMs = 50;
    _progressTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_startedAt!).inMilliseconds;
      final total = _currentDuration.inMilliseconds;
      setState(() {
        _progress = (elapsed / total).clamp(0.0, 1.0);
      });
      if (elapsed >= total) {
        t.cancel();
        _next();
      }
    });
  }

  void _next() {
    if (!mounted) return;
    if (_index < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (!mounted) return;
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      // at first — do nothing or exit
      Navigator.of(context).pop();
    }
  }

  void _pause({bool userInitiated = false}) {
    if (userInitiated) _userPaused = true;
    _progressTimer?.cancel();
    try {
      _videoController?.pause();
    } catch (_) {}
  }

  void _resume({bool userInitiated = false}) {
    if (userInitiated) _userPaused = false;
    // resume image timer continuing from current progress
    try {
      if (_videoController != null && _videoController!.value.isInitialized) {
        _videoController!.play();
      } else if (_currentDuration.inMilliseconds > 0) {
        final elapsed = (_progress * _currentDuration.inMilliseconds).round();
        _startedAt = DateTime.now().subtract(Duration(milliseconds: elapsed));
        _progressTimer?.cancel();
        const tickMs = 50;
        _progressTimer = Timer.periodic(const Duration(milliseconds: tickMs), (
          t,
        ) {
          if (!mounted) return;
          final elapsed = DateTime.now().difference(_startedAt!).inMilliseconds;
          final total = _currentDuration.inMilliseconds;
          setState(() => _progress = (elapsed / total).clamp(0.0, 1.0));
          if (elapsed >= total) {
            t.cancel();
            _next();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markViewed(String? storyId) async {
    // Record one unique view per viewer in a subcollection under the story.
    // This is idempotent and avoids the unbounded 'viewedBy' array pattern.
    if (storyId == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (user.uid == widget.userId) return;

      final storyRef = _fs
          .collection('users')
          .doc(widget.userId)
          .collection('stories')
          .doc(storyId);
      final viewerDocRef = storyRef.collection('views').doc(user.uid);

      final snap = await viewerDocRef.get();
      if (snap.exists) return;

      await viewerDocRef.set({
        'ownerId': widget.userId,
        'storyId': storyId,
        'viewerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final payload = {
          'viewerId': user.uid,
          'ownerId': widget.userId,
          'storyId': storyId,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        await OutboxService.instance.enqueue({
          'type': 'story_view',
          'payload': payload,
        });
      } catch (_) {}
    }
  }

  Future<void> _confirmAndDeleteCurrentStory() async {
    if (_stories.isEmpty) return;
    final storyId = _stories[_index]['__id'] as String?;
    if (storyId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir story'),
        content: const Text(
          'Tem certeza que deseja excluir este story? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deleteCurrentStory(storyId);
    }
  }

  Future<void> _deleteCurrentStory(String storyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (user.uid != widget.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você não pode excluir este story')),
        );
        return;
      }

      final docRef = _fs
          .collection('users')
          .doc(widget.userId)
          .collection('stories')
          .doc(storyId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;
      final data = docSnap.data() ?? <String, dynamic>{};
      final mediaUrl = data['mediaUrl'] as String?;

      // Attempt to delete media from Firebase Storage if present
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          await ref.delete();
        } catch (e) {
          // If storage delete fails, enqueue delete to Outbox and continue with doc deletion
          try {
            await OutboxService.instance.enqueue({
              'type': 'story_delete',
              'payload': {
                'ownerId': widget.userId,
                'storyId': storyId,
                'mediaUrl': mediaUrl,
              },
            });
          } catch (_) {}
        }
      }

      // Delete story document
      await docRef.delete();

      // Update local state immediately: remove story and navigate appropriately
      if (!mounted) return;
      setState(() {
        final removedIndex = _index;
        _stories.removeWhere((s) => s['__id'] == storyId);
        if (_stories.isEmpty) {
          // close viewer
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return;
        } else {
          final nextIndex = removedIndex < _stories.length
              ? removedIndex
              : (_stories.length - 1);
          // start next story
          _startForIndex(nextIndex);
        }
      });
    } catch (e) {
      // Fallback: enqueue delete operation for later
      try {
        await OutboxService.instance.enqueue({
          'type': 'story_delete',
          'payload': {'ownerId': widget.userId, 'storyId': storyId},
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A exclusão foi agendada e será processada quando possível.',
            ),
          ),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir o story.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Story')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Falha ao carregar stories.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() { _hasError = false; });
                  _loadStories();
                },
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Story')),
        body: const Center(child: Text('Nenhum story disponível')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: (d) {
            if (d.delta.dy > 12) {
              _pause();
              Navigator.of(context).pop();
            }
          },
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _stories.length,
                onPageChanged: (p) {
                  // start the media for new page
                  _startForIndex(p);
                },
                itemBuilder: (context, i) {
                  final story = _stories[i];
                  final mediaUrl = story['mediaUrl'] as String?;
                  final type = (story['type'] as String?) ?? 'image';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 16.0,
                      ),
                      child: type == 'video' &&
                              mediaUrl != null &&
                              _videoController != null &&
                              i == _index
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : (mediaUrl != null
                              ? CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                                  imageUrl: mediaUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (c, u) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink()),
                    ),
                  );
                },
              ),

              // Progress bars
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Column(
                  children: [
                    Row(
                      children: List.generate(_stories.length, (i) {
                        final filled = i < _index;
                        final current = i == _index;
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                                  filled ? 1.0 : (current ? _progress : 0.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Top-left: author and close
              Positioned(
                top: 16,
                left: 12,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: _stories[_index]['authorPhoto'] != null
                          ? NetworkImage(_stories[_index]['authorPhoto'])
                          : null,
                      child: _stories[_index]['authorPhoto'] == null
                          ? Text(
                              (_stories[_index]['authorName'] ?? '')[0] ?? '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stories[_index]['authorName'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_stories[_index]['createdAt'] != null)
                          Text(
                            _relativeTime(_stories[_index]['createdAt']),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Top-right: viewers button (visible to story owner) and delete
              Positioned(
                top: 8,
                right: 8,
                child: FutureBuilder(
                  future:
                      FirebaseAuth.instance.currentUser?.uid == widget.userId
                          ? Future.value(true)
                          : FirebaseAuth.instance.currentUser
                              ?.getIdTokenResult(true)
                              .then((r) => (r.claims ?? {})['isAdmin'] == true),
                  builder: (context, snap) {
                    final allowed = snap.data == true;
                    if (!allowed) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_red_eye,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StoryViewersPage(
                                  ownerId: widget.userId,
                                  storyId: _stories[_index]['__id'] as String,
                                  firestore: _fs,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            await _confirmAndDeleteCurrentStory();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Left/right tap areas
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _prev,
                        onLongPressStart: (_) => _pause(userInitiated: true),
                        onLongPressEnd: (_) => _resume(userInitiated: true),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _next,
                        onLongPressStart: (_) => _pause(userInitiated: true),
                        onLongPressEnd: (_) => _resume(userInitiated: true),
                      ),
                    ),
                  ],
                ),
              ),

              // Interaction bar (reply + like)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Responder',
                                    hintStyle: TextStyle(color: Colors.white54),
                                  ),
                                  onSubmitted: (text) async {
                                    if (text.trim().isEmpty) return;
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Faça login para enviar resposta',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final ownerId = widget.userId;
                                    final storyId =
                                        _stories[_index]['__id'] as String;
                                    final mediaUrl =
                                        _stories[_index]['mediaUrl'] as String?;
                                    final displayName =
                                        user.displayName ?? 'Você';
                                    // create or reuse a private chat room between current user and story owner
                                    final roomId = ChatService.privateRoomId(
                                      user.uid,
                                      ownerId,
                                    );
                                    final chat = ChatService(roomId: roomId);
                                    try {
                                      await chat.sendMessage(
                                        senderId: user.uid,
                                        senderName: displayName,
                                        text: text.trim(),
                                        meta: {
                                          'type': 'story_reply',
                                          'recipientId': ownerId,
                                          'storyOwnerId': ownerId,
                                          'storyId': storyId,
                                          if (mediaUrl != null)
                                            'storyMediaUrl': mediaUrl,
                                        },
                                      );

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Resposta enviada'),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Erro ao enviar resposta',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () async {
                                  // like toggle with optimistic UI and duplicate-request protection
                                  if (_reactionPending) return;
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Faça login para curtir'),
                                      ),
                                    );
                                    return;
                                  }
                                  _reactionPending = true;
                                  final prevLiked = _liked;
                                  // optimistic update
                                  setState(() {
                                    _liked = !_liked;
                                    _likeCount = _liked
                                        ? _likeCount + 1
                                        : (_likeCount > 0 ? _likeCount - 1 : 0);
                                  });

                                  try {
                                    await _reactionService
                                        .toggleReactionOnStory(
                                      ownerId: widget.userId,
                                      storyId:
                                          _stories[_index]['__id'] as String,
                                      userId: user.uid,
                                      emoji: _likeEmoji,
                                    );
                                    // backend change will be reflected by the reactions subscription
                                  } catch (e) {
                                    // revert optimistic update on error
                                    setState(() {
                                      _liked = prevLiked;
                                      _likeCount = prevLiked
                                          ? _likeCount + 1
                                          : (_likeCount > 0
                                              ? _likeCount - 1
                                              : 0);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Erro ao atualizar curtida. Tente novamente.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    _reactionPending = false;
                                  }
                                },
                                icon: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      _liked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _liked
                                          ? Colors.pinkAccent
                                          : Colors.white,
                                    ),
                                    if (_likeCount > 0)
                                      Positioned(
                                        right: -28,
                                        top: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '$_likeCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(dynamic ts) {
    try {
      DateTime dt;
      if (ts is Timestamp)
        dt = ts.toDate();
      else if (ts is int)
        dt = DateTime.fromMillisecondsSinceEpoch(ts);
      else if (ts is DateTime)
        dt = ts;
      else
        return '';
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'agora';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
