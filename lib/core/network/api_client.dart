import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';

// Le champ _tokens est privé alors que le paramètre est nommé : l'assignation
// dans l'initialiseur est volontaire.
// ignore_for_file: prefer_initializing_formals

/// Erreur métier/HTTP normalisée, avec le message envoyé par le backend.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;

  /// Rejet définitif du serveur : réessayer à l'identique ne changera rien.
  /// Les 4xx sont des erreurs de la requête elle-même — sauf 408 (timeout),
  /// 425 (trop tôt) et 429 (throttling), qui méritent une nouvelle tentative.
  bool get isPermanent =>
      statusCode >= 400 &&
      statusCode < 500 &&
      statusCode != 408 &&
      statusCode != 425 &&
      statusCode != 429;

  /// Le serveur a déjà traité cette ressource : pour une synchronisation,
  /// c'est un succès, pas un échec (voir SyncEngine).
  bool get isAlreadyApplied => statusCode == 409;

  /// La ressource visée n'existe plus côté serveur.
  bool get isGone => statusCode == 404 || statusCode == 410;

  @override
  String toString() => message;
}

/// Le réseau n'a pas permis d'atteindre le serveur : pas de réponse HTTP du
/// tout (pas d'interface, DNS mort, connexion coupée, délai dépassé).
///
/// Distinguer ce cas d'une [ApiException] est central pour l'architecture
/// Offline-First : une erreur réseau met l'opération en attente et la fera
/// repartir plus tard, là où un rejet du serveur doit être traité comme tel.
class NetworkUnavailableException implements Exception {
  final String message;
  final Object? cause;

  const NetworkUnavailableException([
    this.message = 'Aucune connexion au serveur.',
    this.cause,
  ]);

  @override
  String toString() => cause != null ? '$message ($cause)' : message;
}

/// Entrée du cache en mémoire.
class _ApiCacheEntry {
  final dynamic data;
  final DateTime storedAt;

  const _ApiCacheEntry(this.data, this.storedAt);
}

/// Client HTTP central : header JWT, refresh automatique sur 401,
/// décodage JSON et normalisation des erreurs DRF.
///
/// Cache transparent des GET : les réponses sont servies depuis la mémoire
/// puis SharedPreferences tant qu'elles sont fraîches ([defaultTtl]), ce qui
/// évite de re-télécharger les mêmes données à chaque navigation/onglet.
/// Les mutations (POST/PATCH/DELETE) invalident automatiquement les GET
/// voisins, et si le réseau échoue, une copie périmée (moins d'un jour) est
/// renvoyée en secours.
class ApiClient {
  static const _cachePrefix = 'dodome.cache.v1.';
  static const _maxBodyChars = 300000;

  final http.Client _client;
  final TokenStorage _tokens;

  /// Cache historique des GET dans SharedPreferences.
  ///
  /// **Désactivé par défaut depuis l'architecture Offline-First** : la base
  /// locale SQLite est devenue le magasin de référence, et ce cache faisait
  /// double emploi avec elle. Le garder actif signifiait écrire chaque réponse
  /// deux fois, et parcourir toutes les clés de SharedPreferences à chaque
  /// mutation pour les invalider — du travail disque pur pour des données déjà
  /// stockées ailleurs.
  ///
  /// Le code reste disponible pour un appelant qui n'aurait pas de couche
  /// locale, mais plus rien ne l'utilise dans l'application.
  bool cacheEnabled = false;

  /// Durée de fraîcheur d'un GET en cache (2 minutes par défaut).
  Duration defaultTtl = const Duration(minutes: 2);

  /// Délai au-delà duquel une requête est considérée comme perdue (75s pour supporter le réveil complet de Render).
  Duration timeout = const Duration(seconds: 75);

  /// Notifié à chaque requête aboutie ou perdue, pour que le service de
  /// connectivité tienne son état à jour sans sonder en permanence.
  void Function({required bool reachable})? onReachability;

  /// Cache en mémoire (lecture instantanée, sans toucher au disque).
  final Map<String, _ApiCacheEntry> _memoryCache = {};

  /// Dédup des GET en vol : même path -> même Future (thundering herd).
  final Map<String, Future<dynamic>> _inFlight = {};

