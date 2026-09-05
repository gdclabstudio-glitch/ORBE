import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:labomba_app/features/memories/models/memory.dart';
import 'package:labomba_app/features/memories/providers/memory_provider.dart';
import 'package:labomba_app/providers/google_auth_provider.dart';
import 'package:labomba_app/widgets/app_feedback.dart';

class MemoryEditorPage extends StatefulWidget {
  const MemoryEditorPage({super.key});

  @override
  State<MemoryEditorPage> createState() => _MemoryEditorPageState();
}

class _MemoryEditorPageState extends State<MemoryEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final List<String> _attachments = []; // urls for images, gifs, stickers

  // A small curated list of GIF URLs (public demo links) for lightweight picker
  final List<String> _sampleGifs = const [
    'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
    'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    'https://media.giphy.com/media/26xBwdIuRJiAIqHwA/giphy.gif',
  ];

  // Sample stickers (transparent PNGs or small images hosted publicly)
  final List<String> _sampleStickers = const [
    'https://i.imgur.com/4M7IWwP.png',
    'https://i.imgur.com/5QfKQ8Z.png',
    'https://i.imgur.com/0g7Qd3m.png',
  ];

  // A compact emoji set for the quick picker
  final List<String> _emojiSet = const [
    '😀',
    '😂',
    '😍',
    '🥳',
    '🤩',
    '🎉',
    '👏',
    '🔥',
    '💜',
    '📸',
    '🎭',
    '🥁',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _openEmojiPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: GridView.count(
              crossAxisCount: 6,
              children: _emojiSet.map((e) {
                return IconButton(
                  onPressed: () {
                    // Insert emoji at cursor
                    final pos = _descController.selection.base.offset;
                    final text = _descController.text;
                    final newText =
                        pos >= 0 ? text.replaceRange(pos, pos, e) : text + e;
                    _descController.text = newText;
                    _descController.selection = TextSelection.collapsed(
                      offset: (pos >= 0 ? pos : newText.length) + e.length,
                    );
                    Navigator.of(context).pop();
                  },
                  icon: Text(e, style: const TextStyle(fontSize: 24)),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _openGifPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 320,
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Escolha um GIF',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.all(12),
                  childAspectRatio: 1,
                  children: _sampleGifs.map((g) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _attachments.add(g));
                        Navigator.of(context).pop();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                          imageUrl: g,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStickerPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: GridView.count(
              crossAxisCount: 4,
              children: _sampleStickers.map((s) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _attachments.add(s));
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                        imageUrl: s,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty && desc.isEmpty && _attachments.isEmpty) {
      // nothing to save
      AppFeedback.showWarning(context, 'Adicione conteúdo antes de salvar.');
      return;
    }

    final id = const Uuid().v4();
    final memory = Memory(
      id: id,
      title: title.isEmpty ? 'Sem título' : title,
      description: desc.isEmpty ? null : desc,
      imageUrls: List<String>.from(_attachments),
      createdAt: DateTime.now(),
      ownerId: context.read<GoogleAuthProvider>().currentUserData?.uid,
    );

    final provider = context.read<MemoryProvider>();
    await provider.addOrUpdate(memory);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Memória'),
        actions: [
          IconButton(
            onPressed: _openEmojiPicker,
            icon: const Icon(Icons.emoji_emotions),
          ),
          IconButton(onPressed: _openGifPicker, icon: const Icon(Icons.gif)),
          IconButton(
            onPressed: _openStickerPicker,
            icon: const Icon(Icons.sticky_note_2),
          ),
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Escreva uma memória...',
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, idx) => Stack(
                    children: [
                      CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                        imageUrl: _attachments[idx],
                        width: 120,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            color: Colors.white,
                            onPressed: () =>
                                setState(() => _attachments.removeAt(idx)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                    ],
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _attachments.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
