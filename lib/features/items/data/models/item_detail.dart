import '../../../../core/network/media_url.dart';

/// Fiche article complète — `GET /items/{id}/` + `GET /items/{id}/stock/`.
class ItemDetailModel {
  final String id;
  final String nom;
  final String ref;
  final String description;
  final num prix;
  final String unite;
  final String statut;
  final int total;
  final int disponibles;
  final int sorties;
  final int endommages;
  final int perdus;
  final int enEntretien;
  final int aVerifierCount;
  final String? categorie;
  final String? categoryId;
  final Map<String, dynamic> characteristics;
  final bool? entretienRequis;
  final String etatEntretien;
  final bool aVerifier;
  final String? photoUrl;
  final String? createdAt;
  final String? updatedAt;
  final String? qrCode;

  const ItemDetailModel({
    required this.id,
    required this.nom,
    this.ref = '',
    this.description = '',
    this.prix = 0,
    this.unite = '',
    this.statut = 'ACTIF',
    this.total = 0,
    this.disponibles = 0,
    this.sorties = 0,
    this.endommages = 0,
    this.perdus = 0,
    this.enEntretien = 0,
    this.aVerifierCount = 0,
    this.categorie,
    this.categoryId,
    this.characteristics = const {},
    this.entretienRequis,
    this.etatEntretien = '—',
    this.aVerifier = false,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.qrCode,
  });

  /// Condition affichée dans la carte de statut.
  String get conditionLabel {
    if (!(entretienRequis ?? false)) return 'PRÊT';
    return etatEntretien.isEmpty ? '—' : etatEntretien;
  }

  /// Alerte affichée dans la carte de statut.
  String get alerteLabel => aVerifier ? 'À VÉRIFIER' : 'AUCUNE';

  /// Unités en entretien (API ou calcul résiduel).
  int get entretienStock {
    if (enEntretien > 0) return enEntretien;
    final rest = total - disponibles - sorties - endommages - perdus;
    return rest > 0 ? rest : 0;
  }

  int get verifierStock =>
      aVerifierCount > 0 ? aVerifierCount : (aVerifier ? 1 : 0);

  factory ItemDetailModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? stock,
  }) {
    final category = json['category'];
    final photos = ((json['photos'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final photoPath = photos.isEmpty ? null : photos.first['image'] as String?;
    final rawPrix = json['prix'];
    final s = stock ?? const {};
    return ItemDetailModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      ref: (json['reference'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      prix: rawPrix is num ? rawPrix : num.tryParse('$rawPrix') ?? 0,
      unite: (json['unite'] as String?) ?? '',
      statut: (json['statut'] as String?) ?? 'ACTIF',
      total: (s['total'] as num?)?.toInt() ?? 0,
      disponibles: (s['disponibles'] as num?)?.toInt() ?? 0,
      sorties: (s['sorties'] as num?)?.toInt() ?? 0,
      endommages: (s['endommages'] as num?)?.toInt() ?? 0,
      perdus: (s['perdus'] as num?)?.toInt() ?? 0,
      enEntretien: (s['en_entretien'] as num?)?.toInt() ?? 0,
      aVerifierCount: (s['a_verifier_count'] as num?)?.toInt() ?? 0,
      categorie: category is Map<String, dynamic>
          ? ((category['nom'] as String?) ?? '—')
          : null,
      categoryId: category is Map<String, dynamic>
          ? (category['id'] as String?)
          : null,
      characteristics:
          (json['characteristics'] as Map<String, dynamic>?) ?? const {},
      entretienRequis: json['entretien_requis'] as bool?,
      etatEntretien: _libelleEtat(s['etat_entretien']),
      aVerifier: (s['a_verifier'] as bool?) ?? false,
      photoUrl: photoPath == null ? null : mediaUrl(photoPath),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      qrCode: json['qr_code'] as String?,
    );
  }

  static String _libelleEtat(dynamic etat) {
    if (etat is Map<String, dynamic>) {
      return ((etat['libelle'] as String?) ?? '').toUpperCase();
    }
    return '—';
  }
}