import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Ombres et surfaces du design system DODOME (inspiré de location-platform-frontend).
class AppDecorations {
  /// Ombre diffuse et moderne
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Ombre pour cartes interactives ou sélectionnées
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Carte d'article ou composant standard (Radius 24px)
  static BoxDecoration productCard({Color? color, double radius = 24}) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: cardShadow,
      );

  /// Tuile de catégorie immersive grand format (Radius 32px)
  static BoxDecoration categoryTile({double radius = 32}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: elevatedShadow,
      );

  /// Panneau de sélection / BottomSheet (Radius 28px)
  static BoxDecoration sheetDecoration({double radius = 28}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      );

  /// Pill badge pour statuts ou compteurs (Radius 999px)
  static BoxDecoration pillBadge({required Color background, Color? border}) =>
      BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border, width: 1) : null,
      );

  /// Panneau glassmorphism (75 % blanc + bordure lumineuse).
  static BoxDecoration glassPanel({double radius = 24}) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: cardShadow,
      );

  /// Carte flottante avec fond personnalisable (StatCard, KPI, etc.)
  static BoxDecoration floatingCard({Color? color, double radius = 20}) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: cardShadow,
      );
}
