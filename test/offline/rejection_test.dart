import 'dart:convert';

import 'package:dodome/core/network/api_client.dart';
import 'package:dodome/core/offline/connectivity/connectivity_service.dart';
import 'package:dodome/core/offline/db/local_database.dart';
import 'package:dodome/core/offline/db/local_store.dart';
import 'package:dodome/core/offline/entity_registry.dart';
import 'package:dodome/core/offline/offline_repository.dart';
import 'package:dodome/core/offline/sync/id_map.dart';
import 'package:dodome/core/offline/sync/sync_engine.dart';
import 'package:dodome/core/offline/sync/sync_queue.dart';
import 'package:dodome/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fichier propre a cette suite (execution parallele).
const _dbFile = 'test_rejection.db';

/// Régression : une opération refusée par le serveur alors qu'on était **en
/// ligne** ne remontait pas à l'appelant.
///
/// Conséquence observée en production : l'écran de contrôle de retour affichait
/// « Retour enregistré », se fermait, et le serveur avait pourtant répondu 400.
/// L'utilisateur ne pouvait pas le savoir, et le bouton restait là.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase database;
  late LocalStore store;
  late SyncQueue queue;
  late ConnectivityService connectivity;
  late OfflineRepository offline;
  late SyncEngine engine;

  /// Monte la couche offline sur un serveur simulé.
  Future<void> boot(http.Client client) async {
    database = LocalDatabase(fileName: _dbFile);
    await database.open();
    store = LocalStore(database);
    queue = SyncQueue(database);
    final idMap = IdMap(database);
    connectivity = ConnectivityService(client: client);
    addTearDown(connectivity.dispose);
    final api = ApiClient(client: client, tokens: TokenStorage());
    engine = SyncEngine(
      database: database,
      store: store,
      queue: queue,
      idMap: idMap,
      api: api,
      connectivity: connectivity,
    );
    offline = OfflineRepository(
      database: database,
      store: store,
      queue: queue,
      idMap: idMap,
      engine: engine,
      api: api,
      connectivity: connectivity,
    );
    // Le moteur ne pousse que s'il se sait en ligne, et uniquement les
    // operations du business actif : sans cette portee, la file reste intacte.
    engine.businessId = 'biz-1';
    connectivity.reportSuccess();
  }

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/$_dbFile',
    );
  });

  tearDown(() async => database.close());

  /// Serveur qui refuse toute mutation avec une règle métier.
  http.Client refusant(String message) => MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'results': []}), 200);
        }
        return http.Response(
          jsonEncode([message]),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

  group('Refus définitif du serveur', () {
    test('une action refusée remonte à l\'appelant', () async {
      await boot(refusant('Impossible de terminer une réservation TERMINEE.'));
      await store.putFromServer(
        'reservation',
        {'id': 'res-1', 'statut': 'EN_COURS', 'quantite': 5},
        businessId: 'biz-1',
      );

      // Sans cette remontée, l'écran annonçait un succès et se fermait.
      await expectLater(
        offline.action(
          EntityRegistry.reservation,
          'biz-1',
          'res-1',
          path: '/businesses/biz-1/reservations/res-1/terminer/',
          body: const {'quantite_retournee': 5},
          localEffect: (current) => {...current, 'statut': 'TERMINEE'},
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Impossible de terminer'),
          ),
        ),
      );
    });

    test('l\'état local revient à la vérité du serveur', () async {
      await boot(refusant('Règle de gestion non respectée.'));
      await store.putFromServer(
        'reservation',
        {'id': 'res-2', 'statut': 'EN_COURS'},
        businessId: 'biz-1',
      );

      await offline
          .action(
            EntityRegistry.reservation,
            'biz-1',
            'res-2',
            path: '/businesses/biz-1/reservations/res-2/terminer/',
            localEffect: (current) => {...current, 'statut': 'TERMINEE'},
          )
          .catchError((_) => <String, dynamic>{});

      // L'effet optimiste doit être annulé : afficher TERMINEE alors que le
      // serveur dit EN_COURS ferait disparaître l'action à faire.
      final record = await store.findPayload('reservation', 'res-2');
      expect(record!['statut'], 'EN_COURS');
    });

    test('l\'opération refusée ne reste pas dans la file', () async {
      await boot(refusant('Refusé.'));
      await store.putFromServer(
        'reservation',
        {'id': 'res-3', 'statut': 'EN_COURS'},
        businessId: 'biz-1',
      );

      await offline
          .action(
            EntityRegistry.reservation,
            'biz-1',
            'res-3',
            path: '/businesses/biz-1/reservations/res-3/terminer/',
          )
          .catchError((_) => <String, dynamic>{});

      // L'utilisateur a été informé : la laisser produirait une erreur
      // permanente dans le bandeau, pour une opération qui ne peut pas aboutir.
      expect(await queue.outstandingCount(), 0);
    });

    test('une création refusée ne laisse pas de fantôme local', () async {
      await boot(refusant('Cette référence existe déjà.'));

      await offline
          .create(EntityRegistry.item, 'biz-1', {'nom': 'Doublon'})
          .catchError((_) => <String, dynamic>{});

      expect(await store.listPayloads('item', businessId: 'biz-1'), isEmpty);
    });
  });

  group('Hors ligne : rien ne remonte', () {
    test('une écriture hors ligne réussit et reste en attente', () async {
      // Serveur injoignable : c'est le cas nominal de l'architecture, pas un
      // refus. L'opération doit être conservée sans lever d'exception.
      await boot(MockClient((_) async => throw const SocketExceptionStub()));
      connectivity.reportNetworkFailure();

      final payload = await offline.create(
        EntityRegistry.item,
        'biz-1',
        {'nom': 'Créé sur le terrain'},
      );

      expect(payload['nom'], 'Créé sur le terrain');
      expect(await queue.outstandingCount(), 1);
      expect(
        await store.listPayloads('item', businessId: 'biz-1'),
        hasLength(1),
      );
    });
  });
}

/// Panne réseau simulée.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
