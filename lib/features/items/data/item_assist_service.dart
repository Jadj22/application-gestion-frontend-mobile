import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/offline/entity_registry.dart';
import '../../../core/offline/offline_repository.dart';
import 'models/image_description.dart';

/// D'où l'utilisateur veut que l'IA tire sa proposition.
///
/// L'énumération existe pour que le choix soit **explicite de bout en bout** :
/// c'est l'utilisateur qui décide de la source, pas l'application qui devine.
enum AiSource {
  /// Analyser la photo déjà prise.
  photo,

  /// Partir du nom saisi.
  nom,

  /// Partir de mots-clés libres.
  motsCles,

  /// Partir de tous les champs déjà remplis du formulaire.
  champs,

  /// Reformuler la description actuelle.
  amelioration,

  /// Demande libre écrite par l'utilisateur.
  libre,
}

extension AiSourceLabel on AiSource {
  String get label => switch (this) {
        AiSource.photo => 'À partir de la photo',
        AiSource.nom => 'À partir du nom',
        AiSource.motsCles => 'À partir de mots-clés',
        AiSource.champs => 'À partir des informations saisies',
        AiSource.amelioration => 'Améliorer la description actuelle',
        AiSource.libre => 'Écrire une demande personnalisée',
      };

  String get hint => switch (this) {
        AiSource.photo => 'L\'IA analyse la photo de l\'article',
        AiSource.nom => 'L\'IA part du nom que vous avez saisi',
        AiSource.motsCles => 'Quelques mots suffisent',
        AiSource.champs => 'Nom, catégorie, prix, caractéristiques…',
        AiSource.amelioration => 'Reformulée, sans invention',
        AiSource.libre => 'Dites ce que vous attendez',
      };

  /// Valeur attendue par le backend (`source` de `/ai/item-description/`).
  String get wireValue => switch (this) {
        AiSource.photo => 'photo',
        AiSource.nom => 'nom',
        AiSource.motsCles => 'mots_cles',
        AiSource.champs => 'champs',
        AiSource.amelioration => 'amelioration',
        AiSource.libre => 'libre',
      };
}

/// Ce que le formulaire connaît de l'article au moment où l'IA est sollicitée.
class ItemDraftContext {
  final String nom;
  final String description;
  final String categorie;
  final String reference;
  final String unite;
  final String prix;
  final Map<String, String> caracteristiques;
  final String? photoPath;

  const ItemDraftContext({
    this.nom = '',
    this.description = '',
    this.categorie = '',
    this.reference = '',
    this.unite = '',
    this.prix = '',
    this.caracteristiques = const {},
    this.photoPath,
  });

  bool get hasPhoto => (photoPath ?? '').isNotEmpty;
}

/// Assistance à la saisie d'un article : génération IA et référence.
///
/// Deux principes portés par cette classe :
///
/// * **L'IA ne part jamais toute seule.** Aucune méthode ici n'est appelée par
///   un effet de bord (prise de photo, changement de champ) : chacune répond à
///   un geste explicite de l'utilisateur.
/// * **La référence n'a pas besoin de l'IA.** C'est un calcul déterministe,
///   qui doit donc fonctionner hors ligne et sans coût.
class ItemAssistService {
  final ApiClient _api;
  final OfflineRepository _offline;

  ItemAssistService(this._api, this._offline);

  bool get isOnline => _offline.connectivity.isOnline;

  // ── Génération IA ────────────────────────────────────────────────────────

  /// Génère une proposition de fiche article.
  ///
  /// **Exige le réseau** : le modèle tourne côté serveur. Hors ligne, on le dit
  /// clairement au lieu d'échouer sur une erreur technique — et la création
  /// manuelle, elle, continue de fonctionner.
  Future<ImageDescription> generate(
    AiSource source,
    ItemDraftContext context, {
    String motsCles = '',
    String consigne = '',
  }) async {
    if (_offline.connectivity.isOffline) {
      throw const OfflineUnsupportedException(
        'La génération avec l\'IA nécessite une connexion Internet.\n\n'
        'Vous pouvez continuer à remplir la fiche manuellement : votre article '
        'sera enregistré et synchronisé plus tard.',
      );
    }

    if (source == AiSource.photo) {
      final path = context.photoPath;
      if (path == null || path.isEmpty) {
        throw const OfflineUnsupportedException(
          'Prenez d\'abord une photo de l\'article.',
        );
      }
      final data = await _api.uploadFile(
        ApiEndpoints.aiImageDescription,
        filePath: path,
        field: 'image',
      ) as Map<String, dynamic>;
      return ImageDescription.fromJson(data);
    }

    final data = await _api.post(
      ApiEndpoints.aiItemDescription,
      body: {
        'source': source.wireValue,
        if (context.nom.isNotEmpty) 'nom': context.nom,
        if (motsCles.isNotEmpty) 'mots_cles': motsCles,
        if (consigne.isNotEmpty) 'consigne': consigne,
        if (context.description.isNotEmpty)
          'description_actuelle': context.description,
        if (context.categorie.isNotEmpty) 'categorie': context.categorie,
        if (context.reference.isNotEmpty) 'reference': context.reference,
        if (context.unite.isNotEmpty) 'unite': context.unite,
        if (context.prix.isNotEmpty) 'prix': context.prix,
        if (context.caracteristiques.isNotEmpty)
          'caracteristiques': context.caracteristiques,
      },
    ) as Map<String, dynamic>;
    return ImageDescription.fromJson(data);
  }

