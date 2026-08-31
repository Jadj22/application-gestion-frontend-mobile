import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/logi_event_shell.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/maintenance_task.dart';

/// Détail d'une tâche d'entretien — données réelles du backend (US-15 à US-17).
class MaintenanceTaskDetailPage extends StatefulWidget {
  final String taskId;
  final String title;
  final String procedureName;

  const MaintenanceTaskDetailPage({
    super.key,
    required this.taskId,
    this.title = '',
    this.procedureName = '',
  });

  @override
  State<MaintenanceTaskDetailPage> createState() =>
      _MaintenanceTaskDetailPageState();
}

class _MaintenanceTaskDetailPageState extends State<MaintenanceTaskDetailPage> {
  MaintenanceTaskModel? _task;
  bool _loading = true;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (businessId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task =
          await context.read<MaintenanceRepository>().taskDetail(businessId, widget.taskId);
      if (mounted) setState(() => _task = task);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskStepModel> get _steps =>
      _task?.steps.where((s) => !s.estTerminee).toList() ?? const [];

  TaskStepModel? get _activeStep {
    for (final step in _steps) {
      if (step.estEnCours) return step;
    }
    for (final step in _steps) {
      if (step.estEnAttente) return step;
    }
    return null;
  }

  String get _statusLabel {
    final task = _task;
    if (task == null) return '—';
    final done = task.steps.where((s) => s.estTerminee).length;
    if (task.estTerminee) return 'Entretien Terminé';
    if (task.estEnCours && done == 0) return 'Entretien À Démarrer';
    if (done == task.steps.length) return 'Entretien Terminé';
    return 'Entretien Partiellement Effectué';
  }

  Future<void> _validateStep() async {
    final active = _activeStep;
    final task = _task;
    if (active == null || task == null) return;
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (businessId == null) return;
    setState(() => _working = true);
    try {
      await context
          .read<MaintenanceRepository>()
          .updateStep(businessId, task.id, active.id, statut: 'TERMINE');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Étape « ${active.nom} » validée.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cloture({bool partielle = false}) async {
    final task = _task;
    if (task == null) return;
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (businessId == null) return;
    setState(() => _working = true);
    try {
      await context
          .read<MaintenanceRepository>()
          .clotureTask(businessId, task.id, partielle: partielle);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            partielle
                ? 'Tâche clôturée en incomplète (entretien partiel).'
                : 'Tâche clôturée avec succès.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.contains('obligatoires non terminées')) {
        _confirmPartialClosure();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmPartialClosure() async {
    final task = _task;
    if (task == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clôture incomplète'),
        content: const Text(
          'Des étapes obligatoires ne sont pas terminées. '
          'Clôturer en incomplète (entretien partiel) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clôturer en partiel'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) await _cloture(partielle: true);
  }

  @override
  Widget build(BuildContext context) {
    return LogiEventShell(
      navIndex: 2,
      showNavigation: false,
      pageTitle: 'Détail d\'entretien',
      body: SafeArea(
        child: _loading
            ? _buildLoadingSkeleton()
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonText(width: 200, height: 22),
            const SizedBox(height: 8),
            const SkeletonText(width: 140, height: 14),
            const SizedBox(height: 24),
            const SkeletonCard(child: SkeletonListItem()),
            const SizedBox(height: 12),
            const SkeletonCard(child: SkeletonListItem()),
            const SizedBox(height: 12),
            const SkeletonCard(child: SkeletonListItem()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final task = _task!;
    final active = _activeStep;
    final isWide = MediaQuery.sizeOf(context).width >= 768;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32 : 16,
        isWide ? 24 : 8,
        isWide ? 32 : 16,
        isWide ? 32 : 100,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskHeader(
                title: widget.title.isNotEmpty ? widget.title : task.itemNom,
                procedure: widget.procedureName.isNotEmpty
                    ? widget.procedureName
                    : task.procedureNom,
                statusLabel: _statusLabel,
              ),
              const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildStepsPanel(task, active)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildContextPanel(task)),
                  ],
                )
              else ...[
                _buildStepsPanel(task, active),
                const SizedBox(height: 24),
                _buildContextPanel(task),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepsPanel(MaintenanceTaskModel task, TaskStepModel? active) {
    final done = task.steps.where((s) => s.estTerminee).length;
    return LogiEventCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression de la Procédure',
                style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
              ),
              Text(
                '$done/${task.steps.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...task.steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StepTile(step: step),
              )),
          if (task.statut == 'EN_COURS') ...[
            const Divider(color: AppColors.dashOutlineVariant),
            const SizedBox(height: 16),
            if (active != null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _working ? null : _validateStep,
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text('Valider l\'étape « ${active.nom} »'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dashPrimary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _working ? null : () => _cloture(),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Clôturer la tâche'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dashOnSurfaceVariant,
                  side: const BorderSide(color: AppColors.dashOutlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContextPanel(MaintenanceTaskModel task) {
    final history = task.steps
        .where((s) => s.estTerminee && s.finishedAt != null)
        .toList()
      ..sort((a, b) => (b.finishedAt ?? '').compareTo(a.finishedAt ?? ''));

    return Column(
      children: [
        LogiEventCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Article',
                style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.dashSurfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: AppColors.dashPrimary,
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
                            color: AppColors.dashOnSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.motif.isEmpty
                              ? 'Procédure : ${task.procedureNom}'
                              : task.motif,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LogiEventCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historique',
                style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
              ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Aucune étape terminée pour le moment.',
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              else
                ...history.map((step) => _TimelineEntry(step: step)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskHeader extends StatelessWidget {
  final String title;
  final String procedure;
  final String statusLabel;

  const _TaskHeader({
    required this.title,
    required this.procedure,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 768;
    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dashOnSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Procédure : $procedure',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.dashOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: statusLabel),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashOnSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Procédure : $procedure',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _StatusBadge(label: statusLabel),
            ],
          );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceTint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.dashSurfaceTint.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.build,
            size: 18,
            color: AppColors.dashSurfaceTint,
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.dashSurfaceTint,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final TaskStepModel step;

  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return switch (step.statut) {
      'TERMINE' => _CompletedStep(step: step),
      'EN_COURS' => _InProgressStep(step: step),
      _ => _TodoStep(step: step),
    };
  }
}

class _CompletedStep extends StatelessWidget {
  final TaskStepModel step;

  const _CompletedStep({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.dashTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.nom,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dashOnSurface,
                  ),
                ),
                if (step.estControle)
                  const Text(
                    'Contrôle',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dashOnSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.dashTertiaryContainerBg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Terminé',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.dashTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InProgressStep extends StatelessWidget {
  final TaskStepModel step;

  const _InProgressStep({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dashSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: const Border(
          left: BorderSide(color: AppColors.dashSecondary, width: 4),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.dashSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.nom,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashOnSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'En cours',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.play_circle_fill,
            color: AppColors.dashSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _TodoStep extends StatelessWidget {
  final TaskStepModel step;

  const _TodoStep({required this.step});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.radio_button_unchecked,
              color: AppColors.dashOutline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.nom,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.dashOnSurface,
                    ),
                  ),
                  if (step.estControle)
                    const Text(
                      'Contrôle',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.dashOnSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.dashOutlineVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'À faire',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final TaskStepModel step;

  const _TimelineEntry({required this.step});

  String get _timeLabel {
    final raw = step.finishedAt ?? step.startedAt ?? '';
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final h = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return 'Le $d/$m/${parsed.year} à $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.dashSecondary,
                    border: Border.all(
                      color: AppColors.dashSurfaceLowest,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.dashOutlineVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${step.nom} terminé',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.dashOnSurface,
                    ),
                  ),
                  if (_timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.dashOnSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.hint),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}