import 'package:intl/intl.dart';

/// Demande de réservation côté équipe (authentifié) — `BookingRequestTeamSerializer`.
class BookingRequestModel {
  final String id;
  final String itemId;
  final String itemNom;
  final String itemReference;
  final String itemUnite;
  final int quantite;
  final String clientNom;
  final String clientEmail;
  final String clientTelephone;
  final String message;
  final String dateDebut;
  final String dateFin;
  final String lieuNom;
  final String lieuAdresse;
  final String contactNom;
  final String contactTelephone;
  final String notesLivraison;
  final String statut;
  final String statutDisplay;
  final String? motifRefus;
  final Map<String, dynamic>? contreProposition;
  final String? reservationCreeeId;
  final String createdAt;
  final String updatedAt;

  BookingRequestModel({
    required this.id,
    required this.itemId,
    required this.itemNom,
    required this.itemReference,
    required this.itemUnite,
    required this.quantite,
    required this.clientNom,
    required this.clientEmail,
    required this.clientTelephone,
    required this.message,
    required this.dateDebut,
    required this.dateFin,
    required this.lieuNom,
    required this.lieuAdresse,
    required this.contactNom,
    required this.contactTelephone,
    required this.notesLivraison,
    required this.statut,
    required this.statutDisplay,
    this.motifRefus,
    this.contreProposition,
    this.reservationCreeeId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingRequestModel.fromJson(Map<String, dynamic> json) {
    return BookingRequestModel(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemNom: json['item_nom'] as String,
      itemReference: json['item_reference'] as String? ?? '',
      itemUnite: json['item_unite'] as String? ?? '',
      quantite: json['quantite'] as int,
      clientNom: json['client_nom'] as String,
      clientEmail: json['client_email'] as String,
      clientTelephone: json['client_telephone'] as String,
      message: json['message'] as String? ?? '',
      dateDebut: json['date_debut'] as String,
      dateFin: json['date_fin'] as String,
      lieuNom: json['lieu_nom'] as String? ?? '',
      lieuAdresse: json['lieu_adresse'] as String? ?? '',
      contactNom: json['contact_nom'] as String? ?? '',
      contactTelephone: json['contact_telephone'] as String? ?? '',
      notesLivraison: json['notes_livraison'] as String? ?? '',
      statut: json['statut'] as String,
      statutDisplay: json['statut_display'] as String? ?? '',
      motifRefus: json['motif_refus'] as String?,
      contreProposition: json['contre_proposition'] as Map<String, dynamic>?,
      reservationCreeeId: json['reservation_creee_id'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'item_nom': itemNom,
        'item_reference': itemReference,
        'item_unite': itemUnite,
        'quantite': quantite,
        'client_nom': clientNom,
        'client_email': clientEmail,
        'client_telephone': clientTelephone,
        'message': message,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        'lieu_nom': lieuNom,
        'lieu_adresse': lieuAdresse,
        'contact_nom': contactNom,
        'contact_telephone': contactTelephone,
        'notes_livraison': notesLivraison,
        'statut': statut,
        'statut_display': statutDisplay,
        'motif_refus': motifRefus,
        'contre_proposition': contreProposition,
        'reservation_creee_id': reservationCreeeId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}