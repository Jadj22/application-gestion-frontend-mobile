import 'sync_operation.dart';

/// Résultat d'une compaction : ce qu'il reste à envoyer, et ce qui peut être
/// supprimé de la file sans jamais atteindre le réseau.
class CompactionResult {
  /// Opérations à envoyer, dans l'ordre.
  final List<SyncOperation> operations;

  /// Identifiants d'opérations devenues inutiles, à retirer de la file.
  final List<String> discardedIds;

  /// Entités créées puis supprimées hors ligne : elles n'ont jamais existé
  /// côté serveur, leurs lignes locales peuvent être purgées.
  final List<({String entityType, String entityId})> vanished;

  const CompactionResult({
    required this.operations,
    required this.discardedIds,
    required this.vanished,
  });

  int get savedRequests => discardedIds.length;
}

/// Réduit une file d'opérations avant de la pousser sur le réseau.
///
/// L'utilisateur qui travaille une heure hors ligne produit typiquement des
/// séquences très redondantes sur la même entité. Les envoyer telles quelles
/// serait correct mais coûteux, lent, et exposerait des états intermédiaires
/// que personne n'a besoin de voir.
///
/// Les règles, appliquées par entité (`entityType` + `entityId`) :
///
/// ```text
/// CREATE  → UPDATE            ⇒ CREATE (payload fusionné)
/// CREATE  → UPDATE → DELETE   ⇒ rien du tout          (jamais existé côté serveur)
/// UPDATE  → UPDATE            ⇒ UPDATE (payloads fusionnés)
/// UPDATE  → DELETE            ⇒ DELETE                (l'update est sans objet)
/// DELETE  → …                 ⇒ DELETE                (plus rien après)
/// ```
///
/// Deux garde-fous importants :
///
/// * les opérations `action` et `upload` ne sont **jamais** fusionnées : elles
///   portent chacune un effet de bord propre côté serveur (clôturer une tâche,
///   valider une réservation, envoyer une photo) ;
/// * la fusion s'arrête à la première opération `action`/`upload` rencontrée
///   sur l'entité, car réordonner autour d'elle changerait le résultat métier.
class SyncCompactor {
  const SyncCompactor();

  CompactionResult compact(List<SyncOperation> input) {
    final discarded = <String>[];
    final vanished = <({String entityType, String entityId})>[];
    final output = <SyncOperation>[];

    // Index de la dernière opération CRUD retenue, par entité.
    final lastCrudIndex = <String, int>{};
    // Entités dont la séquence est « gelée » par une action/upload : plus
    // aucune fusion en arrière n'est permise.
    final frozen = <String>{};

    for (final operation in input) {
      final key = '${operation.entityType}#${operation.entityId}';

      if (operation.type == SyncOperationType.action ||
          operation.type == SyncOperationType.upload) {
        // Effet de bord non idempotent au sens métier : on le laisse passer
        // tel quel et on interdit toute fusion ultérieure en arrière.
        frozen.add(key);
        output.add(operation);
        continue;
      }

      final previousIndex = frozen.contains(key) ? null : lastCrudIndex[key];
      if (previousIndex == null) {
        lastCrudIndex[key] = output.length;
        output.add(operation);
        continue;
      }

      final previous = output[previousIndex];
      final merged = _merge(previous, operation);

      switch (merged.outcome) {
        case _MergeOutcome.replace:
          // `operation == null` signifie « garder la précédente telle quelle ».
          final kept = merged.operation;
          if (kept != null) output[previousIndex] = kept;
          discarded.add(operation.id);

        case _MergeOutcome.annihilate:
          // CREATE suivi de DELETE : rien n'a jamais existé côté serveur.
          discarded
            ..add(previous.id)
            ..add(operation.id);
          output.removeAt(previousIndex);
          _shiftIndexes(lastCrudIndex, previousIndex);
          lastCrudIndex.remove(key);
          vanished.add((
            entityType: operation.entityType,
            entityId: operation.entityId,
          ));

        case _MergeOutcome.keepBoth:
          lastCrudIndex[key] = output.length;
          output.add(operation);
      }
    }

    return CompactionResult(
      operations: output,
      discardedIds: discarded,
      vanished: vanished,
    );
  }

  /// Décale les index mémorisés après le retrait d'un élément de [output].
  void _shiftIndexes(Map<String, int> indexes, int removedAt) {
    for (final entry in indexes.entries.toList()) {
      if (entry.value > removedAt) indexes[entry.key] = entry.value - 1;
    }
  }

  _Merge _merge(SyncOperation previous, SyncOperation next) {
    switch (next.type) {
      case SyncOperationType.update:
        if (previous.type == SyncOperationType.delete) {
          // Modifier après avoir supprimé n'a pas de sens : on garde le DELETE.
          return const _Merge(_MergeOutcome.replace, null);
        }
        // CREATE + UPDATE ⇒ CREATE enrichi ; UPDATE + UPDATE ⇒ UPDATE enrichi.
        // On conserve le type et l'endpoint du premier : c'est lui qui décide
        // si l'entité doit être créée ou modifiée côté serveur.
        return _Merge(
          _MergeOutcome.replace,
          previous.copyWith(
            payload: {...?previous.payload, ...?next.payload},
            clearError: true,
          ),
        );

      case SyncOperationType.delete:
        if (previous.type == SyncOperationType.create) {
          return const _Merge(_MergeOutcome.annihilate, null);
        }
        // UPDATE (ou DELETE) puis DELETE ⇒ seul le DELETE compte. On garde
        // l'identité de l'opération suivante mais la position de la première.
        return _Merge(_MergeOutcome.replace, next);

      case SyncOperationType.create:
        // Deux CREATE sur la même entité : anomalie (rejeu). On garde le
        // premier, dont la clé d'idempotence est déjà connue du serveur.
        return const _Merge(_MergeOutcome.replace, null);

      case SyncOperationType.action:
      case SyncOperationType.upload:
        return const _Merge(_MergeOutcome.keepBoth, null);
    }
  }
}

enum _MergeOutcome {
  /// Remplace l'opération précédente (par [_Merge.operation] si fourni, sinon
  /// la précédente est conservée telle quelle) et jette la suivante.
  replace,

  /// Les deux opérations s'annulent : rien ne part.
  annihilate,

  /// Aucune fusion possible, les deux restent.
  keepBoth,
}

class _Merge {
  final _MergeOutcome outcome;
  final SyncOperation? operation;

  const _Merge(this.outcome, this.operation);
}
