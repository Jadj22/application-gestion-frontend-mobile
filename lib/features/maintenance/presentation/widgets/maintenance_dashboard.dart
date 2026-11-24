import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../items/data/models/catalog_item.dart';
import '../../data/models/maintenance_task.dart';

/// Dashboard de maintenance avec statistiques et indicateurs.
class MaintenanceDashboard extends StatelessWidget {
  final List<MaintenanceTaskModel> tasks;
  final List<CatalogItemModel> catalogItems;
  final String? catalogError;
  final VoidCallback? onNewTask;
  final VoidCallback? onBulkTask;
  final ValueChanged<MaintenanceTaskModel>? onTaskTap;
  final ValueChanged<CatalogItemModel>? onPlanItem;

  const MaintenanceDashboard({
    super.key,
    required this.tasks,
    required this.catalogItems,
    this.catalogError,
    this.onNewTask,
    this.onBulkTask,
    this.onTaskTap,
    this.onPlanItem,
  });

  @override
  Widget build(BuildContext context) {
    final enCours = tasks.where((t) => t.statut == 'EN_COURS').toList();
    final terminees = tasks.where((t) => t.estTerminee).toList();
    final partielles = tasks.where((t) => t.statut == 'PARTIELLE').toList();
    final planifiees = tasks.where((t) => t.statut == 'A_FAIRE').toList();
    final itemsWithTasks = tasks
        .where((task) => !task.estTerminee)
        .map((task) => task.itemId)
        .toSet();
    final aPlanifier = catalogItems
        .where(
          (item) =>
              (item.entretienRequis || item.endommages > 0) &&
              !itemsWithTasks.contains(item.id),
        )
        .toList();

    final totalEnCours = enCours.length;
    final totalTerminees = terminees.length;
    final totalPartielles = partielles.length;

    final urgentes = enCours.where((t) {
      final progress =
          t.etapesFaites / (t.etapesTotal == 0 ? 1 : t.etapesTotal);
      return progress < 0.3 && t.etapesTotal > 0;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSection(
            totalEnCours: totalEnCours,
            totalTerminees: totalTerminees,
            totalPartielles: totalPartielles,
          ),
          if (catalogError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Articles à planifier indisponibles : $catalogError',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warningText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          if (urgentes.isNotEmpty) ...[
            _buildUrgentSection(urgentes),
            const SizedBox(height: 24),
          ],

          if (enCours.isNotEmpty) ...[
            _buildTaskSection(
              'En cours',
              enCours.take(5).toList(),
              AppColors.kpiAmber,
            ),
            const SizedBox(height: 24),
          ],

          if (partielles.isNotEmpty) ...[
            _buildTaskSection(
              'Partielles',
              partielles.take(5).toList(),
              AppColors.kpiAmber,
            ),
            const SizedBox(height: 24),
          ],

          if (planifiees.isNotEmpty) ...[
            _buildTaskSection(
              'Planifiées',
              planifiees.take(5).toList(),
              AppColors.dashPrimary,
            ),
            const SizedBox(height: 24),
          ],

          if (aPlanifier.isNotEmpty) ...[
            _buildPlanningSection(aPlanifier),
            const SizedBox(height: 24),
          ],

          if (terminees.isNotEmpty) ...[
            _buildTaskSection(
              'Récemment terminées',
              terminees.take(3).toList(),
              AppColors.kpiGreen,
            ),
            const SizedBox(height: 24),
          ],

          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildKpiSection({
    required int totalEnCours,
    required int totalTerminees,
    required int totalPartielles,
  }) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'En cours',
            value: '$totalEnCours',
            color: AppColors.kpiAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Terminées',
            value: '$totalTerminees',
            color: AppColors.kpiGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Partielles',
            value: '$totalPartielles',
            color: AppColors.kpiBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(label: 'Nouvelle tâche', onTap: onNewTask),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            label: 'Tâches en lot',
            outlined: true,
            onTap: onBulkTask,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanningSection(List<CatalogItemModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'À planifier',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PlanningItemCard(
              item: item,
              onTap: () => onPlanItem?.call(item),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentSection(List<MaintenanceTaskModel> urgentes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dangerText.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.dangerText.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.priority_high,
                  size: 16,
                  color: AppColors.dangerText,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Attention requise',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerText,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${urgentes.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...urgentes
              .take(3)
              .map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UrgentTaskTile(
                    task: task,
                    onTap: () => onTaskTap?.call(task),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTaskSection(
    String title,
    List<MaintenanceTaskModel> tasks,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TaskMiniCard(
              task: task,
              color: color,
              onTap: () => onTaskTap?.call(task),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.label,
    this.outlined = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? AppColors.surface : AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: outlined ? AppColors.primary : AppColors.primary,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: outlined ? AppColors.primary : AppColors.surface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanningItemCard extends StatelessWidget {
  final CatalogItemModel item;
  final VoidCallback? onTap;

  const _PlanningItemCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final damaged = item.endommages;
    final detail = damaged > 0
        ? '$damaged abîmée${damaged > 1 ? 's' : ''} · aucune tâche'
        : 'Entretien requis · aucune tâche';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.dangerText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onTap, child: const Text('Planifier')),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentTaskTile extends StatelessWidget {
  final MaintenanceTaskModel task;
  final VoidCallback? onTap;

  const _UrgentTaskTile({required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = task.etapesTotal == 0
        ? 0.0
        : task.etapesFaites / task.etapesTotal;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.itemNom,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      task.procedureNom,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: AppColors.dangerText.withValues(
                        alpha: 0.2,
                      ),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.dangerText,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskMiniCard extends StatelessWidget {
  final MaintenanceTaskModel task;
  final Color color;
  final VoidCallback? onTap;

  const _TaskMiniCard({required this.task, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (task.progressValue / 100).clamp(0.0, 1.0);
    final statusLabel = task.statut == 'A_FAIRE'
        ? 'PLANIFIÉE'
        : task.statutLabel;
    final description = [
      task.procedureNom,
      if (task.motif.isNotEmpty) task.motif,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EADF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      size: 23,
                      color: AppColors.hint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.itemNom,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.inputBackground,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).round()} %',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
