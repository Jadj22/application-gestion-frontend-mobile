import 'dart:convert';
import 'dart:io';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handler pour les messages reçus en arrière-plan.
/// Doit être une fonction top-level (pas une méthode de classe).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM Background: ${message.messageId}');
}

/// Service de notifications push via Firebase Cloud Messaging.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  /// Accès à FCM, résolu **à l'usage** et non à la construction.
  ///
  /// `FirebaseMessaging.instance` exige que `Firebase.initializeApp()` ait déjà
  /// été appelé. En champ initialisé d'emblée, construire ce service avant
  /// Firebase faisait planter le démarrage — et rendait l'ordre d'initialisation
  /// de `main()` silencieusement critique. En le résolvant ici, le service peut
  /// être construit à tout moment, y compris quand Firebase n'est pas
  /// disponible (appareil sans Play Services, démarrage hors ligne).
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Canal de notification haute priorité pour Android.
  static const AndroidNotificationChannel _highImportanceChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'Notifications importantes',
    description: 'Alertes et notifications importantes de Dodome',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Callback appelé quand l'utilisateur tape sur une notification.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Callback pour enregistrer le token auprès du backend.
  Future<String?> Function(String fcmToken, String? installationId)?
      onTokenRefresh;

  /// Token FCM actuel.
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// ID d'installation Firebase.
  String? _installationId;
  String? get installationId => _installationId;

  /// ID du device enregistré côté backend.
  String? _deviceId;
  String? get deviceId => _deviceId;

  /// Initialise le service FCM.
  Future<void> init() async {
    // Enregistrer le handler pour les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Demander les permissions (iOS et Android 13+)
    await _requestPermission();

    // Configurer les notifications locales
    await _setupLocalNotifications();

    // Créer le canal Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_highImportanceChannel);
    }

    // Récupérer le token FCM et l'ID d'installation
    await _getToken();
    await _getInstallationId();

    // Écouter les rafraîchissements de token
    _fcm.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      debugPrint('FCM Token refreshed: $token');
      // Envoyer le nouveau token au backend
      await registerWithBackend();
    });

    // Gérer les messages reçus quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Gérer le tap sur une notification qui a ouvert l'app
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Vérifier si l'app a été ouverte via une notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Demande les permissions de notification.
  Future<bool> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('FCM Permission: ${settings.authorizationStatus}');
    return granted;
  }

  /// Configure les notifications locales.
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            onNotificationTap?.call(data);
          } catch (_) {}
        }
      },
    );
  }

  /// Récupère le token FCM.
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('FCM TOKEN (pour tests):');
      debugPrint(_fcmToken ?? 'null');
      debugPrint('═══════════════════════════════════════════════════════════');
      return _fcmToken;
    } catch (e) {
      debugPrint('FCM Token error: $e');
      return null;
    }
  }

  /// Récupère l'ID d'installation Firebase.
  Future<String?> _getInstallationId() async {
    try {
      _installationId = await FirebaseInstallations.instance.getId();
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('FIREBASE INSTALLATION ID (pour tests Firebase Console):');
      debugPrint(_installationId ?? 'null');
      debugPrint('═══════════════════════════════════════════════════════════');
      return _installationId;
    } catch (e) {
      debugPrint('Installation ID error: $e');
      return null;
    }
  }

  /// Copie le token FCM dans le presse-papiers.
  Future<void> copyFcmTokenToClipboard() async {
    if (_fcmToken != null) {
      await Clipboard.setData(ClipboardData(text: _fcmToken!));
      debugPrint('FCM Token copié dans le presse-papiers');
    }
  }

  /// Copie l'ID d'installation dans le presse-papiers.
  Future<void> copyInstallationIdToClipboard() async {
    if (_installationId != null) {
      await Clipboard.setData(ClipboardData(text: _installationId!));
      debugPrint('Installation ID copié dans le presse-papiers');
    }
  }

  /// Enregistre le token FCM auprès du backend.
  /// Appelé automatiquement au refresh du token et peut être appelé
  /// manuellement après la connexion de l'utilisateur.
  Future<void> registerWithBackend() async {
    if (_fcmToken == null) {
      debugPrint('FCM: No token to register');
      return;
    }
    if (onTokenRefresh == null) {
      debugPrint('FCM: No backend callback configured');
      return;
    }
    try {
      _deviceId = await onTokenRefresh!(_fcmToken!, _installationId);
      if (_deviceId != null) {
        debugPrint('FCM: Device registered with backend: $_deviceId');
      }
    } catch (e) {
      debugPrint('FCM: Backend registration failed: $e');
    }
  }

  /// Affiche les informations de debug FCM.
  void printDebugInfo() {
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════╗');
    debugPrint('║          FIREBASE CLOUD MESSAGING - DEBUG INFO            ║');
    debugPrint('╠═══════════════════════════════════════════════════════════╣');
    debugPrint('║ Installation ID:                                          ║');
    debugPrint('║ $_installationId');
    debugPrint('╠═══════════════════════════════════════════════════════════╣');
    debugPrint('║ FCM Token:                                                ║');
    debugPrint('║ $_fcmToken');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');
    debugPrint('');
  }

  /// Gère un message reçu au premier plan.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM Foreground: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Afficher une notification locale
    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Dodome',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _highImportanceChannel.id,
          _highImportanceChannel.name,
          channelDescription: _highImportanceChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Gère le tap sur une notification.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM Notification tap: ${message.data}');
    onNotificationTap?.call(message.data);
  }

  /// S'abonne à un topic FCM.
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('FCM subscribed to: $topic');
  }

  /// Se désabonne d'un topic FCM.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('FCM unsubscribed from: $topic');
  }

  /// S'abonne aux notifications d'un business.
  Future<void> subscribeToBusinessNotifications(String businessId) async {
    await subscribeToTopic('business_$businessId');
  }

  /// Se désabonne des notifications d'un business.
  Future<void> unsubscribeFromBusinessNotifications(String businessId) async {
    await unsubscribeFromTopic('business_$businessId');
  }
}
