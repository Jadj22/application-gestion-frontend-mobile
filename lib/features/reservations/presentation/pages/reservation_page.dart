import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/logi_event_shell.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../items/data/items_repository.dart';
import '../../../items/data/models/catalog_item.dart';
import '../../../rentals/presentation/pages/rental_return_page.dart';
import '../../data/models/reservation.dart';
import '../../data/reservations_repository.dart';
import 'invoice_create_screen.dart';

/// Création / consultation d'une réservation — données réelles du backend
/// (Sprint 8, US-29 à US-31).
class ReservationPage extends StatefulWidget {
  final bool isDetailMode;
  final String? reservationId;

  const ReservationPage({
    super.key,
    this.isDetailMode = false,
    this.reservationId,
  });

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final _formKey = GlobalKey<FormState>();

  DateTimeRange? _period;
  bool _submitting = false;

  // Données réelles
  List<CatalogItemModel> _catalog = [];
  List<ReservationModel> _reservations = [];
  bool _loading = true;
  String? _error;
  final Map<String, int> _quantities = {};

  // Détail
  ReservationModel? _reservation;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _businessId =>
      context.read<SessionController>().currentBusiness?.id;

  Future<void> _load() async {
    final businessId = _businessId;
    if (businessId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.isDetailMode) {
        final id = widget.reservationId;
        if (id == null) {
          throw ApiException(400, 'Identifiant de réservation manquant.');
        }
        final reservation = await context
            .read<ReservationsRepository>()
            .detail(businessId, id);
        if (mounted) setState(() => _reservation = reservation);
      } else {
        final results = await Future.wait<dynamic>([
          context.read<ItemsRepository>().catalog(businessId),
          context.read<ReservationsRepository>().reservations(businessId),
        ]);
        if (mounted) {
          setState(() {
            _catalog = results[0] as List<CatalogItemModel>;
            _reservations = results[1] as List<ReservationModel>;
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _rentalDays {
    if (_period == null) return 0;
    return _period!.duration.inDays + 1;
  }

  List<CatalogItemModel> get _availableItems =>
      _catalog.where((item) => !item.inactif && item.quantite > 0).toList();

  /// Réservations qui immobilisent du stock (attente, validée ou en cours).
  List<ReservationModel> get _holdingReservations => _reservations
      .where((r) => !r.estAnnulee && !r.estTerminee)
      .toList();

  /// Une réservation chevauche-t-elle la période demandée ?
  bool _overlaps(ReservationModel r, DateTimeRange period) {
    final start = r.dateDebut;
    final end = r.dateFin;
    if (start == null || end == null) return false;
    return !start.isAfter(period.end) && !end.isBefore(period.start);
  }

  /// Quantité réellement disponible pour l'article sur la période :
  /// stock total moins les quantités déjà immobilisées par d'autres
  /// réservations qui chevauchent la période.
  int _availableFor(DateTimeRange period, CatalogItemModel item) {
    final reserved = _holdingReservations
        .where((r) => r.itemId == item.id && _overlaps(r, period))
        .fold<int>(0, (sum, r) => sum + r.quantite);
    return item.quantite - reserved;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _period ??
          DateTimeRange(
            start: now.add(const Duration(days: 1)),
            end: now.add(const Duration(days: 3)),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.dashSecondary,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _period = picked);
    }
  }

  void _setQuantity(String id, int qty, int max) {
    setState(() {
      _quantities[id] = qty.clamp(0, max);
    });
  }

  Future<void> _confirm() async {
    final businessId = _businessId;
    final period = _period;
    if (businessId == null || period == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une période de location.')),
      );
      return;
    }
    final selected =
        _availableItems.where((item) => (_quantities[item.id] ?? 0) > 0).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un article.')),
      );
      return;
    }

    // Vérification de la disponibilité réelle sur la période choisie,
    // avant tout appel réseau : on bloque avec une explication claire.
    final blocked = <CatalogItemModel>[];
    final overbooked = <CatalogItemModel>[];
    for (final item in selected) {
      final available = _availableFor(period, item);
      if (available <= 0) {
        blocked.add(item);
      } else if (_quantities[item.id]! > available) {
        overbooked.add(item);
      }
    }
    if (blocked.isNotEmpty || overbooked.isNotEmpty) {
      await _showAvailabilityDialog(blocked, overbooked, period);
      return;
    }

    setState(() => _submitting = true);
    final repo = context.read<ReservationsRepository>();
    try {
      await repo.createBulk(
        businessId,
        items: [
          for (final item in selected)
            (itemId: item.id, quantite: _quantities[item.id]!),
        ],
        dateDebut: period.start,
        dateFin: period.end,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} réservation${selected.length > 1 ? 's' : ''} '
            'créée${selected.length > 1 ? 's' : ''} avec succès.',
          ),
        ),
      );
      Navigator.maybePop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  /// Dialogue explicatif quand des articles sélectionnés ne sont pas
  /// disponibles (ou pas en quantité suffisante) sur la période choisie.
  Future<void> _showAvailabilityDialog(
    List<CatalogItemModel> blocked,
    List<CatalogItemModel> overbooked,
    DateTimeRange period,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.event_busy,
            color: AppColors.dashError, size: 32),
        title: const Text(
          'Disponibilité insuffisante',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Période : ${_formatDate(period.start)} → ${_formatDate(period.end)}',
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (blocked.isNotEmpty) ...[
                Text(
                  'Ces articles sont déjà réservés sur ces dates :',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashError,
                  ),
                ),
                const SizedBox(height: 6),
                for (final item in blocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${item.nom}',
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ),
              ],
              if (blocked.isNotEmpty && overbooked.isNotEmpty)
                const SizedBox(height: 8),
              if (overbooked.isNotEmpty) ...[
                Text(
                  'Quantité demandée trop élevée :',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashError,
                  ),
                ),
                const SizedBox(height: 6),
                for (final item in overbooked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${item.nom} : ${_quantities[item.id]} demandés, '
                      '${_availableFor(period, item)} disponibles',
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                'Réduisez la quantité ou choisissez une autre période.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(String action) async {
    final businessId = _businessId;
    final reservation = _reservation;
    if (businessId == null || reservation == null) return;
    setState(() => _working = true);
    try {
      final updated = await context
          .read<ReservationsRepository>()
          .action(businessId, reservation.id, action);
      if (mounted) setState(() => _reservation = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réservation « ${updated.statutLabel} ».'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openReturn() async {
    final reservation = _reservation;
    if (reservation == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RentalReturnPage(reservationId: reservation.id),
      ),
    );
    // Le retour peut avoir changé le statut (EN_COURS -> TERMINEE) : on
    // recharge pour que "Contrôler le retour" disparaisse si c'est fait.
    if (mounted) _load();
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 768;
    final pageTitle =
        widget.isDetailMode ? 'Détail Réservation' : 'Nouvelle Réservation';

    return LogiEventShell(
      navIndex: 3,
      showNavigation: false,
      pageTitle: pageTitle,
      body: SafeArea(
        child: _loading
            ? _buildLoadingSkeleton(isWide)
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : 16,
                      isWide ? 24 : 8,
                      isWide ? 32 : 16,
                      isWide ? 32 : 120,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child:
                            widget.isDetailMode
                                ? _buildDetail()
                                : _buildCreateForm(isWide),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isWide) {
    return Skeleton(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isWide ? 32 : 16,
          isWide ? 24 : 8,
          isWide ? 32 : 16,
          isWide ? 32 : 120,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SkeletonCircle(size: 24),
                    SizedBox(width: 12),
                    SkeletonText(width: 160, height: 20),
                  ],
                ),
                SizedBox(height: 24),
                SkeletonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: 140, height: 18),
                      SizedBox(height: 16),
                      SkeletonBox(height: 64, borderRadius: BorderRadius.all(Radius.circular(12))),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                SkeletonCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: 100, height: 18),
                      SizedBox(height: 16),
                      SkeletonListItem(),
                      SkeletonListItem(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm(bool isWide) {
    final items = _availableItems;
    final period = _period;
    final Map<String, int>? availability = period == null
        ? null
        : {
            for (final item in items) item.id: _availableFor(period, item),
          };
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _PeriodSection(
                        period: _period,
                        rentalDays: _rentalDays,
                        onPick: _pickDateRange,
                        onPreset: (range) => setState(() => _period = range),
                        formatDate: _formatDate,
                      ),
                      const SizedBox(height: 24),
                      _EquipmentSection(
                        items: items,
                        period: period,
                        availabilityFor: availability,
                        quantities: _quantities,
                        onQuantityChanged: _setQuantity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildSubmitPanel(
                    period: period,
                    availability: availability,
                  ),
                ),
              ],
            )
          else ...[
            _PeriodSection(
              period: _period,
              rentalDays: _rentalDays,
              onPick: _pickDateRange,
              onPreset: (range) => setState(() => _period = range),
              formatDate: _formatDate,
            ),
            const SizedBox(height: 24),
            _EquipmentSection(
              items: items,
              period: period,
              availabilityFor: availability,
              quantities: _quantities,
              onQuantityChanged: _setQuantity,
            ),
            const SizedBox(height: 24),
            _buildSubmitPanel(
              period: period,
              availability: availability,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitPanel({
    DateTimeRange? period,
    Map<String, int>? availability,
  }) {
    final items = _availableItems;
    var count = 0;
    for (final item in items) {
      count += _quantities[item.id] ?? 0;
    }
    final unavailable = <CatalogItemModel>[];
    final overbooked = <CatalogItemModel>[];
    if (period != null && availability != null) {
      for (final item in items) {
        final qty = _quantities[item.id] ?? 0;
        if (qty == 0) continue;
        final available = availability[item.id] ?? 0;
        if (available <= 0) {
          unavailable.add(item);
        } else if (qty > available) {
          overbooked.add(item);
        }
      }
    }
    return LogiEventCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Récapitulatif',
            style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
          ),
          const SizedBox(height: 20),
          _SummaryLine(
            label: 'Articles',
            value: '$count',
            hint: period == null
                ? 'sur ${items.length} en stock'
                : 'sur ${items.length} dispo. pour ces dates',
          ),
          const SizedBox(height: 12),
          _SummaryLine(
            label: 'Durée',
            value: _rentalDays > 0 ? '$_rentalDays jour(s)' : '—',
          ),
          if (period == null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.dashSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Choisissez une période pour vérifier la disponibilité.',
                    style: AppTextStyles.body.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (unavailable.isNotEmpty || overbooked.isNotEmpty) ...[
            const Divider(height: 32, color: AppColors.dashOutlineVariant),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dashError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.dashError.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (unavailable.isNotEmpty) ...[
                    Text(
                      'Indisponibles pour ces dates :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dashError,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final item in unavailable)
                      Text(
                        '• ${item.nom}',
                        style: AppTextStyles.body.copyWith(fontSize: 12),
                      ),
                  ],
                  if (unavailable.isNotEmpty && overbooked.isNotEmpty)
                    const SizedBox(height: 8),
                  if (overbooked.isNotEmpty) ...[
                    Text(
                      'Quantité supérieure au disponible :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dashError,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final item in overbooked)
                      Text(
                        '• ${item.nom} (${availability?[item.id] ?? 0} max. sur la période)',
                        style: AppTextStyles.body.copyWith(fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
          ],
          const Divider(height: 32, color: AppColors.dashOutlineVariant),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _confirm,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.dashPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'CONFIRMER LA RÉSERVATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final reservation = _reservation!;
    final session = context.read<SessionController>();
    final canManage = session.can('reservation.manage');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReservationSummaryCard(reservation: reservation),
        const SizedBox(height: 24),
        LogiEventCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Détails',
                style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                label: 'Article',
                value: reservation.itemNom,
              ),
              _DetailRow(
                label: 'Référence',
                value: reservation.reference,
              ),
              _DetailRow(
                label: 'Période',
                value:
                    '${reservation.dateDebut != null ? _formatDate(reservation.dateDebut!) : '—'} → '
                    '${reservation.dateFin != null ? _formatDate(reservation.dateFin!) : '—'}',
              ),
              _DetailRow(
                label: 'Quantité',
                value: '${reservation.quantite}',
              ),
              if (reservation.motif.isNotEmpty)
                _DetailRow(label: 'Motif', value: reservation.motif),
              if (reservation.reservePar != null)
                _DetailRow(
                  label: 'Réservé par',
                  value: reservation.reservePar!.displayName,
                ),
              if (reservation.observations.isNotEmpty)
                _DetailRow(
                  label: 'Observations',
                  value: reservation.observations,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (canManage && reservation.estEnCours) ...[
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _working ? null : _openReturn,
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Contrôler le retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dashPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (canManage && reservation.estEnAttente)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : () => _runAction('annuler'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.dashError,
                    side: BorderSide(color: AppColors.dashError.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _working ? null : () => _runAction('valider'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.dashPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Valider'),
                ),
              ),
            ],
          ),
        if (canManage && reservation.estValidee)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working ? null : () => _runAction('annuler'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.dashError,
                    side: BorderSide(color: AppColors.dashError.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _working ? null : () => _runAction('demarrer'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.dashPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Démarrer'),
                ),
              ),
            ],
          ),
        if (canManage && (reservation.estValidee || reservation.estEnCours || reservation.estTerminee)) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final business = context.read<SessionController>().currentBusiness;
                if (business == null) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InvoiceCreateScreen(
                      businessId: business.id,
                      businessName: business.nom,
                      preselectedReservationId: reservation.id,
                    ),
                  ),
                );
                if (mounted) _load();
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Créer une facture'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dashPrimary,
                side: BorderSide(color: AppColors.dashPrimary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

}

class _ReservationSummaryCard extends StatelessWidget {
  final ReservationModel reservation;

  const _ReservationSummaryCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    return LogiEventCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.dashSurfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.event_available_outlined,
              size: 26,
              color: AppColors.dashPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.itemNom,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dashOnSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reservation.reference,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.dashOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(status: reservation.statut),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'EN_ATTENTE' => AppColors.kpiAmber,
      'VALIDEE' => AppColors.kpiBlue,
      'EN_COURS' => AppColors.kpiIndigo,
      'TERMINEE' => AppColors.kpiGreen,
      'ANNULEE' => AppColors.kpiRose,
      _ => AppColors.dashOutline,
    };
    final label = switch (status) {
      'EN_ATTENTE' => 'EN ATTENTE',
      'VALIDEE' => 'VALIDÉE',
      'EN_COURS' => 'EN COURS',
      'TERMINEE' => 'TERMINÉE',
      'ANNULEE' => 'ANNULÉE',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.fieldLabel.copyWith(
                color: AppColors.dashOnSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.dashOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

DateTimeRange _presetRange(int days) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  return DateTimeRange(start: start, end: start.add(Duration(days: days - 1)));
}

DateTimeRange _presetWeekend() {
  final now = DateTime.now();
  var saturday = DateTime(now.year, now.month, now.day);
  while (saturday.weekday != DateTime.saturday) {
    saturday = saturday.add(const Duration(days: 1));
  }
  return DateTimeRange(start: saturday, end: saturday.add(const Duration(days: 1)));
}

class _PeriodSection extends StatelessWidget {
  final DateTimeRange? period;
  final int rentalDays;
  final VoidCallback onPick;
  final ValueChanged<DateTimeRange> onPreset;
  final String Function(DateTime) formatDate;

  const _PeriodSection({
    required this.period,
    required this.rentalDays,
    required this.onPick,
    required this.onPreset,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return LogiEventCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: AppColors.dashOnSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Période de location',
                style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dashSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.dashOutlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE DE DÉBUT',
                          style: AppTextStyles.fieldLabel,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          period != null
                              ? formatDate(period!.start)
                              : 'Sélectionner',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: period != null
                                ? AppColors.dashOnSurface
                                : AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: AppColors.dashOnSurfaceVariant,
                    size: 20,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'DATE DE FIN',
                          style: AppTextStyles.fieldLabel,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          period != null
                              ? formatDate(period!.end)
                              : 'Sélectionner',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: period != null
                                ? AppColors.dashOnSurface
                                : AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Ce week-end',
                active: false,
                onTap: () => onPreset(_presetWeekend()),
              ),
              _FilterChip(
                label: '3 jours',
                active: false,
                onTap: () => onPreset(_presetRange(3)),
              ),
              _FilterChip(
                label: '1 semaine',
                active: false,
                onTap: () => onPreset(_presetRange(7)),
              ),
            ],
          ),
          if (period != null) ...[
            const SizedBox(height: 12),
            Text(
              'Durée : $rentalDays jour${rentalDays > 1 ? 's' : ''}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.dashSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EquipmentSection extends StatefulWidget {
  final List<CatalogItemModel> items;
  final DateTimeRange? period;
  final Map<String, int>? availabilityFor;
  final Map<String, int> quantities;
  final void Function(String id, int qty, int max) onQuantityChanged;

  const _EquipmentSection({
    required this.items,
    required this.period,
    required this.availabilityFor,
    required this.quantities,
    required this.onQuantityChanged,
  });

  @override
  State<_EquipmentSection> createState() => _EquipmentSectionState();
}

class _EquipmentSectionState extends State<_EquipmentSection> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final set = <String>{};
    for (final item in widget.items) {
      final c = item.categorie;
      if (c != null && c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<CatalogItemModel> get _filtered {
    final query = _query.trim().toLowerCase();
    return widget.items.where((item) {
      if (_selectedCategory != null && item.categorie != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.nom.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query);
    }).toList();
  }

  List<CatalogItemModel> get _selectedItems => widget.items
      .where((item) => (widget.quantities[item.id] ?? 0) > 0)
      .toList();

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final filtered = _filtered;
    final selected = _selectedItems;

    return LogiEventCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: AppColors.dashOnSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Matériel',
                style: AppTextStyles.h2.copyWith(color: AppColors.dashOnSurface),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in selected)
                  _SelectedChip(
                    label: '${item.nom} × ${widget.quantities[item.id]}',
                    onRemove: () =>
                        widget.onQuantityChanged(item.id, 0, item.quantite),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Rechercher un article...',
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: AppColors.dashOutline),
              isDense: true,
              filled: true,
              fillColor: AppColors.dashSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                borderSide:
                    const BorderSide(color: AppColors.dashSecondary, width: 1.5),
              ),
            ),
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Tous',
                    active: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: c,
                      active: _selectedCategory == c,
                      onTap: () => setState(
                        () => _selectedCategory =
                            _selectedCategory == c ? null : c,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucun article disponible pour la réservation.',
                  style: AppTextStyles.body,
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucun article ne correspond à votre recherche.',
                  style: AppTextStyles.body,
                ),
              ),
            )
          else
            ...filtered.map(
              (item) => _EquipmentRow(
                item: item,
                period: widget.period,
                available: widget.availabilityFor?[item.id] ?? item.quantite,
                quantity: widget.quantities[item.id] ?? 0,
                onChanged: (qty) => widget.onQuantityChanged(
                  item.id,
                  qty,
                  widget.availabilityFor?[item.id] ?? item.quantite,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _SelectedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.dashPrimary,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppColors.dashPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  final CatalogItemModel item;
  final DateTimeRange? period;
  final int available;
  final int quantity;
  final ValueChanged<int> onChanged;

  const _EquipmentRow({
    required this.item,
    required this.period,
    required this.available,
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.quantite;
    final period = this.period;
    final selectable = period == null ? total : available;
    final (Color, String) availability = switch (period) {
      null => (AppColors.kpiGreen, '$total disponibles'),
      _ when available <= 0 => (
          AppColors.dashError,
          'Indisponible pour ces dates',
        ),
      _ when available < total => (
          AppColors.kpiAmber,
          '$available dispo. pour ces dates (sur $total)',
        ),
      _ => (AppColors.kpiGreen, '$total dispo. pour ces dates'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nom,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dashOnSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.sku.isNotEmpty
                      ? '${item.sku} · ${item.categorie ?? '—'}'
                      : (item.categorie ?? '—'),
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      period != null && available <= 0
                          ? Icons.block
                          : Icons.inventory_2_outlined,
                      size: 13,
                      color: availability.$1,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        availability.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          color: availability.$1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _QtyStepper(
            value: selectable <= 0
                ? 0
                : quantity.clamp(0, selectable),
            max: selectable,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  Future<void> _editExact(BuildContext context) async {
    final controller = TextEditingController(text: '$value');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        void submit() =>
            Navigator.of(dialogContext).pop(int.tryParse(controller.text));
        return AlertDialog(
          title: const Text('Quantité'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              suffixText: '/ $max dispo.',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(onPressed: submit, child: const Text('OK')),
          ],
        );
      },
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dashOutlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          InkWell(
            onTap: () => _editExact(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            visualDensity: VisualDensity.compact,
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
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
            letterSpacing: 0.2,
            color: active ? Colors.white : AppColors.dashOnSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const _SummaryLine({
    required this.label,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.fieldLabel.copyWith(
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: AppTextStyles.body.copyWith(fontSize: 11),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.dashOnSurface,
          ),
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
          const Icon(Icons.cloud_off, size: 48, color: AppColors.hint),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
