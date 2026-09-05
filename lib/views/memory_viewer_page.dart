import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';

class MemoryViewerPage extends StatelessWidget {
  final String url;
  const MemoryViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () async {
              try {
                // Prefer sharing the direct URL; Share handles text/URLs gracefully
                await SharePlus.instance.share(
                  ShareParams(
                    text: url,
                    subject: 'Confira esta mídia - La Bomba',
                  ),
                );
              } catch (e) {
                // Fallback: show a simple snackbar on failure
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao compartilhar')),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: url,
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, _) => Shimmer.fromColors(
                baseColor: Colors.grey.shade800,
                highlightColor: Colors.grey.shade700,
                child: Container(color: Colors.grey.shade800),
              ),
              errorWidget: (context, _, __) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
