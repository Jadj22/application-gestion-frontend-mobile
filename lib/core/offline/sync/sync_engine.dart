import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../network/api_client.dart';
import '../connectivity/connectivity_service.dart';
import '../db/local_database.dart';
import '../db/local_record.dart';
import '../db/local_store.dart';
import '../entity_registry.dart';
import 'conflict_resolver.dart';
import 'id_map.dart';
import 'sync_compactor.dart';
import 'sync_operation.dart';
import 'sync_queue.dart';

// Les champs sont prives mais l'injection reste nommee pour la lisibilite :
// un parametre nomme ne peut pas s'appeler `_xxx`, donc pas de formel
// initialisant possible ici.
// ignore_for_file: prefer_initializing_formals

/// État global de la synchronisation, tel que l'UI l'affiche.
enum SyncState {
  /// Tout est synchronisé, rien en attente.
  idle,

  /// Synchronisation en cours.
  syncing,

  /// Hors ligne : des opérations attendent le retour du réseau.
  offline,

  /// Au moins une opération a échoué ou est en conflit.
  error,
}

/// Bilan d'un cycle de synchronisation.
class SyncReport {
  final int pushed;
  final int compacted;
  final int failed;
  final int conflicts;
  final int pulled;
  final Object? error;

  const SyncReport({
    this.pushed = 0,
    this.compacted = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.pulled = 0,
    this.error,
  });

  bool get isSuccess => error == null && failed == 0 && conflicts == 0;
}

/// Orchestrateur de la synchronisation locale ↔ serveur.
///
/// Un cycle complet, dans cet ordre :
///
/// 1. **Compaction** — la file est réduite (CREATE+UPDATE ⇒ CREATE, CREATE puis
///    DELETE ⇒ rien) avant de toucher au réseau.
/// 2. **Push** — les opérations partent dans l'ordre causal, avec leur clé
///    d'idempotence. Chaque création acceptée déclenche la réécriture de son
///    identifiant local dans toute la file et toute la base.
/// 3. **Pull** — les collections du serveur sont rapatriées, sans jamais
///    écraser un document encore en attente d'envoi.
///
/// Le moteur est **réentrant-safe** : deux déclencheurs concurrents (retour du
/// réseau + ouverture d'un écran) partagent le même cycle plutôt que d'en
/// lancer deux.
class SyncEngine extends ChangeNotifier {
  final LocalDatabase _database;
  final LocalStore _store;
  final SyncQueue _queue;
  final IdMap _idMap;
  final ApiClient _api;
  final ConnectivityService _connectivity;
  final ConflictResolver _resolver;
  final SyncCompactor _compactor;

  SyncEngine({
    required LocalDatabase database,
    required LocalStore store,
    required SyncQueue queue,
    required IdMap idMap,
    required ApiClient api,
    required ConnectivityService connectivity,
    ConflictResolver resolver = const ConflictResolver(),
    SyncCompactor compactor = const SyncCompactor(),
  })  : _database = database,
        _store = store,
        _queue = queue,
        _idMap = idMap,
        _api = api,
        _connectivity = connectivity,
        _resolver = resolver,
        _compactor = compactor;

  SyncState _state = SyncState.idle;
  int _pendingCount = 0;
  int _failedCount = 0;
  DateTime? _lastSyncAt;
  String? _lastError;
  String? _businessId;

  Future<SyncReport>? _inFlight;
  StreamSubscription<void>? _backOnlineSubscription;

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  bool get hasPending => _pendingCount > 0;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  bool get isOnline => _connectivity.isOnline;

  /// Business actif : borne la synchronisation au tenant courant.
  String? get businessId => _businessId;

  set businessId(String? value) {
    if (_businessId == value) return;
    _businessId = value;
    unawaited(refreshCounters());
  }

  String get _scope => LocalStore.scopeOf(_businessId);

