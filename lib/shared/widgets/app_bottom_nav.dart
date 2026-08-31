import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Barre de navigation principale — Design DODOME Émeraude
// ─────────────────────────────────────────────────────────────────────────────

/// Modèle décrivant un onglet de navigation.
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Liste centralisée des destinations de navigation.
const _destinations = [
  NavDestination(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Dashboard',
  ),
  NavDestination(
    icon: Icons.category_outlined,
    activeIcon: Icons.category_rounded,
    label: 'Catalogue',
  ),
  NavDestination(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Réservations',
  ),
  NavDestination(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
    label: 'Stock',
  ),
  NavDestination(
    icon: Icons.more_horiz_rounded,
    activeIcon: Icons.more_horiz_rounded,
    label: 'Plus',
  ),
];

/// Barre de navigation principale avec indicateur émeraude animé.
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(
              _destinations.length,
              (i) => _NavItem(
                destination: _destinations[i],
                index: i,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Élément individuel de navigation ─────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final NavDestination destination;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.destination,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Indicateur + Icône ────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: selected ? 52 : 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        selected
                            ? destination.activeIcon
                            : destination.icon,
                        key: ValueKey('${destination.label}_$selected'),
                        size: 22,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // ── Label ─────────────────────────────────────────────────
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10.5,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    height: 1.0,
                  ),
                  child: Text(destination.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
