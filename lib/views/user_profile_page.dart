import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/memories/models/memory.dart';
import '../features/memories/providers/memory_provider.dart';
import '../features/memories/views/memories_list_page.dart';
import '../providers/google_auth_provider.dart';
import '../models/admin_profile.dart';
import '../services/admin_profile_service.dart';
import '../services/storage_platform.dart';
import '../widgets/user_appbar_actions.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  AdminProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MemoryProvider>().load();
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final profile = await AdminProfileService(storage: PlatformStorageService())
        .getCurrentUserProfile();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<GoogleAuthProvider>().currentUserData;
    final memories = context.watch<MemoryProvider>().memories;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meu perfil')),
        body: const Center(child: Text('Entre para acessar seu perfil.')),
      );
    }

    final ownMemories = memories
        .where((memory) => memory.ownerId == user.uid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        actions: [UserAppBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: context.read<MemoryProvider>().load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundImage: user.photoUrl?.isNotEmpty == true
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl?.isNotEmpty == true
                          ? null
                          : Text(
                              displayName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 30),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (user.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.email!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if ((_profile?.bio ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_profile!.bio!, textAlign: TextAlign.center),
                    ],
                    if (_profile?.socialLinks.isNotEmpty == true)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: _profile!.socialLinks.entries
                            .where((entry) => entry.value.isNotEmpty)
                            .map(
                              (entry) => ActionChip(
                                avatar: Icon(_socialIcon(entry.key), size: 18),
                                label: Text(entry.key),
                                onPressed: () => launchUrl(
                                  Uri.parse(entry.value),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    Text('${ownMemories.length} memórias publicadas'),
                  ],
                ),
              ),
            ),
            if (ownMemories.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Você ainda não publicou memórias.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _MemoryTile(memory: ownMemories[index]),
                    childCount: ownMemories.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _socialIcon(String network) {
    switch (network) {
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'tiktok':
        return Icons.music_note_outlined;
      case 'twitter':
        return Icons.alternate_email;
      case 'whatsapp':
        return Icons.chat_outlined;
      default:
        return Icons.link;
    }
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MemoryDetailPage(memory: memory)),
      ),
      onLongPress: () => _showManagementMenu(context),
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: memory.imageUrls.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    memory.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            : CachedNetworkImage(
errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                imageUrl: memory.imageUrls.first,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      ),
    );
  }

  Future<void> _showManagementMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizar'),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text('Excluir memória'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'view') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MemoryDetailPage(memory: memory)),
      );
    } else if (action == 'delete') {
      await context.read<MemoryProvider>().remove(memory.id);
    }
  }
}
