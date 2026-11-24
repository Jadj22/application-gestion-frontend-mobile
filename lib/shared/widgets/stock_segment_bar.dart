import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Barre de répartition stock : disponible / entretien / abîmé / reste.
class StockSegmentBar extends StatelessWidget {
  final int disponible;
  final int entretien;
  final int endommage;
  final int total;
  final double height;

  const StockSegmentBar({
    super.key,
    required this.disponible,
    this.entretien = 0,
    this.endommage = 0,
    required this.total,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    final green = disponible.clamp(0, 1 << 30);
    final orange = entretien.clamp(0, 1 << 30);
    final red = endommage.clamp(0, 1 << 30);
    final used = green + orange + red;
    final rest = (total - used).clamp(0, 1 << 30);
    final denom = total > 0 ? total : (used > 0 ? used : 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Row(
          children: [
            if (green > 0)
              Flexible(flex: green, child: Container(color: AppColors.success)),
            if (orange > 0)
              Flexible(flex: orange, child: Container(color: AppColors.warning)),
            if (red > 0)
              Flexible(flex: red, child: Container(color: AppColors.danger)),
            if (rest > 0 || used == 0)
              Flexible(
                flex: used == 0 ? denom : rest,
                child: Container(color: AppColors.surfaceMuted),
              ),
          ],
        ),
      ),
    );
  }
}
