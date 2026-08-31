import 'dart:convert';

/// État de synchronisation d'un enregistrement local.
enum RecordSyncState {
  /// Identique à la dernière version connue du serveur.
  synced,

  /// Modifié localement, en attente d'envoi.
  pending,

  /// Le serveur a rejeté ou divergé : arbitrage nécessaire.
  conflict,
}

RecordSyncState _stateFromName(String value) => RecordSyncState.values
    .firstWhere((s) => s.name == value, orElse: () => RecordSyncState.synced);

/// Un document métier stocké localement.
///
/// Le contenu ([payload]) est le JSON **tel que l'API le renvoie**. C'est un
/// choix délibéré : les modèles du projet n'exposent que `fromJson`, donc en
/// conservant la forme serveur on réutilise les modèles existants sans écrire
/// un seul `toJson`, et sans dupliquer le schéma dans la base locale.
class LocalRecord {
  final String entityType;
  final String id;

  /// Cloisonnement multi-tenant : identifiant du business, ou `global`.
  final String scope;

  /// Document courant, celui que l'interface affiche.
  final Map<String, dynamic> payload;

  /// Dernière version connue du serveur, figée au moment du dernier pull.
  ///
  /// Sert de base commune à la fusion trois voies : `base` → local d'un côté,
  /// `base` → serveur de l'autre. Sans elle, impossible de distinguer « le
  /// champ n'a pas changé » de « le champ a été remis à sa valeur d'origine ».
  final Map<String, dynamic>? basePayload;

  /// Horodatage local de la dernière écriture.
  final DateTime localUpdatedAt;

  /// `updated_at` renvoyé par le serveur pour cette version.
  final DateTime? serverUpdatedAt;

  final RecordSyncState syncState;

  /// Suppression logique : la ligne reste en base tant que le DELETE n'a pas
  /// été confirmé par le serveur, pour qu'un redémarrage ne l'oublie pas.
  final bool deleted;

  /// Créé hors ligne et jamais accepté par le serveur : son [id] est encore un
  /// identifiant local temporaire.
  final bool localOnly;

  const LocalRecord({
    required this.entityType,
    required this.id,
    required this.scope,
    required this.payload,
    this.basePayload,
    required this.localUpdatedAt,
    this.serverUpdatedAt,
    this.syncState = RecordSyncState.synced,
    this.deleted = false,
    this.localOnly = false,
  });

  bool get isPending => syncState == RecordSyncState.pending;
  bool get isConflicted => syncState == RecordSyncState.conflict;

  LocalRecord copyWith({
    Map<String, dynamic>? payload,
    Map<String, dynamic>? basePayload,
    DateTime? localUpdatedAt,
    DateTime? serverUpdatedAt,
    RecordSyncState? syncState,
    bool? deleted,
    bool? localOnly,
    String? id,
  }) =>
      LocalRecord(
        entityType: entityType,
        id: id ?? this.id,
        scope: scope,
        payload: payload ?? this.payload,
        basePayload: basePayload ?? this.basePayload,
        localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
        serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
        syncState: syncState ?? this.syncState,
        deleted: deleted ?? this.deleted,
        localOnly: localOnly ?? this.localOnly,
      );

  Map<String, Object?> toRow() => {
        'entity_type': entityType,
        'id': id,
        'scope': scope,
        'payload': jsonEncode(payload),
        'base_payload': basePayload == null ? null : jsonEncode(basePayload),
        'local_updated_at': localUpdatedAt.toUtc().toIso8601String(),
        'server_updated_at': serverUpdatedAt?.toUtc().toIso8601String(),
        'sync_state': syncState.name,
        'deleted': deleted ? 1 : 0,
        'local_only': localOnly ? 1 : 0,
      };

  factory LocalRecord.fromRow(Map<String, Object?> row) {
    final base = row['base_payload'] as String?;
    final serverUpdatedAt = row['server_updated_at'] as String?;
    return LocalRecord(
      entityType: row['entity_type'] as String,
      id: row['id'] as String,
      scope: row['scope'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      basePayload:
          base == null ? null : jsonDecode(base) as Map<String, dynamic>,
      localUpdatedAt: DateTime.parse(row['local_updated_at'] as String),
      serverUpdatedAt:
          serverUpdatedAt == null ? null : DateTime.parse(serverUpdatedAt),
      syncState: _stateFromName(row['sync_state'] as String),
      deleted: (row['deleted'] as int? ?? 0) == 1,
      localOnly: (row['local_only'] as int? ?? 0) == 1,
    );
  }
}
