import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_feedback.dart';
import '../../../views/memory_viewer_page.dart';
import '../models/memory.dart';
import '../providers/memory_provider.dart';

class BlockGalleryPage extends StatefulWidget {
  const BlockGalleryPage({super.key});

  @override
  State<BlockGalleryPage> createState() => _BlockGalleryPageState();
}

class _BlockGalleryPageState extends State<BlockGalleryPage> {
  String _dateFilter = 'Todas';
  String _authorFilter = 'Todos';

  List<Memory> _filteredMemories(List<Memory> memories) {
    final now = DateTime.now();
    return memories
        .where((memory) {
          if (_authorFilter != 'Todos' && memory.ownerId != _authorFilter) {
            return false;
          }
          if (_dateFilter == 'Hoje') {
            final date = memory.createdAt.toLocal();
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }
          if (_dateFilter == 'Últimos 7 dias') {
            return now.difference(memory.createdAt.toLocal()).inDays < 7;
          }
          return true;
        })
        .where((memory) => memory.imageUrls.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _share(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      AppFeedback.showSuccess(
        context,
        'Link da mídia copiado para compartilhar.',
      );
    }
  }

  Future<void> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppFeedback.showError(
          context,
          'Não foi possível abrir a mídia em alta resolução.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memories = context.watch<MemoryProvider>().memories;
    final authors = memories
        .map((memory) => memory.ownerId)
        .whereType<String>()
        .where((ownerId) => ownerId.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final filtered = _filteredMemories(memories);

    return Scaffold(
      appBar: AppBar(title: const Text('Galeria do bloco')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _filter(
                          'Data',
                          _dateFilter,
                          [
                            'Todas',
                            'Hoje',
                            'Últimos 7 dias',
                          ],
                          (value) => setState(() => _dateFilter = value)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _filter(
                          'Autor',
                          _authorFilter,
                          [
                            'Todos',
                            ...authors,
                          ],
                          (value) => setState(() => _authorFilter = value)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma mídia encontrada para estes filtros.',
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount =
                              width > 1000 ? 4 : (width > 700 ? 3 : 2);
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _GalleryTile(
                              memory: filtered[index],
                              onShare: _share,
                              onDownload: _download,
                              onView: (url) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MemoryViewerPage(url: url),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filter(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final Memory memory;
  final ValueChanged<String> onShare;
  final ValueChanged<String> onDownload;
  final ValueChanged<String>? onView;

  const _GalleryTile({
    required this.memory,
    required this.onShare,
    required this.onDownload,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final url = memory.imageUrls.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap:
                  onView != null ? () => onView!(url) : () => onDownload(url),
              child: _GalleryMedia(url: url),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
            child: Text(
              memory.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Compartilhar mídia',
                icon: const Icon(Icons.share_outlined, color: AppTheme.primary),
                onPressed: () => onShare(url),
              ),
              IconButton(
                tooltip: 'Abrir mídia em alta resolução',
                icon: const Icon(
                  Icons.download_outlined,
                  color: AppTheme.primary,
                ),
                onPressed: () => onDownload(url),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryMedia extends StatefulWidget {
  final String url;

  const _GalleryMedia({required this.url});

  @override
  State<_GalleryMedia> createState() => _GalleryMediaState();
}

class _GalleryMediaState extends State<_GalleryMedia> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) {
            _controller!
              ..setLooping(true)
              ..play();
            setState(() {});
          }
        });
    }
  }

  bool _isVideo(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return ['.mp4', '.mov', '.webm', '.m3u8'].any(path.endsWith);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      if (!controller.value.isInitialized) {
        // Shimmer skeleton for video placeholder
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(color: Colors.grey.shade300),
        );
      }
      return Hero(
        tag: widget.url,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }
    return Hero(
      tag: widget.url,
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: BoxFit.cover,
        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(color: Colors.grey.shade300),
        ),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
