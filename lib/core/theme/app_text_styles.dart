import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Titres éditoriaux (Stitch : EB Garamond → serif système).
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.onSurface,
    fontFamily: 'Georgia',
  );

  static const TextStyle wordmark = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.primary,
    fontFamily: 'Georgia',
  );

  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );
}
