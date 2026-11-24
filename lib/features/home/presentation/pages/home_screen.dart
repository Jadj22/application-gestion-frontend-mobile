import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/animated_entrance.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/guide/guide_overlay.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../../shared/widgets/sync_status_banner.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../items/data/models/category.dart';
import '../../../items/data/models/item.dart';
import '../../../items/data/models/stock_movement.dart';
import '../../../items/presentation/pages/add_item_page.dart';
import '../../../items/presentation/pages/items_screen.dart';
import '../../../items/presentation/pages/new_category_page.dart';
import '../../../items/presentation/pages/stock_entry_page.dart';
import '../../../maintenance/presentation/pages/maintenance_screen.dart';
import '../../../reservations/presentation/pages/reservations_screen.dart';
import '../../../notifications/presentation/pages/notifications_screen.dart';
import '../../data/home_repository.dart';
import 'actions_activity_page.dart';
import 'more_page.dart';
import '../widgets/actions_journal_widgets.dart';

// ---------------------------------------------------------------------------
// HomeScreen â€” maquette Stitch Â« JoÃ«l Events & DÃ©coration Â» (accuiel.html)
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  InventoryFocus? _inventoryFocus;

  bool _loading = true;
  String? _error;
  HomeDashboard? _dashboard;

  // Cibles du guide de dÃ©marrage (onglet Plus) sur les vrais widgets du
  // dashboard â€” pas une maquette sÃ©parÃ©e.
  final _topBarKey = GlobalKey();
  final _kpiGridKey = GlobalKey();
  final _newActionKey = GlobalKey();
  final _bottomNavKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _startDashboardGuide() async {
    setState(() => _tabIndex = 0);
    // Laisse le dashboard se reconstruire avant de mesurer les widgets.
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await GuideOverlayController.start(context, [
      GuideStep(
        targetKey: _topBarKey,
        title: 'Votre tableau de bord',
        description:
            'Le nom de votre business, la recherche et vos notifications.',
      ),
      GuideStep(
        targetKey: _kpiGridKey,
        title: 'Suivi du stock en un coup d\'Å“il',
        description:
            'Total, disponible, en location, entretien... Touchez une carte '
            'pour filtrer l\'inventaire correspondant.',
      ),
      GuideStep(
        targetKey: _newActionKey,
        title: 'Nouvelle action rapide',
        description:
            'Ajoutez un article, une entrÃ©e de stock ou une catÃ©gorie en '
            'un instant.',
      ),
      GuideStep(
        targetKey: _bottomNavKey,
        title: 'Naviguez dans l\'app',
        description:
            'Inventaire, Entretien, RÃ©servations et Plus sont toujours Ã  '
            'portÃ©e de main.',
      ),
    ]);
  }

  Future<void> _load() async {
    final businessId =
        context.read<SessionController>().currentBusiness?.id;
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

  void _openInventory(InventoryFocus focus) {
    setState(() {
      _inventoryFocus = focus;
      _tabIndex = 1;
    });
  }

  void _openActionsPage({bool journal = false}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActionsActivityPage(initialJournalTab: journal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashSurfaceLow,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: switch (_tabIndex) {
            0 => _buildDashboard(),
            1 => ItemsScreen(
                key: ValueKey('tab-inventory-${_inventoryFocus ?? "all"}'),
                showBottomNav: false,
                focus: _inventoryFocus,
              ),
            2 => const MaintenanceScreen(
                key: ValueKey('tab-maintenance'),
                showBottomNav: false,
              ),
            3 => const ReservationsScreen(
                key: ValueKey('tab-reservations'),
                showBottomNav: false,
              ),
            _ => MorePage(
                key: const ValueKey('tab-more'),
                onStartGuide: _startDashboardGuide,
              ),
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        key: _bottomNavKey,
        currentIndex: _tabIndex,
        onTap: (index) {
          setState(() {
            if (index == 1) _inventoryFocus = null;
            _tabIndex = index;
          });
        },
      ),
    );
  }

  Future<void> _openAddItem() async {
    final canAdd = context.read<SessionController>().can('item.edit');
    if (!canAdd) {
      _showPermissionDenied('gÃ©rer les articles');
      return;
    }
    final created = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(builder: (_) => const AddItemPage()),
    );
    if (created != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Â« ${created.nom} Â» a Ã©tÃ© ajoutÃ© au catalogue.')),
      );
    }
  }

  Future<void> _openStockEntry() async {
    final canMove = context.read<SessionController>().can('stock.mouvement');
    if (!canMove) {
      _showPermissionDenied('gÃ©rer le stock');
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
            '+${movement.quantite} Â« ${movement.itemNom} Â» ajoutÃ© au stock.',
          ),
        ),
      );
    }
  }

  Future<void> _openNewCategory() async {
    final canManage = context.read<SessionController>().can('catalog.manage');
    if (!canManage) {
      _showPermissionDenied('gÃ©rer le catalogue');
      return;
    }
    final category = await Navigator.of(context).push<CategoryModel>(
      MaterialPageRoute(builder: (_) => const NewCategoryPage()),
    );
    if (category != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La catÃ©gorie Â« ${category.nom} Â» a Ã©tÃ© crÃ©Ã©e.'),
        ),
      );
    }
  }

  void _showPermissionDenied(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vous n\'avez pas la permission de $action.')),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouvelle action', style: AppTextStyles.h2),
              const SizedBox(height: 16),
              _QuickActionTile(
                icon: Icons.add_box_outlined,
                label: 'Ajouter un article',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openAddItem();
                },
              ),
              _QuickActionTile(
                icon: Icons.add_circle_outline,
                label: 'Nouvelle entre de stock',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openStockEntry();
                },
              ),
              _QuickActionTile(
                icon: Icons.category_outlined,
                label: 'Nouvelle catégorie',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openNewCategory();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final businessName =
        context.watch<SessionController>().currentBusiness?.nom ??
            'JoÃ«l Events & DÃ©coration';

    return Column(
      children: [
        _DashboardTopBar(key: _topBarKey, businessName: businessName),
        const SyncStatusBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.dashSecondary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OperationalHeader(
                    onNewAction: _showQuickActions,
                    actionButtonKey: _newActionKey,
                  ),
                  const SizedBox(height: 24),
                  if (_dashboard == null)
                    _LoadingOrError(
                      loading: _loading,
                      error: _error,
                      onRetry: _load,
                    )
                  else ...[
                    _KpiGrid(
                      key: _kpiGridKey,
                      dashboard: _dashboard!,
                      onFilterTap: _openInventory,
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 720;
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ActionsTodoList(
                                  actions: _dashboard!.actions,
                                  maxItems: 6,
                                  onSeeAll: () => _openActionsPage(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ActivityJournalList(
                                  activities: _dashboard!.activities,
                                  maxItems: 6,
                                  onSeeAll: () => _openActionsPage(journal: true),
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            ActionsTodoList(
                              actions: _dashboard!.actions,
                              maxItems: 6,
                              onSeeAll: () => _openActionsPage(),
                            ),
                            const SizedBox(height: 24),
                            ActivityJournalList(
                              activities: _dashboard!.activities,
                              maxItems: 6,
                              onSeeAll: () => _openActionsPage(journal: true),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}

// ---------------------------------------------------------------------------
// Top App Bar
// ---------------------------------------------------------------------------

class _DashboardTopBar extends StatelessWidget {
  final String businessName;

  const _DashboardTopBar({super.key, required this.businessName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppColors.dashSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.dashOutlineVariant, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // â”€â”€ Logo badge D â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.dashPrimary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Georgia',
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // â”€â”€ Nom du business â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dashOnSurface,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                const Text(
                  'Tableau de bord',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dashOnSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // â”€â”€ Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recherche â€” bientÃ´t disponible')),
              );
            },
            icon: const Icon(
              Icons.search_rounded,
              color: AppColors.dashOnSurface,
              size: 22,
            ),
            tooltip: 'Rechercher',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.dashOnSurface,
              size: 22,
            ),
            tooltip: 'Notifications',
          ),
        ],
      ),
    );
}
}

// ---------------------------------------------------------------------------
// En-tÃªte opÃ©rationnel
// ---------------------------------------------------------------------------

class _OperationalHeader extends StatelessWidget {
  final VoidCallback onNewAction;
  final Key? actionButtonKey;

  const _OperationalHeader({required this.onNewAction, this.actionButtonKey});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 480;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dashOnSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Vue d\'ensemble',
              style: AppTextStyles.h1.copyWith(
                fontSize: 22,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Inventaire & tâches en temps réel.',
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.dashOnSurfaceVariant,
              ),
            ),
          ],
        );

        final actionBtn = FilledButton.icon(
          key: actionButtonKey,
          onPressed: onNewAction,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.dashPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Nouvelle action'),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 16), actionBtn],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actionBtn,
          ],
        );
      },
);
    }
  }


