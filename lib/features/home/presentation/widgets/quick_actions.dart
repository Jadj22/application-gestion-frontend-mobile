import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Quatre raccourcis d'actions du Home.
class QuickActions extends StatelessWidget {
  final VoidCallback onReserve;
  final VoidCallback onArticle;
  final VoidCallback onMaintenance;
  final VoidCallback onShowcase;

  const QuickActions({
    super.key,
    required this.onReserve,
    required this.onArticle,
    required this.onMaintenance,
    required this.onShowcase,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final columns = constraints.maxWidth < 320 ? 2 : 4;
          final itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: itemWidth,
                child: QuickActionButton(
                  label: 'Réserver',
                  icon: Icons.add_rounded,
                  emphasized: true,
                  onTap: onReserve,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: QuickActionButton(
                  label: 'Article',
                  icon: Icons.layers_outlined,
                  onTap: onArticle,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: QuickActionButton(
                  label: 'Entretien',
                  icon: Icons.build_outlined,
                  onTap: onMaintenance,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: QuickActionButton(
                  label: 'Vitrine',
                  icon: Icons.link_rounded,
                  onTap: onShowcase,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: emphasized ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: emphasized
                      ? null
                      : Border.all(color: AppColors.border, width: 1),
                  boxShadow: emphasized
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: emphasized ? Colors.white : AppColors.primary,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
