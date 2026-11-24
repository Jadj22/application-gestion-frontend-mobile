import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/guide/guide_overlay.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../../shared/widgets/sync_status_banner.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../items/presentation/pages/items_screen.dart';
import '../../../maintenance/presentation/pages/maintenance_screen.dart';
import '../../../notifications/presentation/pages/notifications_screen.dart';
import '../../../reservations/data/models/reservation.dart';
import '../../../reservations/data/reservations_repository.dart';
import '../../../reservations/presentation/pages/reservation_page.dart';
import '../../../reservations/presentation/pages/reservations_screen.dart';
import '../../data/home_repository.dart';
import '../widgets/availability_card.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_actions.dart';
import '../widgets/tasks_section.dart';
import '../widgets/upcoming_reservations.dart';
import 'actions_activity_page.dart';
import 'more_page.dart';

/// Accueil / Dashboard — refonte alignée sur la maquette Stitch « Test déco ».
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
  List<ReservationModel> _reservations = [];

  final _headerKey = GlobalKey();
  final _availabilityKey = GlobalKey();
  final _quickActionsKey = GlobalKey();
  final _bottomNavKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _startDashboardGuide() async {
    setState(() => _tabIndex = 0);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await GuideOverlayController.start(context, [
      GuideStep(
        targetKey: _headerKey,
        title: 'Votre tableau de bord',
        description:
            'Le nom de votre business, la recherche et vos notifications.',
      ),
      GuideStep(
        targetKey: _availabilityKey,
        title: 'Disponibilité en un coup d\'œil',
        description:
            'Stock disponible, en location, entretien et matériel abîmé. '
            'Touchez un indicateur pour filtrer l\'inventaire.',
      ),
      GuideStep(
        targetKey: _quickActionsKey,
        title: 'Actions rapides',
        description:
            'Réservez, ouvrez le catalogue, l\'entretien ou votre vitrine.',
      ),
      GuideStep(
        targetKey: _bottomNavKey,
        title: 'Naviguez dans l\'app',
        description:
            'Inventaire, Réservations, Entretien et Plus sont toujours à '
            'portée de main.',
      ),
    ]);
  }

  Future<void> _load() async {
    final session = context.read<SessionController>();
    final homeRepo = context.read<HomeRepository>();
    final reservationsRepo = context.read<ReservationsRepository>();
    final businessId = session.currentBusiness?.id;
    if (businessId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Aucune entreprise active n’est sélectionnée.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await homeRepo.load(businessId);
      List<ReservationModel> resas = [];
      try {
        resas = await reservationsRepo.reservations(businessId);
      } catch (_) {
        // Réservations optionnelles pour les blocs À traiter / À venir.
      }
      if (mounted) {
        setState(() {
          _dashboard = data;
          _reservations = resas;
        });
      }
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

  void _openTab(int index) {
    setState(() {
      if (index == 1) _inventoryFocus = null;
      _tabIndex = index;
    });
  }

  void _openActionsPage({bool journal = false}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActionsActivityPage(initialJournalTab: journal),
      ),
    );
  }

  Future<void> _openNewReservation() async {
    final created = await Navigator.of(context).push<ReservationModel>(
      MaterialPageRoute(builder: (_) => const ReservationPage()),
    );
    if (created != null && mounted) _load();
  }

  Future<void> _openReservation(ReservationModel reservation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReservationPage(
          isDetailMode: true,
          reservationId: reservation.id,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openShowcase() async {
    final slug = context.read<SessionController>().currentBusiness?.slug ?? '';
    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun lien vitrine disponible.')),
      );
      return;
    }
    final url = '${AppConfig.webBaseUrl}/b/$slug';
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la vitrine.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  List<ReservationModel> get _upcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = _reservations.where((r) {
      if (r.estAnnulee || r.estTerminee) return false;
      final date = r.dateDebut ?? r.livraisonPrevueLe;
      if (date == null) return r.estValidee || r.estEnAttente || r.estEnCours;
      final day = DateTime(date.year, date.month, date.day);
      return !day.isBefore(today);
    }).toList();
    list.sort((a, b) {
      final da = a.dateDebut ?? a.livraisonPrevueLe ?? DateTime(2100);
      final db = b.dateDebut ?? b.livraisonPrevueLe ?? DateTime(2100);
      return da.compareTo(db);
    });
    return list;
  }

  List<HomeTaskItem> _buildTasks(HomeDashboard dashboard) {
    final tasks = <HomeTaskItem>[];
    final pending = _reservations.where((r) => r.estEnAttente).toList()
      ..sort((a, b) {
        final da = a.dateDebut ?? DateTime(2100);
        final db = b.dateDebut ?? DateTime(2100);
        return da.compareTo(db);
      });

    for (final r in pending.take(2)) {
      final date = r.dateDebut;
      final subtitleParts = <String>[];
      if (r.motif.trim().isNotEmpty) {
        subtitleParts.add(r.motif.trim());
      } else if (r.itemNom.isNotEmpty) {
        subtitleParts.add(r.itemNom);
      }
      if (date != null) subtitleParts.add(_shortDate(date));
      tasks.add(
        HomeTaskItem(
          id: 'resa-${r.id}',
          kind: HomeTaskKind.reservation,
          title: 'Réservation à valider',
          subtitle: subtitleParts.isEmpty
              ? 'En attente de confirmation'
              : subtitleParts.join(' · '),
          priority: 3,
          onTap: () => _openReservation(r),
        ),
      );
    }

    if (dashboard.endommageCount > 0) {
      HomeAlert? alert;
      for (final a in dashboard.alerts) {
        if (a.code.contains('DOMMAGE') || a.mode == 'BLOCAGE') {
          alert = a;
          break;
        }
      }
      tasks.add(
        HomeTaskItem(
          id: 'damaged',
          kind: HomeTaskKind.damaged,
          title: dashboard.endommageCount == 1
              ? '1 unité abîmée'
              : '${dashboard.endommageCount} unités abîmées',
          subtitle: alert != null && alert.itemNom.isNotEmpty
              ? '${alert.itemNom} · à vérifier'
              : 'Matériel à vérifier',
          priority: 2,
          onTap: () => _openInventory(InventoryFocus.endommage),
        ),
      );
    }

    if (dashboard.entretienCount > 0) {
      HomeAlert? alert;
      for (final a in dashboard.alerts) {
        if (a.code.contains('ENTRETIEN') || a.code.contains('A_VERIFIER')) {
          alert = a;
          break;
        }
      }
      tasks.add(
        HomeTaskItem(
          id: 'entretien',
          kind: HomeTaskKind.maintenance,
          title: 'Entretien en cours',
          subtitle: alert != null && alert.itemNom.isNotEmpty
              ? alert.itemNom
              : '${dashboard.entretienCount} article${dashboard.entretienCount > 1 ? 's' : ''} concerné${dashboard.entretienCount > 1 ? 's' : ''}',
          priority: 1,
          onTap: () => _openTab(3),
        ),
      );
    }

    if (dashboard.aVerifierTotal > 0 &&
        !tasks.any((t) => t.kind == HomeTaskKind.damaged)) {
      tasks.add(
        HomeTaskItem(
          id: 'verifier',
          kind: HomeTaskKind.other,
          title: dashboard.aVerifierTotal == 1
              ? 'Article à vérifier'
              : '${dashboard.aVerifierTotal} articles à vérifier',
          subtitle: dashboard.inventaireActif
              ? 'Inventaire en cours'
              : 'Contrôle qualité requis',
          priority: 1,
          onTap: () => _openInventory(InventoryFocus.verifier),
        ),
      );
    }

    tasks.sort((a, b) => b.priority.compareTo(a.priority));
    return tasks.take(5).toList();
  }

  String _shortDate(DateTime date) {
    const months = [
      'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  int get _pointsATraiter {
    final d = _dashboard;
    if (d == null) return 0;
    return d.reservationsEnAttente +
        (d.endommageCount > 0 ? 1 : 0) +
        (d.entretienCount > 0 ? 1 : 0) +
        (d.aVerifierTotal > 0 ? 1 : 0) +
        d.conflitsReservation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            2 => const ReservationsScreen(
                key: ValueKey('tab-reservations'),
                showBottomNav: false,
              ),
            3 => const MaintenanceScreen(
                key: ValueKey('tab-maintenance'),
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
        onTap: _openTab,
      ),
    );
  }

  Widget _buildDashboard() {
    final session = context.watch<SessionController>();
    final businessName = session.currentBusiness?.nom ?? 'Mon espace';
    final userName = session.user?.firstName.isNotEmpty == true
        ? session.user!.firstName
        : (session.user?.displayName.split(' ').first ?? '');

    return Column(
      children: [
        HomeHeader(
          key: _headerKey,
          businessName: businessName,
          userName: userName,
          onSearch: () => _openInventory(InventoryFocus.total),
          onNotifications: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SyncStatusBanner(),
        if (_error != null && _dashboard != null)
          _HomeRefreshError(message: _error!, onRetry: _load),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _loading && _dashboard == null
                      ? const _HomeLoadingSkeleton()
                      : _error != null && _dashboard == null
                          ? _HomeError(
                              message: _error!,
                              onRetry: session.currentBusiness == null
                                  ? null
                                  : _load,
                            )
                          : _buildDashboardContent(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    final dashboard = _dashboard!;
    final tasks = _buildTasks(dashboard);
    final upcoming = _upcoming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AvailabilityCard(
          key: _availabilityKey,
          totalStock: dashboard.totalStock,
          disponibleCount: dashboard.disponibleCount,
          enLocationCount: dashboard.enLocationCount,
          entretienCount: dashboard.entretienCount,
          endommageCount: dashboard.endommageCount,
          pointsATraiter: _pointsATraiter,
          onDisponibleTap: () => _openInventory(InventoryFocus.disponible),
          onLocationTap: () => _openInventory(InventoryFocus.location),
          onEntretienTap: () => _openInventory(InventoryFocus.entretien),
          onEndommageTap: () => _openInventory(InventoryFocus.endommage),
        ),
        QuickActions(
          key: _quickActionsKey,
          onReserve: _openNewReservation,
          onArticle: () => _openInventory(InventoryFocus.total),
          onMaintenance: () => _openTab(3),
          onShowcase: _openShowcase,
        ),
        TasksSection(
          tasks: tasks,
          badgeCount: _pointsATraiter,
          onSeeAll: () => _openActionsPage(),
        ),
        UpcomingReservations(
          reservations: upcoming,
          onSeeAll: () => _openTab(2),
          onTapReservation: _openReservation,
        ),
      ],
    );
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            const SkeletonCard(
              radius: 20,
              child: SizedBox(height: 160, width: double.infinity),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                4,
                (_) => const Column(
                  children: [
                    SkeletonCircle(size: 56),
                    SizedBox(height: 8),
                    SkeletonText(width: 48, height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SkeletonCard(child: SkeletonListItem()),
            const SizedBox(height: 8),
            const SkeletonCard(child: SkeletonListItem()),
            const SizedBox(height: 8),
            const SkeletonCard(child: SkeletonListItem()),
          ],
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _HomeError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppColors.dashOutline),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (onRetry != null)
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }
}

class _HomeRefreshError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeRefreshError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.warningText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Actualisation impossible : $message',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
