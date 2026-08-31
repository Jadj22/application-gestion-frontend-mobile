import '../config.dart';

/// Résout un chemin de média backend (`/media/...`) en URL complète.
String mediaUrl(String path) {
  if (path.startsWith('http')) return path;
  final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  return '$base$path';
}