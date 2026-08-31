/// Catégorie du catalogue — `CategorySerializer` (US-05).
class CategoryModel {
  final String id;
  final String nom;
  final String? image;

  const CategoryModel({required this.id, required this.nom, this.image});

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        nom: json['nom'] as String,
        // Backend expose `image` (ImageField) et `image_url` (SerializerMethodField absolu).
        // `image` peut être une URL absolue, relative ou null ; `image_url` est prioritaire.
        image: (json['image_url'] ?? json['image']) as String?,
      );
}