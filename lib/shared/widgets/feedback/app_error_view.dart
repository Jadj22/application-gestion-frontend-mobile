import 'package:flutter/material.dart';
import 'package:dodome/core/theme/app_colors.dart';
import 'package:dodome/core/theme/app_text_styles.dart';

/// Reusable error view widget for displaying an error icon, error message,
/// optional title, and an optional retry button.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.cloud_off,
    this.onRetry,
    this.retryLabel = 'Réessayer',
    this.showRetry = true,
    this.iconSize = 48.0,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
  });

  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool showRetry;
  final double iconSize;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final canRetry = showRetry && onRetry != null;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? AppColors.dashOutline,
            ),
            const SizedBox(height: 16),
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            if (canRetry) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