  // ── Référence ────────────────────────────────────────────────────────────

  /// Propose une référence libre pour un article.
  ///
  /// En ligne, c'est le serveur qui tranche : lui seul connaît toutes les
  /// références déjà prises, y compris celles créées par les collègues.
  ///
  /// Hors ligne, la référence est calculée localement, avec un suffixe propre à
  /// cet appareil — voir [_localReference] pour la raison.
  Future<String> suggestReference(String businessId, String nom) async {
    final propre = nom.trim();
    if (propre.isEmpty) return '';

    if (_offline.connectivity.worthTrying) {
      try {
        final data = await _api.get(
          '${ApiEndpoints.businessItemNextReference(businessId)}'
          '?nom=${Uri.encodeQueryComponent(propre)}',
          ttl: Duration.zero,
          refresh: true,
        );
        if (data is Map<String, dynamic>) {
          final reference = (data['reference'] as String?) ?? '';
          if (reference.isNotEmpty) return reference;
        }
      } on NetworkUnavailableException {
        // Le réseau vient de tomber : on bascule sur le calcul local.
      } on ApiException {
        // Permission manquante ou route indisponible : idem.
      }
    }

    return _localReference(businessId, propre);
  }

  /// Référence calculée sur l'appareil, sans réseau.
  ///
  /// Le piège de l'Offline-First est ici : deux appareils qui génèrent chacun
  /// `CHA-001` hors ligne produisent un doublon que le serveur refusera à la
  /// synchronisation (contrainte `unique(business, reference)`), et
  /// l'opération partirait en échec sans que l'utilisateur comprenne pourquoi.
  ///
  /// Un compteur local n'est donc **pas** globalement unique, et on ne fait pas
  /// semblant qu'il l'est : la référence produite hors ligne porte un suffixe
  /// dérivé d'un identifiant tiré au sort une fois par installation. Deux
  /// appareils ne peuvent alors pas produire la même référence, même en
  /// partant du même nom et du même catalogue.
  Future<String> _localReference(String businessId, String nom) async {
    final prefix = referencePrefix(nom);
    if (prefix.isEmpty) return '';

    final existing = await _offline.store.listPayloads(
      EntityRegistry.item.type,
      businessId: businessId,
    );
    final prises = <String>{
      for (final row in existing)
        if (row['reference'] is String)
          (row['reference'] as String).toUpperCase(),
    };

    final device = await deviceToken();
    for (var compteur = 1; compteur < 1000; compteur++) {
      final candidate =
          '$prefix-${compteur.toString().padLeft(3, '0')}-$device';
      if (!prises.contains(candidate.toUpperCase())) return candidate;
    }
    return '';
  }

  /// Préfixe dérivé du nom : « Chaise pliante en bois » → `CHA-PLI-BOI`.
  ///
  /// Reproduit la logique du serveur pour que les références gardent la même
  /// forme, qu'elles soient calculées ici ou là-bas.
  static String referencePrefix(String nom) {
    const motsVides = {
      'de', 'du', 'des', 'la', 'le', 'les', 'un', 'une', 'en', 'et',
      'a', 'à', 'au', 'aux', 'pour', 'sur', 'avec', 'dans', 'par',
    };
    final mots = nom
        .split(RegExp(r'\s+'))
        .map(_normalize)
        .where((m) => m.isNotEmpty)
        .toList();
    final retenus = mots
        .where((m) => !motsVides.contains(m.toLowerCase()))
        .toList();
    final source = retenus.isEmpty ? mots : retenus;
    if (source.isEmpty) return '';
    return source.take(3).map((m) => m.substring(0, min(3, m.length))).join('-');
  }

  /// Retire les accents et la ponctuation, met en majuscules.
  static String _normalize(String mot) {
    const accents = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
    final buffer = StringBuffer();
    for (final rune in mot.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = accents.indexOf(char);
      final replaced = index >= 0 ? plain[index] : char;
      if (RegExp(r'[a-z0-9]').hasMatch(replaced)) buffer.write(replaced);
    }
    return buffer.toString().toUpperCase();
  }

  static const _deviceTokenKey = 'dodome.device_token';
  static String? _cachedToken;

  /// Jeton court et stable identifiant cette installation.
  ///
  /// Tiré au sort au premier usage puis conservé : c'est lui qui garantit que
  /// deux appareils hors ligne ne fabriquent pas la même référence.
  static Future<String> deviceToken() async {
    final cached = _cachedToken;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_deviceTokenKey);
    if (token == null || token.isEmpty) {
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans I/O/0/1
      final random = Random.secure();
      token = List.generate(
        3,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join();
      await prefs.setString(_deviceTokenKey, token);
    }
    _cachedToken = token;
    return token;
  }

  /// Réinitialise le jeton mémorisé (tests).
  static void resetDeviceTokenCache() => _cachedToken = null;
}
