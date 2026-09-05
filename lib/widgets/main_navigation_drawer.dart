import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_icons.dart';

class MainNavigationDrawer extends StatelessWidget {
  const MainNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isMasterDeveloper = context.watch<AuthService>().isMasterUser;

    final items = <Widget>[
      DrawerHeader(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF102A72)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(AppIcons.celebration, color: Colors.white, size: 38),
            SizedBox(height: 8),
            Text(
              'Navegação La Bomba',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      _NavigationItem(
        icon: AppIcons.memories,
        label: 'Memórias',
        route: '/memories',
      ),
      _NavigationItem(
        icon: Icons.photo_library_outlined,
        label: 'Galeria do bloco',
        route: '/gallery',
      ),
      _NavigationItem(icon: AppIcons.chat, label: 'Chat', route: '/chat'),
      _NavigationItem(
        icon: Icons.rss_feed,
        label: 'Feed Social',
        route: '/social/feed',
      ),
      _NavigationItem(
        icon: Icons.hub_outlined,
        label: 'Comunidades',
        route: '/communities',
      ),
      _NavigationItem(
        icon: Icons.person_outline,
        label: 'Perfil',
        route: '/profile',
      ),
      _NavigationItem(
        icon: AppIcons.foliaos,
        label: 'Foliões',
        route: '/foliaos',
      ),
      _NavigationItem(
        icon: AppIcons.settings,
        label: 'Configurações',
        route: '/settings',
      ),
    ];

    if (isMasterDeveloper) {
      items.add(
        _NavigationItem(
          icon: Icons.developer_mode,
          label: 'Developer (God-Mode)',
          route: '/admin/master-developer',
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(padding: EdgeInsets.zero, children: items),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
