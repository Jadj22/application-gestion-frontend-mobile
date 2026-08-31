import '../../../../features/auth/data/models/user.dart';

/// Réservation — `ReservationSerializer` du backend (Sprint 8 + V2 localisation).
class ReservationModel {
  final String id;
  final String itemId;
  final String itemNom;
  final User? reservePar;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final int quantite;
  final String motif;
  final String statut;
  final String? createdAt;
  final int? quantiteRetournee;
  final int? quantiteAbimee;
  final int? quantitePerdue;
  final String observations;
  final DateTime? retourneLe;

  // --- V2: Localisation & traçabilité livraison/reprise ---
  final String lieuNom;
  final String lieuAdresse;
  final double? lieuLat;
  final double? lieuLng;
  final String contactNom;
  final String contactTelephone;
  final DateTime? livraisonPrevueLe;
  final DateTime? livraisonEffectueeLe;
  final String? livreurId;
  final DateTime? reprisePrevueLe;
  final DateTime? repriseEffectueeLe;
  final String? repriseParId;
  final String statutLivraison; // EN_ATTENTE, LIVREE, REPRISE, RETOURNEE
  final String notesLivraison;

  const ReservationModel({
    required this.id,
    required this.itemId,
    required this.itemNom,
    this.reservePar,
    this.dateDebut,
    this.dateFin,
    this.quantite = 1,
    this.motif = '',
    this.statut = 'EN_ATTENTE',
    this.createdAt,
    this.quantiteRetournee,
    this.quantiteAbimee,
    this.quantitePerdue,
    this.observations = '',
    this.retourneLe,
    // V2
    this.lieuNom = '',
    this.lieuAdresse = '',
    this.lieuLat,
    this.lieuLng,
    this.contactNom = '',
    this.contactTelephone = '',
    this.livraisonPrevueLe,
    this.livraisonEffectueeLe,
    this.livreurId,
    this.reprisePrevueLe,
    this.repriseEffectueeLe,
    this.repriseParId,
    this.statutLivraison = 'EN_ATTENTE',
    this.notesLivraison = '',
  });

  bool get estEnAttente => statut == 'EN_ATTENTE';
  bool get estValidee => statut == 'VALIDEE';
  bool get estEnCours => statut == 'EN_COURS';
  bool get estTerminee => statut == 'TERMINEE';
  bool get estAnnulee => statut == 'ANNULEE';

  /// Statuts livraison
  bool get livraisonEnAttente => statutLivraison == 'EN_ATTENTE';
  bool get livraisonLivree => statutLivraison == 'LIVREE';
  bool get livraisonReprise => statutLivraison == 'REPRISE';
  bool get livraisonRetournee => statutLivraison == 'RETOURNEE';

  /// Libellé français du statut.
  String get statutLabel {
    switch (statut) {
      case 'EN_ATTENTE':
        return 'En attente de validation';
      case 'VALIDEE':
        return 'Validée';
      case 'EN_COURS':
        return 'En cours';
      case 'TERMINEE':
        return 'Terminée';
      case 'ANNULEE':
        return 'Annulée';
      default:
        return statut;
    }
  }

  String get statutLivraisonLabel {
    switch (statutLivraison) {
      case 'EN_ATTENTE':
        return 'En attente de livraison';
      case 'LIVREE':
        return 'Livrée';
      case 'REPRISE':
        return 'Reprise (retour client)';
      case 'RETOURNEE':
        return 'Retournée au dépôt';
      default:
        return statutLivraison;
    }
  }

  /// Référence courte affichable (`R-XXXX`).
  String get reference => 'R-${id.split('-').first.toUpperCase()}';

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      ReservationModel(
        id: json['id'] as String,
        itemId: (json['item_id'] as String?) ?? '',
        itemNom: (json['item_nom'] as String?) ?? '',
        reservePar: json['reserve_par'] is Map<String, dynamic>
            ? User.fromJson(json['reserve_par'] as Map<String, dynamic>)
            : null,
        dateDebut: DateTime.tryParse((json['date_debut'] as String?) ?? ''),
        dateFin: DateTime.tryParse((json['date_fin'] as String?) ?? ''),
        quantite: (json['quantite'] as num?)?.toInt() ?? 1,
        motif: (json['motif'] as String?) ?? '',
        statut: (json['statut'] as String?) ?? 'EN_ATTENTE',
        createdAt: json['created_at'] as String?,
        quantiteRetournee: (json['quantite_retournee'] as num?)?.toInt(),
        quantiteAbimee: (json['quantite_abimee'] as num?)?.toInt(),
        quantitePerdue: (json['quantite_perdue'] as num?)?.toInt(),
        observations: (json['observations'] as String?) ?? '',
        retourneLe: DateTime.tryParse((json['retourne_le'] as String?) ?? ''),
        // V2
        lieuNom: (json['lieu_nom'] as String?) ?? '',
        lieuAdresse: (json['lieu_adresse'] as String?) ?? '',
        lieuLat: (json['lieu_lat'] as num?)?.toDouble(),
        lieuLng: (json['lieu_lng'] as num?)?.toDouble(),
        contactNom: (json['contact_nom'] as String?) ?? '',
        contactTelephone: (json['contact_telephone'] as String?) ?? '',
        livraisonPrevueLe: json['livraison_prevue_le'] != null
            ? DateTime.tryParse(json['livraison_prevue_le'] as String)
            : null,
        livraisonEffectueeLe: json['livraison_effectuee_le'] != null
            ? DateTime.tryParse(json['livraison_effectuee_le'] as String)
            : null,
        livreurId: json['livreur'] is Map
            ? (json['livreur'] as Map)['id'] as String?
            : json['livreur_id'] as String?,
        reprisePrevueLe: json['reprise_prevue_le'] != null
            ? DateTime.tryParse(json['reprise_prevue_le'] as String)
            : null,
        repriseEffectueeLe: json['reprise_effectuee_le'] != null
            ? DateTime.tryParse(json['reprise_effectuee_le'] as String)
            : null,
        repriseParId: json['reprise_par'] is Map
            ? (json['reprise_par'] as Map)['id'] as String?
            : json['reprise_par_id'] as String?,
        statutLivraison: (json['statut_livraison'] as String?) ?? 'EN_ATTENTE',
        notesLivraison: (json['notes_livraison'] as String?) ?? '',
      );
}