import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/offline/entity_registry.dart';
import '../../../core/offline/offline_repository.dart';
import 'models/catalog_item.dart';
import 'models/category.dart';
import 'models/image_description.dart';
import 'models/item.dart';
import 'models/item_detail.dart';
import 'models/stock_movement.dart';

/// Catalogue et stock, en Offline-First.
///
/// Les signatures n'ont pas changé : les écrans appellent les mêmes méthodes et
/// reçoivent les mêmes modèles. Ce qui change est la source — la base locale —
/// et le fait qu'une écriture hors ligne est désormais conservée et rejouée au
/// lieu d'échouer.
class ItemsRepository {
  final ApiClient _api;
  final OfflineRepository _offline;

  ItemsRepository(this._api, this._offline);

  // ── Catégories ───────────────────────────────────────────────────────────

  /// Catégories du business (catalog.view). Lues localement, rafraîchies quand
  /// le réseau le permet.
  Future<List<CategoryModel>> categories(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.category,
      businessId,
      refresh: refresh,
    );
    return rows.map(CategoryModel.fromJson).toList();
  }

  /// Crée une catégorie. Hors ligne, elle apparaît immédiatement avec un
  /// identifiant local et part dès le retour du réseau.
  bool _isLocalImage(String? path) => path != null && path.startsWith('/');

  Future<CategoryModel> createCategory(
    String businessId, {
    required String nom,
    String? description,
    bool? entretienRequis,
    String? image,
  }) async {
    final isLocal = _isLocalImage(image);
    // Ne pas envoyer le chemin local brut en JSON : il doit partir en multipart.
    final createPayload = <String, dynamic>{
      'nom': nom,
      if (description != null && description.isNotEmpty)
        'description': description,
      'entretien_requis': ?entretienRequis,
      if (!isLocal && image != null && image.isNotEmpty) 'image': image,
    };
    final payload = await _offline.create(
      EntityRegistry.category,
      businessId,
      createPayload,
    );
    var category = CategoryModel.fromJson(payload);
    if (isLocal) {
      // Upload différé : la catégorie existe localement (id temporaire),
      // le fichier partira dès que le réseau le permet (PATCH).
      await _offline.upload(
        EntityRegistry.category,
        businessId,
        category.id,
        path: ApiEndpoints.businessCategory(businessId, category.id),
        filePath: image!,
        field: 'image',
        method: 'PATCH',
      );
      // Garder l'aperçu local immédiat
      category = CategoryModel(id: category.id, nom: category.nom, image: image);
    }
    return category;
  }

  /// Met à jour une catégorie. Les articles qui la référencent verront
  /// les changements (nom, image) après rafraîchissement.
  Future<CategoryModel> updateCategory(
    String businessId,
    String categoryId, {
    required String nom,
    String? description,
    bool? entretienRequis,
    String? image,
  }) async {
    final isLocal = _isLocalImage(image);
    final isDelete = image == null;
    final updatePayload = <String, dynamic>{
      'nom': nom,
      if (description != null) 'description': description,
      'entretien_requis': ?entretienRequis,
      // Suppression explicite : envoyer null pour effacer côté serveur
      if (isDelete) 'image': null,
      // Si image est une URL distante inchangée, ne rien envoyer
      // Si image est un fichier local, ne pas l'envoyer en JSON (upload séparé)
      if (!isLocal && !isDelete && image.isNotEmpty && !image.startsWith('http'))
        'image': image,
    };
    final payload = await _offline.update(
      EntityRegistry.category,
      businessId,
      categoryId,
      updatePayload,
    );
    var category = CategoryModel.fromJson(payload);
    if (isLocal) {
      await _offline.upload(
        EntityRegistry.category,
        businessId,
        categoryId,
        path: ApiEndpoints.businessCategory(businessId, categoryId),
        filePath: image!,
        field: 'image',
        method: 'PATCH',
      );
      category = CategoryModel(id: category.id, nom: category.nom, image: image);
    } else if (isDelete) {
      // Retour local avec image effacée pour rafraîchir l'aperçu immédiatement
      category = CategoryModel(id: category.id, nom: category.nom, image: null);
    }
    return category;
  }

  // ── Articles ─────────────────────────────────────────────────────────────

  Future<List<ItemModel>> items(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.item,
      businessId,
      refresh: refresh,
    );
    return rows.map(ItemModel.fromJson).toList();
  }

  /// Catalogue enrichi de l'état du stock.
  ///
  /// Les deux collections sont lues localement puis recroisées ici : hors
  /// ligne, un article créé sur le terrain apparaît avec son stock initial,
  /// même si le serveur ne l'a jamais vu.
  Future<List<CatalogItemModel>> catalog(String businessId,
      {bool refresh = false}) async {
    final results = await Future.wait([
      _offline.readCollection(EntityRegistry.item, businessId,
          refresh: refresh),
      _offline.readCollection(EntityRegistry.stockState, businessId,
          refresh: refresh),
    ]);
    final items = results[0];
    final stockRows = results[1];

    final stockByItem = <String, Map<String, dynamic>>{
      for (final row in stockRows)
        if (row['item_id'] is String) row['item_id'] as String: row,
    };

    return items
        .map(
          (json) => CatalogItemModel.fromJson(
            json,
            stock: stockByItem[json['id'] as String],
          ),
        )
        .toList();
  }

  /// Crée un article (item.edit).
  ///
  /// [initialQuantity] > 0 crée aussi l'entrée de stock initiale côté serveur ;
  /// hors ligne, la quantité est reflétée localement pour que l'article
  /// n'apparaisse pas à zéro en attendant la synchronisation.
  Future<ItemModel> create(
    String businessId, {
    required String nom,
    String? reference,
    String? description,
    num? prix,
    String? unite,
    String? categoryId,
    bool? entretienRequis,
    int? initialQuantity,
    Map<String, String>? characteristics,
    bool isPublished = false,
  }) async {
    final categories = await _offline.store.findPayload(
      EntityRegistry.category.type,
      categoryId ?? '',
    );

    final payload = await _offline.create(
      EntityRegistry.item,
      businessId,
      {
        'nom': nom,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (prix != null && prix > 0) 'prix': prix,
        if (unite != null && unite.isNotEmpty) 'unite': unite,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        'entretien_requis': ?entretienRequis,
        if (characteristics != null && characteristics.isNotEmpty)
          'characteristics': characteristics,
        if (initialQuantity != null && initialQuantity > 0)
          'initial_quantity': initialQuantity,
        'is_published': isPublished,
      },
      // Ce que le serveur calculerait, reproduit localement pour que la fiche
      // s'affiche complète tout de suite.
      optimisticFields: {
        'statut': 'ACTIF',
        'category': ?categories,
      },
    );

    // Le serveur calcule l'etat du stock ; hors ligne il n'existe pas encore.
    // Sans cette projection, un article cree avec dix unites s'affichait
    // « Epuise » jusqu'a la premiere synchronisation.
    await _seedStockLocally(
      businessId,
      payload['id'] as String,
      initialQuantity ?? 0,
    );
    return ItemModel.fromJson(payload);
  }

  /// Cree l'etat de stock local d'un article tout juste cree.
  ///
  /// C'est une projection, pas une verite : le prochain pull la remplace par
  /// le calcul du serveur, qui reste l'autorite.
  Future<void> _seedStockLocally(
    String businessId,
    String itemId,
    int quantite,
  ) async {
    final existant = await _offline.store.find(
      EntityRegistry.stockState.type,
      itemId,
    );
    if (existant != null) return;

    // Ecrite comme une donnee serveur, pas comme une modification en attente :
    // il n'y a **aucune operation a pousser** pour cette projection, et la
    // marquer « en attente » l'aurait rendue definitivement non rafraichissable
    // — l'ingestion refuse d'ecraser un document non synchronise.
    await _offline.store.putFromServer(
      EntityRegistry.stockState.type,
      {
        'id': itemId,
        'item_id': itemId,
        'total': quantite,
        'disponibles': quantite,
        'sorties': 0,
        'endommages': 0,
        'perdus': 0,
      },
      businessId: businessId,
    );
  }

  Future<ItemModel> update(
    String businessId,
    String itemId, {
    required String nom,
    String? reference,
    String? description,
    num? prix,
    String? unite,
    String? categoryId,
    bool? entretienRequis,
    Map<String, String>? characteristics,
    bool? isPublished,
  }) async {
    final payload = await _offline.update(
      EntityRegistry.item,
      businessId,
      itemId,
      {
        'nom': nom,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (prix != null && prix > 0) 'prix': prix,
        if (unite != null && unite.isNotEmpty) 'unite': unite,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        'entretien_requis': ?entretienRequis,
        if (characteristics != null && characteristics.isNotEmpty)
          'characteristics': characteristics,
        if (isPublished != null) 'is_published': isPublished,
      },
    );
    return ItemModel.fromJson(payload);
  }

  /// Supprime un article (catalog.manage). L'article disparaît de l'écran
  /// immédiatement ; l'intention est conservée jusqu'à confirmation du serveur.
  Future<void> delete(String businessId, String itemId) =>
      _offline.delete(EntityRegistry.item, businessId, itemId);

  /// Fiche article complète.
  Future<ItemDetailModel> detail(
    String businessId,
    String itemId, {
    bool refresh = false,
  }) async {
    final item = await _offline.readOne(
      EntityRegistry.item,
      businessId,
      itemId,
      refresh: refresh,
    );
    if (item == null) {
      throw ApiException(404, 'Article introuvable.');
    }

    final resolvedId = item['id'] as String;
    final stock = await _offline.store.findPayload(
      EntityRegistry.stockState.type,
      resolvedId,
    );
    return ItemDetailModel.fromJson(item, stock: stock ?? const {});
  }

  /// Historique immuable des mouvements d'un article.
  ///
  /// Les mouvements créés hors ligne y figurent avant même d'être partis : le
  /// terrain doit voir ce qu'il vient de saisir.
  Future<List<StockMovementModel>> history(
    String businessId,
    String itemId, {
    bool refresh = false,
  }) async {
    final resolvedId = await _offline.idMap.resolve(itemId);
    final rows = await _offline.readCollection(
      EntityRegistry.stockMovement,
      businessId,
      path: ApiEndpoints.businessItemStockHistory(businessId, resolvedId),
      refresh: refresh,
    );
    return rows
        .where((row) => row['item_id'] == resolvedId || row['item_id'] == null)
        .map(StockMovementModel.fromJson)
        .toList();
  }

  // ── Mouvements de stock ──────────────────────────────────────────────────

  /// Enregistre un mouvement de stock (stock.mouvement).
  ///
  /// Journal append-only : chaque mouvement est un fait daté, jamais réécrit.
  /// C'est ce qui rend la reprise de synchronisation sûre — rejouer la séquence
  /// dans l'ordre redonne exactement le même stock côté serveur.
  Future<StockMovementModel> createStockMovement(
    String businessId, {
    required String type,
    required String itemId,
    required int quantite,
    String? motif,
    String? reference,
  }) async {
    final resolvedId = await _offline.idMap.resolve(itemId);
    final payload = await _offline.create(
      EntityRegistry.stockMovement,
      businessId,
      {
        'type': type,
        'item_id': resolvedId,
        'quantite': quantite,
        if (motif != null && motif.isNotEmpty) 'motif': motif,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      },
    );
    await _applyStockLocally(resolvedId, type, quantite);
    return StockMovementModel.fromJson(payload);
  }

  Future<StockMovementModel> createStockEntry(
    String businessId, {
    required String itemId,
    required int quantite,
    String? motif,
    String? reference,
  }) =>
      createStockMovement(
        businessId,
        type: 'ENTREE',
        itemId: itemId,
        quantite: quantite,
        motif: motif,
        reference: reference,
      );

  /// Répercute un mouvement sur l'état de stock local.
  ///
  /// Le serveur reste l'autorité : cette projection est écrasée au prochain
  /// pull. Elle existe pour qu'un magasinier hors ligne voie le stock bouger
  /// pendant qu'il travaille, au lieu d'un chiffre figé.
  Future<void> _applyStockLocally(
    String itemId,
    String type,
    int quantite,
  ) async {
    final current = await _offline.store.find(
      EntityRegistry.stockState.type,
      itemId,
    );
    if (current == null) return;

    final delta = switch (type) {
      'ENTREE' || 'RETOUR' => quantite,
      'SORTIE' || 'PERTE' || 'DOMMAGE' => -quantite,
      _ => 0,
    };
    if (delta == 0) return;

    final payload = {...current.payload};
    for (final key in const ['total', 'disponibles']) {
      final value = payload[key];
      if (value is num) payload[key] = (value + delta).clamp(0, 1 << 31);
    }
    await _offline.store.put(current.copyWith(payload: payload));
  }

  // ── Photos & IA : opérations qui touchent des fichiers ou un service tiers ─

  /// Ajoute une photo à un article (item.edit).
  ///
  /// Le fichier reste sur le disque du téléphone et l'envoi est mis en file :
  /// prendre une photo dans un entrepôt sans réseau doit fonctionner.
  Future<void> addPhoto(
    String businessId,
    String itemId,
    String filePath,
  ) async {
    final resolvedId = await _offline.idMap.resolve(itemId);
    await _offline.upload(
      EntityRegistry.item,
      businessId,
      resolvedId,
      path: ApiEndpoints.businessItemPhotos(businessId, resolvedId),
      filePath: filePath,
      field: 'image',
    );
  }

  /// Analyse une photo par l'IA du backend (Gemini).
  ///
  /// **Exige le réseau** : le traitement se fait côté serveur, il n'y a rien à
  /// simuler hors ligne et inventer une fiche article serait pire que refuser.
  Future<ImageDescription> describeImage(String filePath) async {
    if (_offline.connectivity.isOffline) {
      throw const OfflineUnsupportedException(
        'L\'analyse automatique de photo nécessite une connexion Internet. '
        'Vous pouvez saisir la fiche manuellement.',
      );
    }
    final data = await _api.uploadFile(
      ApiEndpoints.aiImageDescription,
      filePath: filePath,
      field: 'image',
    ) as Map<String, dynamic>;
    return ImageDescription.fromJson(data);
  }
}
