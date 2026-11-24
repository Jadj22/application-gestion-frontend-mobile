import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Section "Aujourd'hui" groupée du Tableau de Bord
class DashboardTodaySection extends StatelessWidget {
  final int pendingReservationsCount;
  final String? pendingReservationSubtitle;
  final int otherTodayCount;
  final VoidCallback? onPendingTap;
  final VoidCallback? onOtherTap;

  const DashboardTodaySection({
    super.key,
    required this.pendingReservationsCount,
    this.pendingReservationSubtitle,
    this.otherTodayCount = 0,
    this.onPendingTap,
    this.onOtherTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Titre de section ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Text(
            "Aujourd'hui",
            style: AppTextStyles.h2.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // ─── Carte groupée à 2 entrées ────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Ligne 1 : Réservations à valider
              _TodayRow(
                icon: Icons.calendar_today_outlined,
                iconBg: AppColors.badgeIndigoBg,
                iconColor: AppColors.primary,
                title: pendingReservationsCount > 1
                    ? 'Réservations à valider'
                    : 'Réservation à valider',
                subtitle: pendingReservationSubtitle ??
                    (pendingReservationsCount > 0
                        ? 'En attente de confirmation'
                        : 'Aucune réservation en attente'),
                badgeCount: pendingReservationsCount,
                badgeBg: pendingReservationsCount > 0
                    ? AppColors.primary
                    : AppColors.background,
                badgeTextColor: pendingReservationsCount > 0
                    ? Colors.white
                    : AppColors.textSecondary,
                showBottomDivider: true,
                onTap: onPendingTap,
              ),

              // Ligne 2 : Autres activités / Livraisons, retours
              _TodayRow(
                icon: Icons.check_circle_outline_rounded,
                iconBg: AppColors.background,
                iconColor: AppColors.textSecondary,
                title: otherTodayCount == 0
                    ? "Rien d'autre aujourd'hui"
                    : 'Opérations du jour',
                subtitle: 'Livraisons, retours, vérifications',
                badgeCount: otherTodayCount,
                badgeBg: AppColors.background,
                badgeTextColor: AppColors.textSecondary,
                showBottomDivider: false,
                onTap: onOtherTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int badgeCount;
  final Color badgeBg;
  final Color badgeTextColor;
  final bool showBottomDivider;
  final VoidCallback? onTap;

  const _TodayRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.showBottomDivider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: showBottomDivider
                ? const Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  )
                : null,
          ),
          child: Row(
            children: [
              // ─── Carré d'icône 40x40 arrondi 12px ───────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),

              // ─── Textes ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ─── Badge compteur pilule ───────────────────────────────────
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