  /// Business actif pour le multi-tenant (header X-Business-ID, RM-01).
  String? businessId;

// L'assignation est volontaire : TokenStorage est une dépendance injectée.
  ApiClient({http.Client? client, required TokenStorage tokens})
      : _client = client ?? http.Client(),
        _tokens = tokens;

  Uri _uri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    return Uri.parse('${AppConfig.apiBaseUrl}$path');
  }

  /// Préfixe de clé de cache : isole les données par business (multi-tenant).
  String _scope() => '$_cachePrefix${businessId ?? 'anon'}';

  String _cacheKey(String path) => '${_scope()}$path';

  Map<String, String> _headers({
    bool auth = true,
    bool json = true,
    String? idempotencyKey,
  }) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = _tokens.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    final businessId = this.businessId;
    if (businessId != null && businessId.isNotEmpty) {
      headers['X-Business-ID'] = businessId;
    }
    // Rejouer une mutation avec la même clé ne doit produire qu'un seul effet
    // côté serveur : c'est ce qui permet de réessayer sans créer de doublon
    // quand la réponse s'est perdue après que le serveur a commité.
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    bool auth = true,
    Duration? ttl,
    bool refresh = false,
  }) =>
      _send('GET', path,
          auth: auth, ttl: ttl ?? defaultTtl, refresh: refresh);

  /// GET d'une liste : déplie l'enveloppe de pagination DRF
  /// `{"count", "next", "previous", "results": [...]}` quand elle est
  /// présente ; accepte aussi une liste brute. Suit automatiquement `next`
  /// pour ne jamais tronquer (DRF page_size 20-50).
  Future<List<dynamic>> getList(
    String path, {
    bool auth = true,
    Duration? ttl,
    bool refresh = false,
  }) async {
    final List<dynamic> all = [];
    String? nextPath = path;
    while (nextPath != null) {
      final decoded = await _send('GET', nextPath,
          auth: auth, ttl: ttl ?? defaultTtl, refresh: refresh);
      if (decoded is List) {
        all.addAll(decoded);
        break;
      }
      if (decoded is Map<String, dynamic>) {
        final results = decoded['results'];
        if (results is List) all.addAll(results);
        final next = decoded['next'];
        if (next is String && next.isNotEmpty) {
          // next est une URL absolue (ex: https://.../api/...?page=2) -> extraire path+query
          final uri = Uri.parse(next);
          nextPath = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
          // Si l'API renvoie une URL avec host différent (Render), ne garder que le path
          if (nextPath.startsWith('/api/')) {
            // ok
          } else if (nextPath.contains('/api/')) {
            nextPath = '/api' + nextPath.split('/api').last;
          }
          continue;
        }
        break;
      }
      throw ApiException(200, 'Réponse inattendue : liste attendue.');
    }
    return all;
  }

  /// Force la suppression d'une entrée du cache (appelé après une mutation).
  Future<void> invalidate(String path) => _invalidate(path);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? idempotencyKey,
  }) =>
      _send('POST', path,
          body: body, auth: auth, idempotencyKey: idempotencyKey);

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? idempotencyKey,
  }) =>
      _send('PATCH', path,
          body: body, auth: auth, idempotencyKey: idempotencyKey);

  Future<dynamic> delete(
    String path, {
    bool auth = true,
    String? idempotencyKey,
  }) =>
      _send('DELETE', path, auth: auth, idempotencyKey: idempotencyKey);

  /// Multipart upload : champs + fichier (photo/logo/catégorie).
  /// Seul le JSON ne suffit pas : DRF attend `request.FILES`.
  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    String field = 'image',
    Map<String, String>? fields,
    bool auth = true,
    bool retried = false,
    String? idempotencyKey,
    String method = 'POST',
  }) async {
    // Le Content-Type est posé par MultipartRequest lui-même (avec sa
    // frontière) : l'imposer ici casserait la requête.
    final request = http.MultipartRequest(method, _uri(path))
      ..headers.addAll(
        _headers(auth: auth, json: false, idempotencyKey: idempotencyKey),
      );
    if (fields != null) request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(field, filePath));

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on Object catch (error) {
      if (error is ApiException) rethrow;
      onReachability?.call(reachable: false);
      throw NetworkUnavailableException(
        "Impossible d'envoyer le fichier : serveur injoignable.",
        error,
      );
    }
    onReachability?.call(reachable: true);

    if (response.statusCode == 401 && auth && !retried) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return uploadFile(
          path,
          filePath: filePath,
          field: field,
          fields: fields,
          auth: auth,
          retried: true,
          method: method,
          idempotencyKey: idempotencyKey,
        );
      }
      throw ApiException(401, 'Session expirée. Veuillez vous reconnecter.');
    }

    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        _extractErrorMessage(decoded, response.body, response.statusCode),
      );
    }

    if (cacheEnabled) await _invalidate(path);
    return decoded;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
    Duration? ttl,
    bool refresh = false,
    String? idempotencyKey,
  }) async {
    // Dédup GET en vol
    if (method == 'GET' && !refresh) {
      final key = '${businessId ?? 'anon'}:$method:$path';
      final existing = _inFlight[key];
      if (existing != null) return existing;
      final fut = _sendInner(method, path, body: body, auth: auth, retried: retried, ttl: ttl, refresh: refresh, idempotencyKey: idempotencyKey);
      _inFlight[key] = fut;
      try {
        return await fut;
      } finally {
        _inFlight.remove(key);
      }
    }
    return _sendInner(method, path, body: body, auth: auth, retried: retried, ttl: ttl, refresh: refresh, idempotencyKey: idempotencyKey);
  }

  Future<dynamic> _sendInner(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
    Duration? ttl,
    bool refresh = false,
    String? idempotencyKey,
  }) async {
    if (cacheEnabled && method == 'GET' && ttl != null && !refresh) {
      final cached = await _readCache(path, ttl);
      if (cached != null) return cached;
    }

    final request = http.Request(method, _uri(path));
    request.headers.addAll(_headers(auth: auth, idempotencyKey: idempotencyKey));
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } catch (error) {
      onReachability?.call(reachable: false);
      // Réseau indisponible : renvoie une copie périmée en secours.
      if (cacheEnabled && method == 'GET') {
        final stale = await _readStaleCache(path);
        if (stale != null) return stale;
      }
      // Typée, pour que l'appelant distingue « pas de réseau » (l'opération
      // repart plus tard) de « le serveur a refusé » (il faut trancher).
      throw NetworkUnavailableException(
        'Serveur injoignable. Vos modifications sont conservées localement.',
        error,
      );
    }

    // Signalé hors du bloc `try` : une réponse a bien été reçue, donc le
    // serveur est joignable — quel que soit son code HTTP. Placer cet appel
    // dans le `try` ferait interpréter une exception d'un écouteur comme une
    // panne réseau, et masquerait l'erreur réelle.
    onReachability?.call(reachable: true);

    if (response.statusCode == 401 && auth && !retried) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(
          method,
          path,
          body: body,
          auth: auth,
          retried: true,
          ttl: ttl,
          refresh: refresh,
          idempotencyKey: idempotencyKey,
        );
      }
      throw ApiException(401, 'Session expirée. Veuillez vous reconnecter.');
    }

    final decoded = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        _extractErrorMessage(decoded, response.body, response.statusCode),
      );
    }

    if (cacheEnabled) {
      if (method == 'GET') {
        await _writeCache(path, decoded);
      } else {
        await _invalidate(path);
      }
    }
    return decoded;
  }

  /// Lecture d'une copie fraîche (mémoire d'abord, puis disque).
  Future<dynamic> _readCache(String path, Duration ttl) async {
    final key = _cacheKey(path);
    final now = DateTime.now();

    final entry = _memoryCache[key];
    if (entry != null) {
      if (now.difference(entry.storedAt) <= ttl) return entry.data;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(map['t'] as String);
      if (now.difference(storedAt) <= ttl) {
        final data = map['d'];
        _memoryCache[key] = _ApiCacheEntry(data, storedAt);
        return data;
      }
    } catch (_) {
      await prefs.remove(key);
    }
    return null;
  }

  /// Copie périmée (dépassée de [ttl] mais datant de moins d'un jour),
  /// utilisée quand le réseau est indisponible.
  Future<dynamic> _readStaleCache(String path) async {
    final key = _cacheKey(path);
    final now = DateTime.now();

    final entry = _memoryCache[key];
    if (entry != null && now.difference(entry.storedAt) <= _staleMaxAge) {
      return entry.data;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(map['t'] as String);
      if (now.difference(storedAt) <= _staleMaxAge) {
        final data = map['d'];
        _memoryCache[key] = _ApiCacheEntry(data, storedAt);
        return data;
      }
    } catch (_) {}
    return null;
  }

  static final _staleMaxAge = const Duration(days: 1);

  Future<void> _writeCache(String path, dynamic decoded) async {
    final key = _cacheKey(path);
    final raw = jsonEncode({'t': DateTime.now().toIso8601String(), 'd': decoded});
    if (raw.length > _maxBodyChars) return; // trop volumineux : on ne cache pas

    _memoryCache[key] = _ApiCacheEntry(decoded, DateTime.now());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, raw);
    await _prune(prefs);
  }

  /// Supprime les entrées du cache liées à une mutation : la collection
  /// parente du path (listes, détail, sous-ressources) et leurs requêtes.
  Future<void> _invalidate(String path) async {
    final slash = path.lastIndexOf('/', path.length - 2);
    final collection = path.substring(0, slash + 1);
    final prefix = _scope();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(prefix) && k.substring(prefix.length).startsWith(collection))
        .toList();
    for (final key in keys) {
      prefs.remove(key);
      _memoryCache.remove(key);
    }
  }

  /// Nettoie les entrées obsolètes (> 1 jour) pour ne pas grossir indéfiniment.
  Future<void> _prune(SharedPreferences prefs) async {
    final prefix = _scope();
    final staleBefore = DateTime.now().subtract(_staleMaxAge).toIso8601String();
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    if (keys.length < 500) return;

    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final t = map['t'] as String? ?? '';
        if (t.compareTo(staleBefore) < 0) {
          prefs.remove(key);
          _memoryCache.remove(key);
        }
      } catch (_) {
        prefs.remove(key);
        _memoryCache.remove(key);
      }
    }
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken == null) return false;
    try {
      final request = http.Request('POST', _uri(ApiEndpoints.refresh));
      request.headers.addAll(_headers(auth: false));
      request.body = jsonEncode({'refresh': refreshToken});
      final response =
          await http.Response.fromStream(await _client.send(request));
      if (response.statusCode != 200) {
        await _tokens.clear();
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _tokens.saveAccess(data['access'] as String);
      return true;
    } catch (_) {
      await _tokens.clear();
      return false;
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  /// Normalise les erreurs DRF : `{"detail": ...}`, `{"champ": [...]}`,
  /// liste d'erreurs ou texte brut.
  String _extractErrorMessage(dynamic decoded, String rawBody, [int? statusCode]) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) return '${detail.first}';
      final buffer = <String>[];
      decoded.forEach((field, value) {
        if (field == 'detail') return;
        final label = field.split('.').last;
        if (value is List && value.isNotEmpty) {
          buffer.add('$label : ${value.first}');
        } else if (value is String && value.isNotEmpty) {
          buffer.add('$label : $value');
        }
      });
      if (buffer.isNotEmpty) return buffer.join('\n');
    }
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic> && first['detail'] is String) {
        return first['detail'] as String;
      }
    }
    final trimmed = rawBody.trim();
    final lower = trimmed.toLowerCase();
    final isHtml = lower.startsWith('<!doctype') ||
        lower.startsWith('<html') ||
        lower.contains('<title>server error');
    if (isHtml) {
      if (statusCode != null && statusCode >= 500) {
        return 'Une erreur interne est survenue sur le serveur ($statusCode). Veuillez réessayer dans quelques instants.';
      }
      return 'Le serveur a renvoyé une page HTML au lieu d\'une réponse API. '
          'Vérifiez l\'URL de l\'API (API_BASE_URL).';
    }
    if (trimmed.isNotEmpty) {
      if (trimmed.length > 240) {
        return '${trimmed.substring(0, 240)}…';
      }
      return trimmed;
    }
    return 'Erreur inattendue.';
  }
}