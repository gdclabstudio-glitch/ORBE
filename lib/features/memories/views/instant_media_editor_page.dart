import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';

import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/media_compressor.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../services/storage_platform.dart';

import '../../../providers/google_auth_provider.dart';
import '../models/memory.dart';
import '../providers/memory_provider.dart';

class InstantMediaEditorPage extends StatefulWidget {
  final XFile media;
  final bool isVideo;

  const InstantMediaEditorPage({
    super.key,
    required this.media,
    required this.isVideo,
  });

  @override
  State<InstantMediaEditorPage> createState() => _InstantMediaEditorPageState();
}

class _InstantMediaEditorPageState extends State<InstantMediaEditorPage> {
  final _captionController = TextEditingController();
  static const _maxCaptionLength = 280;
  static const _blockedTerms = [
    'ameaça',
    'discriminação',
    'racismo',
    'violência',
    'nudez',
  ];
  VideoPlayerController? _videoController;
  int _filterIndex = 0;
  bool _publishing = false;
  static const _uploadCooldown = Duration(seconds: 30);
  final _storageService = PlatformStorageService();
  String? _validationMessage;
  String? _selectedGif;

  static const _filters = [
    ColorFilter.mode(Colors.transparent, BlendMode.dst),
    ColorFilter.mode(Color(0x553B82F6), BlendMode.color),
    ColorFilter.mode(Color(0x55F59E0B), BlendMode.color),
    ColorFilter.mode(Color(0x55EC4899), BlendMode.color),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.media.path))
            ..initialize().then((_) {
              if (mounted) setState(() {});
            });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _validateCaption(String value) {
    final normalized = value.trim().toLowerCase();
    final blocked = _blockedTerms.firstWhere(
      normalized.contains,
      orElse: () => '',
    );
    setState(() {
      _validationMessage = value.length > _maxCaptionLength
          ? 'A legenda deve ter no máximo $_maxCaptionLength caracteres.'
          : blocked.isNotEmpty
              ? 'Remova termos que violam as regras de convivência do bloco.'
              : null;
    });
  }

  Future<void> _pickGif() async {
    const gifs = [
      'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
      'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
      'https://media.giphy.com/media/26xBwdIuRJiAIqHwA/giphy.gif',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(12),
        children: gifs
            .map(
              (gif) => InkWell(
                onTap: () => Navigator.pop(context, gif),
                child: CachedNetworkImage(
                  imageUrl: gif,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(color: Colors.grey.shade300),
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedGif = selected);
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;
    _validateCaption(_captionController.text);
    if (_validationMessage != null) return;

    setState(() => _publishing = true);
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('É necessário entrar para publicar.');

      // Client-side rate limiting: prevent frequent uploads by same user
      final lastKey = 'last_upload_${user.uid}';
      final lastRaw = await _storageService.read(key: lastKey);
      if (lastRaw != null && lastRaw.isNotEmpty) {
        final last = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRaw));
        final diff = DateTime.now().difference(last);
        if (diff < _uploadCooldown) {
          final remain = _uploadCooldown - diff;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Aguarde ${remain.inSeconds}s antes de enviar outra mídia.',
                ),
              ),
            );
          }
          return;
        }
      }

      final extension = widget.isVideo ? 'mp4' : 'jpg';
      final ref = FirebaseStorage.instance.ref(
        'users/${user.uid}/memories/${const Uuid().v4()}.$extension',
      );

      try {
        if (widget.isVideo) {
          final File original = File(widget.media.path);
          final File compressed = await MediaCompressor.compressVideoFile(
            original,
          );
          await ref.putFile(compressed);
        } else {
          final File original = File(widget.media.path);
          final Uint8List compressed = await MediaCompressor.compressImageFile(
            original,
          );
          await ref.putData(
            compressed,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
      } catch (e) {
        // Wrap upload/compression errors to be handled below
        throw Exception('Erro durante compressão/upload: $e');
      }

      final url = await ref.getDownloadURL();
      final caption = _captionController.text.trim();
      final mediaUrls = [url, if (_selectedGif != null) _selectedGif!];
      await context.read<MemoryProvider>().addOrUpdate(
            Memory(
              id: const Uuid().v4(),
              title: caption.isEmpty ? 'Memória da folia' : caption,
              description: caption.isEmpty ? null : caption,
              imageUrls: mediaUrls,
              ownerId: context.read<GoogleAuthProvider>().currentUserData?.uid,
            ),
          );

      // Persist last upload time for rate limiting
      await _storageService.write(
        key: lastKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      if (mounted)
        Navigator.popUntil(context, ModalRoute.withName('/memories'));
    } catch (e) {
      if (mounted)
        await _showErrorRetry(
          'Falha ao publicar mídia: ${e.toString()}',
          _publish,
        );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _showErrorRetry(
    String message,
    Future<void> Function() retry,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Erro ao enviar mídia'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // allow retry after brief delay so UI can update
              Future.delayed(const Duration(milliseconds: 100), () => retry());
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (widget.isVideo) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      );
    }
    return FutureBuilder<Uint8List>(
      future: widget.media.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.memory(snapshot.data!, fit: BoxFit.contain);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar publicação'),
        actions: [
          IconButton(
            tooltip: 'Publicar',
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const CircularProgressIndicator()
                : const Icon(Icons.send),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColorFiltered(
                  colorFilter: _filters[_filterIndex],
                  child: _preview(),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Filtro carnavalesco',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: List.generate(
                  _filters.length,
                  (index) => ChoiceChip(
                    label: Text(index == 0 ? 'Original' : 'Folia $index'),
                    selected: _filterIndex == index,
                    onSelected: (_) => setState(() => _filterIndex = index),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _captionController,
                maxLines: 3,
                maxLength: _maxCaptionLength,
                onChanged: _validateCaption,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Legenda rápida',
                  hintText: 'Conte como foi esse momento...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_validationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _validationMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickGif,
                icon: const Icon(Icons.gif_box_outlined),
                label: Text(
                  _selectedGif == null ? 'Adicionar GIF' : 'GIF adicionado',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _publishing ? null : _publish,
                icon: const Icon(Icons.publish),
                label: const Text('Publicar memória'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
