import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/google_auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_icons.dart';

class UserAppBarActions extends StatelessWidget {
  const UserAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final google = context.watch<GoogleAuthProvider?>();
    final auth = Provider.of<AuthService?>(context, listen: false);
    final userData = google?.currentUserData;

    if (userData == null) {
      // show generic icon and a settings shortcut
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: AppIcons.themed(AppIcons.profile),
            tooltip: 'Entrar / Perfil',
            onPressed: () {
              if (auth?.currentUser != null) {
                Navigator.pushNamed(context, '/settings');
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
          ),
        ],
      );
    }

    final display = userData.displayName ?? 'Usuário';
    final photo = userData.photoUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuickNavButton(
          tooltip: 'Memórias',
          icon: AppIcons.memories,
          onPressed: () => Navigator.pushNamed(context, '/memories'),
        ),
        _QuickNavButton(
          tooltip: 'Chat',
          icon: AppIcons.chat,
          onPressed: () => Navigator.pushNamed(context, '/chat'),
        ),
        _QuickNavButton(
          tooltip: 'Foliões',
          icon: AppIcons.foliaos,
          onPressed: () => Navigator.pushNamed(context, '/foliaos'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              if (photo != null && photo.isNotEmpty)
                CircleAvatar(radius: 16, backgroundImage: NetworkImage(photo))
              else
                CircleAvatar(
                  radius: 16,
                  child: Text(
                    display.isNotEmpty ? display[0].toUpperCase() : 'U',
                  ),
                ),
              const SizedBox(width: 8),
              Text(display, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'settings') {
              Navigator.pushNamed(context, '/settings');
            } else if (v == 'profile') {
              Navigator.pushNamed(context, '/profile');
            } else if (v == 'notifications') {
              Navigator.pushNamed(context, '/notifications');
            } else if (v == 'moderation') {
              Navigator.pushNamed(context, '/admin/moderation');
            } else if (v == 'badge') {
              Navigator.pushNamed(context, '/badge');
            } else if (v == 'foliaos') {
              Navigator.pushNamed(context, '/foliaos');
            } else if (v == 'signout') {
              try {
                if (google != null) {
                  await google.signOut();
                } else if (auth != null) {
                  await auth.signOut();
                }

                // After sign out, navigate to landing
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              } catch (_) {}
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'settings',
              child: Text('Configurações'),
            ),
            const PopupMenuItem(value: 'profile', child: Text('Meu perfil')),
            const PopupMenuItem(
              value: 'notifications',
              child: Text('Notificações'),
            ),
            const PopupMenuItem(value: 'moderation', child: Text('Moderação')),
            const PopupMenuItem(
              value: 'badge',
              child: Text('Meu crachá Folião Raiz'),
            ),
            const PopupMenuItem(value: 'foliaos', child: Text('Foliões')),
            const PopupMenuItem(value: 'signout', child: Text('Sair')),
          ],
        ),
      ],
    );
  }
}

class _QuickNavButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickNavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed);
  }
}
