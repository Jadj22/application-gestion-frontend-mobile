/// Business — `BusinessSerializer` / `MeView` / `BusinessListCreateView`.
class Business {
  final String id;
  final String nom;
  final String slug;
  final String businessType;
  final String adresse;
  final String telephone;
  final String email;
  final String logoUrl;
  final DateTime? createdAt;

  /// Rôle de l'utilisateur courant dans ce business (GET /businesses/, /auth/me/).
  final String? role;

  /// Rôle (membre) du business : ADMIN, OWNER... (côté liste de /auth/me/).
  final String? roleNom;

  /// Id du rôle de l'utilisateur courant (côté /auth/me/ uniquement).
  final String? roleId;

  /// Statut de la membership (côté /auth/me/).
  final String? statut;

  const Business({
    required this.id,
    required this.nom,
    this.slug = '',
    this.businessType = '',
    this.adresse = '',
    this.telephone = '',
    this.email = '',
    this.logoUrl = '',
    this.createdAt,
    this.role,
    this.roleNom,
    this.roleId,
    this.statut,
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as String,
        nom: json['nom'] as String,
        slug: (json['slug'] as String?) ?? '',
        businessType: (json['business_type'] as String?) ?? '',
        adresse: (json['adresse'] as String?) ?? '',
        telephone: (json['telephone'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        logoUrl: (json['logoUrl'] as String?) ?? (json['logo_url'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
        role: json['role'] as String?,
        roleNom: json['role'] as String?,
        roleId: json['role_id'] as String?,
        statut: json['statut'] as String?,
      );

  /// Forme serveur du business, pour memoriser la session hors ligne.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'slug': slug,
        'business_type': businessType,
        'adresse': adresse,
        'telephone': telephone,
        'email': email,
        'logoUrl': logoUrl,
        'created_at': createdAt?.toIso8601String(),
        'role': role,
        'role_id': roleId,
        'statut': statut,
      };
}

/// Brouillon du tunnel d'onboarding avant l'envoi à POST /businesses/.
class BusinessDraft {
  String businessType;
  String nom;
  String logoUrl;

  /// Chemin local d'une image choisie dans la galerie (upload multipart).
  String? logoPath;
  String adresse;
  String telephone;
  String email;

  BusinessDraft({
    this.businessType = '',
    this.nom = '',
    this.logoUrl = '',
    this.logoPath,
    this.adresse = '',
    this.telephone = '',
    this.email = '',
  });

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'business_type': businessType,
        'adresse': adresse,
        'telephone': telephone,
        'email': email,
        if (logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      };
}