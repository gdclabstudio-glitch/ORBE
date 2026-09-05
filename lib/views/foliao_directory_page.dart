import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/services/foliao_directory_service.dart';
import '../providers/google_auth_provider.dart';
import '../widgets/user_appbar_actions.dart';

class FoliaoDirectoryPage extends StatefulWidget {
  const FoliaoDirectoryPage({super.key});

  @override
  State<FoliaoDirectoryPage> createState() => _FoliaoDirectoryPageState();
}

class _FoliaoDirectoryPageState extends State<FoliaoDirectoryPage> {
  final FoliaoDirectoryService _service = FoliaoDirectoryService();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final currentUid = context.watch<GoogleAuthProvider>().currentUserData?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diretório de Foliões'),
        actions: [UserAppBarActions()],
      ),
      body: StreamBuilder<List<FoliaoProfile>>(
        stream: _service.streamFoliaos(excludeUid: currentUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os foliões.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final foliaos = snapshot.data!
              .where(
                (profile) => profile.displayName.toLowerCase().contains(
                      _query.trim().toLowerCase(),
                    ),
              )
              .toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar foliões',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: foliaos.isEmpty
                    ? const Center(child: Text('Nenhum folião encontrado.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: foliaos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final foliao = foliaos[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    foliao.photoUrl?.isNotEmpty == true
                                        ? NetworkImage(foliao.photoUrl!)
                                        : null,
                                child: foliao.photoUrl?.isNotEmpty == true
                                    ? null
                                    : Text(foliao.displayName[0].toUpperCase()),
                              ),
                              title: Text(foliao.displayName),
                              subtitle: foliao.email == null
                                  ? null
                                  : Text(foliao.email!),
                              trailing: FilledButton.icon(
                                onPressed: currentUid == null
                                    ? null
                                    : () => Navigator.pushNamed(
                                          context,
                                          '/chat',
                                          arguments: foliao.uid,
                                        ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Conversar'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
