import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/google_auth_provider.dart';
import '../widgets/user_appbar_actions.dart';

class BadgeGeneratorPage extends StatelessWidget {
  const BadgeGeneratorPage({super.key});

  Future<void> _shareBadge(BuildContext context, String name) async {
    final text = Uri.encodeComponent(
      'Sou Foliao Raiz da La Bomba! Vem curtir o carnaval comigo, $name.',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum app de compartilhamento disponível.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<GoogleAuthProvider>().currentUserData;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crachá Folião Raiz')),
        body: const Center(child: Text('Entre para gerar seu crachá.')),
      );
    }

    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : 'Folião';
    final photoUrl = user.photoUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crachá Folião Raiz'),
        actions: [UserAppBarActions()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: .72,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF6A00),
                      Color(0xFFEC4899),
                      Color(0xFF7C1AFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'LA BOMBA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'CARNAVAL 2027',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 70,
                        backgroundImage: photoUrl?.isNotEmpty == true
                            ? NetworkImage(photoUrl!)
                            : null,
                        child: photoUrl?.isNotEmpty == true
                            ? null
                            : Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 48),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Chip(
                        avatar: Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                        ),
                        label: Text('FOLIÃO RAIZ'),
                      ),
                      const Spacer(),
                      const Text(
                        'PEÇANHA • MG',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _shareBadge(context, name),
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar nas redes'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu crachá está pronto para celebrar e compartilhar a energia da La Bomba.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
