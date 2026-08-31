import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'auth/offline_auth_store.dart';
import 'connectivity/connectivity_service.dart';
import 'db/local_database.dart';
import 'db/local_store.dart';
import 'offline_repository.dart';
import 'sync/id_map.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_queue.dart';

/// Assemble la couche Offline-First et l'expose au reste de l'application.
///
/// Un seul objet à construire au démarrage, une seule dépendance à injecter
/// dans les repositories. Il ne contient aucune logique métier : uniquement le
/// câblage entre la base locale, la file, le réseau et le moteur.
class OfflineRuntime {
  final LocalDatabase database;
  final LocalStore store;
  final SyncQueue queue;
  final IdMap idMap;
  final ConnectivityService connectivity;
  final SyncEngine engine;
  final OfflineAuthStore auth;
  final OfflineRepository repository;

  OfflineRuntime._({
    required this.database,
    required this.store,
    required this.queue,
    required this.idMap,
    required this.connectivity,
    required this.engine,
    required this.auth,
    required this.repository,
  });

  /// Ouvre la base, restaure la file et démarre la surveillance du réseau.
  ///
  /// Appelée avant `runApp` : l'application ne doit jamais afficher un écran
  /// sans savoir ce qu'elle a en local ni ce qui reste à envoyer.
  static Future<OfflineRuntime> boot({required ApiClient api}) async {
    final database = LocalDatabase();
    await database.open();

    final store = LocalStore(database);
    final queue = SyncQueue(database);
    final idMap = IdMap(database);
    final connectivity = ConnectivityService();

    final engine = SyncEngine(
      database: database,
      store: store,
      queue: queue,
      idMap: idMap,
      api: api,
      connectivity: connectivity,
    );

    // Chaque requête métier renseigne l'état du réseau : c'est une preuve plus
    // fraîche qu'une sonde périodique, et ça évite de sonder pour rien.
    api.onReachability = ({required bool reachable}) {
      if (reachable) {
        connectivity.reportSuccess();
      } else {
        connectivity.reportNetworkFailure();
      }
    };

    final runtime = OfflineRuntime._(
      database: database,
      store: store,
      queue: queue,
      idMap: idMap,
      connectivity: connectivity,
      engine: engine,
      auth: OfflineAuthStore(),
      repository: OfflineRepository(
        database: database,
        store: store,
        queue: queue,
        idMap: idMap,
        engine: engine,
        api: api,
        connectivity: connectivity,
      ),
    );

    await connectivity.start();
    await engine.start();
    return runtime;
  }

  /// Suit le business actif : la synchronisation et le stockage sont cloisonnés
  /// par tenant.
  void useBusiness(String? businessId) => engine.businessId = businessId;

  /// Prépare une déconnexion.
  ///
  /// Renvoie le nombre d'opérations encore en attente : l'appelant doit
  /// prévenir l'utilisateur avant d'effacer quoi que ce soit, sinon on
  /// détruirait du travail hors ligne sans le lui dire.
  Future<int> pendingBeforeLogout() => queue.outstandingCount();

  /// Efface les données locales du compte (déconnexion confirmée).
  Future<void> clearAccountData() async {
    await database.wipe();
    await auth.clear();
    await engine.refreshCounters();
  }

  Future<void> dispose() async {
    engine.dispose();
    connectivity.dispose();
    await database.close();
  }
}

/// Exécute [action] sans jamais laisser remonter une erreur de fond de tâche.
///
/// Utilisé pour les déclenchements « au mieux » (synchronisation d'ouverture
/// d'écran) : ils ne doivent pas casser l'interface s'ils échouent.
void fireAndForget(Future<void> Function() action, {String label = 'tâche'}) {
  unawaited(
    action().catchError((Object error) {
      debugPrint('$label en arrière-plan : $error');
    }),
  );
}
