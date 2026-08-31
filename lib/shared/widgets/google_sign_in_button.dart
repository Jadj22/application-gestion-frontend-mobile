import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'google_logo.dart';

/// Bouton « Continuer avec Google » avec état de chargement dédié
/// (spinner + libellé pendant l'appel au sélecteur de compte).
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          foregroundColor: AppColors.onSurface,
          side: BorderSide(
            color: AppColors.primaryDark.withValues(alpha: 0.1),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          shadowColor: AppColors.primaryDark.withValues(alpha: 0.05),
        ),
        child: isLoading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Connexion à Google...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoogleLogo(size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Continuer avec Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}