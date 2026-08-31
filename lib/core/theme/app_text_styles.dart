import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hiérarchie typographique DODOME — alignée sur location-platform-frontend.
/// Police principale : Inter (sans-serif), Police d'affichage : Georgia (éditoriale).
class AppTextStyles {
  // ─── Titres ─────────────────────────────────────────────────────────────

  /// Très grand titre d'accroche (Hero Banner login / splash)
  static const TextStyle display = TextStyle(
    fontSize: 36,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
    fontFamily: 'Georgia',
  );

  /// Titre de section principal (H1)
  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Titre secondaire (H2) — Modales, sous-sections
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  /// Titre de carte ou de ligne de liste (H3)
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // ─── Corps de texte ──────────────────────────────────────────────────────

  /// Corps standard — descriptions, paragraphes
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Corps secondaire — légendes, métadonnées
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  // ─── Bouton ──────────────────────────────────────────────────────────────

  /// Texte bouton principal (Plein)
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.1,
    height: 1.2,
  );

  // ─── Labels & Badges ────────────────────────────────────────────────────

  /// Label de champ de formulaire
  static const TextStyle fieldLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
    height: 1.3,
  );

  /// Capsule de badge / statut en MAJUSCULE
  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.textSecondary,
    height: 1.0,
  );

  // ─── Valeurs & Prix ─────────────────────────────────────────────────────

  /// Montant monétaire principal (FCFA)
  static const TextStyle price = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.price,
    letterSpacing: -0.3,
    height: 1.1,
  );

  /// Prix plus petit (liste ou résumé)
  static const TextStyle priceSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.price,
    letterSpacing: -0.1,
    height: 1.2,
  );

  // ─── Marque ─────────────────────────────────────────────────────────────

  /// Logo texte DODOME (wordmark)
  static const TextStyle wordmark = TextStyle(
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: AppColors.primary,
    fontFamily: 'Georgia',
  );
}
