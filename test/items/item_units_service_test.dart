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
import 'package:dodome/features/items/data/item_units_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Les unités personnalisées passent par la vraie base locale : la garantie
/// testée ici — « l'unité créée par l'utilisateur est enregistrée et revient »
/// — n'a de valeur que si elle survit à une fermeture de l'application.
/// Fichier propre a cette suite : deux suites qui partagent le meme
/// fichier s'effacent mutuellement leurs donnees en execution parallele.
const _dbFile = 'test_units.db';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase database;
  late LocalStore store;
  late ItemUnitsService service;
  late OfflineRepository offline;

  Future<void> open() async {
    database = LocalDatabase(fileName: _dbFile);
    await database.open();
    store = LocalStore(database);
    final connectivity = ConnectivityService();
    addTearDown(connectivity.dispose);
    final queue = SyncQueue(database);
    final idMap = IdMap(database);
    final api = ApiClient(tokens: TokenStorage());
    final engine = SyncEngine(
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
    service = ItemUnitsService(offline);
  }

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/$_dbFile',
    );
    await open();
  });

  tearDown(() async => database.close());

  group('Validation', () {
    test('une unité vide est refusée', () {
      expect(ItemUnitsService.validate('   ').valid, isFalse);
    });

    test('une unité trop longue est refusée avant l\'envoi', () {
      // `Item.unite` est un CharField(max_length=30) : laisser passer plus
      // long ferait échouer la création bien après que l'utilisateur a quitté
      // l'écran, dans la file de synchronisation.
      final result = ItemUnitsService.validate('a' * 31);
      expect(result.valid, isFalse);
      expect(result.error, contains('30'));
    });

    test('un nombre seul est refusé', () {
      // Presque toujours une quantité saisie dans le mauvais champ.
      expect(ItemUnitsService.validate('12').valid, isFalse);
    });

    test('les espaces superflus sont normalisés', () {
      final result = ItemUnitsService.validate('  botte   de   paille ');
      expect(result.valid, isTrue);
      expect(result.value, 'botte de paille');
    });

    test('la casse choisie par l\'utilisateur est conservée', () {
      expect(ItemUnitsService.validate('Bobine').value, 'Bobine');
    });
  });

  group('Enregistrement', () {
    test('une unité créée est proposée ensuite', () async {
      await service.remember('biz-1', 'botte');
      expect(await service.customUnits('biz-1'), contains('botte'));
    });

    test('elle survit à la fermeture de l\'application', () async {
      await service.remember('biz-1', 'plateau');

      // L'application est tuée puis relancée.
      await database.close();
      await open();

      expect(await service.customUnits('biz-1'), contains('plateau'));
    });

    test('une unité déjà standard n\'est pas dupliquée', () async {
      // Sinon la liste « Vos unités » se remplirait de doublons de `kg`.
      await service.remember('biz-1', 'kg');
      await service.remember('biz-1', 'Kilogramme');
      expect(await service.customUnits('biz-1'), isEmpty);
    });

    test('la même unité à une casse près n\'est ajoutée qu\'une fois', () async {
      await service.remember('biz-1', 'Botte');
      await service.remember('biz-1', 'botte');
      await service.remember('biz-1', 'BOTTE');
      final unites = await service.customUnits('biz-1');
      expect(unites.where((u) => u.toLowerCase() == 'botte').length, 1);
    });

    test('une unité invalide n\'est jamais enregistrée', () async {
      await service.remember('biz-1', '   ');
      await service.remember('biz-1', 'x' * 40);
      expect(await service.customUnits('biz-1'), isEmpty);
    });

    test('les unités sont cloisonnées par business', () async {
      await service.remember('biz-1', 'botte');
      expect(await service.customUnits('biz-2'), isEmpty);
    });
  });

  group('Unités déduites du catalogue', () {
    test('une unité portée par un article existant est proposée', () async {
      // Cas réel : l'unité vient d'un article créé sur un autre appareil, ou
      // avant l'existence de cette liste. Elle doit rester proposable.
      await store.putFromServer(
        'item',
        {'id': 'srv-1', 'nom': 'Paille', 'unite': 'botte'},
        businessId: 'biz-1',
      );
      expect(await service.customUnits('biz-1'), contains('botte'));
    });

    test('les unités standard des articles ne polluent pas la liste', () async {
      await store.putFromServer(
        'item',
        {'id': 'srv-2', 'nom': 'Riz', 'unite': 'kg'},
        businessId: 'biz-1',
      );
      expect(await service.customUnits('biz-1'), isEmpty);
    });

    test('les articles sans unité sont ignorés', () async {
      await store.putFromServer(
        'item',
        {'id': 'srv-3', 'nom': 'Sans unité', 'unite': ''},
        businessId: 'biz-1',
      );
      expect(await service.customUnits('biz-1'), isEmpty);
    });
  });

  group('Invalidation apres ecriture', () {
    test("une ecriture perime les lectures qu'elle rend fausses", () async {
      // Regression : apres une modification, un ecran recharge renvoyait la
      // copie d'avant pendant tout le delai de fraicheur (2 minutes), donc un
      // mouvement de stock restait invisible et un article cree apparaissait
      // sans stock.
      await store.setMeta('fetched.item.biz-1', DateTime.now().toIso8601String());
      await store.setMeta(
        'fetched.stock_state.biz-1',
        DateTime.now().toIso8601String(),
      );
      await store.setMeta('derived.dashboard.biz-1', '{}');

      // Un mouvement de stock invalide l'article, l'etat du stock, et tous
      // les agregats calcules par le serveur.
      await offline.create(
        EntityRegistry.stockMovement,
        'biz-1',
        {'type': 'ENTREE', 'item_id': 'srv-1', 'quantite': 5},
      );

      expect(await store.meta('fetched.stock_state.biz-1'), isNull);
      expect(await store.meta('fetched.item.biz-1'), isNull);
      expect(await store.meta('derived.dashboard.biz-1'), isNull);
    });

    test("une ecriture ne perime pas les lectures d'un autre business", () async {
      await store.setMeta('fetched.item.biz-2', 'garde-moi');

      await offline.create(
        EntityRegistry.stockMovement,
        'biz-1',
        {'type': 'ENTREE', 'item_id': 'srv-1', 'quantite': 5},
      );

      expect(await store.meta('fetched.item.biz-2'), 'garde-moi');
    });
  });

  group('Retrait', () {
    test('une unité retirée disparaît des propositions', () async {
      await service.remember('biz-1', 'bobine');
      await service.forget('biz-1', 'bobine');
      expect(await service.customUnits('biz-1'), isEmpty);
    });

    test('retirer une unité ne touche pas les articles qui l\'utilisent',
        () async {
      await store.putFromServer(
        'item',
        {'id': 'srv-4', 'nom': 'Câble', 'unite': 'bobine'},
        businessId: 'biz-1',
      );
      await service.remember('biz-1', 'bobine');
      await service.forget('biz-1', 'bobine');

      // L'article garde son unité…
      final item = await store.findPayload('item', 'srv-4');
      expect(item!['unite'], 'bobine');
      // …et comme il l'utilise, elle reste proposable.
      expect(await service.customUnits('biz-1'), contains('bobine'));
    });
  });
}
