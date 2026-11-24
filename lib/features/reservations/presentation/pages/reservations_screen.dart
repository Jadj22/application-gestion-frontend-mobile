import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_view.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/data/models/user.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/models/reservation.dart';
import '../../data/reservations_repository.dart';
import 'reservation_page.dart';
import 'booking_request_list_screen.dart';

/// Liste des réservations (US-29) — maquette Stitch « Joël Events ».
class ReservationsScreen extends StatefulWidget {
  final bool showBottomNav;

  const ReservationsScreen({super.key, this.showBottomNav = true});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  late final ReservationsRepository _repository;
  late final Business _business;

  List<ReservationModel> _reservations = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const _filters = [
    (null, 'Toutes'),
    ('EN_ATTENTE', 'En attente'),
    ('VALIDEE', 'Validées'),
    ('EN_COURS', 'En cours'),
    ('TERMINEE', 'Terminées'),
    ('ANNULEE', 'Annulées'),
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<ReservationsRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reservations =
          await _repository.reservations(_business.id, statut: _statusFilter);
      if (mounted) setState(() => _reservations = reservations);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ReservationPage()),
    );
    if (mounted) _load();
  }

  Future<void> _openDetail(ReservationModel reservation) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashSurfaceLow,
      appBar: AppBar(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Réservations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.dashPrimary),
            tooltip: 'Nouvelle réservation',
            onPressed: _openCreate,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.assignment, color: AppColors.dashPrimary),
            tooltip: 'Demandes de location',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookingRequestListScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (value, label) in _filters) ...[
                    if (value != _filters.first.$1) const SizedBox(width: 8),
                    _FilterChip(
                      label: label,
                      active: _statusFilter == value,
                      onTap: () {
                        setState(() => _statusFilter = value);
                        _load();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? AppBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (index == 3) return;
                Navigator.of(context).pop();
              },
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Skeleton(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, _) => const SkeletonCard(
            padding: EdgeInsets.all(14),
            radius: 16,
            child: SkeletonListItem(),
          ),
        ),
      );
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _load);
    }
    if (_reservations.isEmpty) {
      return _emptyScrollable(
        AppEmptyState(
          icon: Icons.event_available_outlined,
          title: _statusFilter == null
              ? 'Aucune réservation.'
              : 'Aucune réservation dans cet état.',
          actionLabel: _statusFilter == null ? 'Nouvelle réservation' : null,
          onAction: _statusFilter == null ? _openCreate : null,
        ),
      );
    }
    final groups = _groupReservations(_reservations);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.dashSecondary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final group = groups[index];
          if (group.items.length == 1) {
            final reservation = group.items.first;
            return _ReservationCard(
              reservation: reservation,
              onTap: () => _openDetail(reservation),
            );
          }
          return _ReservationGroupCard(group: group, onTapItem: _openDetail);
        },
      ),
    );
  }

  /// Regroupe les réservations créées ensemble (même période + même
  /// demandeur) — une réservation « bulk » de 5 articles crée 5 lignes côté
  /// backend ; sans ça la liste donnerait l'impression de 5 réservations
  /// distinctes alors que l'utilisateur n'a fait qu'une seule action.
  List<_ReservationGroup> _groupReservations(List<ReservationModel> list) {
    final groups = <String, _ReservationGroup>{};
    final order = <String>[];
    for (final r in list) {
      final key = '${r.dateDebut}|${r.dateFin}|${r.reservePar?.id}';
      final existing = groups[key];
      if (existing == null) {
        groups[key] = _ReservationGroup(
          dateDebut: r.dateDebut,
          dateFin: r.dateFin,
          reservePar: r.reservePar,
          items: [r],
        );
        order.add(key);
      } else {
        existing.items.add(r);
      }
    }
    return [for (final key in order) groups[key]!];
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

class _ReservationGroup {
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final User? reservePar;
  final List<ReservationModel> items;

  _ReservationGroup({
    required this.dateDebut,
    required this.dateFin,
    required this.reservePar,
    required this.items,
  });
}

String _fmtShort(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m';
}

Color _statusColorOf(String statut) => switch (statut) {
      'EN_ATTENTE' => AppColors.kpiAmber,
      'VALIDEE' => AppColors.kpiBlue,
      'EN_COURS' => AppColors.kpiIndigo,
      'TERMINEE' => AppColors.kpiGreen,
      'ANNULEE' => AppColors.kpiRose,
      _ => AppColors.dashOutline,
    };

class _ReservationGroupCard extends StatelessWidget {
  final _ReservationGroup group;
  final ValueChanged<ReservationModel> onTapItem;

  const _ReservationGroupCard({required this.group, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final period = group.dateDebut != null && group.dateFin != null
        ? '${_fmtShort(group.dateDebut!)} → ${_fmtShort(group.dateFin!)}'
        : 'Période non précisée';

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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.event_available_outlined,
                    size: 20,
                    color: AppColors.dashPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.items.length} articles réservés',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dashOnSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.reservePar != null
                            ? '$period · ${group.reservePar!.displayName}'
                            : period,
                        style: AppTextStyles.body.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.dashOutlineVariant),
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: AppColors.dashOutlineVariant,
              ),
            _GroupItemRow(
              reservation: group.items[i],
              onTap: () => onTapItem(group.items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupItemRow extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback onTap;

  const _GroupItemRow({required this.reservation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _statusColorOf(reservation.statut);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${reservation.itemNom} · ${reservation.quantite} unité${reservation.quantite > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dashOnSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reservation.statutLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.dashOutline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback onTap;

  const _ReservationCard({required this.reservation, required this.onTap});

  Color get _statusColor => _statusColorOf(reservation.statut);

  @override
  Widget build(BuildContext context) {
    final period = reservation.dateDebut != null && reservation.dateFin != null
        ? '${_fmtShort(reservation.dateDebut!)} → ${_fmtShort(reservation.dateFin!)}'
        : 'Période non précisée';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.dashSurfaceLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.event_available_outlined,
                  size: 20,
                  color: AppColors.dashPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.itemNom,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dashOnSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$period · ${reservation.quantite} unité${reservation.quantite > 1 ? 's' : ''}',
                      style: AppTextStyles.body.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reservation.statutLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: _statusColor,
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

