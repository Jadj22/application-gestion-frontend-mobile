import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_database.dart';
import 'local_record.dart';

/// Accès aux documents métier de la base locale.
///
/// C'est la **source de vérité de l'interface** : les écrans lisent ici, jamais
/// directement l'API. Toutes les méthodes acceptent une [Transaction] pour que
/// l'écriture d'un document et l'enfilement de son opération de synchronisation
/// se fassent dans la même transaction.
class LocalStore {
  final LocalDatabase _database;

  LocalStore(this._database);

  DatabaseExecutor _exec(Transaction? txn) => txn ?? _database.db;

  /// Portée d'un enregistrement : le business, ou `global` hors multi-tenant.
  static String scopeOf(String? businessId) =>
      (businessId == null || businessId.isEmpty) ? 'global' : businessId;

  /// Identifiant d'un document renvoyé par l'API.
  ///
  /// Toutes les collections ne s'indexent pas sur `id` : `/stock/` renvoie des
  /// lignes agrégées par article, identifiées par `item_id` et **sans champ
  /// `id`**. Un seul point de vérité pour cette règle, car deux endroits qui
  /// identifiaient les documents différemment provoquaient l'effacement
  /// complet du stock local à chaque synchronisation.
  static String? identify(Map<String, dynamic> payload) {
    final id = payload['id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    final itemId = payload['item_id']?.toString();
    if (itemId != null && itemId.isNotEmpty) return itemId;
    return null;
  }

  /// Clé du marqueur de fraîcheur d'une collection.
  ///
  /// Partagée par la lecture d'écran et par la synchronisation de fond : deux
  /// clés différentes signifiaient que le moteur téléchargeait une collection
  /// sans que les écrans le sachent, et qu'ils la retéléchargeaient aussitôt.
  static String fetchKey(String entityType, String businessId) =>
      'fetched.$entityType.$businessId';

  /// Document complété de son identifiant quand l'API ne le fournit pas.
  static Map<String, dynamic> normalize(Map<String, dynamic> payload) {
    if (payload['id'] != null) return payload;
    final id = identify(payload);
    if (id == null) return payload;
    return {...payload, 'id': id};
  }

  // ── Lecture ──────────────────────────────────────────────────────────────

  /// Tous les documents visibles d'un type (suppressions logiques exclues).
  Future<List<LocalRecord>> list(
    String entityType, {
    String? businessId,
    bool includeDeleted = false,
    Transaction? txn,
  }) async {
    final where = StringBuffer('entity_type = ? AND scope = ?');
    final args = <Object?>[entityType, scopeOf(businessId)];
    if (!includeDeleted) where.write(' AND deleted = 0');

    final rows = await _exec(txn).query(
      'records',
      where: where.toString(),
      whereArgs: args,
    );
    return rows.map(LocalRecord.fromRow).toList();
  }

  /// Les documents d'un type, sous leur forme JSON, prêts pour `fromJson`.
  Future<List<Map<String, dynamic>>> listPayloads(
    String entityType, {
    String? businessId,
    Transaction? txn,
  }) async {
    final records = await list(entityType, businessId: businessId, txn: txn);
    return records.map((r) => r.payload).toList();
  }

  Future<LocalRecord?> find(
    String entityType,
    String id, {
    bool includeDeleted = false,
    Transaction? txn,
  }) async {
    final deletedClause = includeDeleted ? '' : ' AND deleted = 0';
    final rows = await _exec(txn).query(
      'records',
      where: 'entity_type = ? AND id = ?$deletedClause',
      whereArgs: [entityType, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalRecord.fromRow(rows.first);
  }

  Future<Map<String, dynamic>?> findPayload(
    String entityType,
    String id, {
    Transaction? txn,
  }) async =>
      (await find(entityType, id, txn: txn))?.payload;

  /// Nombre de documents encore en attente d'envoi, pour l'indicateur d'UI.
  Future<int> pendingCount({String? businessId, Transaction? txn}) async {
    final rows = await _exec(txn).rawQuery(
      'SELECT COUNT(*) AS n FROM records '
      'WHERE sync_state = ? AND scope = ?',
      [RecordSyncState.pending.name, scopeOf(businessId)],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<List<LocalRecord>> conflicted({
    String? businessId,
    Transaction? txn,
  }) async {
    final rows = await _exec(txn).query(
      'records',
      where: 'sync_state = ? AND scope = ?',
      whereArgs: [RecordSyncState.conflict.name, scopeOf(businessId)],
    );
    return rows.map(LocalRecord.fromRow).toList();
  }

  // ── Écriture ─────────────────────────────────────────────────────────────

  Future<void> put(LocalRecord record, {Transaction? txn}) async {
    await _exec(txn).insert(
      'records',
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Enregistre un document **venant du serveur** : il devient la nouvelle
  /// référence (`base_payload`) et l'état repasse à `synced`.
  Future<LocalRecord> putFromServer(
    String entityType,
    Map<String, dynamic> payload, {
    String? businessId,
    Transaction? txn,
  }) async {
    final id = payload['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('Document serveur sans identifiant : $entityType');
    }
    final record = LocalRecord(
      entityType: entityType,
      id: id,
      scope: scopeOf(businessId),
      payload: payload,
      basePayload: payload,
      localUpdatedAt: DateTime.now().toUtc(),
      serverUpdatedAt: _serverStamp(payload),
      syncState: RecordSyncState.synced,
    );
    await put(record, txn: txn);
    return record;
  }

  /// Enregistre un document **modifié localement** : il reste `pending` tant
  /// que le serveur ne l'a pas confirmé, et `base_payload` n'est pas touché.
  Future<LocalRecord> putLocal(
    String entityType,
    String id,
    Map<String, dynamic> payload, {
    String? businessId,
    bool localOnly = false,
    Map<String, dynamic>? basePayload,
    Transaction? txn,
  }) async {
    final existing = await find(entityType, id, includeDeleted: true, txn: txn);
    final record = LocalRecord(
      entityType: entityType,
      id: id,
      scope: scopeOf(businessId),
      payload: payload,
      basePayload: basePayload ?? existing?.basePayload,
      localUpdatedAt: DateTime.now().toUtc(),
      serverUpdatedAt: existing?.serverUpdatedAt,
      syncState: RecordSyncState.pending,
      localOnly: localOnly || (existing?.localOnly ?? false),
    );
    await put(record, txn: txn);
    return record;
  }

  /// Marque un document supprimé sans l'effacer : la ligne survit au
  /// redémarrage jusqu'à confirmation du serveur (§5, « une suppression hors
  /// ligne ne doit pas être perdue »).
  Future<void> markDeleted(
    String entityType,
    String id, {
    Transaction? txn,
  }) async {
    await _exec(txn).update(
      'records',
      {
        'deleted': 1,
        'sync_state': RecordSyncState.pending.name,
        'local_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_type = ? AND id = ?',
      whereArgs: [entityType, id],
    );
  }

  /// Efface physiquement une ligne (suppression confirmée par le serveur, ou
  /// annulation d'une création jamais partie).
  Future<void> purge(
    String entityType,
    String id, {
    Transaction? txn,
  }) async {
    await _exec(txn).delete(
      'records',
      where: 'entity_type = ? AND id = ?',
      whereArgs: [entityType, id],
    );
  }

  Future<void> markSynced(
    String entityType,
    String id, {
    Map<String, dynamic>? serverPayload,
    Transaction? txn,
  }) async {
    final values = <String, Object?>{
      'sync_state': RecordSyncState.synced.name,
      'local_only': 0,
    };
    if (serverPayload != null) {
      values['payload'] = jsonEncode(serverPayload);
      values['base_payload'] = jsonEncode(serverPayload);
      values['server_updated_at'] =
          _serverStamp(serverPayload)?.toIso8601String();
    }
    await _exec(txn).update(
      'records',
      values,
      where: 'entity_type = ? AND id = ?',
      whereArgs: [entityType, id],
    );
  }

  Future<void> markConflict(
    String entityType,
    String id, {
    Transaction? txn,
  }) async {
    await _exec(txn).update(
      'records',
      {'sync_state': RecordSyncState.conflict.name},
      where: 'entity_type = ? AND id = ?',
      whereArgs: [entityType, id],
    );
  }

  /// Réécrit un identifiant local temporaire en identifiant serveur.
  ///
  /// La clé primaire change : on ne peut pas faire un simple UPDATE si une
  /// ligne portant déjà l'identifiant serveur a été rapatriée entre-temps —
  /// d'où le `REPLACE` suivi de la suppression de l'ancienne ligne.
  Future<void> remapId(
    String entityType,
    String localId,
    String serverId, {
    Map<String, dynamic>? serverPayload,
    Transaction? txn,
  }) async {
    final record =
        await find(entityType, localId, includeDeleted: true, txn: txn);
    if (record == null) return;

    final promoted = record.copyWith(
      id: serverId,
      payload: serverPayload ?? {...record.payload, 'id': serverId},
      basePayload: serverPayload ?? record.basePayload,
      syncState: RecordSyncState.synced,
      localOnly: false,
      serverUpdatedAt:
          serverPayload == null ? record.serverUpdatedAt : _serverStamp(serverPayload),
    );
    await _exec(txn).insert(
      'records',
      promoted.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await purge(entityType, localId, txn: txn);
  }

  /// Remplace intégralement le contenu local d'un type par la vérité serveur,
  /// **sans toucher aux documents encore en attente d'envoi**.
  ///
  /// C'est ce qui rend un pull complet non destructif : une création ou une
  /// modification hors ligne n'est jamais écrasée par la liste du serveur qui,
  /// par définition, ne la contient pas encore.
  Future<void> replaceCollection(
    String entityType,
    List<Map<String, dynamic>> serverPayloads, {
    String? businessId,
    required Transaction txn,
  }) async {
    final scope = scopeOf(businessId);
    final serverIds = <String>{};

    for (final payload in serverPayloads) {
      final id = identify(payload);
      if (id == null) continue;
      serverIds.add(id);
    }

    // Les lignes locales à supprimer : celles qui étaient synchronisées et que
    // le serveur ne renvoie plus (supprimées par quelqu'un d'autre).
    final existing = await txn.query(
      'records',
      columns: ['id', 'sync_state', 'local_only'],
      where: 'entity_type = ? AND scope = ?',
      whereArgs: [entityType, scope],
    );
    for (final row in existing) {
      final id = row['id'] as String;
      final state = row['sync_state'] as String;
      final localOnly = (row['local_only'] as int? ?? 0) == 1;
      if (serverIds.contains(id)) continue;
      if (state == RecordSyncState.synced.name && !localOnly) {
        await txn.delete(
          'records',
          where: 'entity_type = ? AND id = ?',
          whereArgs: [entityType, id],
        );
      }
    }
  }

  DateTime? _serverStamp(Map<String, dynamic> payload) {
    final raw = payload['updated_at'] ?? payload['created_at'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  // ── Métadonnées de synchronisation ───────────────────────────────────────

  Future<String?> meta(String key, {Transaction? txn}) async {
    final rows = await _exec(txn).query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Supprime toutes les metadonnees commencant par [prefix].
  ///
  /// Sert a invalider en bloc les marqueurs de fraicheur et les agregats
  /// serveur apres une ecriture : sans cela, une lecture juste apres une
  /// modification renvoie la copie d'avant.
  Future<void> clearMeta(String prefix, {Transaction? txn}) async {
    await _exec(txn).delete(
      'sync_meta',
      where: 'key LIKE ?',
      whereArgs: ['$prefix%'],
    );
  }

  Future<void> setMeta(String key, String value, {Transaction? txn}) async {
    await _exec(txn).insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
