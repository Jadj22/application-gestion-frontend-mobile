import 'user_simple.dart';

/// Rappel programmé — Sprint 3.
class ReminderModel {
  final String id;
  final String? taskId;
  final String? itemId;
  final String? itemNom;
  final UserSimple user;
  final String rappelA;
  final String message;
  final bool envoye;
  final UserSimple? createdBy;
  final String? createdAt;

  const ReminderModel({
    required this.id,
    this.taskId,
    this.itemId,
    this.itemNom,
    required this.user,
    required this.rappelA,
    required this.message,
    this.envoye = false,
    this.createdBy,
    this.createdAt,
  });

  /// Vérifie si le rappel est en attente.
  bool get estEnAttente => !envoye;

  factory ReminderModel.fromJson(Map<String, dynamic> json) => ReminderModel(
        id: json['id'] as String,
        taskId: json['task_id'] as String?,
        itemId: json['item_id'] as String?,
        itemNom: json['item_nom'] as String?,
        user: UserSimple.fromJson(json['user']),
        rappelA: (json['rappel_a'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
        envoye: (json['envoye'] as bool?) ?? false,
        createdBy: json['created_by'] != null
            ? UserSimple.fromJson(json['created_by'])
            : null,
        createdAt: json['created_at'] as String?,
      );
}
