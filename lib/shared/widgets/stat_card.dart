import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Carte KPI du tableau de bord — Design DODOME Émeraude.
///
/// Affiche une valeur, un titre, une icône et une couleur d'accentuation.
/// Un tap optionnel peut naviguer vers un écran de détail.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color? valueColor;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.bgColor = AppColors.surface,
    this.iconColor = AppColors.primary,
    this.valueColor,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: iconColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icône + Titre ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppColors.hint,
                    ),
                ],
              ),
              const Spacer(),
              // ── Valeur principale ─────────────────────────────────────
              Text(
                value,
                style: AppTextStyles.h1.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.labelCaps.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              // ── Badge optionnel ───────────────────────────────────────
              if (badge != null && badgeColor != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor!.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!.toUpperCase(),
                    style: AppTextStyles.labelCaps.copyWith(
                      color: badgeColor,
                      fontSize: 10,
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