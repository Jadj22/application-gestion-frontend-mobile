import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../../items/data/models/item.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/procedure.dart';

/// Page de creation de taches en lot pour plusieurs articles.
class BulkTaskPage extends StatefulWidget {
  /// Articles pre-selectionnes (optionnel).
  final List<String>? preselectedItemIds;

  const BulkTaskPage({super.key, this.preselectedItemIds});

  @override
  State<BulkTaskPage> createState() => _BulkTaskPageState();
}

class _BulkTaskPageState extends State<BulkTaskPage> {
  late final MaintenanceRepository _repository;
  late final Business _business;

  List<ItemModel> _items = [];
  List<ProcedureModel> _procedures = [];
  bool _loadingOptions = true;
  String? _optionsError;

  Set<String> _selectedItemIds = {};
  ProcedureModel? _selectedProcedure;
  bool _useDefaultProcedure = true;
  final _motifController = TextEditingController();

  bool _creating = false;
  int _createdCount = 0;
  int _failedCount = 0;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _repository = context.read<MaintenanceRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _loadOptions();
  }

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _repository.items(_business.id),
        _repository.procedures(_business.id),
      ]);
      if (mounted) {
        setState(() {
          _items = (results[0] as List).cast<ItemModel>();
          _procedures = (results[1] as List).cast<ProcedureModel>();
          // Pre-selection si fournie
          if (widget.preselectedItemIds != null) {
            _selectedItemIds = widget.preselectedItemIds!.toSet();
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _optionsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  void _toggleItem(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedItemIds = _items.map((i) => i.id).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  Future<void> _createTasks() async {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectionnez au moins un article.')),
      );
      return;
    }

    setState(() {
      _creating = true;
      _createdCount = 0;
      _failedCount = 0;
      _errors = [];
    });

    final procedureId = _useDefaultProcedure ? null : _selectedProcedure?.id;
    final motif = _motifController.text.trim();

    for (final itemId in _selectedItemIds) {
      try {
        await _repository.createTask(
          _business.id,
          itemId: itemId,
          procedureId: procedureId,
          motif: motif.isNotEmpty ? motif : null,
        );
        setState(() => _createdCount++);
      } on ApiException catch (e) {
        setState(() {
          _failedCount++;
          final item = _items.firstWhere(
            (i) => i.id == itemId,
            orElse: () => ItemModel(id: itemId, nom: 'Article inconnu'),
          );
          _errors.add('${item.nom}: ${e.message}');
        });
      }
    }

    setState(() => _creating = false);

    if (mounted) {
      if (_failedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_createdCount tache(s) creee(s) avec succes !'),
            backgroundColor: AppColors.kpiGreen,
          ),
        );
        Navigator.of(context).pop(_createdCount);
      } else {
        // Afficher le dialogue des erreurs
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultat'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_createdCount tache(s) creee(s)'),
                Text('$_failedCount echec(s)',
                    style: const TextStyle(color: AppColors.dangerText)),
                if (_errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Erreurs:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ..._errors.take(5).map((e) => Text(
                        '- $e',
                        style: const TextStyle(fontSize: 12),
                      )),
                  if (_errors.length > 5)
                    Text('... et ${_errors.length - 5} autre(s)',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.hint)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(_createdCount);
                },
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Entretien en lot', style: AppTextStyles.h2),
        centerTitle: false,
        actions: [
          if (_selectedItemIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedItemIds.length} article(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loadingOptions
          ? _buildLoadingSkeleton()
          : _optionsError != null
              ? _buildError()
              : _buildContent(),
      bottomNavigationBar: _loadingOptions || _optionsError != null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: PrimaryButton(
                  label: _creating
                      ? 'Creation en cours... ($_createdCount/${_selectedItemIds.length})'
                      : 'Creer ${_selectedItemIds.length} tache(s)',
                  icon: Icons.add_task,
                  isLoading: _creating,
                  onPressed: _selectedItemIds.isEmpty || _creating
                      ? null
                      : _createTasks,
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const SkeletonCard(child: SkeletonListItem()),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.hint),
          const SizedBox(height: 12),
          Text(_optionsError!, style: AppTextStyles.body),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadOptions,
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Introduction
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.kpiAmber.withValues(alpha: 0.15),
                  AppColors.kpiAmber.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.kpiAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flash_on,
                      color: AppColors.kpiAmber, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creation en masse',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Selectionnez plusieurs articles pour creer des taches d\'entretien simultanement.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Options procedure
          const Text(
            'PROCEDURE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Toggle procedure par defaut
          _OptionTile(
            title: 'Procedure par defaut',
            subtitle: 'Utiliser la procedure configuree pour chaque article',
            selected: _useDefaultProcedure,
            onTap: () => setState(() => _useDefaultProcedure = true),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            title: 'Meme procedure pour tous',
            subtitle: _selectedProcedure?.nom ?? 'Selectionnez une procedure',
            selected: !_useDefaultProcedure,
            onTap: () => setState(() => _useDefaultProcedure = false),
          ),

          if (!_useDefaultProcedure) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<ProcedureModel>(
              initialValue: _selectedProcedure,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              hint: const Text('Choisir une procedure'),
              items: _procedures
                  .where((p) => p.estActif)
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.nom, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (p) => setState(() => _selectedProcedure = p),
            ),
          ],

          const SizedBox(height: 16),

          // Motif optionnel
          const Text(
            'MOTIF (OPTIONNEL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _motifController,
            decoration: InputDecoration(
              hintText: 'Ex: Retour de location, Nettoyage mensuel...',
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Liste des articles
          Row(
            children: [
              const Text(
                'ARTICLES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectedItemIds.length == _items.length
                    ? _deselectAll
                    : _selectAll,
                child: Text(
                  _selectedItemIds.length == _items.length
                      ? 'Tout deselectionner'
                      : 'Tout selectionner',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Aucun article dans le catalogue.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = _selectedItemIds.contains(item.id);
                return _ItemSelectCard(
                  item: item,
                  selected: selected,
                  onTap: () => _toggleItem(item.id),
                );
              },
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.hint,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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

class _ItemSelectCard extends StatelessWidget {
  final ItemModel item;
  final bool selected;
  final VoidCallback onTap;

  const _ItemSelectCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.hint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nom,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.reference != null && item.reference!.isNotEmpty)
                        Text(
                          'Ref: ${item.reference}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
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
