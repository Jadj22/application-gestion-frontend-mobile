import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/media_url.dart';

/// Article du catalogue public (lecture seule) — `PublicItemSerializer` (V1).
class PublicItemModel {
  final String id;
  final String nom;
  final String? reference;
  final String publicDescription;
  final num prix;
  final String unite;
  final String? photoUrl;
  final String? categoryNom;
  final String? qrCode;

  // Disponibilité temps réel (Option B) — présents si ?date_debut=&date_fin=
  final int? totalStock;
  final int? disponible;
  final int? reservesPendantPeriode;
  final int? bookingRequestsPendantes;
  final int? enEntretien;
  final bool? peutReserver;

  const PublicItemModel({
    required this.id,
    required this.nom,
    this.reference,
    this.publicDescription = '',
    this.prix = 0,
    this.unite = '',
    this.photoUrl,
    this.categoryNom,
    this.qrCode,
    this.totalStock,
    this.disponible,
    this.reservesPendantPeriode,
    this.bookingRequestsPendantes,
    this.enEntretien,
    this.peutReserver,
  });

  factory PublicItemModel.fromJson(Map<String, dynamic> json) {
    final rawPrix = json['prix'];
    return PublicItemModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      reference: json['reference'] as String?,
      publicDescription: (json['public_description'] as String?) ?? '',
      prix: rawPrix is num ? rawPrix : num.tryParse('$rawPrix') ?? 0,
      unite: (json['unite'] as String?) ?? '',
      photoUrl: json['photo_url'] as String?,
      categoryNom: json['category_nom'] as String?,
      qrCode: json['qr_code'] as String?,
      totalStock: (json['total_stock'] as num?)?.toInt(),
      disponible: (json['disponible'] as num?)?.toInt(),
      reservesPendantPeriode: (json['reserves_pendant_periode'] as num?)?.toInt(),
      bookingRequestsPendantes: (json['booking_requests_pendantes'] as num?)?.toInt(),
      enEntretien: (json['en_entretien'] as num?)?.toInt(),
      peutReserver: json['peut_reserver'] as bool?,
    );
  }

  /// Prix formaté avec unité (ex: "2 500 FCFA/jour")
  String get prixFormate {
    final formatter = NumberFormat('#,##0', 'fr_FR');
    return '${formatter.format(prix)} FCFA${unite.isNotEmpty ? '/$unite' : ''}';
  }

  /// Badge de disponibilité pour l'affichage
  String get disponibiliteLabel {
    if (peutReserver == false) return 'Indisponible';
    if (disponible == null) return 'Disponibilité inconnue';
    if (disponible! <= 0) return 'Complet';
    if (disponible! <= 3) return 'Il reste $disponible';
    return 'Disponible ($disponible)';
  }

  Color get disponibiliteColor {
    if (peutReserver == false || disponible == 0) return Colors.red;
    if (disponible != null && disponible! <= 3) return Colors.orange;
    return Colors.green;
  }
}