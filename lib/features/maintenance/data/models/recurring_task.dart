import 'user_simple.dart';

/// Tâche récurrente — Sprint 3.
class RecurringTaskModel {
  final String id;
  final Map<String, dynamic>? item;
  final Map<String, dynamic>? category;
  final String procedureId;
  final String procedureNom;
  final int frequenceJours;
  final String prochaineExecution;
  final bool estActif;
  final UserSimple? createdBy;
  final String? createdAt;
  final String? updatedAt;

  const RecurringTaskModel({
    required this.id,
    this.item,
    this.category,
    required this.procedureId,
    required this.procedureNom,
    required this.frequenceJours,
    required this.prochaineExecution,
    this.estActif = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Nom de l'article cible (null si la cible est une catégorie).
  String? get itemNom =>
      item != null ? item!['nom'] as String? : null;

  /// Nom de la catégorie cible (null si la cible est un article).
  String? get categoryNom =>
      category != null ? category!['nom'] as String? : null;

  /// Nom de la cible (article ou catégorie).
  String get cibleNom {
    if (item != null) {
      return item!['nom'] as String? ?? 'Article inconnu';
    }
    if (category != null) {
      return category!['nom'] as String? ?? 'Catégorie inconnue';
    }
    return 'Non défini';
  }

  /// Label de fréquence (ex: "Tous les 7 jours").
  String get frequenceLabel {
    if (frequenceJours == 1) return 'Quotidien';
    if (frequenceJours == 7) return 'Hebdomadaire';
    if (frequenceJours == 14) return 'Bi-hebdomadaire';
    if (frequenceJours == 30) return 'Mensuel';
    if (frequenceJours == 90) return 'Trimestriel';
    if (frequenceJours == 365) return 'Annuel';
    return 'Tous les $frequenceJours jours';
  }

  factory RecurringTaskModel.fromJson(Map<String, dynamic> json) =>
      RecurringTaskModel(
        id: json['id'] as String,
        item: json['item'] as Map<String, dynamic>?,
        category: json['category'] as Map<String, dynamic>?,
        procedureId: (json['procedure'] as String?) ?? '',
        procedureNom: (json['procedure_nom'] as String?) ?? '',
        frequenceJours: (json['frequence_jours'] as num?)?.toInt() ?? 7,
        prochaineExecution: (json['prochaine_execution'] as String?) ?? '',
        estActif: (json['est_actif'] as bool?) ?? true,
        createdBy: json['created_by'] != null
            ? UserSimple.fromJson(json['created_by'])
            : null,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}
