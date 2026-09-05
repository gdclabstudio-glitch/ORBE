import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AdminSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final bool forceExpanded; // when used inside Drawer on mobile, show labels

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    this.forceExpanded = false,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final expanded = widget.forceExpanded || _isExpanded;
    return MouseRegion(
      onEnter: widget.forceExpanded
          ? null
          : (_) => setState(() => _isExpanded = true),
      onExit: widget.forceExpanded
          ? null
          : (_) => setState(() => _isExpanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: expanded ? 240 : 80,
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          boxShadow: [
            if (expanded)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(5, 0),
              ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Header Logo
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  expanded ? _buildExpandedHeader() : _buildCollapsedHeader(),
            ),
            const SizedBox(height: 48),
            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _SidebarItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Clientes',
                    isSelected: widget.selectedIndex == 0,
                    isExpanded: expanded,
                    onTap: () => widget.onDestinationSelected(0),
                  ),
                ],
              ),
            ),
            // Footer (Logout)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _SidebarItem(
                icon: Icons.logout_rounded,
                label: 'Sair',
                isSelected: false,
                isExpanded: expanded,
                onTap: widget.onLogout,
                isDestructive: true,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader() {
    return Image.asset(
      'assets/images/labomba_banner.png',
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.flash_on, color: AppTheme.primary, size: 36),
    );
  }

  Widget _buildExpandedHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/labomba_banner.png',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.flash_on, color: AppTheme.primary, size: 28),
        ),
        const SizedBox(width: 12),
        const Text(
          'LABOMBA',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        widget.isDestructive ? Colors.redAccent : AppTheme.primary;
    final fgColor = widget.isSelected
        ? activeColor
        : (_isHovered ? Colors.white : Colors.white60);
    final bgColor = widget.isSelected
        ? activeColor.withValues(alpha: 0.15)
        : (_isHovered
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: widget.isExpanded ? 16 : 0,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? activeColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: widget.isExpanded
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(8),
                child: Icon(
                  widget.icon,
                  color: fgColor,
                  size: widget.isSelected ? 26 : 24,
                ),
              ),
              if (widget.isExpanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 15,
                      fontWeight:
                          widget.isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
