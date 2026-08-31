/// Réponse de POST /ai/image-description/ : la photo d'un article analysée
/// par Gemini, sous forme de fiche prête à remplir le formulaire de création.
///
/// Le backend relie la suggestion au catalogue du business actif (header
/// X-Business-ID) : [categoryId] est renseigné quand la catégorie proposée
/// existe déjà, et [reference] est libre dans ce catalogue.
class ImageDescription {
  final String nom;
  final String description;

  /// Libellé de catégorie : celui du catalogue si [categoryId] est non nul,
  /// sinon une proposition que l'utilisateur peut créer.
  final String categorie;
  final String? categoryId;

  /// Référence (SKU) suggérée, déjà vérifiée comme libre dans le catalogue.
  final String reference;
  final String unite;

  /// État apparent : NEUF, BON, USE, ENDOMMAGE ou INCONNU.
  final String etat;

  /// Caractéristiques factuelles relevées sur la photo (matière, couleur...).
  final Map<String, String> caracteristiques;

  /// HAUTE, MOYENNE ou FAIBLE : fiabilité de l'identification.
  final String confiance;

  const ImageDescription({
    required this.nom,
    required this.description,
    this.categorie = '',
    this.categoryId,
    this.reference = '',
    this.unite = '',
    this.etat = 'INCONNU',
    this.caracteristiques = const {},
    this.confiance = 'MOYENNE',
  });

  factory ImageDescription.fromJson(Map<String, dynamic> json) {
    final brut = json['caracteristiques'];
    final caracteristiques = <String, String>{};
    if (brut is Map) {
      brut.forEach((key, value) {
        final libelle = '$key'.trim();
        final valeur = '$value'.trim();
        if (libelle.isNotEmpty && valeur.isNotEmpty) {
          caracteristiques[libelle] = valeur;
        }
      });
    }
    final categoryId = (json['category_id'] as String?)?.trim();
    return ImageDescription(
      nom: (json['nom'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      categorie: (json['categorie'] as String?)?.trim() ?? '',
      categoryId: (categoryId == null || categoryId.isEmpty) ? null : categoryId,
      reference: (json['reference'] as String?)?.trim() ?? '',
      unite: (json['unite'] as String?)?.trim() ?? '',
      etat: (json['etat'] as String?)?.trim() ?? 'INCONNU',
      caracteristiques: caracteristiques,
      confiance: (json['confiance'] as String?)?.trim() ?? 'MOYENNE',
    );
  }

  /// Copie retouchee de la proposition.
  ///
  /// L'utilisateur peut modifier le texte propose avant de l'appliquer : la
  /// proposition doit donc etre transformable sans etre reconstruite a la main.
  ImageDescription copyWith({
    String? nom,
    String? description,
    String? categorie,
    String? categoryId,
    String? reference,
    String? unite,
    String? etat,
    Map<String, String>? caracteristiques,
    String? confiance,
  }) =>
      ImageDescription(
        nom: nom ?? this.nom,
        description: description ?? this.description,
        categorie: categorie ?? this.categorie,
        categoryId: categoryId ?? this.categoryId,
        reference: reference ?? this.reference,
        unite: unite ?? this.unite,
        etat: etat ?? this.etat,
        caracteristiques: caracteristiques ?? this.caracteristiques,
        confiance: confiance ?? this.confiance,
      );

  bool get hasContent => nom.isNotEmpty || description.isNotEmpty;

  /// Vrai quand le modèle propose une catégorie absente du catalogue :
  /// l'application peut alors proposer de la créer.
  bool get proposeUneNouvelleCategorie =>
      categoryId == null && categorie.isNotEmpty;

  /// Libellé lisible de l'état apparent, pour l'affichage.
  String get etatLisible => switch (etat) {
        'NEUF' => 'Neuf',
        'BON' => 'Bon état',
        'USE' => 'Usé',
        'ENDOMMAGE' => 'Endommagé',
        _ => 'État indéterminé',
      };

  /// Libellé lisible de la confiance, pour l'affichage.
  String get confianceLisible => switch (confiance) {
        'HAUTE' => 'Identification fiable',
        'FAIBLE' => 'Identification incertaine',
        _ => 'Identification à vérifier',
      };

  bool get confianceFaible => confiance == 'FAIBLE';
}
