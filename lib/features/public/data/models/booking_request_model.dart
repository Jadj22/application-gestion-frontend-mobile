import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Demande de location client (V2) — `BookingRequestSerializer` côté backend.
class BookingRequestModel {
  final String id;
  final String itemId;
  final String itemNom;
  final String itemReference;
  final num itemPrix;
  final String itemUnite;
  final String? itemPhotoUrl;
  final String clientNom;
  final String clientTelephone;
  final String clientEmail;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int quantite;
  final String message;
  final String lieuNom;
  final String lieuAdresse;
  final String contactNom;
  final String contactTelephone;
  final String notesLivraison;
  final String statut;
  final String statutDisplay;
  final String? motifRefus;
  final Map<String, dynamic>? contreProposition;
  final bool peutAnnuler;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Token d'accès magique (pour URLs publiques sans auth)
  final String accessToken;
  final DateTime expiresAt;

  const BookingRequestModel({
    required this.id,
    required this.itemId,
    required this.itemNom,
    required this.itemReference,
    required this.itemPrix,
    required this.itemUnite,
    this.itemPhotoUrl,
    required this.clientNom,
    required this.clientTelephone,
    required this.clientEmail,
    required this.dateDebut,
    required this.dateFin,
    required this.quantite,
    required this.message,
    required this.lieuNom,
    required this.lieuAdresse,
    required this.contactNom,
    required this.contactTelephone,
    required this.notesLivraison,
    required this.statut,
    required this.statutDisplay,
    this.motifRefus,
    this.contreProposition,
    required this.peutAnnuler,
    required this.createdAt,
    required this.updatedAt,
    required this.accessToken,
    required this.expiresAt,
  });

  factory BookingRequestModel.fromJson(Map<String, dynamic> json) {
    final rawPrix = json['item_prix'];
    return BookingRequestModel(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemNom: json['item_nom'] as String,
      itemReference: (json['item_reference'] as String?) ?? '',
      itemPrix: rawPrix is num ? rawPrix : num.tryParse('$rawPrix') ?? 0,
      itemUnite: (json['item_unite'] as String?) ?? '',
      itemPhotoUrl: json['item_photo_url'] as String?,
      clientNom: json['client_nom'] as String,
      clientTelephone: json['client_telephone'] as String,
      clientEmail: json['client_email'] as String,
      dateDebut: DateTime.tryParse((json['date_debut'] as String?) ?? '') ?? DateTime.now(),
      dateFin: DateTime.tryParse((json['date_fin'] as String?) ?? '') ?? DateTime.now(),
      quantite: (json['quantite'] as num?)?.toInt() ?? 1,
      message: (json['message'] as String?) ?? '',
      lieuNom: (json['lieu_nom'] as String?) ?? '',
      lieuAdresse: (json['lieu_adresse'] as String?) ?? '',
      contactNom: (json['contact_nom'] as String?) ?? '',
      contactTelephone: (json['contact_telephone'] as String?) ?? '',
      notesLivraison: (json['notes_livraison'] as String?) ?? '',
      statut: (json['statut'] as String?) ?? 'EN_ATTENTE',
      statutDisplay: (json['statut_display'] as String?) ?? '',
      motifRefus: json['motif_refus'] as String?,
      contreProposition: json['contre_proposition'] as Map<String, dynamic>?,
      peutAnnuler: json['peut_annuler'] as bool? ?? false,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] as String?) ?? '') ?? DateTime.now(),
      accessToken: (json['access_token'] as String?) ?? '',
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  /// Statut enum helpers
  bool get estEnAttente => statut == 'EN_ATTENTE';
  bool get estAcceptee => statut == 'ACCEPTEE';
  bool get estRefusee => statut == 'REFUSEE';
  bool get estExpiree => statut == 'EXPIREE';
  bool get estAnnuleeClient => statut == 'ANNULEE_CLIENT';
  bool get estConvertie => statut == 'CONVERTIE';

  bool get aContreProposition => contreProposition != null && contreProposition!.isNotEmpty;

  /// Prix unitaire formaté
  String get itemPrixFormate {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return '${formatter.format(itemPrix)} FCFA';
  }

  /// Périodes formatées
  String get periodeFormatee {
    final df = DateFormat('dd/MM/yyyy');
    return '${df.format(dateDebut)} - ${df.format(dateFin)}';
  }

  String get montantTotal {
    final total = itemPrix * quantite;
    return '${NumberFormat('#,##0', 'fr_FR').format(total)} FCFA';
  }

  Color get statutColor {
    switch (statut) {
      case 'EN_ATTENTE':
        return Colors.orange;
      case 'ACCEPTEE':
        return Colors.blue;
      case 'REFUSEE':
        return Colors.red;
      case 'EXPIREE':
        return Colors.grey;
      case 'ANNULEE_CLIENT':
        return Colors.grey;
      case 'CONVERTIE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}