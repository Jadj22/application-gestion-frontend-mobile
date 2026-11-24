import 'package:flutter/material.dart';

/// Design System DODOME — Charte iOS / SF Pro / Inter
/// Conforme à la spécification visuelle « Test déco – Écrans de l'app »
class AppColors {
  // ─── Accent Principal ─────────────────────────────────────────────────────
  /// Bleu Apple d'action et d'accentuation (#0066CC)
  static const Color primary = Color(0xFF0066CC);
  static const Color primaryDark = Color(0xFF004DA3);
  static const Color primaryDeep = Color(0xFF003D82);
  static const Color primaryLight = Color(0xFFE6F0FB); // Fond de badge bleu

  /// Prix & Tarification (FCFA)
  static const Color price = Color(0xFF1D1D1F);

  // ─── Surfaces & Arrière-plans ─────────────────────────────────────────────
  /// Fond d'écran global (#F5F5F7)
  static const Color background = Color(0xFFF5F5F7);
  /// Cartes et sections (#FFFFFF)
  static const Color surface = Color(0xFFFFFFFF);
  /// Surfaces secondaires / segmented controls / pistes (#E8E8ED)
  static const Color surfaceMuted = Color(0xFFE8E8ED);
  /// Texte sur surface
  static const Color onSurface = Color(0xFF1D1D1F);

  // ─── Typographie & Textes ─────────────────────────────────────────────────
  /// Titres et texte principal (#1D1D1F)
  static const Color textPrimary = Color(0xFF1D1D1F);
  /// Sous-titres et métadonnées (#6E6E73)
  static const Color textSecondary = Color(0xFF6E6E73);
  /// Fond des champs de formulaire
  static const Color inputBackground = Color(0xFFFFFFFF);
  /// Fond des barres de recherche grises
  static const Color inputBackgroundMuted = Color(0xFFE8E8ED);

  // ─── Bordures & Séparateurs ───────────────────────────────────────────────
  /// Bordure standard 1px (#E0E0E0)
  static const Color border = Color(0xFFE0E0E0);
  /// Bordure légère (#E8E8ED)
  static const Color borderLight = Color(0xFFE8E8ED);

  // ─── Statuts & Feedbacks ──────────────────────────────────────────────────
  /// Vert succès / Validé / Disponible (#34C759)
  static const Color success = Color(0xFF34C759);
  static const Color successBg = Color(0xFFE8F8F2);
  static const Color successText = Color(0xFF1E7D5F);

  /// Orange attention / Entretien (#FF9500 / #C25E00)
  static const Color warning = Color(0xFFFF9500);
  static const Color warningBg = Color(0xFFFFF4E5);
  static const Color warningText = Color(0xFFC25E00);

  /// Rouge danger / Erreur / Date (#D70015 / #FF3B30)
  static const Color danger = Color(0xFFD70015);
  static const Color dangerBg = Color(0xFFFEECEB);
  static const Color dangerText = Color(0xFFD70015);

  /// Teinte neutre estompée / placeholders (#86868B)
  static const Color hint = Color(0xFF86868B);

  // ─── Badges de statut & KPI ───────────────────────────────────────────────
  static const Color badgeAvailableBg = Color(0xFFE8F8F2);
  static const Color badgeAvailableFg = Color(0xFF1E7D5F);
  static const Color badgeAvailableBorder = Color(0xFFBCE7D6);

  static const Color badgeNeutralBg = Color(0xFFF5F5F7);
  static const Color badgeNeutralFg = Color(0xFF1D1D1F);
  static const Color badgeNeutralBorder = Color(0xFFE0E0E0);

  static const Color badgeIndigoBg = Color(0xFFE6F0FB);
  static const Color badgeIndigoFg = Color(0xFF0066CC);
  static const Color badgeIndigoBorder = Color(0xFFB8D5F8);

  static const Color badgeDangerBg = Color(0xFFFEECEB);
  static const Color badgeDangerFg = Color(0xFFD70015);
  static const Color badgeDangerBorder = Color(0xFFFCA5A5);

  static const Color kpiGreen = Color(0xFF34C759);
  static const Color kpiIndigo = Color(0xFF0066CC);
  static const Color kpiAmber = Color(0xFFFF9500);
  static const Color kpiRose = Color(0xFFD70015);
  static const Color kpiBlue = Color(0xFF0066CC);
  static const Color kpiViolet = Color(0xFF5856D6);

  // ─── Aliases de compatibilité historique ──────────────────────────────────
  static const Color dashPrimary = Color(0xFF0066CC);
  static const Color dashSecondary = Color(0xFF0066CC);
  static const Color dashSurface = Color(0xFFFFFFFF);
  static const Color dashSurfaceLow = Color(0xFFF5F5F7);
  static const Color dashSurfaceLowest = Color(0xFFFFFFFF);
  static const Color dashSurfaceContainer = Color(0xFFE8E8ED);
  static const Color dashSecondaryContainer = Color(0xFFE6F0FB);
  static const Color dashOnSurface = Color(0xFF1D1D1F);
  static const Color dashOnSurfaceVariant = Color(0xFF6E6E73);
  static const Color dashOutline = Color(0xFFB0B0B5);
  static const Color dashOutlineVariant = Color(0xFFE0E0E0);
  static const Color dashError = Color(0xFFD70015);
  static const Color dashErrorContainer = Color(0xFFFEECEB);
  static const Color dashSurfaceTint = Color(0xFFE6F0FB);
  static const Color dashTertiaryContainer = Color(0xFFE8F8F2);
  static const Color dashTertiaryContainerBg = Color(0xFFE8F8F2);

  static Color statusBackgroundColor(String status) {
    switch (status.toUpperCase()) {
      case 'EN_ATTENTE':
      case 'DRAFT':
        return warningBg;
      case 'VALIDEE':
      case 'CONFIRMED':
      case 'ACTIF':
        return successBg;
      case 'EN_COURS':
      case 'IN_PROGRESS':
        return primaryLight;
      case 'TERMINEE':
      case 'COMPLETED':
        return const Color(0xFFF5F5F7);
      case 'ANNULEE':
      case 'CANCELLED':
      case 'INACTIF':
        return dangerBg;
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
        return primary;
      case 'TERMINEE':
      case 'COMPLETED':
        return textSecondary;
      case 'ANNULEE':
      case 'CANCELLED':
      case 'INACTIF':
        return dangerText;
      default:
        return textSecondary;
    }
  }
}
