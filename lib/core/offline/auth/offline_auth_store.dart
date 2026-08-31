import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pourquoi une connexion hors ligne a été refusée.
enum OfflineLoginFailure {
  /// Aucune session n'a jamais été établie sur cet appareil.
  neverAuthenticated,

  /// Le compte demandé n'est pas celui enregistré localement.
  unknownAccount,

  /// Mot de passe incorrect.
  badCredentials,

  /// La session locale est trop ancienne : le serveur doit revalider.
  sessionExpired,

  /// Ce compte s'est authentifié via Google : il n'y a pas de mot de passe
  /// local à vérifier.
  requiresProvider,
}

class OfflineLoginResult {
  final bool granted;
  final OfflineLoginFailure? failure;
  final String? message;

  const OfflineLoginResult.granted()
      : granted = true,
        failure = null,
        message = null;

  const OfflineLoginResult.denied(this.failure, this.message) : granted = false;
}

/// Session mémorisée pour rouvrir l'application hors ligne.
class CachedSession {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> businesses;
  final DateTime savedAt;

  /// `password` ou `google` : détermine si une connexion hors ligne par mot de
  /// passe est possible.
  final String provider;

  const CachedSession({
    required this.user,
    required this.businesses,
    required this.savedAt,
    required this.provider,
  });

  String get email => (user['email'] as String?) ?? '';

  Map<String, dynamic> toJson() => {
        'user': user,
        'businesses': businesses,
        'saved_at': savedAt.toUtc().toIso8601String(),
        'provider': provider,
      };