// ---------------------------------------------------------------------------
// Grille KPI (6 cartes)
// ---------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  final HomeDashboard dashboard;
  final ValueChanged<InventoryFocus> onFilterTap;

  const _KpiGrid({
    super.key,
    required this.dashboard,
    required this.onFilterTap,
  });

  String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
                ? 3
                : 2;

        final cards = [
          _KpiCard(
            label: 'Total',
            value: _fmt(dashboard.totalStock),
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.dashOutline,
            onTap: () => onFilterTap(InventoryFocus.total),
          ),
          _KpiCard(
            label: 'Disponible',
            value: _fmt(dashboard.disponibleCount),
            icon: Icons.check_circle,
            iconColor: AppColors.kpiGreen,
            badgeLabel: 'PrÃªt',
            badgeColor: AppColors.kpiGreen,
            onTap: () => onFilterTap(InventoryFocus.disponible),
          ),
          _KpiCard(
            label: 'En Location',
            value: _fmt(dashboard.enLocationCount),
            icon: Icons.local_shipping_outlined,
            iconColor: AppColors.kpiIndigo,
            badgeLabel: 'DÃ©ployÃ©',
            badgeColor: AppColors.kpiIndigo,
            onTap: () => onFilterTap(InventoryFocus.location),
          ),
          _KpiCard(
            label: 'Entretien',
            value: _fmt(dashboard.entretienCount),
            icon: Icons.build_outlined,
            iconColor: AppColors.kpiAmber,
            badgeLabel: 'En Réparation',
            badgeColor: AppColors.kpiAmber,
            onTap: () => onFilterTap(InventoryFocus.entretien),
          ),
          _KpiCard(
            label: 'Endommagé',
            value: _fmt(dashboard.endommageCount),
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.kpiRose,
            badgeLabel: 'Action Req',
            badgeColor: AppColors.kpiRose,
            valueColor: AppColors.kpiRose,
            onTap: () => onFilterTap(InventoryFocus.endommage),
          ),
          _KpiCard(
            label: 'À Vérifier',
            value: _fmt(dashboard.aVerifierTotal),
            icon: Icons.fact_check_outlined,
            iconColor: AppColors.kpiBlue,
            badgeLabel: 'En Attente',
            badgeColor: AppColors.kpiBlue,
            onTap: () => onFilterTap(InventoryFocus.verifier),
          ),
        ];

        // Ratio adaptatif : les écrans mobiles (<600) ont besoin d'assez de hauteur
        // pour loger l'icône, la valeur, le label et le badge sans overflow.
        final double ratio = cols == 2
            ? (constraints.maxWidth < 360 ? 1.05 : 1.15)
            : 1.4;

        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: ratio,
          children: [
            for (var i = 0; i < cards.length; i++)
              AnimatedEntrance(
                delay: Duration(milliseconds: 60 * i),
                duration: const Duration(milliseconds: 400),
                child: cards[i],
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color? valueColor;
  final VoidCallback onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeLabel,
    this.badgeColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withValues(alpha: 0.06),
        highlightColor: iconColor.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Icône dans un container coloré ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppColors.dashOutline,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── Valeur numérique, label & badge ─────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: valueColor ?? AppColors.dashOnSurface,
                          letterSpacing: -0.8,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.dashOnSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                    if (badgeLabel != null && badgeColor != null) ...[
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: badgeColor!.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeLabel!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
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


// ---------------------------------------------------------------------------
// Ã‰lÃ©ments partagÃ©s
// ---------------------------------------------------------------------------


class _LoadingOrError extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const _LoadingOrError({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Skeleton(
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
              children: List.generate(
                4,
                (_) => const SkeletonCard(
                  radius: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonCircle(size: 22),
                      Spacer(),
                      SkeletonText(width: 60, height: 22),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SkeletonCard(child: SkeletonListItem()),
            const SizedBox(height: 8),
            const SkeletonCard(child: SkeletonListItem()),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppColors.dashOutline),
          const SizedBox(height: 12),
          Text(
            error ?? 'Impossible de charger les données.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.dashSurfaceLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dashOutlineVariant),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.dashPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dashOnSurface,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.dashOutline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


