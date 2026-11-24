import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_view.dart';
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
    ('entretien', 'En entretien'),
    ('endommage', 'Abîmés'),
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
    list.sort(
      (a, b) => _sortAsc
          ? a.nom.toLowerCase().compareTo(b.nom.toLowerCase())
          : b.nom.toLowerCase().compareTo(a.nom.toLowerCase()),
    );
    return list;
  }

  /// Catalogue : filtre par catégorie + recherche.
  List<CatalogItemModel> get _filteredCatalog {
    final query = _query.trim().toLowerCase();
    return _sorted(
      _items.where((item) {
        if (_selectedCategoryId != null &&
            item.categoryId != _selectedCategoryId) {
          return false;
        }
        if (query.isEmpty) return true;
        return item.nom.toLowerCase().contains(query) ||
            item.sku.toLowerCase().contains(query) ||
            (item.categorie?.toLowerCase().contains(query) ?? false);
      }),
    );
  }

  /// Stock : filtre par statut + recherche.
  List<CatalogItemModel> get _filteredStock {
    final query = _query.trim().toLowerCase();
    return _sorted(
      _items.where((item) {
        if (!_matchesStatus(item, _selectedStatus)) return false;
        if (query.isEmpty) return true;
        return item.nom.toLowerCase().contains(query) ||
            item.sku.toLowerCase().contains(query);
      }),
    );
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
        return item.entretienStock > 0;
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
    final created = await Navigator.of(
      context,
    ).push<ItemModel>(MaterialPageRoute(builder: (_) => const AddItemPage()));
    if (created != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('« ${created.nom} » a été ajouté au catalogue.'),
        ),
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
        backgroundColor: AppColors.dashSurfaceLow,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text(
          'Inventaire',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.dashOnSurface,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.dashPrimary,
            ),
            tooltip: 'Exporter les stocks',
            onPressed: _openStockExport,
          ),
          PopupMenuButton<String>(
            tooltip: 'Autres actions',
            onSelected: (value) {
              if (value == 'categories') {
                _openCategories();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications — bientôt disponible'),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'categories',
                child: Text('Gérer les catégories'),
              ),
              PopupMenuItem(
                value: 'notifications',
                child: Text('Notifications'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.dashPrimary),
            tooltip: _tabController.index == 0
                ? 'Ajouter un article'
                : 'Nouvelle entrée de stock',
            onPressed: _fabAction,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.dashSurfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                indicator: BoxDecoration(
                  color: AppColors.dashSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dashOutlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: AppColors.dashOnSurface,
                unselectedLabelColor: AppColors.dashOnSurfaceVariant,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Catalogue'),
                  Tab(text: 'Stock'),
                ],
              ),
            ),
          ),
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
                  ? AppErrorView(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildCatalogTab(), _buildStockTab()],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? AppBottomNav(
              currentIndex: 1,
              onTap: (index) {
                if (index != 1) {
                  const labels = [
                    'Accueil',
                    'Inventaire',
                    'Réservations',
                    'Entretien',
                    'Plus',
                  ];
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('« ${labels[index]} » arrive bientôt'),
                    ),
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
          final cols = width >= 1024
              ? 3
              : width >= 360
              ? 2
              : 1;
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
                          const SkeletonImage(
                            width: 60,
                            height: 60,
                            radius: 12,
                          ),
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
              ? 'Nom, référence ou catégorie'
              : 'Rechercher dans le stock',
          prefixIcon: const Icon(Icons.search, color: AppColors.dashOutline),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintStyle: const TextStyle(
            color: AppColors.dashOutline,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.dashOutlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.dashOutlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.dashSecondary,
              width: 1.5,
            ),
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
    bool showSort = false,
  }) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
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
          ),
          if (showSort)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _sortAsc ? 'Tri A à Z' : 'Tri Z à A',
              onPressed: () => setState(() => _sortAsc = !_sortAsc),
              icon: Icon(
                _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
                color: AppColors.dashOnSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return _buildChips(
      options: [
        (null, 'Tous · ${_items.length}'),
        for (final c in _categories) (c.id, c.nom),
      ],
      selected: _selectedCategoryId,
      onSelect: (value) => setState(() => _selectedCategoryId = value),
      showSort: true,
    );
  }

  Widget _buildStatusChips() {
    return _buildChips(
      options: _stockFilters,
      selected: _selectedStatus,
      onSelect: (value) => setState(() => _selectedStatus = value),
      showSort: true,
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.dashSecondary,
            child: items.isEmpty
                ? _emptyScrollable(
                    AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _query.isEmpty && _selectedCategoryId == null
                          ? 'Le catalogue est vide.'
                          : 'Aucun article ne correspond à votre recherche.',
                    ),
                  )
                : _buildBento(
                    itemCount: items.length,
                    mobileGrid: true,
                    cardBuilder: (context, cardWidth, index) => _CatalogCard(
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

  // ---------------------------------------------------------------------------
  // Onglet Stock
  // ---------------------------------------------------------------------------

  Map<String, List<CatalogItemModel>> _groupByCategory(
    List<CatalogItemModel> items,
  ) {
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
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.dashSecondary,
            child: items.isEmpty
                ? _emptyScrollable(
                    AppEmptyState(
                      icon: Icons.query_stats,
                      title: _query.isEmpty && _selectedStatus == null
                          ? 'Aucun article dans le stock.'
                          : 'Aucun article ne correspond à ce filtre.',
                    ),
                  )
                : groupByCategory
                ? _buildCategoryGroupedStock(items)
                : _buildBento(
                    itemCount: items.length,
                    cardBuilder: (context, cardWidth, index) => _StockCard(
                      item: items[index],
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
        final unitCount = categoryItems.fold<int>(
          0,
          (sum, i) => sum + i.quantite,
        );
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
    bool mobileGrid = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1024
            ? 3
            : width >= 640 || (mobileGrid && width >= 360)
            ? 2
            : 1;
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
            _CategoryStockRow(item: items[i], onTap: () => onItemTap(items[i])),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Thumbnail(
                    item: item,
                    size: 44,
                    radius: 8,
                    enableHero: false,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
              const SizedBox(height: 10),
              _StockSegmentBar(item: item),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.badgeIndigoBg : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.dashPrimary
                  : AppColors.dashOutlineVariant,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active
                  ? AppColors.dashPrimary
                  : AppColors.dashOnSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte du catalogue (bento)
// ---------------------------------------------------------------------------

class _CatalogCard extends StatelessWidget {
  final CatalogItemModel item;
  final double cardWidth;
  final VoidCallback onTap;

  const _CatalogCard({
    required this.item,
    required this.cardWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = item.quantite;
    final rented = item.sorties;
    final damaged = item.endommages;
    final lost = item.perdus;
    final maintenance = item.entretienStock;
    final tracked = available + rented + maintenance + damaged + lost;
    final total = item.total > tracked ? item.total : tracked;

    String? statusLabel;
    Color? statusColor;
    if (item.aVerifier || damaged > 0) {
      statusLabel = 'À vérifier';
      statusColor = AppColors.danger;
    } else if (maintenance > 0) {
      statusLabel = 'En entretien';
      statusColor = AppColors.warning;
    } else if (rented > 0) {
      statusLabel = 'En location';
      statusColor = AppColors.dashPrimary;
    } else if (available <= 0 && item.entretienRequis) {
      statusLabel = 'Entretien requis';
      statusColor = AppColors.warning;
    }

    final imageTint = statusLabel == 'À vérifier'
        ? AppColors.badgeDangerBg
        : statusLabel == 'En entretien' || statusLabel == 'Entretien requis'
        ? AppColors.warningBg
        : statusLabel == 'En location'
        ? AppColors.badgeIndigoBg
        : AppColors.successBg;
    final imageHeight = (cardWidth * 0.72).clamp(110.0, 150.0).toDouble();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.photoUrl != null)
                    Image.network(
                      item.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imagePlaceholder(imageTint),
                    )
                  else
                    _imagePlaceholder(imageTint),
                  if (statusLabel != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dashOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dashOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.categorie ?? 'Sans catégorie',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.dashOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StockSegmentBar(item: item),
                  const SizedBox(height: 8),
                  Text(
                    item.stockConnu || item.total > 0
                        ? '$available / $total dispo'
                        : 'Stock non renseigné',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dashOnSurface,
                    ),
                  ),
                  if (maintenance > 0 || damaged > 0 || rented > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      maintenance > 0
                          ? '$maintenance en entretien'
                          : damaged > 0
                          ? '$damaged abîmé${damaged > 1 ? 's' : ''}'
                          : '$rented en location',
                      style: TextStyle(
                        fontSize: 11,
                        color: damaged > 0
                            ? AppColors.dangerText
                            : AppColors.warningText,
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

  Widget _imagePlaceholder(Color tint) {
    return ColoredBox(
      color: tint,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: AppColors.dashOutline,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte du stock (bento) — état détaillé
// ---------------------------------------------------------------------------

class _StockCard extends StatelessWidget {
  final CatalogItemModel item;
  final VoidCallback onTap;

  const _StockCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final maintenance = item.entretienStock;
    final tracked =
        item.quantite +
        item.sorties +
        item.endommages +
        item.perdus +
        maintenance;
    final total = item.total > tracked ? item.total : tracked;
    final (status, statusColor, statusBackground) = item.inactif
        ? ('Inactif', AppColors.badgeNeutralFg, AppColors.badgeNeutralBg)
        : item.aVerifier || item.endommages > 0
        ? ('À vérifier', AppColors.dangerText, AppColors.badgeDangerBg)
        : item.sorties > 0
        ? ('En location', AppColors.badgeIndigoFg, AppColors.badgeIndigoBg)
        : maintenance > 0
        ? ('En entretien', AppColors.warningText, AppColors.warningBg)
        : item.quantite > 0
        ? ('Disponible', AppColors.badgeAvailableFg, AppColors.badgeAvailableBg)
        : item.entretienRequis
        ? ('Entretien requis', AppColors.warningText, AppColors.warningBg)
        : !item.stockConnu
        ? ('Stock à venir', AppColors.badgeNeutralFg, AppColors.badgeNeutralBg)
        : ('Épuisé', AppColors.badgeDangerFg, AppColors.badgeDangerBg);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                          '${item.categorie ?? 'Sans catégorie'} · $total au total',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StockSegmentBar(item: item),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StockMetric(
                      label: 'Dispo',
                      value: item.quantite,
                      color: AppColors.kpiGreen,
                    ),
                  ),
                  Expanded(
                    child: _StockMetric(
                      label: 'Location',
                      value: item.sorties,
                      color: AppColors.kpiIndigo,
                    ),
                  ),
                  Expanded(
                    child: _StockMetric(
                      label: 'Entretien',
                      value: maintenance,
                      color: AppColors.kpiAmber,
                    ),
                  ),
                  Expanded(
                    child: _StockMetric(
                      label: 'Abîmés',
                      value: item.endommages,
                      color: AppColors.kpiRose,
                    ),
                  ),
                ],
              ),
              if (item.perdus > 0) ...[
                const SizedBox(height: 8),
                _StockMetric(
                  label: 'Perdus',
                  value: item.perdus,
                  color: AppColors.dashOutline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StockSegmentBar extends StatelessWidget {
  final CatalogItemModel item;

  const _StockSegmentBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final tracked =
        item.quantite +
        item.sorties +
        item.endommages +
        item.perdus +
        item.entretienStock;
    final total = item.total > tracked ? item.total : tracked;
    final maintenance = item.entretienStock;
    final remaining = (total - tracked).clamp(0, total).toInt();
    final segments = <(int, Color)>[
      if (item.quantite > 0) (item.quantite, AppColors.kpiGreen),
      if (item.sorties > 0) (item.sorties, AppColors.kpiIndigo),
      if (maintenance > 0) (maintenance, AppColors.kpiAmber),
      if (item.endommages > 0) (item.endommages, AppColors.kpiRose),
      if (item.perdus > 0) (item.perdus, AppColors.dashOutline),
      if (remaining > 0) (remaining, AppColors.dashOutline),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: double.infinity,
        height: 10,
        child: ColoredBox(
          color: AppColors.dashOutlineVariant,
          child: Row(
            children: [
              for (final (count, color) in segments)
                Expanded(
                  flex: count,
                  child: ColoredBox(color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StockMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w600,
            color: value > 0 ? color : AppColors.dashOnSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
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
