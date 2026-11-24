import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hiérarchie typographique DODOME — Charte SF Pro Text / Inter.
/// Conforme à la spécification visuelle « Test déco – Écrans de l'app ».
class AppTextStyles {
  // ─── Chiffres & Displays ────────────────────────────────────────────────
  /// Grand chiffre KPI (ex: 150)
  static const TextStyle display = TextStyle(
    fontSize: 44,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
    color: AppColors.textPrimary,
    fontFamily: 'Inter',
  );

  /// Chiffre KPI moyen (ex: 26)
  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    fontFamily: 'Inter',
  );

  // ─── Titres ─────────────────────────────────────────────────────────────
  /// Titre de section principal (H1)
  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
    fontFamily: 'Inter',
  );

  /// Titre de groupe (H2) — ex: "Aujourd'hui", "À venir" (21px)
  static const TextStyle h2 = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.23,
    height: 1.25,
    fontFamily: 'Inter',
  );

  /// Titre d'élément (H3) — ex: "Réservation à valider", "Mariage Adjovi" (17px)
  static const TextStyle h3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.37,
    height: 1.25,
    fontFamily: 'Inter',
  );

  // ─── Corps de texte ──────────────────────────────────────────────────────
  /// Corps standard (17px normal)
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: -0.37,
    height: 1.3,
    fontFamily: 'Inter',
  );

  /// Corps secondaire (14px) — descriptions, détails
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: -0.22,
    height: 1.3,
    fontFamily: 'Inter',
  );

  /// Légende / métadonnée (12px)
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: -0.12,
    height: 1.2,
    fontFamily: 'Inter',
  );

  /// Légende en gras (12px w600) — ex: "1 point à traiter", pill text
  static const TextStyle captionBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.12,
    height: 1.2,
    fontFamily: 'Inter',
  );

  // ─── Boutons & Navigation ────────────────────────────────────────────────
  /// Bouton principal
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: -0.2,
    height: 1.2,
    fontFamily: 'Inter',
  );

  /// Label navigation bar (10px)
  static const TextStyle navLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.08,
    fontFamily: 'Inter',
  );

  // ─── Labels & Badges ────────────────────────────────────────────────────
  /// Capsule / En-tête de section en majuscule (11px ou 12px)
  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
    color: AppColors.textSecondary,
    height: 1.0,
    fontFamily: 'Inter',
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.3,
    fontFamily: 'Inter',
  );

  // ─── Valeurs & Prix ─────────────────────────────────────────────────────
  static const TextStyle price = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.1,
    fontFamily: 'Inter',
  );

  static const TextStyle priceSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.2,
    fontFamily: 'Inter',
  );

  // ─── Marque ─────────────────────────────────────────────────────────────
  static const TextStyle wordmark = TextStyle(
    fontSize: 28,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.primary,
    fontFamily: 'Inter',
  );
}
