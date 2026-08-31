import 'package:dodome/core/offline/sync/sync_compactor.dart';
import 'package:dodome/core/offline/sync/sync_operation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fabrique une opération de test avec des valeurs par défaut raisonnables.
SyncOperation op(
  String id,
  SyncOperationType type, {
  String entity = 'item',
  String entityId = 'item-1',
  Map<String, dynamic>? payload,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return SyncOperation(
    id: id,
    scope: 'biz-1',
    entityType: entity,
    entityId: entityId,
    type: type,
    method: switch (type) {
      SyncOperationType.create => 'POST',
      SyncOperationType.update => 'PATCH',
      SyncOperationType.delete => 'DELETE',
      _ => 'POST',
    },
    endpoint: '/businesses/biz-1/items/',
    payload: payload,
    idempotencyKey: id,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const compactor = SyncCompactor();

  group('SyncCompactor', () {
    test('CREATE puis UPDATE ne produit qu\'une création enrichie', () {
      final result = compactor.compact([
        op('1', SyncOperationType.create, payload: {'nom': 'Perceuse'}),
        op('2', SyncOperationType.update, payload: {'prix': 120}),
      ]);

      expect(result.operations, hasLength(1));
      expect(result.operations.single.type, SyncOperationType.create);
      // Le POST doit partir complet : créer puis modifier ferait apparaître un
      // état intermédiaire que personne n'a besoin de voir.
      expect(result.operations.single.payload, {'nom': 'Perceuse', 'prix': 120});
      expect(result.discardedIds, ['2']);
    });

    test('CREATE → UPDATE → UPDATE → DELETE n\'envoie rien du tout', () {
      // Le scénario exact du cahier des charges : l'objet n'a jamais existé
      // côté serveur, il n'y a donc rien à lui dire.
      final result = compactor.compact([
        op('1', SyncOperationType.create, payload: {'nom': 'Brouillon'}),
        op('2', SyncOperationType.update, payload: {'nom': 'Renommé'}),
        op('3', SyncOperationType.update, payload: {'prix': 10}),
        op('4', SyncOperationType.delete),
      ]);

      expect(result.operations, isEmpty);
      expect(result.discardedIds, hasLength(4));
      expect(result.vanished.single.entityId, 'item-1');
    });

    test('UPDATE répétés fusionnent en un seul PATCH', () {
      final result = compactor.compact([
        op('1', SyncOperationType.update, payload: {'prix': 10}),
        op('2', SyncOperationType.update, payload: {'prix': 20}),
        op('3', SyncOperationType.update, payload: {'nom': 'Final'}),
      ]);

      expect(result.operations, hasLength(1));
      // La dernière valeur d'un champ l'emporte, les autres champs sont
      // conservés : c'est bien l'état final voulu par l'utilisateur.
      expect(result.operations.single.payload, {'prix': 20, 'nom': 'Final'});
    });

    test('UPDATE puis DELETE ne garde que la suppression', () {
      final result = compactor.compact([
        op('1', SyncOperationType.update, payload: {'prix': 10}),
        op('2', SyncOperationType.delete),
      ]);

      expect(result.operations, hasLength(1));
      expect(result.operations.single.type, SyncOperationType.delete);
    });

    test('les entités distinctes ne sont jamais mélangées', () {
      final result = compactor.compact([
        op('1', SyncOperationType.create, entityId: 'item-1'),
        op('2', SyncOperationType.create, entityId: 'item-2'),
        op('3', SyncOperationType.update, entityId: 'item-1', payload: {'a': 1}),
      ]);

      expect(result.operations, hasLength(2));
      expect(
        result.operations.map((o) => o.entityId),
        containsAll(['item-1', 'item-2']),
      );
    });

    test('une action métier n\'est jamais fusionnée', () {
      // Clôturer une tâche produit un effet de bord côté serveur : deux
      // clôtures ne valent pas une, et les fusionner perdrait l'intention.
      final result = compactor.compact([
        op('1', SyncOperationType.action, entity: 'maintenance_task'),
        op('2', SyncOperationType.action, entity: 'maintenance_task'),
      ]);

      expect(result.operations, hasLength(2));
      expect(result.discardedIds, isEmpty);
    });

    test('une action gèle la fusion des opérations qui la suivent', () {
      // Réordonner un UPDATE autour d'une action changerait le résultat métier.
      final result = compactor.compact([
        op('1', SyncOperationType.update, payload: {'a': 1}),
        op('2', SyncOperationType.action),
        op('3', SyncOperationType.update, payload: {'b': 2}),
      ]);

      expect(result.operations, hasLength(3));
      expect(result.discardedIds, isEmpty);
    });

    test('un envoi de photo traverse la compaction intact', () {
      final result = compactor.compact([
        op('1', SyncOperationType.create),
        op('2', SyncOperationType.upload),
      ]);

      expect(result.operations, hasLength(2));
      expect(result.operations.last.type, SyncOperationType.upload);
    });

    test('l\'ordre causal des opérations restantes est préservé', () {
      final result = compactor.compact([
        op('1', SyncOperationType.create, entityId: 'a'),
        op('2', SyncOperationType.create, entityId: 'b'),
        op('3', SyncOperationType.create, entityId: 'c'),
      ]);

      expect(
        result.operations.map((o) => o.entityId).toList(),
        ['a', 'b', 'c'],
      );
    });

    test('une entité annulée ne décale pas les suivantes', () {
      // Régression : retirer une opération du milieu invalidait les index
      // mémorisés pour les autres entités.
      final result = compactor.compact([
        op('1', SyncOperationType.create, entityId: 'a'),
        op('2', SyncOperationType.create, entityId: 'b'),
        op('3', SyncOperationType.delete, entityId: 'a'),
        op('4', SyncOperationType.update, entityId: 'b', payload: {'x': 1}),
      ]);

      expect(result.operations, hasLength(1));
      final remaining = result.operations.single;
      expect(remaining.entityId, 'b');
      expect(remaining.type, SyncOperationType.create);
      expect(remaining.payload, {'x': 1});
    });

    test('une file vide reste vide', () {
      final result = compactor.compact([]);
      expect(result.operations, isEmpty);
      expect(result.savedRequests, 0);
    });
  });
}
