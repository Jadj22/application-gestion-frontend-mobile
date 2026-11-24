import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum HomeTaskKind { reservation, damaged, maintenance, other }

/// Élément de la section « À traiter ».
class HomeTaskItem {
  final String id;
  final HomeTaskKind kind;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int priority;

  const HomeTaskItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.priority = 0,
  });
}

/// Section « À traiter » avec badge compteur et liste de tâches.
class TasksSection extends StatelessWidget {
  final List<HomeTaskItem> tasks;
  final int? badgeCount;
  final VoidCallback? onSeeAll;

  const TasksSection({
    super.key,
    required this.tasks,
    this.badgeCount,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final count = badgeCount ?? tasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
          child: Row(
            children: [
              Text(
                'À traiter',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (onSeeAll != null && tasks.isNotEmpty)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Tout voir'),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: tasks.isEmpty
              ? const _EmptyTasksState()
              : Column(
                  children: [
                    for (var i = 0; i < tasks.length; i++)
                      TaskItem(
                        item: tasks[i],
                        showDivider: i < tasks.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class TaskItem extends StatelessWidget {
  final HomeTaskItem item;
  final bool showDivider;

  const TaskItem({
    super.key,
    required this.item,
    this.showDivider = true,
  });

  (IconData, Color, Color) get _visual {
    switch (item.kind) {
      case HomeTaskKind.reservation:
        return (
          Icons.calendar_today_outlined,
          AppColors.badgeIndigoBg,
          AppColors.primary,
        );
      case HomeTaskKind.damaged:
        return (
          Icons.warning_amber_rounded,
          AppColors.badgeDangerBg,
          AppColors.danger,
        );
      case HomeTaskKind.maintenance:
        return (
          Icons.build_outlined,
          AppColors.warningBg,
          AppColors.warningText,
        );
      case HomeTaskKind.other:
        return (
          Icons.fact_check_outlined,
          AppColors.background,
          AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _visual;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
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

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tout est à jour !',
            style: AppTextStyles.h3.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Aucune tâche en attente pour le moment.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
