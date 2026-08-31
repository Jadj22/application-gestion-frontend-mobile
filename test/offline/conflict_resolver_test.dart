import 'package:dodome/core/offline/db/local_record.dart';
import 'package:dodome/core/offline/entity_registry.dart';
import 'package:dodome/core/offline/sync/conflict_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

LocalRecord record({
  required Map<String, dynamic> payload,
  Map<String, dynamic>? base,
  String entityType = 'item',
}) =>
    LocalRecord(
      entityType: entityType,
      id: 'srv-1',
      scope: 'biz-1',
      payload: payload,
      basePayload: base,
      localUpdatedAt: DateTime.utc(2026, 6, 1),
      syncState: RecordSyncState.pending,
    );

void main() {
  const resolver = ConflictResolver();

  group('Fusion champ par champ (articles, catégories, procédures)', () {
    test('seuls les champs réellement modifiés en local sont conservés', () {
      // Le collègue a changé le nom, moi le prix : les deux doivent survivre.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.item,
        local: record(
          payload: {'id': 'srv-1', 'nom': 'Perceuse', 'prix': 500},
          base: {'id': 'srv-1', 'nom': 'Perceuse', 'prix': 400},
        ),
        server: {'id': 'srv-1', 'nom': 'Perceuse Bosch', 'prix': 400},
      );

      expect(resolution.outcome, ConflictOutcome.pushLocal);
      expect(resolution.payload['prix'], 500);
      expect(resolution.payload['nom'], 'Perceuse Bosch');
    });

    test('un champ non touché en local garde la valeur du serveur', () {
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.item,
        local: record(
          payload: {'id': 'srv-1', 'nom': 'A', 'prix': 100},
          base: {'id': 'srv-1', 'nom': 'A', 'prix': 100},
        ),
        server: {'id': 'srv-1', 'nom': 'B', 'prix': 100},
      );

      // Rien n'a bougé en local : inutile de renvoyer quoi que ce soit.
      expect(resolution.outcome, ConflictOutcome.takeResolved);
      expect(resolution.payload['nom'], 'B');
    });

    test('les champs calculés par le serveur ne sont jamais écrasés', () {
      // `statut` est dérivé de l'état du stock et de l'entretien : une valeur
      // locale périmée ne doit pas remonter.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.item,
        local: record(
          payload: {'id': 'srv-1', 'nom': 'Neuf', 'statut': 'ACTIF'},
          base: {'id': 'srv-1', 'nom': 'Ancien', 'statut': 'ACTIF'},
        ),
        server: {'id': 'srv-1', 'nom': 'Ancien', 'statut': 'EN_ENTRETIEN'},
      );

      expect(resolution.payload['nom'], 'Neuf');
      expect(resolution.payload['statut'], 'EN_ENTRETIEN');
    });

    test('sans version de référence, le serveur fait foi', () {
      // Fusionner à l'aveugle écraserait des champs qu'on ne sait pas juger.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.item,
        local: record(payload: {'id': 'srv-1', 'nom': 'Local'}),
        server: {'id': 'srv-1', 'nom': 'Serveur'},
      );

      expect(resolution.outcome, ConflictOutcome.takeResolved);
      expect(resolution.payload['nom'], 'Serveur');
    });

    test('un décimal renvoyé en chaîne ne crée pas de faux conflit', () {
      // DRF sérialise les décimaux en "120.00" ; comparer brutalement ferait
      // croire à une modification à chaque synchronisation.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.item,
        local: record(
          payload: {'id': 'srv-1', 'prix': 120},
          base: {'id': 'srv-1', 'prix': '120'},
        ),
        server: {'id': 'srv-1', 'prix': '120'},
      );

      expect(resolution.outcome, ConflictOutcome.takeResolved);
    });
  });

  group('Le serveur gagne (tâches d\'entretien)', () {
    test('le workflow serveur écrase l\'état local', () {
      // Le statut d'une tâche suit RM-11, appliqué côté serveur : lui seul sait.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.maintenanceTask,
        local: record(
          entityType: 'maintenance_task',
          payload: {'id': 'srv-1', 'statut': 'EN_COURS'},
          base: {'id': 'srv-1', 'statut': 'A_FAIRE'},
        ),
        server: {'id': 'srv-1', 'statut': 'TERMINE'},
      );

      expect(resolution.outcome, ConflictOutcome.takeResolved);
      expect(resolution.payload['statut'], 'TERMINE');
    });
  });

  group('Le client gagne (journaux, commentaires)', () {
    test('un fait saisi sur le terrain n\'est jamais écrasé', () {
      // Un mouvement de stock est un fait daté : le serveur n'a rien à en dire.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.stockMovement,
        local: record(
          entityType: 'stock_movement',
          payload: {'id': 'srv-1', 'quantite': 7},
          base: {'id': 'srv-1', 'quantite': 7},
        ),
        server: {'id': 'srv-1', 'quantite': 3},
      );

      expect(resolution.outcome, ConflictOutcome.pushLocal);
      expect(resolution.payload['quantite'], 7);
    });
  });

  group('Arbitrage manuel (réservations)', () {
    test('une modification concurrente est soumise à l\'utilisateur', () {
      // Deux appareils hors ligne peuvent réserver le même article : personne
      // d'autre que l'utilisateur ne peut décider qui cède.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.reservation,
        local: record(
          entityType: 'reservation',
          payload: {'id': 'srv-1', 'quantite': 5},
          base: {'id': 'srv-1', 'quantite': 2, 'updated_at': '2026-06-01T10:00:00Z'},
        ),
        server: {
          'id': 'srv-1',
          'quantite': 3,
          'updated_at': '2026-06-02T10:00:00Z',
        },
      );

      expect(resolution.outcome, ConflictOutcome.askUser);
    });

    test('sans modification concurrente, on ne dérange pas l\'utilisateur', () {
      // Le serveur n'a pas bougé depuis la référence : ce n'est pas un conflit.
      final resolution = resolver.resolve(
        descriptor: EntityRegistry.reservation,
        local: record(
          entityType: 'reservation',
          payload: {'id': 'srv-1', 'quantite': 5},
          base: {'id': 'srv-1', 'quantite': 2, 'updated_at': '2026-06-01T10:00:00Z'},
        ),
        server: {
          'id': 'srv-1',
          'quantite': 2,
          'updated_at': '2026-06-01T10:00:00Z',
        },
      );

      expect(resolution.outcome, ConflictOutcome.pushLocal);
    });
  });

  group('Delta envoyé au serveur', () {
    test('un PATCH ne contient que ce que l\'utilisateur a changé', () {
      // Envoyer l'objet entier réécrirait des champs auxquels personne n'a
      // touché, et écraserait le travail des collègues.
      final changes = resolver.localChanges(
        descriptor: EntityRegistry.item,
        record: record(
          payload: {'id': 'srv-1', 'nom': 'A', 'prix': 500, 'unite': 'u'},
          base: {'id': 'srv-1', 'nom': 'A', 'prix': 400, 'unite': 'u'},
        ),
      );

      expect(changes, {'prix': 500});
    });

    test('les champs du serveur sont exclus du delta', () {
      final changes = resolver.localChanges(
        descriptor: EntityRegistry.item,
        record: record(
          payload: {'id': 'srv-1', 'statut': 'ACTIF', 'nom': 'B'},
          base: {'id': 'srv-1', 'statut': 'EN_ENTRETIEN', 'nom': 'A'},
        ),
      );

      expect(changes.containsKey('statut'), isFalse);
      expect(changes.containsKey('id'), isFalse);
      expect(changes, {'nom': 'B'});
    });
  });

  group('Cohérence du registre', () {
    test('chaque entité déclarée est joignable par son type', () {
      for (final entry in EntityRegistry.all.entries) {
        expect(entry.value.type, entry.key);
      }
    });

    test('tout ce qui est écrit hors ligne a une route de collection', () {
      for (final descriptor in EntityRegistry.all.values) {
        if (!descriptor.writableOffline) continue;
        if (descriptor.type == 'task_comment') continue; // route portée par le parent
        expect(
          () => descriptor.collectionPath('biz-1'),
          returnsNormally,
          reason: '${descriptor.type} doit exposer une collection',
        );
      }
    });

    test('les entités sensibles restent en lecture seule', () {
      // Régression volontaire : rendre les rôles ou les membres modifiables
      // hors ligne ouvrirait une fenêtre de droits non validés par le serveur.
      expect(EntityRegistry.role.writableOffline, isFalse);
      expect(EntityRegistry.member.writableOffline, isFalse);
    });

    test('les dépendances passent avant ce qui les référence', () {
      expect(
        EntityRegistry.category.priority,
        lessThan(EntityRegistry.item.priority),
      );
      expect(
        EntityRegistry.item.priority,
        lessThan(EntityRegistry.maintenanceTask.priority),
      );
      expect(
        EntityRegistry.item.priority,
        lessThan(EntityRegistry.stockMovement.priority),
      );
    });
  });
}
