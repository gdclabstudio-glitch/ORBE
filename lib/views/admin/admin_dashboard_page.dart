import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin/admin_sidebar.dart';
import 'client_base_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  final List<String> _sectionTitles = ['Base de Clientes'];

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AdminAuthProvider>().isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        final sidebar = AdminSidebar(
          selectedIndex: _selectedIndex,
          forceExpanded: !isDesktop,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            if (!isDesktop && Scaffold.of(context).isDrawerOpen) {
              Navigator.pop(context);
            }
          },
          onLogout: () async {
            await context.read<AdminAuthProvider>().logout();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            }
          },
        );

        final isMasterDeveloper = context.watch<AuthService>().isMasterUser;

        return Scaffold(
          appBar: AppBar(
            title: Text('LaBomba Admin • ${_sectionTitles[_selectedIndex]}'),
            actions: [
              if (isMasterDeveloper)
                TextButton.icon(
                  onPressed: () {
                    final authService = context.read<AuthService>();
                    final isAllowed = authService.isMasterUser;

                    if (!isAllowed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Acesso negado')),
                      );
                      return;
                    }

                    Navigator.pushNamed(context, '/admin/god-mode');
                  },
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('God-Mode'),
                ),
            ],
          ),
          drawer: isDesktop ? null : Drawer(child: sidebar),
          body: Row(
            children: [
              if (isDesktop) sidebar,
              const Expanded(child: ClientBasePage(embedded: true)),
            ],
          ),
        );
      },
    );
  }
}
