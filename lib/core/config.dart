/// Configuration globale du frontend.
class AppConfig {
  AppConfig._();

  /// URL de base de l'API Django REST.
  // flutter build apk --release --dart-define=API_BASE_URL=https://application-gestion-backend.onrender.com
  /// 
  /// Surchargeable au lancement :
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.0.2:8000/api`
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.72:8000/api`
  /// `flutter run --dart-define=API_BASE_URL=https://application-gestion-backend.onrender.com/api`
  /// `npx next dev -H 0.0.0.0 -p 3000`
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://application-gestion-backend.onrender.com/api',
  );

  /// URL de base normalisée (sans slash final, avec suffixe /api).
  static String get apiBaseUrl => _normalizeApiUrl(_rawApiBaseUrl);

  static String _normalizeApiUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api')) {
      return '$url/api';
    }
    return url;
  }

  /// URL de base du site web public (vitrine client).
  ///
  /// Surchargeable au lancement :
  /// `flutter run --dart-define=WEB_BASE_URL=http://localhost:3000`
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://application-vitrine-location-eta.vercel.app',
  );
}
