import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Ombres et surfaces du design system Stitch « DODOME Premium B2B ».
class AppDecorations {
  /// Halo shadow — ombre diffuse teintée navy, sans offset directionnel.
  static List<BoxShadow> get haloShadow => [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.05),
          blurRadius: 50,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Panneau glassmorphism (70 % blanc + bordure lumineuse).
  static BoxDecoration glassPanel({double radius = 24}) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: haloShadow,
      );

  static BoxDecoration floatingCard({Color? color, double radius = 20}) =>
      BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: cardShadow,
      );
}
