import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'connectivity/connectivity_service.dart';
import 'db/local_database.dart';
import 'db/local_record.dart';
import 'db/local_store.dart';
import 'entity_registry.dart';
import 'sync/id_map.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_operation.dart';
import 'sync/sync_queue.dart';

/// Levée quand une opération exige le réseau et que celui-ci est absent.
///
/// Réservée aux opérations qui ne *peuvent pas* être différées : inscription,
/// connexion Google, analyse d'image par l'IA, invitation d'un membre. Simuler
/// leur succès hors ligne produirait un état mensonger.
class OfflineUnsupportedException implements Exception {
  final String message;

  const OfflineUnsupportedException(this.message);

  @override
  String toString() => message;
}

/// Socle commun des repositories Offline-First.
///
/// Le contrat vu par l'interface ne change pas : les écrans appellent toujours
/// `repository.items(businessId)` et reçoivent des modèles typés. Ce qui change
/// est ce qui se passe dessous :
///
/// ```text
/// Écran → Repository → Base locale  (toujours)
///                          ↑
///                    Sync Engine → API   (quand le réseau le permet)
/// ```
///
/// Une lecture ne échoue jamais faute de réseau, une écriture n'est jamais
/// perdue faute de réseau.
class OfflineRepository {
  final LocalDatabase database;
  final LocalStore store;
  final SyncQueue queue;
  final IdMap idMap;
  final SyncEngine engine;
  final ApiClient api;
  final ConnectivityService connectivity;

  const OfflineRepository({
    required this.database,
    required this.store,
    required this.queue,
    required this.idMap,
    required this.engine,
    required this.api,
    required this.connectivity,
  });

  /// Durée au-delà de laquelle une collection est re-téléchargée si le réseau
  /// est disponible. En deçà, la copie locale suffit.
  static const Duration defaultFreshness = Duration(minutes: 2);

  // ── Lecture ──────────────────────────────────────────────────────────────

  /// Lit une collection : base locale d'abord, rafraîchissement réseau ensuite.
  ///
  /// Hors ligne, ou si le serveur ne répond pas, la copie locale est renvoyée
  /// telle quelle — l'appelant n'a rien de particulier à gérer.
  Future<List<Map<String, dynamic>>> readCollection(
    EntityDescriptor descriptor,
    String businessId, {
    String? path,
    Duration? maxAge,
    bool refresh = false,
  }) async {
    final endpoint = path ?? descriptor.collectionPath(businessId);
    final stale = refresh ||
        await _isStale(descriptor, businessId, maxAge ?? defaultFreshness);

    if (stale && connectivity.worthTrying) {
      try {
        final rows = await api.getList(endpoint, refresh: true);
        final payloads = rows.whereType<Map<String, dynamic>>().toList();
        await ingestCollection(descriptor, payloads, businessId);
        connectivity.reportSuccess();
      } on NetworkUnavailableException {
        // Le réseau vient de tomber : la copie locale prend le relais.
        connectivity.reportNetworkFailure();
      } on ApiException catch (error) {
        // Une permission refusée ou un 404 ne doit pas casser l'écran s'il y a
        // déjà des données locales à montrer.
        final local = await store.list(descriptor.type, businessId: businessId);
        if (local.isEmpty) rethrow;
        debugPrint('Lecture ${descriptor.type} dégradée : ${error.message}');
      }
    }

    return store.listPayloads(descriptor.type, businessId: businessId);
  }

