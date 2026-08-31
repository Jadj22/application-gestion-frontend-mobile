import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/local_database.dart';
import 'sync_operation.dart';

/// File d'attente persistante des opérations à pousser vers le serveur.
///
/// Deux garanties portées par cette classe :
///
/// 1. **Durabilité** — une opération enfilée est écrite en base dans la même
///    transaction que la donnée qu'elle décrit. Fermer l'application, tuer le
///    processus ou redémarrer le téléphone ne peut pas la faire disparaître.
/// 2. **Compaction** — la file est réduite avant l'envoi, pour qu'une rafale
///    de modifications hors ligne ne devienne pas une rafale de requêtes.
class SyncQueue {
  static const _uuid = Uuid();

  final LocalDatabase _database;

  SyncQueue(this._database);

  DatabaseExecutor _exec(Transaction? txn) => txn ?? _database.db;

  static String newOperationId() => _uuid.v4();

  /// Préfixe des identifiants attribués localement, avant que le serveur n'ait
  /// donné le sien. Reconnaissable pour ne jamais partir tel quel vers l'API.
  static const String localIdPrefix = 'local:';

  static String newLocalId() => '$localIdPrefix${_uuid.v4()}';

  static bool isLocalId(String? id) =>
      id != null && id.startsWith(localIdPrefix);

  // ── Enfilement ───────────────────────────────────────────────────────────

  /// Ajoute une opération à la file et renvoie sa version persistée.
  ///
  /// [txn] doit être la transaction qui écrit aussi le document local : c'est
  /// cette atomicité qui garantit qu'on n'a jamais une donnée sans son
  /// opération, ni l'inverse.
  Future<SyncOperation> enqueue(
    SyncOperation operation, {
    Transaction? txn,
  }) async {
    final seq = await _exec(txn).insert('sync_ops', operation.toRow());
    return operation.copyWith(seq: seq);
  }

  // ── Lecture ──────────────────────────────────────────────────────────────

  /// Opérations prêtes à partir, dans l'ordre : priorité d'entité puis ordre
  /// d'enfilement. Les opérations dont le backoff n'est pas écoulé sont
  /// exclues.
  Future<List<SyncOperation>> ready({
    String? scope,
    DateTime? now,
    Transaction? txn,
  }) async {
    final at = (now ?? DateTime.now().toUtc()).toIso8601String();
    final where = StringBuffer(
      'status = ? AND (next_attempt_at IS NULL OR next_attempt_at <= ?)',
    );
    final args = <Object?>[SyncOperationStatus.pending.name, at];
    if (scope != null) {
      where.write(' AND scope = ?');
      args.add(scope);
    }
    final rows = await _exec(txn).query(
      'sync_ops',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'priority ASC, seq ASC',
    );
    return rows.map(SyncOperation.fromRow).toList();
  }

  /// Toutes les opérations non terminées (y compris celles en backoff) : c'est
  /// ce que l'utilisateur voit sous « N modifications en attente ».
  Future<List<SyncOperation>> outstanding({
    String? scope,
    Transaction? txn,
  }) async {
    final where = StringBuffer('status IN (?, ?, ?)');
    final args = <Object?>[
      SyncOperationStatus.pending.name,
      SyncOperationStatus.syncing.name,
      SyncOperationStatus.failed.name,
    ];
    if (scope != null) {
      where.write(' AND scope = ?');
      args.add(scope);
    }
    final rows = await _exec(txn).query(
      'sync_ops',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'priority ASC, seq ASC',
    );
    return rows.map(SyncOperation.fromRow).toList();
  }

