import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// En-tête supérieur du Tableau de Bord (iOS style)
class DashboardHeader extends StatelessWidget {
  final String businessName;
  final String userName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  const DashboardHeader({
    super.key,
    required this.businessName,
    required this.userName,
    required this.onSearch,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final initial = businessName.isNotEmpty
        ? businessName.substring(0, 1).toUpperCase()
        : 'D';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          // ─── Avatar initial business ────────────────────────────────────
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.37,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ─── Salutation & Nom de l'entreprise ───────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bonjour, $userName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // ─── Actions de droite (Recherche & Notifications) ──────────────
          IconButton(
            onPressed: onSearch,
            icon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'Rechercher',
          ),
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'Notifications',
          ),
        ],
      ),
    );
  }
}
