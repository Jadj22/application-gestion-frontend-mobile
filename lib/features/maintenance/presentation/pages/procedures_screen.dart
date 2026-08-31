import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/procedure.dart';
import 'procedure_form_page.dart';
import 'procedure_template_picker.dart';

/// Liste des procedures d'entretien (US-13, US-14).
class ProceduresScreen extends StatefulWidget {
  const ProceduresScreen({super.key});

  @override
  State<ProceduresScreen> createState() => _ProceduresScreenState();
}

class _ProceduresScreenState extends State<ProceduresScreen> {
  late final MaintenanceRepository _repository;
  late final Business _business;
  late final SessionController _session;

  List<ProcedureModel> _procedures = [];
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  String _query = '';

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
      final procedures = await _repository.procedures(_business.id);
      if (mounted) setState(() => _procedures = procedures);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ProcedureModel> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _procedures;
    return _procedures.where((p) {
      return p.nom.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openCreate() async {
    if (!_session.can('entretien.manage')) {
      _showNoPermission();
      return;
    }
    // Ouvrir le selecteur de template
    final created = await Navigator.of(context).push<ProcedureModel>(
      MaterialPageRoute(builder: (_) => const ProcedureTemplatePicker()),
    );
    if (created != null && mounted) _load();
  }

  Future<void> _openEdit(ProcedureModel procedure) async {
    if (!_session.can('entretien.manage')) {
      _showNoPermission();
      return;
    }
    final updated = await Navigator.of(context).push<ProcedureModel>(
      MaterialPageRoute(
        builder: (_) => ProcedureFormPage(procedure: procedure),
      ),
    );
    if (updated != null && mounted) _load();
  }

  Future<void> _duplicateProcedure(ProcedureModel procedure) async {
    if (!_session.can('entretien.manage')) {
      _showNoPermission();
      return;
    }

    try {
      // Creer une copie avec un nouveau nom
      final stepsData = procedure.steps.asMap().entries.map((e) => {
        'nom': e.value.nom,
        'ordre': e.key,
        'obligatoire': e.value.obligatoire,
        'type': e.value.type,
        'description': e.value.description,
      }).toList();

      await _repository.createProcedure(
        _business.id,
        nom: '${procedure.nom} (copie)',
        description: procedure.description,
        steps: stepsData,
      );

      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procedure dupliquee')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _confirmDelete(ProcedureModel procedure) async {
    if (!_session.can('entretien.manage')) {
      _showNoPermission();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la procedure ?'),
        content: Text(
          'La procedure "${procedure.nom}" sera supprimee definitivement. '
          'Cette action est irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteProcedure(_business.id, procedure.id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Procedure supprimee')),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
  }

  void _showNoPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vous n\'avez pas la permission de gerer l\'entretien.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Procedures', style: AppTextStyles.h2),
        centerTitle: false,
      ),
      body: _loading
          ? _buildLoadingSkeleton()
          : _error != null
              ? _LoadError(message: _error!, onRetry: _load)
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const SkeletonCard(child: SkeletonListItem()),
      ),
    );
  }

  Widget _buildContent() {
    final procedures = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Rechercher une procedure...',
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

        // Statistiques
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _StatBadge(
                label: '${_procedures.length} procedure${_procedures.length > 1 ? 's' : ''}',
              ),
              const SizedBox(width: 8),
              _StatBadge(
                label: '${_procedures.where((p) => p.estActif).length} active${_procedures.where((p) => p.estActif).length > 1 ? 's' : ''}',
                emphasize: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Liste
        Expanded(
          child: procedures.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 48, color: AppColors.hint),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'Aucune procedure trouvee.'
                              : 'Aucune procedure pour le moment.\nCreez-en une pour demarrer.',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: procedures.length,
                    itemBuilder: (context, index) {
                      final procedure = procedures[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProcedureCard(
                          procedure: procedure,
                          onTap: () => _openEdit(procedure),
                          onDuplicate: () => _duplicateProcedure(procedure),
                          onDelete: () => _confirmDelete(procedure),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Carte d'une procedure.
class _ProcedureCard extends StatelessWidget {
  final ProcedureModel procedure;
  final VoidCallback? onTap;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const _ProcedureCard({
    required this.procedure,
    this.onTap,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: procedure.estActif
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 22,
                      color: procedure.estActif
                          ? AppColors.primary
                          : AppColors.hint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          procedure.nom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${procedure.stepsCount} etape${procedure.stepsCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!procedure.estActif)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hint,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.hint),
                    onSelected: (value) {
                      if (value == 'duplicate') onDuplicate?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy_outlined,
                                size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('Dupliquer'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: AppColors.dangerText),
                            SizedBox(width: 8),
                            Text('Supprimer',
                                style: TextStyle(color: AppColors.dangerText)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (procedure.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  procedure.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (procedure.steps.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: procedure.steps.take(4).map((step) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: step.isControle
                            ? AppColors.warning.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            step.isControle
                                ? Icons.verified_outlined
                                : Icons.play_circle_outline,
                            size: 12,
                            color: step.isControle
                                ? AppColors.warningText
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              step.nom,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: step.isControle
                                    ? AppColors.warningText
                                    : AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (procedure.steps.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${procedure.steps.length - 4} etape(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.hint,
                      ),
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

/// Badge statistique.
class _StatBadge extends StatelessWidget {
  final String label;
  final bool emphasize;

  const _StatBadge({required this.label, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: emphasize ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Etat d'erreur.
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
          OutlinedButton(onPressed: onRetry, child: const Text('Reessayer')),
        ],
      ),
    );
  }
}
