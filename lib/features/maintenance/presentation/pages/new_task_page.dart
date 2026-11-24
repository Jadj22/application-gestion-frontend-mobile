import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../../items/data/models/item.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/procedure.dart';

/// Mapping categorie -> procedure suggeree (par nom).
const _categorySuggestions = <String, String>{
  'textile': 'Nettoyage standard',
  'linge': 'Nettoyage standard',
  'vetement': 'Nettoyage standard',
  'nappes': 'Nettoyage standard',
  'housse': 'Nettoyage standard',
  'decoration': 'Contrôle qualité',
  'mobilier': 'Contrôle qualité',
  'vaisselle': 'Nettoyage standard',
  'location': 'Préparation location',
  'retour': 'Retour client',
};

/// Création d'une tâche d'entretien (US-15) : article + procédure + motif.
class NewTaskPage extends StatefulWidget {
  /// Si fourni, pre-selectionne cet article.
  final String? preselectedItemId;

  const NewTaskPage({super.key, this.preselectedItemId});

  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  final _formKey = GlobalKey<FormState>();
  late final MaintenanceRepository _repository;
  late final Business _business;

  final _motifController = TextEditingController();

  List<ItemModel> _items = [];
  List<ProcedureModel> _procedures = [];
  bool _loadingOptions = true;
  String? _optionsError;

  ItemModel? _selectedItem;
  ProcedureModel? _selectedProcedure;
  ProcedureModel? _suggestedProcedure;
  bool _submitting = false;
  String? _error;

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
          // Pre-selection si itemId fourni
          if (widget.preselectedItemId != null) {
            _selectedItem = _items.where(
              (i) => i.id == widget.preselectedItemId,
            ).firstOrNull;
            _updateSuggestedProcedure();
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _optionsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  /// Trouve une procedure suggeree basee sur la categorie de l'article.
  void _updateSuggestedProcedure() {
    _suggestedProcedure = null;
    if (_selectedItem == null || _procedures.isEmpty) return;

    final categoryName = _selectedItem!.categoryNom?.toLowerCase() ?? '';

    // Cherche une correspondance dans les suggestions
    for (final entry in _categorySuggestions.entries) {
      if (categoryName.contains(entry.key)) {
        // Trouve la procedure avec ce nom
        _suggestedProcedure = _procedures
            .where((p) => p.nom.toLowerCase().contains(entry.value.toLowerCase()))
            .firstOrNull;
        if (_suggestedProcedure != null) break;
      }
    }

    // Si pas de suggestion specifique, utiliser la premiere procedure active
    _suggestedProcedure ??= _procedures.where((p) => p.estActif).firstOrNull;
  }

  void _onItemChanged(ItemModel? item) {
    setState(() {
      _selectedItem = item;
      _updateSuggestedProcedure();
      // Auto-select la procedure suggeree si aucune n'est selectionnee
      if (_selectedProcedure == null && _suggestedProcedure != null) {
        _selectedProcedure = _suggestedProcedure;
      }
    });
  }

  void _applySuggestion() {
    if (_suggestedProcedure != null) {
      setState(() => _selectedProcedure = _suggestedProcedure);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un article.')),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final task = await _repository.createTask(
        _business.id,
        itemId: _selectedItem!.id,
        procedureId: _selectedProcedure?.id,
        motif: _motifController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(task);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: null,
        leadingWidth: 104,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: const Text('Entretien'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer une tâche', style: AppTextStyles.h1),
                const SizedBox(height: 4),
                Text(
                  'Programmez une intervention d\'entretien pour un article de votre catalogue.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 32),
                if (_loadingOptions)
                  const Skeleton(
                    child: Column(
                      children: [
                        SkeletonBox(
                          height: 56,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        SizedBox(height: 16),
                        SkeletonBox(
                          height: 56,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ],
                    ),
                  )
                else if (_optionsError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(_optionsError!,
                            style: const TextStyle(
                                color: AppColors.dangerText, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: _loadOptions,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  )
                else ...[
                  Text('ARTICLE *', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ItemModel>(
                    initialValue: _selectedItem,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Sélectionner un article',
                      prefixIcon: Icon(Icons.inventory_2_outlined,
                          color: Colors.grey, size: 20),
                    ),
                    items: _items
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.nom,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: _onItemChanged,
                  ),
                  if (_items.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Le catalogue est vide : créez d\'abord un article.',
                      style: AppTextStyles.body,
                    ),
                  ],

                  // Suggestion basee sur la categorie
                  if (_selectedItem != null && _suggestedProcedure != null && _selectedProcedure != _suggestedProcedure) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _applySuggestion,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Suggestion',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Utiliser « ${_suggestedProcedure!.nom} »',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Text('PROCÉDURE', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProcedureModel>(
                    key: ValueKey(_selectedProcedure?.id),
                    initialValue: _selectedProcedure,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Procédure par défaut',
                      prefixIcon: Icon(Icons.build_outlined,
                          color: Colors.grey, size: 20),
                    ),
                    items: _procedures
                        .where((p) => p.estActif)
                        .map((procedure) => DropdownMenuItem(
                              value: procedure,
                              child: Text(procedure.nom,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (procedure) =>
                        setState(() => _selectedProcedure = procedure),
                  ),
                  if (_selectedProcedure == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sans sélection, la procédure par défaut de l\'article sera utilisée.',
                      style: TextStyle(fontSize: 12, color: AppColors.hint),
                    ),
                  ],
                  if (_procedures.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Aucune procédure disponible.',
                      style: AppTextStyles.body,
                    ),
                  ],
                  const SizedBox(height: 20),
                  CustomInputField(
                    label: 'Motif',
                    hint: 'Raison de l\'intervention (optionnel)',
                    prefixIcon: Icons.notes_outlined,
                    controller: _motifController,
                    maxLines: 2,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.dangerText, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: PrimaryButton(
          label: 'Créer la tâche',
          icon: Icons.add_task_outlined,
          isLoading: _submitting,
          onPressed: _loadingOptions || _optionsError != null ? null : _submit,
        ),
      ),
    );
  }
}