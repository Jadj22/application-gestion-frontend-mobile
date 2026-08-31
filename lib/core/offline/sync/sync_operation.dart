import 'dart:convert';

/// Nature d'une opération en attente.
enum SyncOperationType {
  create,
  update,
  delete,

  /// Action métier hors CRUD : clôturer une tâche, valider une réservation,
  /// avancer une étape. Ces opérations ne sont pas compactables entre elles
  /// car chacune porte un effet de bord propre côté serveur.
  action,

  /// Envoi de fichier (photo d'article ou d'étape) en multipart.
  upload,
}

/// Cycle de vie d'une opération dans la file.
enum SyncOperationStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict,
}

T _enumFromName<T extends Enum>(List<T> values, String name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

/// Une opération persistée dans la file de synchronisation.
///
/// Persistée en base : elle survit à la fermeture de l'application, au
/// redémarrage du téléphone et à une mise à jour de l'app.
class SyncOperation {
  /// Identifiant de l'opération (UUID v4).
  final String id;

  /// Ordre d'enfilement — matérialise l'ordre causal des actions utilisateur.
  /// `null` tant que l'opération n'a pas été écrite en base.
  final int? seq;

  final String scope;
  final String entityType;

  /// Identifiant de l'entité visée : local temporaire (`local:<uuid>`) tant
  /// que le serveur n'a pas attribué le sien.
  final String entityId;

  final SyncOperationType type;
  final String method;
  final String endpoint;
  final Map<String, dynamic>? payload;

  /// Fichier à envoyer pour une opération [SyncOperationType.upload].
  final String? filePath;
  final String? fileField;
  final Map<String, String>? fileFields;

  final SyncOperationStatus status;
  final int retryCount;

  /// Date avant laquelle il ne faut pas réessayer (backoff exponentiel).
  final DateTime? nextAttemptAt;

  final String? lastError;

  /// Ordre de passage : dérivé de l'entité (une catégorie avant un article).
  final int priority;

  /// Rejouer une opération avec la même clé ne doit produire qu'un seul effet
  /// côté serveur. C'est ce qui rend la synchronisation idempotente quand la
  /// réponse se perd alors que le serveur a déjà commité.
  final String idempotencyKey;

  /// Opérations qui doivent être synchronisées avant celle-ci (typiquement la
  /// création de l'entité que ce payload référence).
  final List<String> dependsOn;

  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncOperation({
    required this.id,
    this.seq,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.type,
    required this.method,
    required this.endpoint,
    this.payload,
    this.filePath,
    this.fileField,
    this.fileFields,
    this.status = SyncOperationStatus.pending,
    this.retryCount = 0,
    this.nextAttemptAt,
    this.lastError,
    this.priority = 100,
    required this.idempotencyKey,
    this.dependsOn = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == SyncOperationStatus.pending;

  /// L'opération est-elle prête à partir maintenant ? (backoff écoulé)
  bool readyAt(DateTime now) {
    if (status != SyncOperationStatus.pending) return false;
    final next = nextAttemptAt;
    return next == null || !next.isAfter(now);
  }

  SyncOperation copyWith({
    int? seq,
    String? entityId,
    String? endpoint,
    Map<String, dynamic>? payload,
    SyncOperationStatus? status,
    int? retryCount,
    DateTime? nextAttemptAt,
    String? lastError,
    List<String>? dependsOn,
    DateTime? updatedAt,
    bool clearNextAttempt = false,
    bool clearError = false,
  }) =>
      SyncOperation(
        id: id,
        seq: seq ?? this.seq,
        scope: scope,
        entityType: entityType,
        entityId: entityId ?? this.entityId,
        type: type,
        method: method,
        endpoint: endpoint ?? this.endpoint,
        payload: payload ?? this.payload,
        filePath: filePath,
        fileField: fileField,
        fileFields: fileFields,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        nextAttemptAt:
            clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
        lastError: clearError ? null : (lastError ?? this.lastError),
        priority: priority,
        idempotencyKey: idempotencyKey,
        dependsOn: dependsOn ?? this.dependsOn,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      );

  Map<String, Object?> toRow() => {
        'id': id,
        if (seq != null) 'seq': seq,
        'scope': scope,
        'entity_type': entityType,
        'entity_id': entityId,
        'op_type': type.name,
        'method': method,
        'endpoint': endpoint,
        'payload': payload == null ? null : jsonEncode(payload),
        'file_path': filePath,
        'file_field': fileField,
        'file_fields': fileFields == null ? null : jsonEncode(fileFields),
        'status': status.name,
        'retry_count': retryCount,
        'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
        'last_error': lastError,
        'priority': priority,
        'idempotency_key': idempotencyKey,
        'depends_on': jsonEncode(dependsOn),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory SyncOperation.fromRow(Map<String, Object?> row) {
    final payload = row['payload'] as String?;
    final fileFields = row['file_fields'] as String?;
    final dependsOn = row['depends_on'] as String?;
    final nextAttempt = row['next_attempt_at'] as String?;
    return SyncOperation(
      id: row['id'] as String,
      seq: row['seq'] as int?,
      scope: row['scope'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      type: _enumFromName(
        SyncOperationType.values,
        row['op_type'] as String,
        SyncOperationType.action,
      ),
      method: row['method'] as String,
      endpoint: row['endpoint'] as String,
      payload:
          payload == null ? null : jsonDecode(payload) as Map<String, dynamic>,
      filePath: row['file_path'] as String?,
      fileField: row['file_field'] as String?,
      fileFields: fileFields == null
          ? null
          : (jsonDecode(fileFields) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, '$v')),
      status: _enumFromName(
        SyncOperationStatus.values,
        row['status'] as String,
        SyncOperationStatus.pending,
      ),
      retryCount: row['retry_count'] as int? ?? 0,
      nextAttemptAt: nextAttempt == null ? null : DateTime.parse(nextAttempt),
      lastError: row['last_error'] as String?,
      priority: row['priority'] as int? ?? 100,
      idempotencyKey: row['idempotency_key'] as String,
      dependsOn: dependsOn == null
          ? const []
          : (jsonDecode(dependsOn) as List).map((e) => '$e').toList(),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
