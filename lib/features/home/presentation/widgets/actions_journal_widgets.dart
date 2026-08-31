import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/home_repository.dart';

String actionKey(DashboardAction action) => '${action.kind.name}|${action.title}';

/// Liste des actions à faire — réutilisée sur le dashboard et la page dédiée.
class ActionsTodoList extends StatelessWidget {
  final List<DashboardAction> actions;
  final ValueChanged<DashboardAction>? onActionTap;
  final int? maxItems;
  final bool showHeader;
  final VoidCallback? onSeeAll;

  const ActionsTodoList({
    super.key,
    required this.actions,
    this.onActionTap,
    this.maxItems,
    this.showHeader = true,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final visible = maxItems != null ? actions.take(maxItems!).toList() : actions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Row(
            children: [
              const Icon(Icons.checklist, size: 22, color: AppColors.dashOutline),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Actions à Faire',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashOnSurface,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'VOIR TOUT →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.dashSecondary,
                    ),
                  ),
                ),
            ],
          ),
        if (showHeader) const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dashOutlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: visible.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Aucune action en attente.',
                      style: TextStyle(color: AppColors.dashOnSurfaceVariant),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          color: AppColors.dashOutlineVariant,
                        ),
                      ActionTodoTile(
                        action: visible[i],
                        onTap: onActionTap != null
                            ? () => onActionTap!(visible[i])
                            : null,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class ActionTodoTile extends StatelessWidget {
  final DashboardAction action;
  final VoidCallback? onTap;

  const ActionTodoTile({super.key, required this.action, this.onTap});

  (Color, IconData) get _style => switch (action.kind) {
        ActionKind.maintenance => (AppColors.kpiAmber, Icons.build),
        ActionKind.stockCheck => (AppColors.kpiBlue, Icons.inventory),
        ActionKind.returnCheck => (AppColors.kpiIndigo, Icons.sync_alt),
        ActionKind.reservationConflict => (AppColors.kpiRose, Icons.event_busy),
        ActionKind.exception => (AppColors.kpiViolet, Icons.gavel),
      };

  String get _priorityLabel => switch (action.priority) {
        ActionPriority.critical => 'Critique',
        ActionPriority.high => 'Haut',
        ActionPriority.medium => 'Moyen',
      };

  Color get _priorityColor => action.priority == ActionPriority.critical
      ? AppColors.kpiRose
      : AppColors.dashOnSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            action.title.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: AppColors.dashOnSurface,
                            ),
                          ),
                        ),
                        Text(
                          _priorityLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: action.priority == ActionPriority.critical
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _priorityColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.dashOnSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                onTap != null ? Icons.arrow_forward : Icons.more_horiz,
                size: 20,
                color: onTap != null
                    ? AppColors.dashSecondary
                    : AppColors.dashOutline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Journal d'activité — timeline réutilisable.
class ActivityJournalList extends StatelessWidget {
  final List<ActivityEntry> activities;
  final int? maxItems;
  final bool showHeader;
  final VoidCallback? onSeeAll;

  const ActivityJournalList({
    super.key,
    required this.activities,
    this.maxItems,
    this.showHeader = true,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final visible =
        maxItems != null ? activities.take(maxItems!).toList() : activities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Row(
            children: [
              const Icon(Icons.history, size: 22, color: AppColors.dashOutline),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Journal d\'Activité',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashOnSurface,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'VOIR TOUT →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.dashSecondary,
                    ),
                  ),
                ),
            ],
          ),
        if (showHeader) const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dashOutlineVariant),
          ),
          child: visible.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Aucune activité récente.',
                      style: TextStyle(color: AppColors.dashOnSurfaceVariant),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Positioned(
                      left: 11,
                      top: 8,
                      bottom: 8,
                      child: Container(
                        width: 2,
                        color:
                            AppColors.dashOutlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    Column(
                      children: [
                        for (final entry in visible)
                          ActivityTimelineTile(entry: entry),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class ActivityTimelineTile extends StatelessWidget {
  final ActivityEntry entry;

  const ActivityTimelineTile({super.key, required this.entry});

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Aujourd\'hui';
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}';
  }

  IconData _iconFor(String action) {
    if (action.contains('DOMMAGE')) return Icons.broken_image_outlined;
    if (action.contains('TASK') || action.contains('ENTRETIEN')) {
      return Icons.build_outlined;
    }
    if (action.contains('DECISION')) return Icons.warning_amber_outlined;
    if (action.contains('RETOUR')) return Icons.move_to_inbox_outlined;
    if (action.contains('RESERVATION')) return Icons.event_available_outlined;
    if (action.contains('ENTREE') || action.contains('SORTIE')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel(entry.createdAt);
    final date = _dateLabel(entry.createdAt);

    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(-24, 0),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.dashOutlineVariant),
              ),
              child: Icon(
                _iconFor(entry.action),
                size: 14,
                color: AppColors.dashOutline,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (time.isNotEmpty || date.isNotEmpty)
                  Text(
                    [if (date.isNotEmpty) date, if (time.isNotEmpty) time]
                        .join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dashOnSurfaceVariant,
                    ),
                  ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.dashOnSurface,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '${entry.actorLabel}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: entry.summary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badges statistiques pour la page actions.
class ActionStatBadge extends StatelessWidget {
  final String label;
  final bool emphasize;

  const ActionStatBadge({super.key, required this.label, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final parts = label.split(' ');
    final number = parts.length > 1 ? parts.last : '';
    final text = parts.length > 1 ? parts.first : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(text: '$text '),
            if (number.isNotEmpty)
              TextSpan(
                text: number,
                style: TextStyle(
                  color: emphasize ? AppColors.dangerText : AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur ACTIONS / JOURNAL — même pattern que Entretien (NOTES / TÂCHES).
class ActionsJournalSegment extends StatelessWidget {
  final bool showJournal;
  final ValueChanged<bool> onChanged;

  const ActionsJournalSegment({
    super.key,
    required this.showJournal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentOption(
            label: 'ACTIONS',
            active: !showJournal,
            onTap: () => onChanged(false),
          ),
          _SegmentOption(
            label: 'JOURNAL',
            active: showJournal,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: active ? AppColors.primary : AppColors.hint,
          ),
        ),
      ),
    );
  }
}
