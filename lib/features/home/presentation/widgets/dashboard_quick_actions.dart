import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// 4 boutons d'action rapide circulaires/squircles du Dashboard
class DashboardQuickActions extends StatelessWidget {
  final VoidCallback onReserve;
  final VoidCallback onAddArticle;
  final VoidCallback onMaintenance;
  final VoidCallback onShowcase;

  const DashboardQuickActions({
    super.key,
    required this.onReserve,
    required this.onAddArticle,
    required this.onMaintenance,
    required this.onShowcase,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(
            label: 'Réserver',
            icon: Icons.add_rounded,
            onTap: onReserve,
          ),
          _ActionButton(
            label: 'Article',
            icon: Icons.layers_outlined,
            onTap: onAddArticle,
          ),
          _ActionButton(
            label: 'Entretien',
            icon: Icons.build_outlined,
            onTap: onMaintenance,
          ),
          _ActionButton(
            label: 'Vitrine',
            icon: Icons.link_rounded,
            onTap: onShowcase,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
