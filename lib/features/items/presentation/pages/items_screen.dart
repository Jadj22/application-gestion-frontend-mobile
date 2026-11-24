import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../../shared/widgets/sync_status_banner.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/items_repository.dart';
import '../../data/models/catalog_item.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';
import '../../data/models/stock_movement.dart';
import 'add_item_page.dart';
import 'categories_list_page.dart';
import 'item_detail_screen.dart';
import 'stock_entry_page.dart';
import '../widgets/stock_export_bottom_sheet.dart';

/// Filtre d'ouverture depuis les KPI du dashboard.
class InventoryFocus {
  final int tabIndex;
  final String? statusFilter;

  const InventoryFocus({this.tabIndex = 1, this.statusFilter});

  static const total = InventoryFocus();
  static const disponible = InventoryFocus(statusFilter: 'disponible');
  static const location = InventoryFocus(statusFilter: 'location');
  static const entretien = InventoryFocus(statusFilter: 'entretien');
  static const endommage = InventoryFocus(statusFilter: 'endommage');
  static const verifier = InventoryFocus(statusFilter: 'verifier');
}

/// Inventaire (US-06) — maquette « Logistics Manager - Inventory » :
/// deux onglets, Catalogue (recherche + filtres par catégorie) et
/// Stock (état détaillé de chaque article), avec badges de statut.
class ItemsScreen extends StatefulWidget {
  final bool showBottomNav;
  final InventoryFocus? focus;

  const ItemsScreen({super.key, this.showBottomNav = true, this.focus});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen>
    with SingleTickerProviderStateMixin {
  late final ItemsRepository _repository;
  late final Business _business;
  late final SessionController _session;
  late final TabController _tabController;

  List<CatalogItemModel> _items = [];
  List<CategoryModel> _categories = [];
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _selectedCategoryId;
  String? _selectedStatus;
  bool _sortAsc = true;

  static const _stockFilters = [
    (null, 'Tous'),
    ('disponible', 'Disponible'),
    ('location', 'En location'),
    ('entretien', 'Entretien'),
    ('endommage', 'Endommagé'),
    ('verifier', 'À vérifier'),
    ('epuise', 'Épuisé'),
    ('inactif', 'Inactif'),
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _session = context.read<SessionController>();
    _business = _session.currentBusiness!;
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    final focus = widget.focus;
    if (focus != null) {
      _selectedStatus = focus.statusFilter;
      if (focus.tabIndex != _tabController.index) {
        _tabController.index = focus.tabIndex;
      }
    }
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _repository.catalog(_business.id),
        _repository.categories(_business.id),
      ]);
      if (mounted) {
        setState(() {
          _items = results[0] as List<CatalogItemModel>;
          _categories = results[1] as List<CategoryModel>;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _items.isEmpty) setState(() => _error = e.message);
    } on NetworkUnavailableException catch (e) {
      if (mounted && _items.isEmpty) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && _items.isEmpty) {
        setState(() => _error = 'Impossible de charger le catalogue.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Filtres
  // ---------------------------------------------------------------------------

  List<CatalogItemModel> _sorted(Iterable<CatalogItemModel> source) {
    final list = source.toList();
    list.sort((a, b) => _sortAsc
        ? a.nom.toLowerCase().compareTo(b.nom.toLowerCase())
        : b.nom.toLowerCase().compareTo(a.nom.toLowerCase()));
    return list;
  }

  /// Catalogue : filtre par catégorie + recherche.
  List<CatalogItemModel> get _filteredCatalog {
    final query = _query.trim().toLowerCase();
    return _sorted(_items.where((item) {
      if (_selectedCategoryId != null &&
          item.categoryId != _selectedCategoryId) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.nom.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query) ||
          (item.categorie?.toLowerCase().contains(query) ?? false);
    }));
  }

  /// Stock : filtre par statut + recherche.
  List<CatalogItemModel> get _filteredStock {
    final query = _query.trim().toLowerCase();
    return _sorted(_items.where((item) {
      if (!_matchesStatus(item, _selectedStatus)) return false;
      if (query.isEmpty) return true;
      return item.nom.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query);
    }));
  }

  bool _matchesStatus(CatalogItemModel item, String? status) {
    switch (status) {
      case null:
        return true;
      case 'disponible':
        return !item.inactif && item.quantite > 0;
      case 'location':
        return item.sorties > 0;
      case 'entretien':
        return item.entretienRequis && item.endommages == 0;
      case 'endommage':
        return item.endommages > 0;
      case 'verifier':
        return item.aVerifier;
      case 'epuise':
        // Filtre sur les ruptures reelles : un stock inconnu n'en est pas une.
        return item.epuise;
      case 'inactif':
        return item.inactif;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openAddItem() async {
    if (!_session.can('item.edit')) {
      _showPermissionDenied('gérer les articles');
      return;
    }
    final created = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(builder: (_) => const AddItemPage()),
    );
    if (created != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${created.nom} » a été ajouté au catalogue.')),
      );
    }
  }

  Future<void> _openCategories() async {
    if (!_session.can('catalog.view')) {
      _showPermissionDenied('voir les catégories');
      return;
    }
    final created = await Navigator.of(context).push<CategoryModel>(
      MaterialPageRoute(builder: (_) => const CategoriesListPage()),
    );
    if (created != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catégorie « ${created.nom} » ajoutée.')),
      );
    }
  }

