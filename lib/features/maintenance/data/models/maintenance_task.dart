import 'user_simple.dart';

/// Tâche d'entretien — `MaintenanceTaskSerializer` (US-15 à US-17).
class MaintenanceTaskModel {
  final String id;
  final String itemId;
  final String itemNom;
  final String procedureNom;
  final String motif;
  final String statut;
  final int etapesTotal;
  final int etapesFaites;
  final String etatArticle;
  final List<TaskStepModel> steps;
  final String? createdAt;
  // Sprint 1: Attribution
  final UserSimple? assignedTo;
  final String? assignedAt;
  final UserSimple? assignedBy;
  final UserSimple? createdBy;
  // Sprint 2: Coûts
  final double? coutMainOeuvre;
  final double? coutMateriel;
  final double? coutTotal;
  // Sprint 1: Commentaires
  final int commentsCount;
  // Sprint 6: Timer
  final int? dureeTotale;

  const MaintenanceTaskModel({
    required this.id,
    required this.itemId,
    required this.itemNom,
    required this.procedureNom,
    this.motif = '',
    required this.statut,
    this.etapesTotal = 0,
    this.etapesFaites = 0,
    this.etatArticle = '—',
    this.steps = const [],
    this.createdAt,
    this.assignedTo,
    this.assignedAt,
    this.assignedBy,
    this.createdBy,
    this.coutMainOeuvre,
    this.coutMateriel,
    this.coutTotal,
    this.commentsCount = 0,
    this.dureeTotale,
  });

  bool get estAssignee => assignedTo != null;

  bool get estTerminee => statut == 'TERMINEE';

  bool get estEnCours =>
      statut == 'EN_COURS' || statut == 'PARTIELLE';

  /// Progression en pourcentage (0 si aucune étape).
  int get progressValue =>
      etapesTotal == 0 ? 0 : (etapesFaites * 100 / etapesTotal).round();

  /// Libellé français du statut.
  String get statutLabel {
    switch (statut) {
      case 'EN_COURS':
        return 'EN COURS';
      case 'PARTIELLE':
        return 'PARTIELLE';
      case 'TERMINEE':
        return 'TERMINÉE';
      default:
        return statut;
    }
  }

