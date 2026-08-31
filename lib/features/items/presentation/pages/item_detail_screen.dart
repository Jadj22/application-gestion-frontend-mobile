import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../../maintenance/data/maintenance_repository.dart';
import '../../../maintenance/data/models/maintenance_task.dart';
import '../../../maintenance/presentation/pages/new_task_page.dart';
import '../../data/items_repository.dart';
import '../../data/models/item.dart';
import '../../data/models/item_detail.dart';
import '../../data/models/stock_movement.dart';
import '../widgets/qr_code_widget.dart';
import 'add_item_page.dart';
import 'stock_entry_page.dart';

/// Fiche article détaillée — maquette « Logistics Manager - Detailed Item View ».
class ItemDetailScreen extends StatefulWidget {
  final String itemId;
  final String? initialNom;

  const ItemDetailScreen({super.key, required this.itemId, this.initialNom});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen>
    with SingleTickerProviderStateMixin {
  late final ItemsRepository _repository;
  late final MaintenanceRepository _maintenanceRepository;
  late final Business _business;
  late final SessionController _session;
  late final TabController _tabController;

  ItemDetailModel? _item;
  bool _loading = true;
  String? _error;

  List<StockMovementModel> _history = const [];
  List<MaintenanceTaskModel> _maintenanceTasks = const [];
  bool _loadingHistory = false;
  bool _loadingMaintenance = false;
  bool _historyLoaded = false;
  bool _maintenanceLoaded = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _maintenanceRepository = context.read<MaintenanceRepository>();
    _session = context.read<SessionController>();
    _business = _session.currentBusiness!;
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 2) _loadHistory();
    if (_tabController.index == 3) _loadMaintenance();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await _repository.detail(_business.id, widget.itemId);
      if (mounted) setState(() => _item = item);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadAll() async {
    _historyLoaded = false;
    _maintenanceLoaded = false;
    _history = const [];
    _maintenanceTasks = const [];
    await _load();
    if (_tabController.index == 2) await _loadHistory(force: true);
    if (_tabController.index == 3) await _loadMaintenance(force: true);
  }

