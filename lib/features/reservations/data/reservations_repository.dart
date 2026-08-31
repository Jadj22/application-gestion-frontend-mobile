import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/offline/entity_registry.dart';
import '../../../../core/offline/offline_repository.dart';
import 'models/reservation.dart';

/// Réservations du business (Sprint 8, US-29 à US-31), en Offline-First.
///
/// Particularité de ce domaine : une réservation **engage une ressource
/// partagée**. Deux appareils hors ligne peuvent réserver le même article aux
/// mêmes dates, et seul le serveur peut arbitrer. C'est pourquoi l'entité est
/// déclarée en résolution de conflit `manual` : une demande rejetée n'est ni
/// effacée ni ré-envoyée en boucle, elle est signalée à l'utilisateur.
class ReservationsRepository {
  final OfflineRepository _offline;

  ReservationsRepository(this._offline);

  /// Liste des réservations (reservation.view), filtrée localement.
  Future<List<ReservationModel>> reservations(
    String businessId, {
    String? statut,
    String? itemId,
    bool refresh = false,
  }) async {
    final rows = await _offline.readCollection(
      EntityRegistry.reservation,
      businessId,
      refresh: refresh,
    );

    final resolvedItem =
        itemId == null ? null : await _offline.idMap.resolve(itemId);

    // Les filtres étaient des paramètres d'URL ; ils s'appliquent désormais à
    // la copie locale, ce qui les rend disponibles hors ligne.
    return rows
        .where((row) {
          if (statut != null && row['statut'] != statut) return false;
          if (resolvedItem != null && _itemIdOf(row) != resolvedItem) {
            return false;
          }
          return true;
        })
        .map(ReservationModel.fromJson)
        .toList();
  }

  Future<ReservationModel> detail(
    String businessId,
    String reservationId, {
    bool refresh = false,
  }) async {
    final payload = await _offline.readOne(
      EntityRegistry.reservation,
      businessId,
      reservationId,
      refresh: refresh,
    );
    if (payload == null) {
      throw ApiException(404, 'Réservation introuvable.');
    }
    return ReservationModel.fromJson(payload);
  }

  /// Crée une réservation EN_ATTENTE (reservation.view).
  ///
  /// Hors ligne, elle est enregistrée en attente de validation serveur — ce qui
  /// correspond exactement à son statut métier. L'utilisateur n'est donc pas
  /// induit en erreur : une réservation « en attente » l'est aussi côté
  /// synchronisation.
  Future<ReservationModel> create(
    String businessId, {
    required String itemId,
    required DateTime dateDebut,
    required DateTime dateFin,
    required int quantite,
    String motif = '',
  }) async {
    final resolvedItem = await _offline.idMap.resolve(itemId);
    final item = await _offline.store.findPayload(
      EntityRegistry.item.type,
      resolvedItem,
    );

    final payload = await _offline.create(
      EntityRegistry.reservation,
      businessId,
      {
        'item_id': resolvedItem,
        'date_debut': _isoDate(dateDebut),
        'date_fin': _isoDate(dateFin),
        'quantite': quantite,
        if (motif.trim().isNotEmpty) 'motif': motif.trim(),
      },
      optimisticFields: {
        'statut': 'EN_ATTENTE',
        'item': ?item,
      },
    );
    return ReservationModel.fromJson(payload);
  }

  /// Crée plusieurs réservations en un seul appel atomique (US-29).
  ///
  /// L'atomicité est une garantie **du serveur** : si un article échoue, rien
  /// n'est créé. Hors ligne, on ne peut pas la reproduire — mais on peut la
  /// préserver en envoyant, plus tard, exactement la même requête groupée.
  /// Les réservations sont donc enregistrées localement pour l'affichage, et
  /// une unique opération porte le lot entier.
  Future<List<ReservationModel>> createBulk(
    String businessId, {
    required List<({String itemId, int quantite})> items,
    required DateTime dateDebut,
    required DateTime dateFin,
    String motif = '',
  }) async {
    final lines = <Map<String, dynamic>>[];
    for (final item in items) {
      lines.add({
        'item_id': await _offline.idMap.resolve(item.itemId),
        'quantite': item.quantite,
      });
    }

    final body = <String, dynamic>{
      'items': lines,
      'date_debut': _isoDate(dateDebut),
      'date_fin': _isoDate(dateFin),
      if (motif.trim().isNotEmpty) 'motif': motif.trim(),
    };

    final created = <ReservationModel>[];
    for (final line in lines) {
      final itemId = line['item_id'] as String;
      final item = await _offline.store.findPayload(
        EntityRegistry.item.type,
        itemId,
      );
      created.add(
        ReservationModel.fromJson({
          'id': 'local-bulk-$itemId-${dateDebut.millisecondsSinceEpoch}',
          'item_id': itemId,
          'item': ?item,
          'quantite': line['quantite'],
          'date_debut': body['date_debut'],
          'date_fin': body['date_fin'],
          'statut': 'EN_ATTENTE',
          'motif': body['motif'] ?? '',
        }),
      );
    }

    await _offline.action(
      EntityRegistry.reservation,
      businessId,
      // Le lot n'a pas d'identité propre : on l'attache au premier article,
      // ce qui suffit à ordonner l'opération après la création de cet article.
      lines.first['item_id'] as String,
      path: ApiEndpoints.businessReservationsBulk(businessId),
      body: body,
    );

    return created;
  }

  /// Contrôle de retour (US-31).
  Future<ReservationModel> finish(
    String businessId,
    String reservationId, {
    int? quantiteRetournee,
    int? quantiteAbimee,
    int? quantitePerdue,
    String observations = '',
  }) =>
      action(
        businessId,
        reservationId,
        'terminer',
        body: {
          'quantite_retournee': ?quantiteRetournee,
          'quantite_abimee': ?quantiteAbimee,
          'quantite_perdue': ?quantitePerdue,
          if (observations.trim().isNotEmpty)
            'observations': observations.trim(),
        },
      );

  /// Action de gestion (reservation.manage) : valider, annuler, démarrer,
  /// terminer.
  ///
  /// L'effet est appliqué localement tout de suite pour que l'écran réagisse,
  /// puis confirmé — ou infirmé — par le serveur.
  Future<ReservationModel> action(
    String businessId,
    String reservationId,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final resolvedId = await _offline.idMap.resolve(reservationId);
    final payload = await _offline.action(
      EntityRegistry.reservation,
      businessId,
      resolvedId,
      path: ApiEndpoints.businessReservationAction(
        businessId,
        resolvedId,
        action,
      ),
      body: body,
      localEffect: (current) => {
        ...current,
        ...?body,
        'statut': _statutAfter(action) ?? current['statut'],
      },
    );
    if (payload == null) {
      throw ApiException(404, 'Réservation introuvable.');
    }
    return ReservationModel.fromJson(payload);
  }

  /// Statut résultant d'une action, tel que le serveur l'appliquerait.
  static String? _statutAfter(String action) => switch (action) {
        'valider' => 'VALIDEE',
        'annuler' => 'ANNULEE',
        'demarrer' => 'EN_COURS',
        'terminer' => 'TERMINEE',
        _ => null,
      };

  static String? _itemIdOf(Map<String, dynamic> row) {
    final item = row['item'];
    if (item is Map && item['id'] is String) return item['id'] as String;
    return row['item_id'] as String?;
  }

  static String _isoDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
