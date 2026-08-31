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
const _dbFile = 'test_verbs.db';

/// Régression : toutes les actions métier partaient en POST.
///
/// Observé en production : `POST .../steps/<id>/` renvoyait 405 en boucle,
/// parce que `TaskStepUpdateView` n'expose que PATCH. L'opération portait
/// pourtant déjà son verbe — le moteur ne le lisait pas.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase database;
  late LocalStore store;
  late OfflineRepository offline;
  late SyncEngine engine;
  late List<String> appels;

  Future<void> boot() async {
    appels = [];
    database = LocalDatabase(fileName: _dbFile);
    await database.open();
    store = LocalStore(database);
    final queue = SyncQueue(database);
    final idMap = IdMap(database);

    final client = MockClient((request) async {
      appels.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'results': []}), 200);
      }
      return http.Response(jsonEncode({'id': 'srv-1'}), 200);
    });

    final connectivity = ConnectivityService(client: client);
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
    engine.businessId = 'biz-1';
    connectivity.reportSuccess();
  }

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/$_dbFile',
    );
    await boot();
    await store.putFromServer(
      'maintenance_task',
      {'id': 'task-1', 'statut': 'EN_COURS', 'steps': const []},
      businessId: 'biz-1',
    );
  });

  tearDown(() async => database.close());

  Future<void> agir(String method) => offline.action(
        EntityRegistry.maintenanceTask,
        'biz-1',
        'task-1',
        path: '/businesses/biz-1/maintenance/tasks/task-1/steps/s-1/',
        body: const {'statut': 'TERMINE'},
        method: method,
      );

  group('Verbe HTTP des actions', () {
    test('une action déclarée PATCH part bien en PATCH', () async {
      await agir('PATCH');

      expect(
        appels,
        contains(
          'PATCH /api/businesses/biz-1/maintenance/tasks/task-1/steps/s-1/',
        ),
      );
    });

    test('une action déclarée DELETE part bien en DELETE', () async {
      await agir('DELETE');

      expect(
        appels,
        contains(
          'DELETE /api/businesses/biz-1/maintenance/tasks/task-1/steps/s-1/',
        ),
      );
    });

    test('POST reste le comportement par défaut', () async {
      await offline.action(
        EntityRegistry.maintenanceTask,
        'biz-1',
        'task-1',
        path: '/businesses/biz-1/maintenance/tasks/task-1/cloturer/',
        body: const {'partielle': false},
      );

      expect(
        appels,
        contains('POST /api/businesses/biz-1/maintenance/tasks/task-1/cloturer/'),
      );
    });

    test('le verbe survit à une mise en file hors ligne', () async {
      // Le verbe est persisté avec l'opération : il doit être respecté même
      // quand l'envoi n'a lieu que bien plus tard.
      final queue = SyncQueue(database);
      await agir('PATCH');
      expect(await queue.outstandingCount(), 0);
      expect(appels.where((a) => a.startsWith('PATCH')), hasLength(1));
    });
  });

  group('Marqueur de fraîcheur', () {
    test('une collection rapatriée par le moteur est marquée fraîche',
        () async {
      // Sans ce marqueur, chaque écran retéléchargeait la collection que le
      // moteur venait de rapatrier, quelques secondes plus tôt.
      await engine.sync(reason: 'test');

      expect(
        await store.meta(LocalStore.fetchKey('item', 'biz-1')),
        isNotNull,
      );
      expect(
        await store.meta(LocalStore.fetchKey('category', 'biz-1')),
        isNotNull,
      );
    });

    test('une lecture juste après le pull ne retélécharge pas', () async {
      await engine.sync(reason: 'test');
      final apresPull = appels.length;

      await offline.readCollection(EntityRegistry.item, 'biz-1');

      expect(appels.length, apresPull);
    });
  });
}
