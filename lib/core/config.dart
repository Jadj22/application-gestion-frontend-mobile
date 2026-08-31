/// Configuration globale du frontend.
class AppConfig {
  AppConfig._();

  /// URL de base de l'API Django REST.
  ///
  /// Surchargeable au lancement :
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.0.2:8000/api`
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.72:8000/api`
  /// `npx next dev -H 0.0.0.0 -p 3000`
  /// Par défaut : serveur sur le réseau local (192.168.1.72).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://application-gestion-backend.onrender.com/api',
  );

  /// URL de base du site web public (vitrine client).
  ///
  /// Surchargeable au lancement :
  /// `flutter run --dart-define=WEB_BASE_URL=http://localhost:3000`
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://application-vitrine-location-eta.vercel.app',
  );
}
