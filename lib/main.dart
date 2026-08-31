import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/offline/connectivity/connectivity_service.dart';
import 'core/offline/derived_cache.dart';
import 'core/offline/offline_repository.dart';
import 'core/offline/offline_runtime.dart';
import 'core/offline/sync/sync_engine.dart';
import 'core/services/push_notification_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/google_sign_in_service.dart';
import 'features/auth/presentation/pages/accept_invitation_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/auth/presentation/pages/welcome_screen.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/business/data/business_repository.dart';
import 'features/business/presentation/pages/business_onboarding_page.dart';
import 'features/home/data/home_repository.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/items/data/item_assist_service.dart';
import 'features/items/data/item_units_service.dart';
import 'features/items/data/items_repository.dart';
import 'features/maintenance/data/maintenance_repository.dart';
import 'features/members/data/members_repository.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/reservations/data/reservations_repository.dart';
import 'features/reservations/data/repositories/booking_request_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = TokenStorage();
  final apiClient = ApiClient(tokens: tokens);

  // La couche Offline-First démarre avant l'interface : au premier écran,
  // l'application doit déjà savoir ce qu'elle a en local et ce qui reste à
  // envoyer. Elle ne dépend ni de Firebase ni du réseau pour s'ouvrir.
  final offline = await OfflineRuntime.boot(api: apiClient);

  final derived = DerivedCache(
    offline.store,
    apiClient,
    offline.connectivity,
  );

  final authRepository = AuthRepository(
    apiClient,
    tokens,
    offline.auth,
    offline.connectivity,
  );

  // Firebase et les notifications push exigent le réseau et les services
  // Google : leur échec ne doit pas empêcher l'application de s'ouvrir hors
  // ligne. `Firebase.initializeApp()` doit précéder toute utilisation du
  // service — l'inverse fait planter le démarrage.
  final pushService = PushNotificationService();
  try {
    await Firebase.initializeApp();
    pushService.onTokenRefresh = (fcmToken, installationId) async {
      return authRepository.registerDevice(
        fcmToken: fcmToken,
        installationId: installationId,
      );
    };
    await pushService.init();
  } catch (error) {
    debugPrint('Notifications push indisponibles au démarrage : $error');
  }

  runApp(
    DodomeApp(
      pushNotificationService: pushService,
      offline: offline,
      tokens: tokens,
      apiClient: apiClient,
      authRepository: authRepository,
      businessRepository: BusinessRepository(apiClient),
      membersRepository: MembersRepository(apiClient, offline.repository),
      homeRepository: HomeRepository(derived),
      itemsRepository: ItemsRepository(apiClient, offline.repository),
      itemAssistService: ItemAssistService(apiClient, offline.repository),
      itemUnitsService: ItemUnitsService(offline.repository),
      maintenanceRepository: MaintenanceRepository(
        apiClient,
        offline.repository,
        derived,
      ),
      reservationsRepository: ReservationsRepository(offline.repository),
      bookingRequestRepository: BookingRequestRepository(apiClient),
      notificationsRepository: NotificationsRepository(offline.repository),
    ),
  );
}

class DodomeApp extends StatelessWidget {
  final PushNotificationService pushNotificationService;
  final OfflineRuntime offline;
  final TokenStorage tokens;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final BusinessRepository businessRepository;
  final MembersRepository membersRepository;
  final HomeRepository homeRepository;
  final ItemsRepository itemsRepository;
  final ItemAssistService itemAssistService;
  final ItemUnitsService itemUnitsService;
  final MaintenanceRepository maintenanceRepository;
  final ReservationsRepository reservationsRepository;
  final BookingRequestRepository bookingRequestRepository;
  final NotificationsRepository notificationsRepository;

