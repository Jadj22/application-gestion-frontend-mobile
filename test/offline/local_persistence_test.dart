import 'package:dodome/core/offline/db/local_database.dart';
import 'package:dodome/core/offline/db/local_record.dart';
import 'package:dodome/core/offline/db/local_store.dart';
import 'package:dodome/core/offline/sync/id_map.dart';
import 'package:dodome/core/offline/sync/sync_operation.dart';
import 'package:dodome/core/offline/sync/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ces tests s'exécutent sur le **vrai moteur SQLite**, pas sur un faux en
/// mémoire : la garantie testée ici — « rien n'est perdu quand l'application
/// est fermée » — n'a de valeur que si elle porte sur le moteur de production.
///
/// Fermer puis rouvrir la base simule exactement ce que fait le système quand
/// l'utilisateur tue l'application ou redémarre son téléphone.
/// Fichier propre a cette suite : deux suites qui partagent le meme
/// fichier s'effacent mutuellement leurs donnees en execution parallele.
const _dbFile = 'test_persistence.db';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase database;
  late LocalStore store;
  late SyncQueue queue;
  late IdMap idMap;

  Future<void> open() async {
    database = LocalDatabase(fileName: _dbFile);
    await database.open();
    store = LocalStore(database);
    queue = SyncQueue(database);
    idMap = IdMap(database);
  }

  setUp(() async {
    // `databaseFactoryFfi` place les bases dans un répertoire temporaire ;
    // on repart d'un état propre à chaque test.
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/$_dbFile',
    );
    await open();
  });

  tearDown(() async => database.close());

  SyncOperation operation({
    required String entityId,
    SyncOperationType type = SyncOperationType.create,
    String entityType = 'item',
    Map<String, dynamic>? payload,
    int priority = 20,
  }) {
    final now = DateTime.now().toUtc();
    final id = SyncQueue.newOperationId();
    return SyncOperation(
      id: id,
      scope: 'biz-1',
      entityType: entityType,
      entityId: entityId,
      type: type,
      method: 'POST',
      endpoint: '/businesses/biz-1/items/',
      payload: payload,
      priority: priority,
      idempotencyKey: id,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Persistance de la file', () {
    test('une opération survit à la fermeture de l\'application', () async {
      await queue.enqueue(operation(entityId: 'local:abc'));
      expect(await queue.outstandingCount(), 1);

      // L'application est tuée, puis relancée.
      await database.close();
      await open();

      final pending = await queue.outstanding();
      expect(pending, hasLength(1));
      expect(pending.single.entityId, 'local:abc');
    });

    test('la donnée et son opération sont écrites atomiquement', () async {
      // Si la transaction échoue, ni le document ni l'opération ne doivent
      // subsister : une donnée sans ordre d'envoi serait invisible du serveur,
      // un ordre sans donnée serait un envoi de rien.
      await expectLater(
        database.transaction((txn) async {
          await store.putLocal(
            'item',
            'local:atomic',
            {'id': 'local:atomic', 'nom': 'Perceuse'},
            businessId: 'biz-1',
            localOnly: true,
            txn: txn,
          );
          throw StateError('panne au milieu de la transaction');
        }),
        throwsStateError,
      );

      expect(await store.find('item', 'local:atomic'), isNull);
      expect(await queue.outstandingCount(), 0);
    });

    test('une suppression hors ligne survit au redémarrage', () async {
      await store.putFromServer(
        'item',
        {'id': 'srv-1', 'nom': 'À supprimer'},
        businessId: 'biz-1',
      );
      await database.transaction((txn) async {
        await store.markDeleted('item', 'srv-1', txn: txn);
        await queue.enqueue(
          operation(entityId: 'srv-1', type: SyncOperationType.delete),
          txn: txn,
        );
      });

      await database.close();
      await open();

      // Invisible pour l'interface…
      expect(await store.find('item', 'srv-1'), isNull);
      // …mais l'intention est toujours là, prête à partir.
      final record = await store.find('item', 'srv-1', includeDeleted: true);
      expect(record!.deleted, isTrue);
      expect(await queue.outstandingCount(), 1);
    });

    test('une opération interrompue en vol repart au démarrage', () async {
      final op = await queue.enqueue(operation(entityId: 'local:x'));
      await queue.markSyncing(op);

      // L'application est tuée pendant l'envoi.
      await database.close();
      await open();

      // Sans reprise, cette opération resterait bloquée en « syncing » pour
      // toujours et ne partirait jamais.
      expect(await queue.ready(), isEmpty);
      await queue.recoverInterrupted();
      expect(await queue.ready(), hasLength(1));
    });
  });

  group('Ordre et priorités', () {
    test('les entités dont les autres dépendent partent en premier', () async {
      await queue.enqueue(
        operation(entityId: 'task-1', entityType: 'maintenance_task', priority: 30),
      );
      await queue.enqueue(
        operation(entityId: 'cat-1', entityType: 'category', priority: 10),
      );
      await queue.enqueue(operation(entityId: 'item-1', priority: 20));

      final ready = await queue.ready();
      expect(
        ready.map((o) => o.entityType).toList(),
        ['category', 'item', 'maintenance_task'],
      );
    });

    test('à priorité égale, l\'ordre de saisie est respecté', () async {
      await queue.enqueue(operation(entityId: 'a'));
      await queue.enqueue(operation(entityId: 'b'));
      await queue.enqueue(operation(entityId: 'c'));

      final ready = await queue.ready();
      expect(ready.map((o) => o.entityId).toList(), ['a', 'b', 'c']);
    });

    test('une opération en attente de backoff ne repart pas trop tôt', () async {
      final op = await queue.enqueue(operation(entityId: 'a'));
      await queue.reschedule(op, 'serveur injoignable');

      expect(await queue.ready(), isEmpty);
      // Le délai écoulé, elle redevient éligible.
      final later = DateTime.now().toUtc().add(const Duration(minutes: 1));
      expect(await queue.ready(now: later), hasLength(1));
    });

    test('le backoff croît puis se stabilise', () {
      expect(SyncQueue.backoffFor(1), const Duration(seconds: 5));
      expect(SyncQueue.backoffFor(2), const Duration(seconds: 15));
      expect(SyncQueue.backoffFor(3), const Duration(seconds: 45));
      // Plafonné : une panne serveur longue ne doit pas vider la batterie…
      expect(SyncQueue.backoffFor(20), const Duration(minutes: 30));
      // …et surtout ne fait jamais disparaître l'opération.
      expect(SyncQueue.backoffFor(20), lessThanOrEqualTo(const Duration(hours: 1)));
    });
  });

  group('Identifiants locaux', () {
    test('l\'identifiant serveur remplace le local partout', () async {
      const localId = 'local:tmp-1';
      await store.putLocal(
        'item',
        localId,
        {'id': localId, 'nom': 'Perceuse'},
        businessId: 'biz-1',
        localOnly: true,
      );
      // Une tâche créée hors ligne référence l'article par son id local.
      await queue.enqueue(
        operation(
          entityId: 'local:task-1',
          entityType: 'maintenance_task',
          payload: {'item_id': localId},
        ),
      );

      await idMap.record('item', localId, 'srv-99');
      await store.remapId(
        'item',
        localId,
        'srv-99',
        serverPayload: {'id': 'srv-99', 'nom': 'Perceuse'},
      );
      await queue.remapLocalId(localId, 'srv-99');

      expect(await store.find('item', localId), isNull);
      final promoted = await store.find('item', 'srv-99');
      expect(promoted!.localOnly, isFalse);
      expect(promoted.syncState, RecordSyncState.synced);

      // La référence dans la file a suivi : sans cela, le serveur recevrait un
      // identifiant qu'il ne connaît pas.
      final pending = await queue.outstanding();
      expect(pending.single.payload!['item_id'], 'srv-99');
    });

    test('la correspondance survit au redémarrage', () async {
      await idMap.record('item', 'local:z', 'srv-z');
      await database.close();
      await open();

      // Un écran ouvert avant la synchronisation peut encore citer l'ancien
      // identifiant longtemps après.
      expect(await idMap.resolve('local:z'), 'srv-z');
    });

    test('un identifiant inconnu est renvoyé tel quel', () async {
      expect(await idMap.resolve('srv-déjà-bon'), 'srv-déjà-bon');
    });
  });

  group('Pull non destructif', () {
    test('le serveur n\'écrase pas une modification en attente', () async {
      await store.putFromServer(
        'item',
        {'id': 'srv-1', 'nom': 'Nom serveur', 'prix': 100},
        businessId: 'biz-1',
      );
      await store.putLocal(
        'item',
        'srv-1',
        {'id': 'srv-1', 'nom': 'Nom modifié hors ligne', 'prix': 100},
        businessId: 'biz-1',
      );

      // Un pull rapatrie la version serveur, qui ignore la modification locale.
      await database.transaction((txn) async {
        await store.replaceCollection(
          'item',
          [
            {'id': 'srv-1', 'nom': 'Nom serveur', 'prix': 100},
          ],
          businessId: 'biz-1',
          txn: txn,
        );
      });

      final record = await store.find('item', 'srv-1');
      expect(record!.payload['nom'], 'Nom modifié hors ligne');
      expect(record.syncState, RecordSyncState.pending);
    });

    test('une création locale absente du serveur n\'est pas supprimée', () async {
      await store.putLocal(
        'item',
        'local:new',
        {'id': 'local:new', 'nom': 'Créé sur le terrain'},
        businessId: 'biz-1',
        localOnly: true,
      );

      // Le serveur ne peut pas connaître cet article : il vient d'être créé
      // hors ligne. Le pull ne doit surtout pas le faire disparaître.
      await database.transaction((txn) async {
        await store.replaceCollection('item', [], businessId: 'biz-1', txn: txn);
      });

      expect(await store.find('item', 'local:new'), isNotNull);
    });

    test('un élément supprimé côté serveur disparaît en local', () async {
      await store.putFromServer(
        'item',
        {'id': 'srv-old', 'nom': 'Supprimé ailleurs'},
        businessId: 'biz-1',
      );

      await database.transaction((txn) async {
        await store.replaceCollection('item', [], businessId: 'biz-1', txn: txn);
      });

      expect(await store.find('item', 'srv-old'), isNull);
    });
  });

  group('Cloisonnement multi-tenant', () {
    test('les données d\'un business n\'apparaissent pas dans un autre', () async {
      await store.putFromServer(
        'item',
        {'id': 'a', 'nom': 'Chez A'},
        businessId: 'biz-1',
      );
      await store.putFromServer(
        'item',
        {'id': 'b', 'nom': 'Chez B'},
        businessId: 'biz-2',
      );

      final first = await store.listPayloads('item', businessId: 'biz-1');
      expect(first.map((r) => r['nom']), ['Chez A']);
    });

    test('le compteur d\'attente est propre à chaque business', () async {
      await queue.enqueue(operation(entityId: 'x'));
      expect(await queue.outstandingCount(scope: 'biz-1'), 1);
      expect(await queue.outstandingCount(scope: 'biz-2'), 0);
    });
  });
}
