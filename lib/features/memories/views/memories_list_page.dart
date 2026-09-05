import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:labomba_app/services/street_mode_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import 'memory_editor_page.dart';

import 'package:labomba_app/theme/app_theme.dart';
import 'package:labomba_app/widgets/main_navigation_drawer.dart';
import 'package:labomba_app/features/memories/providers/memory_provider.dart';
import 'package:labomba_app/widgets/user_appbar_actions.dart';
import 'package:labomba_app/features/memories/widgets/memory_social_panel.dart';
import 'package:labomba_app/features/memories/models/memory.dart';
import 'package:labomba_app/features/memories/services/memory_social_service.dart';
import 'package:labomba_app/widgets/heat_explosion_widget.dart';
import 'package:labomba_app/widgets/official_horn_listener.dart';

class MemoriesListPage extends StatelessWidget {
  const MemoriesListPage({super.key});

  // Vibrant palette tuned for carnival
  static const Color _bgGradientStart = Color(0xFF7C1AFF); // magenta/purple
  static const Color _bgGradientEnd = Color(0xFFFF6A00); // orange
  static const double _cardRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();

    return Scaffold(
      drawer: const MainNavigationDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Abrir navegação',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Memórias'),
        backgroundColor: _bgGradientStart,
        elevation: 2,
        actions: [UserAppBarActions()],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgGradientStart, _bgGradientEnd],
              ),
            ),
            child: Builder(
              builder: (context) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Text(
                      'Erro: ${provider.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                // Sort memories chronologically (newest first)
                final List<Memory> items = List.from(provider.memories)
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma memória encontrada',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: items.length +
                          1, // +1 for the stories carousel header
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _FameWallCarousel(
                            memories: items,
                            accentColor: AppTheme.primary,
                          );
                        }

                        final m = items[index - 1];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemoryDetailPage(memory: m),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(_cardRadius),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(
                                    _cardRadius,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.primaryLight.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    if (m.imageUrls.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _MemoryMediaPreview(
                                          url: m.imageUrls.first,
                                          width: 84,
                                          height: 84,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.photo,
                                          color: Colors.white30,
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (m.description != null)
                                            Text(
                                              m.description!,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${m.createdAt.toLocal()}',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    MemorySocialPanel(
                                      memoryId: m.id,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const OfficialHornListener(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HeatExplosionWidget(),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'create-memory',
            backgroundColor: AppTheme.primary,
            tooltip: 'Criar nova memória',
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MemoryEditorPage())),
          ),
        ],
      ),
    );
  }
}

class MemoryDetailPage extends StatelessWidget {
  final Memory memory;
  const MemoryDetailPage({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(memory.title),
        backgroundColor: const Color(0xFF7C1AFF),
        actions: [UserAppBarActions()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryLight.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memory.description ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Data: ${memory.date.toLocal()}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            MemorySocialPanel(memoryId: memory.id),
            const SizedBox(height: 12),
            if (memory.imageUrls.isNotEmpty) ...[
              const Text('Imagens:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (_, idx) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _MemoryMediaPreview(
                      url: memory.imageUrls[idx],
                      width: 160,
                      height: 120,
                    ),
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: memory.imageUrls.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryMediaPreview extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const _MemoryMediaPreview({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  State<_MemoryMediaPreview> createState() => _MemoryMediaPreviewState();
}

class _MemoryMediaPreviewState extends State<_MemoryMediaPreview>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isVideo = false;
  bool _streetMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _streetMode = context.read<StreetModeService>().enabled;
    _isVideo = _looksLikeVideo(widget.url);
    if (_isVideo && !_streetMode) _initializeVideo();
  }

  bool _looksLikeVideo(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm') ||
        path.endsWith('.m3u8');
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(true);
    await controller.play();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      if (!_streetMode) controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_isVideo) {
      return CachedNetworkImage(
        imageUrl: widget.url,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _FameWallCarousel extends StatefulWidget {
  final List<Memory> memories;
  final Color accentColor;

  const _FameWallCarousel({required this.memories, required this.accentColor});

  @override
  State<_FameWallCarousel> createState() => _FameWallCarouselState();
}

class _FameWallCarouselState extends State<_FameWallCarousel> {
  final MemorySocialService _socialService = MemorySocialService();
  late Future<List<_EngagedMemory>> _highlights;

  @override
  void initState() {
    super.initState();
    _highlights = _loadHighlights();
  }

  @override
  void didUpdateWidget(covariant _FameWallCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memories != widget.memories) {
      _highlights = _loadHighlights();
    }
  }

  Future<List<_EngagedMemory>> _loadHighlights() async {
    final today = DateTime.now();
    final candidates = widget.memories.where((memory) {
      final created = memory.createdAt.toLocal();
      return created.year == today.year &&
          created.month == today.month &&
          created.day == today.day &&
          memory.imageUrls.isNotEmpty;
    }).take(20);
    final scored = await Future.wait(
      candidates.map((memory) async {
        final score = await _socialService.engagementCount(memory.id);
        return _EngagedMemory(memory: memory, score: score);
      }),
    );
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(8).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_EngagedMemory>>(
      future: _highlights,
      builder: (context, snapshot) {
        final highlights = snapshot.data ?? const <_EngagedMemory>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 190,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        if (highlights.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                child: Text(
                  'Mural da fama',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: highlights.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final highlight = highlights[index];
                    return _FameWallCard(
                      highlight: highlight,
                      accentColor: widget.accentColor,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EngagedMemory {
  final Memory memory;
  final int score;

  const _EngagedMemory({required this.memory, required this.score});
}

class _FameWallCard extends StatelessWidget {
  final _EngagedMemory highlight;
  final Color accentColor;

  const _FameWallCard({required this.highlight, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final memory = highlight.memory;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MemoryDetailPage(memory: memory)),
      ),
      child: Container(
        width: 142,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.9),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _MemoryMediaPreview(
              url: memory.imageUrls.first,
              width: 142,
              height: 154,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${highlight.score} interações',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