  const DodomeApp({
    super.key,
    required this.pushNotificationService,
    required this.offline,
    required this.tokens,
    required this.apiClient,
    required this.authRepository,
    required this.businessRepository,
    required this.membersRepository,
    required this.homeRepository,
    required this.itemsRepository,
    required this.itemAssistService,
    required this.itemUnitsService,
    required this.maintenanceRepository,
required this.reservationsRepository,
      required this.bookingRequestRepository,
      required this.notificationsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionController(
            tokens: tokens,
            authRepository: authRepository,
            businessRepository: businessRepository,
            membersRepository: membersRepository,
            apiClient: apiClient,
            googleSignInService: GoogleSignInService(),
            pushNotificationService: pushNotificationService,
            offline: offline,
          )..init(),
        ),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<BusinessRepository>.value(value: businessRepository),
        Provider<MembersRepository>.value(value: membersRepository),
        Provider<HomeRepository>.value(value: homeRepository),
        Provider<ItemsRepository>.value(value: itemsRepository),
        Provider<ItemAssistService>.value(value: itemAssistService),
        Provider<ItemUnitsService>.value(value: itemUnitsService),
        Provider<MaintenanceRepository>.value(value: maintenanceRepository),
        Provider<ApiClient>.value(value: apiClient),
        Provider<ReservationsRepository>.value(value: reservationsRepository),
        Provider<BookingRequestRepository>.value(value: bookingRequestRepository),
        Provider<NotificationsRepository>.value(value: notificationsRepository),
        Provider<PushNotificationService>.value(value: pushNotificationService),
        // La couche hors ligne est exposée à l'interface : l'indicateur d'état
        // et la liste des opérations en attente s'y abonnent.
        Provider<OfflineRuntime>.value(value: offline),
        Provider<OfflineRepository>.value(value: offline.repository),
        ChangeNotifierProvider<SyncEngine>.value(value: offline.engine),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: offline.connectivity,
        ),
      ],
      child: MaterialApp(
        title: 'DODOME',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Guard de navigation (S 1-04) :
///   inconnu -> splash ; non authentifié -> Login ;
///   succès de connexion/inscription -> WelcomeScreen (puis Onboarding/Home) ;
///   authentifié sans business -> Onboarding ; sinon -> Home.
///
/// Un lien d'invitation (deep link Android, Sprint 10) bascule vers
/// AcceptInvitationPage tant que son token n'a pas été traité.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  String? _pendingToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks.getInitialLink().then(_handleLink);
    _sub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  /// Reprise de l'application au premier plan : on revérifie le réseau et on
  /// vide la file s'il y a de quoi.
  ///
  /// C'est le second déclencheur de synchronisation, à côté du retour de
  /// connexion : l'utilisateur qui rouvre l'application dans une zone couverte
  /// doit voir son travail partir sans rien avoir à faire.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final offline = context.read<OfflineRuntime>();
    fireAndForget(
      () async {
        await offline.connectivity.probe();
        if (offline.connectivity.isOnline && offline.engine.hasPending) {
          await offline.engine.sync(reason: 'reprise de l\'application');
        }
      },
      label: 'Synchronisation à la reprise',
    );
  }

  /// Extrait le token d'invitation d'un lien `.../invitation?token=...`
  /// (https://app.dodome.app/invitation?token=... ou dodome://invitation?token=...).
  void _handleLink(Uri? uri) {
    if (uri == null || !mounted) return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    setState(() => _pendingToken = token);
  }

  @override
  Widget build(BuildContext context) {
    final pendingToken = _pendingToken;
    final Widget screen;
    if (pendingToken != null) {
      screen = AcceptInvitationPage(
        key: const ValueKey('accept-invitation'),
        token: pendingToken,
        onAccepted: () => setState(() => _pendingToken = null),
        onCancel: () => setState(() => _pendingToken = null),
      );
    } else {
      final session = context.watch<SessionController>();
      switch (session.status) {
        case SessionStatus.unknown:
          screen = const SplashScreen(key: ValueKey('splash'));
        case SessionStatus.unauthenticated:
          screen = const LoginPage(key: ValueKey('login'));
        case SessionStatus.authenticated:
          final welcome = session.welcomeMessage;
          if (welcome != null) {
            screen = WelcomeScreen(
              key: const ValueKey('welcome'),
              message: welcome,
              onDone: () => context.read<SessionController>().consumeWelcome(),
            );
          } else {
            screen = session.businesses.isEmpty
                ? const BusinessOnboardingPage(key: ValueKey('onboarding'))
                : const HomePage(key: ValueKey('home'));
          }
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: screen,
    );
  }
}
