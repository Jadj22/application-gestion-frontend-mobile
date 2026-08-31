import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/maintenance_task.dart';
import '../widgets/maintenance_dashboard.dart';
import 'bulk_task_page.dart';
import 'maintenance_detail_page.dart';
import 'new_task_page.dart';
import 'procedures_screen.dart';

/// Gestion de la maintenance (US-15 à US-17) : tâches réelles du backend,
/// statistiques et progression par étape.
class MaintenanceScreen extends StatefulWidget {
  final bool showBottomNav;

  const MaintenanceScreen({super.key, this.showBottomNav = true});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late final MaintenanceRepository _repository;
  late final Business _business;
  late final SessionController _session;

  List<MaintenanceTaskModel> _tasks = [];
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  String _query = '';
  bool _showNotes = false;
  bool _showDashboard = true;
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MaintenanceRepository>();
    _session = context.read<SessionController>();
    _business = _session.currentBusiness!;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _repository.tasks(_business.id);
      if (mounted) setState(() => _tasks = tasks);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MaintenanceTaskModel> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _tasks;
    return _tasks.where((task) {
      return task.procedureNom.toLowerCase().contains(query) ||
          task.itemNom.toLowerCase().contains(query);
    }).toList();
  }

  void _openTaskDetail(MaintenanceTaskModel task) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MaintenanceTaskDetailPage(
          taskId: task.id,
          title: task.itemNom,
          procedureName: task.procedureNom,
        ),
      ),
    );
  }

  Future<void> _openNewTask() async {
    if (!_session.can('entretien.manage')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas la permission de gérer l\'entretien.'),
        ),
      );
      return;
    }
    final created = await Navigator.of(context).push<MaintenanceTaskModel>(
      MaterialPageRoute(builder: (_) => const NewTaskPage()),
    );
    if (created != null && mounted) _load();
  }

  Future<void> _openBulkTask() async {
    if (!_session.can('entretien.manage')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas la permission de gérer l\'entretien.'),
        ),
      );
      return;
    }
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const BulkTaskPage()),
    );
    if (count != null && count > 0 && mounted) _load();
  }

  void _showHistory() {
    final terminees =
        _tasks.where((task) => task.estTerminee).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: terminees.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('Aucune tâche terminée pour le moment.',
                      style: AppTextStyles.body),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: terminees.length,
                itemBuilder: (context, index) {
                  final task = terminees[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskCard(
                      task: task,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openTaskDetail(task);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? _buildLoadingSkeleton()
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : _buildContent(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showNotes ? null : _openNewTask,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? AppBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (index != 3) {
                  const labels = [
                    'Accueil',
                    'Articles',
                    'Stock',
                    'Entretien',
                    'Plus'
                  ];
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('« ${labels[index]} » arrive bientôt')),
                  );
                  return;
                }
                Navigator.of(context).pop();
              },
            )
          : null,
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const SkeletonCard(child: SkeletonListItem()),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne 1 : Titre + menu overflow
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Entretien', style: AppTextStyles.h1),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                tooltip: 'Plus d\'options',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'procedures':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProceduresScreen(),
                        ),
                      );
                      break;
                    case 'bulk':
                      _openBulkTask();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'procedures',
                    child: Row(
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 20, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text('Procédures'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'bulk',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add,
                            size: 20, color: AppColors.kpiAmber),
                        SizedBox(width: 12),
                        Text('Entretien en lot'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Ligne 2 : Onglets + toggle vue
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _buildSegmentedControl(),
              const Spacer(),
              if (!_showNotes) _buildViewToggle(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_showNotes)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 48, color: AppColors.hint),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune note pour le moment.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_showDashboard)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: MaintenanceDashboard(
                tasks: _tasks,
                onNewTask: _openNewTask,
                onBulkTask: _openBulkTask,
                onTaskTap: _openTaskDetail,
              ),
            ),
          )
        else ...[
          _buildSearchAndStats(),
          const SizedBox(height: 16),
          Expanded(child: _buildTaskList()),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Sélecteur NOTES / TÂCHES
  // ---------------------------------------------------------------------------

  Widget _buildSegmentedControl() {
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
            label: 'NOTES',
            active: _showNotes,
            onTap: () => setState(() => _showNotes = true),
          ),
          _SegmentOption(
            label: 'TÂCHES',
            active: !_showNotes,
            onTap: () => setState(() => _showNotes = false),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewToggleOption(
            icon: Icons.dashboard_outlined,
            active: _showDashboard,
            onTap: () => setState(() => _showDashboard = true),
          ),
          _ViewToggleOption(
            icon: Icons.list,
            active: !_showDashboard,
            onTap: () => setState(() => _showDashboard = false),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Recherche & statistiques
  // ---------------------------------------------------------------------------

  Widget _buildSearchAndStats() {
    final total = _tasks.length;
    final enCours = _tasks.where((t) => t.estEnCours).length;
    final terminees = _tasks.where((t) => t.estTerminee).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Rechercher une tâche...',
              prefixIcon: const Icon(Icons.search, color: AppColors.hint),
              filled: true,
              fillColor: AppColors.inputBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBadge(label: 'total $total'),
              const SizedBox(width: 8),
              _StatBadge(label: 'en cours $enCours', emphasize: true),
              const SizedBox(width: 8),
              _StatBadge(label: 'terminés $terminees'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Liste des tâches
  // ---------------------------------------------------------------------------

  Widget _buildTaskList() {
    final tasks = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Aujourd'hui",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
              Row(
                children: [
                  _ViewModeIcon(
                    icon: Icons.view_list_outlined,
                    active: !_gridView,
                    onTap: () => setState(() => _gridView = false),
                  ),
                  const SizedBox(width: 4),
                  _ViewModeIcon(
                    icon: Icons.grid_view_outlined,
                    active: _gridView,
                    onTap: () => setState(() => _gridView = true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune tâche d\'entretien pour le moment.',
                    style: AppTextStyles.body,
                  ),
                )
              : _gridView
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) => _TaskCard(
                          task: tasks[index],
                          onTap: () => _openTaskDetail(tasks[index]),
                        ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TaskCard(
                          task: tasks[index],
                          onTap: () => _openTaskDetail(tasks[index]),
                        ),
                      ),
                    ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: TextButton(
              onPressed: _showHistory,
              child: const Text(
                'VOIR L\'HISTORIQUE COMPLET →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Option du sélecteur NOTES / TÂCHES.
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

/// Option du toggle vue Dashboard / Liste.
class _ViewToggleOption extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggleOption({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
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
        child: Icon(
          icon,
          size: 18,
          color: active ? AppColors.primary : AppColors.hint,
        ),
      ),
    );
  }
}

/// Badge statistique arrondi.
class _StatBadge extends StatelessWidget {
  final String label;
  final bool emphasize;

  const _StatBadge({required this.label, this.emphasize = false});

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

/// Icône de bascule vue liste / vue grille.
class _ViewModeIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ViewModeIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: active ? AppColors.primary : AppColors.hint,
      ),
    );
  }
}

/// Carte d'une tâche d'entretien.
class _TaskCard extends StatelessWidget {
  final MaintenanceTaskModel task;
  final VoidCallback? onTap;

  const _TaskCard({required this.task, this.onTap});

  IconData get _statusIcon {
    switch (task.statut) {
      case 'EN_COURS':
        return Icons.sync_outlined;
      case 'PARTIELLE':
        return Icons.timelapse_outlined;
      case 'TERMINEE':
        return Icons.check_circle_outline;
      default:
        return Icons.event_outlined;
    }
  }

  (String, Color, Color) get _statusStyle {
    switch (task.statut) {
      case 'EN_COURS':
        return ('EN COURS', _infoBackground, AppColors.primary);
      case 'PARTIELLE':
        return ('PARTIELLE', AppColors.warning, AppColors.warningText);
      case 'TERMINEE':
        return ('TERMINÉE', AppColors.success, AppColors.successText);
      default:
        return (task.statutLabel, AppColors.inputBackground, AppColors.hint);
    }
  }

  static const Color _infoBackground = Color(0xFFE3EEF4);

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusBg, statusFg) = _statusStyle;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.build_outlined,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 13, color: statusFg),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.hint),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.procedureNom,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            task.itemNom,
            style: const TextStyle(fontSize: 12.5, color: AppColors.hint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.motif.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.motif,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROGRESSION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.hint,
                ),
              ),
              Text(
                '${task.progressValue}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: task.progressValue / 100,
              minHeight: 6,
              backgroundColor: AppColors.inputBackground,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

/// État d'erreur avec bouton réessayer.
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