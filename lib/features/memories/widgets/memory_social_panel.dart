import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/google_auth_provider.dart';
import '../services/memory_social_service.dart';

class MemorySocialPanel extends StatefulWidget {
  final String memoryId;
  final bool compact;

  const MemorySocialPanel({
    super.key,
    required this.memoryId,
    this.compact = false,
  });

  @override
  State<MemorySocialPanel> createState() => _MemorySocialPanelState();
}

class _MemorySocialPanelState extends State<MemorySocialPanel> {
  final MemorySocialService _service = MemorySocialService();
  final TextEditingController _commentController = TextEditingController();
  String? _replyTo;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _userId =>
      context.read<GoogleAuthProvider>().currentUserData?.uid ?? 'anonymous';

  String get _userName =>
      context.read<GoogleAuthProvider>().currentUserData?.displayName ??
      'Usuário';

  Future<void> _sendComment() async {
    final text = _commentController.text;
    if (text.trim().isEmpty) return;
    await _service.addComment(
      memoryId: widget.memoryId,
      authorId: _userId,
      authorName: _userName,
      text: text,
      parentId: _replyTo,
    );
    _commentController.clear();
    setState(() => _replyTo = null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _service.likesListStream(widget.memoryId),
      builder: (context, likesSnapshot) {
        final likes = likesSnapshot.data ?? const <String>[];
        final liked = likes.contains(_userId);
        final content = Row(
          children: [
            _SocialActionButton(
              tooltip: liked ? 'Remover curtida' : 'Curtir',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey<bool>(liked),
                  color: liked ? Colors.pinkAccent : null,
                ),
              ),
              onPressed: () => _service.toggleLike(
                memoryId: widget.memoryId,
                userId: _userId,
              ),
            ),
            Text('${likes.length}'),
            _SocialActionButton(
              tooltip: 'Comentários',
              icon: const Icon(Icons.mode_comment_outlined),
              onPressed: widget.compact ? () => _showComments(context) : null,
            ),
            if (widget.compact)
              StreamBuilder<List<MemoryComment>>(
                stream: _service.commentsStream(widget.memoryId),
                builder: (_, snapshot) => Text('${snapshot.data?.length ?? 0}'),
              ),
          ],
        );
        return widget.compact ? content : _commentsBody(content);
      },
    );
  }

  Widget _commentsBody(Widget header) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, _commentComposer(), _commentList()],
    );
  }

  Future<void> _showComments(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              const ListTile(title: Text('Comentários')),
              _commentList(),
              _commentComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _commentComposer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: _replyTo == null
                    ? 'Escreva um comentário...'
                    : 'Responder...',
              ),
            ),
          ),
          IconButton(onPressed: _sendComment, icon: const Icon(Icons.send)),
        ],
      ),
    );
  }

  Widget _commentList() {
    return StreamBuilder<List<MemoryComment>>(
      stream: _service.commentsStream(widget.memoryId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Não foi possível carregar comentários.'),
          );
        }
        final comments = snapshot.data ?? const <MemoryComment>[];
        if (comments.isEmpty) {
          return const Expanded(
            child: Center(child: Text('Seja o primeiro a comentar!')),
          );
        }
        return Expanded(
          child: ListView.builder(
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index];
              final depth = comment.parentId == null ? 0 : 1;
              return _CommentTile(
                key: ValueKey(comment.id),
                comment: comment,
                leftPadding: 12.0 + depth * 24,
                onReply: () => setState(() => _replyTo = comment.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final MemoryComment comment;
  final double leftPadding;
  final VoidCallback onReply;

  const _CommentTile({
    super.key,
    required this.comment,
    required this.leftPadding,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, right: 12),
      child: ListTile(
        dense: true,
        title: Text(comment.authorName),
        subtitle: Text(comment.text),
        trailing: TextButton(
          onPressed: onReply,
          child: const Text('Responder'),
        ),
      ),
    );
  }
}

class _SocialActionButton extends StatefulWidget {
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  const _SocialActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_SocialActionButton> createState() => _SocialActionButtonState();
}

class _SocialActionButtonState extends State<_SocialActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onPressed == null
            ? null
            : () => setState(() => _pressed = false),
        onTapUp: widget.onPressed == null
            ? null
            : (_) {
                setState(() => _pressed = false);
                widget.onPressed!();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.82 : 1,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.secondary,
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}