  void _openStockExport() {
    StockExportBottomSheet.show(context, _business);
  }

  Future<void> _openStockEntry() async {
    if (!_session.can('stock.mouvement')) {
      _showPermissionDenied('gérer le stock');
      return;
    }
    final movement = await Navigator.of(context).push<StockMovementModel>(
      MaterialPageRoute(builder: (_) => const StockEntryPage()),
    );
    if (movement != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '+${movement.quantite} « ${movement.itemNom} » ajouté au stock.',
          ),
        ),
      );
    }
  }

  void _showPermissionDenied(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vous n\'avez pas la permission de $action.')),
    );
  }

  Future<void> _openDetail(CatalogItemModel item) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(itemId: item.id, initialNom: item.nom),
      ),
    );
    if (deleted == true && mounted) _load();
  }

  void _fabAction() {
    if (_tabController.index == 0) {
      _openAddItem();
    } else {
      _openStockEntry();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashSurfaceLow,
      appBar: AppBar(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.search, color: AppColors.dashPrimary),
          tooltip: 'Rechercher',
          onPressed: () => _searchFocus.requestFocus(),
        ),
        title: const Text(
          'Inventaire',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined,
                color: AppColors.dashPrimary),
            tooltip: 'Exporter les stocks',
            onPressed: _openStockExport,
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined,
                color: AppColors.dashPrimary),
            tooltip: 'Catégories',
            onPressed: _openCategories,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.dashPrimary),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Notifications — bientôt disponible')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: AppColors.dashOutlineVariant,
          indicatorColor: AppColors.dashPrimary,
          indicatorWeight: 2,
          labelColor: AppColors.dashPrimary,
          unselectedLabelColor: AppColors.dashOnSurfaceVariant,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Catalogue', icon: Icon(Icons.view_list_outlined, size: 18)),
            Tab(text: 'Stock', icon: Icon(Icons.inventory_2_outlined, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SyncStatusBanner(),
            Expanded(
              child: _loading
                  ? _buildLoadingSkeleton()
                  : _error != null
                      ? _LoadError(message: _error!, onRetry: _load)
                      : TabBarView(
                          controller: _tabController,
                          children: [_buildCatalogTab(), _buildStockTab()],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fabAction,
        backgroundColor: AppColors.dashPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: _tabController.index == 0
            ? 'Ajouter un article'
            : 'Nouvelle entrée de stock',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? AppBottomNav(
              currentIndex: 1,
              onTap: (index) {
                if (index != 1) {
                  const labels = [
                    'Dashboard',
                    'Inventaire',
                    'Entretien',
                    'Réservations',
                    'Plus'
                  ];
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('« ${labels[index]} » arrive bientôt')),
                  );
                  return;
                }
                Navigator.of(context).pop();
              },
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Barre de recherche
  // ---------------------------------------------------------------------------

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cols = width >= 1024 ? 3 : width >= 640 ? 2 : 1;
          const spacing = 12.0;
          final cardWidth = (width - 32 - spacing * (cols - 1)) / cols;
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < 6; i++)
                  SizedBox(
                    width: cardWidth,
                    child: SkeletonCard(
                      radius: 24,
                      child: Row(
                        children: [
                          const SkeletonImage(width: 60, height: 60, radius: 12),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SkeletonText(width: 120, height: 14),
                                SizedBox(height: 8),
                                SkeletonText(width: 80, height: 11),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: _tabController.index == 0
              ? 'Rechercher par nom, SKU ou catégorie...'
              : 'Rechercher dans le stock...',
          prefixIcon: const Icon(Icons.search, color: AppColors.dashOutline),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintStyle: const TextStyle(color: AppColors.dashOutline, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.dashOutlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.dashOutlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.dashSecondary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pastilles de filtre (catégories / statuts)
  // ---------------------------------------------------------------------------

  Widget _buildChips({
    required List<(String?, String)> options,
    required String? selected,
    required ValueChanged<String?> onSelect,
  }) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (value, label) in options) ...[
            if (value != options.first.$1) const SizedBox(width: 8),
            _FilterChip(
              label: label,
              active: selected == value,
              onTap: () => onSelect(value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return _buildChips(
      options: [(null, 'Tous'), for (final c in _categories) (c.id, c.nom)],
      selected: _selectedCategoryId,
      onSelect: (value) => setState(() => _selectedCategoryId = value),
    );
  }

  Widget _buildStatusChips() {
    return _buildChips(
      options: _stockFilters,
      selected: _selectedStatus,
      onSelect: (value) => setState(() => _selectedStatus = value),
    );
  }

  // ---------------------------------------------------------------------------
  // Onglet Catalogue
  // ---------------------------------------------------------------------------

  Widget _buildCatalogTab() {
    final items = _filteredCatalog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildCategoryChips(),
        const SizedBox(height: 8),
        _buildHeader('Tous les articles (${items.length})'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.dashSecondary,
            child: items.isEmpty
                ? _emptyScrollable(_EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: _query.isEmpty && _selectedCategoryId == null
                        ? 'Le catalogue est vide.'
                        : 'Aucun article ne correspond à votre recherche.',
                  ))
                : _buildBento(
                    itemCount: items.length,
                    cardBuilder: (context, cardWidth, index) => _CatalogCard(
                      item: items[index],
                      onTap: () => _openDetail(items[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Onglet Stock
  // ---------------------------------------------------------------------------

  String get _stockHeaderTitle {
    final count = _filteredStock.length;
    switch (_selectedStatus) {
      case 'disponible':
        final units =
            _filteredStock.fold<int>(0, (sum, i) => sum + i.quantite);
        return 'Disponibles ($count · $units unités)';
      case 'location':
        return 'En location ($count)';
      case 'entretien':
        return 'En entretien ($count)';
      case 'endommage':
        return 'Endommagés ($count)';
      case 'verifier':
        return 'À vérifier ($count)';
      case 'epuise':
        return 'Épuisés ($count)';
      case 'inactif':
        return 'Inactifs ($count)';
      default:
        return 'État du stock ($count)';
    }
  }

  Map<String, List<CatalogItemModel>> _groupByCategory(
      List<CatalogItemModel> items) {
    final map = <String, List<CatalogItemModel>>{};
    for (final item in items) {
      final key = item.categorie ?? 'Sans catégorie';
      map.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  Widget _buildStockTab() {
    final items = _filteredStock;
    final groupByCategory = _selectedStatus == 'disponible';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildStatusChips(),
        const SizedBox(height: 8),
        _buildHeader(_stockHeaderTitle),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.dashSecondary,
            child: items.isEmpty
                ? _emptyScrollable(_EmptyState(
                    icon: Icons.query_stats,
                    message: _query.isEmpty && _selectedStatus == null
                        ? 'Aucun article dans le stock.'
                        : 'Aucun article ne correspond à ce filtre.',
                  ))
                : groupByCategory
                    ? _buildCategoryGroupedStock(items)
                    : _buildBento(
                        itemCount: items.length,
                        cardBuilder: (context, cardWidth, index) => _StockCard(
                          item: items[index],
                          cardWidth: cardWidth,
                          onTap: () => _openDetail(items[index]),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  /// Vue regroupée par catégorie — utilisée pour le filtre « Disponible ».
  Widget _buildCategoryGroupedStock(List<CatalogItemModel> items) {
    final groups = _groupByCategory(items);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final category = groups.keys.elementAt(index);
        final categoryItems = groups[category]!;
        final unitCount =
            categoryItems.fold<int>(0, (sum, i) => sum + i.quantite);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _CategoryStockSection(
            category: category,
            items: categoryItems,
            unitCount: unitCount,
            onItemTap: _openDetail,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Bento (grille adaptative) + éléments partagés
  // ---------------------------------------------------------------------------

  /// Grille de type bento : 1 colonne mobile, 2 tablette, 3 bureau —
  /// hauteurs intrinsèques (Wrap) pour rester robuste au contenu.
  Widget _buildBento({
    required int itemCount,
    required Widget Function(BuildContext context, double cardWidth, int index)
        cardBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1024 ? 3 : width >= 640 ? 2 : 1;
        const spacing = 12.0;
        final cardWidth = (width - 32 - spacing * (cols - 1)) / cols;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < itemCount; i++)
                SizedBox(
                  width: cardWidth,
                  child: cardBuilder(context, cardWidth, i),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.dashOnSurface,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: AppColors.dashOnSurfaceVariant,
            ),
            tooltip: _sortAsc ? 'Tri A → Z' : 'Tri Z → A',
            onPressed: () => setState(() => _sortAsc = !_sortAsc),
          ),
        ],
      ),
    );
  }

  Widget _emptyScrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section catégorie (vue stock « Disponible »)
// ---------------------------------------------------------------------------

class _CategoryStockSection extends StatelessWidget {
  final String category;
  final List<CatalogItemModel> items;
  final int unitCount;
  final ValueChanged<CatalogItemModel> onItemTap;

  const _CategoryStockSection({
    required this.category,
    required this.items,
    required this.unitCount,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.kpiGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.category_outlined,
                    size: 18,
                    color: AppColors.kpiGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dashOnSurface,
                        ),
                      ),
                      Text(
                        '${items.length} article${items.length > 1 ? 's' : ''} · $unitCount unité${unitCount > 1 ? 's' : ''} prête${unitCount > 1 ? 's' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.dashOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.dashOutlineVariant),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.dashOutlineVariant,
              ),
            _CategoryStockRow(
              item: items[i],
              onTap: () => onItemTap(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryStockRow extends StatelessWidget {
  final CatalogItemModel item;
  final VoidCallback onTap;

  const _CategoryStockRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Thumbnail(item: item, size: 44, radius: 8, enableHero: false),
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
                        color: AppColors.dashOnSurface,
                      ),
                    ),
                    if (item.sku.isNotEmpty)
                      Text(
                        item.sku,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.dashOnSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.kpiGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${item.quantite}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kpiGreen,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.dashOutline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pastille de filtre
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.dashPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.dashPrimary : AppColors.dashOutlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: active ? Colors.white : AppColors.dashOnSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge de statut — couleurs de la maquette « Logistics Manager »
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  const _StatusBadge.available()
      : this(
          label: 'Disponible',
          background: AppColors.badgeAvailableBg,
          foreground: AppColors.badgeAvailableFg,
          border: AppColors.badgeAvailableBorder,
        );

  const _StatusBadge.neutral(String label)
      : this(
          label: label,
          background: AppColors.badgeNeutralBg,
          foreground: AppColors.badgeNeutralFg,
          border: AppColors.badgeNeutralBorder,
        );

  const _StatusBadge.indigo(String label)
      : this(
          label: label,
          background: AppColors.badgeIndigoBg,
          foreground: AppColors.badgeIndigoFg,
          border: AppColors.badgeIndigoBorder,
        );

  /// Stock non encore connu de l'appareil (article tout juste cree, ou
  /// premiere synchronisation pas encore faite).
  const _StatusBadge.unknown()
      : this(
          label: 'Stock à venir',
          background: AppColors.badgeNeutralBg,
          foreground: AppColors.badgeNeutralFg,
          border: AppColors.badgeNeutralBorder,
        );

  const _StatusBadge.exhausted()
      : this(
          label: 'Épuisé',
          background: AppColors.badgeDangerBg,
          foreground: AppColors.badgeDangerFg,
          border: AppColors.badgeDangerBorder,
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: foreground,
        ),
      ),
    );
  }
}

/// Résolution du badge selon la priorité : inactif → à vérifier →
/// en location → entretien → disponible → épuisé.
_StatusBadge _badgeOf(CatalogItemModel item) {
  if (item.inactif) return const _StatusBadge.neutral('Inactif');
  if (item.aVerifier) return const _StatusBadge.indigo('À Vérifier');
  if (item.sorties > 0) return const _StatusBadge.indigo('En Location');
  if (item.endommages > 0) {
    return const _StatusBadge.neutral('Endommagé');
  }
  if (item.entretienRequis) {
    return const _StatusBadge.neutral('En Entretien');
  }
  if (item.quantite > 0) return const _StatusBadge.available();
  // Sans information de stock, on ne declare pas la rupture : l'article vient
  // peut-etre d'etre cree et le serveur ne l'a pas encore compte.
  if (!item.stockConnu) return const _StatusBadge.unknown();
  return const _StatusBadge.exhausted();
}

// ---------------------------------------------------------------------------
// Carte du catalogue (bento)
// ---------------------------------------------------------------------------

class _CatalogCard extends StatelessWidget {
  final CatalogItemModel item;
  final VoidCallback onTap;

  const _CatalogCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = (item.categorie ?? '—')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .join(' ')
        .toUpperCase();
    return Material(
      color: AppColors.dashSurfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Thumbnail(item: item, size: 72, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dashOnSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CountLine(label: 'Total', value: item.total),
                            _CountLine(label: 'Avail', value: item.quantite),
                          ],
                        ),
                        const Spacer(),
                        _badgeOf(item),
                      ],
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

class _CountLine extends StatelessWidget {
  final String label;
  final int value;

  const _CountLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
            color: AppColors.dashOutline,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
            color: AppColors.dashOnSurface,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carte du stock (bento) — état détaillé
// ---------------------------------------------------------------------------

class _StockCard extends StatelessWidget {
  final CatalogItemModel item;
  final double cardWidth;
  final VoidCallback onTap;

  const _StockCard({
    required this.item,
    required this.cardWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = (item.categorie ?? '—')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .join(' ')
        .toUpperCase();
    final statWidth = (cardWidth - 28 - 8) / 2;
    return Material(
      color: AppColors.dashSurfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumbnail(item: item, size: 64, radius: 10, enableHero: false),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dashOnSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _badgeOf(item)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.dashOutlineVariant),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: statWidth,
                    child: _StockStat(
                      label: 'Total',
                      value: item.total,
                      color: AppColors.dashOnSurfaceVariant,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _StockStat(
                      label: 'Disponibles',
                      value: item.quantite,
                      color: AppColors.kpiGreen,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _StockStat(
                      label: 'En location',
                      value: item.sorties,
                      color: AppColors.kpiIndigo,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _StockStat(
                      label: 'Endommagés',
                      value: item.endommages,
                      color: AppColors.kpiAmber,
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

class _StockStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StockStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.dashOnSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: AppColors.dashOnSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Miniature (photo ou icône par catégorie)
// ---------------------------------------------------------------------------

class _Thumbnail extends StatelessWidget {
  final CatalogItemModel item;
  final double size;
  final double radius;
  final bool enableHero;

  const _Thumbnail({
    required this.item,
    required this.size,
    required this.radius,
    this.enableHero = true,
  });

  @override
  Widget build(BuildContext context) {
    if (item.photoUrl != null) {
      return HeroMode(
        enabled: enableHero,
        child: Hero(
          tag: 'item-photo-${item.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: size,
              height: size,
              child: Image.network(
                item.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
            ),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final c = (item.categorie ?? '').toLowerCase();
    final IconData icon;
    if (c.contains('table')) {
      icon = Icons.table_restaurant_outlined;
    } else if (c.contains('chaise') || c.contains('siège')) {
      icon = Icons.chair_outlined;
    } else if (c.contains('nappe') || c.contains('linge')) {
      icon = Icons.local_laundry_service_outlined;
    } else if (c.contains('vaisselle')) {
      icon = Icons.rice_bowl_outlined;
    } else {
      icon = Icons.inventory_2_outlined;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: Icon(icon, size: size * 0.5, color: AppColors.dashOutline),
    );
  }
}

// ---------------------------------------------------------------------------
// États : erreur / vide
// ---------------------------------------------------------------------------

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
          const Icon(Icons.cloud_off, size: 48, color: AppColors.dashOutline),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: AppColors.dashOutline),
        const SizedBox(height: 12),
        Text(
          message,
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