  /// Lit un document précis. Accepte un identifiant local temporaire.
  Future<Map<String, dynamic>?> readOne(
    EntityDescriptor descriptor,
    String businessId,
    String id, {
    String? path,
    bool refresh = false,
  }) async {
    final resolvedId = await idMap.resolve(id);
    final itemPath = descriptor.itemPath;

    // Une entité jamais partie n'existe pas côté serveur : inutile d'appeler.
    final isLocal = SyncQueue.isLocalId(resolvedId);
    final shouldRefresh = refresh || await _isStale(descriptor, businessId, defaultFreshness);
    if (!isLocal && connectivity.worthTrying && shouldRefresh) {
      final endpoint = path ?? itemPath?.call(businessId, resolvedId);
      if (endpoint == null) {
        // Pas de route détail : rien à rafraîchir
      } else {
        try {
          final data = await api.get(endpoint, refresh: refresh);
          if (data is Map<String, dynamic>) {
            await _ingestOne(descriptor, data, businessId);
            await _markFetched(descriptor, businessId);
          }
        } on NetworkUnavailableException {
          connectivity.reportNetworkFailure();
        } on ApiException catch (error) {
          if (error.isGone) {
            await store.purge(descriptor.type, resolvedId);
            return null;
          }
        }
      }
    }

    return store.findPayload(descriptor.type, resolvedId);
  }

  // ── Écriture ─────────────────────────────────────────────────────────────

  /// Crée une entité.
  ///
  /// La donnée est écrite en base locale **avant** toute tentative réseau et
  /// l'opération correspondante est enfilée dans la même transaction. L'appelant
  /// récupère immédiatement le document, avec un identifiant local temporaire
  /// s'il a fallu en fabriquer un.
  Future<Map<String, dynamic>> create(
    EntityDescriptor descriptor,
    String businessId,
    Map<String, dynamic> body, {
    String? path,
    Map<String, dynamic> optimisticFields = const {},
    bool requiresNetwork = false,
  }) async {
    if (requiresNetwork || !descriptor.writableOffline) {
      _requireNetwork(descriptor.label);
    }

    final localId = SyncQueue.newLocalId();
    final endpoint = path ?? descriptor.collectionPath(businessId);
    final now = DateTime.now().toUtc().toIso8601String();

    // Ce que l'interface affichera en attendant la réponse du serveur : le
    // corps envoyé, enrichi des champs que le serveur calculerait.
    final optimistic = <String, dynamic>{
      ...body,
      ...optimisticFields,
      'id': localId,
      'created_at': now,
      'updated_at': now,
    };

    final operation = _operation(
      descriptor: descriptor,
      businessId: businessId,
      entityId: localId,
      type: SyncOperationType.create,
      method: 'POST',
      endpoint: endpoint,
      payload: body,
    );

    await database.transaction((txn) async {
      await store.putLocal(
        descriptor.type,
        localId,
        optimistic,
        businessId: businessId,
        localOnly: true,
        txn: txn,
      );
      await queue.enqueue(operation, txn: txn);
    });

    return await _flush(
          descriptor,
          localId,
          businessId: businessId,
          operationId: operation.id,
        ) ??
        optimistic;
  }

