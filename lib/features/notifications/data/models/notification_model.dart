/// Modèle de notification/alerte — `AlertSerializer` du backend.
class NotificationModel {
  final String id;
  final String itemId;
  final String itemNom;
  final String code;
  final String mode;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.itemId,
    required this.itemNom,
    required this.code,
    required this.mode,
    required this.message,
    this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        itemId: (json['item_id'] as String?) ?? '',
        itemNom: (json['item_nom'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        mode: (json['mode'] as String?) ?? 'AVERTISSEMENT',
        message: (json['message'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
        isRead: (json['is_read'] as bool?) ?? false,
      );

  /// Gravité de l'alerte.
  NotificationSeverity get severity =>
      mode == 'BLOCAGE' ? NotificationSeverity.critical : NotificationSeverity.warning;

  /// Titre lisible basé sur le code.
  String get title {
    switch (code) {
      case 'ARTICLE_EN_ENTRETIEN':
        return 'Article en entretien';
      case 'ENTRETIEN_PARTIEL':
        return 'Entretien partiel';
      case 'ARTICLE_A_VERIFIER':
        return 'Article à vérifier';
      case 'STOCK_BAS':
        return 'Stock bas';
      case 'STOCK_EPUISE':
        return 'Stock épuisé';
      case 'RESERVATION_EN_ATTENTE':
        return 'Réservation en attente';
      default:
        return itemNom.isEmpty ? 'Notification' : itemNom;
    }
  }

  /// Copie avec modification.
  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        itemId: itemId,
        itemNom: itemNom,
        code: code,
        mode: mode,
        message: message,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );
}

/// Gravité d'une notification.
enum NotificationSeverity { warning, critical }
