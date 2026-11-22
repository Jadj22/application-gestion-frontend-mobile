import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/auth/offline_auth_store.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../../core/offline/offline_runtime.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../business/data/business_repository.dart';
import '../../business/data/models/business.dart';
import '../../members/data/members_repository.dart';
import '../../members/data/models/role.dart';
import '../data/auth_repository.dart';
import '../data/google_sign_in_service.dart';
import '../data/models/user.dart';

enum SessionStatus { unknown, unauthenticated, authenticated }

/// État global de session (S 1-04 : auth + guards de navigation).
///
/// Flux : unknown -> unauthenticated -> authenticated -> (businesses.isEmpty
/// ? onboarding : home). Les permissions de l'utilisateur courant dans le
/// business actif sont résolues depuis GET /roles/ (S 1-05, RM-19).
class SessionController extends ChangeNotifier {
  final TokenStorage tokens;
  final AuthRepository authRepository;
  final BusinessRepository businessRepository;
  final MembersRepository membersRepository;
  final ApiClient apiClient;
  final GoogleSignInService googleSignInService;
  final PushNotificationService? pushNotificationService;
  final OfflineRuntime offline;

  SessionController({
    required this.tokens,
    required this.authRepository,
    required this.businessRepository,
    required this.membersRepository,
    required this.apiClient,
    required this.googleSignInService,
    required this.offline,
    this.pushNotificationService,
  });

  SessionStatus status = SessionStatus.unknown;
  User? user;
  List<Business> businesses = [];
  Business? currentBusiness;

  /// ID du business actif (null tant qu'aucun business n'est sélectionné).
  String? get currentBusinessId => currentBusiness?.id;

  List<Role> roles = [];
  bool _busy = false;
  bool get busy => _busy;

  /// La session courante a-t-elle été rouverte sans que le serveur la valide ?
  ///
  /// L'interface s'en sert pour expliquer ce que l'utilisateur voit, et le
  /// moteur pour revalider dès que le réseau revient.
  bool _offlineSession = false;
  bool get isOfflineSession => _offlineSession;

  /// Charge en cours propre au flux « Continuer avec Google »
  /// (sélecteur de compte + échange du token) — indépendant de `busy`.
  bool _googleBusy = false;
  bool get googleBusy => _googleBusy;

  /// Message de succès à afficher après une connexion/inscription réussie
  /// (écran de bienvenue) ; null une fois consommé ou après déconnexion.
  String? _welcomeMessage;
  String? get welcomeMessage => _welcomeMessage;

  void _setWelcome(String message) {
    _welcomeMessage = message;
  }

  /// Marque l'écran de bienvenue comme consommé (fin de l'animation).
  void consumeWelcome() {
    if (_welcomeMessage == null) return;
    _welcomeMessage = null;
    notifyListeners();
  }