  /// Branche la reprise automatique : dès que le réseau revient, on vide la
  /// file sans que l'utilisateur ait quoi que ce soit à faire.
  Future<void> start() async {
    // Une opération laissée en « syncing » par une application tuée doit
    // repartir, sinon elle resterait bloquée indéfiniment.
    await _queue.recoverInterrupted();
    await refreshCounters();

    _backOnlineSubscription = _connectivity.onBackOnline.listen((_) {
      unawaited(sync(reason: 'retour du réseau'));
    });
    _connectivity.addListener(_onConnectivityChanged);
    _onConnectivityChanged();
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOffline && _state != SyncState.syncing) {
      _setState(_failedCount > 0 ? SyncState.error : SyncState.offline);
    } else if (_connectivity.isOnline && _state == SyncState.offline) {
      _setState(_pendingCount > 0 ? SyncState.syncing : SyncState.idle);
    }
  }

  /// Lance un cycle complet. Les appels concurrents partagent le même cycle.
  Future<SyncReport> sync({
    String reason = 'manuel',
    bool pull = true,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _runSync(reason: reason, pull: pull);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<SyncReport> _runSync({
    required String reason,
    required bool pull,
  }) async {
    if (!_connectivity.isOnline) {
      final reachable = await _connectivity.probe();
      if (!reachable) {
        await refreshCounters();
        _setState(_failedCount > 0 ? SyncState.error : SyncState.offline);
        return const SyncReport();
      }
    }

    _setState(SyncState.syncing);
    _lastError = null;

    var report = const SyncReport();
    try {
      report = await _push();
      if (pull && _businessId != null) {
        final pulled = await _pull();
        report = SyncReport(
          pushed: report.pushed,
          compacted: report.compacted,
          failed: report.failed,
          conflicts: report.conflicts,
          pulled: pulled,
        );
      }
      _lastSyncAt = DateTime.now();
      await _store.setMeta('last_sync_at', _lastSyncAt!.toIso8601String());
    } on NetworkUnavailableException catch (error) {
      // Le réseau est retombé au milieu du cycle : ce n'est pas une erreur, la
      // file reste intacte et repartira au prochain retour.
      _connectivity.reportNetworkFailure();
      report = SyncReport(error: error);
    } catch (error, stack) {
      debugPrint('Sync ($reason) a échoué : $error\n$stack');
      _lastError = '$error';
      report = SyncReport(error: error);
    }

    await refreshCounters();
    if (!_connectivity.isOnline) {
      _setState(SyncState.offline);
    } else if (_failedCount > 0 || report.conflicts > 0) {
      _setState(SyncState.error);
    } else {
      _setState(SyncState.idle);
    }
    return report;
  }

  // ── Push ─────────────────────────────────────────────────────────────────

  Future<SyncReport> _push() async {
    final pending = await _queue.ready(scope: _scope);
    if (pending.isEmpty) return const SyncReport();

    final compaction = _compactor.compact(pending);

    // Les opérations écartées et les entités « nées puis mortes » hors ligne
    // sont retirées avant tout appel réseau : elles n'ont rien à y faire.
    if (compaction.discardedIds.isNotEmpty || compaction.vanished.isNotEmpty) {
      await _database.transaction((txn) async {
        for (final id in compaction.discardedIds) {
          await _queue.complete(id, txn: txn);
        }
        for (final entity in compaction.vanished) {
          await _store.purge(entity.entityType, entity.entityId, txn: txn);
        }
      });
    }

    var pushed = 0;
    var failed = 0;
    var conflicts = 0;

    for (final operation in compaction.operations) {
      final outcome = await _pushOne(operation);
      switch (outcome) {
        case _PushOutcome.success:
          pushed++;
        case _PushOutcome.retry:
          // Réseau : on arrête le cycle, la file repartira intacte. Continuer
          // ne ferait qu'accumuler des échecs identiques.
          return SyncReport(
            pushed: pushed,
            compacted: compaction.savedRequests,
            failed: failed,
            conflicts: conflicts,
          );
        case _PushOutcome.failed:
          failed++;
        case _PushOutcome.conflict:
          conflicts++;
      }
      await refreshCounters(notify: false);
    }

    return SyncReport(
      pushed: pushed,
      compacted: compaction.savedRequests,
      failed: failed,
      conflicts: conflicts,
    );
  }

  Future<_PushOutcome> _pushOne(SyncOperation operation) async {
    // L'entité visée a-t-elle reçu son identifiant serveur entre-temps ?
    final resolved = await _resolveReferences(operation);

    // Une opération qui référence encore une création jamais partie ne peut
    // pas aboutir : on la laisse en file plutôt que d'envoyer un identifiant
    // que le serveur ne connaît pas.
    if (_hasUnresolvedReference(resolved)) {
      await _queue.reschedule(
        resolved,
        'En attente de la création de l\'élément référencé.',
      );
      return _PushOutcome.failed;
    }

    await _queue.markSyncing(resolved);

    try {
      final response = await _execute(resolved);
      await _applySuccess(resolved, response);
      _connectivity.reportSuccess();
      return _PushOutcome.success;
    } on NetworkUnavailableException catch (error) {
      await _queue.reschedule(resolved, error.message);
      _connectivity.reportNetworkFailure();
      return _PushOutcome.retry;
    } on ApiException catch (error) {
      return _handleApiError(resolved, error);
    } catch (error) {
      await _queue.reschedule(resolved, '$error');
      return _PushOutcome.retry;
    }
  }

  Future<dynamic> _execute(SyncOperation operation) {
    switch (operation.type) {
      case SyncOperationType.upload:
        final path = operation.filePath;
        if (path == null) {
          throw const ApiException(400, 'Fichier introuvable pour cet envoi.');
        }
        return _api.uploadFile(
          operation.endpoint,
          filePath: path,
          field: operation.fileField ?? 'image',
          fields: operation.fileFields,
          idempotencyKey: operation.idempotencyKey,
          method: operation.method,
        );

      case SyncOperationType.delete:
        return _api.delete(
          operation.endpoint,
          idempotencyKey: operation.idempotencyKey,
        );

      case SyncOperationType.update:
        return _api.patch(
          operation.endpoint,
          body: operation.payload,
          idempotencyKey: operation.idempotencyKey,
        );

      case SyncOperationType.create:
        return _api.post(
          operation.endpoint,
          body: operation.payload,
          idempotencyKey: operation.idempotencyKey,
        );

      case SyncOperationType.action:
        // Une action metier n'est pas toujours un POST : avancer une etape
        // d'entretien est un PATCH, retirer une photo un DELETE. Le verbe est
        // porte par l'operation ; l'ignorer produisait des 405 en boucle sur
        // des operations qui ne pouvaient jamais aboutir.
        return _sendWithMethod(operation);
    }
  }

  /// Envoie une action en respectant le verbe HTTP qu'elle declare.
  Future<dynamic> _sendWithMethod(SyncOperation operation) {
    switch (operation.method.toUpperCase()) {
      case 'PATCH':
        return _api.patch(
          operation.endpoint,
          body: operation.payload,
          idempotencyKey: operation.idempotencyKey,
        );
      case 'DELETE':
        return _api.delete(
          operation.endpoint,
          idempotencyKey: operation.idempotencyKey,
        );
      default:
        return _api.post(
          operation.endpoint,
          body: operation.payload,
          idempotencyKey: operation.idempotencyKey,
        );
    }
  }

  Future<void> _applySuccess(SyncOperation operation, dynamic response) async {
    final serverPayload =
        response is Map<String, dynamic> ? response : null;

    await _database.transaction((txn) async {
      switch (operation.type) {
        case SyncOperationType.create:
          final serverId = serverPayload?['id']?.toString();
          if (SyncQueue.isLocalId(operation.entityId) && serverId != null) {
            // Le serveur a attribué son identifiant : on le propage partout,
            // y compris dans les opérations encore en file qui référencent
            // l'ancien identifiant local.
            await _idMap.record(
              operation.entityType,
              operation.entityId,
              serverId,
              txn: txn,
            );
            await _store.remapId(
              operation.entityType,
              operation.entityId,
              serverId,
              serverPayload: serverPayload,
              txn: txn,
            );
            await _queue.remapLocalId(operation.entityId, serverId, txn: txn);
          } else if (serverPayload != null) {
            await _store.markSynced(
              operation.entityType,
              operation.entityId,
              serverPayload: serverPayload,
              txn: txn,
            );
          }

        case SyncOperationType.update:
        case SyncOperationType.action:
          await _store.markSynced(
            operation.entityType,
            operation.entityId,
            serverPayload: serverPayload,
            txn: txn,
          );

        case SyncOperationType.delete:
          // Confirmée par le serveur : la ligne locale peut enfin disparaître.
          await _store.purge(operation.entityType, operation.entityId, txn: txn);

        case SyncOperationType.upload:
          await _store.markSynced(
            operation.entityType,
            operation.entityId,
            txn: txn,
          );
      }

      await _queue.complete(operation.id, txn: txn);
    });
  }

  Future<_PushOutcome> _handleApiError(
    SyncOperation operation,
    ApiException error,
  ) async {
    // 409 : le serveur a déjà appliqué cette opération (rejeu après une
    // réponse perdue). C'est un succès du point de vue de la file.
    if (error.isAlreadyApplied) {
      await _database.transaction((txn) async {
        await _queue.complete(operation.id, txn: txn);
        await _store.markSynced(
          operation.entityType,
          operation.entityId,
          txn: txn,
        );
      });
      return _PushOutcome.success;
    }

    // La cible d'une suppression n'existe plus : le résultat voulu est atteint.
    if (error.isGone && operation.type == SyncOperationType.delete) {
      await _database.transaction((txn) async {
        await _store.purge(operation.entityType, operation.entityId, txn: txn);
        await _queue.complete(operation.id, txn: txn);
      });
      return _PushOutcome.success;
    }

    if (error.isUnauthorized) {
      // Session expirée : inutile d'insister, la file est conservée jusqu'à la
      // prochaine authentification.
      await _queue.reschedule(operation, 'Session expirée.');
      return _PushOutcome.retry;
    }

    if (!error.isPermanent) {
      await _queue.reschedule(operation, error.message);
      return _PushOutcome.retry;
    }

    // Rejet métier définitif (règle de gestion, chevauchement de réservation,
    // permission refusée) : l'opération reste en base, visible, et attend une
    // décision de l'utilisateur. Rien n'est perdu.
    final descriptor = EntityRegistry.find(operation.entityType);
    if (descriptor?.conflictStrategy == ConflictStrategy.manual) {
      await _recordConflict(operation, error.message);
      await _queue.markConflict(operation, error.message);
      await _store.markConflict(operation.entityType, operation.entityId);
      return _PushOutcome.conflict;
    }

    await _queue.markFailed(operation, error.message);
    await _store.markConflict(operation.entityType, operation.entityId);
    return _PushOutcome.failed;
  }

  Future<void> _recordConflict(SyncOperation operation, String reason) async {
    final record = await _store.find(
      operation.entityType,
      operation.entityId,
      includeDeleted: true,
    );
    await _database.db.insert(
      'sync_conflicts',
      {
        'id': operation.id,
        'scope': operation.scope,
        'entity_type': operation.entityType,
        'entity_id': operation.entityId,
        'local_payload': jsonEncodeSafe(record?.payload ?? operation.payload),
        'server_payload': null,
        'reason': reason,
        'detected_at': DateTime.now().toUtc().toIso8601String(),
        'resolved': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remplace les identifiants locaux déjà résolus par leur identifiant
  /// serveur, dans la cible, l'URL et les références du payload.
  Future<SyncOperation> _resolveReferences(SyncOperation operation) async {
    var current = operation;

    Future<SyncOperation> apply(String localId) async {
      final serverId = await _idMap.serverIdFor(localId);
      if (serverId == null) return current;
      return SyncQueue.rewriteId(current, localId, serverId) ?? current;
    }

    if (SyncQueue.isLocalId(current.entityId)) {
      current = await apply(current.entityId);
    }

    final payload = current.payload;
    if (payload != null) {
      for (final value in payload.values.toList()) {
        if (value is String && SyncQueue.isLocalId(value)) {
          current = await apply(value);
        }
      }
    }
    return current;
  }

  bool _hasUnresolvedReference(SyncOperation operation) {
    if (SyncQueue.isLocalId(operation.entityId) &&
        operation.type != SyncOperationType.create) {
      return true;
    }
    if (operation.endpoint.contains(SyncQueue.localIdPrefix)) return true;
    final payload = operation.payload;
    if (payload == null) return false;
    return payload.values
        .any((v) => v is String && SyncQueue.isLocalId(v));
  }

  // ── Pull ─────────────────────────────────────────────────────────────────

  /// Rapatrie les collections du serveur dans la base locale.
  ///
  /// Les documents encore en attente d'envoi ne sont jamais écrasés : c'est
  /// [LocalStore.replaceCollection] et l'arbitrage par entité qui garantissent
  /// qu'un pull ne peut pas faire disparaître du travail hors ligne.
  Future<int> _pull() async {
    final businessId = _businessId;
    if (businessId == null) return 0;

    var pulled = 0;
    for (final descriptor in EntityRegistry.pullOrder) {
      try {
        final rows = await _api.getList(
          descriptor.collectionPath(businessId),
          refresh: true,
        );
        final payloads = rows.whereType<Map<String, dynamic>>().toList();
        pulled += await _ingest(descriptor, payloads, businessId);
      } on NetworkUnavailableException {
        rethrow;
      } on ApiException catch (error) {
        // Une permission manquante sur une collection ne doit pas faire
        // échouer tout le cycle : on saute et on continue.
        if (error.isPermanent) continue;
        rethrow;
      }
    }
    return pulled;
  }

  Future<int> _ingest(
    EntityDescriptor descriptor,
    List<Map<String, dynamic>> payloads,
    String businessId,
  ) async {
    var count = 0;
    await _database.transaction((txn) async {
      for (final payload in payloads) {
        // `/stock/` est indexé par article et n'a pas de champ `id`.
        final id = LocalStore.identify(payload);
        if (id == null) continue;
        final normalized = LocalStore.normalize(payload);
        final local = await _store.find(
          descriptor.type,
          id,
          includeDeleted: true,
          txn: txn,
        );

        // Cas simple : rien en attente localement, le serveur fait foi.
        if (local == null || local.syncState == RecordSyncState.synced) {
          if (local?.deleted ?? false) continue; // suppression encore en vol
          await _store.putFromServer(
            descriptor.type,
            normalized,
            businessId: businessId,
            txn: txn,
          );
          count++;
          continue;
        }

        // Divergence : la stratégie de l'entité tranche.
        final resolution = _resolver.resolve(
          descriptor: descriptor,
          local: local,
          server: normalized,
        );
        switch (resolution.outcome) {
          case ConflictOutcome.takeResolved:
            await _store.putFromServer(
              descriptor.type,
              resolution.payload,
              businessId: businessId,
              txn: txn,
            );
            count++;
          case ConflictOutcome.pushLocal:
            // On garde la version locale et sa place dans la file, mais on met
            // à jour la référence : le prochain PATCH n'enverra que le delta
            // réellement voulu.
            await _store.put(
              local.copyWith(
                payload: resolution.payload,
                basePayload: normalized,
              ),
              txn: txn,
            );
          case ConflictOutcome.askUser:
            await _store.markConflict(descriptor.type, id, txn: txn);
        }
      }

      await _store.replaceCollection(
        descriptor.type,
        payloads,
        businessId: businessId,
        txn: txn,
      );

      // Le moteur vient de telecharger cette collection : les ecrans doivent
      // le savoir, sinon chacun la retelecharge a l'ouverture — la meme
      // collection partait deux fois sur le reseau a quelques secondes
      // d'intervalle.
      await _store.setMeta(
        LocalStore.fetchKey(descriptor.type, businessId),
        DateTime.now().toUtc().toIso8601String(),
        txn: txn,
      );
    });
    return count;
  }

  // ── Compteurs & état ─────────────────────────────────────────────────────

  Future<void> refreshCounters({bool notify = true}) async {
    if (!_database.isOpen) return;
    _pendingCount = await _queue.outstandingCount(scope: _scope);
    _failedCount = await _queue.failedCount(scope: _scope);
    if (notify) notifyListeners();
  }

  /// Relance les opérations en échec (bouton « Réessayer » de l'UI).
  Future<SyncReport> retryFailed() async {
    await _queue.retryFailed(scope: _scope);
    await refreshCounters();
    return sync(reason: 'nouvelle tentative');
  }

  /// Opérations encore en attente, pour l'écran de détail.
  Future<List<SyncOperation>> outstandingOperations() =>
      _queue.outstanding(scope: _scope);

  void _setState(SyncState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_backOnlineSubscription?.cancel());
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

enum _PushOutcome { success, retry, failed, conflict }

/// Encode un payload en JSON en tolérant le cas null.
String jsonEncodeSafe(Map<String, dynamic>? payload) =>
    payload == null ? '{}' : jsonEncode(payload);
