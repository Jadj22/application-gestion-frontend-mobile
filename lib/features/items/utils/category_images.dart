/// Utilitaires pour les images de catégories avec fallback.
class CategoryImages {
  CategoryImages._();

  /// Images par catégorie normalisée (minuscules, sans accents).
  static const Map<String, String> _categoryImages = {
    'coutellerie': 'https://images.unsplash.com/photo-1540339223169-20b13b46c470?auto=format&fit=crop&w=400&q=80',
    'vaisselle': 'https://images.unsplash.com/photo-1584990347449-24c3a99de55d?auto=format&fit=crop&w=400&q=80',
    'verrerie': 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=400&q=80',
    'arts de la table': 'https://images.unsplash.com/photo-1518831959646-742c3a14ebf7?auto=format&fit=crop&w=400&q=80',
    'linge de maison': 'https://images.unsplash.com/photo-1584100936595-c0654d59b854?auto=format&fit=crop&w=400&q=80',
    'decoration': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=400&q=80',
    'electromenager': 'https://images.unsplash.com/photo-1574781330855-d0db2707499e?auto=format&fit=crop&w=400&q=80',
    'ustensiles': 'https://images.unsplash.com/photo-1556909114-f6e7ad7bf393?auto=format&fit=crop&w=400&q=80',
    'cuisine': 'https://images.unsplash.com/photo-1556909114-f6e7ad7bf393?auto=format&fit=crop&w=400&q=80',
    'patisserie': 'https://images.unsplash.com/photo-1517433456452-f9633a875f6f?auto=format&fit=crop&w=400&q=80',
    'boulangerie': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80',
    'bar': 'https://images.unsplash.com/photo-1551538827-9c037cb4f32a?auto=format&fit=crop&w=400&q=80',
    'cave': 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?auto=format&fit=crop&w=400&q=80',
    'epicerie': 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=400&q=80',
    'conserves': 'https://images.unsplash.com/photo-1585515656422-7d9e9f4f3974?auto=format&fit=crop&w=400&q=80',
    'surgeles': 'https://images.unsplash.com/photo-1585515656422-7d9e9f4f3974?auto=format&fit=crop&w=400&q=80',
    'produits frais': 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=400&q=80',
    'boissons': 'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=400&q=80',
    'vins': 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=400&q=80',
    'spiritueux': 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80',
    'cafe': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400&q=80',
    'the': 'https://images.unsplash.com/photo-1597318183820-0d2ab9dfc5e5?auto=format&fit=crop&w=400&q=80',
    'mobilier': 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=400&q=80',
    'lumiere': 'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=400&q=80',
    'textile': 'https://images.unsplash.com/photo-1584100936595-c0654d59b854?auto=format&fit=crop&w=400&q=80',
    'jardin': 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=400&q=80',
    'exterieur': 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=400&q=80',
    'nettoyage': 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=400&q=80',
    'entretien': 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=400&q=80',
    'securite': 'https://images.unsplash.com/photo-1581093458791-9d37e5e5b3e7?auto=format&fit=crop&w=400&q=80',
    'outillage': 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=400&q=80',
    'bricolage': 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=400&q=80',
  };

  /// Image par défaut (fallback).
  static const String _defaultImage =
      'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=85';

  /// Normalise une chaîne : minuscules, sans accents, espaces -> rien.
  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[\s\-_]+'), '');
  }

  /// Retourne l'URL d'image pour une catégorie.
  /// Si la catégorie a une image locale, la retourne.
  /// Sinon cherche dans le mapping, sinon retourne l'image par défaut.
  static String getCategoryImage({
    String? localImage,
    required String categoryName,
  }) {
    // Si l'utilisateur a uploadé une image locale, on l'utilise
    if (localImage != null && localImage.isNotEmpty) {
      return localImage;
    }

    // Sinon on cherche dans le mapping
    final normalized = _normalize(categoryName);
    return _categoryImages[normalized] ?? _defaultImage;
  }

  /// Retourne true si c'est une image locale (file://)
  static bool isLocalImage(String? image) {
    return image != null && image.isNotEmpty && image.startsWith('/');
  }
}