  factory CachedSession.fromJson(Map<String, dynamic> json) => CachedSession(
        user: (json['user'] as Map).cast<String, dynamic>(),
        businesses: ((json['businesses'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        savedAt:
            DateTime.tryParse(json['saved_at'] as String? ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
        provider: (json['provider'] as String?) ?? 'password',
      );
}

/// Gère l'authentification quand le serveur est injoignable.
///
/// Le principe : **la première authentification exige le réseau**, les
/// suivantes non. Après une connexion validée par le serveur, l'appareil
/// conserve de quoi rouvrir une session localement :
///
/// * la session elle-même (utilisateur, business, rôle) ;
/// * un *vérificateur* de mot de passe — jamais le mot de passe.
///
/// Le vérificateur est un PBKDF2-HMAC-SHA256 sur 120 000 itérations avec un sel
/// aléatoire par appareil, stocké dans le coffre du système. Il permet de dire
/// « ce mot de passe est bien celui de la dernière connexion réussie » sans
/// jamais pouvoir le reconstituer, et sans pouvoir être rejoué sur le serveur.
class OfflineAuthStore {
  static const _verifierKey = 'dodome.offline.verifier';
  static const _saltKey = 'dodome.offline.salt';
  static const _emailKey = 'dodome.offline.email';
  static const _sessionKey = 'dodome.offline.session';

  /// Nombre d'itérations PBKDF2. Assez élevé pour rendre une attaque par
  /// dictionnaire coûteuse, assez bas pour rester imperceptible au démarrage.
  static const int _iterations = 120000;

  /// Durée maximale pendant laquelle l'appareil accepte de rouvrir une session
  /// sans que le serveur l'ait revalidée.
  ///
  /// C'est le compromis central de l'authentification hors ligne : trop court,
  /// l'utilisateur en déplacement est bloqué ; trop long, un appareil perdu
  /// reste exploitable indéfiniment. 30 jours correspond à un mois de terrain
  /// sans réseau fiable.
  static const Duration maxOfflineWindow = Duration(days: 30);

  final FlutterSecureStorage _secure;

  OfflineAuthStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // ── Enregistrement après une connexion réussie ───────────────────────────

  /// Mémorise de quoi rouvrir une session hors ligne.
  ///
  /// [password] n'est fourni que pour une connexion par mot de passe ; pour
  /// Google, il n'y a rien à vérifier localement et le paramètre reste null.
  Future<void> remember({
    required Map<String, dynamic> user,
    required List<Map<String, dynamic>> businesses,
    String? password,
    String provider = 'password',
  }) async {
    final session = CachedSession(
      user: user,
      businesses: businesses,
      savedAt: DateTime.now().toUtc(),
      provider: provider,
    );

    await _write(_sessionKey, jsonEncode(session.toJson()));
    await _write(_emailKey, session.email.toLowerCase());

    if (password != null && password.isNotEmpty) {
      final salt = _randomSalt();
      final verifier = await _deriveOffThread(password, salt);
      await _write(_saltKey, base64Encode(salt));
      await _write(_verifierKey, base64Encode(verifier));
    }
  }

  /// Met à jour la session mémorisée (changement de business, nouveau rôle)
  /// sans toucher au vérificateur de mot de passe.
  Future<void> updateSession({
    required Map<String, dynamic> user,
    required List<Map<String, dynamic>> businesses,
  }) async {
    final existing = await cachedSession();
    await _write(
      _sessionKey,
      jsonEncode(
        CachedSession(
          user: user,
          businesses: businesses,
          savedAt: DateTime.now().toUtc(),
          provider: existing?.provider ?? 'password',
        ).toJson(),
      ),
    );
  }

  Future<CachedSession?> cachedSession() async {
    final raw = await _read(_sessionKey);
    if (raw == null) return null;
    try {
      return CachedSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (error) {
      debugPrint('Session locale illisible : $error');
      return null;
    }
  }

  Future<bool> get hasOfflineSession async => (await _read(_sessionKey)) != null;

  // ── Connexion hors ligne ─────────────────────────────────────────────────

  /// Vérifie des identifiants sans réseau.
  ///
  /// Renvoie un refus explicite plutôt qu'un simple `false` : l'utilisateur
  /// doit comprendre *pourquoi* il est bloqué, notamment quand la fenêtre hors
  /// ligne est dépassée et qu'il lui faut simplement retrouver du réseau.
  Future<OfflineLoginResult> verify({
    required String email,
    required String password,
    required Duration? sessionAge,
  }) async {
    final session = await cachedSession();
    if (session == null) {
      return const OfflineLoginResult.denied(
        OfflineLoginFailure.neverAuthenticated,
        'Première connexion : une connexion Internet est nécessaire.',
      );
    }

    final knownEmail = await _read(_emailKey);
    if (knownEmail == null ||
        knownEmail.toLowerCase() != email.trim().toLowerCase()) {
      return const OfflineLoginResult.denied(
        OfflineLoginFailure.unknownAccount,
        'Ce compte ne s\'est jamais connecté sur cet appareil. '
        'Une connexion Internet est nécessaire.',
      );
    }

    if (session.provider != 'password') {
      return const OfflineLoginResult.denied(
        OfflineLoginFailure.requiresProvider,
        'Ce compte utilise la connexion Google : une connexion Internet est '
        'nécessaire pour le réauthentifier.',
      );
    }

    if (sessionAge != null && sessionAge > maxOfflineWindow) {
      return OfflineLoginResult.denied(
        OfflineLoginFailure.sessionExpired,
        'Votre session hors ligne a expiré après '
        '${maxOfflineWindow.inDays} jours. Connectez-vous à Internet pour la '
        'renouveler.',
      );
    }

    final saltRaw = await _read(_saltKey);
    final verifierRaw = await _read(_verifierKey);
    if (saltRaw == null || verifierRaw == null) {
      return const OfflineLoginResult.denied(
        OfflineLoginFailure.neverAuthenticated,
        'Aucun identifiant local enregistré. Une connexion Internet est '
        'nécessaire.',
      );
    }

    final computed = await _deriveOffThread(
      password,
      Uint8List.fromList(base64Decode(saltRaw)),
    );
    if (!_constantTimeEquals(computed, base64Decode(verifierRaw))) {
      return const OfflineLoginResult.denied(
        OfflineLoginFailure.badCredentials,
        'Mot de passe incorrect.',
      );
    }

    return const OfflineLoginResult.granted();
  }

  /// La session locale est-elle encore dans sa fenêtre de validité ?
  bool isWithinOfflineWindow(Duration? sessionAge) =>
      sessionAge == null || sessionAge <= maxOfflineWindow;

  /// Efface tout ce qui permettrait une session hors ligne (déconnexion).
  Future<void> clear() async {
    for (final key in const [
      _verifierKey,
      _saltKey,
      _emailKey,
      _sessionKey,
    ]) {
      await _delete(key);
    }
  }

  // ── Cryptographie ────────────────────────────────────────────────────────

  /// Derive le verificateur sur un isolate secondaire.
  ///
  /// 120 000 iterations de HMAC-SHA256 en Dart pur representent plusieurs
  /// centaines de millisecondes : les executer sur l'isolate principal ferait
  /// visiblement saccader l'ecran de connexion.
  static Future<Uint8List> _deriveOffThread(String password, Uint8List salt) =>
      compute(_pbkdf2, _Pbkdf2Request(password, salt, _iterations));

  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// Comparaison à temps constant : comparer octet par octet avec sortie
  /// anticipée laisserait fuir la position de la première différence.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // ── Coffre ───────────────────────────────────────────────────────────────

  Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (error) {
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
}

/// Parametres de derivation, transmis a l'isolate de calcul.
class _Pbkdf2Request {
  final String password;
  final Uint8List salt;
  final int iterations;

  const _Pbkdf2Request(this.password, this.salt, this.iterations);
}

/// PBKDF2-HMAC-SHA256, implemente sur le HMAC de `package:crypto`.
///
/// Fonction de premier niveau : `compute()` exige une cible qu'un isolate peut
/// resoudre sans capturer de contexte.
Uint8List _pbkdf2(_Pbkdf2Request request) {
  final hmac = Hmac(sha256, utf8.encode(request.password));

  // Un seul bloc suffit : la sortie voulue fait exactement la taille de
  // SHA-256, soit le bloc numero 1 de PBKDF2.
  final seed = Uint8List(request.salt.length + 4)
    ..setRange(0, request.salt.length, request.salt)
    ..setRange(request.salt.length, request.salt.length + 4, const [0, 0, 0, 1]);

  var current = Uint8List.fromList(hmac.convert(seed).bytes);
  final result = Uint8List.fromList(current);

  for (var i = 1; i < request.iterations; i++) {
    current = Uint8List.fromList(hmac.convert(current).bytes);
    for (var j = 0; j < result.length; j++) {
      result[j] ^= current[j];
    }
  }
  return result;
}
