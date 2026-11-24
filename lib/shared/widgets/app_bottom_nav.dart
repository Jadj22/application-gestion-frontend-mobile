import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Barre de navigation principale — Design épuré iOS / SF Pro / Inter
// Conforme à la spécification visuelle « Test déco – Écrans de l'app »
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

/// Liste des 5 destinations de navigation principales.
const destinations = [
  NavDestination(
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    label: 'Accueil',
  ),
  NavDestination(
    icon: Icons.layers_outlined,
    activeIcon: Icons.layers_rounded,
    label: 'Inventaire',
  ),
  NavDestination(
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Réservations',
  ),
  NavDestination(
    icon: Icons.build_outlined,
    activeIcon: Icons.build_rounded,
    label: 'Entretien',
  ),
  NavDestination(
    icon: Icons.more_horiz_outlined,
    activeIcon: Icons.more_horiz_rounded,
    label: 'Plus',
  ),
];

/// Barre de navigation inférieure iOS (Hauteur 68px, fond #F5F5F7, bordure #E0E0E0).
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
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(
              destinations.length,
              (i) => _NavItem(
                destination: destinations[i],
                index: i,
                isSelected: i == currentIndex,
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavDestination destination;
  final int index;
  final bool isSelected;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.destination,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textSecondary;
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: () => onTap(index),
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Semantics(
            selected: isSelected,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? destination.activeIcon : destination.icon,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.navLabel.copyWith(
                      color: color,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
