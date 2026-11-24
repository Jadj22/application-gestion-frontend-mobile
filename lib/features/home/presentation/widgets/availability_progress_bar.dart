import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Barre segmentée vert / orange / rouge pour la disponibilité stock.
class AvailabilityProgressBar extends StatelessWidget {
  final int disponible;
  final int entretien;
  final int endommage;
  final int total;
  final double height;

  const AvailabilityProgressBar({
    super.key,
    required this.disponible,
    required this.entretien,
    required this.endommage,
    required this.total,
    this.height = 7,
  });

  @override
  Widget build(BuildContext context) {
    final green = disponible.clamp(0, 1 << 30);
    final orange = entretien.clamp(0, 1 << 30);
    final red = endommage.clamp(0, 1 << 30);
    final sum = green + orange + red;
    final denominator = sum > 0 ? sum : (total > 0 ? total : 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Row(
          children: [
            if (green > 0)
              Flexible(
                flex: green,
                child: Container(color: AppColors.success),
              ),
            if (orange > 0)
              Flexible(
                flex: orange,
                child: Container(color: AppColors.warning),
              ),
            if (red > 0)
              Flexible(
                flex: red,
                child: Container(color: AppColors.danger),
              ),
            if (sum == 0)
              Flexible(
                flex: denominator,
                child: Container(color: AppColors.surfaceMuted),
              )
            else if (total > sum)
              Flexible(
                flex: (total - sum).clamp(1, 1 << 30),
                child: Container(color: AppColors.surfaceMuted),
              ),
          ],
        ),
      ),
    );
  }
}
