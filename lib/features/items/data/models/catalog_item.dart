import '../../../../core/network/media_url.dart';

/// Ligne du catalogue — jointure `/items/` + `/stock/` par item.
///
/// `quantite` = disponibilité (RM-04) ; les autres compteurs (total, sorties,
/// entretien, endommagés, perdus) servent à l'onglet Stock.
class CatalogItemModel {
  final String id;
  final String nom;
  final String sku;
  final int quantite;
  final int total;
  final int sorties;
  final int enEntretien;
  final int endommages;
  final int perdus;
  final String? categorie;
  final String? categoryId;
  final String statut;
  final bool entretienRequis;
  final String etatEntretien;
  final bool aVerifier;
  final String? photoUrl;

  /// L'etat du stock de cet article est-il connu ?
  ///
  /// Distinction essentielle : un article **sans ligne de stock** n'est pas un
  /// article epuise. C'est le cas d'un article tout juste cree hors ligne, que
  /// le serveur n'a pas encore compte. Confondre les deux affichait « Epuise »
  /// sur un article qu'on venait de creer avec dix unites en stock.
  final bool stockConnu;

  const CatalogItemModel({
    required this.id,
    required this.nom,
    this.sku = '',
    this.quantite = 0,
    this.total = 0,
    this.sorties = 0,
    this.enEntretien = 0,
    this.endommages = 0,
    this.perdus = 0,
    this.categorie,
    this.categoryId,
    this.statut = 'ACTIF',
    this.entretienRequis = false,
    this.etatEntretien = '—',
    this.aVerifier = false,
    this.photoUrl,
    this.stockConnu = false,
  });

  bool get inactif => statut == 'INACTIF';

  /// Article actif dont le stock est **connu** et entierement indisponible.
  ///
  /// Un stock inconnu n'est jamais « faible » : ce serait affirmer une rupture
  /// qu'on n'a pas constatee.
  bool get faible => !inactif && stockConnu && quantite <= 0;

  /// Article reellement en rupture, par opposition a un stock non renseigne.
  bool get epuise => faible;

  /// Unités actuellement en entretien, distinctes du flag de maintenance
  /// requis sur l'article.
  int get entretienStock {
    if (enEntretien > 0) return enEntretien;
    final rest = total - quantite - sorties - endommages - perdus;
    return rest > 0 ? rest : 0;
  }

  factory CatalogItemModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? stock,
  }) {
    final category = json['category'];
    final photos = ((json['photos'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final photoPath =
        json['photo_url'] as String? ??
        (photos.isEmpty ? null : photos.first['image'] as String?);
    final s = stock ?? const {};
    // Une ligne de stock vide veut dire « pas d'information », pas « zero ».
    final stockConnu = stock != null && stock.isNotEmpty;
    return CatalogItemModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      sku: (json['reference'] as String?) ?? '',
      quantite: (s['disponibles'] as num?)?.toInt() ?? 0,
      total: (s['total'] as num?)?.toInt() ?? 0,
      sorties: (s['sorties'] as num?)?.toInt() ?? 0,
      enEntretien: (s['en_entretien'] as num?)?.toInt() ?? 0,
      endommages: (s['endommages'] as num?)?.toInt() ?? 0,
      perdus: (s['perdus'] as num?)?.toInt() ?? 0,
      categorie: category is Map<String, dynamic>
          ? ((category['nom'] as String?) ?? '—')
          : null,
      categoryId: category is Map<String, dynamic>
          ? (category['id'] as String?)
          : null,
      statut: (json['statut'] as String?) ?? 'ACTIF',
      entretienRequis: (s['entretien_requis'] as bool?) ?? false,
      etatEntretien: _libelleEtat(s['etat_entretien']),
      aVerifier: (s['a_verifier'] as bool?) ?? false,
      photoUrl: photoPath == null ? null : mediaUrl(photoPath),
      stockConnu: stockConnu,
    );
  }

  static String _libelleEtat(dynamic etat) {
    if (etat is Map<String, dynamic>) {
      return ((etat['libelle'] as String?) ?? '').toUpperCase();
    }
    return '—';
  }
}
