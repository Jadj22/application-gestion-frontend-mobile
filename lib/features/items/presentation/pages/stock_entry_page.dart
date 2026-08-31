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
import '../../data/items_repository.dart';
import '../../data/models/item.dart';
import 'add_item_page.dart';

/// Enregistrement d'une entrée de stock (US-08) : article + quantité.
class StockEntryPage extends StatefulWidget {
  final String? preselectedItemId;

  const StockEntryPage({super.key, this.preselectedItemId});

  @override
  State<StockEntryPage> createState() => _StockEntryPageState();
}

class _StockEntryPageState extends State<StockEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late final ItemsRepository _repository;
  late final Business _business;

  final _quantiteController = TextEditingController();
  final _referenceController = TextEditingController();
  final _motifController = TextEditingController();

  List<ItemModel> _items = [];
  bool _loadingItems = true;
  String? _itemsError;
  ItemModel? _selectedItem;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _loadItems();
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _referenceController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    try {
      final items = await _repository.items(_business.id);
      if (mounted) {
        setState(() {
          _items = items.where((i) => i.statut == 'ACTIF').toList();
          final presetId = widget.preselectedItemId;
          if (presetId != null) {
            for (final item in _items) {
              if (item.id == presetId) {
                _selectedItem = item;
                break;
              }
            }
          }
          if (_selectedItem != null &&
              !_items.any((i) => i.id == _selectedItem!.id)) {
            _selectedItem = null;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _itemsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      setState(() => _error = 'Sélectionnez un article.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final movement = await _repository.createStockEntry(
        _business.id,
        itemId: _selectedItem!.id,
        quantite: int.parse(_quantiteController.text.trim()),
        reference: _referenceController.text.trim(),
        motif: _motifController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(movement);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle entrée de stock')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entrée de stock', style: AppTextStyles.h1),
                const SizedBox(height: 4),
                Text(
                  'Enregistrez une arrivée de matériel dans votre stock.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 32),
                Text('ARTICLE *', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                if (_loadingItems)
                  const Skeleton(
                    child: SkeletonBox(
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  )
                else if (_itemsError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(_itemsError!,
                            style: const TextStyle(
                                color: AppColors.dangerText, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: _loadItems,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  )
                else if (_items.isEmpty)
                  _EmptyCatalogBanner(
                    onAddItem: () async {
                      final created = await Navigator.of(context)
                          .push<ItemModel>(
                        MaterialPageRoute(builder: (_) => const AddItemPage()),
                      );
                      if (created != null) _loadItems();
                    },
                  )
                else
                  DropdownButtonFormField<ItemModel>(
                    initialValue: _selectedItem,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choisir un article',
                      prefixIcon: Icon(Icons.inventory_2_outlined,
                          color: Colors.grey, size: 20),
                    ),
                    items: _items
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.reference == null || item.reference!.isEmpty
                                    ? item.nom
                                    : '${item.nom} — ${item.reference}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (item) => setState(() => _selectedItem = item),
                  ),
                const SizedBox(height: 20),
                CustomInputField(
                  label: 'Quantité *',
                  hint: '5',
                  prefixIcon: Icons.format_list_numbered_outlined,
                  controller: _quantiteController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'La quantité est requise';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) {
                      return 'Quantité invalide (entier > 0)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomInputField(
                  label: 'Référence (bon de livraison, facture…)',
                  hint: 'BL-2026-001',
                  prefixIcon: Icons.receipt_long_outlined,
                  controller: _referenceController,
                ),
                const SizedBox(height: 20),
                CustomInputField(
                  label: 'Motif (optionnel)',
                  hint: 'Livraison fournisseur',
                  prefixIcon: Icons.notes_outlined,
                  controller: _motifController,
                  maxLines: 2,
                ),
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
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Enregistrer l\'entrée',
                  icon: Icons.south_outlined,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Catalogue vide : invite à créer d'abord un article.
class _EmptyCatalogBanner extends StatelessWidget {
  final VoidCallback onAddItem;

  const _EmptyCatalogBanner({required this.onAddItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.hint),
          const SizedBox(height: 8),
          const Text(
            'Aucun article actif dans le catalogue.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onAddItem,
            child: const Text('Ajouter un article'),
          ),
        ],
      ),
    );
  }
}