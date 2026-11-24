import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'availability_progress_bar.dart';

/// Carte principale « Disponibilité » du dashboard.
class AvailabilityCard extends StatelessWidget {
  final int totalStock;
  final int disponibleCount;
  final int enLocationCount;
  final int entretienCount;
  final int endommageCount;
  final int pointsATraiter;
  final VoidCallback? onDisponibleTap;
  final VoidCallback? onLocationTap;
  final VoidCallback? onEntretienTap;
  final VoidCallback? onEndommageTap;

  const AvailabilityCard({
    super.key,
    required this.totalStock,
    required this.disponibleCount,
    required this.enLocationCount,
    required this.entretienCount,
    required this.endommageCount,
    required this.pointsATraiter,
    this.onDisponibleTap,
    this.onLocationTap,
    this.onEntretienTap,
    this.onEndommageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'DISPONIBILITÉ',
                style: AppTextStyles.labelCaps.copyWith(
                  letterSpacing: 0.66,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (pointsATraiter > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pointsATraiter <= 1
                            ? '$pointsATraiter point à traiter'
                            : '$pointsATraiter points à traiter',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onDisponibleTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$disponibleCount',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 44,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'sur $totalStock unités',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AvailabilityProgressBar(
            disponible: disponibleCount,
            entretien: entretienCount,
            endommage: endommageCount,
            total: totalStock,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AvailabilityStat(
                  count: enLocationCount,
                  label: 'En location',
                  color: AppColors.textPrimary,
                  onTap: onLocationTap,
                ),
              ),
              Expanded(
                child: _AvailabilityStat(
                  count: entretienCount,
                  label: 'En entretien',
                  color: AppColors.warningText,
                  onTap: onEntretienTap,
                ),
              ),
              Expanded(
                child: _AvailabilityStat(
                  count: endommageCount,
                  label: 'Abîmés',
                  color: AppColors.dangerText,
                  onTap: onEndommageTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AvailabilityStat({
    required this.count,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: AppTextStyles.displayMedium.copyWith(
                color: color,
                fontSize: 26,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