  factory MaintenanceTaskModel.fromJson(Map<String, dynamic> json) {
    final etapes = (json['etapes'] as Map<String, dynamic>?) ?? const {};
    return MaintenanceTaskModel(
      id: json['id'] as String,
      itemId: (json['item_id'] as String?) ?? '',
      itemNom: (json['item_nom'] as String?) ?? '',
      procedureNom: (json['procedure_nom'] as String?) ?? '',
      motif: (json['motif'] as String?) ?? '',
      statut: (json['statut'] as String?) ?? 'EN_COURS',
      etapesTotal: (etapes['total'] as num?)?.toInt() ?? 0,
      etapesFaites: (etapes['faites'] as num?)?.toInt() ?? 0,
      etatArticle: _libelleEtat(json['etat_article']),
      steps: ((json['steps'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TaskStepModel.fromJson)
          .toList(),
      createdAt: json['created_at'] as String?,
      // Sprint 1: Attribution
      assignedTo: json['assigned_to'] != null
          ? UserSimple.fromJson(json['assigned_to'])
          : null,
      assignedAt: json['assigned_at'] as String?,
      assignedBy: json['assigned_by'] != null
          ? UserSimple.fromJson(json['assigned_by'])
          : null,
      createdBy: json['created_by'] != null
          ? UserSimple.fromJson(json['created_by'])
          : null,
      // Sprint 2: Coûts
      coutMainOeuvre: (json['cout_main_oeuvre'] as num?)?.toDouble(),
      coutMateriel: (json['cout_materiel'] as num?)?.toDouble(),
      coutTotal: (json['cout_total'] as num?)?.toDouble(),
      // Sprint 1: Commentaires
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      // Sprint 6: Timer
      dureeTotale: (json['duree_totale'] as num?)?.toInt(),
    );
  }

  static String _libelleEtat(dynamic etat) {
    if (etat is Map<String, dynamic>) {
      return ((etat['libelle'] as String?) ?? '').toUpperCase();
    }
    return '—';
  }
}

/// Étape d'une tâche — `TaskStepSerializer` (US-16).
class TaskStepModel {
  final String id;
  final String nom;
  final int ordre;
  final bool obligatoire;
  final String type;
  final String statut;
  final String? startedAt;
  final String? finishedAt;
  final UserSimple? doneBy;
  // Sprint 6: Durée
  final int? dureeEstimeeSecondes;
  final int? dureeReelle;
  // Sprint 2: Photos
  final List<TaskStepPhotoModel> photos;

  const TaskStepModel({
    required this.id,
    required this.nom,
    this.ordre = 0,
    this.obligatoire = true,
    this.type = 'OPERATION',
    this.statut = 'EN_ATTENTE',
    this.startedAt,
    this.finishedAt,
    this.doneBy,
    this.dureeEstimeeSecondes,
    this.dureeReelle,
    this.photos = const [],
  });

  bool get estTerminee => statut == 'TERMINE';
  bool get estEnCours => statut == 'EN_COURS';
  bool get estEnAttente => statut == 'EN_ATTENTE';
  bool get estControle => type == 'CONTROLE';

  /// Durée formatée (ex: "5min 30s")
  String? get dureeFormatee {
    if (dureeReelle == null) return null;
    final minutes = dureeReelle! ~/ 60;
    final secondes = dureeReelle! % 60;
    if (minutes > 0) {
      return '${minutes}min ${secondes}s';
    }
    return '${secondes}s';
  }

  factory TaskStepModel.fromJson(Map<String, dynamic> json) => TaskStepModel(
        id: json['id'] as String,
        nom: (json['nom'] as String?) ?? '',
        ordre: (json['ordre'] as num?)?.toInt() ?? 0,
        obligatoire: (json['obligatoire'] as bool?) ?? true,
        type: (json['type'] as String?) ?? 'OPERATION',
        statut: (json['statut'] as String?) ?? 'EN_ATTENTE',
        startedAt: json['started_at'] as String?,
        finishedAt: json['finished_at'] as String?,
        doneBy: json['done_by'] != null
            ? UserSimple.fromJson(json['done_by'])
            : null,
        dureeEstimeeSecondes: (json['duree_estimee_secondes'] as num?)?.toInt(),
        dureeReelle: (json['duree_reelle'] as num?)?.toInt(),
        photos: ((json['photos'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TaskStepPhotoModel.fromJson)
            .toList(),
      );
}


/// Photo d'une étape de tâche — Sprint 2.
class TaskStepPhotoModel {
  final String id;
  final String imageUrl;
  final String type; // AVANT ou APRES
  final String caption;
  final UserSimple? uploadedBy;
  final String? createdAt;

  const TaskStepPhotoModel({
    required this.id,
    required this.imageUrl,
    required this.type,
    this.caption = '',
    this.uploadedBy,
    this.createdAt,
  });

  bool get estAvant => type == 'AVANT';
  bool get estApres => type == 'APRES';

  factory TaskStepPhotoModel.fromJson(Map<String, dynamic> json) =>
      TaskStepPhotoModel(
        id: json['id'] as String,
        imageUrl: (json['image'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'AVANT',
        caption: (json['caption'] as String?) ?? '',
        uploadedBy: json['uploaded_by'] != null
            ? UserSimple.fromJson(json['uploaded_by'])
            : null,
        createdAt: json['created_at'] as String?,
      );
}


/// Commentaire sur une tâche — Sprint 1.
class TaskCommentModel {
  final String id;
  final UserSimple auteur;
  final String contenu;
  final String? createdAt;
  final String? updatedAt;

  const TaskCommentModel({
    required this.id,
    required this.auteur,
    required this.contenu,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskCommentModel.fromJson(Map<String, dynamic> json) =>
      TaskCommentModel(
        id: json['id'] as String,
        auteur: UserSimple.fromJson(json['auteur']),
        contenu: (json['contenu'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}