  /// Modifie une entité.
  ///
  /// [changes] ne contient que les champs réellement modifiés : envoyer
  /// l'objet entier écraserait le travail des autres membres de l'équipe sur
  /// les champs auxquels l'utilisateur n'a pas touché.
  Future<Map<String, dynamic>> update(
    EntityDescriptor descriptor,
    String businessId,
    String id,
    Map<String, dynamic> changes, {
    String? path,
  }) async {
    if (!descriptor.writableOffline) _requireNetwork(descriptor.label);

    final resolvedId = await idMap.resolve(id);
    final existing = await store.find(descriptor.type, resolvedId);
    if (existing == null) {
      throw ApiException(404, '${descriptor.label} introuvable localement.');
    }

    final merged = <String, dynamic>{
      ...existing.payload,
      ...changes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final itemPath = descriptor.itemPath;
    final endpoint = path ??
        (itemPath == null ? null : itemPath(businessId, resolvedId));
    if (endpoint == null) {
      throw UnsupportedError(
        '${descriptor.label} n\'expose pas de route de modification.',
      );
    }

    final operation = _operation(
      descriptor: descriptor,
      businessId: businessId,
      entityId: resolvedId,
      type: SyncOperationType.update,
      method: 'PATCH',
      endpoint: endpoint,
      payload: changes,
    );

    await database.transaction((txn) async {
      await store.putLocal(
        descriptor.type,
        resolvedId,
        merged,
        businessId: businessId,
        txn: txn,
      );
      await queue.enqueue(operation, txn: txn);
    });

    return await _flush(
          descriptor,
          resolvedId,
          businessId: businessId,
          operationId: operation.id,
        ) ??
        merged;
  }

  /// Supprime une entité.
  ///
  /// La ligne locale est **marquée** supprimée, pas effacée : tant que le
  /// serveur n'a pas confirmé, l'intention doit survivre à la fermeture de
  /// l'application. Elle disparaît de l'interface immédiatement.
  Future<void> delete(
    EntityDescriptor descriptor,
    String businessId,
    String id, {
    String? path,
  }) async {
    if (!descriptor.writableOffline) _requireNetwork(descriptor.label);

    final resolvedId = await idMap.resolve(id);
    final itemPath = descriptor.itemPath;
    final endpoint = path ??
        (itemPath == null ? null : itemPath(businessId, resolvedId));
    if (endpoint == null) {
      throw UnsupportedError(
        '${descriptor.label} n\'expose pas de route de suppression.',
      );
    }

    final operation = _operation(
      descriptor: descriptor,
      businessId: businessId,
      entityId: resolvedId,
      type: SyncOperationType.delete,
      method: 'DELETE',
      endpoint: endpoint,
    );

    await database.transaction((txn) async {
      await store.markDeleted(descriptor.type, resolvedId, txn: txn);
      await queue.enqueue(operation, txn: txn);
    });

    await _flush(
      descriptor,
      resolvedId,
      businessId: businessId,
      operationId: operation.id,
    );
  }

  /// Action métier hors CRUD : clôturer une tâche, valider une réservation,
  /// avancer une étape.
  ///
  /// [localEffect] applique tout de suite au document local ce que le serveur
  /// fera de son côté, pour que l'interface reflète l'action sans attendre.
  Future<Map<String, dynamic>?> action(
    EntityDescriptor descriptor,
    String businessId,
    String id, {
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic> Function(Map<String, dynamic> current)? localEffect,
    /// Verbe HTTP de l'action. Toutes les actions metier ne sont pas des POST :
    /// avancer une etape est un PATCH, retirer une photo un DELETE.
    String method = 'POST',
  }) async {
    if (!descriptor.writableOffline) _requireNetwork(descriptor.label);

    final resolvedId = await idMap.resolve(id);
    final existing = await store.find(descriptor.type, resolvedId);

    final operation = _operation(
      descriptor: descriptor,
      businessId: businessId,
      entityId: resolvedId,
      type: SyncOperationType.action,
      method: method,
      endpoint: path,
      payload: body,
    );

    await database.transaction((txn) async {
      if (existing != null && localEffect != null) {
        await store.putLocal(
          descriptor.type,
          resolvedId,
          localEffect(existing.payload),
          businessId: businessId,
          txn: txn,
        );
      }
      await queue.enqueue(operation, txn: txn);
    });

    return _flush(
      descriptor,
      resolvedId,
      businessId: businessId,
      operationId: operation.id,
    );
  }

  /// Envoi de fichier (photo). Le fichier reste sur le disque du téléphone
  /// jusqu'à ce que l'envoi aboutisse : c'est lui la donnée durable, pas la
  /// requête.
  Future<void> upload(
    EntityDescriptor descriptor,
    String businessId,
    String id, {
    required String path,
    required String filePath,
    String field = 'image',
    Map<String, String>? fields,
    String method = 'POST',
  }) async {
    final resolvedId = await idMap.resolve(id);
    await queue.enqueue(
      _operation(
        descriptor: descriptor,
        businessId: businessId,
        entityId: resolvedId,
        type: SyncOperationType.upload,
        method: method,
        endpoint: path,
        filePath: filePath,
        fileField: field,
        fileFields: fields,
      ),
    );
    await _flush(descriptor, resolvedId, businessId: businessId);
  }

  // ── Ingestion ────────────────────────────────────────────────────────────

  /// Écrit une collection venue du serveur, sans écraser ce qui est en attente.
  Future<void> ingestCollection(
    EntityDescriptor descriptor,
    List<Map<String, dynamic>> payloads,
    String businessId,
  ) async {
    await database.transaction((txn) async {
      for (final payload in payloads) {
        final id = LocalStore.identify(payload);
        if (id == null) continue;
        final normalized = LocalStore.normalize(payload);
        final local =
            await store.find(descriptor.type, id, includeDeleted: true, txn: txn);

        // Une modification ou une suppression locale non encore synchronisée
        // n'est jamais écrasée par la vérité serveur : elle a la priorité
        // jusqu'à ce que le Sync Engine l'ait poussée et arbitrée.
        if (local != null && local.syncState != RecordSyncState.synced) continue;

        await store.putFromServer(
          descriptor.type,
          normalized,
          businessId: businessId,
          txn: txn,
        );
      }
      await store.replaceCollection(
        descriptor.type,
        payloads,
        businessId: businessId,
        txn: txn,
      );
    });
    await _markFetched(descriptor, businessId);
  }

  Future<void> _ingestOne(
    EntityDescriptor descriptor,
    Map<String, dynamic> payload,
    String businessId,
  ) async {
    final id = payload['id']?.toString();
    if (id == null) return;
    final local = await store.find(descriptor.type, id, includeDeleted: true);
    if (local != null && local.syncState != RecordSyncState.synced) return;
    await store.putFromServer(descriptor.type, payload, businessId: businessId);
  }

  // ── Utilitaires ──────────────────────────────────────────────────────────

  SyncOperation _operation({
    required EntityDescriptor descriptor,
    required String businessId,
    required String entityId,
    required SyncOperationType type,
    required String method,
    required String endpoint,
    Map<String, dynamic>? payload,
    String? filePath,
    String? fileField,
    Map<String, String>? fileFields,
  }) {
    final now = DateTime.now().toUtc();
    final operationId = SyncQueue.newOperationId();
    return SyncOperation(
      id: operationId,
      scope: LocalStore.scopeOf(businessId),
      entityType: descriptor.type,
      entityId: entityId,
      type: type,
      method: method,
      endpoint: endpoint,
      payload: payload,
      filePath: filePath,
      fileField: fileField,
      fileFields: fileFields,
      priority: descriptor.priority,
      // La clé est celle de l'opération : elle est fixée une fois pour toutes
      // à l'enfilement et ne change pas entre deux tentatives. C'est ce qui
      // permet au serveur de reconnaître un rejeu.
      idempotencyKey: operationId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Tente de pousser tout de suite si le réseau le permet, puis renvoie la
  /// version courante du document (potentiellement réécrite avec son
  /// identifiant serveur).
  ///
  /// Hors ligne, on ne bloque pas : l'utilisateur continue à travailler et la
  /// file partira toute seule au retour du réseau.
  Future<Map<String, dynamic>?> _flush(
    EntityDescriptor descriptor,
    String localId, {
    String? businessId,
    String? operationId,
  }) async {
    if (businessId != null) {
      await _invalidateFreshness(descriptor, businessId);
    }
    if (connectivity.isOnline) {
      await engine.sync(reason: 'écriture ${descriptor.type}', pull: false);
      if (operationId != null) {
        await _raiseIfRejected(descriptor, localId, operationId);
      }
    } else {
      await engine.refreshCounters();
    }
    final resolvedId = await idMap.resolve(localId);
    return store.findPayload(descriptor.type, resolvedId);
  }

  /// Fait remonter un refus **définitif** du serveur à l'appelant.
  ///
  /// Le principe Offline-First veut qu'une écriture ne bloque jamais : elle
  /// est enfilée et repart plus tard. Mais quand on est en ligne et que le
  /// serveur oppose un refus métier — règle de gestion, réservation déjà
  /// terminée, permission manquante — le taire serait mentir : l'écran
  /// annoncerait un succès, se fermerait, et l'utilisateur ne saurait jamais
  /// que rien n'a été enregistré.
  ///
  /// L'opération est retirée de la file et la version serveur restaurée en
  /// local : la laisser produirait une erreur permanente dans le bandeau et un
  /// affichage qui contredit le serveur.
  Future<void> _raiseIfRejected(
    EntityDescriptor descriptor,
    String localId,
    String operationId,
  ) async {
    final operation = await queue.findById(operationId);
    // Absente = acceptée par le serveur ; encore en attente = à réessayer
    // plus tard, ce n'est pas un refus.
    if (operation == null) return;
    final refusee = operation.status == SyncOperationStatus.failed ||
        operation.status == SyncOperationStatus.conflict;
    if (!refusee) return;

    await queue.complete(operationId);
    await _revertLocal(descriptor, localId);
    await engine.refreshCounters();

    throw ApiException(
      400,
      operation.lastError ?? 'Le serveur a refusé cette opération.',
    );
  }

  /// Rend au document local la dernière version connue du serveur.
  ///
  /// Une création refusée n'a jamais existé : sa ligne est supprimée. Une
  /// modification refusée retrouve la version de référence, pour que l'écran
  /// cesse d'afficher un état que le serveur n'a pas accepté.
  Future<void> _revertLocal(EntityDescriptor descriptor, String localId) async {
    final resolvedId = await idMap.resolve(localId);
    final record = await store.find(
      descriptor.type,
      resolvedId,
      includeDeleted: true,
    );
    if (record == null) return;

    final base = record.basePayload;
    if (base == null || record.localOnly) {
      await store.purge(descriptor.type, resolvedId);
      return;
    }
    await store.put(
      record.copyWith(
        payload: base,
        deleted: false,
        syncState: RecordSyncState.synced,
      ),
    );
  }

  /// Marque comme perimees les lectures que cette ecriture rend fausses.
  ///
  /// Sans cela, un ecran recharge juste apres une modification renvoie la
  /// copie d'avant pendant tout le delai de fraicheur : un article cree
  /// s'affiche sans son stock, un mouvement enregistre reste invisible.
  ///
  /// Les agregats calcules par le serveur (tableau de bord, statistiques) sont
  /// invalides en bloc : ils croisent tellement de sources qu'il serait faux
  /// de pretendre savoir lesquels sont encore valables.
  Future<void> _invalidateFreshness(
    EntityDescriptor descriptor,
    String businessId,
  ) async {
    await store.clearMeta(_fetchKey(descriptor, businessId));
    for (final type in descriptor.invalidates) {
      final dependant = EntityRegistry.find(type);
      if (dependant == null) continue;
      await store.clearMeta(_fetchKey(dependant, businessId));
    }
    await store.clearMeta('derived.');
  }

  Never _requireNetwork(String label) => throw OfflineUnsupportedException(
        'Une connexion Internet est nécessaire pour cette action ($label).',
      );

  String _fetchKey(EntityDescriptor descriptor, String businessId) =>
      LocalStore.fetchKey(descriptor.type, businessId);

  Future<bool> _isStale(
    EntityDescriptor descriptor,
    String businessId,
    Duration maxAge,
  ) async {
    final raw = await store.meta(_fetchKey(descriptor, businessId));
    if (raw == null) return true;
    final at = DateTime.tryParse(raw);
    if (at == null) return true;
    return DateTime.now().toUtc().difference(at) > maxAge;
  }

  Future<void> _markFetched(
    EntityDescriptor descriptor,
    String businessId,
  ) =>
      store.setMeta(
        _fetchKey(descriptor, businessId),
        DateTime.now().toUtc().toIso8601String(),
      );
}
