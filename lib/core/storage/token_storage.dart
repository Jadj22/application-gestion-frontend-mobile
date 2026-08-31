import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage des jetons JWT dans le coffre sécurisé du système.
///
/// Les jetons sont des identifiants de session : sur Android ils sont chiffrés
/// via le Keystore (`EncryptedSharedPreferences`), sur iOS ils vivent dans le
/// Trousseau. SharedPreferences, où ils étaient stockés jusqu'ici, est un
/// simple fichier XML lisible sur un appareil rooté ou via une sauvegarde.
///
/// La base locale (`dodome_offline.db`) reste séparée : elle ne contient que
/// des données métier et la file de synchronisation, jamais de secret. Cette
/// séparation est volontaire — voir `docs/OFFLINE_FIRST.md`, section Sécurité.
class TokenStorage {
  static const _accessKey = 'dodome.access_token';
  static const _refreshKey = 'dodome.refresh_token';

  /// Date de la dernière authentification réellement validée par le serveur.
  /// Elle borne la durée pendant laquelle une session hors ligne est acceptée.
  static const _lastOnlineAuthKey = 'dodome.last_online_auth';

  final FlutterSecureStorage _secure;

  TokenStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  String? accessToken;
  String? refreshToken;
  DateTime? lastOnlineAuthAt;

  Future<void> load() async {
    await _migrateFromSharedPreferences();
    accessToken = await _read(_accessKey);
    refreshToken = await _read(_refreshKey);
    final stamp = await _read(_lastOnlineAuthKey);
    lastOnlineAuthAt = stamp == null ? null : DateTime.tryParse(stamp);
  }

  Future<void> save(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    await _write(_accessKey, access);
    await _write(_refreshKey, refresh);
    await markOnlineAuth();
  }

  Future<void> saveAccess(String access) async {
    accessToken = access;
    await _write(_accessKey, access);
    // Un refresh réussi prouve que le serveur accepte encore la session : la
    // fenêtre hors ligne repart de zéro.
    await markOnlineAuth();
  }

  /// Horodate une authentification validée par le serveur.
  Future<void> markOnlineAuth() async {
    final now = DateTime.now().toUtc();
    lastOnlineAuthAt = now;
    await _write(_lastOnlineAuthKey, now.toIso8601String());
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    lastOnlineAuthAt = null;
    await _delete(_accessKey);
    await _delete(_refreshKey);
    await _delete(_lastOnlineAuthKey);
  }

  bool get hasTokens => accessToken != null && refreshToken != null;

  /// Depuis combien de temps le serveur n'a plus validé cette session.
  Duration? get offlineAge {
    final at = lastOnlineAuthAt;
    if (at == null) return null;
    return DateTime.now().toUtc().difference(at);
  }

  // ── Coffre ───────────────────────────────────────────────────────────────

  Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (error) {
      // Coffre indisponible (appareil verrouillé, Keystore corrompu après une
      // restauration) : on ne fait pas planter le démarrage, l'utilisateur se
      // reconnectera.
      debugPrint('Coffre sécurisé illisible ($key) : $error');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (error) {
      debugPrint('Écriture impossible dans le coffre ($key) : $error');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (error) {
      debugPrint('Suppression impossible dans le coffre ($key) : $error');
    }
  }

  /// Déplace les jetons de l'ancien emplacement (SharedPreferences, en clair)
  /// vers le coffre, puis efface l'original.
  ///
  /// Sans cette étape, une mise à jour de l'application déconnecterait tous les
  /// utilisateurs déjà installés — et laisserait leurs anciens jetons en clair
  /// sur l'appareil.
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString(_accessKey);
      final legacyRefresh = prefs.getString(_refreshKey);
      if (legacyAccess == null && legacyRefresh == null) return;

      if (legacyAccess != null) await _write(_accessKey, legacyAccess);
      if (legacyRefresh != null) await _write(_refreshKey, legacyRefresh);
      if (await _read(_lastOnlineAuthKey) == null) await markOnlineAuth();

      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } catch (error) {
      debugPrint('Migration des jetons vers le coffre impossible : $error');
    }
  }
}
