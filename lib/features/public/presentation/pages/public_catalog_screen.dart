import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/public_item_model.dart';
import '../../data/repositories/public_catalog_repository.dart';
import '../widgets/availability_badge.dart';
import 'public_item_detail_screen.dart';

/// Écran catalogue public d'un business (V1) — accessible sans authentification.
class PublicCatalogScreen extends StatefulWidget {
  final String slug;
  final String businessName;

  const PublicCatalogScreen({
    super.key,
    required this.slug,
    required this.businessName,
  });

  @override
  State<PublicCatalogScreen> createState() => _PublicCatalogScreenState();
}

class _PublicCatalogScreenState extends State<PublicCatalogScreen> {
  late final PublicCatalogRepository _repository;
  DateTime? _selectedDateDebut;
  DateTime? _selectedDateFin;
  List<PublicItemModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _repository = PublicCatalogRepository(apiClient);
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await _repository.getCatalog(
        slug: widget.slug,
        dateDebut: _selectedDateDebut,
        dateFin: _selectedDateFin,
      );
    } catch (e) {
      _error = 'Erreur de chargement: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateDebut != null && _selectedDateFin != null
          ? DateTimeRange(start: _selectedDateDebut!, end: _selectedDateFin!)
          : null,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Theme.of(context).primaryColor,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateDebut = picked.start;
        _selectedDateFin = picked.end;
      });
      _loadCatalog();
    }
  }

  void _clearDates() {
    setState(() {
      _selectedDateDebut = null;
      _selectedDateFin = null;
    });
    _loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.businessName),
        actions: [
          if (_selectedDateDebut != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDates,
              tooltip: 'Retirer les dates',
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDateRange,
            tooltip: 'Filtrer par dates',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCatalog,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun article publié',
                            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'L\'entreprise n\'a pas encore publié d\'articles.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCatalog,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _PublicItemCard(
                            item: item,
                            onTap: () => _navigateToDetail(item),
                          );
                        },
                      ),
                    ),
    );
  }

  void _navigateToDetail(PublicItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicItemDetailScreen(
          slug: widget.slug,
          businessName: widget.businessName,
          item: item,
          selectedDateDebut: _selectedDateDebut,
          selectedDateFin: _selectedDateFin,
        ),
      ),
    );
  }
}

/// Carte d'article pour le catalogue public
class _PublicItemCard extends StatelessWidget {
  final PublicItemModel item;
  final VoidCallback onTap;

  const _PublicItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: item.photoUrl != null
                      ? Image.network(
                          item.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nom,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.reference != null && item.reference!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Ref: ${item.reference}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ),
                    if (item.categoryNom != null && item.categoryNom!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.categoryNom!,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Prix + dispo
                    Row(
                      children: [
                        Text(
                          item.prixFormate,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        AvailabilityBadge(
                          disponible: item.disponible,
                          peutReserver: item.peutReserver,
                          showLabel: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
}