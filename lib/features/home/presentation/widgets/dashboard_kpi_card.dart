import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Carte principale de Disponibilité et Répartition du stock (Style Apple 24px)
class DashboardKpiCard extends StatelessWidget {
  final int totalStock;
  final int disponibleCount;
  final int enLocationCount;
  final int entretienCount;
  final int endommageCount;
  final int pointsATraiter;
  final VoidCallback? onTotalTap;
  final VoidCallback? onLocationTap;
  final VoidCallback? onEntretienTap;
  final VoidCallback? onEndommageTap;

  const DashboardKpiCard({
    super.key,
    required this.totalStock,
    required this.disponibleCount,
    required this.enLocationCount,
    required this.entretienCount,
    required this.endommageCount,
    required this.pointsATraiter,
    this.onTotalTap,
    this.onLocationTap,
    this.onEntretienTap,
    this.onEndommageTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalStock > 0
        ? (disponibleCount / totalStock).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── En-tête : "DISPONIBILITÉ" + Pillule "X point(s) à traiter" ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISPONIBILITÉ',
                style: AppTextStyles.labelCaps.copyWith(
                  letterSpacing: 0.66,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

          // ─── Chiffre principal : "150" sur 150 articles ──────────────────
          const SizedBox(height: 6),
          InkWell(
            onTap: onTotalTap,
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
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'sur $totalStock articles',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),

          // ─── Jauge de progression verte ──────────────────────────────────
          const SizedBox(height: 12),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // ─── 3 Sous-compteurs : En location / Entretien / Endommagés ─────
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SubStat(
                  count: enLocationCount,
                  label: 'En location',
                  color: AppColors.textPrimary,
                  onTap: onLocationTap,
                ),
              ),
              Expanded(
                child: _SubStat(
                  count: entretienCount,
                  label: 'Entretien',
                  color: AppColors.warningText,
                  onTap: onEntretienTap,
                ),
              ),
              Expanded(
                child: _SubStat(
                  count: endommageCount,
                  label: 'Endommagés',
                  color: AppColors.textPrimary,
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

class _SubStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SubStat({
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
