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
  DateTime _selectedDate = DateTime.now();
  bool _calendarExpanded = true;
  final Set<String> _workingGroups = {};

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
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reservations = await _repository.reservations(
        _business.id,
        refresh: refresh,
      );
      if (mounted) setState(() => _reservations = reservations);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ReservationPage()));
    if (mounted) _load(refresh: true);
  }

  Future<void> _openDetail(ReservationModel reservation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ReservationPage(isDetailMode: true, reservationId: reservation.id),
      ),
    );
    if (mounted) _load(refresh: true);
  }

  List<ReservationModel> get _visibleReservations {
    final selectedDate = _dateOnly(_selectedDate);
    final reservations = _reservations.where((reservation) {
      if (_statusFilter != null && reservation.statut != _statusFilter) {
        return false;
      }
      final endDate = reservation.dateFin ?? reservation.dateDebut;
      return endDate == null || !_dateOnly(endDate).isBefore(selectedDate);
    }).toList();
    reservations.sort((a, b) {
      final dateA = a.dateDebut ?? DateTime(9999);
      final dateB = b.dateDebut ?? DateTime(9999);
      return dateA.compareTo(dateB);
    });
    return reservations;
  }

  int _countFor(String? status) => _groupReservations(
    status == null
        ? _reservations
        : _reservations
              .where((reservation) => reservation.statut == status)
              .toList(),
  ).length;

  Future<void> _runGroupAction(_ReservationGroup group, String action) async {
    if (!context.read<SessionController>().can('reservation.manage')) return;
    final groupKey = group.key;
    if (_workingGroups.contains(groupKey)) return;
    setState(() => _workingGroups.add(groupKey));

    try {
      for (final reservation in group.items) {
        await _repository.action(_business.id, reservation.id, action);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'valider'
                  ? 'Réservation${group.items.length > 1 ? 's' : ''} validée${group.items.length > 1 ? 's' : ''}.'
                  : 'Réservation${group.items.length > 1 ? 's' : ''} refusée${group.items.length > 1 ? 's' : ''}.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _workingGroups.remove(groupKey));
        await _load(refresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashSurfaceLow,
      appBar: AppBar(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Réservations',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.dashOnSurface,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.dashPrimary),
            tooltip: 'Actualiser',
            onPressed: () => _load(refresh: true),
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.dashOnSurfaceVariant,
            ),
            tooltip: _calendarExpanded
                ? 'Masquer le calendrier'
                : 'Afficher le calendrier',
            onPressed: () =>
                setState(() => _calendarExpanded = !_calendarExpanded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            onSelected: (value) {
              if (value == 'requests') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookingRequestListScreen(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'requests',
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Demandes de location'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.dashPrimary),
            tooltip: 'Nouvelle réservation',
            onPressed: _openCreate,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_calendarExpanded) _buildWeekCalendar(),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (value, label) in _filters) ...[
                    if (value != _filters.first.$1) const SizedBox(width: 8),
                    _FilterChip(
                      label: '$label · ${_countFor(value)}',
                      active: _statusFilter == value,
                      onTap: () {
                        setState(() => _statusFilter = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Prochaines réservations',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashOnSurface,
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? AppBottomNav(
              currentIndex: 2,
              onTap: (index) {
                if (index == 2) return;
                Navigator.of(context).pop();
              },
            )
          : null,
    );
  }

  Widget _buildWeekCalendar() {
    final weekStart = _dateOnly(
      _selectedDate,
    ).subtract(Duration(days: _selectedDate.weekday - 1));
    final weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${months[_selectedDate.month - 1]} ${_selectedDate.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashOnSurface,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedDate = DateTime.now()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.dashPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Aujourd’hui'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: _CalendarDay(
                    date: weekStart.add(Duration(days: index)),
                    weekday: weekdays[index],
                    selected: _isSameDay(
                      weekStart.add(Duration(days: index)),
                      _selectedDate,
                    ),
                    dots: _reservationsOn(weekStart.add(Duration(days: index))),
                    onTap: (date) => setState(() => _selectedDate = date),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _reservationsOn(DateTime date) {
    final day = _dateOnly(date);
    final colors = <Color>[];
    for (final reservation in _reservations) {
      final start = reservation.dateDebut;
      final end = reservation.dateFin ?? start;
      if (start == null || end == null) continue;
      if (!day.isBefore(_dateOnly(start)) && !day.isAfter(_dateOnly(end))) {
        colors.add(_statusColorOf(reservation.statut));
      }
      if (colors.length == 2) break;
    }
    return colors;
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
      return AppErrorView(
        message: _error!,
        onRetry: () => _load(refresh: true),
      );
    }
    final reservations = _visibleReservations;
    if (reservations.isEmpty) {
      return _emptyScrollable(
        AppEmptyState(
          icon: Icons.event_available_outlined,
          title: _statusFilter == null
              ? 'Aucune réservation à venir.'
              : 'Aucune réservation à venir dans cet état.',
          actionLabel: _statusFilter == null ? 'Nouvelle réservation' : null,
          onAction: _statusFilter == null ? _openCreate : null,
        ),
      );
    }
    final groups = _groupReservations(reservations);
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: AppColors.dashSecondary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _ReservationGroupCard(
            group: group,
            canManage: context.read<SessionController>().can(
              'reservation.manage',
            ),
            busy: _workingGroups.contains(group.key),
            onTap: () => _openDetail(group.items.first),
            onAction: (action) => _runGroupAction(group, action),
          );
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
      final key = '${r.dateDebut}|${r.dateFin}|${r.reservePar?.id}|${r.motif}';
      final existing = groups[key];
      if (existing == null) {
        groups[key] = _ReservationGroup(
          dateDebut: r.dateDebut,
          dateFin: r.dateFin,
          reservePar: r.reservePar,
          motif: r.motif,
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

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _ReservationGroup {
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final User? reservePar;
  final String motif;
  final List<ReservationModel> items;

  _ReservationGroup({
    required this.dateDebut,
    required this.dateFin,
    required this.reservePar,
    required this.motif,
    required this.items,
  });

  String get key => items.map((reservation) => reservation.id).join('|');
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
  final bool canManage;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  const _ReservationGroupCard({
    required this.group,
    required this.canManage,
    required this.busy,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final first = group.items.first;
    final statusColor = _statusColorOf(first.statut);
    final title = group.motif.trim().isNotEmpty
        ? group.motif.trim()
        : group.reservePar?.displayName ?? 'Réservation';
    final itemsSummary = group.items
        .map((reservation) => '${reservation.quantite} ${reservation.itemNom}')
        .join(' · ');
    final period = group.dateDebut != null && group.dateFin != null
        ? '${_fmtShort(group.dateDebut!)} → ${_fmtShort(group.dateFin!)}'
        : 'Période non précisée';
    final date = group.dateDebut;
    final canAct =
        canManage &&
        group.items.every((reservation) => reservation.estEnAttente);

    return Material(
      color: AppColors.dashSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
                children: [
                  _ReservationDateBadge(date: date),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dashOnSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          itemsSummary,
                          style: AppTextStyles.body.copyWith(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 15,
                    color: AppColors.dashOnSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      period,
                      style: AppTextStyles.body.copyWith(fontSize: 12),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _shortStatus(first.statut),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (canAct) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => onAction('annuler'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          foregroundColor: AppColors.dashError,
                          side: BorderSide(
                            color: AppColors.dashError.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: busy ? null : () => onAction('valider'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          backgroundColor: AppColors.dashPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Valider'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _shortStatus(String status) => switch (status) {
  'EN_ATTENTE' => 'En attente',
  'VALIDEE' => 'Validée',
  'EN_COURS' => 'En cours',
  'TERMINEE' => 'Terminée',
  'ANNULEE' => 'Annulée',
  _ => status,
};

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final String weekday;
  final bool selected;
  final List<Color> dots;
  final ValueChanged<DateTime> onTap;

  const _CalendarDay({
    required this.date,
    required this.weekday,
    required this.selected,
    required this.dots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(date),
      child: Column(
        children: [
          Text(
            weekday,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.dashOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.dashPrimary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.dashOnSurface,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in dots)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
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

class _ReservationDateBadge extends StatelessWidget {
  final DateTime? date;

  const _ReservationDateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    const months = [
      'JAN',
      'FÉV',
      'MAR',
      'AVR',
      'MAI',
      'JUN',
      'JUL',
      'AOÛ',
      'SEP',
      'OCT',
      'NOV',
      'DÉC',
    ];
    return Container(
      width: 48,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: date == null
          ? const Icon(
              Icons.event_available_outlined,
              color: AppColors.dashPrimary,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  months[date!.month - 1],
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dashPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${date!.day}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dashOnSurface,
                  ),
                ),
              ],
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
            color: active
                ? AppColors.dashPrimary
                : AppColors.dashOutlineVariant,
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
