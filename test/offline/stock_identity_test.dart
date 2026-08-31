import 'package:dodome/core/offline/db/local_database.dart';
import 'package:dodome/core/offline/db/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fichier propre a cette suite (execution parallele).
const _dbFile = 'test_stock_identity.db';

/// Régression : le stock local disparaissait à chaque synchronisation.
///
/// Symptôme observé : le tableau de bord annonçait 360 articles disponibles,
/// pendant que l'inventaire affichait tous les articles sans stock. Les deux
/// écrans lisaient pourtant la même vérité serveur.
///
/// Cause : `/stock/` renvoie des lignes agrégées par article, identifiées par
/// `item_id` et **sans champ `id`**. L'ingestion le savait ; le nettoyage qui
/// la suit, non. Il concluait que le serveur ne renvoyait plus aucune ligne, et
/// supprimait tout ce qui venait d'être écrit.
///
/// Le tableau de bord, lui, passe par un cache séparé — d'où l'incohérence
/// entre deux écrans censés dire la même chose.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase database;
  late LocalStore store;

  setUp(() async {
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/$_dbFile',
    );
    database = LocalDatabase(fileName: _dbFile);
    await database.open();
    store = LocalStore(database);
  });

  tearDown(() async => database.close());

  /// Ligne telle que `StockListView` la renvoie réellement : pas de `id`.
  Map<String, dynamic> ligneStock(String itemId, {int disponibles = 12}) => {
        'item_id': itemId,
        'nom': 'Chaise',
        'statut': 'ACTIF',
        'total': disponibles,
        'disponibles': disponibles,
      };

  group('Identité des documents', () {
    test('une ligne sans `id` est identifiée par `item_id`', () {
      expect(LocalStore.identify(ligneStock('srv-1')), 'srv-1');
    });

    test('`id` reste prioritaire quand il existe', () {
      expect(
        LocalStore.identify({'id': 'a', 'item_id': 'b'}),
        'a',
      );
    });

    test('un document sans aucune clé est ignoré', () {
      expect(LocalStore.identify({'nom': 'Orphelin'}), isNull);
    });

    test('la normalisation ajoute `id` sans écraser l\'existant', () {
      expect(LocalStore.normalize(ligneStock('srv-1'))['id'], 'srv-1');
      expect(
        LocalStore.normalize({'id': 'a', 'item_id': 'b'})['id'],
        'a',
      );
    });
  });

  group('Le stock survit à la synchronisation', () {
    test('une ligne de stock n\'est pas effacée par le nettoyage', () async {
      final ligne = ligneStock('srv-1');

      await database.transaction((txn) async {
        await store.putFromServer(
          'stock_state',
          LocalStore.normalize(ligne),
          businessId: 'biz-1',
          txn: txn,
        );
        // C'est ici que tout disparaissait : le nettoyage ne reconnaissait
        // pas la ligne qu'on venait d'écrire.
        await store.replaceCollection(
          'stock_state',
          [ligne],
          businessId: 'biz-1',
          txn: txn,
        );
      });

      final stock = await store.listPayloads(
        'stock_state',
        businessId: 'biz-1',
      );
      expect(stock, hasLength(1));
      expect(stock.single['disponibles'], 12);
    });

    test('deux synchronisations de suite conservent le stock', () async {
      // Le symptôme n'apparaissait qu'après un cycle complet : la première
      // écriture semblait bonne, la suivante vidait la table.
      for (var i = 0; i < 2; i++) {
        await database.transaction((txn) async {
          await store.putFromServer(
            'stock_state',
            LocalStore.normalize(ligneStock('srv-1', disponibles: 360)),
            businessId: 'biz-1',
            txn: txn,
          );
          await store.replaceCollection(
            'stock_state',
            [ligneStock('srv-1', disponibles: 360)],
            businessId: 'biz-1',
            txn: txn,
          );
        });
      }

      final stock = await store.listPayloads(
        'stock_state',
        businessId: 'biz-1',
      );
      expect(stock, hasLength(1));
      expect(stock.single['disponibles'], 360);
    });

    test('une ligne que le serveur ne renvoie plus est bien retirée', () async {
      // Le nettoyage doit continuer de faire son travail : un article
      // supprimé ailleurs ne doit pas garder son stock en local.
      await store.putFromServer(
        'stock_state',
        LocalStore.normalize(ligneStock('srv-obsolete')),
        businessId: 'biz-1',
      );

      await database.transaction((txn) async {
        await store.replaceCollection(
          'stock_state',
          [ligneStock('srv-1')],
          businessId: 'biz-1',
          txn: txn,
        );
      });

      final ids = (await store.listPayloads(
        'stock_state',
        businessId: 'biz-1',
      ))
          .map((r) => r['id'])
          .toList();
      expect(ids, isNot(contains('srv-obsolete')));
    });
  });
}
