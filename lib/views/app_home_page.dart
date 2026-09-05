import 'package:flutter/material.dart';

import '../features/profile/user_profile_page.dart';
import '../features/social/views/community_page.dart';
import '../features/social/views/social_feed_page.dart';
import '../theme/la_bomba_design_system.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage({super.key});

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  int _currentIndex = 0;

  static const List<_HomeTab> _tabs = [
    _HomeTab(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Feed',
      page: SocialFeedPage(),
    ),
    _HomeTab(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Comunidade',
      page: CommunityPage(),
    ),
    _HomeTab(
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: 'Perfil',
      page: UserProfilePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: LaBombaColors.background,
      appBar: AppBar(
        title: const Text('ORBE'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: LaBombaColors.textPrimary,
        titleTextStyle: const TextStyle(
          color: LaBombaColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        actions: [
          _ActionIcon(
            icon: Icons.notifications_none_rounded,
            onTap: () => Navigator.pushNamed(context, '/notifications'),
          ),
          const SizedBox(width: 8),
          _ActionIcon(
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => Navigator.pushNamed(context, '/chat'),
            accent: true,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: LaBombaDecorations.shell,
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _tabs.map((tab) => tab.page).toList(),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: LaBombaColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: LaBombaColors.borderSoft, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x25101218),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: LaBombaColors.primary,
          unselectedItemColor: LaBombaColors.textMuted,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: _tabs
              .map(
                (tab) => BottomNavigationBarItem(
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.all(
                        _currentIndex == _tabs.indexOf(tab) ? 8 : 6),
                    decoration: _currentIndex == _tabs.indexOf(tab)
                        ? BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                LaBombaColors.primary,
                                LaBombaColors.digitalBlue
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4D7C3AED),
                                blurRadius: 12,
                                offset: Offset(0, 8),
                              ),
                            ],
                          )
                        : null,
                    child: Icon(
                      _currentIndex == _tabs.indexOf(tab)
                          ? tab.selectedIcon
                          : tab.icon,
                      color: _currentIndex == _tabs.indexOf(tab)
                          ? Colors.white
                          : LaBombaColors.textMuted,
                    ),
                  ),
                  label: tab.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent
            ? LaBombaColors.primary.withValues(alpha: 0.14)
            : LaBombaColors.card.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(LaBombaRadius.medium),
        border: Border.all(
          color: accent
              ? LaBombaColors.primary.withValues(alpha: 0.35)
              : LaBombaColors.borderSoft,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon,
            color: accent ? LaBombaColors.white : LaBombaColors.textPrimary),
        splashRadius: 18,
      ),
    );
  }
}

class _HomeTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const _HomeTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}
