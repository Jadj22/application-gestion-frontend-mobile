import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/models/notification_model.dart';
import '../../data/notifications_repository.dart';

/// Écran des notifications/alertes du business.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsRepository _repository;
  late final Business _business;

  List<NotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<NotificationsRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await _repository.notifications(_business.id);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _notifications.sort((a, b) {
            if (a.createdAt == null && b.createdAt == null) return 0;
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dashPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Skeleton(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
    if (_notifications.isEmpty) {
      return _emptyScrollable(const _EmptyState());
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.dashSecondary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationCard(notification: notification);
        },
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

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays}j';
    }
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Color get _severityColor => switch (notification.severity) {
        NotificationSeverity.critical => AppColors.kpiRose,
        NotificationSeverity.warning => AppColors.kpiAmber,
      };

  IconData get _severityIcon => switch (notification.severity) {
        NotificationSeverity.critical => Icons.error_outline,
        NotificationSeverity.warning => Icons.warning_amber_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                _severityIcon,
                size: 22,
                color: _severityColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dashOnSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (notification.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(notification.createdAt!),
                          style: AppTextStyles.body.copyWith(
                            fontSize: 11,
                            color: AppColors.dashOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (notification.itemNom.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dashSurfaceLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notification.itemNom,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.dashOnSurfaceVariant,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.notifications_none_outlined,
          size: 48,
          color: AppColors.dashOutline,
        ),
        const SizedBox(height: 12),
        Text(
          'Aucune notification.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Les alertes de stock et d\'entretien\napparaîtront ici.',
          style: AppTextStyles.body.copyWith(
            fontSize: 13,
            color: AppColors.dashOnSurfaceVariant,
          ),
          textAlign: TextAlign.center,
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
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
