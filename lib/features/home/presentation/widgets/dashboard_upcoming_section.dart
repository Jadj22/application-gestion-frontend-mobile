import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Modèle simple pour un élément de réservation à venir
class UpcomingReservationItem {
  final String title;
  final String subtitle;
  final String monthText;
  final String dayText;
  final String status;
  final Color statusDotColor;
  final VoidCallback? onTap;

  const UpcomingReservationItem({
    required this.title,
    required this.subtitle,
    required this.monthText,
    required this.dayText,
    required this.status,
    required this.statusDotColor,
    this.onTap,
  });
}

/// Section "À venir" groupée avec bloc date calendrier
class DashboardUpcomingSection extends StatelessWidget {
  final List<UpcomingReservationItem> items;
  final VoidCallback onSeeAll;

  const DashboardUpcomingSection({
    super.key,
    required this.items,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── En-tête : "À venir" + "Tout voir" ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'À venir',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    'Tout voir',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Carte groupée ────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Aucune réservation programmée.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isLast = index == items.length - 1;

                    return _UpcomingCardTile(
                      item: item,
                      showDivider: !isLast,
                    );
                  }),
                ),
        ),
      ],
    );
  }
}

class _UpcomingCardTile extends StatelessWidget {
  final UpcomingReservationItem item;
  final bool showDivider;

  const _UpcomingCardTile({
    required this.item,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  )
                : null,
          ),
          child: Row(
            children: [
              // ─── Bloc Date Calendrier (52x56) ───────────────────────────
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.monthText.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.08,
                        color: AppColors.danger,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.dayText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // ─── Détails de la réservation ──────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Pillule statut avec dot
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                            decoration: BoxDecoration(
                              color: item.statusDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.status,
                            style: AppTextStyles.captionBold.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Chevron ────────────────────────────────────────────────
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.dashOutline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