  /// Résout l'écran initial au démarrage (token persistant ?).
  Future<void> init() async {
    await tokens.load();
    if (!tokens.hasTokens) {
      status = SessionStatus.unauthenticated;
      notifyListeners();
      return;
    }
    await _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await authRepository.session();
      user = session.user;
      businesses = session.businesses;
      if (businesses.isNotEmpty) {
        await _selectBusiness(businesses.first);
      }
      status = SessionStatus.authenticated;
      await _rememberSession();
      // Enregistrer le token push au démarrage avec session existante
      _registerPushToken();
    } on NetworkUnavailableException {
      // Le serveur est injoignable : c'est exactement le cas que
      // l'architecture Offline-First doit couvrir. Déconnecter ici reviendrait
      // à mettre l'utilisateur dehors — et à rendre inaccessible le travail
      // encore en attente de synchronisation — pour une simple coupure réseau.
      await _restoreFromDevice();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Le serveur a explicitement rejeté la session : là, il faut sortir.
        await authRepository.logout();
        status = SessionStatus.unauthenticated;
      } else {
        await _restoreFromDevice();
      }
    } catch (error) {
      debugPrint('Restauration de session : $error');
      await _restoreFromDevice();
    }
    notifyListeners();
  }

  /// Rouvre la session depuis ce que l'appareil a mémorisé.
  ///
  /// Utilisée quand le serveur ne répond pas au démarrage. La session n'est
  /// rouverte que si elle est encore dans sa fenêtre de validité hors ligne
  /// ([OfflineAuthStore.maxOfflineWindow]) : un appareil qui n'a pas vu le
  /// serveur depuis des semaines doit repasser par lui.
  Future<void> _restoreFromDevice() async {
    final cached = await offline.auth.cachedSession();
    if (cached == null || !offline.auth.isWithinOfflineWindow(tokens.offlineAge)) {
      status = SessionStatus.unauthenticated;
      _offlineSession = false;
      return;
    }

    user = User.fromJson(cached.user);
    businesses = cached.businesses.map(Business.fromJson).toList();
    if (businesses.isNotEmpty) {
      await _selectBusiness(businesses.first);
    }
    status = SessionStatus.authenticated;
    _offlineSession = true;
  }

  /// Mémorise la session courante pour les prochaines ouvertures hors ligne.
  Future<void> _rememberSession({String? password, String? provider}) async {
    final current = user;
    if (current == null) return;
    _offlineSession = false;

    if (password != null || provider != null) {
      await offline.auth.remember(
        user: current.toJson(),
        businesses: businesses.map((b) => b.toJson()).toList(),
        password: password,
        provider: provider ?? 'password',
      );
      return;
    }
    await offline.auth.updateSession(
      user: current.toJson(),
      businesses: businesses.map((b) => b.toJson()).toList(),
    );
  }

  /// Connexion par e-mail et mot de passe.
  ///
  /// Si le serveur ne répond pas et que ce compte s'est déjà connecté sur cet
  /// appareil, la session est rouverte localement : le mot de passe est
  /// vérifié contre un dérivé PBKDF2 stocké dans le coffre du système. La
  /// première connexion, elle, exige toujours le réseau.
  Future<void> login(String email, String password) async {
    _setBusy(true);
    try {
      final result = await authRepository.login(email, password);
      user = result.user;
      final session = await authRepository.session();
      user = session.user;
      businesses = session.businesses;
      if (businesses.isNotEmpty) {
        await _selectBusiness(businesses.first);
      }
      status = SessionStatus.authenticated;
      await _rememberSession(password: password, provider: 'password');
      _setWelcome('Connexion réussie');
      notifyListeners();
      // Enregistrer le token push après connexion
      _registerPushToken();
    } on NetworkUnavailableException {
      try {
        await _loginOffline(email, password);
        notifyListeners();
      } on OfflineUnsupportedException {
        throw const OfflineUnsupportedException(
          'Impossible de joindre le serveur backend.\n\n'
          'Vérifiez votre connexion ou patientez quelques secondes '
          '(le serveur distant est peut-être en cours de réveil).',
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  /// Ouvre une session sans serveur, pour un compte déjà connu de l'appareil.
  Future<void> _loginOffline(String email, String password) async {
    final verdict = await offline.auth.verify(
      email: email,
      password: password,
      sessionAge: tokens.offlineAge,
    );
    if (!verdict.granted) {
      throw OfflineUnsupportedException(
        verdict.message ?? 'Connexion impossible hors ligne.',
      );
    }

    final cached = await offline.auth.cachedSession();
    if (cached == null) {
      throw const OfflineUnsupportedException(
        'Aucune session locale disponible. Une connexion Internet est '
        'nécessaire.',
      );
    }

    user = User.fromJson(cached.user);
    businesses = cached.businesses.map(Business.fromJson).toList();
    if (businesses.isNotEmpty) {
      await _selectBusiness(businesses.first);
    }
    status = SessionStatus.authenticated;
    _offlineSession = true;
    _setWelcome('Connexion hors ligne');
  }

  Future<void> register({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
    String telephone = '',
  }) async {
    _setBusy(true);
    try {
      final result = await authRepository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        telephone: telephone,
      );
      user = result.user;
      final session = await authRepository.session();
      businesses = session.businesses;
      status = SessionStatus.authenticated;
      await _rememberSession(password: password, provider: 'password');
      _setWelcome('Compte créé avec succès');
      notifyListeners();
      // Enregistrer le token push après inscription
      _registerPushToken();
    } on NetworkUnavailableException {
      throw const OfflineUnsupportedException(
        'Impossible de joindre le serveur pour créer votre compte.\n\n'
        'Vérifiez votre connexion ou patientez quelques secondes '
        '(le serveur distant est peut-être en cours de réveil).',
      );
    } finally {
      _setBusy(false);
    }
  }

  /// Accepte une invitation par lien (token) ou par code : mot de passe +
  /// activation, puis reconnexion (les JWT renvoyés connectent l'utilisateur).
  /// Sprint 10 : token signé (deep link) / Sprint 11 : code DODO-XXXXXX.
  Future<void> acceptInvitation({
    String? token,
    String? code,
    required String password,
    String firstName = '',
    String lastName = '',
    String telephone = '',
  }) async {
    _setBusy(true);
    try {
      final result = await authRepository.acceptInvitation(
        token: token,
        code: code,
        password: password,
        firstName: firstName,
        lastName: lastName,
        telephone: telephone,
      );
      user = result.user;
      final session = await authRepository.session();
      businesses = session.businesses;
      if (businesses.isNotEmpty) {
        await _selectBusiness(businesses.first);
      }
      status = SessionStatus.authenticated;
      _setWelcome('Invitation acceptée ! Bienvenue dans l\'équipe.');
      notifyListeners();
      // Enregistrer le token push après acceptation
      _registerPushToken();
    } finally {
      _setBusy(false);
    }
  }

  /// Accepte une invitation par code pour un utilisateur déjà connecté.
  /// L'email de l'utilisateur courant doit correspondre à l'email invité.
  Future<void> acceptInvitationAsCurrentUser({String? code}) async {
    _setBusy(true);
    try {
      await authRepository.acceptInvitationAuthenticated(code: code);
      // Recharger la session pour avoir le nouveau business
      final session = await authRepository.session();
      businesses = session.businesses;
      if (businesses.isNotEmpty) {
        await _selectBusiness(businesses.last); // Le nouveau business
      }
      _setWelcome('Invitation acceptée ! Bienvenue dans l\'équipe.');
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Connexion Google : sélecteur de compte -> ID token -> /auth/google/.
  /// Retourne false si l'utilisateur a annulé le sélecteur Google.
  Future<bool> loginWithGoogle() async {
    _setGoogleBusy(true);
    try {
      final idToken = await googleSignInService.signIn();
      if (idToken == null) return false;
      final result = await authRepository.loginWithGoogle(idToken);
      user = result.user;
      final session = await authRepository.session();
      businesses = session.businesses;
      if (businesses.isNotEmpty) {
        await _selectBusiness(businesses.first);
      }
      status = SessionStatus.authenticated;
      await _rememberSession(provider: 'google');
      _setWelcome('Connexion réussie avec Google');
      notifyListeners();
      // Enregistrer le token push après connexion Google
      _registerPushToken();
      return true;
    } finally {
      _setGoogleBusy(false);
    }
  }

  /// Tunnel d'onboarding : POST /businesses/ puis rechargement.
  Future<Business> createBusiness(BusinessDraft draft) async {
    _setBusy(true);
    try {
      final created = await businessRepository.create(draft);
      final session = await authRepository.session();
      businesses = session.businesses;
      final match =
          businesses.where((b) => b.id == created.id).firstOrNull ?? created;
      await _selectBusiness(match);
      status = SessionStatus.authenticated;
      notifyListeners();
      return created;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _selectBusiness(Business business) async {
    currentBusiness = business;
    apiClient.businessId = business.id;
    // La base locale et la file de synchronisation sont cloisonnées par
    // business : le moteur doit savoir sur quel tenant il travaille avant
    // toute lecture ou tout envoi.
    offline.useBusiness(business.id);
    roles = [];
    try {
      roles = await membersRepository.roles(business.id);
    } on ApiException {
      // Sans permission role.view, l'UI s'appuiera sur le rôle connu.
    } on NetworkUnavailableException {
      // Hors ligne : les rôles proviennent de la copie locale, ou restent
      // vides si le business n'a jamais été synchronisé.
    }
  }

  /// Permissions de l'utilisateur courant dans le business actif.
  List<String> get myPermissions {
    final roleId = currentBusiness?.roleId;
    if (roleId == null) return const [];
    final role = roles.where((r) => r.id == roleId).firstOrNull;
    if (role == null) return const [];
    return role.permissions.map((p) => p.codename).toList();
  }

  /// L'utilisateur courant peut-il faire cette action ? (UX uniquement,
  /// le backend reste l'autorité de sécurité — RM-19.)
  bool can(String codename) => myPermissions.contains(codename);

  /// Nombre d'opérations hors ligne qui seraient perdues par une déconnexion.
  ///
  /// L'interface doit le demander **avant** d'appeler [logout] : effacer la
  /// base locale d'un utilisateur qui a travaillé une journée sans réseau, sans
  /// le prévenir, est précisément ce que cette architecture doit empêcher.
  Future<int> pendingBeforeLogout() => offline.pendingBeforeLogout();

  /// Déconnecte et efface les données locales du compte.
  ///
  /// [force] doit valoir true si des opérations restent en attente et que
  /// l'utilisateur a confirmé vouloir les abandonner.
  Future<void> logout({bool force = false}) async {
    final pending = await offline.pendingBeforeLogout();
    if (pending > 0 && !force) {
      throw OfflineUnsupportedException(
        '$pending modification${pending > 1 ? 's' : ''} '
        "n'${pending > 1 ? 'ont' : 'a'} pas encore été synchronisée"
        '${pending > 1 ? 's' : ''}. Connectez-vous à Internet avant de vous '
        'déconnecter, ou confirmez leur abandon.',
      );
    }

    await authRepository.logout();
    await offline.clearAccountData();
    offline.useBusiness(null);
    apiClient.businessId = null;
    user = null;
    businesses = [];
    currentBusiness = null;
    roles = [];
    _welcomeMessage = null;
    _offlineSession = false;
    status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  void _setGoogleBusy(bool value) {
    _googleBusy = value;
    notifyListeners();
  }

  /// Enregistre le token FCM auprès du backend après authentification.
  Future<void> _registerPushToken() async {
    try {
      await pushNotificationService?.registerWithBackend();
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }
}