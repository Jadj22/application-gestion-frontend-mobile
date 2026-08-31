import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum PrimaryButtonVariant { brand, inverse, glass }

/// Bouton principal avec état de chargement (requête API en cours).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final PrimaryButtonVariant variant;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = PrimaryButtonVariant.brand,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      PrimaryButtonVariant.brand => (
          AppColors.primary,
          Colors.white,
          null as Color?,
        ),
      PrimaryButtonVariant.inverse => (
          AppColors.onSurface,
          AppColors.surface,
          null,
        ),
      PrimaryButtonVariant.glass => (
          Colors.white.withValues(alpha: 0.72),
          AppColors.onSurface,
          AppColors.primaryDark.withValues(alpha: 0.1),
        ),
    };

    return Opacity(
      opacity: isLoading ? 0.75 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            disabledBackgroundColor: bg,
            shadowColor: AppColors.primaryDark.withValues(alpha: 0.08),
            elevation: variant == PrimaryButtonVariant.glass ? 0 : 2,
            foregroundColor: fg,
            disabledForegroundColor: fg,
            side: border != null ? BorderSide(color: border) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.button.copyWith(color: fg),
                    ),
                    if (variant == PrimaryButtonVariant.inverse) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18, color: fg),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}