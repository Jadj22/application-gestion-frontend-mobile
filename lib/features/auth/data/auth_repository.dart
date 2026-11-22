import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/offline/auth/offline_auth_store.dart';
import '../../../../core/offline/connectivity/connectivity_service.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../../core/storage/token_storage.dart';
import 'models/user.dart';
import '../../business/data/models/business.dart';

/// Réponse de connexion / inscription : JWT + utilisateur.
class AuthResult {
  final User user;
  final String accessToken;
  final String refreshToken;

  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}

/// GET /auth/me/ : utilisateur + ses business (avec role_id et statut).
class AuthSession {
  final User user;
  final List<Business> businesses;

  const AuthSession({required this.user, required this.businesses});
}

/// Aperçu public d'une invitation (`GET /invitations/{token}/`).
class InvitationPreview {
  final String email;
  final String businessId;
  final String businessNom;
  final String? inviteur;
  final String? role;
  final String statut;

  const InvitationPreview({
    required this.email,
    required this.businessId,
    required this.businessNom,
    required this.inviteur,
    required this.role,
    required this.statut,
  });

  factory InvitationPreview.fromJson(Map<String, dynamic> json) =>
      InvitationPreview(
        email: json['email'] as String,
        businessId: json['business_id'] as String,
        businessNom: json['business_nom'] as String,
        inviteur: json['inviteur'] as String?,
        role: json['role'] as String?,
        statut: json['statut'] as String,
      );
}

/// Validation d'un code d'invitation (`POST /invitations/validate/`).
/// Renvoie les informations pour l'aperçu avant acceptation.
class InvitationValidation {
  final String email;
  final String businessId;
  final String businessNom;
  final String? role;
  final String? inviteur;
  final DateTime? expiresAt;

  const InvitationValidation({
    required this.email,
    required this.businessId,
    required this.businessNom,
    required this.role,
    required this.inviteur,
    required this.expiresAt,
  });

  factory InvitationValidation.fromJson(Map<String, dynamic> json) {
    final invitation = json['invitation'] as Map<String, dynamic>;
    return InvitationValidation(
      email: invitation['email'] as String,
      businessId: invitation['business_id'] as String,
      businessNom: invitation['business_nom'] as String,
      role: invitation['role'] as String?,
      inviteur: invitation['inviteur'] as String?,
      expiresAt: invitation['expires_at'] != null
          ? DateTime.parse(invitation['expires_at'] as String)
          : null,
    );
  }
}

class AuthRepository {
  final ApiClient _api;
  final TokenStorage _tokens;
  final OfflineAuthStore _offlineAuth;
  final ConnectivityService _connectivity;

  AuthRepository(
    this._api,
    this._tokens,
    this._offlineAuth,
    this._connectivity,
  );

  OfflineAuthStore get offlineAuth => _offlineAuth;

  /// Refuse une operation qui ne peut pas etre differee.
  ///
  /// Inscription et connexion Google creent une identite cote serveur :
  /// fabriquer un compte local qui n'existe nulle part serait un mensonge que
  /// l'utilisateur decouvrirait au pire moment.
  void _requireNetwork(String action, String detail) {
    if (_connectivity.status == ConnectionStatus.offline) {
      throw OfflineUnsupportedException('$action\n\n$detail');
    }
  }

  Future<AuthResult> login(String email, String password) async {
    final data = await _api.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    return await _storeTokens(data);
  }

  /// Connexion Google : l'ID token est échangé contre des JWT côté backend.
  ///
  /// **Exige le reseau** : l'identite est verifiee par Google puis par le
  /// backend, aucune des deux etapes ne peut se faire hors ligne.
  Future<AuthResult> loginWithGoogle(String idToken) async {
    _requireNetwork(
      'Une connexion Internet est necessaire pour la connexion Google.',
      'Si vous vous etes deja connecte sur cet appareil, rouvrez simplement '
      "l'application : votre session est conservee.",
    );
    final data = await _api.post(
      ApiEndpoints.google,
      body: {'id_token': idToken},
      auth: false,
    ) as Map<String, dynamic>;
    return await _storeTokens(data);
  }

  /// Inscription. **Exige le reseau** : le compte doit exister cote serveur.
  Future<AuthResult> register({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
    String telephone = '',
  }) async {
    _requireNetwork(
      'Une connexion Internet est necessaire pour creer un compte.',
      'Votre compte doit etre enregistre sur le serveur avant de pouvoir '
      'etre utilise hors ligne.',
    );
    final data = await _api.post(
      ApiEndpoints.register,
      body: {
        'email': email,
        'password': password,
        if (firstName.isNotEmpty) 'first_name': firstName,
        if (lastName.isNotEmpty) 'last_name': lastName,
        if (telephone.isNotEmpty) 'telephone': telephone,
      },
      auth: false,
    ) as Map<String, dynamic>;
    return await _storeTokens(data);
  }