  Future<void> _loadHistory({bool force = false}) async {
    if (_loadingHistory || (_historyLoaded && !force)) return;
    setState(() => _loadingHistory = true);
    try {
      final history =
          await _repository.history(_business.id, widget.itemId);
      if (mounted) {
        setState(() {
          _history = history;
          _historyLoaded = true;
        });
      }
    } on ApiException {
      // L'historique reste vide en cas d'échec.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadMaintenance({bool force = false}) async {
    if (_loadingMaintenance || (_maintenanceLoaded && !force)) return;
    setState(() => _loadingMaintenance = true);
    try {
      final tasks = await _maintenanceRepository.tasks(_business.id);
      if (mounted) {
        setState(() {
          _maintenanceTasks =
              tasks.where((t) => t.itemId == widget.itemId).toList();
          _maintenanceLoaded = true;
        });
      }
    } on ApiException {
      // Liste vide en cas d'échec.
    } finally {
      if (mounted) setState(() => _loadingMaintenance = false);
    }
  }

  bool get _canMoveStock => _session.can('stock.mouvement');

  void _requireStockPermission(VoidCallback action) {
    if (!_canMoveStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas la permission de gérer le stock.'),
        ),
      );
      return;
    }
    action();
  }

  Future<void> _openEntry() async {
    _requireStockPermission(() async {
      final movement = await Navigator.of(context).push<StockMovementModel>(
        MaterialPageRoute(
          builder: (_) => StockEntryPage(preselectedItemId: widget.itemId),
        ),
      );
      if (movement != null && mounted) {
        await _reloadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+${movement.quantite} unité${movement.quantite > 1 ? 's' : ''} ajoutée${movement.quantite > 1 ? 's' : ''}.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _openMovementDialog(String type, String label) async {
    _requireStockPermission(() async {
      final quantite = await showDialog<int>(
        context: context,
        builder: (ctx) => _MovementQuantityDialog(label: label),
      );
      if (quantite == null || !mounted) return;
      try {
        await _repository.createStockMovement(
          _business.id,
          type: type,
          itemId: widget.itemId,
          quantite: quantite,
        );
        if (mounted) {
          await _reloadAll();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label enregistrée.')),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    });
  }

  Future<void> _editItem() async {
    final item = _item;
    if (item == null) return;
    final updated = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(
        builder: (_) => AddItemPage(
          existing: ItemModel(
            id: item.id,
            nom: item.nom,
            reference: item.ref.isEmpty ? null : item.ref,
            description: item.description,
            prix: item.prix,
            unite: item.unite,
            statut: item.statut,
            entretienRequis: item.entretienRequis,
            categoryId: item.categoryId,
          ),
        ),
      ),
    );
    if (updated != null && mounted) {
      await _reloadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${updated.nom} » a été modifié.')),
      );
    }
  }

  Future<void> _createMaintenanceTask() async {
    if (!_session.can('entretien.manage')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas la permission de gérer l\'entretien.'),
        ),
      );
      return;
    }
    final task = await Navigator.of(context).push<MaintenanceTaskModel>(
      MaterialPageRoute(
        builder: (_) => NewTaskPage(preselectedItemId: widget.itemId),
      ),
    );
    if (task != null && mounted) {
      // Recharger les taches si sur l'onglet maintenance
      _maintenanceLoaded = false;
      if (_tabController.index == 3) {
        await _loadMaintenance(force: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tache d\'entretien creee.')),
      );
    }
  }

  /// Creation rapide en 1 clic avec la procedure par defaut
  Future<void> _quickCreateTask() async {
    if (!_session.can('entretien.manage')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas la permission de gerer l\'entretien.'),
        ),
      );
      return;
    }

    // Confirmation rapide
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Creer une tache ?'),
        content: Text(
          'Une tache d\'entretien sera creee pour « ${_item?.nom ?? "cet article"} » '
          'avec la procedure par defaut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dashPrimary,
            ),
            child: const Text('Creer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _maintenanceRepository.createTask(
        _business.id,
        itemId: widget.itemId,
        // Pas de procedureId = utilise la procedure par defaut
      );

      _maintenanceLoaded = false;
      if (_tabController.index == 3) {
        await _loadMaintenance(force: true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tache d\'entretien creee avec succes !'),
            backgroundColor: AppColors.kpiGreen,
          ),
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

  void _showQrCode() {
    final item = _item;
    if (item == null || item.qrCode == null) return;

    QrCodeDialog.show(
      context,
      qrCode: item.qrCode!,
      itemName: item.nom,
      reference: item.ref.isEmpty ? null : item.ref,
    );
  }

  Future<void> _deleteItem() async {
    if (!_session.can('catalog.manage')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous n\'avez pas la permission de gérer le catalogue.'),
        ),
      );
      return;
    }
    final item = _item;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l\'article ?'),
        content: Text(
          '« ${item.nom} » sera retiré du catalogue. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.dangerText),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.delete(_business.id, item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('« ${item.nom} » a été supprimé.')),
        );
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashSurface,
      appBar: AppBar(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dashPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.initialNom ?? _item?.nom ?? 'Inventaire',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_item != null) ...[
            if (_item!.qrCode != null && _item!.qrCode!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.qr_code_2, color: AppColors.dashPrimary),
                tooltip: 'QR Code',
                onPressed: _showQrCode,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.dashPrimary),
              tooltip: 'Modifier',
              onPressed: _editItem,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.dangerText),
              tooltip: 'Supprimer',
              onPressed: _deleteItem,
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? _buildLoadingSkeleton()
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : _buildContent(),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            const labels = [
              'Dashboard',
              'Inventaire',
              'Entretien',
              'Réservations',
              'Plus',
            ];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('« ${labels[index]} » arrive bientôt')),
            );
            return;
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonBox(height: 220, borderRadius: BorderRadius.all(Radius.circular(24))),
            const SizedBox(height: 16),
            const SkeletonText(width: 180, height: 20),
            const SizedBox(height: 8),
            const SkeletonText(width: 120, height: 14),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(child: SkeletonCard(radius: 16, child: SkeletonText(width: 40, height: 22))),
                SizedBox(width: 12),
                Expanded(child: SkeletonCard(radius: 16, child: SkeletonText(width: 40, height: 22))),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonCard(child: SkeletonListItem()),
            const SizedBox(height: 10),
            const SkeletonCard(child: SkeletonListItem()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final item = _item!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 768;
        final padding = wide ? 32.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _reloadAll,
          color: AppColors.dashSecondary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 16, padding, 96),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildLeftColumn(item)),
                      const SizedBox(width: 24),
                      Expanded(flex: 8, child: _buildRightColumn(item)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeftColumn(item),
                      const SizedBox(height: 24),
                      _buildRightColumn(item),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Colonne gauche : photo, alerte, actions
  // ---------------------------------------------------------------------------

  Widget _buildLeftColumn(ItemDetailModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImageCard(item),
        if (item.entretienRequis == true) ...[
          const SizedBox(height: 16),
          _MaintenanceWarningBox(item: item),
        ],
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildImageCard(ItemDetailModel item) {
    final category = item.categorie ?? '—';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: item.photoUrl != null
                ? Hero(
                    tag: 'item-photo-${widget.itemId}',
                    child: Image.network(
                      item.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imageFallback(),
                    ),
                  )
                : _imageFallback(),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nom,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dashPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.dashOnSurfaceVariant,
                  ),
                ),
                if (item.ref.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Réf. ${item.ref}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dashOutline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.dashSurfaceLow,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 72,
        color: AppColors.dashOutline,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _ActionButton(
          label: 'Entrée',
          icon: Icons.add,
          primary: true,
          onTap: _openEntry,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: [
            _ActionButton(
              label: 'Sortie',
              icon: Icons.outbound,
              onTap: () => _openMovementDialog('SORTIE', 'Sortie'),
            ),
            _ActionButton(
              label: 'Retour',
              icon: Icons.keyboard_return,
              onTap: () => _openMovementDialog('RETOUR', 'Retour'),
            ),
            _ActionButton(
              label: 'Dommage',
              icon: Icons.broken_image_outlined,
              danger: true,
              onTap: () => _openMovementDialog('DOMMAGE', 'Dommage'),
            ),
            _ActionButton(
              label: 'Ajustement',
              icon: Icons.tune,
              onTap: () => _openMovementDialog('AJUSTEMENT', 'Ajustement'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Section Entretien
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.kpiAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.kpiAmber.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.build_outlined, size: 16, color: AppColors.kpiAmber),
                  const SizedBox(width: 6),
                  const Text(
                    'ENTRETIEN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.kpiAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Bouton rapide 1 clic
              _ActionButton(
                label: 'Entretien rapide',
                icon: Icons.flash_on,
                primary: true,
                onTap: _quickCreateTask,
              ),
              const SizedBox(height: 6),
              // Bouton avec options
              _ActionButton(
                label: 'Choisir une procedure...',
                icon: Icons.list_alt_outlined,
                onTap: _createMaintenanceTask,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Colonne droite : distribution + onglets
  // ---------------------------------------------------------------------------

  Widget _buildRightColumn(ItemDetailModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DistributionGrid(item: item),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: AppColors.dashOutlineVariant,
          indicatorColor: AppColors.dashPrimary,
          indicatorWeight: 2,
          labelColor: AppColors.dashPrimary,
          unselectedLabelColor: AppColors.dashOnSurfaceVariant,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Résumé'),
            Tab(text: 'Stock'),
            Tab(text: 'Historique'),
            Tab(text: 'Entretien'),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => switch (_tabController.index) {
            0 => _SummaryTab(item: item),
            1 => _StockTab(item: item),
            2 => _HistoryTab(
                history: _history,
                loading: _loadingHistory,
              ),
            _ => _MaintenanceTab(
                tasks: _maintenanceTasks,
                loading: _loadingMaintenance,
              ),
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grille de distribution (6 KPI)
// ---------------------------------------------------------------------------

class _DistributionGrid extends StatelessWidget {
  final ItemDetailModel item;

  const _DistributionGrid({required this.item});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Total', item.total, AppColors.dashPrimary),
      ('Dispo', item.disponibles, AppColors.kpiGreen),
      ('Location', item.sorties, AppColors.kpiIndigo),
      ('Entretien', item.entretienStock, AppColors.kpiAmber),
      ('Endommagé', item.endommages, AppColors.kpiRose),
      ('À vérifier', item.verifierStock, AppColors.kpiBlue),
    ];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth >= 480 ? 6 : 3;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: cols == 6 ? 1.1 : 1.3,
            children: [
              for (final (label, value, color) in stats)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: label == 'Total'
                            ? AppColors.dashOnSurfaceVariant
                            : color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alerte maintenance
// ---------------------------------------------------------------------------

class _MaintenanceWarningBox extends StatelessWidget {
  final ItemDetailModel item;

  const _MaintenanceWarningBox({required this.item});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFF8F00);
    const amberBg = Color(0xFFFFF8E1);
    const amberBorder = Color(0xFFFFE082);
    return Container(
      decoration: BoxDecoration(
        color: amberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amberBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: const Color(0xFFFFB300)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: amber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'MAINTENANCE REQUIS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.etatEntretien != '—'
                      ? 'État : ${item.etatEntretien}'
                      : 'Entretien requis pour cet article.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.dashOnSurfaceVariant,
                  ),
                ),
                if (item.updatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Dernière mise à jour : ${_formatDate(item.updatedAt!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.dashOnSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Utilisation enregistrée malgré l\'avertissement.'),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dashPrimary,
                      side: const BorderSide(color: AppColors.dashOutlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Utiliser malgré l\'avertissement',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  const months = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  const months = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  final hour = parsed.hour;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}, '
      '$h12:${two(parsed.minute)} $ampm';
}

// ---------------------------------------------------------------------------
// Boutons d'action stock
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return Material(
        color: AppColors.dashPrimary,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: danger ? AppColors.dangerText : AppColors.dashPrimary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: danger ? AppColors.dangerText : AppColors.dashPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Résumé
// ---------------------------------------------------------------------------

class _SummaryTab extends StatelessWidget {
  final ItemDetailModel item;

  const _SummaryTab({required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (item.categorie != null && item.categorie != '—')
        ('Catégorie', item.categorie!),
      if (item.ref.isNotEmpty) ('Référence', item.ref),
      if (item.unite.isNotEmpty) ('Unité', item.unite),
      if (item.prix > 0) ('Prix', '${item.prix.toStringAsFixed(0)} FCFA'),
      ('Statut', item.statut == 'INACTIF' ? 'Inactif' : 'Actif'),
      ('Condition', item.conditionLabel),
      ...item.characteristics.entries
          .where((e) => e.value != null)
          .map((e) => (e.key, '${e.value}')),
      if (item.createdAt != null)
        ('Ajouté le', _formatDate(item.createdAt!)),
    ];
    return _Panel(
      child: item.description.isEmpty && rows.isEmpty
          ? const _EmptyPanel(
              icon: Icons.description_outlined,
              message: 'Aucune information complémentaire.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.description.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.dashOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.dashOnSurface,
                      height: 1.5,
                    ),
                  ),
                  if (rows.isNotEmpty) const SizedBox(height: 20),
                ],
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 24, color: AppColors.dashOutlineVariant),
                  _SpecRow(label: rows[i].$1, value: rows[i].$2),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Stock
// ---------------------------------------------------------------------------

class _StockTab extends StatelessWidget {
  final ItemDetailModel item;

  const _StockTab({required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Total en stock', item.total, AppColors.dashPrimary),
      ('Disponibles', item.disponibles, AppColors.kpiGreen),
      ('En location', item.sorties, AppColors.kpiIndigo),
      ('En entretien', item.entretienStock, AppColors.kpiAmber),
      ('Endommagés', item.endommages, AppColors.kpiRose),
      ('Perdus', item.perdus, AppColors.dashOnSurfaceVariant),
      ('À vérifier', item.verifierStock, AppColors.kpiBlue),
    ];
    return _Panel(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.dashOutlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.dashOnSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${rows[i].$2}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: rows[i].$3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Historique (timeline)
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  final List<StockMovementModel> history;
  final bool loading;

  const _HistoryTab({required this.history, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _Panel(
        child: Skeleton(
          child: Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i == 3 ? 0 : 10),
                child: const SkeletonListItem(),
              ),
            ),
          ),
        ),
      );
    }
    if (history.isEmpty) {
      return const _Panel(
        child: _EmptyPanel(
          icon: Icons.history,
          message: 'Aucun mouvement enregistré pour le moment.',
        ),
      );
    }
    return _Panel(
      child: _HistoryTimeline(history: history),
    );
  }
}

class _HistoryTimeline extends StatelessWidget {
  final List<StockMovementModel> history;

  const _HistoryTimeline({required this.history});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 11,
          top: 8,
          bottom: 8,
          child: Container(
            width: 2,
            color: AppColors.dashOutlineVariant,
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < history.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i < history.length - 1 ? 24 : 0),
                child: _TimelineEntry(movement: history[i]),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final StockMovementModel movement;

  const _TimelineEntry({required this.movement});

  (IconData icon, Color color, String? delta) get _meta {
    switch (movement.type) {
      case 'ENTREE':
        return (Icons.add_circle, AppColors.kpiGreen, '+${movement.quantite}');
      case 'SORTIE':
        return (Icons.outbound, AppColors.kpiIndigo, '-${movement.quantite}');
      case 'RETOUR':
        return (Icons.keyboard_return, AppColors.kpiGreen, '+${movement.quantite}');
      case 'DOMMAGE':
        return (Icons.broken_image_outlined, AppColors.kpiRose, '-${movement.quantite}');
      case 'PERTE':
        return (Icons.highlight_off, AppColors.kpiRose, '-${movement.quantite}');
      case 'AJUSTEMENT':
        return (Icons.tune, AppColors.kpiAmber, '${movement.quantite}');
      default:
        return (Icons.swap_vert, AppColors.dashOutline, '${movement.quantite}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, delta) = _meta;
    final isStatusUpdate = movement.type == 'AJUSTEMENT' &&
        movement.quantite == 0; // fallback label
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.dashOutlineVariant, width: 2),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.typeLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dashPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(movement.date),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.dashOnSurfaceVariant,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (movement.motif.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  movement.motif,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.dashOutline,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          isStatusUpdate ? 'Mise à jour' : (delta ?? ''),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isStatusUpdate ? AppColors.dashOnSurfaceVariant : color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Entretien
// ---------------------------------------------------------------------------

class _MaintenanceTab extends StatelessWidget {
  final List<MaintenanceTaskModel> tasks;
  final bool loading;

  const _MaintenanceTab({required this.tasks, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _Panel(
        child: Skeleton(
          child: Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i == 3 ? 0 : 10),
                child: const SkeletonListItem(),
              ),
            ),
          ),
        ),
      );
    }
    if (tasks.isEmpty) {
      return const _Panel(
        child: _EmptyPanel(
          icon: Icons.build_outlined,
          message: 'Aucune tâche d\'entretien pour cet article.',
        ),
      );
    }
    return _Panel(
      child: Column(
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.dashOutlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.kpiAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.build,
                      size: 18,
                      color: AppColors.kpiAmber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tasks[i].procedureNom.isNotEmpty
                              ? tasks[i].procedureNom
                              : 'Entretien',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dashPrimary,
                          ),
                        ),
                        if (tasks[i].motif.isNotEmpty)
                          Text(
                            tasks[i].motif,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.dashOnSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tasks[i].statutLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tasks[i].estEnCours
                              ? AppColors.kpiAmber
                              : AppColors.kpiGreen,
                        ),
                      ),
                      if (tasks[i].etapesTotal > 0)
                        Text(
                          '${tasks[i].etapesFaites}/${tasks[i].etapesTotal} étapes',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.dashOutline,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets partagés
// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: child,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyPanel({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.dashOutline),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.dashOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.dashOnSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.dashOnSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _MovementQuantityDialog extends StatefulWidget {
  final String label;

  const _MovementQuantityDialog({required this.label});

  @override
  State<_MovementQuantityDialog> createState() =>
      _MovementQuantityDialogState();
}

class _MovementQuantityDialogState extends State<_MovementQuantityDialog> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Quantité',
          hintText: '1',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(_controller.text.trim());
            if (n == null || n <= 0) return;
            Navigator.of(context).pop(n);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.dashPrimary,
          ),
          child: const Text('Confirmer'),
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
          const Icon(Icons.cloud_off, size: 48, color: AppColors.dashOutline),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.dashOnSurfaceVariant),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
