import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/repositories/booking_request_repository.dart';
import '../../data/models/booking_request_model.dart';
import 'booking_request_detail_screen.dart';

/// Liste des demandes de réservation pour l'équipe
class BookingRequestListScreen extends StatefulWidget {
  final bool showBottomNav;

  const BookingRequestListScreen({super.key, this.showBottomNav = true});

  @override
  State<BookingRequestListScreen> createState() => _BookingRequestListScreenState();
}

class _BookingRequestListScreenState extends State<BookingRequestListScreen> {
  late final BookingRequestRepository _repository;
  late final Business _business;

  final List<BookingRequestModel> _requests = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _statutFilter;
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  // Spécification explicite du type pour éviter l'inférence stricte sur (Null, String)
  static const List<(String?, String)> _statutOptions = [
    (null, 'Tous'),
    ('EN_ATTENTE', 'En attente'),
    ('ACCEPTEE', 'Acceptées'),
    ('REFUSEE', 'Refusées'),
    ('CONVERTIE', 'Converties'),
    ('EXPIREE', 'Expirées'),
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<BookingRequestRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _requests.clear();
    }
    if (!_hasMore && !refresh) return;

    setState(() {
      if (refresh) _loading = true;
      _loadingMore = !refresh;
      _error = null;
    });

    try {
      final result = await _repository.getTeamList(
        businessId: _business.id,
        statut: _statutFilter,
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _requests.addAll(result.results);
          _hasMore = result.next != null;
          _page++;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async => _load(refresh: true);

  Future<void> _openDetail(BookingRequestModel request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingRequestDetailScreen(requestId: request.id),
      ),
    );
    if (mounted) _load(refresh: true);
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
          'Demandes de location',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.dashPrimary),
            tooltip: 'Actualiser',
            onPressed: _onRefresh,
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
                  for (final (value, label) in _statutOptions) ...[
                    if (value != _statutOptions.first.$1) const SizedBox(width: 8),
                    _FilterChip(
                      label: label,
                      active: _statutFilter == value,
                      onTap: () {
                        setState(() => _statutFilter = value);
                        _load(refresh: true);
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
      return _LoadError(message: _error!, onRetry: _load);
    }
    if (_requests.isEmpty) {
      return _emptyScrollable(
        _EmptyState(
          statusFilter: _statutFilter,
          onCreate: () {}, // Pas de création depuis l'équipe
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.dashSecondary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
            if (!_loadingMore && _hasMore) {
              _load();
            }
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: _requests.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _requests.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final request = _requests[index];
            return _BookingRequestCard(
              request: request,
              onTap: () => _openDetail(request),
            );
          },
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.dashPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.dashPrimary : AppColors.dashOutlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.dashOnSurface,
          ),
        ),
      ),
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  final BookingRequestModel request;
  final VoidCallback onTap;

  const _BookingRequestCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColorOf(request.statut);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dashOutlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Statut badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _statusIconOf(request.statut),
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.itemNom,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                request.statutDisplay,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${request.clientNom} • ${_formatDate(request.dateDebut)} → ${_formatDate(request.dateFin)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.quantite} ${request.itemUnite}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColorOf(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return AppColors.kpiAmber;
      case 'ACCEPTEE':
        return AppColors.kpiBlue;
      case 'REFUSEE':
        return AppColors.kpiRose;
      case 'CONVERTIE':
        return AppColors.kpiGreen;
      case 'EXPIREE':
        return Colors.grey;
      default:
        return AppColors.dashOutline;
    }
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  IconData _statusIconOf(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return Icons.schedule;
      case 'ACCEPTEE':
        return Icons.check_circle;
      case 'REFUSEE':
        return Icons.cancel;
      case 'CONVERTIE':
        return Icons.assignment_turned_in;
      case 'EXPIREE':
        return Icons.access_time;
      default:
        return Icons.help_outline;
    }
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.dangerText),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? statusFilter;
  final VoidCallback onCreate;

  const _EmptyState({
    this.statusFilter,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          'Aucune demande',
          style: AppTextStyles.h2,
        ),
        const SizedBox(height: 8),
        Text(
          statusFilter != null
              ? 'Aucune demande avec ce statut'
              : 'Aucune demande de location pour ce business',
          style: AppTextStyles.body.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}