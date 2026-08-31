import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Barre de navigation — maquette Stitch « Joël Events & Décoration ».
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.dashOutlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                current: currentIndex,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
                onTap: onTap,
              ),
              _NavItem(
                index: 1,
                current: currentIndex,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2,
                label: 'Inventaire',
                onTap: onTap,
              ),
              _NavItem(
                index: 2,
                current: currentIndex,
                icon: Icons.build_outlined,
                activeIcon: Icons.build,
                label: 'Entretien',
                onTap: onTap,
              ),
              _NavItem(
                index: 3,
                current: currentIndex,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Réservations',
                onTap: onTap,
              ),
              _NavItem(
                index: 4,
                current: currentIndex,
                icon: Icons.more_horiz,
                label: 'Plus',
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int current;
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.current,
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    final color =
        selected ? AppColors.dashSecondary : AppColors.dashOnSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? (activeIcon ?? icon) : icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
