import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color? valueColor;
  final double height;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.bgColor = AppColors.surface,
    this.iconColor = AppColors.primary,
    this.valueColor,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.floatingCard(color: bgColor, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const Spacer(),
          Text(title.toUpperCase(), style: AppTextStyles.fieldLabel),
          const SizedBox(height: 4),
          Text(
            value,
            style: valueColor == null
                ? AppTextStyles.h1
                : AppTextStyles.h1.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}