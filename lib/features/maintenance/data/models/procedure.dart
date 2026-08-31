/// Etape d'une procedure d'entretien — `ProcedureStepSerializer`.
class ProcedureStepModel {
  final String id;
  final String nom;
  final int ordre;
  final bool obligatoire;
  final String type; // OPERATION ou CONTROLE
  final String description;

  const ProcedureStepModel({
    required this.id,
    required this.nom,
    this.ordre = 0,
    this.obligatoire = true,
    this.type = 'OPERATION',
    this.description = '',
  });

  factory ProcedureStepModel.fromJson(Map<String, dynamic> json) =>
      ProcedureStepModel(
        id: json['id'] as String,
        nom: json['nom'] as String,
        ordre: (json['ordre'] as int?) ?? 0,
        obligatoire: (json['obligatoire'] as bool?) ?? true,
        type: (json['type'] as String?) ?? 'OPERATION',
        description: (json['description'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'ordre': ordre,
        'obligatoire': obligatoire,
        'type': type,
        'description': description,
      };

  bool get isOperation => type == 'OPERATION';
  bool get isControle => type == 'CONTROLE';

  ProcedureStepModel copyWith({
    String? id,
    String? nom,
    int? ordre,
    bool? obligatoire,
    String? type,
    String? description,
  }) =>
      ProcedureStepModel(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        ordre: ordre ?? this.ordre,
        obligatoire: obligatoire ?? this.obligatoire,
        type: type ?? this.type,
        description: description ?? this.description,
      );
}

/// Procedure d'entretien — `ProcedureSerializer` (US-13).
class ProcedureModel {
  final String id;
  final String nom;
  final String description;
  final bool estActif;
  final List<ProcedureStepModel> steps;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProcedureModel({
    required this.id,
    required this.nom,
    this.description = '',
    this.estActif = true,
    this.steps = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProcedureModel.fromJson(Map<String, dynamic> json) => ProcedureModel(
        id: json['id'] as String,
        nom: json['nom'] as String,
        description: (json['description'] as String?) ?? '',
        estActif: (json['est_actif'] as bool?) ?? true,
        steps: (json['steps'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ProcedureStepModel.fromJson)
                .toList() ??
            const [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'description': description,
        'est_actif': estActif,
        'steps_input': steps.map((s) => s.toJson()).toList(),
      };

  int get stepsCount => steps.length;
  int get operationsCount => steps.where((s) => s.isOperation).length;
  int get controlesCount => steps.where((s) => s.isControle).length;

  ProcedureModel copyWith({
    String? id,
    String? nom,
    String? description,
    bool? estActif,
    List<ProcedureStepModel>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProcedureModel(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        description: description ?? this.description,
        estActif: estActif ?? this.estActif,
        steps: steps ?? this.steps,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
