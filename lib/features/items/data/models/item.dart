import '../../../../core/network/media_url.dart';

/// Article du catalogue — `ItemSerializer` (US-06).
class ItemModel {
  final String id;
  final String nom;
  final String? reference;
  final String description;
  final num prix;
  final String unite;
  final String statut;
  final bool? entretienRequis;
  final String? categoryId;
  final String? categoryNom;
  final String? photoUrl;
  final String? qrCode;
  final bool isPublished;

  const ItemModel({
    required this.id,
    required this.nom,
    this.reference,
    this.description = '',
    this.prix = 0,
    this.unite = '',
    this.statut = 'ACTIF',
    this.entretienRequis,
    this.categoryId,
    this.categoryNom,
    this.photoUrl,
    this.qrCode,
    this.isPublished = false,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final rawPrix = json['prix'];
    final photos = ((json['photos'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final photoPath = photos.isEmpty ? null : photos.first['image'] as String?;
    return ItemModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      reference: json['reference'] as String?,
      description: (json['description'] as String?) ?? '',
      prix: rawPrix is num ? rawPrix : num.tryParse('$rawPrix') ?? 0,
      unite: (json['unite'] as String?) ?? '',
      statut: (json['statut'] as String?) ?? 'ACTIF',
      entretienRequis: json['entretien_requis'] as bool?,
      categoryId: category is Map<String, dynamic>
          ? category['id'] as String?
          : (json['category_id'] as String?),
      categoryNom: category is Map<String, dynamic>
          ? category['nom'] as String?
          : null,
      photoUrl: photoPath == null ? null : mediaUrl(photoPath),
      qrCode: json['qr_code'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
    );
  }
}