import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/maintenance_task.dart';

/// Dashboard de maintenance avec statistiques et indicateurs.
class MaintenanceDashboard extends StatelessWidget {
  final List<MaintenanceTaskModel> tasks;
  final VoidCallback? onNewTask;
  final VoidCallback? onBulkTask;
  final ValueChanged<MaintenanceTaskModel>? onTaskTap;

  const MaintenanceDashboard({
    super.key,
    required this.tasks,
    this.onNewTask,
    this.onBulkTask,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final enCours = tasks.where((t) => t.estEnCours).toList();
    final terminees = tasks.where((t) => t.estTerminee).toList();
    final partielles = tasks.where((t) => t.statut == 'PARTIELLE').toList();

    // Calculer les statistiques
    final totalEnCours = enCours.length;
    final totalTerminees = terminees.length;
    final totalPartielles = partielles.length;

    // Taches urgentes (en cours depuis longtemps ou avec beaucoup d'etapes restantes)
    final urgentes = enCours.where((t) {
      final progress = t.etapesFaites / (t.etapesTotal == 0 ? 1 : t.etapesTotal);
      return progress < 0.3 && t.etapesTotal > 0;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          _buildKpiSection(
            totalEnCours: totalEnCours,
            totalTerminees: totalTerminees,
            totalPartielles: totalPartielles,
            urgentes: urgentes.length,
          ),

          const SizedBox(height: 20),

          // Actions rapides
          _buildQuickActions(),

          const SizedBox(height: 20),

          // Taches urgentes
          if (urgentes.isNotEmpty) ...[
            _buildUrgentSection(urgentes),
            const SizedBox(height: 20),
          ],

          // Taches en cours
          if (enCours.isNotEmpty) ...[
            _buildTaskSection(
              'En cours',
              enCours.take(5).toList(),
              AppColors.kpiAmber,
              Icons.pending_actions,
            ),
            const SizedBox(height: 20),
          ],

          // Recemment terminees
          if (terminees.isNotEmpty) ...[
            _buildTaskSection(
              'Récemment terminées',
              terminees.take(3).toList(),
              AppColors.kpiGreen,
              Icons.check_circle_outline,
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildKpiSection({
    required int totalEnCours,
    required int totalTerminees,
    required int totalPartielles,
    required int urgentes,
  }) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'En cours',
            value: '$totalEnCours',
            color: AppColors.kpiAmber,
            icon: Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Terminées',
            value: '$totalTerminees',
            color: AppColors.kpiGreen,
            icon: Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            label: 'Partielles',
            value: '$totalPartielles',
            color: AppColors.kpiBlue,
            icon: Icons.warning_amber,
            warning: totalPartielles > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Actions rapides',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_task,
                  label: 'Nouvelle tâche',
                  onTap: onNewTask,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.playlist_add,
                  label: 'Tâches en lot',
                  color: AppColors.kpiAmber,
                  onTap: onBulkTask,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentSection(List<MaintenanceTaskModel> urgentes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.dangerText.withValues(alpha: 0.2),
        ),
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
          ...urgentes.take(3).map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _UrgentTaskTile(
                  task: task,
                  onTap: () => onTaskTap?.call(task),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTaskSection(
    String title,
    List<MaintenanceTaskModel> tasks,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${tasks.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskMiniCard(
                task: task,
                color: color,
                onTap: () => onTaskTap?.call(task),
              ),
            )),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool warning;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: warning
            ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              if (warning) ...[
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Material(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                      backgroundColor: AppColors.dangerText.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(AppColors.dangerText),
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

  const _TaskMiniCard({
    required this.task,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = task.etapesTotal == 0
        ? 0.0
        : task.etapesFaites / task.etapesTotal;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.build_outlined,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
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
                    Row(
                      children: [
                        Text(
                          task.procedureNom,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (task.etapesTotal > 0) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.hint)),
                          Text(
                            '${task.etapesFaites}/${task.etapesTotal}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (task.etapesTotal > 0) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
