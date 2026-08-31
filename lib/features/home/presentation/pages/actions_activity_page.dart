import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/logi_event_shell.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../maintenance/presentation/pages/maintenance_screen.dart';
import '../../../reservations/data/reservations_repository.dart';
import '../../../reservations/presentation/pages/reservation_page.dart';
import '../../data/home_repository.dart';
import '../widgets/actions_journal_widgets.dart';

/// Page Actions à faire / Journal d'activité — onglets comme Entretien.
class ActionsActivityPage extends StatefulWidget {
  /// `false` = Actions, `true` = Journal
  final bool initialJournalTab;

  const ActionsActivityPage({
    super.key,
    this.initialJournalTab = false,
  });

  @override
  State<ActionsActivityPage> createState() => _ActionsActivityPageState();
}

class _ActionsActivityPageState extends State<ActionsActivityPage> {
  late bool _showJournal;
  HomeDashboard? _dashboard;
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _completedActions = {};

  @override
  void initState() {
    super.initState();
    _showJournal = widget.initialJournalTab;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (businessId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<HomeRepository>().load(businessId);
      if (mounted) setState(() => _dashboard = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DashboardAction> get _visibleActions {
    final actions = _dashboard?.actions ?? [];
    final pending = actions
        .where((a) => !_completedActions.contains(actionKey(a)))
        .toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return pending;
    return pending.where((a) {
      return a.title.toLowerCase().contains(q) ||
          a.message.toLowerCase().contains(q);
    }).toList();
  }

  List<ActivityEntry> get _visibleActivities {
    final activities = _dashboard?.activities ?? [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return activities;
    return activities.where((e) {
      return e.summary.toLowerCase().contains(q) ||
          e.actorLabel.toLowerCase().contains(q) ||
          e.action.toLowerCase().contains(q) ||
          e.cible.toLowerCase().contains(q);
    }).toList();
  }

  void _handleActionTap(DashboardAction action) {
    switch (action.kind) {
      case ActionKind.maintenance:
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
        );
        break;
      case ActionKind.reservationConflict:
        _openConflictReservation();
        break;
      case ActionKind.stockCheck:
      case ActionKind.returnCheck:
      case ActionKind.exception:
        setState(() => _completedActions.add(actionKey(action)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('« ${action.title} » marquée comme traitée.')),
        );
        break;
    }
  }

  Future<void> _openConflictReservation() async {
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (businessId == null) return;
    try {
      final reservations =
          await context.read<ReservationsRepository>().reservations(businessId);
      final active = reservations
          .where((r) => r.estEnAttente || r.estValidee || r.estEnCours)
          .toList();
      if (active.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune réservation active pour le moment.'),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReservationPage(
            isDetailMode: true,
            reservationId: active.first.id,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LogiEventShell(
      navIndex: 0,
      showNavigation: false,
      body: SafeArea(
        child: _loading
            ? Skeleton(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, _) =>
                      const SkeletonCard(child: SkeletonListItem()),
                ),
              )
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showJournal ? 'Journal d\'Activité' : 'Actions à Faire',
                      style: AppTextStyles.h1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _showJournal
                          ? 'Historique des opérations sur le matériel'
                          : 'Priorités opérationnelles à traiter',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              ActionsJournalSegment(
                showJournal: _showJournal,
                onChanged: (journal) => setState(() {
                  _showJournal = journal;
                  _query = '';
                  _searchController.clear();
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: _showJournal
                  ? 'Rechercher dans le journal…'
                  : 'Rechercher une action…',
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
        ),
        if (!_showJournal) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActionStats(),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.dashSecondary,
            child: _showJournal ? _buildJournalList() : _buildActionsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionStats() {
    final all = _dashboard?.actions ?? [];
    final pending = all.where((a) => !_completedActions.contains(actionKey(a)));
    final critical =
        pending.where((a) => a.priority == ActionPriority.critical).length;
    final high = pending.where((a) => a.priority == ActionPriority.high).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionStatBadge(label: 'total ${pending.length}'),
        ActionStatBadge(label: 'critiques $critical', emphasize: critical > 0),
        ActionStatBadge(label: 'prioritaires $high', emphasize: high > 0),
      ],
    );
  }

  Widget _buildActionsList() {
    final actions = _visibleActions;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        ActionsTodoList(
          actions: actions,
          showHeader: false,
          onActionTap: _handleActionTap,
        ),
      ],
    );
  }

  Widget _buildJournalList() {
    final activities = _visibleActivities;
    if (activities.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
        children: const [
          Center(
            child: Text(
              'Aucune activité ne correspond à votre recherche.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        ActivityJournalList(
          activities: activities,
          showHeader: false,
        ),
      ],
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
