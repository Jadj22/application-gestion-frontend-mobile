import 'dart:convert';

import '../network/api_client.dart';
import 'connectivity/connectivity_service.dart';
import 'db/local_store.dart';

/// Copie locale des données que **seul le serveur sait calculer** : tableau de
/// bord, statistiques, historique filtré.
///
/// Ces réponses ne sont pas des entités : elles n'ont pas d'identifiant, ne se
/// modifient pas et n'ont donc rien à faire dans la table `records` ni dans la
/// file de synchronisation. Mais elles doivent rester consultables hors ligne,
/// sinon la page d'accueil serait vide dès la première coupure.
///
/// La règle appliquée ici est donc « réseau si possible, dernière copie
/// sinon » — l'inverse du reste de l'application, et c'est volontaire : il n'y
/// a aucune écriture locale à protéger.
class DerivedCache {
  final LocalStore _store;
  final ApiClient _api;
  final ConnectivityService _connectivity;

  // Parametres positionnels : un nom de parametre nomme ne peut pas commencer
  // par un underscore, donc pas de formel initialisant pour un champ prive.
  const DerivedCache(this._store, this._api, this._connectivity);

  /// Récupère un objet calculé, avec repli sur la dernière copie connue.
  ///
  /// Lève [NetworkUnavailableException] uniquement si le serveur est
  /// injoignable **et** qu'aucune copie n'a jamais été téléchargée : c'est le
  /// seul cas où l'application n'a honnêtement rien à afficher.
  Future<Map<String, dynamic>> object(
    String key,
    String path, {
    bool refresh = false,
  }) async {
    if (_connectivity.worthTrying) {
      try {
        final data = await _api.get(path, refresh: refresh);
        if (data is Map<String, dynamic>) {
          await _store.setMeta(_key(key), jsonEncode(data));
          return data;
        }
      } on NetworkUnavailableException {
        // Repli sur la copie locale ci-dessous.
      }
    }

    final cached = await _read(key);
    if (cached is Map<String, dynamic>) return cached;
    throw const NetworkUnavailableException(
      'Ces données n\'ont pas encore été téléchargées sur cet appareil. '
      'Connectez-vous une fois pour les rendre disponibles hors ligne.',
    );
  }

  /// Variante liste. Renvoie une liste vide plutôt qu'une erreur quand rien
  /// n'a été téléchargé : un historique vide se lit, une exception non.
  Future<List<Map<String, dynamic>>> list(
    String key,
    String path, {
    bool refresh = false,
  }) async {
    if (_connectivity.worthTrying) {
      try {
        final data = await _api.get(path, refresh: refresh);
        final rows = data is List
            ? data.whereType<Map<String, dynamic>>().toList()
            : const <Map<String, dynamic>>[];
        await _store.setMeta(_key(key), jsonEncode(rows));
        return rows;
      } on NetworkUnavailableException {
        // Repli sur la copie locale ci-dessous.
      }
    }

    final cached = await _read(key);
    if (cached is List) return cached.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  /// Date de la dernière copie téléchargée, pour signaler « données du … ».
  Future<bool> has(String key) async => (await _read(key)) != null;

  Future<dynamic> _read(String key) async {
    final raw = await _store.meta(_key(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String _key(String key) => 'derived.$key';
}
