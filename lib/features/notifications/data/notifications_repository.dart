import '../../../core/offline/entity_registry.dart';
import '../../../core/offline/offline_repository.dart';
import 'models/notification_model.dart';

/// Alertes et notifications du business.
///
/// Entièrement calculées par le serveur : rien à écrire, donc rien à mettre en
/// file. Elles sont simplement conservées localement pour que la cloche ne se
/// vide pas dès que le réseau tombe.
class NotificationsRepository {
  final OfflineRepository _offline;

  NotificationsRepository(this._offline);

  /// Alertes du business, servies depuis la copie locale hors ligne.
  Future<List<NotificationModel>> notifications(
    String businessId, {
    bool refresh = false,
  }) async {
    final rows = await _offline.readCollection(
      EntityRegistry.alert,
      businessId,
      refresh: refresh,
    );
    return rows.map(NotificationModel.fromJson).toList();
  }

  /// Nombre d'alertes non lues.
  Future<int> unreadCount(String businessId) async {
    final alerts = await notifications(businessId);
    return alerts.where((n) => !n.isRead).length;
  }
}