  /// Enregistre les jetons renvoyes par le serveur.
  ///
  /// L'ecriture est desormais attendue : elle va dans le coffre du systeme,
  /// donc elle est asynchrone. La laisser filer signifiait qu'une fermeture
  /// immediate de l'application pouvait perdre la session tout juste ouverte.
  Future<AuthResult> _storeTokens(Map<String, dynamic> data) async {
    final result = AuthResult(
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['access'] as String,
      refreshToken: data['refresh'] as String,
    );
    await _tokens.save(result.accessToken, result.refreshToken);
    return result;
  }

  /// `GET /invitations/{token}/` — aperçu public du lien d'invitation (deep link).
  Future<InvitationPreview> invitationPreview(String token) async {
    final data = await _api.get(
      ApiEndpoints.invitationPreview(token),
      auth: false,
    ) as Map<String, dynamic>;
    return InvitationPreview.fromJson(data);
  }

  /// `POST /invitations/validate/` — validation d'un code d'invitation (Sprint 11).
  /// Renvoie les informations de l'invitation si le code est valide.
  Future<InvitationValidation> validateCode(String code) async {
    final data = await _api.post(
      ApiEndpoints.invitationValidate,
      body: {'code': code},
      auth: false,
    ) as Map<String, dynamic>;
    return InvitationValidation.fromJson(data);
  }

  /// POST /invitations/accept/ — pose le mot de passe, active l'adhésion
  /// et renvoie des JWT (connexion immédiate).
  /// Accepte soit un token (deep link, Sprint 10) soit un code (Sprint 11).
  Future<AuthResult> acceptInvitation({
    String? token,
    String? code,
    required String password,
    String firstName = '',
    String lastName = '',
    String telephone = '',
  }) async {
    assert(token != null || code != null, 'token ou code requis');
    final data = await _api.post(
      ApiEndpoints.invitationAccept,
      body: {
        'token': ?token,
        'code': ?code,
        'password': password,
        if (firstName.isNotEmpty) 'first_name': firstName,
        if (lastName.isNotEmpty) 'last_name': lastName,
        if (telephone.isNotEmpty) 'telephone': telephone,
      },
      auth: false,
    ) as Map<String, dynamic>;
    return await _storeTokens(data);
  }

  /// POST /invitations/accept/ — acceptation par un utilisateur déjà connecté.
  /// Pas de mot de passe requis, l'utilisateur courant doit correspondre
  /// à l'email invité.
  Future<AuthResult> acceptInvitationAuthenticated({
    String? token,
    String? code,
  }) async {
    assert(token != null || code != null, 'token ou code requis');
    final data = await _api.post(
      ApiEndpoints.invitationAccept,
      body: {
        'token': ?token,
        'code': ?code,
      },
      auth: true,
    ) as Map<String, dynamic>;
    return await _storeTokens(data);
  }

  /// GET /auth/me/ — utilisateur + business (ACTIF uniquement pour la
  /// navigation), avec role_id pour résoudre les permissions (S 1-05).
  Future<AuthSession> session() async {
    final data = await _api.get(ApiEndpoints.me) as Map<String, dynamic>;
    final businesses = ((data['businesses'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((b) => (b['statut'] as String?) == 'ACTIF')
        .map(Business.fromJson)
        .toList();
    return AuthSession(
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      businesses: businesses,
    );
  }

  /// GET /businesses/ — seuls les business avec membership ACTIF.
  Future<List<Business>> myBusinesses() async {
    final data = await _api.getList(ApiEndpoints.businesses);
    return data
        .whereType<Map<String, dynamic>>()
        .map(Business.fromJson)
        .toList();
  }

  /// Deconnexion : jetons **et** materiel de session hors ligne sont effaces.
  ///
  /// Laisser le verificateur de mot de passe derriere permettrait de rouvrir
  /// une session hors ligne apres une deconnexion explicite.
  Future<void> logout() async {
    await _tokens.clear();
    await _offlineAuth.clear();
  }

  /// POST /devices/ — enregistre le token FCM de l'appareil pour les notifications push.
  /// Renvoie l'ID du device créé/mis à jour côté serveur.
  Future<String?> registerDevice({
    required String fcmToken,
    String? installationId,
  }) async {
    try {
      final data = await _api.post(
        ApiEndpoints.devices,
        body: {
          'fcm_token': fcmToken,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'installation_id': ?installationId,
          'app_version': '1.0.0',
        },
      ) as Map<String, dynamic>;
      final deviceId = data['id'] as String?;
      debugPrint('Device registered: $deviceId');
      return deviceId;
    } on ApiException catch (e) {
      debugPrint('Device registration failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Device registration error: $e');
      return null;
    }
  }

  /// DELETE /devices/{id}/ — supprime l'enregistrement de l'appareil (déconnexion).
  Future<void> unregisterDevice(String deviceId) async {
    try {
      await _api.delete(ApiEndpoints.device(deviceId));
      debugPrint('Device unregistered: $deviceId');
    } catch (e) {
      debugPrint('Device unregistration error: $e');
    }
  }
}