  Future<int> outstandingCount({String? scope, Transaction? txn}) async {
    final args = <Object?>[
      SyncOperationStatus.pending.name,
      SyncOperationStatus.syncing.name,
      SyncOperationStatus.failed.name,
    ];
    var sql = 'SELECT COUNT(*) AS n FROM sync_ops WHERE status IN (?, ?, ?)';
    if (scope != null) {
      sql += ' AND scope = ?';
      args.add(scope);
    }
    final rows = await _exec(txn).rawQuery(sql, args);
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<int> failedCount({String? scope, Transaction? txn}) async {
    final args = <Object?>[SyncOperationStatus.failed.name];
    var sql = 'SELECT COUNT(*) AS n FROM sync_ops WHERE status = ?';
    if (scope != null) {
      sql += ' AND scope = ?';
      args.add(scope);
    }
    final rows = await _exec(txn).rawQuery(sql, args);
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Retrouve une opération par son identifiant, quel que soit son état.
  ///
  /// Renvoie null si elle a abouti : le moteur la retire de la file dès que
  /// le serveur l'a acceptée.
  Future<SyncOperation?> findById(String id, {Transaction? txn}) async {
    final rows = await _exec(txn).query(
      'sync_ops',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncOperation.fromRow(rows.first);
  }

  /// Opérations encore en attente qui visent une entité donnée.
  Future<List<SyncOperation>> forEntity(
    String entityType,
    String entityId, {
    Transaction? txn,
  }) async {
    final rows = await _exec(txn).query(
      'sync_ops',
      where: 'entity_type = ? AND entity_id = ? AND status IN (?, ?, ?)',
      whereArgs: [
        entityType,
        entityId,
        SyncOperationStatus.pending.name,
        SyncOperationStatus.syncing.name,
        SyncOperationStatus.failed.name,
      ],
      orderBy: 'seq ASC',
    );
    return rows.map(SyncOperation.fromRow).toList();
  }

  // ── Transitions d'état ───────────────────────────────────────────────────

  Future<void> update(SyncOperation operation, {Transaction? txn}) async {
    await _exec(txn).update(
      'sync_ops',
      operation.copyWith(updatedAt: DateTime.now().toUtc()).toRow(),
      where: 'id = ?',
      whereArgs: [operation.id],
    );
  }

  Future<void> markSyncing(SyncOperation operation, {Transaction? txn}) =>
      update(operation.copyWith(status: SyncOperationStatus.syncing), txn: txn);

  /// L'opération a abouti : on la retire de la file.
  ///
  /// On supprime plutôt qu'on archive : garder un historique complet ferait
  /// grossir la base indéfiniment sans usage réel. Le journal des activités du
  /// backend joue déjà ce rôle.
  Future<void> complete(String operationId, {Transaction? txn}) async {
    await _exec(txn).delete(
      'sync_ops',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Échec réseau ou serveur temporaire : on replanifie avec un délai croissant.
  ///
  /// Le backoff est exponentiel et plafonné : une panne serveur de plusieurs
  /// heures ne doit ni vider la batterie, ni faire perdre l'opération.
  Future<SyncOperation> reschedule(
    SyncOperation operation,
    String error, {
    Transaction? txn,
  }) async {
    final retry = operation.retryCount + 1;
    final updated = operation.copyWith(
      status: SyncOperationStatus.pending,
      retryCount: retry,
      nextAttemptAt: DateTime.now().toUtc().add(backoffFor(retry)),
      lastError: error,
    );
    await update(updated, txn: txn);
    return updated;
  }

  /// Échec définitif (rejet métier du serveur) : l'opération reste en base,
  /// visible, mais ne repart pas toute seule. L'utilisateur doit trancher.
  Future<SyncOperation> markFailed(
    SyncOperation operation,
    String error, {
    Transaction? txn,
  }) async {
    final updated = operation.copyWith(
      status: SyncOperationStatus.failed,
      lastError: error,
      retryCount: operation.retryCount + 1,
    );
    await update(updated, txn: txn);
    return updated;
  }

  Future<SyncOperation> markConflict(
    SyncOperation operation,
    String reason, {
    Transaction? txn,
  }) async {
    final updated = operation.copyWith(
      status: SyncOperationStatus.conflict,
      lastError: reason,
    );
    await update(updated, txn: txn);
    return updated;
  }

  /// Remet les opérations en échec dans la file (action utilisateur
  /// « Réessayer »).
  Future<void> retryFailed({String? scope, Transaction? txn}) async {
    final args = <Object?>[SyncOperationStatus.failed.name];
    var where = 'status = ?';
    if (scope != null) {
      where += ' AND scope = ?';
      args.add(scope);
    }
    await _exec(txn).update(
      'sync_ops',
      {
        'status': SyncOperationStatus.pending.name,
        'retry_count': 0,
        'next_attempt_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: where,
      whereArgs: args,
    );
  }

  /// Remet en `pending` les opérations laissées en `syncing` par un arrêt
  /// brutal de l'application. Appelé au démarrage : sans cela, une opération
  /// interrompue resterait bloquée pour toujours.
  Future<int> recoverInterrupted({Transaction? txn}) async {
    return _exec(txn).update(
      'sync_ops',
      {
        'status': SyncOperationStatus.pending.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [SyncOperationStatus.syncing.name],
    );
  }

  /// Réécrit un identifiant local en identifiant serveur dans toutes les
  /// opérations encore en file : cible, chemin d'appel et références du
  /// payload. Appelé dès que le serveur a accepté une création.
  Future<void> remapLocalId(
    String localId,
    String serverId, {
    Transaction? txn,
  }) async {
    final exec = _exec(txn);
    final rows = await exec.query(
      'sync_ops',
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        SyncOperationStatus.pending.name,
        SyncOperationStatus.syncing.name,
        SyncOperationStatus.failed.name,
      ],
    );

    for (final row in rows) {
      final operation = SyncOperation.fromRow(row);
      final rewritten = rewriteId(operation, localId, serverId);
      if (rewritten == null) continue;
      await exec.update(
        'sync_ops',
        rewritten.toRow(),
        where: 'id = ?',
        whereArgs: [rewritten.id],
      );
    }
  }

  /// Renvoie l'opération avec [localId] remplacé partout, ou null si elle ne
  /// contient pas cet identifiant (rien à écrire).
  static SyncOperation? rewriteId(
    SyncOperation operation,
    String localId,
    String serverId,
  ) {
    var touched = false;

    final entityId = operation.entityId == localId ? serverId : operation.entityId;
    if (entityId != operation.entityId) touched = true;

    final endpoint = operation.endpoint.contains(localId)
        ? operation.endpoint.replaceAll(localId, serverId)
        : operation.endpoint;
    if (endpoint != operation.endpoint) touched = true;

    Map<String, dynamic>? payload = operation.payload;
    if (payload != null) {
      final rewritten = <String, dynamic>{};
      var payloadTouched = false;
      payload.forEach((key, value) {
        if (value == localId) {
          rewritten[key] = serverId;
          payloadTouched = true;
        } else {
          rewritten[key] = value;
        }
      });
      if (payloadTouched) {
        payload = rewritten;
        touched = true;
      }
    }

    if (!touched) return null;
    return operation.copyWith(
      entityId: entityId,
      endpoint: endpoint,
      payload: payload,
    );
  }

  // ── Backoff ──────────────────────────────────────────────────────────────

  /// Délai avant la [retry]-ième tentative : 5 s, 15 s, 45 s, 2 min, 6 min…
  /// plafonné à 30 minutes.
  static Duration backoffFor(int retry) {
    const base = Duration(seconds: 5);
    const cap = Duration(minutes: 30);
    var delay = base;
    for (var i = 1; i < retry && delay < cap; i++) {
      delay *= 3;
    }
    return delay > cap ? cap : delay;
  }
}
