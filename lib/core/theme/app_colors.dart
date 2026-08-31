import 'package:flutter/material.dart';

/// Design System DODOME — Alignement mobile sur la charte « location-platform-frontend » (OKLCH)
class AppColors {
  /// Palette Principale « Vert Émeraude DODOME »
  static const Color primary = Color(0xFF117A65); // Émeraude identitaire
  static const Color primaryDark = Color(0xFF0B4E40); // Vert Forêt profond
  static const Color primaryDeep = Color(0xFF0D6352);
  static const Color primaryLight = Color(0xFFE6F4F0); // Vert menthe très clair
  
  /// Prix & Tarification (FCFA)
  static const Color price = Color(0xFF059669); // Vert doré / valeur
  
  /// Surfaces & Arrière-plans
  static const Color background = Color(0xFFFAF9F6); // Blanc cassé chaleureux
  static const Color surface = Color(0xFFFFFFFF); // Blanc pur cartes
  static const Color surfaceMuted = Color(0xFFF1F4F2); // Sable clair neutre
  static const Color onSurface = Color(0xFF1B2421); // Anthracite profond

  /// Typographie & Textes
  static const Color textPrimary = Color(0xFF1B2421); // Corps & titres
  static const Color textSecondary = Color(0xFF5A6A64); // Sous-titres & gris-vert
  static const Color inputBackground = Color(0xFFF4F6F5);
  static const Color border = Color(0xFFDFE5E2); // Bordures douces

  /// Statuts & Feedbacks
  static const Color success = Color(0xFFE8F8F2);
  static const Color successText = Color(0xFF0D7A55);
  static const Color warning = Color(0xFFFFF8E6);
  static const Color warningText = Color(0xFFD97706);
  static const Color danger = Color(0xFFFEECEB);
  static const Color dangerText = Color(0xFFDC2626);
  static const Color hint = Color(0xFF8F9E98);

  /// Badges de statut & KPI
  static const Color badgeAvailableBg = Color(0xFFD1FAE5);
  static const Color badgeAvailableFg = Color(0xFF047857);
  static const Color badgeAvailableBorder = Color(0xFFA7F3D0);
  
  static const Color badgeNeutralBg = Color(0xFFF1F5F9);
  static const Color badgeNeutralFg = Color(0xFF475569);
  static const Color badgeNeutralBorder = Color(0xFFE2E8F0);

  static const Color badgeIndigoBg = Color(0xFFEEF2FF);
  static const Color badgeIndigoFg = Color(0xFF4F46E5);
  static const Color badgeIndigoBorder = Color(0xFFC7D2FE);

  static const Color badgeDangerBg = Color(0xFFFEECEB);
  static const Color badgeDangerFg = Color(0xFFDC2626);
  static const Color badgeDangerBorder = Color(0xFFFCA5A5);

  static const Color kpiGreen = Color(0xFF10B981);
  static const Color kpiIndigo = Color(0xFF6366F1);
  static const Color kpiAmber = Color(0xFFF59E0B);
  static const Color kpiRose = Color(0xFFE11D48);
  static const Color kpiBlue = Color(0xFF3B82F6);
  static const Color kpiViolet = Color(0xFF8B5CF6);

  /// Aliases de compatibilité pour les widgets historiques (nav bar, home screen, etc.)
  static const Color dashPrimary = Color(0xFF117A65);        // = primary
  static const Color dashSecondary = Color(0xFF059669);      // = price
  static const Color dashSurface = Color(0xFFFFFFFF);        // = surface
  static const Color dashSurfaceLow = Color(0xFFFAF9F6);     // = background
  static const Color dashSurfaceLowest = Color(0xFFF4F7F5);
  static const Color dashSurfaceContainer = Color(0xFFF1F4F2); // = surfaceMuted
  static const Color dashSecondaryContainer = Color(0xFFE6F4F0); // = primaryLight
  static const Color dashOnSurface = Color(0xFF1B2421);      // = textPrimary
  static const Color dashOnSurfaceVariant = Color(0xFF5A6A64); // = textSecondary
  static const Color dashOutline = Color(0xFF8F9E98);        // = hint
  static const Color dashOutlineVariant = Color(0xFFDFE5E2); // = border
  static const Color dashError = Color(0xFFDC2626);          // = dangerText
  static const Color dashErrorContainer = Color(0xFFFEECEB); // = danger
  static const Color dashSurfaceTint = Color(0xFFE6F4F0);    // = primaryLight
  static const Color dashTertiaryContainer = Color(0xFFE8F5E9);
  static const Color dashTertiaryContainerBg = Color(0xFFF1FAF1);

  static Color statusBackgroundColor(String status) {
    switch (status.toUpperCase()) {
      case 'EN_ATTENTE':
      case 'DRAFT':
        return warning;
      case 'VALIDEE':
      case 'CONFIRMED':
      case 'ACTIF':
        return success;
      case 'EN_COURS':
      case 'IN_PROGRESS':
        return const Color(0xFFEFF6FF);
      case 'TERMINEE':
      case 'COMPLETED':
        return const Color(0xFFF3E8FF);
      case 'ANNULEE':
      case 'CANCELLED':
      case 'INACTIF':
        return danger;
      default:
        return surfaceMuted;
    }
  }

  static Color statusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'EN_ATTENTE':
      case 'DRAFT':
        return warningText;
      case 'VALIDEE':
      case 'CONFIRMED':
      case 'ACTIF':
        return successText;
      case 'EN_COURS':
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'TERMINEE':
      case 'COMPLETED':
        return const Color(0xFF7C3AED);
      case 'ANNULEE':
      case 'CANCELLED':
      case 'INACTIF':
        return dangerText;
      default:
        return textSecondary;
    }
  }
}
