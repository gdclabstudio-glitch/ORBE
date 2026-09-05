import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../../../services/auth_service.dart';

import 'package:labomba_app/widgets/user_appbar_actions.dart';

import '../../../services/screen_protection_service.dart';

class ChatPage extends StatefulWidget {
  final String? privateUserId;

  const ChatPage({super.key, this.privateUserId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _privateUserController = TextEditingController();
  late ChatProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ChatProvider>();
    // connect to stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.privateUserId != null) {
        final current = context.read<AuthService>().currentUser?.uid ?? 'anon';
        _provider.switchRoom(
          ChatService.privateRoomId(current, widget.privateUserId!),
        );
      } else {
        _provider.connect();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _privateUserController.dispose();
    super.dispose();
  }

  void _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    try {
      await _provider.sendMessage(
        senderId: user?.uid ?? 'anon',
        senderName: user?.displayName ?? 'Anon',
        text: text,
      );
      _controller.clear();
    } catch (e) {
      final msg = e is StateError
          ? e.message
          : 'Erro ao enviar mensagem: ${e.toString()}';
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _openEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        final emojis = [
          '😀',
          '🎉',
          '❤️',
          '🔥',
          '🥳',
          '💃',
          '🕺',
          '🎭',
          '🎶',
          '📸',
        ];
        return GridView.count(
          crossAxisCount: 5,
          padding: const EdgeInsets.all(12),
          children: emojis
              .map(
                (e) => GestureDetector(
                  onTap: () => Navigator.pop(context, e),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
    if (emoji != null) {
      final newText = _controller.text + emoji;
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  void _openStickers() async {
    final sticker = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        final stickers = [
          'https://via.placeholder.com/150/FF6A00/ffffff?text=ST1',
          'https://via.placeholder.com/150/7C1AFF/ffffff?text=ST2',
          'https://via.placeholder.com/150/00C2FF/ffffff?text=ST3',
        ];
        return GridView.count(
          crossAxisCount: 3,
          padding: const EdgeInsets.all(12),
          children: stickers
              .map(
                (s) => GestureDetector(
                  onTap: () => Navigator.pop(context, s),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                      imageUrl: s,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
    if (sticker != null) {
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      await _provider.sendMessage(
        senderId: user?.uid ?? 'anon',
        senderName: user?.displayName ?? 'Anon',
        stickerUrl: sticker,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final messages = chat.messages;
        return SecureScreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('La Bomba • Chat'),
              backgroundColor: const Color(0xFF7C1AFF),
              actions: [UserAppBarActions()],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        value: chat.roomId == 'general' ? 'general' : 'private',
                        items: const [
                          DropdownMenuItem(
                            value: 'general',
                            child: Text('Grupo geral'),
                          ),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Chat privado'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == 'general') {
                            _provider.switchRoom('general');
                          } else {
                            final userId = await _requestPrivateUser();
                            if (userId != null && userId.isNotEmpty) {
                              final current = context
                                      .read<AuthService>()
                                      .currentUser
                                      ?.uid ??
                                  'anon';
                              _provider.switchRoom(
                                ChatService.privateRoomId(current, userId),
                              );
                            }
                          }
                        },
                      ),
                      if (chat.roomId != 'general')
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('conversa privada'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, idx) {
                      final m = messages[messages.length - 1 - idx];
                      final isMe = m.senderId ==
                          (context.read<AuthService>().currentUser?.uid ?? '');
                      return _ChatBubble(message: m, isMe: isMe);
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Emoji',
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          onPressed: _openEmojiPicker,
                        ),
                        IconButton(
                          tooltip: 'Sticker',
                          icon: const Icon(Icons.sticky_note_2_outlined),
                          onPressed: _openStickers,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Digite uma mensagem...',
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: .7),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: IconButton(
                            tooltip: 'Enviar',
                            color: Colors.white,
                            icon: const Icon(Icons.send_rounded),
                            onPressed: _sendText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _requestPrivateUser() {
    _privateUserController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar chat privado'),
        content: TextField(
          controller: _privateUserController,
          decoration: const InputDecoration(labelText: 'UID do outro usuário'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _privateUserController.text.trim()),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final color = isMe
        ? const Color(0xFFFF6A00)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (message.stickerUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                    imageUrl: message.stickerUrl!,
                    width: 170,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            if (message.text != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  message.text!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
